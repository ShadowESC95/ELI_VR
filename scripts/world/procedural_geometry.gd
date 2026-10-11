extends RefCounted

func torus_mesh(
    major_radius: float,
    tube_radius: float,
    major_segments: int = 64,
    tube_segments: int = 10,
    arc_radians: float = TAU
) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for i in range(major_segments):
        var u0: float = arc_radians * float(i) / float(major_segments)
        var u1: float = arc_radians * float(i + 1) / float(major_segments)
        for j in range(tube_segments):
            var v0: float = TAU * float(j) / float(tube_segments)
            var v1: float = TAU * float(j + 1) / float(tube_segments)

            _torus_vertex(st, major_radius, tube_radius, u0, v0)
            _torus_vertex(st, major_radius, tube_radius, u1, v0)
            _torus_vertex(st, major_radius, tube_radius, u1, v1)

            _torus_vertex(st, major_radius, tube_radius, u0, v0)
            _torus_vertex(st, major_radius, tube_radius, u1, v1)
            _torus_vertex(st, major_radius, tube_radius, u0, v1)

    return st.commit()

func _torus_vertex(
    st: SurfaceTool,
    major_radius: float,
    tube_radius: float,
    u: float,
    v: float
) -> void:
    var cv: float = cos(v)
    var sv: float = sin(v)
    var cu: float = cos(u)
    var su: float = sin(u)
    var ring_r: float = major_radius + tube_radius * cv
    var p: Vector3 = Vector3(ring_r * cu, tube_radius * sv, ring_r * su)
    var n: Vector3 = Vector3(cv * cu, sv, cv * su).normalized()
    st.set_normal(n)
    st.set_uv(Vector2(u / TAU, v / TAU))
    st.add_vertex(p)

func rock_mesh(radius: float, seed_value: float, longitude: int = 14, latitude: int = 9) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for y in range(latitude):
        var v0: float = float(y) / float(latitude)
        var v1: float = float(y + 1) / float(latitude)
        var phi0: float = -PI * 0.5 + PI * v0
        var phi1: float = -PI * 0.5 + PI * v1

        for x in range(longitude):
            var u0: float = float(x) / float(longitude)
            var u1: float = float(x + 1) / float(longitude)
            var theta0: float = TAU * u0
            var theta1: float = TAU * u1

            _rock_vertex(st, radius, seed_value, theta0, phi0, u0, v0)
            _rock_vertex(st, radius, seed_value, theta1, phi0, u1, v0)
            _rock_vertex(st, radius, seed_value, theta1, phi1, u1, v1)

            _rock_vertex(st, radius, seed_value, theta0, phi0, u0, v0)
            _rock_vertex(st, radius, seed_value, theta1, phi1, u1, v1)
            _rock_vertex(st, radius, seed_value, theta0, phi1, u0, v1)

    st.generate_normals()
    return st.commit()

func _rock_vertex(
    st: SurfaceTool,
    radius: float,
    seed_value: float,
    theta: float,
    phi: float,
    u: float,
    v: float
) -> void:
    var cp: float = cos(phi)
    var dir: Vector3 = Vector3(cp * cos(theta), sin(phi), cp * sin(theta))
    var warp: float = (
        sin(theta * 3.0 + seed_value) * 0.10
        + sin(phi * 5.0 - seed_value * 0.7) * 0.08
        + sin((theta + phi) * 7.0 + seed_value * 1.9) * 0.045
        + sin(theta * 11.0 - phi * 4.0 + seed_value) * 0.025
    )
    var squash: float = 0.84 + 0.16 * absf(dir.y)
    var p: Vector3 = dir * radius * (1.0 + warp)
    p.y *= squash
    st.set_uv(Vector2(u, v))
    st.add_vertex(p)
