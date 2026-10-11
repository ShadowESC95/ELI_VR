# ELI VR 0.3.0 Frontier

This is the first pass that treats ELI VR as a spatial product rather than a
collection of prototype rooms.

## Interaction

- Procedural graphite hands replace the orange/blue debug controller blocks.
- Fingers curl from Touch trigger/grip values.
- Pointer rays originate at the index fingertip while orientation comes from
  the OpenXR aim pose.
- Left Touch menu button toggles a wrist-mounted shortcut deck.
- Trigger selects spatial UI.
- B/Y toggles the large spatial console.
- Grip grabs manipulable world objects.
- While gripping an object, that controller's thumbstick changes grab distance
  (Y) and rotates the object (X).
- Left stick moves.
- Left stick click boosts movement.
- Right stick snap-turns.
- In space, underwater, Matrix and Anomaly environments, movement switches to
  free-flight automatically and right-stick Y moves vertically.

## Deep Space

The old deep-space panorama contained a planet baked into the image. That made
it impossible to approach or manipulate the planet as a world object.

Frontier removes the baked panorama and replaces it with:

- a full 4π procedural star/nebula shell, including below the user;
- three actual 3D planets;
- atmosphere shells;
- a ringed world;
- a 3D asteroid field;
- free-flight locomotion;
- grip-based planet manipulation.

You can now look at a planet and push the left stick forward to fly toward it.
You can also point at it and hold grip to pull/rotate it.

## Flagship environment upgrades

The following environments no longer rely on the old baked sky image:

- Mountain Observatory: generated height-field mountain terrain.
- Forest Sanctuary: generated terrain + instanced forest.
- Ocean Platform: much larger ocean horizon + architectural platform.
- Digital Matrix: complete data/grid dome + floating data structures.
- Deep Space: complete procedural space shell + movable planets.
- Arctic Aurora: generated ice terrain + animated aurora dome.
- Desert Observatory: generated dune terrain + full gradient sky.
- Underwater Lab: generated sea-floor + full underwater shell + free flight.

## Performance

The environments remain procedural and quality-scaled. This is intentional:
ELI VR must target 90 Hz on the Rift CV1/RTX 2060 SUPER reference machine while
remaining portable to other OpenXR systems. MultiMesh is used for repeated
forest/asteroid geometry and all new sky shells use stereo-safe shaders.

## Offline policy

No cloud service, account, telemetry, analytics, remote API or runtime asset
download was added. These systems run entirely on the user's machine.
