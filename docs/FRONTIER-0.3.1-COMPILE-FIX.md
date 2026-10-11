# ELI VR 0.3.1 Frontier compile fix

Godot 4.7.2 is configured to treat several GDScript inference warnings as
errors. Frontier 0.3.0 still had a handful of expressions where the compiler
saw `Variant` rather than a concrete type.

0.3.1 makes the new Frontier XR/world code explicit:

- locomotion environment ID, sticks, movement vectors and booleans;
- hand trigger/grip/curl values;
- world-manipulation vectors, rays and hit dictionaries;
- pointer pose/ray/hit types;
- terrain interpolation values.

It also fixes the export-preset warnings. Empty `[preset.N.options]` sections
are not materialized by Godot's ConfigFile parser, so each preset now contains
real export options rather than an empty section.

No networking behavior changed.
