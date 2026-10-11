class_name NetworkPolicy
extends RefCounted

enum Mode {
    OFF,
    LOCAL_ONLY,
    ONLINE
}

var mode: Mode = Mode.LOCAL_ONLY
var allow_loopback := true
var allow_remote := false

func configure(config) -> void:
    var requested := str(config.get_value("network.mode", "local_only")).to_lower()
    match requested:
        "off":
            mode = Mode.OFF
        "online":
            mode = Mode.ONLINE
        _:
            mode = Mode.LOCAL_ONLY

    allow_loopback = bool(config.get_value("network.allow_loopback", true))
    allow_remote = bool(config.get_value("network.allow_remote", false))

    # Standalone 0.2.1 deliberately refuses remote networking even if a
    # config file is manually edited. A future ELI-owned network service can
    # replace this policy when integration is intentionally enabled.
    if mode == Mode.ONLINE:
        push_warning("ELI VR standalone has no remote online services; forcing LOCAL_ONLY.")
        mode = Mode.LOCAL_ONLY
        allow_remote = false

func permits_loopback() -> bool:
    return mode != Mode.OFF and allow_loopback

func permits_remote() -> bool:
    return mode == Mode.ONLINE and allow_remote

func is_loopback_host(host: String) -> bool:
    var h := host.strip_edges().to_lower()
    return h in ["127.0.0.1", "::1", "[::1]", "localhost"]

func permits_host(host: String) -> bool:
    if is_loopback_host(host):
        return permits_loopback()
    return permits_remote()

func permits_url(url: String) -> bool:
    var u := url.strip_edges().to_lower()
    if u.begins_with("ws://127.0.0.1") or u.begins_with("ws://localhost") or u.begins_with("ws://[::1]"):
        return permits_loopback()
    if u.begins_with("wss://127.0.0.1") or u.begins_with("wss://localhost") or u.begins_with("wss://[::1]"):
        return permits_loopback()
    return permits_remote()
