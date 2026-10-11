# ELI VR 0.6.0 — Cinematic Asset Tier

This release stops treating primitive meshes as the visual destination.

## Visual content

Natural environments now use an offline asset/material library generated into
this project: rock, stone, bark, foliage, sand, ice, seabed, metal, coral and
memory-stone albedo/normal/roughness maps. Runtime procedural meshes use those
materials instead of flat colours.

The forest uses branching tree meshes with real trunk/branch topology and
irregular foliage volumes. Underwater uses branching coral. Arctic uses jagged
procedural glacier formations. Desert uses rock arches. Mountain receives an
observatory assembly and larger terrain. Industrial worlds use curved trusses,
arches and machinery rather than random floating blocks.

Digital Matrix and Anomaly deliberately remain abstract, but are now built from
Möbius strips and Lorenz-attractor ribbons rather than boxes/cones.

## Deep Space

The old structured sphere distribution is removed. Stars are sampled
stochastically with an isotropic component plus a noisy galactic-plane mixture.
Void masks break up uniform wallpaper density.

The far-field now includes generated high-resolution spiral, edge-on and violet
galaxy sprites, layered nebula sprites, a globular cluster and additional
reachable/distant 3D planets. Stars use soft emissive billboards instead of
low-poly sphere dots.

## Linux Wayland desktop

The empty desktop screen was not a rendering bug: no capture provider was
feeding frames. The CV1 launcher now prefers a new local XDG Desktop Portal +
PipeWire adapter on Wayland. It asks the compositor for a ScreenCast session,
feeds the authorized PipeWire stream through GStreamer and sends raw RGBA frames
over 127.0.0.1 to Godot.

Install the Ubuntu adapter dependencies once with:

```bash
./tools/install-linux-wayland-capture-deps.sh
```

Then launch normally. A desktop-share selector may appear when the portal needs
permission. A persisted restore token is stored locally when the portal
supports it.

The OpenXR composition-layer desktop path is now opt-in. The portable 3D mesh is
the default, avoiding the CV1 composition-layer lifecycle/acquire errors seen in
0.5.0.

## Portability

The portal bridge is only the Linux Wayland capture adapter. Windows, macOS,
Android and other capture providers remain separate native adapters; the Godot
desktop surface and frame protocol do not depend on Linux.
