#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then CHECK_ONLY=1; fi
if [[ $# -gt 0 && "${1:-}" != "--check" ]]; then
  echo 'Usage: ./scripts/build.sh [--check]' >&2; exit 2
fi
if [[ "$(uname -s)" != Darwin ]]; then echo 'Wakey builds on macOS only.' >&2; exit 1; fi
xcrun --find swiftc >/dev/null
BUILD="$ROOT/.build"
mkdir -p "$BUILD"
if [[ "$CHECK_ONLY" == 1 ]]; then
  IDENTITY='-'
  CERTIFICATE='0000000000000000000000000000000000000000'
else
  IDENTITIES=$(security find-identity -v -p codesigning)
  if [[ -n "${SIGNING_IDENTITY_HASH:-}" ]]; then
    CERTIFICATE="$SIGNING_IDENTITY_HASH"
  else
    CERTIFICATE=$(printf '%s\n' "$IDENTITIES" | sed -nE 's/^[[:space:]]*[0-9]+\) ([A-F0-9]{40}) "Apple (Development|Distribution|Developer ID Application).*$/\1/p' | head -n 1)
    # Developer ID identities use a different display-name prefix.
    if [[ -z "$CERTIFICATE" ]]; then
      CERTIFICATE=$(printf '%s\n' "$IDENTITIES" | sed -nE 's/^[[:space:]]*[0-9]+\) ([A-F0-9]{40}) "Developer ID Application:.*$/\1/p' | head -n 1)
    fi
  fi
  if [[ ! "$CERTIFICATE" =~ ^[A-F0-9]{40}$ ]] || ! printf '%s' "$IDENTITIES" | grep -Fq "$CERTIFICATE"; then
    echo 'No usable Apple signing identity. Add an Apple Development certificate in Xcode → Settings → Accounts → Manage Certificates.' >&2
    echo 'For a particular identity: SIGNING_IDENTITY_HASH=<40-character certificate hash> ./scripts/build.sh' >&2
    exit 1
  fi
  IDENTITY="$CERTIFICATE"
fi
printf 'enum BuildIdentity { static let certificate = "%s" }\n' "$CERTIFICATE" > "$BUILD/BuildIdentity.swift"
STAGING=$(mktemp -d /private/tmp/wakey-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Wakey.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Creature" "$APP/Contents/Library/LaunchDaemons"
TARGET="$(uname -m)-apple-macosx26.0"
xcrun swiftc -parse-as-library -swift-version 6 -O -target "$TARGET" "$BUILD/BuildIdentity.swift" Sources/HelperProtocol.swift Sources/SleepHelper.swift -o "$APP/Contents/MacOS/SleepHelper"
xcrun swiftc -parse-as-library -swift-version 6 -O -target "$TARGET" "$BUILD/BuildIdentity.swift" Sources/HelperProtocol.swift Sources/Power.swift Sources/CreatureAnimator.swift Sources/Wakey.swift -o "$APP/Contents/MacOS/Wakey"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/app.wakey.mac.helper.plist "$APP/Contents/Library/LaunchDaemons/"
# Copy only manifest-owned assets; synced folders can contain conflict duplicates.
/usr/bin/python3 - "$ROOT" "$APP" <<'PY'
import json, pathlib, shutil, sys
root,app=map(pathlib.Path,sys.argv[1:])
source=root/'Resources/Creature';target=app/'Contents/Resources/Creature'
manifest=json.loads((source/'manifest.json').read_text())
for key in ['awake','sleep','wake','settle']:
    spec=manifest['sequences'][key]
    assert spec['frameCount']>0 and 0<spec['fps']<=60
    (target/key).mkdir()
    for i in range(spec['frameCount']):
        name=f'{i:03d}.png';shutil.copyfile(source/key/name,target/key/name)
shutil.copyfile(source/'manifest.json',target/'manifest.json')
PY
if [[ -f Resources/Wakey.icns ]]; then cp Resources/Wakey.icns "$APP/Contents/Resources/"; fi
xattr -cr "$APP"
codesign --force --options runtime --sign "$IDENTITY" --identifier app.wakey.mac.helper "$APP/Contents/MacOS/SleepHelper"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/Wakey" --check-animation-assets
mkdir -p dist
ditto "$APP" dist/Wakey.app
xattr -cr dist/Wakey.app
if [[ "$CHECK_ONLY" == 1 ]]; then
  echo 'Check build passed. This ad-hoc build cannot register the privileged helper.'
else
  codesign --verify --test-requirement "=anchor apple generic and certificate leaf = H\"$CERTIFICATE\" and identifier \"app.wakey.mac\"" "$APP"
  codesign --verify --test-requirement "=anchor apple generic and certificate leaf = H\"$CERTIFICATE\" and identifier \"app.wakey.mac.helper\"" "$APP/Contents/MacOS/SleepHelper"
  ditto -c -k --norsrc --keepParent "$APP" dist/Wakey.zip
  echo 'Built dist/Wakey.app. Copy it to /Applications before launching.'
fi
