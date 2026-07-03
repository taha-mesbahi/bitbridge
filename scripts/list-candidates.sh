#!/bin/bash
set -euo pipefail

PATH="/usr/bin:/bin:/usr/sbin:/sbin"

diskutil list external 2>/dev/null | awk '/disk[0-9]+s[0-9]+$/ {print $NF}' | while read -r identifier; do
  plist="$(diskutil info -plist "$identifier" 2>/dev/null || true)"
  [ -n "$plist" ] || continue

  uuid="$(printf '%s' "$plist" | plutil -extract DiskUUID raw - 2>/dev/null || true)"
  content="$(printf '%s' "$plist" | plutil -extract Content raw - 2>/dev/null || true)"
  size="$(printf '%s' "$plist" | plutil -extract Size raw - 2>/dev/null || true)"

  [ -n "$uuid" ] || continue

  case "$content" in
    "Microsoft Basic Data")
      if awk -v bytes="${size:-0}" 'BEGIN {exit !(bytes > 1000000000)}'; then
        size_label="$(awk -v bytes="${size:-0}" 'BEGIN {printf "%.1f GB", bytes / 1000000000}')"
        printf '%s | %s | %s | %s\n' "$identifier" "$uuid" "$content" "$size_label"
      fi
      ;;
  esac
done
