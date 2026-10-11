#!/usr/bin/env bash
set -Eeuo pipefail

cat <<'EOF'
This is FIRST-RUN/DEVELOPMENT tooling and may contact configured OS package repositories.
This installs native build dependencies for the optional Rust desktop bridge.
It does NOT install/modify Monado, SteamVR, WayVR, NVIDIA drivers or OpenHMD.
EOF

sudo apt update
sudo apt install -y \
  curl build-essential pkg-config libclang-dev \
  libxcb1-dev libxrandr-dev libdbus-1-dev \
  libpipewire-0.3-dev libwayland-dev libegl-dev libgbm-dev

if ! command -v cargo >/dev/null 2>&1; then
  echo
  echo "Rust is not installed."
  echo "Install rustup from https://rustup.rs/ and then re-run the bridge build."
fi

echo
echo "Godot 4.7.2 must also be installed separately."
