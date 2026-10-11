# ELI VR 0.3.3 — calibration loader fix

0.3.2 added the controller-calibration subsystem, but a clean Godot import could
load `XRCalibrationWidget` before the `XRControllerCalibration` global class had
been registered in the generated class cache.

The widget declared:

```gdscript
var manager: XRControllerCalibration
func setup(p_manager: XRControllerCalibration, ...)
```

That unnecessary compile-time dependency could make the widget resource fail to
resolve during the first project scan, which then made `app.gd` fail at its
preload line.

0.3.3 removes that class-cache dependency. The manager is still the same
calibration node at runtime; the widget simply receives it dynamically.

The calibration reset signal was also renamed to `calibration_reset` for an
unambiguous subsystem-specific signal name.

No XR behavior, controller offsets, network policy or world content changed.
