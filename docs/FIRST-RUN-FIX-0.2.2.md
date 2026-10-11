# ELI VR 0.2.2 first-run fix

This repair removes ELI VR's dependency on Godot's generated `.godot/global_script_class_cache.cfg`.

The source-only 0.2.1 package excluded `.godot/`, but several scripts referred to custom `class_name` types while `app.gd` was being parsed. On a clean first run Godot can therefore report errors such as:

- `Could not find type "AppConfig" in the current scope`
- `Identifier "SpatialConsole" not declared in the current scope`

0.2.2 uses explicit `preload()` dependencies and path-based inheritance where needed. The generated Godot cache is no longer required for the application scripts to parse.

For a flat-mode test always use:

```bash
./launch/run-linux.sh flat
```

Do not use a bare `godot` command for that test, because `project.godot` has OpenXR support enabled and Godot may try the machine's currently active OpenXR runtime.
