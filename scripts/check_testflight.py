"""Wait for the uploaded FanControl build to finish Apple's processing."""
import base64
import json
import os
import subprocess
import time
import urllib.parse
import urllib.request

def request(path, body=None):
    def b64(value):
        return base64.urlsafe_b64encode(value).decode().rstrip('=')
    now = int(time.time())
    header = b64(json.dumps({'alg': 'ES256', 'kid': os.environ['ASC_KEY_ID'], 'typ': 'JWT'}).encode())
    payload = b64(json.dumps({'iss': os.environ['ASC_ISSUER_ID'], 'iat': now, 'exp': now + 600, 'aud': 'appstoreconnect-v1'}).encode())
    signing_input = (header + '.' + payload).encode()
    signature = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', os.environ['ASC_KEY_PATH']], input=signing_input, capture_output=True, check=True).stdout
    assert signature[0] == 0x30 and signature[1] < 128
    offset = 2
    parts = []
    for _ in range(2):
        assert signature[offset] == 2
        size = signature[offset + 1]
        parts.append(int.from_bytes(signature[offset+2:offset+2+size], 'big').to_bytes(32, 'big'))
        offset += size + 2
    token = header + '.' + payload + '.' + b64(b''.join(parts))
    req = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/' + path, data=json.dumps(body).encode() if body else None, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

apps = request('apps?' + urllib.parse.urlencode({'filter[bundleId]': 'dev.fancontrol.watch'}))['data']
assert len(apps) == 1, 'FanControl App Store Connect app missing or ambiguous'
app = apps[0]['id']
deadline = time.monotonic() + 1200
last = None
while time.monotonic() < deadline:
    builds = request('builds?' + urllib.parse.urlencode({'filter[app]': app, 'filter[version]': os.environ['BUILD_NUMBER'], 'include': 'preReleaseVersion'}))
    if builds['data']:
        assert len(builds['data']) == 1, 'Build is ambiguous'
        build = builds['data'][0]
        state = build['attributes']['processingState']
        if state != last:
            print('Apple processing: ' + state, flush=True)
            last = state
        if state in ('FAILED', 'INVALID'):
            raise SystemExit('Apple processing rejected build')
        if state == 'VALID':
            detail = request('builds/' + build['id'] + '/buildBetaDetail')['data']['attributes']
            groups = request('apps/' + app + '/betaGroups')['data']
            internal = [group for group in groups if group['attributes'].get('isInternalGroup')]
            named = [group for group in internal if group['attributes']['name'].lower() == 'internal testing']
            chosen = named if len(named) == 1 else internal
            assert len(chosen) == 1, 'Existing internal testing group missing or ambiguous'
            request('betaGroups/' + chosen[0]['id'] + '/relationships/builds', {'data':[{'type':'builds','id':build['id']}]})
            assigned = request('builds/' + build['id'] + '/betaGroups')['data']
            assert any(group['id'] == chosen[0]['id'] for group in assigned), 'Internal group assignment not confirmed'
            result = {'build_id': build['id'], 'internal_groups': [group['attributes']['name'] for group in assigned], 'build': build['attributes']['version'], 'processingState': state, 'expired': build['attributes']['expired'], 'usesNonExemptEncryption': build['attributes'].get('usesNonExemptEncryption'), 'beta': detail, 'marketingVersions': [item['attributes']['version'] for item in builds.get('included', []) if item['type'] == 'preReleaseVersions']}
            print(json.dumps(result), flush=True)
            with open('build/testflight-processing.json', 'w') as output:
                json.dump(result, output, indent=2)
            break
    time.sleep(20)
else:
    raise SystemExit('Apple processing has not completed within 20 minutes')

