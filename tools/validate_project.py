#!/usr/bin/env python3
import json, re, sys, struct, zlib
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
    "scripts/world/procedural_geometry.gd",
    "scripts/world/cosmic_field.gd",
    "scripts/world/room_factory.gd",
    "scripts/desktop/desktop_surface.gd",
    "assets/shaders/universal_world_sky.gdshader",
    "assets/shaders/cosmic_nebula.gdshader",
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
for token in ["GRIP_FALLBACK", "get_has_tracking_data()", "PointerBeam", "query.collision_mask = 2"]:
    if token not in pointer:
        print("POINTER INVARIANT MISSING", token); bad = True

manip = (ROOT / "scripts/xr/world_manipulator.gd").read_text(errors="ignore")
if "query.collision_mask = 4" not in manip:
    print("MANIPULATION LAYER MISSING"); bad = True

widget = (ROOT / "scripts/xr/calibration_widget.gd").read_text(errors="ignore")
for token in [
    "CHORD_HOLD_SECONDS", "grip_click", "trigger_click",
    "var left_stick: Vector2", "var right_stick: Vector2",
    'manager.call(&"calibrate_hands")',
]:
    if token not in widget:
        print("CALIBRATION UX MISSING", token); bad = True
for forbidden in ["XRControllerCalibration", 'preload("res://scripts/world/interactable_3d.gd")']:
    if forbidden in widget:
        print("CALIBRATION COMPILE-ISOLATION REGRESSION", forbidden); bad = True

spatial = (ROOT / "scripts/world/spatial_console.gd").read_text(errors="ignore")
for token in ["MovablePanelClass", '"BLUE"', '"BLACK"', '"PURPLE"', '"GREEN"', '"ORANGE"', '"CYAN"']:
    if token not in spatial:
        print("MOVABLE/COLOR UI MISSING", token); bad = True

desktop = (ROOT / "scripts/desktop/desktop_surface.gd").read_text(errors="ignore")
for token in [
    "extends Area3D", "collision_layer = 4", "begin_grab", "end_grab",
    "_activate_composition_layer", "display_mode == \"composition\"",
]:
    if token not in desktop:
        print("DESKTOP SURFACE MISSING", token); bad = True
# Ensure the composition node is added before layer properties are set.
if desktop.find("add_child(composition_layer)") > desktop.find('composition_layer.set("layer_viewport", viewport)'):
    print("DESKTOP COMPOSITION LIFECYCLE REGRESSION"); bad = True

cosmic = (ROOT / "scripts/world/cosmic_field.gd").read_text(errors="ignore")
for token in ["_stochastic_star_volume", "_galaxy_billboards", "_globular_cluster", "_nebula_volumes", "MultiMesh"]:
    if token not in cosmic:
        print("COSMIC FIELD MISSING", token); bad = True

world = (ROOT / "scripts/world/room_factory.gd").read_text(errors="ignore")
for token in ["CosmicFieldClass", "ProceduralGeometryClass", "_torus(", "_rock_field(", "_cosmic_field(parent)"]:
    if token not in world:
        print("CINEMATIC WORLD SYSTEM MISSING", token); bad = True
for fn in [
    "_build_core", "_build_memory", "_build_workshop", "_build_mountain",
    "_build_debug", "_build_fabrication", "_build_digital", "_build_anomaly",
    "_build_evidence", "_build_forest", "_build_ocean", "_build_space",
    "_build_arctic", "_build_desert", "_build_underwater",
]:
    if ("func %s(" % fn) not in world:
        print("ENVIRONMENT BUILDER MISSING", fn); bad = True

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


asset_required = [
    "scripts/world/cinematic_assets.gd",
    "native/desktop_portal_bridge/eli_portal_bridge.py",
    "tools/install-linux-wayland-capture-deps.sh",
    "assets/cinematic/textures/star_soft.png",
    "assets/cinematic/textures/galaxy_blue.png",
    "assets/cinematic/textures/rock_albedo.png",
]
for rel in asset_required:
    if not (ROOT / rel).exists():
        print("MISSING CINEMATIC ASSET TIER", rel); bad=True

world_text = (ROOT / "scripts/world/room_factory.gd").read_text(errors="ignore")
for token in [
    "CinematicAssetsClass", "_lorenz_ribbon", "_mobius(",
    "_glacier_field", "_coral_garden", "_observatory",
]:
    if token not in world_text:
        print("MISSING ADVANCED WORLD SYSTEM", token); bad=True

cosmic_text = (ROOT / "scripts/world/cosmic_field.gd").read_text(errors="ignore")
if "GOLDEN_ANGLE" in cosmic_text:
    print("STRUCTURED GOLDEN-ANGLE STAR FIELD STILL PRESENT"); bad=True
for token in ["galaxy_blue.png", "galaxy_edge.png", "_stochastic_star_volume"]:
    if token not in cosmic_text:
        print("MISSING DEEP SPACE VISUAL", token); bad=True

client_text = (ROOT / "scripts/desktop/desktop_bridge_client.gd").read_text(errors="ignore")
for token in ["RAW_MAGIC", "Image.FORMAT_RGBA8", 'frame_mode == "raw"']:
    if token not in client_text:
        print("MISSING RAW DESKTOP FRAME SUPPORT", token); bad=True

portal_text = (ROOT / "native/desktop_portal_bridge/eli_portal_bridge.py").read_text(errors="ignore")
for token in ["ScreenCast", "OpenPipeWireRemote", "pipewiresrc", "127.0.0.1"]:
    if token not in portal_text:
        print("MISSING WAYLAND PORTAL CAPTURE", token); bad=True


polish_checks = {
    "scripts/world/cosmic_field.gd": ["_nebula_volume", "DeepStars", "galaxy_gold.png"],
    "scripts/world/room_factory.gd": ["_asteroid_belt", "_distant_star", "palette_world_strength"],
    "scripts/world/spatial_console.gd": ["set_desktop_workspace", "RESET UI"],
    "scripts/desktop/desktop_surface.gd": ["layout_version", "reset_workspace_transform"],
    "native/desktop_portal_bridge/eli_portal_bridge.py": ["open_listener", "ScreenCast interface version", "live desktop capture streaming"],
}
for rel, tokens in polish_checks.items():
    text=(ROOT/rel).read_text(errors="ignore")
    for token in tokens:
        if token not in text:
            print("MISSING 0.6.1 POLISH", rel, token); bad=True

# The 0.6.0 placeholder albedo bug must never return.
try:
    from PIL import Image, ImageStat
    for rel in ["rock_albedo.png","bark_albedo.png","sand_albedo.png","ice_albedo.png"]:
        im=Image.open(ROOT/"assets/cinematic/textures"/rel).convert("RGB")
        stat=ImageStat.Stat(im)
        if all(v > 254.5 for v in stat.mean):
            print("BLANK CINEMATIC ALBEDO", rel); bad=True
except Exception as exc:
    print("TEXTURE VALIDATION ERROR", exc); bad=True

launch_text=(ROOT/"launch/run-linux-monado-cv1-reference.sh").read_text(errors="ignore")
if 'desktop_portal_bridge/eli_portal_bridge.py" 2>/dev/null || true' not in launch_text:
    print("PORTAL BRIDGE STALE-PROCESS CLEANUP MISSING"); bad=True


# Reject source blocks accidentally serialized with literal "\\n" escapes.
# Normal string literals such as "line1\\nline2" are allowed; these patterns
# specifically detect escaped newlines in function/code structure.
import re as _re
_source_patterns = [
    _re.compile(r"->\s*[A-Za-z0-9_\[\]]+\s*:\\n"),
    _re.compile(r"\\nfunc\s+"),
    _re.compile(r"\\n\s{4}(?:var|if|for|while|match|return|_[A-Za-z])"),
]
for _gd in (ROOT / "scripts").rglob("*.gd"):
    _src = _gd.read_text(errors="ignore")
    for _pat in _source_patterns:
        if _pat.search(_src):
            print("GDSCRIPT ESCAPED-NEWLINE CORRUPTION", _gd.relative_to(ROOT))
            bad = True
            break

print("ELI VR project validation:", "FAILED" if bad else "OK")
sys.exit(1 if bad else 0)
