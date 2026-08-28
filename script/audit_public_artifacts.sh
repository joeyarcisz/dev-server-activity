#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'artifact audit failed: %s\n' "$*" >&2
  exit 2
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-source}"

audit_source() {
  cd "$ROOT_DIR"

  local png_count=0
  local file
  local profile
  local expected_width
  local actual_width
  while IFS= read -r -d '' file; do
    png_count=$((png_count + 1))
    profile="$(/usr/bin/sips -g profile "$file" 2>/dev/null | /usr/bin/awk -F': ' '/profile:/{print $2; exit}')"
    [ "$profile" = "sRGB IEC61966-2.1" ] || fail "$file uses unexpected color profile: ${profile:-none}"

    if /usr/bin/strings "$file" | /usr/bin/grep -Fq "Studio Display"; then
      fail "$file contains a device-specific display profile"
    fi

    expected_width=""
    case "$file" in
      Assets/AppIcon.iconset/icon_16x16.png) expected_width=16 ;;
      Assets/AppIcon.iconset/icon_16x16@2x.png) expected_width=32 ;;
      Assets/AppIcon.iconset/icon_32x32.png) expected_width=32 ;;
      Assets/AppIcon.iconset/icon_32x32@2x.png) expected_width=64 ;;
      Assets/AppIcon.iconset/icon_128x128.png) expected_width=128 ;;
      Assets/AppIcon.iconset/icon_128x128@2x.png) expected_width=256 ;;
      Assets/AppIcon.iconset/icon_256x256.png) expected_width=256 ;;
      Assets/AppIcon.iconset/icon_256x256@2x.png) expected_width=512 ;;
      Assets/AppIcon.iconset/icon_512x512.png) expected_width=512 ;;
      Assets/AppIcon.iconset/icon_512x512@2x.png) expected_width=1024 ;;
    esac

    if [ -n "$expected_width" ]; then
      actual_width="$(/usr/bin/sips -g pixelWidth "$file" 2>/dev/null | /usr/bin/awk -F': ' '/pixelWidth:/{print $2; exit}')"
      [ "$actual_width" = "$expected_width" ] || fail "$file has width $actual_width; expected $expected_width"
    fi
  done < <(/usr/bin/git ls-files -z -- '*.png')

  [ "$png_count" -gt 0 ] || fail "no tracked PNG files were found"

  /usr/bin/python3 <<'PY'
import struct
import subprocess
import sys
from pathlib import Path

png_signature = b"\x89PNG\r\n\x1a\n"
prohibited_chunks = {b"eXIf", b"iTXt", b"tEXt", b"zTXt", b"tIME", b"pHYs"}


def reject(message: str) -> None:
    print(f"artifact audit failed: {message}", file=sys.stderr)
    raise SystemExit(2)


def inspect_png(data: bytes, label: str) -> None:
    if not data.startswith(png_signature):
        reject(f"{label} is not valid PNG data")

    cursor = len(png_signature)
    found_end = False
    while cursor + 12 <= len(data):
        payload_length = struct.unpack(">I", data[cursor:cursor + 4])[0]
        chunk_type = data[cursor + 4:cursor + 8]
        chunk_end = cursor + payload_length + 12
        if chunk_end > len(data):
            reject(f"{label} contains a malformed PNG chunk")
        if chunk_type in prohibited_chunks:
            reject(f"{label} contains prohibited PNG metadata chunk {chunk_type.decode('ascii')}")
        cursor = chunk_end
        if chunk_type == b"IEND":
            found_end = True
            break

    if not found_end or cursor != len(data):
        reject(f"{label} contains a malformed PNG trailer")


tracked_pngs = subprocess.check_output(
    ["/usr/bin/git", "ls-files", "-z", "--", "*.png"]
).split(b"\0")
for raw_path in filter(None, tracked_pngs):
    path = Path(raw_path.decode("utf-8"))
    inspect_png(path.read_bytes(), str(path))

tracked_icons = subprocess.check_output(
    ["/usr/bin/git", "ls-files", "-z", "--", "*.icns"]
).split(b"\0")
for raw_path in filter(None, tracked_icons):
    path = Path(raw_path.decode("utf-8"))
    data = path.read_bytes()
    if len(data) < 8 or data[:4] != b"icns":
        reject(f"{path} is not a valid ICNS container")
    declared_length = struct.unpack(">I", data[4:8])[0]
    if declared_length != len(data):
        reject(f"{path} has an invalid ICNS length")

    cursor = 8
    embedded_png_count = 0
    while cursor + 8 <= len(data):
        element_type = data[cursor:cursor + 4].decode("latin-1")
        element_length = struct.unpack(">I", data[cursor + 4:cursor + 8])[0]
        if element_length < 8 or cursor + element_length > len(data):
            reject(f"{path} contains a malformed ICNS element")
        payload = data[cursor + 8:cursor + element_length]
        if payload.startswith(png_signature):
            embedded_png_count += 1
            inspect_png(payload, f"{path}:{element_type}")
        cursor += element_length

    if cursor != len(data):
        reject(f"{path} contains a malformed ICNS trailer")
    if embedded_png_count == 0:
        reject(f"{path} contains no inspectable PNG icon payloads")
PY

  local unsafe_fixtures
  unsafe_fixtures="$(
    /usr/bin/git grep -I -n -E '[[:space:]][0-9]+[[:space:]]+[[:alnum:]_.-]+[[:space:]][0-9]+u[[:space:]]+IPv' -- Tests 2>/dev/null \
      | /usr/bin/grep -v ' tester ' || true
  )"
  [ -z "$unsafe_fixtures" ] || fail "process fixtures contain a non-synthetic username"

  local unpinned_actions
  unpinned_actions="$(
    /usr/bin/git grep -n -E 'uses:[[:space:]]+[^[:space:]]+@' -- .github/workflows 2>/dev/null \
      | /usr/bin/grep -Ev '@[0-9a-f]{40}([[:space:]]|$)' || true
  )"
  [ -z "$unpinned_actions" ] || fail "GitHub Actions contains a non-immutable action reference"

  printf 'Source artifact audit passed: clean sRGB media, synthetic fixtures, and immutable Action references.\n'
}

audit_archive() {
  [ "$#" -eq 1 ] || fail "archive mode requires exactly one ZIP path"

  local archive="$1"
  [ -f "$archive" ] || fail "archive not found: $archive"

  [ -x /usr/bin/python3 ] || fail "archive inspection requires /usr/bin/python3"
  /usr/bin/python3 - "$archive" <<'PY'
import stat
import sys
import zipfile

archive_path = sys.argv[1]
maximum_entries = 10_000
maximum_entry_bytes = 256 * 1024 * 1024
maximum_total_bytes = 512 * 1024 * 1024
appledouble_magic = b"\x00\x05\x16\x07"
prohibited_markers = (
    (b"com.apple.quarantine", "local xattr metadata"),
    (b"com.apple.provenance", "local xattr metadata"),
    (b"com.apple.metadata:kmditemwherefroms", "local xattr metadata"),
    (b"/users/", "an absolute user path"),
    (b"/private/tmp/", "a temporary build path"),
    (b"/var/folders/", "a temporary build path"),
    (b"/tmp/", "a temporary build path"),
)
maximum_marker_length = max(len(marker) for marker, _ in prohibited_markers)


def reject(message: str) -> None:
    print(f"artifact audit failed: {message}", file=sys.stderr)
    raise SystemExit(2)


try:
    with zipfile.ZipFile(archive_path, "r") as archive:
        entries = archive.infolist()
        if not entries:
            reject("archive is empty")
        if len(entries) > maximum_entries:
            reject(f"archive contains more than {maximum_entries} entries")

        total_bytes = 0
        normalized_names: set[str] = set()

        for entry in entries:
            name = entry.filename
            normalized = name.replace("\\", "/")
            components = [component for component in normalized.split("/") if component not in ("", ".")]

            if not name or "\x00" in name:
                reject("archive contains an empty or NUL-bearing path")
            if normalized.startswith("/") or (len(normalized) >= 2 and normalized[1] == ":"):
                reject(f"archive contains an absolute path: {name}")
            if ".." in normalized.split("/"):
                reject(f"archive contains path traversal: {name}")
            if not components:
                reject(f"archive contains an invalid path: {name}")

            canonical_name = "/".join(components)
            if canonical_name in normalized_names:
                reject(f"archive contains a duplicate normalized path: {name}")
            normalized_names.add(canonical_name)

            lowercase_components = [component.lower() for component in components]
            if "__macosx" in lowercase_components or components[-1].startswith("._"):
                reject(f"archive contains AppleDouble metadata entry: {name}")
            if entry.flag_bits & 0x1:
                reject(f"archive contains an encrypted entry: {name}")
            if entry.file_size > maximum_entry_bytes:
                reject(f"archive entry exceeds {maximum_entry_bytes} bytes: {name}")

            total_bytes += entry.file_size
            if total_bytes > maximum_total_bytes:
                reject(f"archive expands beyond {maximum_total_bytes} bytes")

            mode = (entry.external_attr >> 16) & 0xFFFF
            is_symlink = stat.S_ISLNK(mode)
            first_bytes = bytearray()
            overlap = b""
            symlink_target = bytearray()

            with archive.open(entry, "r") as stream:
                while True:
                    chunk = stream.read(64 * 1024)
                    if not chunk:
                        break
                    if len(first_bytes) < len(appledouble_magic):
                        missing = len(appledouble_magic) - len(first_bytes)
                        first_bytes.extend(chunk[:missing])
                    if is_symlink:
                        symlink_target.extend(chunk)

                    searchable = (overlap + chunk).lower()
                    for marker, description in prohibited_markers:
                        if marker in searchable:
                            reject(f"archive entry embeds {description}: {name}")
                    overlap = searchable[-(maximum_marker_length - 1):]

            if bytes(first_bytes) == appledouble_magic:
                reject(f"archive contains disguised AppleDouble data: {name}")
            if is_symlink:
                try:
                    target = symlink_target.decode("utf-8")
                except UnicodeDecodeError:
                    reject(f"archive contains a non-UTF-8 symlink target: {name}")
                normalized_target = target.replace("\\", "/")
                if normalized_target.startswith("/") or ".." in normalized_target.split("/"):
                    reject(f"archive contains an unsafe symlink target: {name}")
except (OSError, RuntimeError, NotImplementedError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
    reject(f"archive could not be inspected safely: {error}")
PY

  printf 'Release archive audit passed: no AppleDouble or local provenance metadata.\n'
}

case "$MODE" in
  source)
    [ "$#" -eq 1 ] || fail "source mode accepts no additional arguments"
    audit_source
    ;;
  archive)
    shift
    audit_archive "$@"
    ;;
  *)
    fail "usage: $0 [source | archive ZIP_PATH]"
    ;;
esac
