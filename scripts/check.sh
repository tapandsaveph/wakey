#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc -parse-as-library -swift-version 6 Sources/Power.swift Tests/PowerChecks.swift -o .build/PowerChecks
.build/PowerChecks
./scripts/build.sh --check
/usr/bin/python3 - <<'PY'
import os, pathlib, platform, plistlib, re, subprocess
app=pathlib.Path('dist/Wakey.app')
minimum=plistlib.loads((app/'Contents/Info.plist').read_bytes())['LSMinimumSystemVersion']
for binary in ['Wakey','SleepHelper']:
    output=subprocess.check_output(['xcrun','vtool','-show-build',str(app/'Contents/MacOS'/binary)],text=True)
    versions=re.findall(r'\bminos\s+([0-9.]+)',output)
    assert versions and set(versions)=={minimum}, (binary,minimum,output)
    arches=set(subprocess.check_output(['lipo','-archs',str(app/'Contents/MacOS'/binary)],text=True).split())
    expected=set(os.environ.get('BUILD_ARCHS',platform.machine()).split())
    assert arches==expected, (binary,arches,expected)
print(f'PASS: app and helper deployment metadata match bundle minimum {minimum}')
PY
/usr/bin/python3 - <<'PYTEST'
import subprocess
result=subprocess.run(['./scripts/package-dmg.sh','--experimental'],capture_output=True,text=True)
assert result.returncode!=0 and 'Apple-issued signature' in result.stderr, (result.returncode,result.stdout,result.stderr)
print('PASS: ad-hoc check build cannot be packaged as an experimental helper release')
PYTEST
