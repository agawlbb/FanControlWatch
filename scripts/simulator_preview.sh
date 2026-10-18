#!/bin/bash
set -euo pipefail
xcrun simctl list devices available --json > build/simulators.json
udid=$(python3 - <<'PY'
import json
with open('build/simulators.json') as f: devices=json.load(f)['devices']
for runtime, entries in devices.items():
    if 'watchOS' in runtime and entries:
        print(entries[0]['udid']); break
else: raise SystemExit('No watchOS simulator runtime installed')
PY
)
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" build/Build/Products/Debug-watchsimulator/FanControlWatch.app
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp
sleep 3
xcrun simctl io "$udid" screenshot build/watch-first-launch.png
xcrun simctl shutdown "$udid"
