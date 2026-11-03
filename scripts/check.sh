#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc -parse-as-library -swift-version 6 Sources/Power.swift Tests/PowerChecks.swift -o .build/PowerChecks
.build/PowerChecks
./scripts/build.sh --check
/usr/bin/python3 - <<'PY'
import pathlib, plistlib, re, subprocess
app=pathlib.Path('dist/Wakey.app')
minimum=plistlib.loads((app/'Contents/Info.plist').read_bytes())['LSMinimumSystemVersion']
for binary in ['Wakey','SleepHelper']:
    output=subprocess.check_output(['xcrun','vtool','-show-build',str(app/'Contents/MacOS'/binary)],text=True)
    match=re.search(r'\bminos\s+([0-9.]+)',output)
    assert match and match.group(1)==minimum, (binary,minimum,output)
print(f'PASS: app and helper deployment metadata match bundle minimum {minimum}')
PY
