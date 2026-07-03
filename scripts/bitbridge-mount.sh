#!/bin/bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="BitBridge"
STATE_DIR="${HOME}/Library/Application Support/${APP_NAME}"
CONFIG_FILE="${STATE_DIR}/config.env"
LOG_FILE="${STATE_DIR}/bitbridge.log"
LOCK_DIR="${STATE_DIR}/run.lock"
ANYLINUXFS="${ANYLINUXFS:-/opt/homebrew/bin/anylinuxfs}"
ASKPASS="${ASKPASS:-${STATE_DIR}/sudo-askpass-osx.sh}"
KEYCHAIN_ACCOUNT="${KEYCHAIN_ACCOUNT:-${USER:-$(id -un)}}"
KEYCHAIN_SERVICE_DEFAULT="io.github.taha-mesbahi.bitbridge.recovery-key"

mkdir -p "$STATE_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

notify_failure() {
  /usr/bin/osascript -e 'display notification "Mount failed. Open the BitBridge log for details." with title "BitBridge"' >/dev/null 2>&1 || true
}

config_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); gsub(/^"|"$/, ""); print; exit}' "$CONFIG_FILE" 2>/dev/null
}

sanitize_mount_name() {
  printf '%s' "$1" | tr -cd 'A-Za-z0-9._-'
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
set promptText to "Paste the BitLocker recovery key. BitBridge will store it in your login Keychain."
set dialogResult to display dialog promptText default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel"
text returned of dialogResult
APPLESCRIPT
}

read_recovery_key() {
  local key

  key="$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null || true)"
  if [ -n "$key" ]; then
    normalize_recovery_key "$key"
    return 0
  fi

  key="$(prompt_for_recovery_key 2>/dev/null || true)"
  key="$(normalize_recovery_key "$key")"

  if [[ ! "$key" =~ ^[0-9]{6}(-[0-9]{6}){7}$ ]]; then
    log "No valid BitLocker recovery key available."
    return 1
  fi

  if ! printf '%s\n%s\n' "$key" "$key" | security add-generic-password -U -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -l "BitBridge recovery key" -j "Used by BitBridge" -w >/dev/null 2>>"$LOG_FILE"; then
    log "Failed to store recovery key in Keychain."
    return 1
  fi

  printf '%s\n' "$key"
}

find_target_device() {
  local identifier uuid

  for identifier in $(diskutil list external 2>/dev/null | awk '/disk[0-9]+s[0-9]+$/ {print $NF}'); do
    uuid="$(diskutil info -plist "$identifier" 2>/dev/null | plutil -extract DiskUUID raw - 2>/dev/null || true)"
    if [ "$uuid" = "$TARGET_UUID" ]; then
      printf '/dev/%s\n' "$identifier"
      return 0
    fi
  done

  return 1
}

is_mounted() {
  mount | grep -F " on ${MOUNT_POINT} " >/dev/null 2>&1
}

main() {
  local mount_name device key

  if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
  fi

  TARGET_UUID="$(config_value TARGET_UUID)"
  mount_name="$(sanitize_mount_name "$(config_value MOUNT_NAME)")"
  MOUNT_POINT="$(config_value MOUNT_POINT)"
  KEYCHAIN_SERVICE="$(config_value KEYCHAIN_SERVICE)"

  [ -n "$TARGET_UUID" ] || exit 0
  [ -n "$mount_name" ] || mount_name="BitBridge-Windows"
  [ -n "$MOUNT_POINT" ] || MOUNT_POINT="/Volumes/${mount_name}"
  [ -n "$KEYCHAIN_SERVICE" ] || KEYCHAIN_SERVICE="$KEYCHAIN_SERVICE_DEFAULT"

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

  if is_mounted; then
    exit 0
  fi

  if [ ! -x "$ANYLINUXFS" ]; then
    log "anylinuxfs not found at $ANYLINUXFS."
    notify_failure
    exit 1
  fi

  device="$(find_target_device || true)"
  if [ -z "$device" ]; then
    exit 0
  fi

  key="$(read_recovery_key || true)"
  if [ -z "$key" ]; then
    log "Recovery key unavailable."
    notify_failure
    exit 1
  fi

  log "Mounting $device at $MOUNT_POINT."

  if ! SUDO_ASKPASS="$ASKPASS" sudo -A mkdir -p "$MOUNT_POINT" >>"$LOG_FILE" 2>&1; then
    log "Failed to create mount point $MOUNT_POINT."
    notify_failure
    exit 1
  fi

  if ALFS_PASSPHRASE="$key" SUDO_ASKPASS="$ASKPASS" sudo -E -A "$ANYLINUXFS" mount -o ro --ignore-permissions -t ntfs3 "$device" "$MOUNT_POINT" >>"$LOG_FILE" 2>&1; then
    log "Mounted $device at $MOUNT_POINT."
    open "$MOUNT_POINT" >/dev/null 2>&1 || true
  else
    log "Mount command failed for $device."
    notify_failure
    exit 1
  fi
}

main "$@"
