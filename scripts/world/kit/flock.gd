extends MultiMeshInstance3D

# Birds in flight, drawn as one batch (a MultiMesh of MeshKit.bird). Each flies by the three rules
# of a flock (Reynolds' boids): keep clear of the nearest, go the way the near ones go, keep near
# them; and by its own: hold its kind's cruising speed, stay in its kind's band of height over the
# surface below (the sea, the ground: the room says where that is), stay out past `keep_out` from
# the middle of where it flies and turn back before `roam`, and wander a little on its own. It
# banks into its turns the way a bird does, its wings tilted so their lift points along what it
# needs to turn and stay up (the turn's acceleration plus gravity), and it pitches with its climb.
# It flaps in bouts and glides between them, flapping when it climbs or has slowed; the wing beat
# itself is in the vertex shader (bird.gdshader), each bird at its own phase and pace. Nothing is
# allocated per frame: positions and velocities live in packed arrays and the batch is written in place.

const MeshKitClass = preload("res://scripts/world/kit/mesh_kit.gd")
const MaterialKitClass = preload("res://scripts/world/kit/material_kit.gd")
const GRAVITY := 9.81
const MAX_PATH_SLOPE := 0.36            # tan 20°: the steepest a bird climbs or sinks in level flight

# What each kind of bird is (true figures for the bird, not tuning): its span tip to tip (m); its
# shape (MeshKit.bird: body rings [t, half width, half height] as shares of its length; the wing's
# leading and trailing edge as shares of the span at stations out along it, 0 at the shoulder and
# 1 at the tip; where the wrist is; where the dark tips begin; the plumage, in linear colour); how
# it flies: cruising speed and its range (m/s), wing beats a second, the most it can turn or climb
# (m/s², which sets how far it banks), its band of height over the surface below (m), and how
# long its bouts of flapping and of gliding last (s).
const KINDS := {
    # a large gull (herring gull): long narrow wings with a crooked wrist and black tips, white
    # head and body, grey back
    "gull": {
        "span": 1.35, "cruise": 10.5, "slowest": 8.0, "fastest": 14.0, "beats": 3.0, "turn": 6.0,
        "band": Vector2(4.0, 30.0), "flapping": Vector2(1.2, 3.0), "gliding": Vector2(2.5, 7.0),
        "glide_arm": 0.17, "glide_hand": -0.42, "arm_beat": 0.62, "hand_beat": 0.5,
        "shape": {
            "length": 0.44, "bill_to": 0.09, "thickness": 0.022, "camber": 0.012, "wrist": 0.45, "tips_from": 0.78,
            "rings": [[0.0, 0.0, 0.0], [0.05, 0.012, 0.016], [0.1, 0.045, 0.05], [0.17, 0.062, 0.064], [0.25, 0.058, 0.06],
                      [0.4, 0.095, 0.088], [0.55, 0.1, 0.09], [0.7, 0.08, 0.068], [0.82, 0.055, 0.03], [0.92, 0.065, 0.012],
                      [1.0, 0.07, 0.006], [1.0, 0.0, 0.0]],
            "stations": [0.0, 0.2, 0.45, 0.6, 0.72, 0.78, 0.86, 0.94, 1.0],
            "lead": [-0.05, -0.062, -0.072, -0.058, -0.04, -0.028, -0.004, 0.03, 0.07],
            "trail": [0.11, 0.105, 0.092, 0.086, 0.082, 0.08, 0.077, 0.074, 0.07],
            "body": Color(0.86, 0.87, 0.88), "mantle": Color(0.36, 0.39, 0.43), "under": Color(0.8, 0.81, 0.83),
            "tips": Color(0.025, 0.025, 0.03), "bill": Color(0.85, 0.62, 0.08),
        },
    },
    # a schooling fish (mackerel): blue-green back, silver belly; it swims in bursts and coasts, and
    # hardly rolls in a turn ("swims": tail beats instead of wing beats)
    "fish": {
        "swims": true, "span": 0.3, "cruise": 1.3, "slowest": 0.7, "fastest": 2.4, "beats": 3.2, "turn": 1.6,
        "bank": 0.2, "band": Vector2(1.5, 9.0), "flapping": Vector2(2.0, 6.0), "gliding": Vector2(0.6, 1.6),
        "sway": 0.13,
        "shape": {
            "rings": [[0.0, 0.0, 0.0], [0.05, 0.03, 0.04], [0.15, 0.06, 0.09], [0.3, 0.075, 0.115], [0.5, 0.07, 0.11],
                      [0.7, 0.045, 0.07], [0.85, 0.02, 0.03], [0.9, 0.012, 0.02], [0.9, 0.0, 0.0]],
            "dorsal": 0.11, "back": Color(0.1, 0.24, 0.26), "belly": Color(0.72, 0.76, 0.78), "fin": Color(0.16, 0.22, 0.24),
        },
    },
    # a reef fish keeping near the lab: deep-bodied, gold
    "reef_fish": {
        "swims": true, "span": 0.22, "cruise": 0.9, "slowest": 0.4, "fastest": 1.8, "beats": 3.8, "turn": 1.4,
        "bank": 0.2, "band": Vector2(1.0, 6.0), "flapping": Vector2(1.5, 4.0), "gliding": Vector2(0.5, 1.2),
        "sway": 0.11,
        "shape": {
            "rings": [[0.0, 0.0, 0.0], [0.06, 0.04, 0.06], [0.18, 0.07, 0.16], [0.35, 0.08, 0.2], [0.55, 0.07, 0.17],
                      [0.72, 0.045, 0.09], [0.85, 0.02, 0.035], [0.9, 0.012, 0.02], [0.9, 0.0, 0.0]],
            "dorsal": 0.19, "back": Color(0.85, 0.5, 0.08), "belly": Color(0.95, 0.78, 0.35), "fin": Color(0.9, 0.42, 0.08),
        },
    },
    # a soaring bird of prey (buzzard): broad wings, a square fingered hand, brown, hardly flapping
    "raptor": {
        "span": 1.25, "cruise": 9.0, "slowest": 7.0, "fastest": 12.0, "beats": 2.6, "turn": 5.0,
        "band": Vector2(12.0, 60.0), "flapping": Vector2(0.8, 1.6), "gliding": Vector2(6.0, 14.0),
        "glide_arm": 0.12, "glide_hand": -0.05, "arm_beat": 0.5, "hand_beat": 0.35,
        "shape": {
            "length": 0.42, "bill_to": 0.07, "thickness": 0.03, "camber": 0.015, "wrist": 0.5, "tips_from": 0.86,
            "rings": [[0.0, 0.0, 0.0], [0.05, 0.02, 0.022], [0.1, 0.05, 0.055], [0.17, 0.065, 0.068], [0.25, 0.07, 0.07],
                      [0.4, 0.1, 0.095], [0.55, 0.1, 0.092], [0.7, 0.085, 0.07], [0.8, 0.07, 0.03], [0.92, 0.085, 0.012],
                      [1.0, 0.09, 0.006], [1.0, 0.0, 0.0]],
            "stations": [0.0, 0.2, 0.5, 0.62, 0.75, 0.86, 0.94, 1.0],
            "lead": [-0.07, -0.075, -0.082, -0.08, -0.074, -0.066, -0.058, -0.04],
            "trail": [0.15, 0.15, 0.146, 0.142, 0.135, 0.125, 0.105, 0.07],
            "body": Color(0.2, 0.13, 0.07), "mantle": Color(0.13, 0.08, 0.045), "under": Color(0.42, 0.33, 0.22),
            "tips": Color(0.03, 0.025, 0.02), "bill": Color(0.12, 0.12, 0.13),
        },
    },
}

var kind := {}
var home := Vector3.ZERO      # the middle of where they fly
var keep_out := 20.0          # they stay out past this many metres from it (the deck, you)
var roam := 80.0              # and turn back before this many
var floor_y := 0.0            # the surface below them: the sea, the ground
var ground := Callable()      # or the ground's height at (x, z), where it is not level (a seabed)
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _lift := PackedVector3Array()      # what each needs to turn and stay up, smoothed: where it banks
var _flap := PackedFloat32Array()      # how much each is flapping now, 0 gliding .. 1
var _bout := PackedFloat32Array()      # seconds left of its bout
var _flapping := PackedByteArray()     # whether this bout is one of flapping
var _size := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

## `count` birds (or fish) of `kind_name` (a key of KINDS) going round `centre` between `inner` and
## `outer` metres from it, over a surface at height `surface`, or over `under`'s height at (x, z).
func setup(kind_name: String, centre: Vector3, inner: float, outer: float, count: int, surface: float,
           under: Callable = Callable()) -> void:
    kind = KINDS.get(kind_name, KINDS["gull"])
    home = centre
    keep_out = inner
    roam = maxf(outer, inner + 10.0)
    floor_y = surface
    ground = under
    _rng.seed = hash(kind_name) + count
    var span: float = kind["span"]
    var shape: Dictionary = kind["shape"]
    var many := MultiMesh.new()
    many.transform_format = MultiMesh.TRANSFORM_3D
    many.use_custom_data = true
    many.mesh = MeshKitClass.fish(span, shape) if kind.get("swims", false) else MeshKitClass.bird(span, shape)
    many.instance_count = count
    var band: Vector2 = kind["band"]
    # everything they can reach, so the batch's bounds are never worked out again as they move
    many.custom_aabb = AABB(Vector3(home.x - roam - 20.0, floor_y, home.z - roam - 20.0),
                            Vector3(2.0 * roam + 40.0, band.y + 30.0, 2.0 * roam + 40.0))
    multimesh = many
    if kind.get("swims", false):
        material_override = MaterialKitClass.shader("res://assets/shaders/fish.gdshader", {
            "body": span, "beat_hz": kind["beats"], "sway": kind["sway"],
        })
    else:
        material_override = MaterialKitClass.shader("res://assets/shaders/bird.gdshader", {
            "shoulder": MeshKitClass.bird_shoulder(span, shape),
            "wrist": float(shape["wrist"]) * (span * 0.5 - MeshKitClass.bird_shoulder(span, shape)),
            "beat_hz": kind["beats"], "glide_arm": kind["glide_arm"], "glide_hand": kind["glide_hand"],
            "arm_beat": kind["arm_beat"], "hand_beat": kind["hand_beat"],
        })
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _pos.resize(count)
    _vel.resize(count)
    _lift.resize(count)
    _flap.resize(count)
    _bout.resize(count)
    _size.resize(count)
    _phase.resize(count)
    _flapping.resize(count)
    var cruise: float = kind["cruise"]
    for i in count:
        # start them spread round the ring, going round it, in their band
        var angle := _rng.randf() * TAU
        var out := _rng.randf_range(keep_out, roam) * 0.5 + (keep_out + roam) * 0.25
        _pos[i] = home + Vector3(cos(angle) * out, 0.0, sin(angle) * out)
        _pos[i].y = surface_at(_pos[i].x, _pos[i].z) + _rng.randf_range(band.x, band.y)
        _vel[i] = Vector3(-sin(angle), 0.0, cos(angle)) * cruise
        _lift[i] = Vector3.UP * GRAVITY
        _flapping[i] = 1 if _rng.randf() < 0.4 else 0
        _flap[i] = float(_flapping[i])
        _bout[i] = _rng.randf_range(0.0, 3.0)
        _size[i] = _rng.randf_range(0.9, 1.1)
        _phase[i] = _rng.randf()
    _place()

func _process(delta: float) -> void:
    # a long frame (a room being built) is taken in short steps, and a very long one is not caught up
    var left := minf(delta, 0.25)
    while left > 0.0:
        var dt := minf(left, 1.0 / 30.0)
        step(dt)
        left -= dt
    _place()

## Moves every bird on by `dt` seconds.
func step(dt: float) -> void:
    _clock += dt
    var count := _pos.size()
    var span: float = kind["span"]
    var near := span * 25.0               # how far a bird heeds the others
    var clear := span * 4.0               # how close it lets one come
    var cruise: float = kind["cruise"]
    var slowest: float = kind["slowest"]
    var fastest: float = kind["fastest"]
    var turn: float = kind["turn"]
    var band: Vector2 = kind["band"]
    for i in count:
        var p := _pos[i]
        var v := _vel[i]
        var heading := Vector3.ZERO
        var middle := Vector3.ZERO
        var apart := Vector3.ZERO
        var seen := 0
        for j in count:
            if j == i:
                continue
            var d := _pos[j] - p
            var d2 := d.length_squared()
            if d2 < near * near:
                heading += _vel[j]
                middle += _pos[j]
                seen += 1
                if d2 < clear * clear:
                    apart -= d / maxf(d2, 0.01) * clear
        var want := apart * 2.0
        if seen > 0:
            want += (heading / seen - v) * 0.25 + (middle / seen - p) * 0.02
        # its own way: a heading that drifts slowly, different for each
        var s := _phase[i] * 37.0
        want += Vector3(sin(_clock * 0.31 + s), 0.25 * sin(_clock * 0.23 + s * 1.7), cos(_clock * 0.27 + s * 2.3)) * 1.2
        # hold its cruising speed
        var speed := v.length()
        var forward := v / maxf(speed, 0.001)
        want += forward * (cruise - speed) * 0.6
        # where it may fly comes first (the steering is shared out in that order, as in Reynolds'
        # prioritised flocking): the ring round the middle, and its band over the surface, judged
        # by where it will be in a second and a half on its way
        var keep := Vector3.ZERO
        var flat := Vector2(p.x + v.x * 1.5 - home.x, p.z + v.z * 1.5 - home.z)
        var out := flat.length()
        var outward := Vector3(flat.x, 0.0, flat.y) / maxf(out, 0.001)
        if out > roam:
            keep -= outward * (out - roam) * 0.6
        elif out < keep_out:
            keep += outward * (keep_out - out) * 1.0
        # and, gently, back towards the middle of its ring: birds loiter round a place, not its edge
        want -= outward * (out - (keep_out + roam) * 0.5) * 0.04
        var height := p.y + v.y * 1.5 - surface_at(p.x + v.x * 1.5, p.z + v.z * 1.5)
        if height < band.x:
            keep.y += (band.x - height) * 1.5
        elif height > band.y:
            keep.y -= (height - band.y) * 1.0
        if keep.length() > turn:
            keep = keep.normalized() * turn
        var left := turn - keep.length()
        if want.length() > left:
            want = want.normalized() * left
        want += keep
        v += want * dt
        speed = clampf(v.length(), slowest, fastest)
        v = v.normalized() * speed
        # a bird climbs and sinks along a path no steeper than about twenty degrees
        var level := Vector2(v.x, v.z)
        v.y = clampf(v.y, -MAX_PATH_SLOPE * level.length(), MAX_PATH_SLOPE * level.length())
        v = v.normalized() * speed
        _vel[i] = v
        _pos[i] = p + v * dt
        # what its wings must give: the turn's acceleration plus holding itself up, smoothed
        _lift[i] = _lift[i].lerp(want + Vector3.UP * GRAVITY, 1.0 - exp(-dt * 2.5))
        # bouts of flapping and gliding; it flaps whatever the bout when it climbs or has slowed
        _bout[i] -= dt
        if _bout[i] <= 0.0:
            _flapping[i] = 1 - _flapping[i]
            var lasts: Vector2 = kind["flapping"] if _flapping[i] == 1 else kind["gliding"]
            _bout[i] = _rng.randf_range(lasts.x, lasts.y)
        var flap_now := 1.0 if (_flapping[i] == 1 or v.y > 1.0 or speed < cruise * 0.9) else 0.0
        _flap[i] = move_toward(_flap[i], flap_now, dt * 1.5)

## The height of the surface under (x, z): the ground's where it was given, else the level surface.
func surface_at(x: float, z: float) -> float:
    return float(ground.call(x, z)) if ground.is_valid() else floor_y

## How each bird is turned: nose along its way, its back where its lift points (so it banks into a
## turn and pitches with its climb; a fish, buoyed by the water, rolls only a little: its kind's
## "bank"). Also what the tests read, as the batch is not read back.
func pose(i: int) -> Transform3D:
    var forward := _vel[i].normalized()
    var bank: float = kind.get("bank", 1.0)
    var need := (_lift[i] - Vector3.UP * GRAVITY) * bank + Vector3.UP * GRAVITY
    var lift := need - forward * need.dot(forward)
    var up := lift.normalized() if lift.length() > 0.01 else Vector3.UP
    var back := -forward
    var right := up.cross(back).normalized()
    up = back.cross(right)
    return Transform3D(Basis(right, up, back).scaled(Vector3.ONE * _size[i]), _pos[i])

func _place() -> void:
    for i in _pos.size():
        multimesh.set_instance_transform(i, pose(i))
        multimesh.set_instance_custom_data(i, Color(_phase[i], _flap[i], 1.2 - _size[i] * 0.2, 0.0))

func positions() -> PackedVector3Array:
    return _pos

func velocities() -> PackedVector3Array:
    return _vel
