# Security Policy

## Supported Versions

BitBridge is currently pre-1.0. Security fixes should target the latest `main` branch.

## Sensitive Data

BitBridge should never store a BitLocker recovery key in:

- shell scripts
- LaunchAgent plists
- README examples
- logs
- command-line arguments

Recovery keys belong in the macOS login Keychain.

## Reporting a Vulnerability

Open a private security advisory on GitHub if the repository has advisories enabled. If not, open an issue with a minimal description and avoid posting secrets, recovery keys, personal disk UUIDs, or private logs.

## Design Principles

- Mount read-only by default.
- Ask for administrator privileges only when mounting or unmounting.
- Store only non-secret configuration on disk.
- Keep logs useful but non-sensitive.
