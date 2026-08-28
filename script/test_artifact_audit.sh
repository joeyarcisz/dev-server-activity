#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dev-server-activity-audit.XXXXXX")"
trap '/bin/rm -rf "$TMP_DIR"' EXIT

/usr/bin/python3 - "$TMP_DIR" <<'PY'
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1])

with zipfile.ZipFile(root / "clean.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("DevServerActivity.app/Contents/Info.plist", b"clean release payload")

with zipfile.ZipFile(root / "canonical-appledouble.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("__MACOSX/DevServerActivity.app/._Contents", b"metadata")

with zipfile.ZipFile(root / "disguised-metadata.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
    payload = b"\x00\x05\x16\x07" + (b"x" * 16_384) + b"com.apple.quarantine"
    archive.writestr("DevServerActivity.app/Contents/Resources/cache.bin", payload)

with zipfile.ZipFile(root / "path-traversal.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("../outside", b"unexpected")

(root / "malformed.zip").write_bytes(b"not a ZIP archive")
PY

"$ROOT_DIR/script/audit_public_artifacts.sh" archive "$TMP_DIR/clean.zip" >/dev/null

failures=0
for unsafe_archive in \
  "$TMP_DIR/canonical-appledouble.zip" \
  "$TMP_DIR/disguised-metadata.zip" \
  "$TMP_DIR/path-traversal.zip" \
  "$TMP_DIR/malformed.zip"
do
  if "$ROOT_DIR/script/audit_public_artifacts.sh" archive "$unsafe_archive" >/dev/null 2>&1; then
    printf 'artifact audit test failed: unsafe archive was accepted: %s\n' "$unsafe_archive" >&2
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ] || exit 1
printf 'Artifact audit regression tests passed.\n'
