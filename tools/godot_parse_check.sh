#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
[[ -n "$GODOT" ]] || { echo "Godot not found. Set GODOT_BIN." >&2; exit 1; }

cd "$ROOT"
mkdir -p build
LOG="$ROOT/build/godot-parse-check.log"

echo "==> ELI VR Godot parse/import check (XR forced OFF)"
echo "==> Log: $LOG"

set +e
"$GODOT" --headless --path "$ROOT" --xr-mode off --editor --quit 2>&1 | tee "$LOG"
godot_rc=${PIPESTATUS[0]}
set -e

if (( godot_rc != 0 )); then
    echo "FAILED: Godot exited with status $godot_rc" >&2
    exit "$godot_rc"
fi

if grep -Eiq \
    'SCRIPT ERROR:|Failed to load script|Error importing|ERR_FILE_CORRUPT|Parse Error:|Compile Error:' \
    "$LOG"; then
    echo "FAILED: Godot reported script/import errors. See $LOG" >&2
    exit 2
fi

echo "PASS: Godot reported no script/import errors."
