class_name EliArm
extends EliThing

# A gun of ELI's range: one of ELI's things (a piece of the range game, role arm) that lies on the
# gun table until the grip closes on it, then sits in that hand and points where the hand points.
# EliPlay fires it by the rules ELI's world set for it (eli/world/games.py ARMS): a shot, a bolt, a
# beam or a rail. This draws it (EliArms), shows its flash, tracers and beam, and plays its sound.

const FLASH_SECONDS := 0.06
const TRACER_SECONDS := 0.05

var muzzle := Vector3(0, 0.05, -0.2)         # where shots leave, in the body's space
var length := 0.3
var wielded := false                          # in a hand right now
var home := Vector3.ZERO                      # where it lay on the table
var _flash: MeshInstance3D
var _muzzle_left := 0.0           # how long the flash at the muzzle has left
var _tracer: MeshInstance3D
var _tracer_left := 0.0
var _beam: MeshInstance3D
var _player: AudioStreamPlayer3D
var _charging: MeshInstance3D

func _shape() -> void:
    if shape != "arm":
        super._shape()
        return
    for child in _body.get_children():
        child.queue_free()
    lamp = null
    _moving.clear()
    _material = null
    _name_tag.visible = true
    _name_tag.font_size = 30
    var built := EliArms.build(_body, str(piece.get("tag", "")), colour)
    muzzle = built["muzzle"]
    length = float(built["length"])
    _made_height = 0.14
    _flash = MaterialKit.halo(colour.lightened(0.5), 0.22, 2.5, 1.0)
    _flash.position = muzzle
    _flash.visible = false
    _body.add_child(_flash)
    _charging = MaterialKit.halo(colour, 0.14, 1.5, 0.6)
    _charging.position = muzzle
    _charging.visible = false
    _body.add_child(_charging)
    if _player == null:
        _player = AudioStreamPlayer3D.new()
        _player.unit_size = 4.0
        _player.volume_db = -4.0
        add_child(_player)
    _player.position = muzzle

func refresh(data: Dictionary, first: bool = false) -> void:
    super.refresh(data, first)
    if not wielded and not driven:
        home = _target
    if wielded:
        _body.rotation = Vector3.ZERO           # in the hand the body lies along the hand, not the table

## The grip is closed on it: the world manipulator calls this each frame with where the hand is and
## which way it points. The gun sits in the hand, lying along the aim.
func hold(origin: Vector3, direction: Vector3, _stick: Vector2, _delta: float) -> void:
    wielded = true
    _held = true
    var up := Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.FORWARD
    global_transform = Transform3D(Basis.looking_at(direction.normalized(), up), origin)
    _body.rotation = Vector3.ZERO
    _target = global_position

func end_grab() -> void:
    wielded = false
    beam_off()
    _charging.visible = false
    super.end_grab()
    _body.rotation.y = deg_to_rad(180.0 - turn)

## Back onto the table where it lay, lying as it lay.
func go_home() -> void:
    basis = Basis.IDENTITY
    _body.rotation = Vector3(0.0, deg_to_rad(180.0 - turn), 0.0)
    drive(home)

## Where a shot leaves, and which way: {"from": Vector3, "dir": Vector3}, in the world. From the
## body's turn alone: while a thing grows in, its body is still scaled, and the muzzle is not.
func aim() -> Dictionary:
    var turned: Quaternion = _body.quaternion
    return {"from": to_global(turned * muzzle), "dir": (global_basis * (turned * Vector3.FORWARD)).normalized()}

## A shot fired: the flash at the muzzle, the sound, and a tracer to `to` when there is one.
func fired(fire: String, to: Vector3 = Vector3.INF) -> void:
    _flash.visible = true
    _muzzle_left = FLASH_SECONDS
    if _player != null:
        _player.stream = EliArms.sound(fire)
        _player.play()
    if to.is_finite():
        _line(to, 0.006, colour.lightened(0.6), TRACER_SECONDS)

## A beam lance firing: its beam from the muzzle to `to`, held while the trigger is.
func beam_to(to: Vector3) -> void:
    if _beam == null:
        _beam = _line(to, 0.012, colour.lightened(0.3), 0.0)
        _beam.name = "Beam"
        if _player != null and (_player.stream == null or not _player.playing):
            _player.stream = EliArms.sound("beam")
            _player.play()
    else:
        _lay_along(_beam, aim()["from"], to)

func beam_off() -> void:
    if _beam != null:
        _beam.queue_free()
        _beam = null
        if _player != null and _player.stream == EliArms.sound("beam"):
            _player.stop()

## A rail gun charging: a growing light at the muzzle, `share` of the way to firing.
func charging(share: float) -> void:
    _charging.visible = share > 0.0
    _charging.scale = Vector3.ONE * (0.4 + 1.6 * clampf(share, 0.0, 1.0))
    if share > 0.0 and _player != null and _player.stream != EliArms.sound("rail"):
        _player.stream = EliArms.sound("rail")
        _player.play()

func _line(to: Vector3, radius: float, tint: Color, seconds: float) -> MeshInstance3D:
    var line := MeshInstance3D.new()
    var rod := CylinderMesh.new()
    rod.top_radius = radius
    rod.bottom_radius = radius
    rod.height = 1.0
    rod.radial_segments = 6
    line.mesh = rod
    line.material_override = MaterialKit.light(tint, 3.0)
    line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    line.top_level = true
    add_child(line)
    _lay_along(line, aim()["from"], to)
    if seconds > 0.0:
        _tracer = line
        _tracer_left = seconds
    return line

# A rod laid from `from` to `to` in the world.
func _lay_along(line: MeshInstance3D, from: Vector3, to: Vector3) -> void:
    var along := to - from
    if along.length() < 0.001:
        return
    line.global_position = (from + to) * 0.5
    line.global_basis = Basis(Quaternion(Vector3.UP, along.normalized()))
    line.scale = Vector3(1.0, along.length(), 1.0)

func _process(delta: float) -> void:
    super._process(delta)
    if _muzzle_left > 0.0:
        _muzzle_left -= delta
        if _muzzle_left <= 0.0:
            _flash.visible = false
    if _tracer_left > 0.0:
        _tracer_left -= delta
        if _tracer_left <= 0.0 and is_instance_valid(_tracer):
            _tracer.queue_free()
            _tracer = null
