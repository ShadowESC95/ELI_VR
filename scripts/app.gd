extends Node3D

const AppConfigClass = preload("res://scripts/core/app_config.gd")
const RegistryClass = preload("res://scripts/core/registry.gd")
const CapabilityClass = preload("res://scripts/core/capability_detector.gd")
const NetworkPolicyClass = preload("res://scripts/core/network_policy.gd")
const RuntimeOptimizerClass = preload("res://scripts/core/runtime_optimizer.gd")
const EliLinkClass = preload("res://scripts/eli/eli_link.gd")
const EliPresenceClass = preload("res://scripts/eli/eli_presence.gd")
const EliVoiceClass = preload("res://scripts/eli/eli_voice.gd")
const EliSensesClass = preload("res://scripts/eli/eli_senses.gd")
const EliThingsClass = preload("res://scripts/eli/eli_things.gd")
const XRBootstrapClass = preload("res://scripts/xr/xr_bootstrap.gd")
const XRLocomotionClass = preload("res://scripts/xr/locomotion.gd")
const XRPointerClass = preload("res://scripts/xr/xr_pointer.gd")
const XRSessionPolicyClass = preload("res://scripts/xr/xr_session_policy.gd")
const FrontierHandClass = preload("res://scripts/xr/frontier_hand.gd")
const WristMenuClass = preload("res://scripts/xr/wrist_menu.gd")
const XRWorldManipulatorClass = preload("res://scripts/xr/world_manipulator.gd")
const XRControllerCalibrationClass = preload("res://scripts/xr/controller_calibration.gd")
const XRCalibrationWidgetClass = preload("res://scripts/xr/calibration_widget.gd")
const XRInputDiagnosticsClass = preload("res://scripts/xr/input_diagnostics.gd")
const XRStatusHUDClass = preload("res://scripts/xr/status_hud.gd")
const DesktopNavigationClass = preload("res://scripts/xr/desktop_navigation.gd")
const RoomFactoryClass = preload("res://scripts/world/room_factory.gd")
const RoomPortalClass = preload("res://scripts/world/portal.gd")
const SpatialConsoleClass = preload("res://scripts/world/spatial_console.gd")
const AmbientAudioManagerClass = preload("res://scripts/world/ambient_audio.gd")
const DesktopSurfaceClass = preload("res://scripts/desktop/desktop_surface.gd")
const ControlDockClass = preload("res://scripts/ui/control_dock.gd")
const PerformanceHudClass = preload("res://scripts/ui/performance_hud.gd")
const LicenceClass = preload("res://scripts/core/licence.gd")
const LicenceScreenClass = preload("res://scripts/ui/licence_screen.gd")

var config
var registry
var capabilities: Dictionary
var room_factory
var xr_bootstrap
var xr_active := false
var network_policy

var room_root: Node3D
var portal_root: Node3D
var console
var desktop_surface
var dock
var hud
var ambient_audio
var optimizer

var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var left_aim: XRController3D
var right_aim: XRController3D
var flat_camera: Camera3D
var xr_diagnostics
var left_hand_visual
var right_hand_visual
var wrist_menu
var controller_calibration
var calibration_widget
var _by_toggle_latched := false

var eli_link
var eli_presence
var eli_voice
var eli_senses
var eli_things
var _eli_mood: Dictionary = {}
var _eli_notice := ""
var _eli_notice_until_ms := 0
var _eli_say_pending := false
var _eli_mind: Dictionary = {}
var _talk_latched := false
var _exit_armed_until_ms := 0
var _eli_called_until_ms := 0

func _ready() -> void:
    if not _licensed():
        return
    config = AppConfigClass.new()
    config.load_all()

    registry = RegistryClass.new()
    registry.load_all()

    network_policy = NetworkPolicyClass.new()
    network_policy.configure(config)

    capabilities = CapabilityClass.new().detect()
    _apply_adaptive_hardware_profile()
    room_factory = RoomFactoryClass.new()

    room_root = Node3D.new()
    room_root.name = "Room"
    add_child(room_root)

    portal_root = Node3D.new()
    portal_root.name = "Portals"
    add_child(portal_root)

    _setup_view_rigs()
    _setup_desktop()
    _setup_ui()
    ambient_audio = AmbientAudioManagerClass.new(); ambient_audio.name = "AmbientAudio"; add_child(ambient_audio); ambient_audio.setup(config)
    optimizer = RuntimeOptimizerClass.new(); optimizer.name = "RuntimeOptimizer"; add_child(optimizer); optimizer.setup(self, config, xr_bootstrap.interface if xr_bootstrap else null)
    var session_policy = XRSessionPolicyClass.new(); session_policy.name = "XRSessionPolicy"; add_child(session_policy); session_policy.setup(self, config, xr_bootstrap.interface if xr_bootstrap else null)
    _apply_current_room()

    _setup_eli()
    _setup_eli_say()
    _setup_shot()
    if OS.get_environment("ELI_VR_LOG_FPS") == "1":
        var ticker := Timer.new()
        ticker.wait_time = 2.0
        ticker.autostart = true
        ticker.timeout.connect(func(): print("ELI VR FPS: %d" % Engine.get_frames_per_second()))
        add_child(ticker)

    print("ELI VR ready")
    print(JSON.stringify(capabilities, "\t"))

## An installed copy opens its rooms only with a licence; without one it asks for a key.
func _licensed() -> bool:
    if not LicenceClass.required():
        return true
    var got := LicenceClass.status()
    if LicenceClass.granted(got):
        return true
    print("ELI VR needs a licence: %s" % got.get("reason", ""))
    set_process(false)
    set_process_unhandled_key_input(false)
    if DisplayServer.get_name() == "headless":
        get_tree().quit(3)
        return false
    var screen = LicenceScreenClass.new()
    screen.name = "Licence"
    add_child(screen)
    screen.setup(got)
    screen.licensed.connect(func(): get_tree().reload_current_scene())
    return false

func _apply_adaptive_hardware_profile() -> void:
    if not bool(config.get_value("graphics.auto_quality", true)):
        return

    var requested: String = str(config.get_value("graphics.quality", "auto"))
    if requested != "auto":
        return

    var recommended: String = str(
        capabilities.get("recommended_quality", "medium")
    )
    if not config.apply_profile(recommended):
        return

    # Keep the semantic mode as AUTO while using the detected profile values
    # in memory. We intentionally do not save this hardware-specific result so
    # the same settings file can move between machines.
    config.set_value("graphics.quality", "auto/%s" % recommended)

func _setup_view_rigs() -> void:
    xr_origin = XROrigin3D.new()
    xr_origin.name = "XROrigin"
    add_child(xr_origin)

    xr_camera = XRCamera3D.new()
    xr_camera.name = "XRCamera"
    xr_origin.add_child(xr_camera)

    # Use grip_pose for the primary controller nodes. Input actions are bound
    # to the tracker, while grip pose is the most reliable physical-controller
    # pose across runtimes. Separate aim nodes are used for pointing.
    left_hand = XRController3D.new()
    left_hand.name = "LeftHandGrip"
    left_hand.tracker = "left_hand"
    left_hand.pose = "grip"
    xr_origin.add_child(left_hand)

    right_hand = XRController3D.new()
    right_hand.name = "RightHandGrip"
    right_hand.tracker = "right_hand"
    right_hand.pose = "grip"
    xr_origin.add_child(right_hand)

    left_aim = XRController3D.new()
    left_aim.name = "LeftHandAim"
    left_aim.tracker = "left_hand"
    left_aim.pose = "aim"
    xr_origin.add_child(left_aim)

    right_aim = XRController3D.new()
    right_aim.name = "RightHandAim"
    right_aim.tracker = "right_hand"
    right_aim.pose = "aim"
    xr_origin.add_child(right_aim)

    left_hand.tracking_changed.connect(func(tracking):
        print("ELI VR XR POSE: left grip tracking=", tracking)
    )
    right_hand.tracking_changed.connect(func(tracking):
        print("ELI VR XR POSE: right grip tracking=", tracking)
    )
    left_aim.tracking_changed.connect(func(tracking):
        print("ELI VR XR POSE: left aim tracking=", tracking)
    )
    right_aim.tracking_changed.connect(func(tracking):
        print("ELI VR XR POSE: right aim tracking=", tracking)
    )

    xr_bootstrap = XRBootstrapClass.new()
    xr_active = xr_bootstrap.initialize(config, get_viewport())

    if xr_active:
        xr_origin.position = Vector3(0,0,0)
        var locomotion = XRLocomotionClass.new()
        locomotion.setup(xr_origin,xr_camera,left_hand,right_hand,config,self)
        add_child(locomotion)

        var hand_accent: Color = Color(
            str(
                registry.theme(
                    str(config.get_value("world.theme","frontier"))
                ).get("accent","#63ddff")
            )
        )

        controller_calibration = XRControllerCalibrationClass.new()
        controller_calibration.name = "XRControllerCalibration"
        controller_calibration.setup(
            xr_origin,
            xr_camera,
            left_hand,
            right_hand,
            left_aim,
            right_aim,
            config
        )
        add_child(controller_calibration)

        left_hand_visual = FrontierHandClass.new()
        left_hand_visual.name = "LeftFrontierHand"
        left_hand_visual.setup(left_hand, "left", hand_accent)
        controller_calibration.left_grip_root.add_child(left_hand_visual)

        right_hand_visual = FrontierHandClass.new()
        right_hand_visual.name = "RightFrontierHand"
        right_hand_visual.setup(right_hand, "right", hand_accent)
        controller_calibration.right_grip_root.add_child(right_hand_visual)

        var left_ptr = XRPointerClass.new()
        left_ptr.name = "LeftPointer"
        left_ptr.setup(
            left_hand,
            left_aim,
            left_hand,
            controller_calibration.left_aim_root,
            controller_calibration.left_grip_root,
            left_hand_visual.pointer_socket
        )
        xr_origin.add_child(left_ptr)

        var right_ptr = XRPointerClass.new()
        right_ptr.name = "RightPointer"
        right_ptr.setup(
            right_hand,
            right_aim,
            right_hand,
            controller_calibration.right_aim_root,
            controller_calibration.right_grip_root,
            right_hand_visual.pointer_socket
        )
        xr_origin.add_child(right_ptr)

        if bool(config.get_value("world.object_manipulation", true)):
            var left_grabber = XRWorldManipulatorClass.new()
            left_grabber.name = "LeftWorldManipulator"
            left_grabber.setup(
                left_hand,
                left_aim,
                left_hand,
                controller_calibration.left_aim_root,
                controller_calibration.left_grip_root,
                left_hand_visual.pointer_socket
            )
            add_child(left_grabber)

            var right_grabber = XRWorldManipulatorClass.new()
            right_grabber.name = "RightWorldManipulator"
            right_grabber.setup(
                right_hand,
                right_aim,
                right_hand,
                controller_calibration.right_aim_root,
                controller_calibration.right_grip_root,
                right_hand_visual.pointer_socket
            )
            add_child(right_grabber)

        if bool(config.get_value("ui.wrist_menu", true)):
            wrist_menu = WristMenuClass.new()
            wrist_menu.name = "LeftWristMenu"
            wrist_menu.setup(
                self,
                left_hand,
                controller_calibration.left_grip_root,
                xr_camera,
                registry,
                config
            )
            xr_origin.add_child(wrist_menu)

        calibration_widget = XRCalibrationWidgetClass.new()
        calibration_widget.name = "XRCalibrationWidget"
        calibration_widget.setup(
            controller_calibration,
            left_hand,
            right_hand,
            xr_camera,
            hand_accent
        )
        xr_camera.add_child(calibration_widget)

        xr_diagnostics = XRInputDiagnosticsClass.new()
        xr_diagnostics.name = "XRInputDiagnostics"
        xr_diagnostics.setup(xr_camera, left_hand, right_hand, left_aim, right_aim)
        xr_diagnostics.visible = (
            bool(config.get_value("diagnostics.xr_input_overlay", false))
            and OS.get_environment("ELI_VR_XR_DIAGNOSTICS") == "1"
        )
        add_child(xr_diagnostics)
    else:
        xr_origin.visible = false
        flat_camera = Camera3D.new()
        flat_camera.name = "FlatCamera"
        flat_camera.position = Vector3(0,1.7,2.8)
        flat_camera.current = true
        add_child(flat_camera)
        var nav = DesktopNavigationClass.new()
        nav.setup(flat_camera)
        add_child(nav)

func _setup_desktop() -> void:
    desktop_surface = DesktopSurfaceClass.new()
    desktop_surface.name = "DesktopSurface"
    add_child(desktop_surface)
    desktop_surface.setup(config, xr_active, capabilities)

func _setup_ui() -> void:
    if xr_active:
        hud = XRStatusHUDClass.new()
        hud.name = "XRStatusHUD"
        hud.setup(self, xr_camera)
        add_child(hud)
        hud.visible = bool(config.get_value("ui.performance_hud", true))
    else:
        dock = ControlDockClass.new()
        dock.name = "ControlDock"
        dock.setup(self, registry, config)
        add_child(dock)
        dock.visible = bool(config.get_value("ui.desktop_dock", true))

        hud = PerformanceHudClass.new()
        hud.name = "PerformanceHUD"
        hud.setup(self)
        add_child(hud)
        hud.visible = bool(config.get_value("ui.performance_hud", true))

    if bool(config.get_value("world.spatial_console", true)):
        _rebuild_console()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F1:
            if dock: dock.visible = not dock.visible
        KEY_F2:
            set_desktop_enabled(not desktop_surface.visible)
        KEY_F3:
            if hud: hud.visible = not hud.visible
        KEY_F5:
            _apply_current_room()
        KEY_B:
            eli_build()
        KEY_Z:
            eli_undo()
        KEY_F6:
            if calibration_widget:
                calibration_widget.toggle()
        KEY_F7:
            if controller_calibration:
                controller_calibration.calibrate_hands()
        KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
    _process_eli_talk()
    if not xr_active:
        return
    var by_pressed := left_hand.is_button_pressed("by_button") or right_hand.is_button_pressed("by_button")
    if by_pressed and not _by_toggle_latched:
        set_spatial_console_enabled(not bool(config.get_value("world.spatial_console", true)))
    _by_toggle_latched = by_pressed

func apply_console_action(kind: String, value: String) -> void:
    match kind:
        "room": change_room(value)
        "environment": change_environment(value)
        "theme": change_theme(value)
        "quality": change_quality(value)
        "toggle":
            if value == "desktop":
                set_desktop_enabled(not desktop_surface.visible)
            elif value == "hud":
                if hud:
                    hud.visible = not hud.visible
                    config.set_value("ui.performance_hud", hud.visible)
                    config.save_runtime()
        "eli_model":
            eli_use_model(value)
        "eli":
            if value == "compose":
                eli_build()
            elif value == "undo":
                eli_undo()
        "system":
            if value == "calibration" and calibration_widget:
                calibration_widget.toggle()
            elif value == "reset_workspace":
                if console and console.has_method("reset_layout"):
                    console.reset_layout()
                if desktop_surface and desktop_surface.has_method("reset_workspace_transform"):
                    desktop_surface.reset_workspace_transform()
            elif value == "exit":
                request_exit()

func change_room(room_id: String) -> void:
    if not registry.rooms.has(room_id):
        return
    config.set_value("world.room", room_id)
    config.set_value("world.environment_override", "")
    config.save_runtime()
    reset_play_space()
    _apply_current_room()
    _tell_eli_where_we_are()

func change_environment(environment_id: String) -> void:
    if not environment_id.is_empty() and not registry.environments.has(environment_id):
        return
    config.set_value("world.environment_override", environment_id)
    config.save_runtime()
    reset_play_space()
    _apply_current_room()

func change_theme(theme_id: String) -> void:
    if not registry.themes.has(theme_id):
        return
    config.set_value("world.theme", theme_id)
    config.save_runtime()
    _apply_current_room()
    _rebuild_console()
    var hand_accent := Color(str(registry.theme(theme_id).get("accent","#63ddff")))
    if left_hand_visual: left_hand_visual.set_accent(hand_accent)
    if right_hand_visual: right_hand_visual.set_accent(hand_accent)
    if wrist_menu: wrist_menu.refresh_theme()

func change_quality(profile: String) -> void:
    if profile == "auto":
        config.set_value("graphics.auto_quality", true)
        config.set_value("graphics.quality", "auto")
        _apply_adaptive_hardware_profile()
        config.set_value("graphics.quality", "auto")
        config.save_runtime()
        _apply_current_room()
        return

    if not config.apply_profile(profile):
        return
    config.set_value("graphics.auto_quality", false)
    config.save_runtime()
    # XR render-target sizing is fixed before OpenXR startup in Godot 4.7.
    _apply_current_room()

func set_desktop_enabled(value: bool) -> void:
    config.set_value("desktop.enabled",value)
    config.save_runtime()
    if desktop_surface:
        desktop_surface.set_desktop_visible(value)
    if console and console.has_method("set_desktop_workspace"):
        console.set_desktop_workspace(value)

func set_portals_enabled(value: bool) -> void:
    config.set_value("world.portals",value)
    config.save_runtime()
    _build_portals()

func set_spatial_console_enabled(value: bool) -> void:
    config.set_value("world.spatial_console",value)
    config.save_runtime()
    if value:
        _rebuild_console()
    elif console:
        console.queue_free()
        console = null

func _apply_current_room() -> void:
    var room_id := str(config.get_value("world.room","core_room"))
    var room = registry.room(room_id)
    if room.is_empty():
        room_id = "core_room"
        room = registry.room(room_id)
    var env_id := str(config.get_value("world.environment_override",""))
    if env_id.is_empty():
        env_id = str(room.get("environment","core_station"))
    var theme = registry.theme(str(config.get_value("world.theme","cyan")))
    room_factory.build(room_root,env_id,theme,config)
    if ambient_audio: ambient_audio.play_environment(env_id)
    _build_portals()
    _apply_eli_mood()
    if eli_things:
        eli_things.show_room(room_id)
    _refresh_eli_presence()

func _build_portals() -> void:
    for child in portal_root.get_children():
        child.queue_free()
    if not bool(config.get_value("world.portals",true)):
        return
    var room = registry.room(str(config.get_value("world.room","core_room")))
    var targets: Array = room.get("portals",[])
    var accent := Color(str(registry.theme(str(config.get_value("world.theme","cyan"))).get("accent","#63ddff")))
    var positions := [
        Transform3D(Basis(Vector3.UP,deg_to_rad(-38)),Vector3(-4.0,0.2,-6.0)),
        Transform3D(Basis(Vector3.UP,0.0),Vector3(0.0,0.2,-7.0)),
        Transform3D(Basis(Vector3.UP,deg_to_rad(38)),Vector3(4.0,0.2,-6.0))
    ]
    for i in range(min(targets.size(),3)):
        var target := str(targets[i])
        var p = RoomPortalClass.new()
        p.setup_portal(str(registry.room(target).get("name",target)),target,accent)
        p.transform = positions[i]
        p.activated.connect(apply_console_action)
        portal_root.add_child(p)

func _rebuild_console() -> void:
    if console:
        console.queue_free()
    console = SpatialConsoleClass.new()
    console.name = "SpatialConsole"
    console.setup(self,registry,config)
    add_child(console)
    if console.has_method("set_desktop_workspace"):
        console.set_desktop_workspace(desktop_surface != null and desktop_surface.visible)
    if not _eli_mind.is_empty():
        _take_eli_mind(_eli_mind)

func current_environment_id() -> String:
    var room = registry.room(str(config.get_value("world.room","core_room")))
    var env_id := str(config.get_value("world.environment_override",""))
    if env_id.is_empty():
        env_id = str(room.get("environment","core_station"))
    return env_id

func reset_play_space() -> void:
    if xr_origin:
        xr_origin.position = Vector3.ZERO
        xr_origin.rotation = Vector3.ZERO
    if flat_camera:
        flat_camera.position = Vector3(0,1.7,2.8)

func current_room_name() -> String:
    var room = registry.room(str(config.get_value("world.room","core_room")))
    return str(room.get("name","Unknown"))

func current_environment_name() -> String:
    var room = registry.room(str(config.get_value("world.room","core_room")))
    var env_id := str(config.get_value("world.environment_override",""))
    if env_id.is_empty():
        env_id = str(room.get("environment","core_station"))
    return str(registry.environment(env_id).get("name",env_id))

func desktop_status() -> String:
    if not desktop_surface or not desktop_surface.visible:
        return "OFF"
    return desktop_surface.bridge_status()

# --- ELI ---------------------------------------------------------------------
# Only when the link is switched on. Standalone, none of this exists.

func _setup_eli() -> void:
    eli_link = EliLinkClass.new()
    eli_link.name = "EliLink"
    add_child(eli_link)
    eli_link.configure(config, network_policy)
    if not eli_link.enabled:
        return

    eli_presence = EliPresenceClass.new()
    eli_presence.name = "EliPresence"
    add_child(eli_presence)
    eli_presence.setup(_theme_accent())

    eli_things = EliThingsClass.new()
    eli_things.name = "EliThings"
    add_child(eli_things)
    eli_things.show_room(_current_room_id())
    eli_things.moved_by_hand.connect(_on_eli_thing_moved)

    eli_senses = EliSensesClass.new()
    eli_senses.name = "EliSenses"
    add_child(eli_senses)
    eli_senses.setup(self, eli_link, eli_presence, eli_things)

    if bool(config.get_value("eli_bridge.voice", true)):
        eli_voice = EliVoiceClass.new()
        eli_voice.name = "EliVoice"
        add_child(eli_voice)
        eli_voice.setup(eli_link, eli_presence)
        eli_voice.state_changed.connect(_on_eli_voice_state)
        eli_voice.heard.connect(func(_text): eli_senses.report_now())
        eli_voice.failed.connect(_on_eli_failed)
        eli_voice.built.connect(_on_eli_built)

    eli_link.world_state_received.connect(_on_eli_world_state)
    eli_link.link_changed.connect(_on_eli_link_changed)
    _refresh_eli_presence()

func _theme_accent() -> Color:
    var theme: Dictionary = registry.theme(str(config.get_value("world.theme", "frontier")))
    return Color(str(theme.get("accent", "#63ddff")))

func _current_room_id() -> String:
    return str(config.get_value("world.room", "core_room"))

func _on_eli_link_changed(connected: bool) -> void:
    eli_presence.set_mode("idle" if connected else "dormant")
    if connected and eli_link.can("mind") and _eli_mind.is_empty():
        _settle_eli_mind()
    elif not connected:
        _eli_mind = {}
    if connected:
        eli_link.send_event("vr_session_started", "The user opened ELI VR", {"xr": xr_active})
        _tell_eli_where_we_are()
    _refresh_eli_presence()

func _on_eli_world_state(state: Dictionary) -> void:
    eli_presence.apply_world_state(state)
    eli_things.apply_world_state(state)
    var spaces: Dictionary = state.get("spaces", {})
    var own: Dictionary = spaces.get("own_room", {})
    if own.has("mood"):
        _eli_mood = own["mood"]
        _apply_eli_mood()
    _refresh_eli_presence()

# ELI's own room is drawn the way ELI's world says ELI made it.
func _apply_eli_mood() -> void:
    if _eli_mood.is_empty() or room_root == null:
        return
    for room in room_root.get_children():
        if room.has_method("apply_mood") and not room.is_queued_for_deletion():
            room.apply_mood(_eli_mood)

func current_room_id() -> String:
    return _current_room_id()

# --- ELI's mind -----------------------------------------------------------------
# No model is assumed. ELI says which models it has; the one already loaded is
# used as it is (opened from ELI's window, that is the one in use there). Only
# when nothing is loaded yet is the model kept in ELI VR's settings asked for,
# and a model named on the command line is always asked for.

func _settle_eli_mind() -> void:
    var result = await eli_link.mind()
    if not result.ok:
        return
    _take_eli_mind(result.payload)
    var asked := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--eli-model="):
            asked = arg.trim_prefix("--eli-model=")     # this run only, never saved
    var kept := str(config.get_value("eli_bridge.model", ""))
    var loaded := bool(_eli_mind.get("loaded", false))
    if not asked.is_empty():
        await eli_use_model(asked, false)
    elif not loaded and not kept.is_empty() and kept != str(_eli_mind.get("model", "")):
        await eli_use_model(kept, false)

func _take_eli_mind(mind: Dictionary) -> void:
    _eli_mind = mind
    print("ELI mind: %s%s, %d to choose from" % [
        str(mind.get("model", "")) if not str(mind.get("model", "")).is_empty() else "none",
        "" if bool(mind.get("loaded", false)) else " (not loaded yet)", (mind.get("models", []) as Array).size()])
    if console and console.has_method("show_mind"):
        console.show_mind(mind.get("models", []), str(mind.get("model", "")), bool(mind.get("loaded", false)))

# Choose ELI's model from inside the room. ELI loads it before answering.
func eli_use_model(model_name: String, remember: bool = true) -> void:
    if eli_link == null or not eli_link.can("mind"):
        _eli_say_briefly("this ELI v3 cannot change model from here")
        return
    _eli_say_briefly("loading %s" % model_name.trim_suffix(".gguf"), 600.0)
    var result = await eli_link.use_model(model_name)
    if not result.ok:
        _eli_say_briefly("%s%s" % [result.sentence(), "" if result.detail.is_empty() else ": " + result.detail.left(60)], 12.0)
        return
    _take_eli_mind(result.payload)
    _eli_say_briefly("mind: %s" % model_name.trim_suffix(".gguf"))
    if remember:
        config.set_value("eli_bridge.model", model_name)
        config.save_runtime()

# The model ELI is using, for the status line: never a surprise.
func eli_mind_name() -> String:
    var model_name := str(_eli_mind.get("model", "")).trim_suffix(".gguf")
    if model_name.is_empty():
        return "NO MODEL CHOSEN" if not _eli_mind.is_empty() else ""
    return model_name if bool(_eli_mind.get("loaded", false)) else "%s (NOT LOADED YET)" % model_name

# --- ELI building ---------------------------------------------------------------

# Something for the status line for a few seconds: what ELI made, or why not.
func _eli_say_briefly(text: String, seconds: float = 7.0) -> void:
    _eli_notice = text
    _eli_notice_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
    if eli_presence:
        eli_presence.note(text, seconds)

func _on_eli_failed(result) -> void:
    _eli_say_briefly(result.sentence())

func _on_eli_built(reply: Dictionary) -> void:
    var done := []
    for result in reply.get("results", []):
        if bool(result.get("ok", false)):
            var what := str(result.get("name", ""))
            done.append(what if not what.is_empty() else str(result.get("op", "")))
    if not done.is_empty():
        _eli_say_briefly("made: %s" % ", ".join(done))

# ELI makes one thing in its own room, unasked.
func eli_build() -> void:
    if eli_link == null or not eli_link.can("building"):
        _eli_say_briefly("ELI cannot build from here" if eli_link and eli_link.connected else "ELI is not running")
        return
    _eli_say_briefly("building...", 60.0)
    eli_senses.report_now()
    var result = await eli_link.compose()
    if not result.ok:
        _on_eli_failed(result)
        return
    var reply: Dictionary = result.payload
    _on_eli_built(reply)
    var words := str(reply.get("text", ""))
    if not words.is_empty() and eli_voice != null and eli_voice.state == "idle":
        var speech = await eli_link.speak(words)
        if speech.ok:
            eli_presence.set_mode("speaking")
            await eli_presence.say(speech.payload)
            eli_presence.set_mode("idle")

func eli_undo() -> void:
    if eli_link == null or not eli_link.can("undo"):
        return
    var result = await eli_link.undo()
    if not result.ok:
        _on_eli_failed(result)
    else:
        _eli_say_briefly("taken back" if bool(result.payload.get("ok", false)) else "nothing to take back")

# The user moved one of ELI's things by hand: ELI's world is told where the thing stands.
func _on_eli_thing_moved(thing_id: String, at: Vector3) -> void:
    var pos: Array = EliSensesClass.to_protocol(at)
    var result = await eli_link.edit(
        [{"op": "move", "id": thing_id, "at": [pos[0], pos[2]], "height": pos[1]}],
        _current_room_id(), "The user moved it by hand")
    if not result.ok:
        _on_eli_failed(result)

func _on_eli_voice_state(state: String) -> void:
    eli_presence.set_mode(state if eli_link.connected else "dormant")
    if state != "idle":
        _eli_called_until_ms = Time.get_ticks_msec() + 60000
    _refresh_eli_presence()

func _tell_eli_where_we_are() -> void:
    if eli_link == null or not eli_link.connected:
        return
    if eli_senses:
        eli_senses.report_now()
    eli_link.send_event(
        "vr_room_entered",
        "The user entered the %s in ELI VR" % current_room_name(),
        {"room": _current_room_id()}
    )

# ELI is shown in the room its own world puts it in. Speaking to it brings
# it to you for a minute.
func _refresh_eli_presence() -> void:
    if eli_presence == null:
        return
    eli_presence.set_accent(_theme_accent())
    var called := Time.get_ticks_msec() < _eli_called_until_ms
    eli_presence.visible = called or eli_presence.eli_room == _current_room_id()

# Hold A/X on a controller, or T on the keyboard, to talk.
func _process_eli_talk() -> void:
    if eli_voice == null:
        return
    var held := Input.is_key_pressed(KEY_T)
    if xr_active and left_hand and right_hand:
        held = held or left_hand.is_button_pressed("ax_button") or right_hand.is_button_pressed("ax_button")
    if held and not _talk_latched:
        eli_voice.start_listening()
    elif not held and _talk_latched:
        eli_voice.stop_listening()
    _talk_latched = held

func eli_status() -> String:
    if eli_link == null or not eli_link.enabled:
        return ""
    if Time.get_ticks_msec() < _eli_notice_until_ms:
        return "ELI: %s" % _eli_notice.to_upper()
    var trouble: String = eli_link.status()
    if not trouble.is_empty():
        return trouble.to_upper()
    if eli_voice != null and eli_voice.state != "idle":
        return "ELI %s" % eli_voice.state.to_upper()
    var mind_name := eli_mind_name()
    var with_mind := "" if mind_name.is_empty() else " · %s" % mind_name.to_upper()
    if eli_presence.eli_room == _current_room_id():
        return "ELI HERE%s" % with_mind
    var room: Dictionary = registry.room(eli_presence.eli_room)
    return "ELI IN %s" % str(room.get("name", eli_presence.eli_room)).to_upper()

# --- leaving -----------------------------------------------------------------
# A stray trigger pull should not end the session: the first press arms the
# button for a few seconds, the second one leaves.

func request_exit() -> void:
    if Time.get_ticks_msec() < _exit_armed_until_ms:
        quit_app()
        return
    _exit_armed_until_ms = Time.get_ticks_msec() + 4000

func exit_notice() -> String:
    return "PRESS EXIT AGAIN TO CLOSE" if Time.get_ticks_msec() < _exit_armed_until_ms else ""

# The launcher that started us is waiting for this process to end; it then
# stops the VR runtime and the desktop helper it started.
func quit_app() -> void:
    if eli_link != null and eli_link.connected:
        eli_link.send_event("vr_session_ended", "The user closed ELI VR", {})
        await get_tree().process_frame
        await get_tree().process_frame
    if desktop_surface and desktop_surface.has_method("set_desktop_visible"):
        desktop_surface.set_desktop_visible(false)
    print("ELI VR closing")
    get_tree().quit()

# --- pictures ----------------------------------------------------------------
# --eli-shot=<file.png> lets the room settle, saves what the flat camera sees
# and quits. --eli-shot-view=x,y,z,yaw,pitch places the camera; several views
# separated by ";" give one picture each. For the README pictures, and for
# looking at a room without putting the headset on. --eli-shot-clean leaves
# out the control panels, portals and desktop screen.

# --eli-say="..." sends one sentence to ELI as if it had been spoken, once the
# link is up. For trying the link, and the building, without a microphone.
func _setup_eli_say() -> void:
    var said := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--eli-say="):
            said = arg.trim_prefix("--eli-say=")
    if said.is_empty() or eli_voice == null:
        return
    _eli_say_pending = true
    var waited := 0.0
    while not eli_link.connected or eli_link.protocol == 0:
        await get_tree().create_timer(0.25).timeout
        waited += 0.25
        if waited > 30.0:
            print("ELI: %s" % eli_link.status())
            _eli_say_pending = false
            return
    eli_senses.report_now()
    for sentence in said.split("|"):
        sentence = sentence.strip_edges()
        if sentence == "@build":            # what the ELI: BUILD button does
            await eli_build()
        elif sentence == "@undo":
            await eli_undo()
        elif sentence == "@wait":
            await get_tree().create_timer(2.0).timeout
        else:
            eli_voice.heard.connect(func(text): print("ELI heard: %s" % text), CONNECT_ONE_SHOT)
            eli_voice.replied.connect(func(text): print("ELI said: %s" % text), CONNECT_ONE_SHOT)
            await eli_voice.converse_text(sentence)
        await get_tree().create_timer(1.0).timeout
    print("ELI say: done")
    _eli_say_pending = false

func _setup_shot() -> void:
    var path := ""
    var views := PackedStringArray()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--eli-shot="):
            path = arg.get_slice("=", 1)
        elif arg.begins_with("--eli-shot-view="):
            views = arg.get_slice("=", 1).split(";", false)
    if path.is_empty() or flat_camera == null:
        return
    if DisplayServer.get_name() == "headless":
        push_warning("ELI VR: --eli-shot needs a real display; nothing was saved.")
        return
    if dock: dock.visible = false
    if hud: hud.visible = false
    if "--eli-shot-clean" in OS.get_cmdline_user_args():
        # the room alone, without the panels, portals and screen in front of it
        if console: console.visible = false
        if portal_root: portal_root.visible = false
        if desktop_surface: desktop_surface.visible = false
    if views.is_empty():
        views = PackedStringArray([""])

    await get_tree().create_timer(3.0).timeout
    # with --eli-say, the picture is of what came of it
    while _eli_say_pending:
        await get_tree().create_timer(0.5).timeout
    if "--eli-say=" in " ".join(OS.get_cmdline_user_args()):
        await get_tree().create_timer(4.0).timeout
    for i in views.size():
        var v := views[i].split_floats(",")
        if v.size() >= 3:
            flat_camera.position = Vector3(v[0], v[1], v[2])
        if v.size() >= 5:
            flat_camera.rotation_degrees = Vector3(v[4], v[3], 0.0)
        await get_tree().create_timer(0.4).timeout
        await RenderingServer.frame_post_draw
        var file := path if views.size() == 1 else "%s_%d.png" % [path.trim_suffix(".png"), i + 1]
        get_viewport().get_texture().get_image().save_png(file)
        print("ELI VR picture saved: %s" % file)
    get_tree().quit()
