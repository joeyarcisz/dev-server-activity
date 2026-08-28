#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Config/app.env
source "$ROOT_DIR/Config/app.env"

CONFIGURATION="${CONFIGURATION:-debug}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-$ROOT_DIR/Config/DevServerActivity.entitlements}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SWIFT_SCRATCH_PATH="${SWIFT_SCRATCH_PATH:-}"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"
PRIVACY_MANIFEST="$ROOT_DIR/Config/PrivacyInfo.xcprivacy"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "CONFIGURATION must be debug or release" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"
SWIFT_BUILD_ARGS=(-c "$CONFIGURATION")
if [ -n "$SWIFT_SCRATCH_PATH" ]; then
  SWIFT_BUILD_ARGS+=(--scratch-path "$SWIFT_SCRATCH_PATH")
fi
swift build "${SWIFT_BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
if [ ! -f "$APP_ICON" ]; then
  swift "$ROOT_DIR/Tools/make_app_icon.swift"
fi

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
cp "$PRIVACY_MANIFEST" "$APP_RESOURCES/PrivacyInfo.xcprivacy"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$CURRENT_PROJECT_VERSION</string>
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT_TEXT</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key>
  <true/>
  <key>NSSupportsSuddenTermination</key>
  <true/>
</dict>
</plist>
PLIST

SIGN_ARGS=(--force --deep --options runtime)
if [ "$SIGN_IDENTITY" != "-" ]; then
  SIGN_ARGS+=(--timestamp)
fi
SIGN_ARGS+=(--sign "$SIGN_IDENTITY")
if [ -n "$ENTITLEMENTS_PATH" ]; then
  SIGN_ARGS+=(--entitlements "$ENTITLEMENTS_PATH")
fi

/usr/bin/codesign "${SIGN_ARGS[@]}" "$APP_BUNDLE" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

printf '%s\n' "$APP_BUNDLE"
