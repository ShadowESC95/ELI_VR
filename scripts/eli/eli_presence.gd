class_name EliPresence
extends Node3D

# ELI in the room: a body of light, not a person. It shows which room he is
# in, what he is doing, and whether he is listening, thinking or speaking.
# His voice comes from here.

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

var mode := "dormant"
var eli_room := "core_room"
var activity := ""
var voice_player: AudioStreamPlayer3D

var _base_tint := Color("#63ddff")
var _tint := Color("#63ddff")
var _core_mat: StandardMaterial3D
var _shell_mat: ShaderMaterial
var _ring_mat: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _body: Node3D
var _light: OmniLight3D
var _label: Label3D
var _voice_bus := -1
var _level := 0.0
var _clock := 0.0

func setup(accent: Color) -> void:
    _base_tint = accent
    _tint = accent
    position = HOME

    _body = Node3D.new()
    _body.name = "Body"
    add_child(_body)

    _core_mat = StandardMaterial3D.new()
    _core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var core := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.11
    core_mesh.height = 0.22
    core.mesh = core_mesh
    core.material_override = _core_mat
    _body.add_child(core)

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
    for i in 3:
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.33 + 0.07 * i
        torus.outer_radius = torus.inner_radius + 0.006
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

    set_mode("dormant")

func set_accent(accent: Color) -> void:
    _base_tint = accent

func set_mode(value: String) -> void:
    mode = value if MODES.has(value) else "idle"
    _refresh_label()

# What ELI's world says about him right now.
func apply_world_state(state: Dictionary) -> void:
    eli_room = str(state.get("room", "core_room"))
    var avatar: Dictionary = state.get("avatar", {})
    var awareness: Dictionary = state.get("awareness", {})
    activity = str(avatar.get("activity", "")).replace("_", " ")

    # Doubt warms the light, repair work reddens it.
    var tint := _base_tint
    tint = tint.lerp(Color("#ffb347"), clampf((float(awareness.get("uncertainty", 0.0)) - 0.5) * 1.6, 0.0, 0.8))
    tint = tint.lerp(Color("#ff5a4d"), clampf((float(awareness.get("repair_pressure", 0.0)) - 0.4) * 1.4, 0.0, 0.8))
    _tint = tint
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
    _label.text = "ELI" if line.is_empty() else "ELI\n%s" % line

func _process(delta: float) -> void:
    if _body == null or not visible:
        return
    _clock += delta
    var m: Array = MODES[mode]
    var energy: float = m[0]
    var tint := _tint if mode != "dormant" else Color(0.45, 0.5, 0.55)

    # Speech moves the light with the voice itself.
    var target := 0.0
    if mode == "speaking" and voice_player.playing:
        target = clampf(db_to_linear(AudioServer.get_bus_peak_volume_left_db(_voice_bus, 0)) * 2.5, 0.0, 1.0)
    _level = lerpf(_level, target, clampf(delta * 14.0, 0.0, 1.0))

    var pulse := 1.0 + 0.06 * sin(_clock * (1.2 + float(m[2]) * 5.0)) + 0.35 * _level
    _body.position.y = 0.05 * sin(_clock * 0.9)
    _body.scale = Vector3.ONE * pulse

    for i in _rings.size():
        _rings[i].rotate_y(delta * float(m[1]) * (1.0 + 0.4 * i))
        _rings[i].rotate_x(delta * float(m[1]) * 0.3)

    _core_mat.albedo_color = tint.lightened(0.45) * (0.6 + 0.4 * energy)
    _ring_mat.albedo_color = tint * (0.35 + 0.3 * energy)
    _shell_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
    _shell_mat.set_shader_parameter("energy", energy * (1.0 + _level))
    _shell_mat.set_shader_parameter("activity", float(m[2]))
    _light.light_color = tint
    _light.light_energy = 0.5 * energy * (1.0 + _level)
    _label.modulate = tint.lightened(0.5)
