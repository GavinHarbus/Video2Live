#!/bin/bash
set -euo pipefail

# --- Config -----------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Video2Live"
PROJECT="Video2Live.xcodeproj"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_NAME="${SCHEME}.app"
DMG_NAME="${SCHEME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
EXPORT_OPTIONS="${PROJECT_DIR}/scripts/ExportOptions.plist"
ENTITLEMENTS="${PROJECT_DIR}/Video2Live/Video2Live.entitlements"
VOLUME_NAME="Video2Live"

# --- Clean -------------------------------------------------------------
echo "==> Cleaning previous build..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# --- Archive -----------------------------------------------------------
echo "==> Archiving..."
xcodebuild archive \
  -project "${PROJECT_DIR}/${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_IDENTITY="-" \
  | tail -5

echo "==> Archive complete: ${ARCHIVE_PATH}"

# --- Export ------------------------------------------------------------
echo "==> Exporting app..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  | tail -5

# Verify .app exists
if [ ! -d "${EXPORT_DIR}/${APP_NAME}" ]; then
  echo "ERROR: ${APP_NAME} not found in ${EXPORT_DIR}"
  exit 1
fi

echo "==> Export complete: ${EXPORT_DIR}/${APP_NAME}"

# --- Re-sign with entitlements -----------------------------------------
echo "==> Signing app with entitlements..."
codesign --force --deep --sign "-" \
  --entitlements "${ENTITLEMENTS}" \
  "${EXPORT_DIR}/${APP_NAME}"
echo "==> Signing complete."

# --- Create DMG --------------------------------------------------------
echo "==> Creating DMG..."

DMG_TEMP="${BUILD_DIR}/dmg-staging"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

cp -R "${EXPORT_DIR}/${APP_NAME}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${DMG_TEMP}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

rm -rf "${DMG_TEMP}"

echo ""
echo "==> Done! DMG created at:"
echo "    ${DMG_PATH}"
echo ""
echo "    Size: $(du -h "${DMG_PATH}" | cut -f1)"
