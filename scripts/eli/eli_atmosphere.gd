class_name EliAtmosphere
extends Node3D

# The room around ELI breathes with it. Its light leans toward the colour of how ELI feels, its air
# thickens with ELI's doubt, it stirs with how roused ELI is and swells with ELI's voice, dims a
# little while ELI thinks, and flickers while ELI is repairing something; motes of light drift through
# it with ELI's curiosity. Strongest in the room ELI is in. Each room keeps its own look underneath:
# this only leans on it, and lets go when ELI is not connected.

# How far the room's air leans toward ELI, in ELI's room and in any other.
const LEAN_WITH_ELI := 0.32
const LEAN_AWAY := 0.12
# How far its own lights lean: the glowing trims, strips and lamps that make a place look lived in.
# The sun and the sky keep each place's look.
const GLOW_WITH_ELI := 0.85
const GLOW_AWAY := 0.3
# How quickly the room follows (per second).
const FOLLOW := 1.6

var _app: Node
var _presence: EliPresence
var _env: Environment
var _base := {}
var _glows: Array = []      # [StandardMaterial3D, its own emission colour]
var _strips: Array = []     # [StandardMaterial3D, its own colour]: unlit surfaces that are lights
var _halos: Array = []      # [ShaderMaterial, its own tint]: the soft points of light
var _lamps: Array = []      # [Light3D, its own colour]
var _lean := 0.0
var _clock := 0.0
var _motes: GPUParticles3D
var _motes_mat: ParticleProcessMaterial

func setup(app: Node, presence: EliPresence) -> void:
    _app = app
    _presence = presence
    _motes = _make_motes()
    add_child(_motes)

func _make_motes() -> GPUParticles3D:
    var motes := GPUParticles3D.new()
    motes.name = "AirMotes"
    motes.amount = 160
    motes.lifetime = 14.0
    motes.preprocess = 10.0
    motes.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 6, 16))
    _motes_mat = ParticleProcessMaterial.new()
    _motes_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    _motes_mat.emission_box_extents = Vector3(6.0, 2.2, 6.0)
    _motes_mat.direction = Vector3(0.0, 1.0, 0.0)
    _motes_mat.spread = 180.0
    _motes_mat.initial_velocity_min = 0.005
    _motes_mat.initial_velocity_max = 0.03
    _motes_mat.gravity = Vector3(0.0, 0.004, 0.0)
    _motes_mat.turbulence_enabled = true
    _motes_mat.turbulence_noise_strength = 0.35
    _motes_mat.turbulence_noise_scale = 3.0
    var fade := Gradient.new()
    fade.set_color(0, Color(1, 1, 1, 0))
    fade.add_point(0.25, Color(1, 1, 1, 0.9))
    fade.add_point(0.75, Color(1, 1, 1, 0.7))
    fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
    var ramp := GradientTexture1D.new()
    ramp.gradient = fade
    _motes_mat.color_ramp = ramp
    motes.process_material = _motes_mat
    var quad := QuadMesh.new()
    quad.size = Vector2(0.018, 0.018)
    var look := StandardMaterial3D.new()
    look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    look.vertex_color_use_as_albedo = true
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
    motes.emitting = false
    return motes

## The current room's environment: the one its WorldEnvironment holds.
func _room_environment() -> Environment:
    var root = _app.get("room_root")
    if root == null:
        return null
    for found in root.find_children("*", "WorldEnvironment", true, false):
        var we := found as WorldEnvironment
        if we != null and we.environment != null and not we.is_queued_for_deletion():
            return we.environment
    return null

func _bind(env: Environment) -> void:
    _restore_lights()
    _env = env
    _glows.clear()
    _lamps.clear()
    _strips.clear()
    _halos.clear()
    var root = _app.get("room_root")
    var seen := {}
    for node in root.find_children("*", "", true, false):
        if node is OmniLight3D or node is SpotLight3D:
            _lamps.append([node, (node as Light3D).light_color])
        elif node is GeometryInstance3D:
            var mats: Array = [(node as GeometryInstance3D).material_override]
            if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
                for i in (node as MeshInstance3D).mesh.get_surface_count():
                    mats.append((node as MeshInstance3D).get_active_material(i))
            for m in mats:
                if m == null or seen.has(m.get_instance_id()):
                    continue
                seen[m.get_instance_id()] = true
                var std := m as StandardMaterial3D
                if std != null and std.emission_enabled:
                    _glows.append([std, std.emission])
                elif std != null and std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
                        and maxf(std.albedo_color.r, maxf(std.albedo_color.g, std.albedo_color.b)) > 1.0:
                    _strips.append([std, std.albedo_color])      # brighter than white: a light, not a label
                var shader_mat := m as ShaderMaterial
                if shader_mat != null and shader_mat.get_shader_parameter("tint") is Vector3:
                    _halos.append([shader_mat, shader_mat.get_shader_parameter("tint")])
    _base = {
        "ambient": env.ambient_light_color,
        "energy": env.ambient_light_energy,
        "vfog": env.volumetric_fog_enabled,
        "vfog_albedo": env.volumetric_fog_albedo,
        "vfog_density": env.volumetric_fog_density,
        "fog": env.fog_enabled,
        "fog_colour": env.fog_light_color,
        "fog_density": env.fog_density,
    }

func _process(delta: float) -> void:
    if _presence == null:
        return
    var env := _room_environment()
    if env == null:
        return
    if env != _env:
        _bind(env)
    _clock += delta
    var connected := _presence.mode != "dormant"
    var here := _presence.eli_room == str(_app.call("current_room_id"))
    var target := (LEAN_WITH_ELI if here else LEAN_AWAY) if connected else 0.0
    _lean = lerpf(_lean, target, 1.0 - exp(-delta * FOLLOW))

    var tint: Color = _presence.tint_now()
    var stir: float = _presence.stir_now()
    var aware: Dictionary = _presence.awareness
    var doubt := clampf(float(aware.get("uncertainty", 0.0)), 0.0, 1.0)
    var repair := clampf(float(aware.get("repair_pressure", 0.0)), 0.0, 1.0)
    var curious := clampf(float(aware.get("curiosity", 0.0)), 0.0, 1.0)
    var share := _lean / LEAN_WITH_ELI       # 0..1: how much of ELI reaches this room now

    env.ambient_light_color = (_base["ambient"] as Color).lerp(tint, _lean)
    # an unsteady light while ELI repairs something: slow noise, never a strobe
    var unsteady := 0.0
    if repair > 0.5:
        unsteady = (repair - 0.5) * 0.5 * sin(_clock * 7.3) * sin(_clock * 2.9 + 1.3)
    var thinking := -0.2 if _presence.mode == "thinking" else 0.0
    var energy := 1.0 + share * (0.45 * stir + thinking + 0.7 * _presence.voice_level() + unsteady)
    env.ambient_light_energy = float(_base["energy"]) * maxf(0.4, energy)
    if bool(_base["vfog"]):
        env.volumetric_fog_albedo = (_base["vfog_albedo"] as Color).lerp(tint, _lean)
        env.volumetric_fog_density = float(_base["vfog_density"]) * (1.0 + 1.6 * doubt * share)
    if bool(_base["fog"]):
        env.fog_light_color = (_base["fog_colour"] as Color).lerp(tint, _lean)
        env.fog_density = float(_base["fog_density"]) * (1.0 + 1.6 * doubt * share)

    var glow_lean := (GLOW_WITH_ELI if here else GLOW_AWAY) * (_lean / maxf(target, 0.0001)) if target > 0.0 else 0.0
    glow_lean = clampf(glow_lean, 0.0, GLOW_WITH_ELI)
    for g in _glows:
        if is_instance_valid(g[0]):
            (g[0] as StandardMaterial3D).emission = (g[1] as Color).lerp(tint, glow_lean)
    for l in _lamps:
        if is_instance_valid(l[0]):
            (l[0] as Light3D).light_color = (l[1] as Color).lerp(tint, glow_lean * 0.6)
    for st in _strips:
        if is_instance_valid(st[0]):
            var own: Color = st[1]
            var bright := maxf(own.r, maxf(own.g, own.b))
            var hue := Color(own.r / bright, own.g / bright, own.b / bright).lerp(tint, glow_lean)
            (st[0] as StandardMaterial3D).albedo_color = Color(hue.r * bright, hue.g * bright, hue.b * bright, own.a)
    for h in _halos:
        if is_instance_valid(h[0]):
            var was: Vector3 = h[1]
            var to := Color(was.x, was.y, was.z).lerp(tint, glow_lean)
            (h[0] as ShaderMaterial).set_shader_parameter("tint", Vector3(to.r, to.g, to.b))

    # the air around whoever is looking: motes in ELI's colour, more of them the more curious ELI is
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        global_position = camera.global_position
    _motes.emitting = connected
    _motes.amount_ratio = clampf(0.15 + 0.85 * curious * share + 0.2 * stir * share, 0.0, 1.0)
    _motes_mat.color = tint.lightened(0.35)

func _restore_lights() -> void:
    for g in _glows:
        if is_instance_valid(g[0]):
            (g[0] as StandardMaterial3D).emission = g[1]
    for l in _lamps:
        if is_instance_valid(l[0]):
            (l[0] as Light3D).light_color = l[1]
    for st in _strips:
        if is_instance_valid(st[0]):
            (st[0] as StandardMaterial3D).albedo_color = st[1]
    for h in _halos:
        if is_instance_valid(h[0]):
            (h[0] as ShaderMaterial).set_shader_parameter("tint", h[1])

func _exit_tree() -> void:
    # the room as it was, if the atmosphere goes before the room does
    _restore_lights()
    if _env != null and not _base.is_empty():
        _env.ambient_light_color = _base["ambient"]
        _env.ambient_light_energy = _base["energy"]
        if bool(_base["vfog"]):
            _env.volumetric_fog_albedo = _base["vfog_albedo"]
            _env.volumetric_fog_density = _base["vfog_density"]
        if bool(_base["fog"]):
            _env.fog_light_color = _base["fog_colour"]
            _env.fog_density = _base["fog_density"]
