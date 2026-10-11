class_name NetworkPolicy
extends RefCounted

enum Mode {
    OFF,
    LOCAL_ONLY,
    ONLINE
}

# An IPv6 host is written inside brackets, as in http://[::1]:8081
const IPV6_OPEN := "["
const IPV6_CLOSE := "]"

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
    # Judge the host itself. A prefix test would pass "127.0.0.1.example.com".
    var u := url.strip_edges().to_lower()
    var rest := u.get_slice("://", 1) if u.contains("://") else u
    var authority := rest.get_slice("/", 0)
    var host := authority
    if authority.begins_with(IPV6_OPEN):
        host = authority.get_slice(IPV6_CLOSE, 0) + IPV6_CLOSE
    else:
        host = authority.get_slice(":", 0)
    return permits_host(host)
