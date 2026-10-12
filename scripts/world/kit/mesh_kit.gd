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
