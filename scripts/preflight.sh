#!/bin/bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

failures=0
warnings=0

ok() {
  printf 'OK: %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1"
}

require_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name is available."
  else
    fail "$command_name is missing."
  fi
}

if [ "$(uname -m)" = "arm64" ]; then
  ok "Apple Silicon Mac detected."
else
  fail "BitBridge preview builds target Apple Silicon Macs."
fi

macos_major="$(sw_vers -productVersion 2>/dev/null | awk -F. '{print $1}')"
if [ -n "$macos_major" ] && [ "$macos_major" -ge 13 ] 2>/dev/null; then
  ok "macOS $(sw_vers -productVersion) detected."
else
  warn "macOS 13 Ventura or newer is recommended."
fi

for command_name in diskutil hdiutil launchctl osascript plutil security sudo awk sed grep mount open; do
  require_command "$command_name"
done

if [ -x /opt/homebrew/bin/brew ]; then
  ok "Homebrew is available at /opt/homebrew/bin/brew."
else
  warn "Homebrew was not found at /opt/homebrew/bin/brew. Install Homebrew if you need to install anylinuxfs."
fi

if [ -x /opt/homebrew/bin/anylinuxfs ]; then
  ok "anylinuxfs is available at /opt/homebrew/bin/anylinuxfs."
else
  fail "anylinuxfs is missing. Install it before running BitBridge."
fi

if [ -d /Library/Filesystems/macfuse.fs ]; then
  ok "macFUSE filesystem bundle is installed."
else
  warn "macFUSE was not found. Some anylinuxfs setups may require it."
fi

if security default-keychain >/dev/null 2>&1; then
  ok "macOS Keychain is available."
else
  fail "macOS Keychain is not available."
fi

external_count="$(diskutil list external 2>/dev/null | awk '/disk[0-9]+s[0-9]+$/ {count++} END {print count + 0}')"
if [ "$external_count" -gt 0 ]; then
  ok "External disk partitions are visible to diskutil."
else
  warn "No external disk partition is currently visible. Plug in the BitLocker SSD before installation."
fi

printf '\nSummary: %s failure(s), %s warning(s).\n' "$failures" "$warnings"

if [ "$failures" -gt 0 ]; then
  exit 1
fi

exit 0
