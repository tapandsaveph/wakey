# Security

Wakey changes a system-wide power setting, so it uses a separately approved root helper rather than password storage or passwordless sudo.

## Boundaries

- The public XPC interface accepts a Boolean, not a command, file path, or arbitrary arguments.
- The helper calls only `/usr/bin/pmset -a disablesleep 0|1`.
- App and helper enforce the exact signing certificate and expected executable identifier on XPC connections.
- The helper checks the active console user when accepting a connection and again for each operation.
- Requests are serialized. Operation results go to macOS unified logging.
- Root startup, system approval, validation, and error handling are retained.

Sleep prevention persists after quitting the app, disabling the helper, or rebooting. Turn it off before uninstalling. Wakey does not promise to keep a closed laptop awake in every hardware/power configuration. Keep ventilation clear; test the configuration you intend to use.

## Reporting

Use GitHub’s private vulnerability reporting if it is available on this repository. Otherwise, open a minimal issue asking for a private reporting channel without publishing exploit steps, credentials, or personal data.

This initial project has not had an independent security audit. Compile and automated checks do not substitute for privileged-helper testing on a real Mac.
