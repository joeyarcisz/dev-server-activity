#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build, Developer ID sign, notarize, staple, archive, and verify Dev Server Activity.

Required environment:
  DEVELOPER_ID_APPLICATION  Exact installed Developer ID Application identity
  NOTARY_PROFILE            Existing notarytool Keychain profile name

Optional environment:
  EXPECTED_TEAM_ID          Expected signing team (default: 34M828S6C8)
  DIRECT_RELEASE_OUTPUT_DIR Output root (default: dist/direct)

Example:
  DEVELOPER_ID_APPLICATION="Developer ID Application: Geared Like A Machine LLC (34M828S6C8)" \
  NOTARY_PROFILE="DevServerActivityNotary" \
  ./script/package_direct_release.sh
USAGE
}

fail() {
  printf 'release failed: %s\n' "$*" >&2
  exit 2
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Config/app.env"

SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE_NAME="${NOTARY_PROFILE:-}"
EXPECTED_TEAM_ID_VALUE="${EXPECTED_TEAM_ID:-34M828S6C8}"
RELEASE_OUTPUT_ROOT="${DIRECT_RELEASE_OUTPUT_DIR:-$ROOT_DIR/dist/direct}"
RELEASE_TMP_BASE="${TMPDIR:-/tmp}"

[ -n "$SIGN_IDENTITY" ] || fail "DEVELOPER_ID_APPLICATION is required"
[ -n "$NOTARY_PROFILE_NAME" ] || fail "NOTARY_PROFILE is required"

case "$SIGN_IDENTITY" in
  "Developer ID Application: "*) ;;
  *) fail "DEVELOPER_ID_APPLICATION must be a Developer ID Application identity" ;;
esac

if ! /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "\"$SIGN_IDENTITY\""; then
  fail "the requested Developer ID Application identity is not installed and valid"
fi

cd "$ROOT_DIR"
[ -z "$(git status --porcelain --untracked-files=normal)" ] || fail "source tree must be clean before a public release"
SOURCE_COMMIT="$(git rev-parse HEAD)"

if ! /usr/bin/xcrun notarytool history \
  --keychain-profile "$NOTARY_PROFILE_NAME" \
  --output-format json >/dev/null; then
  fail "NOTARY_PROFILE could not authenticate with Apple's notary service"
fi

WORK_DIR="$(mktemp -d "$RELEASE_TMP_BASE/DevServerActivityRelease.XXXXXX")"
BUILD_OUTPUT_DIR="$WORK_DIR/build"
mkdir -p "$BUILD_OUTPUT_DIR"

swift test --scratch-path "$WORK_DIR/swift-tests"

CONFIGURATION=release \
SIGN_IDENTITY="$SIGN_IDENTITY" \
ENTITLEMENTS_PATH="$ROOT_DIR/Config/DevServerActivity.entitlements" \
OUTPUT_DIR="$BUILD_OUTPUT_DIR" \
SWIFT_SCRATCH_PATH="$WORK_DIR/swift-build" \
"$ROOT_DIR/script/build_bundle.sh" >/dev/null

APP_BUNDLE="$BUILD_OUTPUT_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
[ -d "$APP_BUNDLE" ] || fail "release app bundle was not created"
[ -x "$APP_BINARY" ] || fail "release executable was not created"

ARCHS="$(/usr/bin/lipo -archs "$APP_BINARY")"
case "$ARCHS" in
  arm64) ARCH_LABEL="arm64" ;;
  x86_64) ARCH_LABEL="x86_64" ;;
  "arm64 x86_64"|"x86_64 arm64") ARCH_LABEL="universal" ;;
  *) fail "unsupported release architecture set: $ARCHS" ;;
esac

ARTIFACT_STEM="$PRODUCT_NAME-$MARKETING_VERSION-$CURRENT_PROJECT_VERSION-macos-$ARCH_LABEL"
RELEASE_DIR="$RELEASE_OUTPUT_ROOT/$ARTIFACT_STEM"
FINAL_APP="$RELEASE_DIR/$APP_NAME.app"
FINAL_ZIP="$RELEASE_DIR/$ARTIFACT_STEM.zip"
SHA_FILE="$RELEASE_DIR/$ARTIFACT_STEM.sha256"
RECEIPT_FILE="$RELEASE_DIR/$ARTIFACT_STEM-verification.txt"
NOTARY_RESULT="$RELEASE_DIR/$ARTIFACT_STEM-notary.json"
NOTARY_LOG="$RELEASE_DIR/$ARTIFACT_STEM-notary-log.json"

for target in "$FINAL_APP" "$FINAL_ZIP" "$SHA_FILE" "$RECEIPT_FILE" "$NOTARY_RESULT" "$NOTARY_LOG"; do
  [ ! -e "$target" ] || fail "refusing to overwrite existing release output: $target"
done
mkdir -p "$RELEASE_DIR"

SIGNATURE_DETAILS="$WORK_DIR/signature.txt"
ENTITLEMENTS_CAPTURE="$WORK_DIR/entitlements.plist"
BUILD_DETAILS="$WORK_DIR/build-version.txt"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/codesign -dvvv "$APP_BUNDLE" >"$SIGNATURE_DETAILS" 2>&1
/usr/bin/codesign -d --entitlements - --xml "$APP_BUNDLE" >"$ENTITLEMENTS_CAPTURE" 2>/dev/null
/usr/bin/xcrun vtool -show-build "$APP_BINARY" >"$BUILD_DETAILS"

/usr/bin/grep -Fq "Authority=$SIGN_IDENTITY" "$SIGNATURE_DETAILS" || fail "signature authority mismatch"
/usr/bin/grep -Fq "TeamIdentifier=$EXPECTED_TEAM_ID_VALUE" "$SIGNATURE_DETAILS" || fail "signing team mismatch"
/usr/bin/grep -Fq "runtime" "$SIGNATURE_DETAILS" || fail "Hardened Runtime is missing"
/usr/bin/grep -Fq "Timestamp=" "$SIGNATURE_DETAILS" || fail "secure signing timestamp is missing"
/usr/bin/plutil -lint "$ENTITLEMENTS_CAPTURE" >/dev/null || fail "signed entitlements are not a valid plist"

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
ACTUAL_MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ACTUAL_BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ACTUAL_MIN_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
ACTUAL_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
ACTUAL_PACKAGE_TYPE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$INFO_PLIST")"
ACTUAL_ICON_FILE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")"
ACTUAL_CATEGORY="$(/usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$INFO_PLIST")"

[ "$ACTUAL_BUNDLE_ID" = "$BUNDLE_ID" ] || fail "bundle identifier mismatch"
[ "$ACTUAL_MARKETING_VERSION" = "$MARKETING_VERSION" ] || fail "marketing version mismatch"
[ "$ACTUAL_BUILD_VERSION" = "$CURRENT_PROJECT_VERSION" ] || fail "build version mismatch"
[ "$ACTUAL_MIN_SYSTEM_VERSION" = "$MIN_SYSTEM_VERSION" ] || fail "minimum macOS metadata mismatch"
[ "$ACTUAL_EXECUTABLE" = "$PRODUCT_NAME" ] || fail "bundle executable metadata mismatch"
[ "$ACTUAL_PACKAGE_TYPE" = "APPL" ] || fail "bundle package type is not APPL"
[ "$ACTUAL_ICON_FILE" = "AppIcon" ] || fail "bundle icon metadata mismatch"
[ "$ACTUAL_CATEGORY" = "$APP_CATEGORY" ] || fail "application category metadata mismatch"
[ -s "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ] || fail "app icon resource is missing"
[ -s "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" ] || fail "privacy manifest is missing"
/usr/bin/cmp -s \
  "$ROOT_DIR/Config/PrivacyInfo.xcprivacy" \
  "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" || fail "privacy manifest does not match the configured source"
/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" >/dev/null || fail "privacy manifest is invalid"

/usr/bin/python3 -c '
import plistlib
import sys
with open(sys.argv[1], "rb") as expected_file, open(sys.argv[2], "rb") as signed_file:
    expected = plistlib.load(expected_file)
    signed = plistlib.load(signed_file)
raise SystemExit(0 if expected == signed else 1)
' "$ROOT_DIR/Config/DevServerActivity.entitlements" "$ENTITLEMENTS_CAPTURE" || fail "signed entitlements do not exactly match the configured entitlements"

if [ "$(/usr/bin/plutil -extract com.apple.security.app-sandbox raw -o - "$ENTITLEMENTS_CAPTURE" 2>/dev/null || true)" = "true" ]; then
  fail "App Sandbox is enabled; full process discovery and termination would be degraded"
fi

if [ "$(/usr/bin/plutil -extract com.apple.security.get-task-allow raw -o - "$ENTITLEMENTS_CAPTURE" 2>/dev/null || true)" = "true" ]; then
  fail "debugging entitlement com.apple.security.get-task-allow is enabled"
fi

/usr/bin/grep -Fq "minos $MIN_SYSTEM_VERSION" "$BUILD_DETAILS" || fail "binary minimum macOS does not match $MIN_SYSTEM_VERSION"

SUBMISSION_ZIP="$WORK_DIR/$ARTIFACT_STEM-notary-upload.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$SUBMISSION_ZIP"

if ! /usr/bin/xcrun notarytool submit "$SUBMISSION_ZIP" \
  --keychain-profile "$NOTARY_PROFILE_NAME" \
  --wait \
  --timeout 30m \
  --output-format json >"$NOTARY_RESULT"; then
  fail "Apple notarization submission failed; inspect $NOTARY_RESULT"
fi

NOTARY_STATUS="$(/usr/bin/plutil -extract status raw -o - "$NOTARY_RESULT")"
NOTARY_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_RESULT")"
if [ "$NOTARY_STATUS" != "Accepted" ]; then
  /usr/bin/xcrun notarytool log "$NOTARY_ID" "$NOTARY_LOG" \
    --keychain-profile "$NOTARY_PROFILE_NAME" || true
  fail "Apple notarization status was $NOTARY_STATUS; inspect $NOTARY_RESULT and $NOTARY_LOG"
fi

/usr/bin/xcrun notarytool log "$NOTARY_ID" "$NOTARY_LOG" \
  --keychain-profile "$NOTARY_PROFILE_NAME"
/usr/bin/xcrun stapler staple "$APP_BUNDLE"
/usr/bin/xcrun stapler validate "$APP_BUNDLE"
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

/usr/bin/ditto "$APP_BUNDLE" "$FINAL_APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$FINAL_APP" "$FINAL_ZIP"

VERIFY_DIR="$(mktemp -d "$RELEASE_TMP_BASE/DevServerActivityVerify.XXXXXX")"
/usr/bin/ditto -x -k "$FINAL_ZIP" "$VERIFY_DIR"
VERIFIED_APP="$VERIFY_DIR/$APP_NAME.app"
[ -d "$VERIFIED_APP" ] || fail "archive did not expand to the expected app bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFIED_APP"
/usr/bin/xcrun stapler validate "$VERIFIED_APP"
/usr/sbin/spctl --assess --type execute --verbose=4 "$VERIFIED_APP"

(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$(basename "$FINAL_ZIP")" >"$(basename "$SHA_FILE")"
  /usr/bin/shasum -a 256 -c "$(basename "$SHA_FILE")"
)

{
  printf 'Dev Server Activity direct-release verification\n'
  printf 'Generated (UTC): %s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Source commit: %s\n' "$SOURCE_COMMIT"
  printf 'Bundle ID: %s\n' "$ACTUAL_BUNDLE_ID"
  printf 'Version: %s (%s)\n' "$ACTUAL_MARKETING_VERSION" "$ACTUAL_BUILD_VERSION"
  printf 'Minimum macOS: %s\n' "$ACTUAL_MIN_SYSTEM_VERSION"
  printf 'Architectures: %s\n' "$ARCHS"
  printf 'Signing identity: %s\n' "$SIGN_IDENTITY"
  printf 'Team ID: %s\n' "$EXPECTED_TEAM_ID_VALUE"
  printf 'Notarization ID: %s\n' "$NOTARY_ID"
  printf 'Notarization status: %s\n' "$NOTARY_STATUS"
  printf 'Stapler: validated\n'
  printf 'Gatekeeper: accepted\n'
  printf 'Archive: %s\n' "$FINAL_ZIP"
  printf 'SHA-256: %s\n' "$(/usr/bin/awk '{print $1}' "$SHA_FILE")"
  printf '\nSignature details:\n'
  /bin/cat "$SIGNATURE_DETAILS"
  printf '\nBuild details:\n'
  /bin/cat "$BUILD_DETAILS"
  printf '\nEntitlements:\n'
  /bin/cat "$ENTITLEMENTS_CAPTURE"
} >"$RECEIPT_FILE"

printf 'Release app: %s\n' "$FINAL_APP"
printf 'Release archive: %s\n' "$FINAL_ZIP"
printf 'Checksum: %s\n' "$SHA_FILE"
printf 'Verification receipt: %s\n' "$RECEIPT_FILE"
printf 'Notarization result: %s\n' "$NOTARY_RESULT"
printf 'Temporary work retained at: %s\n' "$WORK_DIR"
printf 'Temporary verification retained at: %s\n' "$VERIFY_DIR"
