#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Jisticle"
SCHEME_NAME="Jisticle"

# -- Setup --
VERSION=${1:-""}
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
fi

echo "Building ${APP_NAME} version ${VERSION}..."

# Resolve dependencies
echo "Resolving Swift Package dependencies..."
swift package resolve

# Generate Xcode Project
echo "Generating Xcode project with XcodeGen..."
rm -rf "${APP_NAME}.xcodeproj"
xcodegen generate

# Archive the project
echo "Archiving project..."
rm -rf .build-archive
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -destination 'platform=macOS' \
    -archivePath ".build-archive/${APP_NAME}.xcarchive" \
    MARKETING_VERSION="${VERSION}" \
    CURRENT_PROJECT_VERSION="${VERSION}"

# Extract .app from archive
echo "Extracting .app from archive..."
rm -rf .build-export
mkdir -p .build-export
cp -R ".build-archive/${APP_NAME}.xcarchive/Products/Applications/${APP_NAME}.app" ".build-export/"

APP_PATH=".build-export/${APP_NAME}.app"

# Ad-hoc signing (without --deep to preserve entitlements)
echo "Ad-hoc signing nested bundles..."
find "${APP_PATH}/Contents" \
    \( -name '*.framework' -o -name '*.dylib' -o -name '*.bundle' \) -print0 2>/dev/null | \
xargs -0 -I {} codesign --force -s - {} || true
echo "Ad-hoc signing main app with entitlements..."
codesign --force -s - --entitlements Sources/Jisticle/Jisticle.entitlements "${APP_PATH}"

# Create distribution DMG
echo "Creating DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_PATH}" -ov -format UDZO "${APP_NAME}-macOS.dmg"

# Mount DMG and copy .app from mounted volume (ensures it's the exact version in the DMG)
echo "Mounting DMG to copy fresh .app..."
MOUNT_OUTPUT=$(hdiutil attach "${APP_NAME}-macOS.dmg" -nobrowse)
MOUNT_POINT=$(echo "${MOUNT_OUTPUT}" | grep -o '/Volumes/.*' | tail -1)

# Open DMG in Finder
echo "Opening DMG..."
open "${APP_NAME}-macOS.dmg"

echo "Success! Created ${APP_NAME}-macOS.dmg and ${APP_NAME}.app"
