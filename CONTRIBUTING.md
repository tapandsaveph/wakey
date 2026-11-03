# Building Wakey

Keep the workflow small: one click changes sleep prevention, the verified system state selects the animation, and right-click exposes Quit.

## Requirements

- App runtime target: macOS 13 Ventura or later. Older-OS and Intel runtime behavior remain unverified.
- Build computer: an OS supported by full Xcode 26+, with Swift 6.2+ and its macOS SDK. A newer SDK can compile an app targeting an older OS.
- An Apple Development or Developer ID Application signing identity for a working helper.

There are no third-party runtime packages. The shell build uses Swift, code signing, Python 3 supplied with Xcode, and standard macOS tools.

## Signing

`./scripts/build.sh` selects an available Apple signing identity and embeds its certificate hash into both executables. Each XPC endpoint pins that certificate and the peer identifier. The hash is generated into ignored `.build/BuildIdentity.swift`; no developer-specific identity is committed.

To choose an identity explicitly:

```bash
security find-identity -v -p codesigning
SIGNING_IDENTITY_HASH=YOUR_40_CHARACTER_CERTIFICATE_HASH ./scripts/build.sh
```

Never commit certificates, private keys, provisioning files, or a generated signing configuration. A Development signature is for your local build; it is not a notarized public installer.

Output: `dist/Wakey.app` and `dist/Wakey.zip`. The target version is read from `Resources/Info.plist` so the bundle and executables share one minimum-version setting. Copy the app to `/Applications` before first launch so macOS can locate its bundled helper. Avoid rebuilding or replacing an approved helper while it is running; unregister the old helper before an update, replace the app, then approve again if macOS asks. Changing the signing identity may require renewed approval.

## Check without a certificate

```bash
./scripts/check.sh
```

This creates an ad-hoc check build with a deliberately unusable helper identity. It verifies compilation, parser failure cases, animation resource loading, routing for initial/unchanged/changed state, and code signatures. Do not install that build for normal use.

## Source layout

| Location | Responsibility |
| :-- | :-- |
| `Sources/Wakey.swift` | Menu-bar interaction, registration, authenticated XPC requests |
| `Sources/SleepHelper.swift` | Restricted root operation and audit logging |
| `Sources/Power.swift` | System-state parsing and read-only process execution |
| `Sources/CreatureAnimator.swift` | Confirmed-state animation playback |
| `Resources/Creature/` | Four native PNG sequences and their manifest |
| `scripts/` | Local build and checks |

## Changes

Preserve the single source of truth in `pmset`. Do not replace verified state with a saved flag or animate success before the command has been checked. Keep helper requests Boolean-only, preserve caller verification, and test errors as well as the happy path.

For UI changes, check the actual menu bar at normal size, both idle poses, intermediate transitions, and Reduce Motion. Document any physical-device checks you did not perform.

## DMG packaging

See [distribution](docs/DISTRIBUTION.md) for local previews and the Developer ID/notarization steps required before a public download. Users of a future signed release will not need Xcode.
