class_name CinematicAssets
extends RefCounted

var material_cache: Dictionary = {}

func material(
    kind: String,
    tint: Color = Color.WHITE,
    metallic: float = 0.0,
    roughness: float = 0.8,
    emission: Color = Color(0, 0, 0, 1),
    emission_energy: float = 1.0
) -> StandardMaterial3D:
    var key: String = "%s|%s|%.2f|%.2f|%s|%.2f" % [
        kind, tint.to_html(), metallic, roughness,
        emission.to_html(), emission_energy
    ]
    if material_cache.has(key):
        return material_cache[key] as StandardMaterial3D

    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metallic
    m.roughness = roughness

    var base: String = "res://assets/cinematic/textures/%s" % kind
    var albedo_path: String = base + "_albedo.png"
    var normal_path: String = base + "_normal.png"
    var rough_path: String = base + "_roughness.png"

    if ResourceLoader.exists(albedo_path):
        m.albedo_texture = load(albedo_path)
    # Runtime procedural meshes do not all carry tangent space yet.
    # Keep normal maps packaged for the authored/imported asset tier, but do
    # not bind them here; this avoids invalid tangent-dependent shading.
    if false and ResourceLoader.exists(normal_path):
        m.normal_enabled = true
        m.normal_texture = load(normal_path)
    if ResourceLoader.exists(rough_path):
        m.roughness_texture = load(rough_path)
        m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

    if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = emission_energy

    material_cache[key] = m
    return m

func tree_mesh(seed_value: int) -> ArrayMesh:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = seed_value

    var trunk: SurfaceTool = SurfaceTool.new()
    trunk.begin(Mesh.PRIMITIVE_TRIANGLES)

    var height: float = rng.randf_range(7.0, 11.5)
    var p0: Vector3 = Vector3.ZERO
    var p1: Vector3 = Vector3(
        rng.randf_range(-0.20, 0.20),
        height,
        rng.randf_range(-0.20, 0.20)
    )
    _append_tube(trunk, p0, p1, 0.28, 0.10, 9)

    var tips: Array[Vector3] = []
    for level in range(4):
        var y: float = height * (0.36 + float(level) * 0.15)
        var branches: int = 4 if level < 2 else 3
        for b in range(branches):
            var a: float = TAU * float(b) / float(branches) + float(level) * 0.83 + rng.randf_range(-0.25, 0.25)
            var start: Vector3 = Vector3(0.0, y, 0.0)
            var length: float = rng.randf_range(1.4, 2.7) * (1.0 - float(level) * 0.10)
            var end: Vector3 = start + Vector3(
                cos(a) * length,
                rng.randf_range(0.5, 1.5),
                sin(a) * length
            )
            _append_tube(trunk, start, end, 0.11, 0.045, 7)
            tips.append(end)

    var mesh: ArrayMesh = trunk.commit()
    mesh.surface_set_material(0, material("bark", Color.WHITE, 0.0, 0.94))

    var leaves: SurfaceTool = SurfaceTool.new()
    leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tip in tips:
        _append_blob(
            leaves,
            tip + Vector3(0.0, 0.35, 0.0),
            Vector3(
                rng.randf_range(0.75, 1.25),
                rng.randf_range(0.9, 1.55),
                rng.randf_range(0.75, 1.25)
            ),
            rng.randf_range(0.0, 100.0),
            9,
            6
        )
    _append_blob(
        leaves,
        p1 + Vector3(0.0, 0.4, 0.0),
        Vector3(1.2, 1.6, 1.2),
        rng.randf_range(0.0, 100.0),
        10,
        7
    )
    leaves.commit(mesh)
    mesh.surface_set_material(1, material("foliage", Color.WHITE, 0.0, 0.88))
    return mesh

func coral_mesh(seed_value: int) -> ArrayMesh:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = seed_value
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var root: Vector3 = Vector3.ZERO
    var main_top: Vector3 = Vector3(0.0, rng.randf_range(2.3, 4.4), 0.0)
    _append_tube(st, root, main_top, 0.18, 0.075, 8)
    for i in range(7):
        var y: float = rng.randf_range(0.7, main_top.y * 0.92)
        var a: float = rng.randf_range(0.0, TAU)
        var start: Vector3 = Vector3(0.0, y, 0.0)
        var mid: Vector3 = start + Vector3(cos(a), rng.randf_range(0.25, 0.8), sin(a)) * rng.randf_range(0.6, 1.2)
        var end: Vector3 = mid + Vector3(cos(a + rng.randf_range(-0.5,0.5)), rng.randf_range(0.6, 1.3), sin(a + rng.randf_range(-0.5,0.5))) * rng.randf_range(0.5, 1.1)
        _append_tube(st, start, mid, 0.09, 0.055, 7)
        _append_tube(st, mid, end, 0.055, 0.025, 7)

    var mesh: ArrayMesh = st.commit()
    mesh.surface_set_material(0, material("coral", Color.WHITE, 0.0, 0.80))
    return mesh

func glacier_mesh(seed_value: int) -> ArrayMesh:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = seed_value
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 8
    var height: float = rng.randf_range(4.0, 11.0)
    var rings: Array[float] = [0.0, 0.45, 0.78, 1.0]
    for r in range(rings.size() - 1):
        var t0: float = rings[r]
        var t1: float = rings[r + 1]
        var rad0: float = lerpf(rng.randf_range(1.0,2.2), 0.06, pow(t0,1.7))
        var rad1: float = lerpf(rad0, 0.03, pow(t1,1.6))
        for i in range(sides):
            var a0: float = TAU * float(i) / float(sides)
            var a1: float = TAU * float(i+1) / float(sides)
            var p00: Vector3 = Vector3(cos(a0)*rad0, t0*height, sin(a0)*rad0)
            var p01: Vector3 = Vector3(cos(a1)*rad0, t0*height, sin(a1)*rad0)
            var p10: Vector3 = Vector3(cos(a0)*rad1, t1*height, sin(a0)*rad1)
            var p11: Vector3 = Vector3(cos(a1)*rad1, t1*height, sin(a1)*rad1)
            _tri(st,p00,p10,p11)
            _tri(st,p00,p11,p01)
    st.generate_normals()
    var mesh: ArrayMesh = st.commit()
    mesh.surface_set_material(0, material("ice", Color(0.85,0.98,1.0), 0.0, 0.28))
    return mesh

func mobius_mesh(radius: float, half_width: float, segments: int = 120, width_segments: int = 8) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(segments):
        var u0: float = TAU * float(i) / float(segments)
        var u1: float = TAU * float(i+1) / float(segments)
        for j in range(width_segments):
            var v0: float = lerpf(-half_width, half_width, float(j)/float(width_segments))
            var v1: float = lerpf(-half_width, half_width, float(j+1)/float(width_segments))
            _mobius_vertex(st,radius,u0,v0)
            _mobius_vertex(st,radius,u1,v0)
            _mobius_vertex(st,radius,u1,v1)
            _mobius_vertex(st,radius,u0,v0)
            _mobius_vertex(st,radius,u1,v1)
            _mobius_vertex(st,radius,u0,v1)
    var mesh: ArrayMesh = st.commit()
    return mesh

func ribbon_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    if points.size() < 2:
        return st.commit()
    for i in range(points.size()-1):
        var a: Vector3 = points[i]
        var b: Vector3 = points[i+1]
        var dir: Vector3 = (b-a).normalized()
        var side: Vector3 = dir.cross(Vector3.UP)
        if side.length_squared() < 0.001:
            side = dir.cross(Vector3.RIGHT)
        side = side.normalized() * width
        _quad(st, a-side, b-side, b+side, a+side)
    var mesh: ArrayMesh = st.commit()
    return mesh

func arch_mesh(radius: float, thickness: float, depth: float, segments: int = 36) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(segments):
        var a0: float = PI * float(i)/float(segments)
        var a1: float = PI * float(i+1)/float(segments)
        var o0: Vector2 = Vector2(cos(a0),sin(a0))*radius
        var o1: Vector2 = Vector2(cos(a1),sin(a1))*radius
        var i0: Vector2 = Vector2(cos(a0),sin(a0))*(radius-thickness)
        var i1: Vector2 = Vector2(cos(a1),sin(a1))*(radius-thickness)
        var z0: float = -depth * 0.5
        var z1: float = depth * 0.5
        _quad(st,Vector3(o0.x,o0.y,z0),Vector3(o1.x,o1.y,z0),Vector3(o1.x,o1.y,z1),Vector3(o0.x,o0.y,z1))
        _quad(st,Vector3(i1.x,i1.y,z0),Vector3(i0.x,i0.y,z0),Vector3(i0.x,i0.y,z1),Vector3(i1.x,i1.y,z1))
        _quad(st,Vector3(i0.x,i0.y,z1),Vector3(o0.x,o0.y,z1),Vector3(o1.x,o1.y,z1),Vector3(i1.x,i1.y,z1))
    st.generate_normals()
    return st.commit()

func _append_tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int) -> void:
    var axis: Vector3 = (b-a).normalized()
    var ref: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
    var xaxis: Vector3 = axis.cross(ref).normalized()
    var yaxis: Vector3 = axis.cross(xaxis).normalized()
    for i in range(sides):
        var t0: float = TAU * float(i)/float(sides)
        var t1: float = TAU * float(i+1)/float(sides)
        var n0: Vector3 = xaxis*cos(t0)+yaxis*sin(t0)
        var n1: Vector3 = xaxis*cos(t1)+yaxis*sin(t1)
        var p00: Vector3 = a+n0*r0
        var p01: Vector3 = a+n1*r0
        var p10: Vector3 = b+n0*r1
        var p11: Vector3 = b+n1*r1
        _quad_norm(st,p00,p10,p11,p01,n0,n0,n1,n1)

func _append_blob(st: SurfaceTool, center: Vector3, scale: Vector3, seed_value: float, longitude: int, latitude: int) -> void:
    for y in range(latitude):
        var v0: float = float(y)/float(latitude)
        var v1: float = float(y+1)/float(latitude)
        var p0: float = -PI*0.5+PI*v0
        var p1: float = -PI*0.5+PI*v1
        for x in range(longitude):
            var u0: float = float(x)/float(longitude)
            var u1: float = float(x+1)/float(longitude)
            var t0: float = TAU*u0
            var t1: float = TAU*u1
            var q00: Vector3 = _blob_point(center,scale,seed_value,t0,p0)
            var q01: Vector3 = _blob_point(center,scale,seed_value,t1,p0)
            var q10: Vector3 = _blob_point(center,scale,seed_value,t0,p1)
            var q11: Vector3 = _blob_point(center,scale,seed_value,t1,p1)
            _tri(st,q00,q10,q11)
            _tri(st,q00,q11,q01)
    st.generate_normals()

func _blob_point(center: Vector3, scale: Vector3, seed_value: float, theta: float, phi: float) -> Vector3:
    var cp: float = cos(phi)
    var d: Vector3 = Vector3(cp*cos(theta),sin(phi),cp*sin(theta))
    var warp: float = 1.0 + 0.13*sin(theta*3.0+seed_value) + 0.08*sin(phi*5.0-seed_value*0.7)
    return center + d*scale*warp

func _mobius_vertex(st: SurfaceTool, r: float, u: float, v: float) -> void:
    var h: float = u*0.5
    var p: Vector3 = Vector3(
        (r+v*cos(h))*cos(u),
        v*sin(h),
        (r+v*cos(h))*sin(u)
    )
    st.set_uv(Vector2(u/TAU,(v+1.0)*0.5))
    st.add_vertex(p)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)
    st.add_vertex(a)
    st.add_vertex(c)
    st.add_vertex(d)

func _quad_norm(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
    st.set_normal(na)
    st.add_vertex(a)
    st.set_normal(nb)
    st.add_vertex(b)
    st.set_normal(nc)
    st.add_vertex(c)
    st.set_normal(na)
    st.add_vertex(a)
    st.set_normal(nc)
    st.add_vertex(c)
    st.set_normal(nd)
    st.add_vertex(d)
