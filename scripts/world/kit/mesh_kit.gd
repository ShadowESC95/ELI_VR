class_name MeshKit
extends RefCounted

# The shapes rooms are put together from. Each comes back with normals,
# tangents and UVs measured in metres, so a tiling material sits right on any
# of them without stretching.

# A profile spun around the Y axis. Points are (radius, height), listed going
# outward along the top, down the outside, then back in underneath. Each band
# between two points is flat, which gives the hard edges of machined metal.
static func lathe(profile: PackedVector2Array, segments: int = 64) -> ArrayMesh:
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
            var t0 := TAU * float(s) / float(segments)
            var t1 := TAU * float(s + 1) / float(segments)
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
    return st.commit()

# A flat ring lying in the XZ plane, facing up. inner = 0 gives a disc.
static func annulus(inner: float, outer: float, segments: int = 96) -> ArrayMesh:
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
    return st.commit()

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

# Open ground: a square of land centred on the origin. It is level inside
# `flat` metres of the centre, where the room's floor goes, and rises into
# the noise over the next `rise` metres. `bowl` lifts the far edges, for land
# that climbs away from you.
static func terrain(
    size: float, cells: int, noise: FastNoiseLite, height: float,
    flat: float, rise: float, bowl: float = 0.0, base_y: float = 0.0
) -> ArrayMesh:
    var step := size / float(cells)
    var half := size * 0.5
    var heights := PackedFloat32Array()
    heights.resize((cells + 1) * (cells + 1))
    for j in cells + 1:
        for i in cells + 1:
            var x := -half + step * i
            var z := -half + step * j
            var r := Vector2(x, z).length()
            var lift := smoothstep(flat, flat + rise, r)
            var far := clampf((r - flat) / maxf(half - flat, 0.001), 0.0, 1.0)
            heights[j * (cells + 1) + i] = base_y + lift * (
                height * (noise.get_noise_2d(x, z) * 0.5 + 0.5) + bowl * far * far)

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
    return st.commit()

# A boulder: a ball pushed in and out by noise. Each seed is a different rock.
static func rock(seed_value: int, radius: float, lumps: float = 0.35, rings: int = 14) -> ArrayMesh:
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
    return st.commit()

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
    return st.commit()

# Two triangles, wound so the face shows from the side its normal points to.
static func _quad(
    st: SurfaceTool,
    p00: Vector3, p01: Vector3, p11: Vector3, p10: Vector3,
    n0: Vector3, n1: Vector3,
    uv00: Vector2, uv01: Vector2, uv11: Vector2, uv10: Vector2
) -> void:
    var facing := (p01 - p00).cross(p10 - p00).dot(n0 + n1)
    var order := [0, 1, 2, 0, 2, 3] if facing < 0.0 else [0, 2, 1, 0, 3, 2]
    var points := [p00, p01, p11, p10]
    var normals := [n0, n1, n1, n0]
    var uvs := [uv00, uv01, uv11, uv10]
    for i in order:
        st.set_normal(normals[i])
        st.set_uv(uvs[i])
        st.add_vertex(points[i])
