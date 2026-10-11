#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
cargo build --release
echo "macOS will require Screen Recording permission when the bridge first captures the desktop."
