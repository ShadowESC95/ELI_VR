# ELI VR 0.3.4 — calibration widget parse fix

0.3.3 removed the explicit `XRControllerCalibration` type from the widget, but
that left the manager as an untyped Variant. With this project configured to
treat GDScript warnings as errors, accessing custom signals/methods/properties
through that Variant can itself make `calibration_widget.gd` fail to compile.

0.3.4 uses a built-in `Node` type and Godot's generic Object API instead:

- `connect(signal_name, Callable(...))` for custom signals;
- `call(method_name, ...)` for calibration methods;
- `get(property_name)` for the displayed yaw value;
- explicit Variant-to-Vector3 checking for the status display.

This removes both failure modes: global-class registration order and unsafe
Variant access. Calibration behavior is otherwise unchanged.
