#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PREVIEW=0
EXPERIMENTAL=0
if [[ "${1:-}" == '--preview' && $# == 1 ]]; then
  PREVIEW=1
elif [[ "${1:-}" == '--experimental' && $# == 1 ]]; then
  EXPERIMENTAL=1
elif [[ $# != 0 ]]; then
  echo 'Usage: ./scripts/package-dmg.sh [--preview|--experimental]' >&2; exit 2
fi
APP="$PWD/dist/Wakey.app"
if [[ ! -d "$APP" ]]; then echo 'Build a signed app with ./scripts/build.sh first.' >&2; exit 1; fi
STAGING=$(mktemp -d /private/tmp/wakey-dmg.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Wakey.app"
xattr -cr "$STAGING/Wakey.app"
APP="$STAGING/Wakey.app"
codesign --verify --deep --strict "$APP"
SIGNATURE=$(codesign -dv --verbose=2 "$APP" 2>&1)
if [[ "$PREVIEW" == 0 && "$EXPERIMENTAL" == 0 ]] && ! printf '%s' "$SIGNATURE" | grep -q '^Authority=Developer ID Application:'; then
  echo 'Notarized-release packaging requires a Developer ID Application-signed app.' >&2
  echo 'For a local, non-distribution preview: ./scripts/package-dmg.sh --preview' >&2
  exit 1
fi
if [[ "$EXPERIMENTAL" == 1 ]]; then
  if ! printf '%s' "$SIGNATURE" | grep -Eq '^Authority=(Apple Development:|Developer ID Application:)'; then
    echo 'Experimental builds still require an Apple-issued signature; ad-hoc builds cannot use this helper.' >&2; exit 1
  fi
  codesign --verify --test-requirement '=anchor apple generic and identifier "app.wakey.mac"' "$APP"
  codesign --verify --test-requirement '=anchor apple generic and identifier "app.wakey.mac.helper.distribution"' "$APP/Contents/MacOS/SleepHelper"
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/Wakey" | tr ' ' '-')
if [[ "$ARCH" == arm64-x86_64 || "$ARCH" == x86_64-arm64 ]]; then ARCH=universal; fi
if [[ ! "$VERSION" =~ ^[0-9A-Za-z.-]+$ ]] || [[ ! "$ARCH" =~ ^[0-9A-Za-z_-]+$ ]]; then
  echo 'Invalid version or architecture for package name.' >&2; exit 1
fi
if [[ "$PREVIEW" == 1 ]]; then
  OUTPUT="$PWD/dist/Wakey-$VERSION-$ARCH-development.dmg"
  printf '%s\n' 'DEVELOPMENT PREVIEW — not a notarized public installer.' 'Drag Wakey.app to Applications. Open it and approve its helper in System Settings.' 'This package requires no Xcode to run, but its development signature is not intended for distribution to other Macs.' > "$STAGING/DEVELOPMENT.txt"
  NOTICE="$STAGING/DEVELOPMENT.txt"
elif [[ "$EXPERIMENTAL" == 1 ]]; then
  OUTPUT="$PWD/dist/Wakey-$VERSION-$ARCH-experimental.dmg"
  printf '%s\n' 'WAKEY — EXPERIMENTAL, NOT NOTARIZED' 'Drag Wakey.app to Applications. macOS app approval and a one-time background-helper approval may be needed.' 'Same system sleep override, animations and one-click controls as the source build.' 'Older macOS versions, Intel execution and installation on a fresh Mac are not yet runtime-verified.' > "$STAGING/EXPERIMENTAL.txt"
  NOTICE="$STAGING/EXPERIMENTAL.txt"
else
  if [[ ! "${SIGNING_IDENTITY_HASH:-}" =~ ^[A-F0-9]{40}$ ]]; then
    echo 'Set SIGNING_IDENTITY_HASH to the Developer ID certificate used to build this app.' >&2; exit 1
  fi
  codesign --verify --test-requirement "=anchor apple generic and certificate leaf = H\"$SIGNING_IDENTITY_HASH\" and identifier \"app.wakey.mac\"" "$APP"
  OUTPUT="$PWD/dist/Wakey-$VERSION-$ARCH.dmg"
  NOTICE="$STAGING/INSTALL.txt"
  printf '%s\n' 'Drag Wakey to Applications, then open it and approve its helper in System Settings.' > "$NOTICE"
fi
if [[ -e "$OUTPUT" ]]; then echo "Package already exists: $OUTPUT" >&2; exit 1; fi
DMGBUILD="$PWD/.build/dmg-tools/bin/dmgbuild"
if [[ ! -x "$DMGBUILD" ]]; then
  echo 'Install packaging tools with Python 3.10+: python3 -m venv .build/dmg-tools && .build/dmg-tools/bin/pip install -r packaging/requirements.txt' >&2
  exit 1
fi
"$DMGBUILD" -s packaging/settings.py -D "root=$PWD/packaging" -D "app=$APP" -D "notice=$NOTICE" Wakey "$OUTPUT"
if [[ "$PREVIEW" == 0 && "$EXPERIMENTAL" == 0 ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY_HASH" "$OUTPUT"
fi
hdiutil verify "$OUTPUT" >/dev/null
echo "Created: $OUTPUT"
if [[ "$PREVIEW" == 0 && "$EXPERIMENTAL" == 0 ]]; then
  echo 'Notarize and staple this DMG before publishing it. See docs/DISTRIBUTION.md.'
fi
