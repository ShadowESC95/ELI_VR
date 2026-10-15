extends RefCounted

## Whether this copy of ELI VR may run: a key of its own, or an ELI v3 key that includes it, from
## the folder every ELI product shares. Godot can't check a key's signature, so the desktop helper
## shipped beside the app does, and anything it can't answer counts as unlicensed.

const HELPER := "native/desktop_bridge/target/release/eli-vr-desktop-bridge"
const BUY := "ko-fi.com/shadowesc95 · jaybridgeman0095@gmail.com"
const _YES := ["1", "true", "yes", "on"]

## An exported copy needs a licence; running from the source in Godot doesn't, unless
## ELI_VR_REQUIRE_LICENCE says so.
static func required() -> bool:
    if OS.get_environment("ELI_VR_REQUIRE_LICENCE").strip_edges().to_lower() in _YES:
        return true
    return OS.has_feature("template")

static func release() -> String:
    return str(ProjectSettings.get_setting("application/config/version", ""))

static func helper_path() -> String:
    var name := HELPER + (".exe" if OS.get_name() == "Windows" else "")
    # beside the app, or a few folders up from inside a macOS .app or an AppImage
    var dir := OS.get_executable_path().get_base_dir()
    for _i in 5:
        if FileAccess.file_exists(dir.path_join(name)):
            return dir.path_join(name)
        dir = dir.get_base_dir()
    if not OS.has_feature("template"):
        var checkout := ProjectSettings.globalize_path("res://").path_join(name)
        if FileAccess.file_exists(checkout):
            return checkout
    return ""

static func granted(got: Dictionary) -> bool:
    return int(got.get("code", -1)) == 0 and bool(got.get("licensed", false))

static func status() -> Dictionary:
    return _ask(["licence", "--for-release", release()])

## Keep a key and check it. An ELI v3 key without ELI VR is still kept, for ELI v3.
static func activate(key: String) -> Dictionary:
    return _ask(["licence", "--for-release", release(), "activate", "--", key.strip_edges()])

static func _ask(args: PackedStringArray) -> Dictionary:
    var helper := helper_path()
    if helper.is_empty():
        return {"licensed": false, "code": -1, "reason": "this copy of ELI VR is missing its licence check (%s)" % HELPER}
    var out: Array = []
    var code := OS.execute(helper, args, out)
    var shown = JSON.parse_string(str(out[0]) if not out.is_empty() else "")
    if typeof(shown) != TYPE_DICTIONARY:
        return {"licensed": false, "code": code, "reason": "the licence check gave no answer"}
    shown["code"] = code
    if not shown.has("reason"):
        shown["reason"] = str(shown.get("error", ""))
    return shown
