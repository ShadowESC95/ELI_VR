class_name EliSenses
extends Node

# What ELI can know of the room while you are in it with him. Every few
# seconds, and just before you speak, this tells ELI v3 where you are standing,
# what the place is, what you are looking at, whether he is there with you and
# what of his is near. ELI keeps it only while it is fresh, and it is how he
# can answer "where are we" or "what am I looking at".
#
# Positions go out as [right, up, forward] in metres from the middle of the
# room's floor, the same way round as the things he builds.

const EVERY_SECONDS := 5.0
const LOOK_DEGREES := 14.0

var app
var link
var presence
var things

var _wait := 1.0
var _started_ms := 0

func setup(p_app, p_link, p_presence, p_things) -> void:
    app = p_app
    link = p_link
    presence = p_presence
    things = p_things
    _started_ms = Time.get_ticks_msec()

func _process(delta: float) -> void:
    if link == null or not link.can("scene"):
        return
    _wait -= delta
    if _wait <= 0.0:
        report_now()

func report_now() -> void:
    _wait = EVERY_SECONDS
    if link != null and link.can("scene"):
        link.report_scene(scene())

static func to_protocol(at: Vector3) -> Array:
    return [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(-at.z, 0.01)]

static func from_protocol(pos: Array) -> Vector3:
    return Vector3(float(pos[0]), float(pos[1]), -float(pos[2]))

func scene() -> Dictionary:
    var camera := get_viewport().get_camera_3d()
    var eye := camera.global_position if camera else Vector3(0, 1.7, 0)
    var gaze := -camera.global_transform.basis.z if camera else Vector3.FORWARD
    var place: Dictionary = app.registry.environment(app.current_environment_id())

    var eli_here: bool = presence != null and presence.visible and presence.mode != "dormant"
    var out := {
        "surface": link.SURFACE,
        "session": link.session_id(),
        "room": app.current_room_id(),
        "room_name": app.current_room_name(),
        "place": app.current_environment_id(),
        "place_name": str(place.get("name", "")),
        "seen_as": str(place.get("seen_as", "")),
        "headset": bool(app.xr_active),
        "screen": app.desktop_surface != null and app.desktop_surface.visible,
        "minutes": snappedf(float(Time.get_ticks_msec() - _started_ms) / 60000.0, 0.1),
        "user": {
            "pos": to_protocol(eye),
            "facing": [snappedf(gaze.x, 0.001), snappedf(-gaze.z, 0.001)],
            "looking_at": _looking_at(eye, gaze, eli_here),
        },
        "eli": {
            "visible": eli_here,
            "pos": to_protocol(presence.global_position) if eli_here else null,
            "distance": snappedf(eye.distance_to(presence.global_position), 0.1) if eli_here else 0.0,
        },
        "things": things.near(eye, 10) if things != null else [],
    }
    return out

# The nearest thing to the middle of the user's view, if anything is in it.
func _looking_at(eye: Vector3, gaze: Vector3, eli_here: bool) -> Dictionary:
    var best := {"kind": "room", "name": app.current_environment_name()}
    var closest := deg_to_rad(LOOK_DEGREES)
    if eli_here:
        var to_eli := gaze.angle_to(presence.global_position - eye)
        if to_eli < closest:
            closest = to_eli
            best = {"kind": "eli", "name": "ELI"}
    if things != null:
        for thing in things.standing():
            var angle := gaze.angle_to(thing.global_position + Vector3(0, thing.eye_height(), 0) - eye)
            if angle < closest:
                closest = angle
                best = {"kind": "object", "name": thing.label}
    if best["kind"] == "room" and app.desktop_surface != null and app.desktop_surface.visible:
        if gaze.angle_to(app.desktop_surface.global_position - eye) < deg_to_rad(22.0):
            best = {"kind": "screen", "name": "the desktop screen"}
    return best
