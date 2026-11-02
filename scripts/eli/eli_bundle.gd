class_name EliBundle
extends RefCounted

# ELI VR on ELI v3's list of bundles, kept there by ELI VR itself. Registering was a command
# typed by hand (`--register-eli`, which also needed Python), so it was never on the list and
# ELI v3 had no way in. Written at each start while ELI v3 is installed on this machine, so a
# moved or updated copy is the one ELI v3 opens. The same record `eli-vr bundle register` writes.

const ID := "vr"
const CONTRACT := 1

## ELI v3's own folder on this machine, where it looks for registered bundles.
static func v3_data_dir() -> String:
    match OS.get_name():
        "Windows":
            var local := OS.get_environment("LOCALAPPDATA")
            if local.is_empty():
                local = OS.get_environment("USERPROFILE").path_join("AppData/Local")
            return local.path_join("ELI_v3")
        "macOS":
            return OS.get_environment("HOME").path_join("Library/Application Support/ELI_v3")
        _:
            var data := OS.get_environment("XDG_DATA_HOME")
            if data.is_empty():
                data = OS.get_environment("HOME").path_join(".local/share")
            return data.path_join("ELI_v3")

static func eli_v3_installed() -> bool:
    return DirAccess.dir_exists_absolute(v3_data_dir())

## What a person starts to open this copy: the launcher says (the AppImage, or launch/eli-vr.sh);
## an exported build on its own is its executable. A run from the editor is nothing to list.
static func own_command() -> String:
    var named := OS.get_environment("ELI_VR_COMMAND")
    if not named.is_empty():
        return named
    return OS.get_executable_path() if OS.has_feature("template") else ""

static func record(version: String, command: String) -> Dictionary:
    return {
        "contract": CONTRACT,
        "id": ID,
        "title": "ELI VR",
        "summary": "ELI's rooms as places to stand in, in a headset or on a monitor, with ELI present.",
        "version": version,
        "edition": ID,
        "icon": "",
        "launch": "",
        "needs": ["server"],
        "requires_core": ">=3.0.131",
        "command": [command],
    }

## The registration file written or already up to date, "" when there is nothing to register:
## ELI v3 is not installed here, or this is not a copy a person starts.
static func register_with_v3(version: String) -> String:
    if not eli_v3_installed():
        return ""
    var command := own_command()
    if command.is_empty():
        return ""
    var folder := v3_data_dir().path_join("bundles")
    var path := folder.path_join("%s.json" % ID)
    var text := JSON.stringify(record(version, command), "  ") + "\n"
    if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text:
        return path
    if DirAccess.make_dir_recursive_absolute(folder) != OK:
        push_warning("ELI VR could not make ELI v3's bundles folder: %s" % folder)
        return ""
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        push_warning("ELI VR could not register with ELI v3 at %s: %s" % [path, FileAccess.get_open_error()])
        return ""
    f.store_string(text)
    return path
