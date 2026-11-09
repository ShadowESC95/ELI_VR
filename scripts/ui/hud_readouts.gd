class_name HudReadouts
extends RefCounted

## Which debug readouts the HUDs show, and what they say. Each piece is on or off on its own, or all at
## once; the choice is kept in ELI VR's own settings (ui.readouts) and is off for normal use. A run started
## in ELI VR's diagnostic mode (ELI_VR_XR_DIAGNOSTICS=1) shows them all, and what is switched in that run
## lasts that run only, so normal use keeps its own choice. What must be seen whatever is on (what ELI just
## did or why not, the second press that closes ELI VR) is not a readout and is always shown.
##
## The XR status HUD, the flat window's HUD, the input diagnostics and the calibration panel's offsets
## all ask here; the wrist menu, the settings dock, F3 and the console's HUD button switch them here.

signal changed

const PIECES := [
    {"id": "fps", "label": "FPS", "about": "Frame rate, hardware class and quality"},
    {"id": "controllers", "label": "COORDINATES", "about": "Controller x / y / z and yaw calibration offsets"},
    {"id": "input", "label": "INPUT", "about": "Controller input diagnostics"},
    {"id": "status", "label": "STATUS", "about": "Room, desktop link and ELI link"},
]

## The environment variable that starts ELI VR in its diagnostic mode.
const DIAGNOSTIC_ENV := "ELI_VR_XR_DIAGNOSTICS"
## How often a readout people read is redrawn: a figure changing every frame cannot be read anyway.
const REFRESH_SECONDS := 0.25
## Settings that switched these before and switch nothing now: taken out of the settings file.
const RETIRED := ["ui.performance_hud", "diagnostics.xr_input_overlay", "developer.show_fps"]

var config
var diagnostic := false
var _this_run := {}

static func diagnostic_mode() -> bool:
    return OS.get_environment(DIAGNOSTIC_ENV) == "1"

func setup(p_config, p_diagnostic: bool = false) -> void:
    config = p_config
    diagnostic = p_diagnostic
    for key in RETIRED:
        config.remove_value(key)

static func ids() -> Array:
    return PIECES.map(func(piece): return piece["id"])

func shown(piece: String) -> bool:
    if diagnostic:
        return bool(_this_run.get(piece, true))
    return bool(config.get_value("ui.readouts.%s" % piece, false))

func any_shown() -> bool:
    return ids().any(func(piece): return shown(piece))

func all_shown() -> bool:
    return ids().all(func(piece): return shown(piece))

## "ON" when every piece is shown, "OFF" when none is, "SOME" between.
func state() -> String:
    return "ON" if all_shown() else ("SOME" if any_shown() else "OFF")

func set_shown(piece: String, on: bool) -> void:
    if not ids().has(piece):
        return
    _put(piece, on)
    _keep()

func toggle(piece: String) -> void:
    set_shown(piece, not shown(piece))

func set_all(on: bool) -> void:
    for piece in ids():
        _put(piece, on)
    _keep()

## All at once: anything shown goes; with nothing shown, everything comes back.
func toggle_all() -> void:
    set_all(not any_shown())

func _put(piece: String, on: bool) -> void:
    if diagnostic:
        _this_run[piece] = on
    else:
        config.set_value("ui.readouts.%s" % piece, on)

func _keep() -> void:
    if not diagnostic:
        config.save_runtime()
    changed.emit()

## The lines a HUD shows now: the readouts that are on, then what is shown whatever is on.
func lines(app) -> PackedStringArray:
    var out := PackedStringArray()
    if shown("fps"):
        out.append("%d FPS · %s · QUALITY %s" % [
            Engine.get_frames_per_second(),
            str(app.capabilities.get("hardware_class", "unknown")).to_upper(),
            str(app.config.get_value("graphics.quality", "auto")).to_upper()])
        if app.optimizer != null:
            out.append(str(app.optimizer.capability_summary()))
    if shown("status"):
        out.append("%s · %s" % [str(app.current_room_name()), str(app.current_environment_name())])
        out.append("%s · DESKTOP %s" % ["XR" if bool(app.xr_active) else "FLAT", str(app.desktop_status())])
        var eli := str(app.eli_status())
        if not eli.is_empty():
            out.append(eli)
    for message in [str(app.eli_notice()), str(app.exit_notice())]:
        if not message.is_empty():
            out.append(message)
    return out
