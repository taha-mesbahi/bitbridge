#!/bin/bash
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="BitBridge"
LABEL="io.github.taha-mesbahi.bitbridge.automount"
KEYCHAIN_SERVICE_PREFIX="io.github.taha-mesbahi.bitbridge.recovery-key"
KEYCHAIN_ACCOUNT="${USER:-$(id -un)}"
RESOURCE_DIR="${BITBRIDGE_RESOURCE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
ROOT_DIR="$(cd "${RESOURCE_DIR}/.." 2>/dev/null && pwd || pwd)"
INSTALL_DIR="${HOME}/Library/Application Support/${APP_NAME}"
CONFIG_FILE="${INSTALL_DIR}/config.env"
PLIST_TARGET="${HOME}/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

TARGET_UUID="${1:-}"
MOUNT_NAME_RAW="${2:-BitBridge-Windows}"
MOUNT_NAME="$(printf '%s' "$MOUNT_NAME_RAW" | tr -cd 'A-Za-z0-9._-')"
[ -n "$MOUNT_NAME" ] || MOUNT_NAME="BitBridge-Windows"
MOUNT_POINT="/Volumes/${MOUNT_NAME}"
KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE_PREFIX}.${TARGET_UUID}"

resource_path() {
  local name="$1"
  local candidate

  for candidate in \
    "${RESOURCE_DIR}/${name}" \
    "${ROOT_DIR}/scripts/${name}" \
    "${ROOT_DIR}/launchd/${name}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Missing resource: %s\n' "$name" >&2
  return 1
}

normalize_recovery_key() {
  local raw digits
  raw="$(printf '%s' "$1" | tr -d '[:space:]')"
  digits="$(printf '%s' "$raw" | tr -cd '0-9')"

  if [ "${#digits}" -eq 48 ]; then
    printf '%s\n' "$digits" | sed -E 's/(.{6})/\1-/g; s/-$//'
  else
    printf '%s\n' "$raw"
  fi
}

prompt_for_recovery_key() {
  /usr/bin/osascript <<'APPLESCRIPT'
set promptText to "Paste the BitLocker recovery key. BitBridge stores it in your login Keychain, not in the installer or LaunchAgent."
set dialogResult to display dialog promptText default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
text returned of dialogResult
APPLESCRIPT
}

if [ -z "$TARGET_UUID" ]; then
  /usr/bin/osascript -e 'display alert "BitBridge" message "No target partition UUID was provided."' >/dev/null 2>&1 || true
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  /usr/bin/osascript -e 'display alert "BitBridge" message "This preview installer is intended for Apple Silicon Macs."' >/dev/null 2>&1 || true
  exit 1
fi

if [ ! -x /opt/homebrew/bin/anylinuxfs ]; then
  /usr/bin/osascript -e 'display alert "BitBridge needs anylinuxfs" message "Install anylinuxfs for Apple Silicon first, then run BitBridge Installer again. Expected path: /opt/homebrew/bin/anylinuxfs"' >/dev/null 2>&1 || true
  exit 1
fi

recovery_key="$(normalize_recovery_key "$(prompt_for_recovery_key)")"
if [[ ! "$recovery_key" =~ ^[0-9]{6}(-[0-9]{6}){7}$ ]]; then
  /usr/bin/osascript -e 'display alert "BitBridge" message "The recovery key was empty or invalid."' >/dev/null 2>&1 || true
  exit 1
fi

mkdir -p "$INSTALL_DIR" "${HOME}/Library/LaunchAgents"
install -m 700 "$(resource_path bitbridge-mount.sh)" "${INSTALL_DIR}/bitbridge-mount.sh"
install -m 700 "$(resource_path bitbridge-unmount.sh)" "${INSTALL_DIR}/bitbridge-unmount.sh"
install -m 700 "$(resource_path sudo-askpass-osx.sh)" "${INSTALL_DIR}/sudo-askpass-osx.sh"

{
  printf 'TARGET_UUID=%s\n' "$TARGET_UUID"
  printf 'MOUNT_NAME=%s\n' "$MOUNT_NAME"
  printf 'MOUNT_POINT=%s\n' "$MOUNT_POINT"
  printf 'KEYCHAIN_SERVICE=%s\n' "$KEYCHAIN_SERVICE"
} > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

printf '%s\n%s\n' "$recovery_key" "$recovery_key" | security add-generic-password -U -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -l "BitBridge recovery key" -j "Used by BitBridge" -w >/dev/null

sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "$(resource_path io.github.taha-mesbahi.bitbridge.automount.plist.template)" > "$PLIST_TARGET"
chmod 644 "$PLIST_TARGET"

launchctl bootout "$GUI_DOMAIN" "$PLIST_TARGET" >/dev/null 2>&1 || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST_TARGET"
launchctl enable "${GUI_DOMAIN}/${LABEL}" >/dev/null 2>&1 || true
launchctl kickstart -k "${GUI_DOMAIN}/${LABEL}" >/dev/null 2>&1 || true

/usr/bin/osascript -e 'display notification "BitBridge automount is installed." with title "BitBridge"' >/dev/null 2>&1 || true
