#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_BUILD_DIR="${ROOT_DIR}/build"
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bitbridge-build.XXXXXX")"
BUILD_DIR="${STAGE_ROOT}/build"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="BitBridge Installer.app"
APP_PATH="${BUILD_DIR}/${APP_NAME}"
ICON_SOURCE="${ROOT_DIR}/assets/bitbridge-icon-source.png"
ICONSET="${BUILD_DIR}/BitBridge.iconset"
ICNS_PATH="${BUILD_DIR}/BitBridge.icns"
DMG_ROOT="${BUILD_DIR}/dmg-root"
DMG_PATH="${DIST_DIR}/BitBridge-Apple-Silicon.dmg"

trap 'rm -rf "$STAGE_ROOT"' EXIT

rm -rf "$PUBLIC_BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR" "$ICONSET"

sips -z 16 16 "$ICON_SOURCE" --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "${ICONSET}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICNS_PATH"

osacompile -o "$APP_PATH" "${ROOT_DIR}/installer/BitBridge Installer.applescript"
mkdir -p "${APP_PATH}/Contents/Resources/bitbridge"

cp "$ICNS_PATH" "${APP_PATH}/Contents/Resources/BitBridge.icns"
cp "${ROOT_DIR}/scripts/"*.sh "${APP_PATH}/Contents/Resources/bitbridge/"
cp "${ROOT_DIR}/launchd/io.github.taha-mesbahi.bitbridge.automount.plist.template" "${APP_PATH}/Contents/Resources/bitbridge/"

plutil -replace CFBundleIconFile -string BitBridge "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string io.github.taha-mesbahi.bitbridge.installer "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleName -string "BitBridge Installer" "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "BitBridge Installer" "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIconName -string BitBridge "${APP_PATH}/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "13.0" "${APP_PATH}/Contents/Info.plist"
plutil -replace NSAppleEventsUsageDescription -string "BitBridge uses AppleScript dialogs to guide setup." "${APP_PATH}/Contents/Info.plist"
plutil -replace NSSystemAdministrationUsageDescription -string "BitBridge needs administrator privileges to mount and unmount external volumes." "${APP_PATH}/Contents/Info.plist"

for privacy_key in \
  NSAppleMusicUsageDescription \
  NSCalendarsUsageDescription \
  NSCameraUsageDescription \
  NSContactsUsageDescription \
  NSHomeKitUsageDescription \
  NSMicrophoneUsageDescription \
  NSPhotoLibraryUsageDescription \
  NSRemindersUsageDescription \
  NSSiriUsageDescription; do
  plutil -remove "$privacy_key" "${APP_PATH}/Contents/Info.plist" >/dev/null 2>&1 || true
done

xattr -cr "$APP_PATH" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP_PATH" >/dev/null

mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/"
cp "${ROOT_DIR}/README.md" "$DMG_ROOT/README.md"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create -volname "BitBridge" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null
mkdir -p "$PUBLIC_BUILD_DIR"
ditto --noextattr --noqtn "$APP_PATH" "${PUBLIC_BUILD_DIR}/${APP_NAME}"

printf '%s\n' "$DMG_PATH"
