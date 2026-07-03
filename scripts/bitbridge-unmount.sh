#!/bin/bash
set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="BitBridge"
STATE_DIR="${HOME}/Library/Application Support/${APP_NAME}"
CONFIG_FILE="${STATE_DIR}/config.env"
LOG_FILE="${STATE_DIR}/bitbridge.log"
ANYLINUXFS="${ANYLINUXFS:-/opt/homebrew/bin/anylinuxfs}"
ASKPASS="${ASKPASS:-${STATE_DIR}/sudo-askpass-osx.sh}"

config_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); gsub(/^"|"$/, ""); print; exit}' "$CONFIG_FILE" 2>/dev/null
}

MOUNT_POINT="$(config_value MOUNT_POINT)"
[ -n "$MOUNT_POINT" ] || MOUNT_POINT="/Volumes/BitBridge-Windows"

if mount | grep -F " on ${MOUNT_POINT} " >/dev/null 2>&1; then
  SUDO_ASKPASS="$ASKPASS" sudo -E -A "$ANYLINUXFS" unmount "$MOUNT_POINT" >>"$LOG_FILE" 2>&1
fi
