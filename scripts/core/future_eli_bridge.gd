class_name FutureEliBridge
extends Node

# Reserved integration seam for ELI v3.
#
# Standalone 0.2.1 permits only loopback IPC and has NO remote ELI service,
# account, sign-in, telemetry or cloud requirement.
#
# Expected future local messages:
# {
#   "type": "eli_world_state",
#   "room": "workshop",
#   "objects": [...],
#   "awareness": {...},
#   "widgets": {...}
# }

signal world_state_received(state: Dictionary)
signal connection_state_changed(connected: bool)

var enabled := false
var endpoint := ""
var _socket: WebSocketPeer
var _policy

func configure(config, policy) -> void:
    _policy = policy
    enabled = bool(config.get_value("eli_bridge.enabled", false))
    endpoint = str(config.get_value("eli_bridge.endpoint", "ws://127.0.0.1:47832"))

    if not enabled:
        return

    if _policy == null or not _policy.permits_url(endpoint):
        push_warning("ELI bridge blocked by ELI VR NetworkPolicy: %s" % endpoint)
        enabled = false
        return

    connect_bridge()

func connect_bridge() -> void:
    if not enabled or endpoint.is_empty() or _policy == null:
        return
    if not _policy.permits_url(endpoint):
        push_warning("ELI bridge connection refused by NetworkPolicy.")
        return

    _socket = WebSocketPeer.new()
    var err := _socket.connect_to_url(endpoint)
    if err != OK:
        push_warning("Local ELI bridge connection request failed: %s" % err)

func _process(_delta: float) -> void:
    if _socket == null:
        return

    _socket.poll()
    var state := _socket.get_ready_state()
    connection_state_changed.emit(state == WebSocketPeer.STATE_OPEN)

    while _socket.get_available_packet_count() > 0:
        var text := _socket.get_packet().get_string_from_utf8()
        var msg = JSON.parse_string(text)
        if typeof(msg) == TYPE_DICTIONARY and msg.get("type", "") == "eli_world_state":
            world_state_received.emit(msg)
