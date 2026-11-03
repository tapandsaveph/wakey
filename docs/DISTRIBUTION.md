# Installing without Xcode

A compiled Wakey app does not need Xcode on the user's Mac. Xcode is a build-time requirement. A DMG is a container for the app and an Applications shortcut; users drag the app to Applications, open it, and approve the helper once.

## Current status

- Runtime deployment target: macOS 13 Ventura+.
- App and helper compile for both Apple Silicon and Intel at that target.
- Older-OS and Intel runtime behavior still need real-device verification.
- Experimental, unnotarized DMGs can be published for testing without requiring users to install Xcode.
- A public, notarized DMG is not yet available. The current development setup has an Apple Development identity, not a Developer ID Application distribution identity.

Keep local `--preview` packages separate from explicitly labeled `--experimental` test releases. A DMG alone does not solve signing or Gatekeeper acceptance. Development signing is not a substitute for Developer ID distribution; fresh-Mac acceptance remains unverified.

## Packaging tools (maintainers only)

Use Python 3.10+ to install the pinned DMG-layout tools once:

```bash
python3 -m venv .build/dmg-tools
.build/dmg-tools/bin/pip install -r packaging/requirements.txt
```

The DMG opens a fixed icon view with Wakey on the left, Applications on the right, and an embedded Retina background. An **Open Privacy & Security** internet-location shortcut is hidden from the installer’s main view (Command–Shift–. reveals it). It opens the settings page after a blocked launch; users still approve Wakey manually. End users need neither Python nor these tools. Test this shortcut on each supported macOS version; opening the page does not guarantee that macOS offers Open Anyway.

## Local preview

```bash
./scripts/build.sh
./scripts/package-dmg.sh --preview
```

The architecture-labeled output in `dist/` contains Wakey.app, an Applications shortcut, and a development notice. It is not notarized. Packaging verifies the app signature and DMG integrity. It does not change system security settings, approve the helper, or install anything.

## Experimental test release

```bash
BUILD_ARCHS="arm64 x86_64" ./scripts/build.sh
./scripts/package-dmg.sh --experimental
```

This retains the Apple-issued development signature and the exact app/helper certificate checks. Ad-hoc check builds are rejected. Publish only as a GitHub prerelease, with a SHA-256 checksum, the signing-certificate fingerprint, installation instructions, and explicit limits. Do not present it as notarized, production-validated, or verified on a fresh Mac. See [installation](INSTALL.md).

## Notarized public release

The maintainer needs Apple Developer Program access to create a **Developer ID Application** certificate and authenticate to Apple's notary service. End users do not need a membership, certificate, or Xcode.

1. Create/install the Developer ID Application signing identity using Apple's developer tools. Do not commit or upload its private key to this repository.
2. Build and package using its certificate hash:

   ```bash
   SIGNING_IDENTITY_HASH=YOUR_DEVELOPER_ID_CERTIFICATE_HASH ./scripts/build.sh
   SIGNING_IDENTITY_HASH=YOUR_DEVELOPER_ID_CERTIFICATE_HASH ./scripts/package-dmg.sh
   ```

3. Submit the resulting DMG with an already-configured notarytool Keychain profile:

   ```bash
   xcrun notarytool submit dist/Wakey-0.2.1-arm64.dmg \
     --keychain-profile YOUR_NOTARY_PROFILE --wait
   ```

4. Only after Apple reports **Accepted**, staple and validate the ticket:

   ```bash
   xcrun stapler staple dist/Wakey-0.2.1-arm64.dmg
   xcrun stapler validate dist/Wakey-0.2.1-arm64.dmg
   ```

5. Test a browser-downloaded copy on a separate Mac: drag-to-Applications, first launch, helper approval, both toggle directions, error handling, and removal. Include the oldest supported OS before calling that OS runtime-tested. Publish the verified artifact and its checksum as a GitHub release asset.

The filenames above illustrate the current version and Apple Silicon build. Use the actual version/architecture printed by the packaging script. The default build uses the build machine's architecture. Set `BUILD_ARCHS="arm64 x86_64"` for a universal app/helper; both architectures are signed together. Intel execution still needs separate hardware testing.

No notarization credentials are read or configured by the packaging script. It never submits to Apple or publishes a release automatically.

Apple references: [Developer ID](https://developer.apple.com/developer-id/), [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Mac distribution](https://developer.apple.com/macos/distribution).
