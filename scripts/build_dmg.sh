#!/bin/bash
set -euo pipefail

# Lyric Fever DMG Build & Packaging Script
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
APP_NAME="Lyric Fever"
APP_BUNDLE="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="LyricFever"
FINAL_DMG="${BUILD_DIR}/${DMG_NAME}.dmg"
STAGING_DIR="${BUILD_DIR}/dmg_staging"
TMP_DMG="${BUILD_DIR}/${DMG_NAME}_temp.dmg"
VOL_NAME="Lyric Fever"

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
ARCH="${ARCH:-$(uname -m)}"

echo "==> 1. Building ${APP_NAME} in Release configuration (arch: ${ARCH})..."
DEVELOPER_DIR="${DEVELOPER_DIR}" xcodebuild \
    -scheme "SpotifyLyricsInMenubar" \
    -destination "platform=macOS,arch=${ARCH}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    -skipMacroValidation \
    build

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: App bundle not found at ${APP_BUNDLE}"
    exit 1
fi

echo "==> 2. Signing App Bundle ad-hoc..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> 3. Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}" "${TMP_DMG}" "${FINAL_DMG}"
mkdir -p "${STAGING_DIR}/.background"

# Copy App
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Create /Applications Symlink
ln -s /Applications "${STAGING_DIR}/Applications"

# Generate @2x Retina Background Image
echo "==> 4. Generating fluid ambient background artwork..."
DEVELOPER_DIR="${DEVELOPER_DIR}" xcrun swiftc \
    "${PROJECT_DIR}/scripts/create_dmg_background.swift" \
    -o "${BUILD_DIR}/create_dmg_bg"
"${BUILD_DIR}/create_dmg_bg" "${STAGING_DIR}/.background"

# Copy Volume Icon
if [ -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" ]; then
    cp "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
fi

echo "==> 5. Creating temporary read-write disk image..."
hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 300m \
    "${TMP_DMG}"

echo "==> 6. Mounting temporary disk image..."
MOUNT_DIR="/Volumes/${VOL_NAME}"
if [ -d "${MOUNT_DIR}" ]; then
    hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || true
fi

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}" | awk '/\/Volumes\// {print $1; exit}')
if [ -z "${DEVICE}" ]; then
    DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}" | head -n 1 | awk '{print $1}')
fi
sleep 2

echo "==> 7. Applying Finder layout & aesthetic styling..."
osascript <<EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        
        -- Set window bounds (left, top, right, bottom) -> 660x440
        set bounds of container window to {120, 120, 780, 560}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        set text size of theViewOptions to 13
        set label position of theViewOptions to bottom
        
        -- Set custom background image
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position icons precisely over the background docks
        set position of item "${APP_NAME}.app" of container window to {180, 220}
        set position of item "Applications" of container window to {480, 220}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Set custom volume icon flag if icon exists
if [ -f "${MOUNT_DIR}/.VolumeIcon.icns" ]; then
    SETFILE_BIN="$(DEVELOPER_DIR="${DEVELOPER_DIR}" xcrun -find SetFile 2>/dev/null || which SetFile 2>/dev/null || true)"
    if [ -n "${SETFILE_BIN}" ]; then
        "${SETFILE_BIN}" -a C "${MOUNT_DIR}" || true
    fi
fi

# Ensure disk synchronizes
sync
sleep 2

echo "==> 8. Unmounting temporary disk image..."
hdiutil detach "${DEVICE}" -force || hdiutil detach "${MOUNT_DIR}" -force || true
rm -rf "${STAGING_DIR}"

echo "==> 9. Converting to compressed read-only DMG..."
hdiutil convert "${TMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${FINAL_DMG}"

rm -f "${TMP_DMG}"

echo "==> 10. DMG Generation Complete!"
ls -lh "${FINAL_DMG}"
shasum -a 256 "${FINAL_DMG}"
