# BitBridge Requirements

BitBridge is designed for Apple Silicon Macs that need read-only access to a BitLocker-encrypted Windows SSD or external NVMe drive.

## Required

- Apple Silicon Mac: M1, M2, M3, M4, or newer.
- macOS 13 Ventura or newer recommended.
- A valid BitLocker recovery key.
- `anylinuxfs` installed at `/opt/homebrew/bin/anylinuxfs`.
- macOS command-line tools available by default:
  - `diskutil`
  - `hdiutil`
  - `launchctl`
  - `mount`
  - `open`
  - `osascript`
  - `plutil`
  - `security`
  - `sudo`

## Optional

- macFUSE, depending on the user's anylinuxfs setup.
- Homebrew, if the user still needs to install anylinuxfs.

## Verify

From the repository root:

```sh
./scripts/preflight.sh
```
