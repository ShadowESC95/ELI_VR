class_name EliPresence
extends Node3D

# ELI in the room: a body of light, not a person. It shows which room it is
# in, what it is doing, whether it is listening, thinking or speaking, and how
# it feels: its colour follows the expression ELI's world gives it, shaded by
# ELI's own doubt, repair work, curiosity and load, and moves there smoothly.
# Its voice comes from here.

const VOICE_BUS := "EliVoice"
const HOME := Vector3(-1.45, 1.5, -2.1)

# mode -> [energy, ring speed, shell activity]
const MODES := {
    "dormant": [0.25, 0.15, 0.05],
    "idle": [1.0, 0.5, 0.2],
    "listening": [1.7, 0.9, 0.55],
    "thinking": [1.3, 2.6, 0.9],
    "speaking": [1.4, 1.1, 0.7],
}

# Each expression ELI's world can carry: how pleasant (-1..1), how stirred (0..1), and its colour.
# An expression not listed here is shown as neutral.
const FEELINGS := {
    "neutral": [0.0, 0.3, ""],
    "serene": [0.6, 0.1, "#5fe0c0"],
    "gentle": [0.5, 0.2, "#7fe7d0"],
    "kind": [0.6, 0.3, "#8ff0a8"],
    "smiling": [0.7, 0.45, "#b6f26a"],
    "grinning": [0.8, 0.6, "#ffd84a"],
    "beaming": [0.9, 0.7, "#ffc23a"],
    "ecstatic": [1.0, 0.95, "#ff9a3c"],
    "manic": [0.4, 1.0, "#ff4fd8"],
    "smirking": [0.3, 0.5, "#c58bff"],
    "confident": [0.5, 0.55, "#4fb6ff"],
    "focused": [0.2, 0.6, "#3f8cff"],
    "intense": [0.0, 0.85, "#ff6a3d"],
    "curious": [0.4, 0.6, "#3ff0ff"],
    "puzzled": [-0.1, 0.5, "#a68bff"],
    "reflective": [0.2, 0.25, "#8a7bff"],
    "cautious": [-0.2, 0.45, "#ffb347"],
    "concerned": [-0.4, 0.55, "#ff9a4d"],
    "flat": [-0.2, 0.05, "#7f93a8"],
    "downcast": [-0.6, 0.15, "#4a62ff"],
    "frowning": [-0.6, 0.6, "#ff5a6a"],
    "angry": [-0.9, 0.95, "#ff2a2a"],
}
# How quickly the colour and the stir move to a new feeling (per second).
const FEEL_RATE := 2.2

var mode := "dormant"
var feeling := "neutral"
var eli_room := "core_room"
var activity := ""
var voice_player: AudioStreamPlayer3D

var _base_tint := Color("#63ddff")
var _tint := Color("#63ddff")
var _target_tint := Color("#63ddff")
var _arousal := 0.3
var _target_arousal := 0.3
var _core_mat: ShaderMaterial
var _nucleus: MeshInstance3D
var _nucleus_mat: StandardMaterial3D
var _motes: GPUParticles3D
var _motes_mat: ParticleProcessMaterial
var _shell_mat: ShaderMaterial
var _ring_mat: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _body: Node3D
var _light: OmniLight3D
var _label: Label3D
var _voice_bus := -1
var _level := 0.0
var _clock := 0.0
var _note := ""
var _note_left := 0.0
var _attend := Vector3.INF          # what the nucleus turns to; INF: whoever is looking
var _pour := Vector3.INF            # where ELI's light streams to while it makes something
var _stream_root: Node3D
var _stream: MeshInstance3D
var _stream_mat: ShaderMaterial

func setup(accent: Color) -> void:
    _base_tint = accent
    _tint = accent
    position = HOME

    _body = Node3D.new()
    _body.name = "Body"
    add_child(_body)

    _core_mat = ShaderMaterial.new()
    _core_mat.shader = load("res://assets/shaders/eli_core.gdshader")
    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.15
    core_mesh.height = 0.30
    core_mesh.radial_segments = 48
    core_mesh.rings = 24
    core.mesh = core_mesh
    core.material_override = _core_mat
    _body.add_child(core)

    # A brighter point inside that drifts toward whoever ELI is attending to.
    _nucleus_mat = StandardMaterial3D.new()
    _nucleus_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _nucleus = MeshInstance3D.new()
    var nucleus_mesh := SphereMesh.new()
    nucleus_mesh.radius = 0.024
    nucleus_mesh.height = 0.048
    _nucleus.mesh = nucleus_mesh
    _nucleus.material_override = _nucleus_mat
    _body.add_child(_nucleus)

    _motes = _make_motes()
    _body.add_child(_motes)

    _shell_mat = ShaderMaterial.new()
    _shell_mat.shader = load("res://assets/shaders/eli_presence.gdshader")
    var shell := MeshInstance3D.new()
    var shell_mesh := SphereMesh.new()
    shell_mesh.radius = 0.27
    shell_mesh.height = 0.54
    shell.mesh = shell_mesh
    shell.material_override = _shell_mat
    _body.add_child(shell)

    _ring_mat = StandardMaterial3D.new()
    _ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    for i in 3:
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.33 + 0.07 * i
        torus.outer_radius = torus.inner_radius + 0.003
        ring.mesh = torus
        ring.material_override = _ring_mat
        ring.rotation = Vector3(0.7 * i, 0.0, 0.5 * i)
        _body.add_child(ring)
        _rings.append(ring)

    _light = OmniLight3D.new()
    _light.omni_range = 4.0
    _light.shadow_enabled = false
    _body.add_child(_light)

    _label = Label3D.new()
    _label.font_size = 28
    _label.pixel_size = 0.0014
    _label.outline_size = 6
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true
    _label.position = Vector3(0.0, -0.62, 0.0)
    add_child(_label)

    _voice_bus = AudioServer.get_bus_index(VOICE_BUS)
    if _voice_bus == -1:
        _voice_bus = AudioServer.bus_count
        AudioServer.add_bus(_voice_bus)
        AudioServer.set_bus_name(_voice_bus, VOICE_BUS)
    voice_player = AudioStreamPlayer3D.new()
    voice_player.name = "Voice"
    voice_player.bus = VOICE_BUS
    voice_player.unit_size = 6.0
    add_child(voice_player)

    # the stream ELI pours into what it is making: a thin cylinder laid along -Z of its root
    _stream_root = Node3D.new()
    _stream_root.name = "Stream"
    _stream_root.top_level = true
    add_child(_stream_root)
    var thread := CylinderMesh.new()
    thread.top_radius = 0.03
    thread.bottom_radius = 0.06
    thread.height = 1.0
    thread.radial_segments = 10
    thread.rings = 1
    _stream_mat = ShaderMaterial.new()
    _stream_mat.shader = load("res://assets/shaders/eli_stream.gdshader")
    _stream = MeshInstance3D.new()
    _stream.mesh = thread
    _stream.material_override = _stream_mat
    _stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _stream.rotation.x = -PI / 2.0
    _stream_root.add_child(_stream)
    _stream_root.visible = false

    set_mode("dormant")

# Motes of light around ELI: more and quicker as it is stirred, in its colour.
func _make_motes() -> GPUParticles3D:
    var motes := GPUParticles3D.new()
    motes.name = "Motes"
    motes.amount = 72
    motes.lifetime = 4.5
    motes.local_coords = true
    _motes_mat = ParticleProcessMaterial.new()
    _motes_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
    _motes_mat.emission_sphere_radius = 0.24
    _motes_mat.direction = Vector3(0.0, 1.0, 0.0)
    _motes_mat.spread = 180.0
    _motes_mat.initial_velocity_min = 0.01
    _motes_mat.initial_velocity_max = 0.05
    _motes_mat.gravity = Vector3.ZERO
    _motes_mat.radial_accel_min = -0.06
    _motes_mat.radial_accel_max = -0.02
    _motes_mat.damping_min = 0.02
    _motes_mat.damping_max = 0.06
    _motes_mat.turbulence_enabled = true
    _motes_mat.turbulence_noise_strength = 0.6
    _motes_mat.turbulence_noise_scale = 1.6
    _motes_mat.scale_min = 0.5
    _motes_mat.scale_max = 1.2
    var fade := Gradient.new()
    fade.set_color(0, Color(1, 1, 1, 0))
    fade.add_point(0.2, Color(1, 1, 1, 1))
    fade.add_point(0.8, Color(1, 1, 1, 0.8))
    fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
    var ramp := GradientTexture1D.new()
    ramp.gradient = fade
    _motes_mat.color_ramp = ramp
    motes.process_material = _motes_mat
    var quad := QuadMesh.new()
    quad.size = Vector2(0.02, 0.02)
    var look := StandardMaterial3D.new()
    look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    look.vertex_color_use_as_albedo = true
    # a soft round point of light, not a square
    var dot := GradientTexture2D.new()
    dot.fill = GradientTexture2D.FILL_RADIAL
    dot.fill_from = Vector2(0.5, 0.5)
    dot.fill_to = Vector2(0.5, 0.0)
    var soft := Gradient.new()
    soft.set_color(0, Color(1, 1, 1, 1))
    soft.set_color(1, Color(1, 1, 1, 0))
    dot.gradient = soft
    look.albedo_texture = dot
    quad.material = look
    motes.draw_pass_1 = quad
    return motes

func set_accent(accent: Color) -> void:
    _base_tint = accent

func set_mode(value: String) -> void:
    mode = value if MODES.has(value) else "idle"
    _refresh_label()

# What ELI's world says about ELI right now.
func apply_world_state(state: Dictionary) -> void:
    eli_room = str(state.get("room", "core_room"))
    var avatar: Dictionary = state.get("avatar", {})
    var awareness: Dictionary = state.get("awareness", {})
    activity = str(avatar.get("activity", "")).replace("_", " ")

    feeling = str(avatar.get("expression", "neutral"))
    if not FEELINGS.has(feeling):
        feeling = "neutral"
    var felt: Array = FEELINGS[feeling]
    var tint := _base_tint if str(felt[2]).is_empty() else Color(str(felt[2]))
    # ELI's own state shades the feeling: doubt toward caution, repair work toward concern;
    # curiosity and work stir it, a quiet mind settles it.
    tint = tint.lerp(Color(str(FEELINGS["cautious"][2])), clampf((float(awareness.get("uncertainty", 0.0)) - 0.5) * 1.2, 0.0, 0.5))
    tint = tint.lerp(Color(str(FEELINGS["concerned"][2])), clampf((float(awareness.get("repair_pressure", 0.0)) - 0.4) * 1.2, 0.0, 0.6))
    var busy := maxf(float(awareness.get("cognitive_load", 0.0)), float(awareness.get("tool_activity", 0.0)))
    _target_tint = tint
    _target_arousal = clampf(float(felt[1]) + 0.3 * float(awareness.get("curiosity", 0.0)) + 0.25 * busy - 0.15, 0.0, 1.0)
    _refresh_label()

## How ELI's light is coloured now (it moves smoothly between feelings).
func tint_now() -> Color:
    return _tint

## Turn the bright point inside toward `point` (Vector3.INF: toward whoever is looking).
func look_toward(point: Vector3) -> void:
    _attend = point

## Stream ELI's light into `point` while it makes something there (Vector3.INF: stop).
func pour_into(point: Vector3) -> void:
    _pour = point

# A line under ELI for a few seconds: what it just made, or why it cannot answer.
func note(text: String, seconds: float = 6.0) -> void:
    _note = text
    _note_left = seconds
    _refresh_label()

func say(stream: AudioStream) -> void:
    voice_player.stream = stream
    voice_player.play()
    await voice_player.finished

func _refresh_label() -> void:
    if _label == null:
        return
    var line := activity
    match mode:
        "dormant": line = "not connected"
        "listening": line = "listening"
        "thinking": line = "thinking"
        "speaking": line = "speaking"
    if not _note.is_empty():
        line = _note if line.is_empty() else "%s\n%s" % [line, _note]
    _label.text = "ELI" if line.is_empty() else "ELI\n%s" % line

func _process(delta: float) -> void:
    if _body == null or not visible:
        return
    _clock += delta
    if _note_left > 0.0:
        _note_left -= delta
        if _note_left <= 0.0:
            _note = ""
            _refresh_label()
    var m: Array = MODES[mode]
    var energy: float = m[0]
    var ease := 1.0 - exp(-delta * FEEL_RATE)
    _tint = _tint.lerp(_target_tint, ease)
    _arousal = lerpf(_arousal, _target_arousal, ease)
    var tint := _tint if mode != "dormant" else Color(0.45, 0.5, 0.55)
    var stir := _arousal if mode != "dormant" else 0.05

    # Speech moves the light with the voice itself.
    var target := 0.0
    if mode == "speaking" and voice_player.playing:
        target = clampf(db_to_linear(AudioServer.get_bus_peak_volume_left_db(_voice_bus, 0)) * 2.5, 0.0, 1.0)
    _level = lerpf(_level, target, clampf(delta * 14.0, 0.0, 1.0))

    var pulse := 1.0 + (0.04 + 0.04 * stir) * sin(_clock * (1.0 + float(m[2]) * 4.0 + stir * 2.0)) + 0.35 * _level
    _body.position.y = 0.05 * sin(_clock * 0.9)
    _body.scale = Vector3.ONE * pulse

    for i in _rings.size():
        _rings[i].rotate_y(delta * float(m[1]) * (1.0 + 0.4 * i))
        _rings[i].rotate_x(delta * float(m[1]) * 0.3)

    _core_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
    var deep := tint.darkened(0.6)
    _core_mat.set_shader_parameter("tint_deep", Vector3(deep.r, deep.g, deep.b))
    _core_mat.set_shader_parameter("energy", 0.6 + 0.6 * energy)
    _core_mat.set_shader_parameter("agitation", stir)
    _core_mat.set_shader_parameter("level", _level)
    _nucleus_mat.albedo_color = tint.lightened(0.45) * (0.8 + 0.6 * energy + _level)
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    var toward := Vector3.ZERO
    if _attend.is_finite():
        toward = (_attend - _body.global_position).normalized() * 0.07
    elif camera != null:
        toward = (camera.global_position - _body.global_position).normalized() * 0.07
    _nucleus.position = _nucleus.position.lerp(toward, clampf(delta * 3.0, 0.0, 1.0))
    _motes_mat.color = tint.lightened(0.3)
    _motes.speed_scale = 0.4 + 1.6 * stir
    _motes.amount_ratio = 0.35 + 0.65 * stir
    _ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.35 + 0.25 * energy)
    _shell_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
    _shell_mat.set_shader_parameter("energy", energy * (1.0 + _level))
    _shell_mat.set_shader_parameter("activity", float(m[2]))
    _light.light_color = tint
    _light.light_energy = 0.5 * energy * (1.0 + _level)
    var from := _body.global_position
    var pouring := _pour.is_finite() and from.distance_to(_pour) > 0.2
    _stream_root.visible = pouring
    if pouring:
        var length := from.distance_to(_pour)
        _stream_root.global_position = from
        _stream_root.look_at(_pour, Vector3.UP if absf((_pour - from).normalized().y) < 0.98 else Vector3.RIGHT)
        _stream.position = Vector3(0, 0, -length * 0.5)
        _stream.scale = Vector3(1.0, length, 1.0)
        _stream_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
        _stream_mat.set_shader_parameter("energy", 2.2 + stir)
    _label.modulate = tint.lightened(0.5)
