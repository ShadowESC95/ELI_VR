#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
echo "Ubuntu/Debian build dependencies:"
echo "  pkg-config libclang-dev libxcb1-dev libxrandr-dev libdbus-1-dev libpipewire-0.3-dev libwayland-dev libegl-dev libgbm-dev"
cargo build --release
