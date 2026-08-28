#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
/usr/bin/swift build --target DevServerActivityCore >/dev/null
BIN_PATH="$(/usr/bin/swift build --show-bin-path)"

/usr/bin/xcrun swiftc \
  -typecheck \
  -parse-as-library \
  -swift-version 6 \
  -strict-concurrency=complete \
  -warnings-as-errors \
  -I "$BIN_PATH/Modules" \
  "$ROOT_DIR/Tests/APICompatibility/NonSendableProtocolConformers.swift"

printf 'Public protocol compatibility check passed for non-Sendable Swift 6 client conformers.\n'
