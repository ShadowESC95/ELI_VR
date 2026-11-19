#!/usr/bin/env python3
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bad = False

required = [
    "project.godot", "main.tscn", "openxr_action_map.tres",
    "scripts/app.gd", "scripts/xr/xr_pointer.gd",
    "scripts/xr/controller_calibration.gd",
    "scripts/xr/calibration_widget.gd",
    "scripts/xr/world_manipulator.gd",
    "scripts/world/movable_panel_3d.gd",
    "scripts/world/room_factory.gd",
    "scripts/desktop/desktop_surface.gd",
    "config/defaults.json", "config/rooms/rooms.json",
    "config/rooms/environments.json", "config/themes/themes.json",
    "native/desktop_bridge/Cargo.toml",
]
for rel in required:
    if not (ROOT / rel).exists():
        print("MISSING", rel); bad = True

for p in ROOT.rglob("*.json"):
    try:
        json.loads(p.read_text())
    except Exception as e:
        print("BAD JSON", p.relative_to(ROOT), e); bad = True

# Source package syntax smoke checks.
for p in ROOT.rglob("*.gd"):
    text = p.read_text(errors="ignore")
    if text.count("(") != text.count(")"):
        print("PAREN COUNT", p.relative_to(ROOT)); bad = True
    if text.count("[") != text.count("]"):
        print("BRACKET COUNT", p.relative_to(ROOT)); bad = True

rooms = json.loads((ROOT / "config/rooms/rooms.json").read_text())
envs = json.loads((ROOT / "config/rooms/environments.json").read_text())
for rid, room in rooms.items():
    if room.get("environment") not in envs:
        print("ROOM ENV MISSING", rid, room.get("environment")); bad = True
    for target in room.get("portals", []):
        if target not in rooms:
            print("PORTAL TARGET MISSING", rid, target); bad = True

am = (ROOT / "openxr_action_map.tres").read_text(errors="ignore")
for token in [
    "/interaction_profiles/oculus/touch_controller",
    "/interaction_profiles/khr/simple_controller",
    'resource_name = "trigger_click"',
    'resource_name = "primary"',
    'resource_name = "aim_pose"',
    'resource_name = "grip_pose"',
    'resource_name = "haptic"',
]:
    if token not in am:
        print("ACTION MAP MISSING", token); bad = True
for forbidden in [
    "grip_surface/pose",
    "/interaction_profiles/bytedance/pico4_controller",
    "/interaction_profiles/ext/hand_interaction_ext",
]:
    if forbidden in am:
        print("ACTION MAP FORBIDDEN", forbidden); bad = True

app = (ROOT / "scripts/app.gd").read_text(errors="ignore")
for token in [
    'left_hand.tracker = "left_hand"',
    'right_hand.tracker = "right_hand"',
    'left_hand.pose = "grip"',
    'right_hand.pose = "grip"',
    'left_aim.pose = "aim"',
    'right_aim.pose = "aim"',
    "XRControllerCalibrationClass",
    "XRCalibrationWidgetClass",
    "XRWorldManipulatorClass",
    "desktop_surface.setup(config, xr_active, capabilities)",
]:
    if token not in app:
        print("APP WIRING MISSING", token); bad = True

pointer = (ROOT / "scripts/xr/xr_pointer.gd").read_text(errors="ignore")
for token in ["PointerBeam", "query.collision_mask = 2", "pose.global_transform"]:
    if token not in pointer:
        print("POINTER INVARIANT MISSING", token); bad = True
if "pointer_socket" in pointer or "pointer_socket" in app:
    print("POINTER INVARIANT: the ray leaves the aim pose, not a socket on the hand"); bad = True

# which pose a hand and its ray stand on is decided in one place, the calibration manager
poses = (ROOT / "scripts/xr/controller_calibration.gd").read_text(errors="ignore")
for token in ["AIM_FROM_GRIP", "get_has_tracking_data", "PLACED_FROM_HEAD", "aim_direction_to"]:
    if token not in poses:
        print("POSE INVARIANT MISSING", token); bad = True

manip = (ROOT / "scripts/xr/world_manipulator.gd").read_text(errors="ignore")
if "query.collision_mask = 4" not in manip:
    print("MANIPULATION LAYER MISSING"); bad = True

widget = (ROOT / "scripts/xr/calibration_widget.gd").read_text(errors="ignore")
for token in [
    "CHORD_HOLD_SECONDS", "CHORD_ACTION", "trigger_click",
    "var left_stick: Vector2", "var right_stick: Vector2",
    'manager.call(&"calibrate_hands")',
]:
    if token not in widget:
        print("CALIBRATION UX MISSING", token); bad = True
for forbidden in ["XRControllerCalibration", 'preload("res://scripts/world/interactable_3d.gd")']:
    if forbidden in widget:
        print("CALIBRATION COMPILE-ISOLATION REGRESSION", forbidden); bad = True

spatial = (ROOT / "scripts/world/spatial_console.gd").read_text(errors="ignore")
for token in ["MovablePanelClass", "registry.themes"]:
    if token not in spatial:
        print("MOVABLE/COLOR UI MISSING", token); bad = True

desktop = (ROOT / "scripts/desktop/desktop_surface.gd").read_text(errors="ignore")
for token in [
    "extends Node3D", "begin_hold", "end_hold", "ray_hit", "keep_in_front",
    "OpenXRCompositionLayerCylinder", "OpenXRCompositionLayerQuad", "sort_order", "desktop_hole.gdshader",
]:
    if token not in desktop:
        print("DESKTOP SURFACE MISSING", token); bad = True
# The layer goes into the tree before it is given its viewport (the 0.5.0 lifecycle error).
if desktop.find("add_child(_layer)") > desktop.find('_layer.set("layer_viewport", _view)'):
    print("DESKTOP COMPOSITION LIFECYCLE REGRESSION"); bad = True

# UI names must be literal colours and the palettes must agree.
themes = json.loads((ROOT / "config/themes/themes.json").read_text())
expected = {
    "frontier":"Blue", "obsidian":"Black", "nebula":"Purple", "emerald":"Green",
    "solar":"Orange", "abyssal":"Cyan", "aurora":"Ice Blue", "monolith":"White",
}
for tid, label in expected.items():
    if themes.get(tid, {}).get("display_name") != label:
        print("THEME NAME MISMATCH", tid, label); bad = True
if themes.get("obsidian", {}).get("surface", "").lower() not in {"#020202", "#000000"}:
    print("BLACK THEME IS NOT BLACK"); bad = True

# CV1 launcher must not force desktop off.
launcher = (ROOT / "launch/run-linux-monado-cv1-reference.sh").read_text(errors="ignore")
if "--eli-desktop=off" in launcher:
    print("CV1 LAUNCHER STILL FORCES DESKTOP OFF"); bad = True


for rel in [
    "native/desktop_portal_bridge/eli_portal_bridge.py",
    "tools/install-linux-wayland-capture-deps.sh",
]:
    if not (ROOT / rel).exists():
        print("MISSING", rel); bad=True

client_text = (ROOT / "scripts/desktop/desktop_bridge_client.gd").read_text(errors="ignore")
for token in ["TILE_MAGIC", "Image.FORMAT_RGBA8", "key_path", "Thread.new()", '"kind": "hello"']:
    if token not in client_text:
        print("MISSING DESKTOP TILE LINK", token); bad=True

portal_text = (ROOT / "native/desktop_portal_bridge/eli_portal_bridge.py").read_text(errors="ignore")
for token in ["ScreenCast", "OpenPipeWireRemote", "pipewiresrc", "127.0.0.1", "def admits", "def issue_key", "def changed"]:
    if token not in portal_text:
        print("MISSING WAYLAND PORTAL CAPTURE", token); bad=True


polish_checks = {
    "scripts/world/spatial_console.gd": ["set_desktop_workspace", "RESET UI"],
    "scripts/desktop/desktop_surface.gd": ["layout_version", "reset_workspace_transform"],
    "native/desktop_portal_bridge/eli_portal_bridge.py": ["open_listener", "ScreenCast interface version", "live desktop capture streaming"],
}
for rel, tokens in polish_checks.items():
    text=(ROOT/rel).read_text(errors="ignore")
    for token in tokens:
        if token not in text:
            print("MISSING 0.6.1 POLISH", rel, token); bad=True

launch_text=(ROOT/"launch/run-linux-monado-cv1-reference.sh").read_text(errors="ignore")
if 'desktop_portal_bridge/eli_portal_bridge.py" 2>/dev/null || true' not in launch_text:
    print("PORTAL BRIDGE STALE-PROCESS CLEANUP MISSING"); bad=True


print("ELI VR project validation:", "FAILED" if bad else "OK")
sys.exit(1 if bad else 0)
