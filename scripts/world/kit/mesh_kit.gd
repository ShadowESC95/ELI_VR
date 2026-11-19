class_name MeshKit
extends RefCounted

# The shapes rooms are put together from. Each comes back with normals,
# tangents and UVs measured in metres, so a tiling material sits right on any
# of them without stretching.
#
# A room's shapes are worked out once. Making them is most of what building a room costs (a sea of
# forty thousand triangles, the land, a flock's bird), and a room is built again every time you
# come back to it: so each room keeps the shapes its last build asked for (RoomBase.build says
# which room is being built) and is handed them again when it asks for the same. A shape a room no
# longer asks for is let go when its build ends, so what is kept never grows past what the rooms
# as they now are use. Shapes are shared, never changed: a room gives them a material of its own
# (material_override), not one set on the mesh.

static var _rooms := {}        # room -> {what a shape was made from: the shape}, as its last build left it
static var _building := ""     # the room being built now, "" between builds
static var _asked := {}        # the shapes this build has asked for so far

# --- parts: a plain shape hung on something ----------------------------------------------------
# The rooms, ELI's things, its guns and its bookcases are all put together from these, each with
# its own sizes and how finely it is turned.

## `mesh` as a part of `parent`, in `material`, at `at` and turned `turn` degrees.
static func part(parent: Node, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = material
    node.position = at
    node.rotation_degrees = turn
    parent.add_child(node)
    return node

static func box(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh

## A cylinder standing along Y, `sides` round; a top of 0 makes it a cone.
static func cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top
    mesh.bottom_radius = bottom
    mesh.height = height
    mesh.radial_segments = sides
    return mesh

static func ball(radius: float) -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    return mesh

## A light that shines all round from `at` on `parent`, casting no shadow.
static func omni(parent: Node, at: Vector3, colour: Color, reach: float, energy: float = 1.0) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = at
    light.light_color = colour
    light.light_energy = energy
    light.omni_range = reach
    light.shadow_enabled = false
    parent.add_child(light)
    return light

## The turn that lays what stands along Y (a cylinder) along `direction`.
static func laid_along(direction: Vector3) -> Basis:
    return Basis(Quaternion(Vector3.UP, direction.normalized()))

## A room starts building: the shapes it asks for from here to built() are its own to keep.
static func build_of(room: String) -> void:
    _building = room
    _asked = {}

## The room is built: it keeps what this build asked for, and lets go of what it did not.
static func built() -> void:
    if not _building.is_empty():
        _rooms[_building] = _asked
    _building = ""
    _asked = {}

## The room being built now ("" when none is): for a shape that is finished after the build (land
## made on a worker thread) to be kept for it with keep().
static func building() -> String:
    return _building

## The shape made from `key` the last time `room` was built (the one being built, by default), or null.
static func kept(key: Array, room: String = "") -> ArrayMesh:
    return held(key, room) as ArrayMesh

## Keeps `shape`, made from `key`, for `room` (the one being built, by default); gives it back.
static func keep(key: Array, shape: ArrayMesh, room: String = "") -> ArrayMesh:
    hold(key, shape, room)
    return shape

## Anything else a room works out once and is handed again the next time it is built (a batch of
## instances, say), kept as its shapes are: what was held for `key`, or null.
static func held(key: Array, room: String = "") -> Variant:
    if room.is_empty():
        room = _building
    if room.is_empty():
        return null
    var thing = (_rooms.get(room, {}) as Dictionary).get(key)
    if thing == null and room == _building:
        thing = _asked.get(key)
    if thing != null and room == _building:
        _asked[key] = thing
    return thing

static func hold(key: Array, thing: Variant, room: String = "") -> void:
    if room.is_empty():
        room = _building
    if room.is_empty():
        return
    if room == _building:
        _asked[key] = thing
    elif _rooms.has(room):
        (_rooms[room] as Dictionary)[key] = thing

## What a noise is, for telling one from another: every setting it stores.
static func noise_key(noise: FastNoiseLite) -> Array:
    var out := []
    for property in noise.get_property_list():
        if int(property["usage"]) & PROPERTY_USAGE_STORAGE:
            out.append(noise.get(property["name"]))
    return out

## What a piece of land is made from: terrain()'s arguments, the noise by its settings.
static func terrain_key(size: float, cells: int, noise: FastNoiseLite, height: float, flat: float, rise: float,
                        bowl: float, base_y: float, fade: float, dunes: Vector4) -> Array:
    return ["terrain", size, cells, noise_key(noise), height, flat, rise, bowl, base_y, fade, dunes]

# A profile spun around the Y axis. Points are (radius, height), listed going
# outward along the top, down the outside, then back in underneath. Each band
# between two points is flat, which gives the hard edges of machined metal.
# `arc` below a full turn spins it only that far, from the angle `from` (0 is
# +X, turning towards +Z): a dome with its slit left open, a shutter leaf.
static func lathe(profile: PackedVector2Array, segments: int = 64, from: float = 0.0, arc: float = TAU) -> ArrayMesh:
    var key := ["lathe", profile, segments, from, arc]
    var had := kept(key)
    if had != null:
        return had
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var run := 0.0
    for i in range(profile.size() - 1):
        var a := profile[i]
        var b := profile[i + 1]
        var length := a.distance_to(b)
        if length < 0.0001:
            continue
        var along := (b - a) / length
        var out := Vector2(-along.y, along.x)
        var girth := maxf((a.x + b.x) * 0.5, 0.01)
        for s in segments:
            var t0 := from + arc * float(s) / float(segments)
            var t1 := from + arc * float(s + 1) / float(segments)
            var c0 := Vector3(cos(t0), 0.0, sin(t0))
            var c1 := Vector3(cos(t1), 0.0, sin(t1))
            _quad(
                st,
                c0 * a.x + Vector3.UP * a.y, c1 * a.x + Vector3.UP * a.y,
                c1 * b.x + Vector3.UP * b.y, c0 * b.x + Vector3.UP * b.y,
                c0 * out.x + Vector3.UP * out.y, c1 * out.x + Vector3.UP * out.y,
                Vector2(t0 * girth, run), Vector2(t1 * girth, run),
                Vector2(t1 * girth, run + length), Vector2(t0 * girth, run + length)
            )
        run += length
    st.generate_tangents()
    return keep(key, st.commit())

# A flat ring lying in the XZ plane, facing up. inner = 0 gives a disc.
static func annulus(inner: float, outer: float, segments: int = 96) -> ArrayMesh:
    var key := ["annulus", inner, outer, segments]
    var had := kept(key)
    if had != null:
        return had
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for s in segments:
        var t0 := TAU * float(s) / float(segments)
        var t1 := TAU * float(s + 1) / float(segments)
        var c0 := Vector3(cos(t0), 0.0, sin(t0))
        var c1 := Vector3(cos(t1), 0.0, sin(t1))
        var p00 := c0 * inner
        var p01 := c1 * inner
        var p11 := c1 * outer
        var p10 := c0 * outer
        _quad(
            st, p00, p01, p11, p10, Vector3.UP, Vector3.UP,
            Vector2(p00.x, p00.z), Vector2(p01.x, p01.z), Vector2(p11.x, p11.z), Vector2(p10.x, p10.z)
        )
    st.generate_tangents()
    return keep(key, st.commit())

# A disc lying in the XZ plane, facing up, made of rings that start `first` metres apart at the
# middle and widen in proportion to their distance out (so a surface moved in its vertex shader,
# like the sea's swell, has its finest grid where you are). The gap between rings at r metres out
# is disc_step(r, ...). UVs are in metres.
static func disc(radius: float, rings: int, segments: int, first: float) -> ArrayMesh:
    var key := ["disc", radius, rings, segments, first]
    var had := kept(key)
    if had != null:
        return had
    # written straight into the surface's arrays, each point once (a sea is tens of thousands of
    # triangles: put together a quad at a time it is the slowest shape a room asks for)
    var growth := disc_growth(radius, rings, first)
    var across := segments + 1                     # the seam's points are doubled, so the UVs do not wrap
    var points := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    points.resize((rings + 1) * across)
    normals.resize(points.size())
    uvs.resize(points.size())
    indices.resize(rings * segments * 6)
    var whole := exp(growth * float(rings)) - 1.0
    for k in rings + 1:
        var r := radius * (exp(growth * float(k)) - 1.0) / whole
        for s in across:
            var angle := TAU * float(s) / float(segments)
            var at := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
            var n := k * across + s
            points[n] = at
            normals[n] = Vector3.UP
            uvs[n] = Vector2(at.x, at.z)
    var i := 0
    for k in rings:
        for s in segments:
            var p00 := k * across + s
            var p01 := p00 + 1
            var p10 := p00 + across
            var p11 := p10 + 1
            # wound to face up, as _quad winds a face to its normal
            for index in [p00, p11, p01, p00, p10, p11]:
                indices[i] = index
                i += 1
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return keep(key, mesh)

## How fast disc()'s rings widen: the g for which ring k sits at radius·(e^{gk} − 1)/(e^{gn} − 1)
## and the first is `first` metres out.
static func disc_growth(radius: float, rings: int, first: float) -> float:
    var lo := 1e-4
    var hi := 1.0
    for i in 60:
        var g := (lo + hi) * 0.5
        var r1 := radius * (exp(g) - 1.0) / (exp(g * float(rings)) - 1.0)
        if r1 > first:
            lo = g
        else:
            hi = g
    return (lo + hi) * 0.5

## The gap between disc()'s rings r metres out: g·(r + radius/(e^{gn} − 1)).
static func disc_step(r: float, radius: float, rings: int, growth: float) -> float:
    return growth * (r + radius / (exp(growth * float(rings)) - 1.0))

# A rectangular beam following a path. `side` is the direction the beam is
# wide in and stays fixed, so the path should lie in the plane across it.
static func beam(path: PackedVector3Array, side: Vector3, width: float, depth: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    side = side.normalized()
    var run := 0.0
    for i in range(path.size() - 1):
        var p := path[i]
        var q := path[i + 1]
        var length := p.distance_to(q)
        if length < 0.0001:
            continue
        var forward := (q - p) / length
        var up := side.cross(forward).normalized()
        var w := side * width * 0.5
        var d := up * depth * 0.5
        # four faces: +up, -up, +side, -side
        for face in [[d, w, up, width], [-d, -w, -up, width], [w, -d, side, depth], [-w, d, -side, depth]]:
            var centre: Vector3 = face[0]
            var across: Vector3 = face[1]
            var normal: Vector3 = face[2]
            var span: float = face[3]
            _quad(
                st,
                p + centre - across, p + centre + across, q + centre + across, q + centre - across,
                normal, normal,
                Vector2(0.0, run), Vector2(span, run), Vector2(span, run + length), Vector2(0.0, run + length)
            )
        run += length
    st.generate_tangents()
    return st.commit()

# Points along a quarter ellipse from (r0, y0) at the bottom to (r1, y1) at
# the top, in the plane through the Y axis at `angle`.
static func arc(r0: float, y0: float, r1: float, y1: float, angle: float, steps: int = 24) -> PackedVector3Array:
    var out := PackedVector3Array()
    var dir := Vector3(cos(angle), 0.0, sin(angle))
    for i in steps + 1:
        var t := float(i) / float(steps) * PI * 0.5
        out.append(dir * (r1 + (r0 - r1) * cos(t)) + Vector3.UP * (y0 + (y1 - y0) * sin(t)))
    return out

# The height of open ground at (x, z): level at `base_y` inside `flat` metres of the centre, where
# the room's floor goes, rising into the noise over the next `rise` metres; `bowl` lifts the far
# edges, for land that climbs away from you; `fade` (metres) settles the land back to `base_y`
# over its last `fade` metres, so it meets a photograph's flat ground without a step. `dunes`
# (see dune_height) lays a field of wind-built dunes over it. terrain() is built from this, and
# LandKit stands things on it by the same figure.
static func land_height(
    x: float, z: float, size: float, noise: FastNoiseLite, height: float,
    flat: float, rise: float, bowl: float = 0.0, base_y: float = 0.0, fade: float = 0.0,
    dunes: Vector4 = Vector4.ZERO
) -> float:
    var half := size * 0.5
    var r := Vector2(x, z).length()
    var lift := smoothstep(flat, flat + rise, r)
    var far := clampf((r - flat) / maxf(half - flat, 0.001), 0.0, 1.0)
    var settle := 1.0 if fade <= 0.0 else 1.0 - smoothstep(half - fade, half, maxf(absf(x), absf(z)))
    return base_y + settle * lift * (height * (noise.get_noise_2d(x, z) * 0.5 + 0.5) + bowl * far * far
                                     + dune_height(x, z, dunes, noise))

# Dry sand slides when it lies steeper than this (its angle of repose, about 32 degrees, as a slope).
const REPOSE := 0.625

# Transverse dunes built by a wind blowing towards (dunes.x, dunes.y), crests `dunes.z` metres
# apart and up to `dunes.w` high: each rises gently on its windward side to a sharp brink and
# falls away on its slip face at the angle of repose, as dunes do. The crests wander (the noise
# bends them) and the dunes grow and shrink along them. 0 when `dunes.w` is 0.
static func dune_height(x: float, z: float, dunes: Vector4, noise: FastNoiseLite) -> float:
    if dunes.w <= 0.0:
        return 0.0
    var wind := Vector2(dunes.x, dunes.y).normalized()
    var p := Vector2(x, z)
    var along := p.dot(wind)
    var across := p.dot(Vector2(-wind.y, wind.x))
    var s := along / dunes.z + 0.7 * noise.get_noise_2d(across * 0.3 + 1000.0, along * 0.08 - 500.0)
    var f := s - floorf(s)
    var tall := dunes.w * (0.6 + 0.4 * noise.get_noise_2d(x * 0.35 + 300.0, z * 0.35 - 700.0))
    # the share of each dune's length its slip face takes, so the face lies at the angle of repose
    var lee := clampf(tall / (REPOSE * dunes.z), 0.04, 0.45)
    var brink := 1.0 - lee
    if f < brink:
        var t := f / brink
        return tall * t * t * (3.0 - 2.0 * t)
    return tall * (1.0 - (f - brink) / lee)

# Open ground: a square of land centred on the origin, `cells` across, shaped by land_height.
static func terrain(
    size: float, cells: int, noise: FastNoiseLite, height: float,
    flat: float, rise: float, bowl: float = 0.0, base_y: float = 0.0, fade: float = 0.0,
    dunes: Vector4 = Vector4.ZERO
) -> ArrayMesh:
    var key := terrain_key(size, cells, noise, height, flat, rise, bowl, base_y, fade, dunes)
    var had := kept(key)
    if had != null:
        return had
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
        terrain_arrays(size, cells, noise, height, flat, rise, bowl, base_y, fade, dunes))
    return keep(key, mesh)

# The same ground as surface arrays (Mesh.ARRAY_*). Made without touching the scene or the renderer,
# so it can be made on a worker thread (LandKit.lay(in_background)) with a noise of its own.
static func terrain_arrays(
    size: float, cells: int, noise: FastNoiseLite, height: float,
    flat: float, rise: float, bowl: float = 0.0, base_y: float = 0.0, fade: float = 0.0,
    dunes: Vector4 = Vector4.ZERO
) -> Array:
    var step := size / float(cells)
    var half := size * 0.5
    var heights := PackedFloat32Array()
    heights.resize((cells + 1) * (cells + 1))
    for j in cells + 1:
        for i in cells + 1:
            heights[j * (cells + 1) + i] = land_height(-half + step * i, -half + step * j, size, noise, height,
                                                       flat, rise, bowl, base_y, fade, dunes)

    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in cells + 1:
        for i in cells + 1:
            var x := -half + step * i
            var z := -half + step * j
            var left := heights[j * (cells + 1) + maxi(i - 1, 0)]
            var right := heights[j * (cells + 1) + mini(i + 1, cells)]
            var back := heights[maxi(j - 1, 0) * (cells + 1) + i]
            var front := heights[mini(j + 1, cells) * (cells + 1) + i]
            st.set_normal(Vector3(left - right, 2.0 * step, back - front).normalized())
            st.set_uv(Vector2(x, z))
            st.add_vertex(Vector3(x, heights[j * (cells + 1) + i], z))
    for j in cells:
        for i in cells:
            var a := j * (cells + 1) + i
            var b := a + 1
            var c := a + cells + 1
            var d := c + 1
            for index in [a, b, c, b, d, c]:
                st.add_index(index)
    st.generate_tangents()
    return st.commit_to_arrays()

# A boulder: a ball pushed in and out by noise. Each seed is a different rock.
static func rock(seed_value: int, radius: float, lumps: float = 0.35, rings: int = 14) -> ArrayMesh:
    var key := ["rock", seed_value, radius, lumps, rings]
    var had := kept(key)
    if had != null:
        return had
    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = 0.9
    noise.fractal_octaves = 3
    var around := rings * 2
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in rings + 1:
        var v := float(j) / float(rings)
        var polar := v * PI
        for i in around + 1:
            var u := float(i) / float(around)
            var angle := u * TAU
            var dir := Vector3(sin(polar) * cos(angle), cos(polar), sin(polar) * sin(angle))
            var push := 1.0 + lumps * noise.get_noise_3dv(dir * 1.7) + lumps * 0.4 * noise.get_noise_3dv(dir * 5.0)
            st.set_uv(Vector2(u * 4.0, v * 2.0) * radius)
            st.add_vertex(dir * radius * push * Vector3(1.0, 0.78, 1.0))
    for j in rings:
        for i in around:
            var a := j * (around + 1) + i
            var b := a + 1
            var c := a + around + 1
            var d := c + 1
            for index in [a, b, c, b, d, c]:
                st.add_index(index)
    st.generate_normals()
    st.generate_tangents()
    return keep(key, st.commit())

# A mesa or a butte: a hill of flat-lying rock worn back to a hard cap. A flat top under its cap
# rock, a cliff broken by ledges where softer beds weathered back, and the scree it sheds spread
# round its foot. `radius` is the cap's, `height` the top's above the plain; `cap` below 1 makes
# the cap narrow against the foot (a butte). Each seed is a different hill: the outline wanders
# and the beds stand out by different amounts. Faces are flat, as broken rock is.
static func mesa(seed_value: int, radius: float, height: float, cap: float = 1.0, segments: int = 56) -> ArrayMesh:
    var key := ["mesa", seed_value, radius, height, cap, segments]
    var had := kept(key)
    if had != null:
        return had
    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = 1.0
    noise.fractal_octaves = 3
    # the profile out from the middle, top down: [share of the cap's radius, share of the height]
    var profile := [[0.0, 1.0], [0.84, 1.0], [0.9, 0.985], [0.9, 0.9], [0.86, 0.87], [0.92, 0.85], [0.93, 0.66],
                    [0.88, 0.63], [0.97, 0.6], [1.0, 0.54], [1.3, 0.38], [1.7, 0.2], [2.1, 0.06], [2.45, 0.0]]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings := []
    for j in profile.size():
        var ring := PackedVector3Array()
        var spread: float = float(profile[j][0])
        # the cap is narrower on a butte; the scree spreads as wide whatever the cap
        var out := spread * cap if spread <= 1.0 else cap + (spread - 1.0)
        for s in segments:
            var a := TAU * float(s) / float(segments)
            var round := Vector2(cos(a), sin(a))
            var wander := 1.0 + 0.24 * noise.get_noise_2dv(round * 1.3) + 0.07 * noise.get_noise_2dv(round * 5.0 + Vector2(j, 0.0))
            ring.append(Vector3(round.x * out * radius * wander, float(profile[j][1]) * height, round.y * out * radius * wander))
        rings.append(ring)
    for j in profile.size() - 1:
        for s in segments:
            var t := (s + 1) % segments
            var a: Vector3 = rings[j][s]
            var b: Vector3 = rings[j][t]
            var c: Vector3 = rings[j + 1][t]
            var d: Vector3 = rings[j + 1][s]
            var out := ((a + b + c + d) * 0.25 * Vector3(1, 0, 1)).normalized() + Vector3.UP * 0.001
            var normal := (c - a).cross(d - b).normalized()      # across the diagonals: whole even where a quad is a triangle
            if normal.dot(out + Vector3.UP) < 0.0:
                normal = -normal
            _quad(st, a, b, c, d, normal, normal, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(d.x, d.z))
    st.generate_tangents()
    return keep(key, st.commit())

# A sheet hanging along a path: aurora, banners, falls of light. UV.x runs
# along the path in metres, UV.y from 0 at the bottom to 1 at the top.
static func curtain(path: PackedVector3Array, height: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var run := 0.0
    for i in range(path.size() - 1):
        var p := path[i]
        var q := path[i + 1]
        var length := p.distance_to(q)
        if length < 0.0001:
            continue
        var normal := Vector3.UP.cross(q - p).normalized()
        var up := Vector3.UP * height
        _quad(
            st, p, q, q + up, p + up, normal, normal,
            Vector2(run, 0.0), Vector2(run + length, 0.0), Vector2(run + length, 1.0), Vector2(run, 1.0)
        )
        run += length
    st.generate_tangents()
    return st.commit()

# A plant: blades fanned round a point, each standing up and leaning over as
# it rises. Ferns, kelp, reeds. UV.y is 1 at the root and 0 at the tip.
static func plant(blades: int, width: float, height: float, lean: float, seed_value: int = 1, segments: int = 6) -> ArrayMesh:
    var key := ["plant", blades, width, height, lean, seed_value, segments]
    var had := kept(key)
    if had != null:
        return had
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for b in blades:
        var angle := TAU * float(b) / float(blades) + rng.randf_range(-0.3, 0.3)
        var out := Vector3(cos(angle), 0.0, sin(angle))
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        var tall := height * rng.randf_range(0.7, 1.1)
        var over := lean * rng.randf_range(0.6, 1.25)
        for s in segments:
            var t0 := float(s) / float(segments)
            var t1 := float(s + 1) / float(segments)
            var p0 := out * (over * t0 * t0) + Vector3.UP * (tall * (t0 - 0.28 * t0 * t0))
            var p1 := out * (over * t1 * t1) + Vector3.UP * (tall * (t1 - 0.28 * t1 * t1))
            var w := side * width * 0.5
            var normal := side.cross(p1 - p0).normalized()
            _quad(st, p0 - w, p0 + w, p1 + w, p1 - w, normal, normal,
                Vector2(0.0, 1.0 - t0), Vector2(1.0, 1.0 - t0), Vector2(1.0, 1.0 - t1), Vector2(0.0, 1.0 - t1))
    st.generate_tangents()
    return keep(key, st.commit())

# A bird in flight, wings spread, `span` metres from tip to tip, facing −Z with its back up, made
# to `shape` (the kinds are in kit/flock.gd: body length, the wing's leading and trailing edge at
# stations out along it, where the wrist is, the plumage). Each wing is a thin cambered aerofoil
# with an upper and a lower skin; the body is a tapering oval from the bill to a fanned tail. The
# plumage is in the vertex colour (back and upper wing, underside, the dark wingtips), and every
# vertex of a wing carries in UV2.x how far out along it it is (0 at the shoulder, 1 at the tip,
# negative on the left wing; the body carries 0): that is what bird.gdshader bends at the shoulder
# (bird_shoulder()) and the wrist to beat and to glide.
static func bird(span: float, shape: Dictionary) -> ArrayMesh:
    var key := ["bird", span, shape]
    var had := kept(key)
    if had != null:
        return had
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var length: float = float(shape["length"]) * span
    var body: Color = shape["body"]
    var back: Color = shape["mantle"]
    var bill: Color = shape["bill"]
    # the body: rings from the bill's tip (t = 0) to the tail's end (t = 1), each [t, half width,
    # half height] as shares of the body's length; a last ring closes the tail
    var rings: Array = shape["rings"]
    var around := 8
    for i in range(rings.size() - 1):
        var a: Array = rings[i]
        var b: Array = rings[i + 1]
        var za := (float(a[0]) - 0.5) * length
        var zb := (float(b[0]) - 0.5) * length
        for s in around:
            var t0 := TAU * float(s) / float(around)
            var t1 := TAU * float(s + 1) / float(around)
            var p00 := Vector3(cos(t0) * float(a[1]), sin(t0) * float(a[2]), 0.0) * length + Vector3(0, 0, za)
            var p01 := Vector3(cos(t1) * float(a[1]), sin(t1) * float(a[2]), 0.0) * length + Vector3(0, 0, za)
            var p11 := Vector3(cos(t1) * float(b[1]), sin(t1) * float(b[2]), 0.0) * length + Vector3(0, 0, zb)
            var p10 := Vector3(cos(t0) * float(b[1]), sin(t0) * float(b[2]), 0.0) * length + Vector3(0, 0, zb)
            var n0 := Vector3(cos(t0) * float(a[2]), sin(t0) * float(a[1]), 0.0).normalized()
            var n1 := Vector3(cos(t1) * float(a[2]), sin(t1) * float(a[1]), 0.0).normalized()
            var mid := (float(a[0]) + float(b[0])) * 0.5
            var upper := sin((t0 + t1) * 0.5) > 0.2
            var paint := bill if mid < float(shape["bill_to"]) else (back if upper and mid > 0.3 and mid < 0.8 else body)
            if float(b[1]) <= 0.0 and float(b[2]) <= 0.0:
                n0 = Vector3.BACK
                n1 = Vector3.BACK
            _quad(st, p00, p01, p11, p10, n0, n1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, paint, Vector4.ZERO)

    # the wings: strips between stations out from the shoulder, each an upper and a lower skin
    # meeting at the leading and trailing edges
    var shoulder := bird_shoulder(span, shape)
    var reach := span * 0.5 - shoulder
    var stations: Array = shape["stations"]
    var lead: Array = shape["lead"]
    var trail: Array = shape["trail"]
    var chord_at := [0.0, 0.3, 0.65, 1.0]
    for side in [-1.0, 1.0]:
        for i in range(stations.size() - 1):
            var f := [float(stations[i]), float(stations[i + 1])]
            var top_rows := []
            var under_rows := []
            for k in 2:
                var x: float = side * (shoulder + f[k] * reach)
                var le: float = float(lead[i + k]) * span
                var te: float = float(trail[i + k]) * span
                var thick: float = float(shape["thickness"]) * span * (1.0 - 0.75 * f[k])
                var camber: float = float(shape["camber"]) * span * (1.0 - 0.6 * f[k])
                var top := []
                var under := []
                for chord in chord_at:
                    var c: float = chord
                    var hump := 4.0 * c * (1.0 - c)
                    top.append(Vector3(x, camber * hump + thick * 0.5 * hump, lerpf(le, te, c)))
                    under.append(Vector3(x, camber * hump - thick * 0.2 * hump, lerpf(le, te, c)))
                top_rows.append(top)
                under_rows.append(under)
            var outer: float = (f[0] + f[1]) * 0.5
            var tip := outer > float(shape["tips_from"])
            var top_paint: Color = shape["tips"] if tip else back
            var under_paint: Color = (shape["tips"] as Color).lerp(shape["under"], 0.35) if tip else shape["under"]
            var spans := Vector4(side * f[0], side * f[1], side * f[1], side * f[0])
            for c in 3:
                _quad(st, top_rows[0][c], top_rows[0][c + 1], top_rows[1][c + 1], top_rows[1][c], Vector3.UP, Vector3.UP,
                      Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, top_paint, Vector4(spans.x, spans.x, spans.y, spans.y))
                _quad(st, under_rows[0][c], under_rows[0][c + 1], under_rows[1][c + 1], under_rows[1][c], Vector3.DOWN, Vector3.DOWN,
                      Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, under_paint, Vector4(spans.x, spans.x, spans.y, spans.y))
    return keep(key, st.commit())

# A small open boat's hull, `length` long and `beam` wide, `depth` from the gunwale to the keel at
# its middle, bow towards −Z: sections lofted from a transom stern through a full middle to a
# fine bow, the sheer rising fore and aft, the bilge rounded. Open at the top; a material that
# shows both sides shows the inside of the hull too. UVs run in metres along and round it.
static func hull(length: float, beam: float, depth: float) -> ArrayMesh:
    var key := ["hull", length, beam, depth]
    var had := kept(key)
    if had != null:
        return had
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var stations := 14
    var round := 6
    var sections := []
    for i in stations + 1:
        var t := float(i) / float(stations)          # 0 at the stern, 1 at the bow
        var half := 0.5 * beam * (0.78 + 0.22 * sin(minf(t / 0.42, 1.0) * PI * 0.5)) if t <= 0.42 \
            else 0.5 * beam * sqrt(maxf(1.0 - pow((t - 0.42) / 0.58, 2.0), 0.0))
        var keel := depth * (0.8 + 0.2 * sin(t * PI)) * (1.0 - 0.6 * smoothstep(0.6, 1.0, t))
        var sheer := 0.12 * depth * pow(1.0 - t, 2.0) + 0.45 * depth * pow(t, 3.0)
        var section := []
        for j in round + 1:
            var a := float(j) / float(round) * PI * 0.5
            section.append(Vector3(half * pow(sin(a), 0.6), sheer - (keel + sheer) * pow(cos(a), 1.4), (0.5 - t) * length))
        sections.append(section)
    for side in [-1.0, 1.0]:
        for i in stations:
            for j in round:
                var a: Vector3 = sections[i][j] * Vector3(side, 1, 1)
                var b: Vector3 = sections[i][j + 1] * Vector3(side, 1, 1)
                var c: Vector3 = sections[i + 1][j + 1] * Vector3(side, 1, 1)
                var d: Vector3 = sections[i + 1][j] * Vector3(side, 1, 1)
                var normal := (c - a).cross(b - d).normalized()
                if normal.dot(Vector3(side, -0.3, 0.0)) < 0.0:
                    normal = -normal
                _quad(st, a, b, c, d, normal, normal,
                      Vector2(a.z, float(j) * 0.2), Vector2(b.z, float(j + 1) * 0.2),
                      Vector2(c.z, float(j + 1) * 0.2), Vector2(d.z, float(j) * 0.2))
        # the transom: the flat stern board
        for j in round:
            var a: Vector3 = sections[0][j] * Vector3(side, 1, 1)
            var b: Vector3 = sections[0][j + 1] * Vector3(side, 1, 1)
            _quad(st, Vector3(0.0, a.y, a.z), a, b, Vector3(0.0, b.y, b.z), Vector3.BACK, Vector3.BACK,
                  Vector2(0.0, a.y), Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(0.0, b.y))
    st.generate_tangents()
    return keep(key, st.commit())

# A fish, `length` metres from snout to tail tip, facing −Z with its back up, made to `shape` (the
# kinds are in kit/flock.gd): a deep, narrow body of rings [t, half width, half height] as shares
# of its length, a forked tail fin and a dorsal fin standing in its middle plane. Back and belly
# colours are in the vertex colour, and every vertex carries in UV2.x how far back along the fish
# it is (0 at the snout, 1 at the tail's tip): what fish.gdshader swings to swim.
static func fish(length: float, shape: Dictionary) -> ArrayMesh:
    var key := ["fish", length, shape]
    var had := kept(key)
    if had != null:
        return had
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array = shape["rings"]
    var back: Color = shape["back"]
    var belly: Color = shape["belly"]
    var fin: Color = shape["fin"]
    var around := 10
    for i in range(rings.size() - 1):
        var a: Array = rings[i]
        var b: Array = rings[i + 1]
        var za := (float(a[0]) - 0.5) * length
        var zb := (float(b[0]) - 0.5) * length
        for s in around:
            var t0 := TAU * float(s) / float(around)
            var t1 := TAU * float(s + 1) / float(around)
            var p00 := Vector3(cos(t0) * float(a[1]), sin(t0) * float(a[2]), 0.0) * length + Vector3(0, 0, za)
            var p01 := Vector3(cos(t1) * float(a[1]), sin(t1) * float(a[2]), 0.0) * length + Vector3(0, 0, za)
            var p11 := Vector3(cos(t1) * float(b[1]), sin(t1) * float(b[2]), 0.0) * length + Vector3(0, 0, zb)
            var p10 := Vector3(cos(t0) * float(b[1]), sin(t0) * float(b[2]), 0.0) * length + Vector3(0, 0, zb)
            var n0 := Vector3(cos(t0) * float(a[2]), sin(t0) * float(a[1]), 0.0).normalized()
            var n1 := Vector3(cos(t1) * float(a[2]), sin(t1) * float(a[1]), 0.0).normalized()
            var paint := back if sin((t0 + t1) * 0.5) > 0.15 else belly
            _quad(st, p00, p01, p11, p10, n0, n1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, paint,
                  Vector4(float(a[0]), float(a[0]), float(b[0]), float(b[0])))
    # the fins: sheets in the middle plane, each laid twice so both faces show
    var root: float = float(rings[rings.size() - 2][0])
    var tail := [
        [Vector3(0, 0.02, root), Vector3(0, 0.0, 1.0), Vector3(0, 0.16, 1.06), Vector3(0, 0.04, root)],
        [Vector3(0, -0.02, root), Vector3(0, 0.0, 1.0), Vector3(0, -0.16, 1.06), Vector3(0, -0.04, root)],
        [Vector3(0, float(shape["dorsal"]), 0.36), Vector3(0, float(shape["dorsal"]) + 0.07, 0.5),
         Vector3(0, float(shape["dorsal"]) - 0.01, 0.62), Vector3(0, float(shape["dorsal"]) - 0.02, 0.45)],
    ]
    for sheet in tail:
        var q := []
        var spans := []
        for v in sheet:
            q.append(Vector3(v.x, v.y * length, (v.z - 0.5) * length))
            spans.append(v.z)
        for side in [1.0, -1.0]:
            _quad(st, q[0], q[1], q[2], q[3], Vector3.RIGHT * side, Vector3.RIGHT * side,
                  Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, fin, Vector4(spans[0], spans[1], spans[2], spans[3]))
    return keep(key, st.commit())

## Where a bird's wings meet its body: metres out from the middle (the body's widest half-width).
static func bird_shoulder(span: float, shape: Dictionary) -> float:
    var widest := 0.0
    for ring in shape["rings"]:
        widest = maxf(widest, float(ring[1]))
    return widest * float(shape["length"]) * span * 0.8

# Two triangles, wound so the face shows from the side its normal points to. `paint` (when its
# alpha is above 0) is set as the vertex colour, and `spans` as UV2.x of p00, p01, p11, p10.
static func _quad(
    st: SurfaceTool,
    p00: Vector3, p01: Vector3, p11: Vector3, p10: Vector3,
    n0: Vector3, n1: Vector3,
    uv00: Vector2, uv01: Vector2, uv11: Vector2, uv10: Vector2,
    paint: Color = Color(0, 0, 0, 0), spans = null
) -> void:
    var facing := (p01 - p00).cross(p10 - p00).dot(n0 + n1)
    var order := [0, 1, 2, 0, 2, 3] if facing < 0.0 else [0, 2, 1, 0, 3, 2]
    var points := [p00, p01, p11, p10]
    var normals := [n0, n1, n1, n0]
    var uvs := [uv00, uv01, uv11, uv10]
    for i in order:
        if paint.a > 0.0:
            st.set_color(paint)
        if spans is Vector4:
            st.set_uv2(Vector2((spans as Vector4)[i], 0.0))
        st.set_normal(normals[i])
        st.set_uv(uvs[i])
        st.add_vertex(points[i])
