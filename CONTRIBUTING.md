# Contributing

Thanks for helping BitBridge become useful for more Mac users.

## Local Development

Build the installer and DMG:

```sh
./tools/build.sh
```

Validate shell scripts:

```sh
bash -n scripts/*.sh tools/*.sh
plutil -lint launchd/*.plist.template
```

## Project Goals

- Keep secrets out of files and command-line arguments.
- Default to read-only mounts.
- Prefer clear shell scripts over opaque binaries.
- Make every destructive or write-capable behavior explicit.
- Keep Apple Silicon support first-class.

## Pull Request Checklist

- Explain the user-facing change.
- Include manual test steps.
- Do not commit recovery keys, UUIDs from private drives, logs, or screenshots containing personal paths.
- Keep generated release artifacts out of git unless a maintainer asks for them.

## Areas That Need Help

- Native SwiftUI installer.
- Notarized release automation.
- Better dependency bootstrap for first-time users.
- More drive/partition detection edge cases.
- Documentation in more languages.
