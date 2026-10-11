class_name XRBootstrap
extends RefCounted

var interface: XRInterface
var active := false

func initialize(config, viewport: Viewport) -> bool:
    var mode := str(config.get_value("xr.mode", "auto")).to_lower()
    if mode == "off":
        active = false
        return false

    interface = XRServer.find_interface("OpenXR")
    if interface == null:
        active = false
        return false

    # With OpenXR enabled in project.godot, Vulkan/mobile initializes at startup.
    # Compatibility/OpenGL runtimes may allow initialize() here.
    if not interface.is_initialized():
        interface.initialize()

    if interface.is_initialized():
        viewport.use_xr = true
        active = true
        # Godot 4.7 requires render_target_size_multiplier to be chosen
        # before OpenXR initializes; scene code runs too late to change it.
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        return true

    if mode == "on":
        push_warning("ELI VR: XR was forced on but OpenXR did not initialize; falling back to flat mode.")
    active = false
    return false
