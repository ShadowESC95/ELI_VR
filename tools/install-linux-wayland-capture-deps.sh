#!/usr/bin/env bash
set -euo pipefail
sudo apt update
sudo apt install -y \
  python3-dbus python3-gi \
  gir1.2-gstreamer-1.0 gir1.2-gst-plugins-base-1.0 \
  gstreamer1.0-pipewire gstreamer1.0-plugins-base gstreamer1.0-tools

echo "ELI VR Wayland portal capture dependencies installed."
python3 - <<'PY'
import dbus, gi
gi.require_version('Gst','1.0')
from gi.repository import Gst
Gst.init(None)
reg=Gst.Registry.get()
assert reg.find_feature('pipewiresrc', Gst.ElementFactory), 'pipewiresrc missing'
print('PASS: dbus + GStreamer + pipewiresrc available')
PY
