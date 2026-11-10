extends RefCounted

# How light goes past a black hole, worked out once so a shader can draw it at the cost of a few
# texture reads. A ray of light near a (non-turning, Schwarzschild) black hole stays in one plane,
# and in that plane the inverse of its distance, u = 1/r, obeys
#
#     d²u/dφ² = 3u² − u            (lengths in units of the hole's mass, GM/c²)
#
# as it goes round by the angle φ. Followed backwards from the eye, every ray is one of three: it
# falls through the horizon (the shadow), it goes on out to the stars bent by some angle, or on the
# way it crosses the plane of the disc of gas round the hole: in front of the hole, behind it (seen
# over the top and under the bottom of the shadow, because the light is bent back towards you), and
# again after going round. table() follows one ray for each angle from the hole's middle out to the
# lens's edge and keeps u at every step of φ, and how far the ray was bent in the end; the shader
# (assets/shaders/black_hole.gdshader) finds where its own ray meets the disc's plane and reads
# the distance there, and reads the stars in the bent direction.

# What the physics fixes (Schwarzschild; units of M):
const HORIZON_U := 0.5                    # u at the event horizon, r = 2
const CRITICAL := 5.196152422706632       # 3√3: light passing closer than this falls in; the shadow's edge
const ISCO := 6.0                         # innermost stable circular orbit: where the disc's gas begins

# How finely the table is made (method constants):
const ROWS := 256                         # ray angles from the hole's middle to the lens's edge
const COLUMNS := 192                      # steps of the orbit angle φ along each ray, 0 .. SWEEP
const SWEEP := 3.0 * PI                   # far enough round to cross the disc's plane three times
const SUBSTEPS := 4                       # integration steps per column (velocity Verlet)

static var _tables := {}                  # Vector2(distance, reach) -> ImageTexture, made once a run

## The impact parameter (in M) of a ray leaving an eye `distance` M from the hole at `angle`
## radians from the hole's middle: 1/b² = (du/dφ)² + u² − 2u³ at the eye.
static func impact(distance: float, angle: float) -> float:
    var s := sin(angle)
    var inv := 1.0 / (distance * distance * s * s) - 2.0 / (distance * distance * distance)
    return 1.0 / sqrt(maxf(inv, 1e-12))

## The angle (radians) at which a ray from the eye just grazes the photon sphere: the shadow's edge.
static func shadow_angle(distance: float) -> float:
    # invert impact(): sin²a = 1 / (D²(1/b² + 2/D³)) with b = CRITICAL
    var inv := 1.0 / (CRITICAL * CRITICAL) + 2.0 / (distance * distance * distance)
    return asin(sqrt(1.0 / (distance * distance * inv)))

## Follows one ray from an eye `distance` M from the hole, leaving at `angle` radians from the
## hole's middle. Fills `columns` (if given, sized COLUMNS) with u at each column's φ: 0 once the
## ray has gone out to the stars, HORIZON_U once it has fallen in. Returns how far the ray was bent
## (its final direction's φ less the straight line's, π − angle), or −1 if it fell in.
static func trace(distance: float, angle: float, columns: PackedFloat32Array = PackedFloat32Array()) -> float:
    var keep := columns.size() == COLUMNS
    var u := 1.0 / distance
    var du := (cos(angle) / maxf(sin(angle), 1e-9)) / distance
    var h := SWEEP / float(COLUMNS * SUBSTEPS)
    var steps := COLUMNS * SUBSTEPS
    var bent := SWEEP - (PI - angle)          # still going round when the table ends
    var fill := -1.0
    var k := 0
    while k < steps:
        var a := 3.0 * u * u - u
        var half := du + a * h * 0.5
        var next := u + half * h
        k += 1
        if next <= 0.0:
            # out to the stars: where u reached 0 between this step and the last is the final direction
            bent = (float(k - 1) + u / (u - next)) * h - (PI - angle)
            fill = 0.0
            break
        if next >= HORIZON_U:
            bent = -1.0
            fill = HORIZON_U
            break
        du = half + (3.0 * next * next - next) * h * 0.5
        u = next
        if keep and k >= SUBSTEPS / 2 and (k - SUBSTEPS / 2) % SUBSTEPS == 0:
            columns[(k - SUBSTEPS / 2) / SUBSTEPS] = u
    if keep and fill >= 0.0:
        # every column from the step the ray ended on (not kept) to the end
        var from := ceili(float(k - SUBSTEPS / 2) / float(SUBSTEPS))
        for c in range(clampi(from, 0, COLUMNS), COLUMNS):
            columns[c] = fill
    return bent

## The lens for an eye `distance` M from the hole, out to `reach` M from it (the lens's edge): a
## COLUMNS × ROWS image, row i the ray at angle asin(reach/distance)·(i + ½)/ROWS from the hole's
## middle, column j its u at φ = SWEEP·(j + ½)/COLUMNS (red), and how far it was bent in the end
## (green, the same along the row; 0 for a ray that fell in). Made once a run for each eye distance.
static func table(distance: float, reach: float) -> ImageTexture:
    var key := Vector2(distance, reach)
    if _tables.has(key):
        return _tables[key]
    var edge := asin(clampf(reach / distance, 0.0, 1.0))
    var image := Image.create(COLUMNS, ROWS, false, Image.FORMAT_RGH)
    var columns := PackedFloat32Array()
    columns.resize(COLUMNS)
    for row in ROWS:
        var angle := edge * (float(row) + 0.5) / float(ROWS)
        columns.fill(0.0)
        var bent := trace(distance, angle, columns)
        for column in COLUMNS:
            image.set_pixel(column, row, Color(columns[column], maxf(bent, 0.0), 0.0, 1.0))
    var texture := ImageTexture.create_from_image(image)
    _tables[key] = texture
    return texture
