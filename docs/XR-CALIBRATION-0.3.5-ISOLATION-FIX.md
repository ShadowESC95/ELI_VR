# ELI VR 0.3.5 — calibration widget compile isolation

Godot was only reporting that `app.gd` could not preload `calibration_widget.gd`,
which masked the nested widget compile failure.

The calibration widget now uses built-in Godot classes only. It has no
`Interactable3D` preload, no custom-class type dependency, and no custom-script
`new()` inference.

It is deliberately pointer-independent:

- both grips + both triggers for one second: guided calibration;
- left stick: X/Y positional trim;
- right stick Y: forward/back trim;
- right stick X: yaw trim;
- both thumbstick clicks: reset;
- F6: toggle panel;
- F7: immediate guided calibration.

Locomotion is suspended while the calibration panel is open so manual trim does
not simultaneously move the player.
