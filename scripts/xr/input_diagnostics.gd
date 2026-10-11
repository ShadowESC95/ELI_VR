class_name XRInputDiagnostics
extends Node3D

var left: XRController3D
var right: XRController3D
var left_aim: XRController3D
var right_aim: XRController3D
var label: Label3D
var elapsed := 0.0
var last_event := "waiting for controller input"

func setup(
    camera: XRCamera3D,
    p_left: XRController3D,
    p_right: XRController3D,
    p_left_aim: XRController3D,
    p_right_aim: XRController3D
) -> void:
    left = p_left
    right = p_right
    left_aim = p_left_aim
    right_aim = p_right_aim

    label = Label3D.new()
    label.text = "ELI VR // TOUCH INPUT"
    label.font_size = 25
    label.pixel_size = 0.00115
    label.outline_size = 7
    label.modulate = Color("#d9f7ff")
    label.position = Vector3(0.0, -0.42, -1.25)
    label.no_depth_test = true
    camera.add_child(label)

    _connect_controller(left, "L")
    _connect_controller(right, "R")

func _connect_controller(controller: XRController3D, side: String) -> void:
    if controller == null:
        return

    controller.button_pressed.connect(func(action_name):
        last_event = "%s button: %s" % [side, str(action_name)]
        print("ELI VR XR INPUT: ", last_event)
        if str(action_name) == "trigger_click":
            controller.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.045, 0.0)
    )

    controller.input_float_changed.connect(func(action_name, value):
        if abs(float(value)) > 0.05:
            last_event = "%s %s %.2f" % [side, str(action_name), float(value)]
    )

    controller.input_vector2_changed.connect(func(action_name, value):
        if value.length() > 0.15:
            last_event = "%s %s (%.2f, %.2f)" % [
                side,
                str(action_name),
                value.x,
                value.y
            ]
    )

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.10 or label == null:
        return
    elapsed = 0.0

    label.text = "ELI VR // TOUCH INPUT\n%s\n%s\n%s" % [
        _line("L", left, left_aim),
        _line("R", right, right_aim),
        last_event
    ]

func _line(side: String, grip: XRController3D, aim: XRController3D) -> String:
    if grip == null:
        return "%s missing" % side

    var stick := grip.get_vector2("primary")
    var grip_state := _pose_state(grip)
    var aim_state := _pose_state(aim)

    return "%s grip[%s]:%s aim[%s]:%s stick:%+.2f,%+.2f trg:%.2f g:%.2f" % [
        side,
        str(grip.pose),
        grip_state,
        str(aim.pose) if aim != null else "-",
        aim_state,
        stick.x,
        stick.y,
        grip.get_float("trigger"),
        grip.get_float("grip")
    ]

func _pose_state(node: XRController3D) -> String:
    if node == null:
        return "-"
    if node.get_has_tracking_data():
        return "TRACK"
    if node.get_is_active():
        return "ACTIVE"
    return "OFF"
