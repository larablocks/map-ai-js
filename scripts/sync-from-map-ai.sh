#!/usr/bin/env bash
# sync-from-map-ai.sh — re-vendors install.sh/doctor.sh/lib.sh/stubs/ from a
# local larablocks/map-ai checkout. Run this (and commit the result) whenever
# map-ai core releases a new version this package should pick up — map-ai-js
# doesn't depend on map-ai at install time, it ships a copy, so nothing pulls
# updates in automatically.
# Usage: ./scripts/sync-from-map-ai.sh [path-to-map-ai-checkout]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
MAP_AI_DIR="${1:-$PACKAGE_ROOT/../../../composer/larablocks/map-ai}"

if [[ ! -f "$MAP_AI_DIR/doctor.sh" ]]; then
  echo "Error: '$MAP_AI_DIR' doesn't look like a map-ai checkout (no doctor.sh found)"
  echo "Usage: $0 [path-to-map-ai-checkout]"
  exit 1
fi

VENDOR_DIR="$PACKAGE_ROOT/vendor"
rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"

cp "$MAP_AI_DIR/install.sh" "$VENDOR_DIR/install.sh"
cp "$MAP_AI_DIR/doctor.sh" "$VENDOR_DIR/doctor.sh"
cp "$MAP_AI_DIR/lib.sh" "$VENDOR_DIR/lib.sh"
cp -r "$MAP_AI_DIR/stubs" "$VENDOR_DIR/stubs"

MAP_AI_VERSION="$(cd "$MAP_AI_DIR" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)"
echo "$MAP_AI_VERSION" > "$VENDOR_DIR/.map-ai-version"

echo "Vendored install.sh/doctor.sh/lib.sh/stubs/ from map-ai @ $MAP_AI_VERSION"
echo "Review the diff, bump package.json's version, and commit."
