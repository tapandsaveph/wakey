# Installing without Xcode

A compiled Wakey app does not need Xcode on the user's Mac. Xcode is a build-time requirement. A DMG is a container for the app and an Applications shortcut; users drag the app to Applications, open it, and approve the helper once.

## Current status

- Runtime deployment target: macOS 13 Ventura+.
- App and helper compile for both Apple Silicon and Intel at that target.
- Older-OS and Intel runtime behavior still need real-device verification.
- A local development DMG can be created now.
- A public, notarized DMG is not yet available. The current development setup has an Apple Development identity, not a Developer ID Application distribution identity.

Do not upload a development preview as an installer for other users. A DMG alone does not solve signing or Gatekeeper acceptance.

## Local preview

```bash
./scripts/build.sh
./scripts/package-dmg.sh --preview
```

The architecture-labeled output in `dist/` contains Wakey.app, an Applications shortcut, and a development notice. It is not notarized. Packaging verifies the app signature and DMG integrity. It does not change system security settings, approve the helper, or install anything.

## Public release

The maintainer needs Apple Developer Program access to create a **Developer ID Application** certificate and authenticate to Apple's notary service. End users do not need a membership, certificate, or Xcode.

1. Create/install the Developer ID Application signing identity using Apple's developer tools. Do not commit or upload its private key to this repository.
2. Build and package using its certificate hash:

   ```bash
   SIGNING_IDENTITY_HASH=YOUR_DEVELOPER_ID_CERTIFICATE_HASH ./scripts/build.sh
   SIGNING_IDENTITY_HASH=YOUR_DEVELOPER_ID_CERTIFICATE_HASH ./scripts/package-dmg.sh
   ```

3. Submit the resulting DMG with an already-configured notarytool Keychain profile:

   ```bash
   xcrun notarytool submit dist/Wakey-0.1.0-arm64.dmg \
     --keychain-profile YOUR_NOTARY_PROFILE --wait
   ```

4. Only after Apple reports **Accepted**, staple and validate the ticket:

   ```bash
   xcrun stapler staple dist/Wakey-0.1.0-arm64.dmg
   xcrun stapler validate dist/Wakey-0.1.0-arm64.dmg
   ```

5. Test a browser-downloaded copy on a separate Mac: drag-to-Applications, first launch, helper approval, both toggle directions, error handling, and removal. Include the oldest supported OS before calling that OS runtime-tested. Publish the verified artifact and its checksum as a GitHub release asset.

The filenames above illustrate the current version and Apple Silicon build. Use the actual version/architecture printed by the packaging script. Intel builds must be built and checked separately; the current build script produces the build machine's architecture, not a universal binary.

No notarization credentials are read or configured by the packaging script. It never submits to Apple or publishes a release automatically.

Apple references: [Developer ID](https://developer.apple.com/developer-id/), [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Mac distribution](https://developer.apple.com/macos/distribution).
