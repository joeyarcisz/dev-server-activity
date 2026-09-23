#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap '/bin/rm -rf "$TMP_DIR"' EXIT
export DSA_LAUNCHER_TEST_MARKER="$TMP_DIR/side-effect"

# Stub side effects so this regression can never stop a real app or build it.
pkill() { touch "$DSA_LAUNCHER_TEST_MARKER"; }
swift() { touch "$DSA_LAUNCHER_TEST_MARKER"; return 99; }
export -f pkill swift

status=0
bash "$ROOT_DIR/script/build_and_run.sh" --invalid-option >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || { printf 'Expected usage exit 2, got %s\n' "$status" >&2; exit 1; }
[ ! -e "$DSA_LAUNCHER_TEST_MARKER" ] || { printf 'Invalid arguments triggered side effects\n' >&2; exit 1; }
printf 'Build/run argument validation regression passed.\n'
