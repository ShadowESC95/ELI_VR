# ELI VR 0.2.5 — controller and XR stability pass

The CV1 log proved the hardware/runtime side is healthy enough to continue:
Monado selected the Rift CV1, detected both Touch controllers, opened both Rift
sensor cameras, and both controller devices eventually came online and tracked.

The application-side issues fixed here are:

- replace Godot's broad default OpenXR action map with a small ELI VR map;
- bind the tested Oculus Touch profile plus the OpenXR simple fallback only;
- remove unsupported palm/grip-surface and untested extension controller profiles;
- stop polling unsupported display-refresh properties every frame;
- stop changing `render_target_size_multiplier` after OpenXR initialization;
- remove ordinary CanvasLayer HUD/dock rendering from the stereo XR viewport;
- add procedural tracked-controller markers, aim rays and an in-headset 3D
  controller diagnostic readout;
- add haptic feedback on trigger diagnostics and successful pointer activation;
- make B/Y toggle the spatial console once per press.

For the Rift CV1 development machine, use:

```bash
./launch/run-linux-cv1-headset-test.sh
```

Generic `./launch/run-linux.sh xr` intentionally follows the system default
OpenXR runtime and can therefore select SteamVR on a machine where SteamVR is
the active runtime.


> Superseded note: 0.2.6 corrects the XRController3D tracker names from OpenXR paths to Godot's reserved `left_hand` / `right_hand` identifiers.
