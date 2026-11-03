# ELI VR 0.9.10 — ELI brings things in, real rooms outdoors, checks on every system

**ELI brings real things into its rooms.** Through ELI v3 (3.0.149), ELI can fetch a model of a thing by what it is from Poly Haven's free library ("fetch a model of a pine tree"), or import a glTF file from your computer ("import the model at ~/things/lamp.glb"), and when it builds of its own accord it may bring in something it does not have. ELI VR fetches each model once over the local link, measures it, tells ELI its real size and draws it. ELI VR itself still downloads nothing.

**The outdoor rooms are made of real things.** The Reflection Chamber, the desert, the arctic snowfield and the ocean platform have scanned boulders, quiver trees, shrubs, dead timber, saplings, a bench, barrels, crates and lanterns in place of the blob rocks and box benches; 28 outdoor models join the catalogue ELI can place from.

**Speech reaches ELI.** The headset's own microphone is tried first (its name shares a word with the headset's), then the system's default; one that gives nothing but silence is passed over in the same press, and the one that is heard is remembered. The log says which was used.

**The desktop's pointer is noticed when the share did not include it.** On Wayland, GNOME's sharing dialog can share the screen with "Allow Remote Interaction" off; the helper now sees that from what was granted, asks once more, and otherwise says so rather than refusing every click.

**Checks run on every system, not just here.** The Godot checks that used to skip without Godot now run on Linux, Windows and macOS in the release workflow, and a two-minute soak builds and takes down every environment over and over, failing if anything is left behind or a room slows.

Not yet: the games ELI makes for you, the flat-window mouse on the desktop screen, and more in the Core deck, Simulation Lab and Debug Basement.
