class_name RuntimeOptimizer
extends Node

var app: Node
var config
var xr: OpenXRInterface
var cached_refresh_rate := 90.0
var refresh_extension_available := false
var foveation_supported := false
var performance_state := "stable"
var sample_time := 0.0

func setup(p_app: Node, p_config, interface: XRInterface) -> void:
    app = p_app
    config = p_config
    if interface is OpenXRInterface:
        xr = interface
        _configure_xr_capabilities()
        if xr.has_signal("session_begun"):
            xr.session_begun.connect(_on_session_begun)
        if xr.has_signal("refresh_rate_changed"):
            xr.refresh_rate_changed.connect(_on_refresh_rate_changed)

func _configure_xr_capabilities() -> void:
    if xr == null:
        return
    foveation_supported = xr.is_foveation_supported()
    if str(config.get_value("xr.foveation", "auto")) != "off" and foveation_supported:
        app.get_viewport().vrs_mode = Viewport.VRS_XR
        var quality := str(config.get_value("graphics.quality", "medium"))
        xr.foveation_dynamic = true
        xr.foveation_level = 1 if quality in ["low", "medium"] else 2

    # Do not change render_target_size_multiplier here. Godot 4.7 requires
    # that property to be set before the OpenXR interface initializes.

func _on_session_begun() -> void:
    if xr == null:
        return
    var rates := xr.get_available_display_refresh_rates()
    refresh_extension_available = not rates.is_empty()
    if refresh_extension_available:
        var reported := xr.display_refresh_rate
        if reported > 1.0:
            cached_refresh_rate = reported
    else:
        cached_refresh_rate = 90.0
    Engine.physics_ticks_per_second = int(round(cached_refresh_rate))

func _on_refresh_rate_changed(rate: float) -> void:
    if rate > 1.0:
        cached_refresh_rate = rate
        Engine.physics_ticks_per_second = int(round(rate))

func _process(delta: float) -> void:
    if xr == null:
        return
    sample_time += delta
    if sample_time < 1.0:
        return
    sample_time = 0.0
    var fps := float(Engine.get_frames_per_second())
    var target := cached_refresh_rate * float(config.get_value("graphics.target_fps_ratio", 0.92))
    performance_state = "low" if fps < target else "stable"

func capability_summary() -> String:
    if xr == null:
        return "XR: unavailable"
    return "XR %.0fHz%s | fov %s | dyn-scale OFF | %s" % [
        cached_refresh_rate,
        "" if refresh_extension_available else "*",
        str(foveation_supported),
        performance_state
    ]
