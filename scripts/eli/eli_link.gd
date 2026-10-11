class_name EliLink
extends Node

# The link to a local ELI v3. Off unless asked for, and loopback only.
# ELI's world state arrives over a WebSocket on v3's own server; speech and
# chat use the same server's HTTP routes. Nothing here starts or installs ELI:
# if he is not running, the link keeps quiet and tries again.

signal world_state_received(state: Dictionary)
signal link_changed(connected: bool)

const DEFAULT_ENDPOINT := "http://127.0.0.1:8081"
const OLD_PLACEHOLDER := "ws://127.0.0.1:47832"
const RETRY_SECONDS := 5.0

var enabled := false
var connected := false
var base_url := DEFAULT_ENDPOINT

var _token := ""
var _session := ""
var _socket: WebSocketPeer
var _retry := 0.0

func configure(config, policy) -> void:
    enabled = bool(config.get_value("eli_bridge.enabled", false))
    base_url = str(config.get_value("eli_bridge.endpoint", DEFAULT_ENDPOINT)).strip_edges().trim_suffix("/")
    # Settings saved before the link existed still carry the reserved port.
    if base_url.is_empty() or base_url == OLD_PLACEHOLDER:
        base_url = DEFAULT_ENDPOINT
    base_url = base_url.replace("ws://", "http://").replace("wss://", "https://")
    # ELI's port can be moved off 8081. When ELI starts us it says which one.
    var port := OS.get_environment("ELI_API_PORT")
    if base_url == DEFAULT_ENDPOINT and port.is_valid_int():
        base_url = "http://127.0.0.1:%s" % port

    var token_env := str(config.get_value("eli_bridge.token_env", "ELI_VR_TOKEN"))
    _token = OS.get_environment(token_env) if not token_env.is_empty() else ""
    _session = "eli-vr-%d" % int(Time.get_unix_time_from_system())

    if enabled and (policy == null or not policy.permits_url(base_url)):
        push_warning("ELI link blocked by the network policy: %s" % base_url)
        enabled = false

func _process(delta: float) -> void:
    if not enabled:
        return
    if _socket == null:
        _retry -= delta
        if _retry <= 0.0:
            _open()
        return

    _socket.poll()
    match _socket.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            _set_connected(true)
            while _socket.get_available_packet_count() > 0:
                var msg = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
                if typeof(msg) == TYPE_DICTIONARY and msg.get("type", "") == "eli_world_state":
                    world_state_received.emit(msg)
        WebSocketPeer.STATE_CLOSED:
            _socket = null
            _retry = RETRY_SECONDS
            _set_connected(false)

func _open() -> void:
    _retry = RETRY_SECONDS
    _socket = WebSocketPeer.new()
    # ELI's world can carry many objects; the default 64 KB is not enough.
    _socket.inbound_buffer_size = 1 << 20
    if not _token.is_empty():
        _socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + _token])
    var url := base_url.replace("http://", "ws://").replace("https://", "wss://") + "/v1/world/ws"
    if _socket.connect_to_url(url) != OK:
        _socket = null

func _set_connected(value: bool) -> void:
    if value == connected:
        return
    connected = value
    print("ELI link: %s" % ("connected" if connected else "lost"))
    link_changed.emit(connected)

func send_event(event_type: String, summary: String, payload: Dictionary = {}) -> void:
    if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    _socket.send_text(JSON.stringify({
        "type": "vr_event",
        "event_type": event_type,
        "summary": summary,
        "payload": payload,
    }))

# --- speech and chat --------------------------------------------------------

func transcribe(wav: PackedByteArray) -> String:
    var r: Dictionary = await _post("/v1/voice/stt?ext=wav", wav, "audio/wav", 60.0)
    if int(r["code"]) != 200:
        return ""
    var data = JSON.parse_string((r["body"] as PackedByteArray).get_string_from_utf8())
    if typeof(data) != TYPE_DICTIONARY or not bool(data.get("ok", false)):
        return ""
    return str(data.get("text", "")).strip_edges()

func chat(message: String) -> String:
    var body := JSON.stringify({"message": message, "user_id": "eli_vr", "session_id": _session})
    # A local model can take a while on a long answer.
    var r: Dictionary = await _post("/v1/chat", body.to_utf8_buffer(), "application/json", 300.0)
    if int(r["code"]) != 200:
        return ""
    var data = JSON.parse_string((r["body"] as PackedByteArray).get_string_from_utf8())
    if typeof(data) != TYPE_DICTIONARY:
        return ""
    return str(data.get("response", "")).strip_edges()

func speak(text: String) -> AudioStreamWAV:
    var body := JSON.stringify({"text": text})
    var r: Dictionary = await _post("/v1/voice/tts", body.to_utf8_buffer(), "application/json", 120.0)
    if int(r["code"]) != 200 or (r["body"] as PackedByteArray).is_empty():
        return null
    return AudioStreamWAV.load_from_buffer(r["body"])

func _post(path: String, body: PackedByteArray, content_type: String, timeout: float) -> Dictionary:
    var failed := {"code": 0, "body": PackedByteArray()}
    if not enabled:
        return failed
    var http := HTTPRequest.new()
    http.timeout = timeout
    add_child(http)
    var headers := PackedStringArray(["Content-Type: " + content_type])
    if not _token.is_empty():
        headers.append("Authorization: Bearer " + _token)
    if http.request_raw(base_url + path, headers, HTTPClient.METHOD_POST, body) != OK:
        http.queue_free()
        return failed
    var result: Array = await http.request_completed
    http.queue_free()
    if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
        return failed
    return {"code": int(result[1]), "body": result[3]}
