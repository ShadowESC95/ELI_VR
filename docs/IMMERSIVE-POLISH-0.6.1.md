# ELI VR 0.6.1 — Immersive Polish

This release fixes three issues visible in the 0.6.0 headset capture.

## 1. Cinematic materials were accidentally blank

The first asset-tier build packaged normal/roughness maps but several albedo
maps were completely white. That meant geometry remained visually close to the
old flat prototype even though the asset system existed.

0.6.1 regenerates a real offline PBR material library with tileable spectral
noise and material-specific structure for rock, stone, bark, foliage, sand,
ice, seabed, coral, metal, dark metal and memory stone.

Normal maps remain packaged but are not bound to runtime-generated meshes until
every generator carries tangent space. This removes the Forward Mobile tangent
warnings rather than asking the renderer to use invalid tangent-dependent
shading.

## 2. Deep Space no longer uses star wallpaper or random black asteroid dots

Deep Space now uses only spatial stochastic star volumes for visible stars.
The UV-cell star component on the sky sphere is disabled. The far field has
more galaxies, two globular clusters and layered 3D nebula billboards.

Random low-poly asteroids around the player are removed. Textured irregular
asteroids now form purposeful belts around distant planetary systems, safely
away from the spawn area. Three emissive distant stars and another distant
planet increase depth cues.

Colour palette selections no longer recolour the world sky. BLUE/BLACK/PURPLE
etc. are UI/accent palettes; each environment keeps its authored atmosphere.

## 3. Desktop workspace and Wayland capture

The desktop screen migrates to a smaller, higher, farther default position.
When it opens, Rooms/Environments/Visual panels automatically dock below it so
the desktop is not hidden behind the UI. All four surfaces remain grabbable.
RESET UI restores the workspace.

The Linux Wayland adapter now binds its loopback frame server before portal
negotiation, kills stale previous portal bridges, reports the ScreenCast portal
version, and the launcher verifies that 127.0.0.1:47831 is actually listening.
If live capture still fails, run:

```bash
./tools/check-linux-wayland-capture.sh
```

and the exact portal/GStreamer failure is shown from the local bridge log.

Developer controller-pose diagnostics are no longer rendered in-headset unless
`ELI_VR_XR_DIAGNOSTICS=1` is explicitly set. Terminal diagnostics remain.
