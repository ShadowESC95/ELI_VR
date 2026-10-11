# ELI VR 0.5.0 — Cinematic Worlds

This release changes the visual-development rule: primitive geometry is no
longer considered final art. Boxes/cylinders may still exist as structural
proxies, but flagship visual systems are now built from reusable procedural
meshes, instancing and mathematical distributions intended to be replaced or
augmented by authored asset packs later without changing interaction logic.

## Deep Space

The old background-star implementation used a UV-cell hash and could reveal a
structured layout. 0.5.0 moves the primary stellar field into real 3D:

- two golden-angle/Fibonacci-like stellar shells with radial jitter;
- a tilted high-density galactic band;
- per-star temperature variation and rare bright stars;
- three actual logarithmic-spiral galaxy point clouds;
- a centrally concentrated globular cluster;
- three layered additive nebula volumes;
- six reachable 3D planets plus asteroids from the previous generation.

This provides parallax while flying. Galaxies are not painted onto a panorama:
they are spatial point-cloud structures made from thousands of instanced stars.

## Mathematical world geometry

A new procedural-geometry module generates torus/arc meshes analytically and
noise-deformed rock meshes. Curved superstructures have been introduced into
Core Station, Memory Cathedral, Workshop, Fabrication, Debug and Anomaly. Rock
fields now dress Mountain, Forest, Ocean, Arctic, Desert and Underwater.

The aim is to remove the obvious repeated-cube language before the authored
PBR/photogrammetry asset layer is introduced.

## Movable XR workspace

The three main startup panels are now independent grabbable Area3D surfaces.
Use GRIP while pointing at the panel itself:

- controller motion moves the panel;
- stick Y changes distance;
- stick X rotates it.

Trigger rays only query UI layer 2, while grip manipulation queries layer 4.
This means the invisible grab surface behind a panel cannot block its buttons.

The desktop screen uses the same manipulation layer and can also be moved.
It now spawns above the startup panels instead of directly behind them.

## Desktop composition lifecycle

The OpenXR composition layer is now inserted into the scene tree before its
viewport/quad properties are assigned. A standard 3D mesh is always present as
fallback. This addresses the Godot `!is_inside_tree()` error seen when opening
the desktop surface.

Live desktop pixels remain a platform-adapter concern. On Linux Wayland the
intended production provider is XDG Desktop Portal ScreenCast + PipeWire; the
unsafe repeated-screenshot path is still not enabled automatically.

## Colour names

The startup visual selector now uses literal colour names:

- Blue
- Black
- Purple
- Green
- Orange
- Cyan
- Ice Blue
- White

The Black palette is now actually near-black/graphite rather than an orange/gold
palette carrying an "Obsidian" label.

## Performance model

The expensive additions use MultiMesh instancing. Stellar/galaxy counts scale
with `graphics.world_detail_scale`, so lower hardware profiles reduce density
without changing the world design or replacing it with a separate simplified
scene.
