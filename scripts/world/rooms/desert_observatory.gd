class_name DesertObservatoryRoom
extends RoomBase

# Desert Observatory: a sea of dunes after dark, far from any town. The sun set an hour ago: the
# Milky Way is out overhead and the last of the twilight lies along the western horizon, under it
# the mesas out on the plain stand dark. The sand still gives off the day's heat, so the far ground
# shimmers against the glow; the evening wind streams loose sand over the dunes and their ripples.
# A dome stands open to the sky with its telescope, a dish turns, and the only lamps are the dim red
# ones astronomers keep so their eyes stay dark. A waxing gibbous moon stands in the south-east:
# where it is and how much of it is lit follow from its age and the set sun, and the light it casts
# (its way, its colour, its strength) from that phase and how high it is (moon()).

# Towards the sun, set in the west 9 degrees under the horizon (the end of nautical twilight): the
# sky overhead dark enough for the Milky Way, the twilight still a band along the horizon.
const SUN_BELOW := Vector3(-0.981, -0.156, 0.121)
# The way the wind blows (from the south-west), and the dunes it has built square across it: crests
# 72 m apart and up to 9 m high (MeshKit.dune_height).
const WIND := Vector2(0.8, -0.6)
const DUNES := Vector4(0.8, -0.6, 72.0, 9.0)
# The night air the sky is seen through (space_sky.gdshader, include/night_air.gdshaderinc): dry
# and clear, the twilight and the faint airglow; the ground's mirage bends the same twilight down.
# The air's Rayleigh colours and thickness are handed to the shaders from here, so the moon's light
# worked out here passes through the same air the sky is drawn with.
const NIGHT_AIR := {"air": 1.0, "sun_dir": SUN_BELOW, "twilight": 6.0, "airglow": 0.012,
                    "rayleigh": Vector3(0.19, 0.45, 1.0), "optical_depth": 0.28}
# The moon: its age in days since new (a synodic month is 29.53), which sets how far round the sky
# from the sun it stands and so its phase; how high it stands at this hour; and, as true figures,
# the Moon's reflectance across red, green and blue (it reddens sunlight a little). FULL_MOON is the
# exposure of a moonlit night: the light energy a full moon overhead gives in this renderer.
const MOON_AGE := 11.0
const MOON_HIGH := deg_to_rad(30.0)
const SYNODIC_MONTH := 29.53
const MOON_TINT := Color(1.0, 0.93, 0.84)
const FULL_MOON := 2.4
const FIELD := 760.0             # the dune field's width; the plain runs on past it to the horizon
const PLAIN_DROP := 0.4          # the plain lies this far under the field's settled edge, out of its way

var _streak: MeshInstance3D
var _streak_material: ShaderMaterial
var _next_streak := 4.0
var _streak_from := Vector3.ZERO
var _streak_to := Vector3.ZERO
var _streak_age := 9.0
var _rng := RandomNumberGenerator.new()
var _land: LandKit
var _sky: ShaderMaterial

func _build() -> void:
    var env := environment(Color(0.1, 0.12, 0.2), 0.55)
    # the galaxy stands up ahead, the whole point of being here, seen through dry desert air
    _sky = star_sky(env, Vector3(0.05, 0.62, -0.78), 62.0, 2.1)
    for key in NIGHT_AIR:
        _sky.set_shader_parameter(key, NIGHT_AIR[key])
    # far things fade into the night air, coloured as the sky behind them
    env.fog_enabled = true
    env.fog_density = 0.00022
    env.fog_aerial_perspective = 0.9
    env.fog_sky_affect = 0.0
    # the moon, and the light it casts, from its phase and height; the sky shows it and is lit by it
    var moon_now := moon()
    var moonlight := sun(moon_now["dir"], moon_now["colour"], moon_now["energy"])
    moonlight.name = "Moonlight"
    _sky.set_shader_parameter("moon_dir", moon_now["dir"])
    _sky.set_shader_parameter("moon", Vector3(moon_now["colour"].r, moon_now["colour"].g, moon_now["colour"].b) * moon_now["share"])
    # and the twilight in the west, faint, a wide glow that casts no shadows
    var glow_way := Vector3(SUN_BELOW.x, 0.25, SUN_BELOW.z).normalized()
    var twilight := sun(glow_way, Color(0.72, 0.62, 0.78), 0.32)
    twilight.shadow_enabled = false

    _dunes()
    _plain_and_mesas()
    _platform()
    _dome()
    _dish()
    _shooting_star()
    _camp()
    if motes:
        _blowing_sand()
    probe()

## The moon tonight: "dir" the way to it, "lit" the share of its face lit, "share" its light against a
## full moon overhead (phase and air both), "colour" and "energy" the light it casts here. Its angle
## from the sun (the elongation) follows from its age; it stands at MOON_HIGH, east of the sun
## (waxing), on the side of the sky towards the south; its phase angle is 180° less the elongation;
## its brightness against full is Allen's magnitude-phase law for the Moon, 0.026·i + 4·10⁻⁹·i⁴
## magnitudes (i in degrees); and the air dims and reddens it by its air mass, as the sky shader does
## (include/night_air.gdshaderinc: exp(−depth·air·mass·(0.35 + 0.65·rayleigh)), mass 1/(sin h + 0.035)).
func moon() -> Dictionary:
    var sun_way := SUN_BELOW.normalized()
    var apart := deg_to_rad(360.0 * MOON_AGE / SYNODIC_MONTH)
    # the azimuth at which a body MOON_HIGH up stands `apart` from the sun: two answers, the southern one
    var level := Vector2(sun_way.x, sun_way.z)
    var reach := (cos(apart) - sun_way.y * sin(MOON_HIGH)) / (cos(MOON_HIGH) * level.length())
    var turn := acos(clampf(reach, -1.0, 1.0))
    var best := Vector3.ZERO
    for side in [1.0, -1.0]:
        var a: float = atan2(level.y, level.x) + side * turn
        var way := Vector3(cos(MOON_HIGH) * cos(a), sin(MOON_HIGH), cos(MOON_HIGH) * sin(a))
        if best == Vector3.ZERO or way.z > best.z:
            best = way
    var phase_deg := 180.0 - rad_to_deg(sun_way.angle_to(best))
    var lit := (1.0 + cos(deg_to_rad(phase_deg))) * 0.5
    var against_full := pow(10.0, -0.4 * (0.026 * phase_deg + 4e-9 * pow(phase_deg, 4.0)))
    var mass := 1.0 / (sin(MOON_HIGH) + 0.035)
    var rayleigh: Vector3 = NIGHT_AIR["rayleigh"]
    var depth: float = NIGHT_AIR["optical_depth"] * NIGHT_AIR["air"] * mass
    var through := Vector3(exp(-depth * (0.35 + 0.65 * rayleigh.x)), exp(-depth * (0.35 + 0.65 * rayleigh.y)),
                           exp(-depth * (0.35 + 0.65 * rayleigh.z)))
    var colour := Color(MOON_TINT.r * through.x, MOON_TINT.g * through.y, MOON_TINT.b * through.z)
    var strongest := maxf(colour.r, maxf(colour.g, colour.b))
    return {"dir": best, "lit": lit, "share": against_full, "phase": phase_deg,
            "colour": Color(colour.r / strongest, colour.g / strongest, colour.b / strongest),
            "energy": FULL_MOON * against_full * strongest}

func _dunes() -> void:
    # sand, rippled by the wind, the bedrock showing only where the land is steeper than a dune
    # ever stands; loose sand streaming over it, and heat shimmering off it far out
    var sand := LandKit.blend("sand", 4.0, Color(0.62, 0.58, 0.56), "rock", 2.4, Color(0.5, 0.44, 0.4),
        {"slope_from": 0.3, "slope_to": 0.62, "breakup": 0.45, "ripples": 0.6, "ripple_dir": WIND,
         "ripple_width": 0.4, "far_blend": 50.0, "drift": 5.0, "haze": 1.0,
         "mirage": NIGHT_AIR["twilight"], "mirage_sun": NIGHT_AIR["sun_dir"],
         "rayleigh": NIGHT_AIR["rayleigh"], "optical_depth": NIGHT_AIR["optical_depth"]})
    # the dune field is the room's heaviest piece: made on a worker thread so coming in does not pause
    _land = LandKit.lay(self, sand, 31, 0.006, 3, FIELD, 230, 6.0, 12.0, 26.0, 0.0, -0.16, 120.0, DUNES, true)

    # the boulders, quiver trees and dry scrub of the flat between the dunes the deck stands on
    # (scanned, assets/models), each on the ground at its height, and dry grass between them
    var rng := RandomNumberGenerator.new()
    rng.seed = 14
    _land.scatter(self, ["namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_05", "namaqualand_boulder_06"],
                  14, 12.0, 44.0, rng, 0.8, 1.7, -0.1, true)
    _land.scatter(self, ["quiver_tree_01", "quiver_tree_02", "didelta_spinosa"], 6, 13.0, 34.0, rng, 0.9, 1.4, -0.02)
    _land.scatter(self, ["shrub_04", "dry_branches_medium_01"], 16, 10.5, 36.0, rng, 1.0, 2.2, -0.03, true)
    var dry := LandKit.sway_material("dry", Color(1.0, 0.92, 0.75), 0.05, 0.7)
    for kind in 2:
        _land.cover(self, LandKit.tuft("dry", 61 + kind), dry, int(120 * detail), 10.5, 30.0, rng, 0.8, 1.8, 0.03)

# Past the dunes the plain runs on to the horizon, the same sand shimmering, and mesas and buttes
# stand out on it, most of them to the west against the last of the light (MeshKit.mesa).
func _plain_and_mesas() -> void:
    var plain_y := _land.base_y - PLAIN_DROP
    var reach := 3900.0
    var plain := add(MeshKitClass.disc(reach, 48, 96, 8.0), _land.ground.material_override, Vector3(0, plain_y, 0))
    plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var rock := MaterialKitClass.surface("rock", 24.0, Color(0.46, 0.34, 0.27), 1.0, true)
    var west := atan2(SUN_BELOW.z, SUN_BELOW.x)
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    for i in 9:
        # stood far enough out that their feet clear the dune field, tall enough (as mesas are, a
        # hundred to three hundred metres over their plains) to stand over its crests from the deck
        var bearing := west + (rng.randf_range(-0.8, 0.8) if i < 6 else rng.randf_range(1.4, TAU - 1.4))
        var butte := i % 3 == 2
        var tall := rng.randf_range(120.0, 260.0) * (1.2 if butte else 1.0)
        var radius := tall * (rng.randf_range(0.4, 0.7) if butte else rng.randf_range(1.2, 2.2))
        var distance := maxf(rng.randf_range(FIELD, reach * 0.8), FIELD * 0.5 + radius * 2.5)
        var hill := add(MeshKitClass.mesa(900 + i, radius, tall, 0.55 if butte else 1.0), rock,
                        Vector3(cos(bearing) * distance, plain_y - 1.0, sin(bearing) * distance))
        hill.rotation.y = rng.randf() * TAU
        hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Sand blown along the ground by the wind round the deck: grains hopping (saltation), each lifted
# off the surface, carried a metre or two and dropped, low and fast.
func _blowing_sand() -> void:
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(24.0, 0.02, 24.0)
    process.direction = Vector3(WIND.x, 0.28, WIND.y).normalized()
    process.spread = 10.0
    process.initial_velocity_min = 3.5
    process.initial_velocity_max = 6.0
    process.gravity = Vector3(0, -9.81, 0)
    process.scale_min = 0.6
    process.scale_max = 1.3
    var grain := QuadMesh.new()
    grain.size = Vector2(0.025, 0.025)
    var look := StandardMaterial3D.new()
    look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    look.albedo_color = Color(0.2, 0.17, 0.16, 0.55)
    look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    var field := GPUParticles3D.new()
    field.amount = int(900 * detail)
    field.lifetime = 0.45
    field.preprocess = 1.0
    field.process_material = process
    field.draw_pass_1 = grain
    field.material_override = look
    field.position = Vector3(0, 0.03, 0)
    field.visibility_aabb = AABB(Vector3(-30, -1, -30), Vector3(60, 3, 60))
    field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(field)

func _platform() -> void:
    var slab := MaterialKitClass.surface("concrete", 3.0, Color(0.6, 0.55, 0.5), 0.9)
    deck(9.0, slab, slab)
    # red lamps low to the ground
    var red := Color(1.0, 0.16, 0.08)
    var post := CylinderMesh.new()
    post.top_radius = 0.03
    post.bottom_radius = 0.04
    post.height = 0.5
    for i in 10:
        var angle := TAU * float(i) / 10.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.8
        add(post, slab, at + Vector3(0, 0.25, 0))
        glow(at + Vector3(0, 0.55, 0), red, 0.7, 1.4, 0.8)
        if i % 2 == 0:
            lamp(at + Vector3(0, 0.6, 0), red, 0.5, 4.5)

func _dome() -> void:
    # painted, not bare metal: a bare dome mirrors the whole sky. Both sides drawn: through the slit
    # you see the inside, dark but for the red lamp the telescope is worked by.
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.86, 0.86, 0.84)
    white.roughness = 0.55
    white.cull_mode = BaseMaterial3D.CULL_DISABLED
    var slab := MaterialKitClass.surface("concrete", 2.5, Color(0.62, 0.58, 0.54))
    var base := Node3D.new()
    base.position = Vector3(-12.0, 0.0, -19.0)
    base.position.y = _land.ground_under(base.position, 4.8).x       # its footing goes down into the sand
    add_child(base)
    # the round wall the dome turns on, its footing going down into the sand
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 3.2), Vector2(4.6, 3.2), Vector2(4.6, -2.0), Vector2(0.0, -2.0),
    ]), 48), slab, Vector3.ZERO, base)
    # the dome turns on it with its slit open from the wall up past the top, the two shutter
    # leaves slid back to either side
    var shell := Node3D.new()
    shell.position = Vector3(0, 3.2, 0)
    base.add_child(shell)
    var profile := PackedVector2Array()
    var leaf := PackedVector2Array()
    for s in 13:
        var a := float(s) / 12.0 * PI * 0.5
        profile.append(Vector2(sin(a) * 4.7 + 0.001, cos(a) * 4.7))
        leaf.append(Vector2(sin(a) * 4.82 + 0.001, cos(a) * 4.82))
    profile.append(Vector2(4.7, 0.0))
    var slit := 0.21                    # half the slit's width, as an angle round the dome (2 m at the wall)
    add(MeshKitClass.lathe(profile, 40, slit, TAU - 2.0 * slit), white, Vector3.ZERO, shell)
    for side in [1.0, -1.0]:
        add(MeshKitClass.lathe(leaf, 6, slit + 0.02 if side > 0.0 else -slit - 0.02 - 0.46, 0.46), white, Vector3.ZERO, shell)
    # inside, the telescope on its pier, aimed out of the slit (the slit faces the shell's +X)
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.6, 0.62, 0.68), 0.7)
    rod(0.25, 1.6, steel, Vector3(0, 0.0, 0), shell)
    var tube := add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 2.4), Vector2(0.5, 2.4), Vector2(0.52, 2.2), Vector2(0.5, 2.1), Vector2(0.5, -1.4),
        Vector2(0.3, -1.5), Vector2(0.0, -1.5),
    ]), 24), steel, Vector3(0.4, 1.4, 0), shell)
    tube.rotation.z = -deg_to_rad(40.0)
    lamp(Vector3(-1.5, 0.6, 0.0), Color(1.0, 0.16, 0.08), 0.25, 4.0, shell)
    shell.rotation.y = deg_to_rad(-70.0)
    spin(shell, Vector3.UP, 0.02)

func _dish() -> void:
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.84, 0.84, 0.82)
    white.roughness = 0.55
    white.cull_mode = BaseMaterial3D.CULL_DISABLED
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.5, 0.52, 0.58))
    var base := Node3D.new()
    base.position = Vector3(15.0, 0.0, -21.0)
    base.position.y = _land.ground_under(base.position, 1.5).x
    add_child(base)
    var mast := CylinderMesh.new()
    mast.top_radius = 0.3
    mast.bottom_radius = 0.5
    mast.height = 6.5
    add(mast, steel, Vector3(0, 2.0, 0), base)
    var head := Node3D.new()
    head.position = Vector3(0, 5.4, 0)
    base.add_child(head)
    # the dish: a paraboloid y = r²/(4f), its feed held at the focus by three legs from the rim
    var focus := 2.27
    var rim := 3.6
    var profile := PackedVector2Array()
    for s in 11:
        var r := float(s) / 10.0 * rim
        profile.append(Vector2(r + 0.001, r * r / (4.0 * focus)))
    var bowl := add(MeshKitClass.lathe(profile, 40), white, Vector3.ZERO, head)
    bowl.rotation.x = deg_to_rad(48.0)
    var feed := Vector3(0, focus, 0)
    for k in 3:
        var a := TAU * float(k) / 3.0 + 0.5
        var at_rim := Vector3(cos(a) * rim * 0.97, pow(rim * 0.97, 2.0) / (4.0 * focus), sin(a) * rim * 0.97)
        var across := (feed - at_rim).cross(Vector3.UP).normalized()
        add(MeshKitClass.beam(PackedVector3Array([at_rim, feed]), across, 0.07, 0.07), steel, Vector3.ZERO, bowl)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.35), Vector2(0.22, 0.35), Vector2(0.3, -0.1), Vector2(0.12, -0.25), Vector2(0.0, -0.25),
    ]), 16), steel, feed, bowl)
    # the counterweight behind the bowl and the bearing it tips on
    box(Vector3(1.0, 0.8, 0.9), steel, Vector3(0, -0.6, -1.1), bowl)
    rod(0.22, 1.4, steel, Vector3(0, 0, 0), head).rotation.z = PI * 0.5
    blink(glow(base.position + Vector3(0, 8.6, 0), Color(1.0, 0.2, 0.12), 0.9, 2.0, 0.9), 2.6)
    spin(head, Vector3.UP, 0.05)

# The astronomers' table at the edge of the platform, where the night's notes are kept under a red
# lamp; the generator by the dome; a stool by the dish (real things, assets/models).
func _camp() -> void:
    var a := deg_to_rad(150.0)
    var table := Node3D.new()
    table.position = Vector3(sin(a), 0.0, -cos(a)) * 6.3
    table.rotation.y = -a + PI * 0.5
    add_child(table)
    prop("wooden_picnic_table", Vector3.ZERO, 0.0, 1.0, table)
    prop("cassette_player", Vector3(0.35, 0.75, 0.5), 20.0, 1.0, table)
    prop("vintage_binocular", Vector3(-0.3, 0.75 + 0.05, -0.4), -35.0, 1.0, table)
    prop("Lantern_01", Vector3(0.0, 0.75, 0.0), 0.0, 1.0, table)
    var red := Color(1.0, 0.25, 0.12)
    glow(Vector3(0.0, 0.95, 0.0), red, 0.5, 1.2, 0.8, table)
    lamp(Vector3(0.0, 1.0, 0.0), red, 0.9, 4.0, table)
    prop("plastic_monobloc_chair_01", Vector3(1.5, 0.0, 1.9), 150.0, 1.0, table)
    _land.on(self, "portable_generator", Vector3(-12.0, 0.0, -19.0) + Vector3(5.5, 0.0, 1.4), -20.0)
    _land.on(self, "metal_stool_01", Vector3(15.0, 0.0, -21.0) + Vector3(-1.4, 0.0, 1.0), 0.0)

func _shooting_star() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2(1.0, 1.0)
    _streak_material = MaterialKitClass.shader("res://assets/shaders/meteor.gdshader", {})
    _streak = add(quad, _streak_material)
    _streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # the quad's bounds are not where the shader draws it: it is always worth drawing
    _streak.extra_cull_margin = 16384.0
    _streak.visible = false
    _rng.seed = 41

func _animate(delta: float) -> void:
    # every so often one crosses the sky: high up, a streak lasting under a second
    _streak_age += delta
    if _clock > _next_streak:
        var a := _rng.randf_range(-1.2, 1.2)
        _streak_from = Vector3(sin(a), _rng.randf_range(0.45, 0.8), -cos(a)).normalized() * 700.0
        _streak_to = _streak_from + Vector3(_rng.randf_range(-260.0, 260.0), _rng.randf_range(-200.0, -80.0), _rng.randf_range(-60.0, 60.0))
        _streak_material.set_shader_parameter("way", (_streak_to - _streak_from).normalized())
        _streak_age = 0.0
        _next_streak = _clock + _rng.randf_range(5.0, 12.0)
    var life := _streak_age / 0.7
    _streak.visible = life < 1.0
    if _streak.visible:
        # the train grows behind the head, then the whole of it fades
        _streak.position = _streak_from.lerp(_streak_to, life)
        _streak_material.set_shader_parameter("length_m", _streak_from.distance_to(_streak_to) * 0.35 * minf(life * 3.0, 1.0))
        _streak_material.set_shader_parameter("energy", 3.0 * sin(life * PI))
