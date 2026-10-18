#!/bin/bash
set -euo pipefail
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}" "${IOS_TEAM_ID:?}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,8}$ ]]
[[ "$IOS_TEAM_ID" == FKR675M7PM ]]
auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
swift test
xcodegen generate
mkdir -p build
xcodebuild -project FanControlWatch.xcodeproj -scheme FanControl -configuration Release \
  -jobs 2 -destination 'generic/platform=iOS' -archivePath build/FanControlWatch.xcarchive \
  DEVELOPMENT_TEAM="$IOS_TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -allowProvisioningUpdates "${auth[@]}" archive
python3 - <<'PY'
import os, plistlib
from pathlib import Path
archive=Path('build/FanControlWatch.xcarchive/Products/Applications')
apps=list(archive.glob('*.app'))
assert len(apps)==1, 'Missing distribution container'
watch=list((apps[0]/'Watch').glob('*.app'))
assert len(watch)==1, 'Missing embedded watch app'
for bundle, expected in [(apps[0],'dev.fancontrol.watch'),(watch[0],'dev.fancontrol.watch.watchkitapp')]:
    info=plistlib.loads((bundle/'Info.plist').read_bytes())
    assert info['CFBundleIdentifier']==expected
    assert info['CFBundleVersion']==os.environ.get('BUILD_NUMBER','1')
assert plistlib.loads((watch[0]/'Info.plist').read_bytes())['WKWatchOnly']
Path('build/ExportOptions.plist').write_bytes(plistlib.dumps({
    'method':'app-store-connect','teamID':os.environ['IOS_TEAM_ID'],
    'signingStyle':'automatic','manageAppVersionAndBuildNumber':False,'destination':'export'}))
PY

xcodebuild -exportArchive -archivePath build/FanControlWatch.xcarchive -exportPath build/signed \
  -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates "${auth[@]}"
# Distribution signing happens at export; avoid allocating a disposable development certificate.
python3 - <<'PY'
import plistlib, subprocess, tempfile, zipfile
from pathlib import Path
packages=list(Path('build/signed').glob('*.ipa'))
assert len(packages)==1, 'Expected one signed package'
with tempfile.TemporaryDirectory() as temp:
    with zipfile.ZipFile(packages[0]) as archive: archive.extractall(temp)
    app=next((Path(temp)/'Payload').glob('*.app'))
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    for bundle in [app,*list((app/'Watch').glob('*.app'))]:
        info=plistlib.loads((bundle/'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] in ['dev.fancontrol.watch','dev.fancontrol.watch.watchkitapp']
        assert (bundle/'embedded.mobileprovision').is_file(), 'Distribution profile missing'
PY
if [[ "${UPLOAD:-false}" == true ]]; then
  python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('build/ExportOptions.plist'); options=plistlib.loads(p.read_bytes())
options['destination']='upload'; Path('build/UploadOptions.plist').write_bytes(plistlib.dumps(options))
PY
  xcodebuild -exportArchive -archivePath build/FanControlWatch.xcarchive -exportPath build/upload \
    -exportOptionsPlist build/UploadOptions.plist -allowProvisioningUpdates "${auth[@]}"
fi

