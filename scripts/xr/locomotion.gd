class_name XRLocomotion
extends Node

var origin: XROrigin3D
var head: XRCamera3D
var left: XRController3D
var right: XRController3D
var config
var app: Node
var snap_ready: bool = true
var snap_timer: float = 0.0

func setup(
    p_origin: XROrigin3D,
    p_head: XRCamera3D,
    p_left: XRController3D,
    p_right: XRController3D,
    p_config,
    p_app: Node
) -> void:
    origin = p_origin
    head = p_head
    left = p_left
    right = p_right
    config = p_config
    app = p_app

func _process(delta: float) -> void:
    if (
        app != null
        and app.get("calibration_widget") != null
        and bool(app.get("calibration_widget").visible)
    ):
        return

    if not bool(config.get_value("xr.smooth_locomotion", true)):
        return

    var universal_flight: bool = bool(
        config.get_value("xr.universal_flight", true)
    )
    var stick: Vector2 = left.get_vector2("primary") if left else Vector2.ZERO
    var left_grabbing: bool = (
        left.is_button_pressed("grip_click") if left else false
    )

    if stick.length() > 0.15 and not left_grabbing:
        var speed: float = (
            float(config.get_value("xr.fly_speed", 4.5))
            if universal_flight
            else float(config.get_value("xr.move_speed", 2.0))
        )

        var boost: bool = (
            left.is_button_pressed("primary_click") if left else false
        )
        if boost:
            speed *= float(config.get_value("xr.boost_multiplier", 2.4))

        var forward: Vector3 = -head.global_transform.basis.z
        var right_v: Vector3 = head.global_transform.basis.x

        if not universal_flight:
            forward.y = 0.0
            right_v.y = 0.0

        forward = forward.normalized()
        right_v = right_v.normalized()
        origin.global_position += (
            forward * -stick.y + right_v * stick.x
        ) * speed * delta

    snap_timer -= delta
    if snap_timer <= 0.0:
        snap_ready = true

    var turn: Vector2 = right.get_vector2("primary") if right else Vector2.ZERO
    var right_grabbing: bool = (
        right.is_button_pressed("grip_click") if right else false
    )

    if universal_flight and not right_grabbing and absf(turn.y) > 0.18:
        var vertical_speed: float = (
            float(config.get_value("xr.fly_speed", 4.5)) * 0.70
        )
        origin.global_position.y += -turn.y * vertical_speed * delta

    if not right_grabbing and snap_ready and absf(turn.x) > 0.72:
        var deg: float = float(
            config.get_value("xr.snap_turn_degrees", 30)
        )
        origin.rotate_y(deg_to_rad(-deg if turn.x > 0.0 else deg))
        snap_ready = false
        snap_timer = float(
            config.get_value("xr.turn_cooldown_seconds", 0.30)
        )
