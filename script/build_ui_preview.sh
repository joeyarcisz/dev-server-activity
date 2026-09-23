#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="${1:?Usage: bash script/build_ui_preview.sh OUTPUT_DIRECTORY}"
mkdir -p "$PREVIEW_DIR"
PREVIEW_DIR="$(cd "$PREVIEW_DIR" && pwd)"
BUILD_DIR="$(mktemp -d /tmp/dev-server-ui-render.XXXXXX)"
cd "$ROOT_DIR"
CORE_SOURCES=()
while IFS= read -r file; do CORE_SOURCES+=("$file"); done < <(find Sources/DevServerActivityCore -name '*.swift' -print | sort)
APP_SOURCES=()
while IFS= read -r file; do APP_SOURCES+=("$file"); done < <(find Sources/DevServerActivity -name '*.swift' ! -path '*/App/*' -print | sort)
/usr/bin/xcrun swiftc -swift-version 5 -parse-as-library -emit-library -emit-module \
  -module-name DevServerActivityCore -emit-module-path "$BUILD_DIR/DevServerActivityCore.swiftmodule" \
  -Xlinker -install_name -Xlinker '@rpath/libDevServerActivityCore.dylib' \
  "${CORE_SOURCES[@]}" -o "$BUILD_DIR/libDevServerActivityCore.dylib"
/usr/bin/xcrun swiftc -swift-version 5 -parse-as-library \
  -I "$BUILD_DIR" -L "$BUILD_DIR" -lDevServerActivityCore \
  -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
  "${APP_SOURCES[@]}" Tools/PreviewApp.swift -o "$BUILD_DIR/render-preview"
for variant in dark:populated:default light:populated:default dark:populated:min dark:empty:min dark:error:min dark:port-only:min dark:long:min dark:filtered:min dark:scanning:min; do
  IFS=: read -r appearance state size <<< "$variant"
  label="$appearance-$state-$size"
  app="$PREVIEW_DIR/DSA Preview $label.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
  cp "$BUILD_DIR/render-preview" "$app/Contents/MacOS/DesignPreview"
  cp "$BUILD_DIR/libDevServerActivityCore.dylib" "$app/Contents/Frameworks/"
  /usr/libexec/PlistBuddy -c 'Clear dict' \
    -c "Add :CFBundleIdentifier string com.joeyarcisz.DevServerActivity.preview.$label" \
    -c "Add :CFBundleName string DSA Preview $label" \
    -c 'Add :CFBundleExecutable string DesignPreview' \
    -c 'Add :CFBundlePackageType string APPL' \
    -c "Add :PreviewAppearance string $appearance" \
    -c "Add :PreviewScenario string $state" \
    -c "Add :PreviewSize string $size" \
    "$app/Contents/Info.plist"
done
printf 'Native preview apps (synthetic data, no automatic scans): %s\n' "$PREVIEW_DIR"
