class_name XRStatusHUD
extends Node3D

var app: Node
var label: Label3D
var elapsed: float = 0.0

func setup(p_app: Node, camera: XRCamera3D) -> void:
    app = p_app
    label = Label3D.new()
    label.name = "XRStatusLabel"
    label.font_size = 18
    label.pixel_size = 0.00092
    label.outline_size = 6
    label.modulate = Color("#dff8ff")
    label.position = Vector3(0.62, 0.32, -1.12)
    label.no_depth_test = true
    camera.add_child(label)

func _process(delta: float) -> void:
    if label == null or app == null:
        return

    elapsed += delta
    if elapsed < 0.25:
        return
    elapsed = 0.0

    var quality: String = str(app.config.get_value("graphics.quality", "auto"))
    var tier: String = str(app.capabilities.get("hardware_class", "unknown"))
    var desktop: String = str(app.desktop_status())

    label.text = (
        "ELI VR\n"
        + "%d FPS  •  %s\n" % [Engine.get_frames_per_second(), tier.to_upper()]
        + "%s\n" % str(app.current_environment_name())
        + "QUALITY %s  •  DESKTOP %s" % [quality.to_upper(), desktop]
    )
