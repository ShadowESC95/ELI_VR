class_name EliLink
extends Node

# The link to a local ELI v3, loopback only. On by itself when ELI v3 is installed here or
# started this copy ("auto"); `--eli-link=off` or a saved false turns it off. Off unless asked
# for, a double-clicked ELI VR had ELI dormant in every room while ELI v3 was running.
# ELI's world state arrives over a WebSocket on v3's own server; speech,
# conversation and building use the same server's HTTP routes. Nothing here
# starts or installs ELI: if it is not running, the link keeps quiet and
# tries again.
#
# Versions are agreed, not assumed. On connecting, this says which versions
# of the world protocol it speaks and what it would like; ELI answers with
# the one both have. An ELI v3 from before that simply never answers, and is
# then spoken to in version 1: presence and talking, no building.

signal world_state_received(state: Dictionary)
signal link_changed(connected: bool)
# The link is whole: ELI's world is arriving and the versions are agreed (in whichever order the two
# came). Once a connection: this is when the session is told to ELI, and told once.
signal agreed

const DEFAULT_ENDPOINT := "http://127.0.0.1:8081"
const LOOPBACK := "http://127.0.0.1"
const OLD_PLACEHOLDER := "ws://127.0.0.1:47832"
const RETRY_SECONDS := 5.0
const INBOUND_BYTES := 1 << 20          # the most one message from ELI may take
const SURFACE := "eli_vr"
const PROTOCOL_VERSIONS := [1, 2]
const WANTS_NOTE := "models: the real things ELI brought in of its own, fetched and drawn"
const WANTS := ["world-state", "room-events", "scene", "say", "building", "undo", "own-room", "mind", "props", "pictures",
                "games", "thoughts", "books", "evidence", "kept-records"]
const WELCOME_SECONDS := 4.0
const CLOSE_UNAUTHORISED := 4401
const CLOSE_INCOMPATIBLE := 4406

var enabled := false
var connected := false
var base_url := DEFAULT_ENDPOINT
var protocol := 0                       # 0 until agreed, then 1 or 2
var capabilities: Array = []
var server := ""
var problem: EliResult                  # why the link is not whole, or null

var _token := ""
var _session := ""
var _socket: WebSocketPeer
var _retry := 0.0
var _was_open := false
var _welcome_wait := 0.0
var _agreed_told := false               # `agreed` was emitted for this connection
# Messages being read on worker threads, oldest first: [task, {"bytes", "msg"}]. ELI's world can be
# a megabyte of records and books, and reading that much JSON takes several frames: done here it
# would stop the headset each time ELI's world sends word. They are taken in the order they came.
var _reading: Array = []
# The world message before the one now shown, held until the next comes: by then nothing shows it
# any more, and it is let go of on a worker thread (taking a megabyte of records apart is most of
# a frame). The tasks doing that, until they are done.
var _shown = null
var _letting_go: Array = []
# The records of the last world message, by id ("kept-records"): ELI sends a record whole when it is
# new or changed, and by its id alone while it is the same; the one held here is then the record.
# ELI's books and what it holds about you are most of a message, and every change anywhere used to
# bring all of them again.
var _held: Dictionary = {}

func configure(config, policy) -> void:
    var asked = config.get_value("eli_bridge.enabled", "auto")
    if typeof(asked) == TYPE_STRING and asked == "auto":
        enabled = EliBundle.eli_v3_installed() or OS.get_environment("ELI_API_PORT").is_valid_int()
    else:
        enabled = bool(asked)
    base_url = str(config.get_value("eli_bridge.endpoint", DEFAULT_ENDPOINT)).strip_edges().trim_suffix("/")
    # Settings saved before the link existed still carry the reserved port.
    if base_url.is_empty() or base_url == OLD_PLACEHOLDER:
        base_url = DEFAULT_ENDPOINT
    base_url = base_url.replace("ws://", "http://").replace("wss://", "https://")
    # ELI's port can be moved off 8081. When ELI starts us it says which one; otherwise a
    # running ELI v3 says where it serves (another program, ELI v2 among them, may hold 8081).
    var port := OS.get_environment("ELI_API_PORT")
    if not port.is_valid_int():
        port = str(EliBundle.v3_serving_port())
    if base_url == DEFAULT_ENDPOINT and port.is_valid_int() and int(port) > 0:
        base_url = "%s:%s" % [LOOPBACK, port]

    var token_env := str(config.get_value("eli_bridge.token_env", "ELI_VR_TOKEN"))
    _token = OS.get_environment(token_env) if not token_env.is_empty() else ""
    _session = "eli-vr-%d" % int(Time.get_unix_time_from_system())

    if enabled and (policy == null or not policy.permits_url(base_url)):
        push_warning("ELI link blocked by the network policy: %s" % base_url)
        enabled = false

func can(capability: String) -> bool:
    return connected and capabilities.has(capability)

func session_id() -> String:
    return _session

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
            if not _was_open:
                _was_open = true
                _welcome_wait = WELCOME_SECONDS
                # max_message: the most one message may take here, so ELI sends no more than this takes
                _socket.send_text(JSON.stringify({
                    "type": "hello", "surface": SURFACE, "session": _session,
                    "protocol_versions": PROTOCOL_VERSIONS, "capabilities": WANTS,
                    "max_message": _socket.inbound_buffer_size,
                }))
            while _socket.get_available_packet_count() > 0:
                var packet := _socket.get_packet()
                if packet.is_empty():
                    continue                # not a message: nothing to parse
                _read(packet)
            _take_read()
            if protocol == 0 and _welcome_wait > 0.0:
                _welcome_wait -= delta
                if _welcome_wait <= 0.0 and connected:
                    # States arrive but no welcome: an ELI v3 from before versions were agreed.
                    _agree(1, ["world-state", "room-events"], "")
        WebSocketPeer.STATE_CLOSED:
            var code := _socket.get_close_code()
            _socket = null
            _retry = RETRY_SECONDS
            if code == CLOSE_UNAUTHORISED:
                problem = EliResult.bad("unauthorised", "", 401)
            elif code == CLOSE_INCOMPATIBLE:
                _retry = 60.0           # nothing will change in five seconds
            elif not _was_open:
                problem = EliResult.bad("unreachable", "", 0, true)
            _was_open = false
            protocol = 0
            capabilities = []
            _agreed_told = false
            _held = {}                  # a new link is sent every record whole
            _drop_reading()             # what was still being read is of a link that is gone
            _set_connected(false)

# A message as it came off the socket, handed to a worker thread to be read.
func _read(packet: PackedByteArray) -> void:
    var held := {"bytes": packet, "msg": null}
    var task := WorkerThreadPool.add_task(func(): held["msg"] = JSON.parse_string((held["bytes"] as PackedByteArray).get_string_from_utf8()))
    _reading.append([task, held])

# The messages that have been read, in the order they came: one still being read holds back those after it.
func _take_read() -> void:
    while not _reading.is_empty() and WorkerThreadPool.is_task_completed(_reading[0][0]):
        var read: Array = _reading.pop_front()
        WorkerThreadPool.wait_for_task_completion(read[0])
        var msg = (read[1] as Dictionary)["msg"]
        if typeof(msg) == TYPE_DICTIONARY:
            _take(msg)

func _drop_reading() -> void:
    for read in _reading:
        WorkerThreadPool.wait_for_task_completion(read[0])
    _reading.clear()

# Lets go of a world message nothing shows any more, on a worker thread: this was the last hold
# on it but for the records still standing in the room, which keep their own.
func _let_go(last: Array) -> void:
    for task in _letting_go.duplicate():
        if WorkerThreadPool.is_task_completed(task):
            WorkerThreadPool.wait_for_task_completion(task)
            _letting_go.erase(task)
    if typeof(last[0]) == TYPE_DICTIONARY:
        _letting_go.append(WorkerThreadPool.add_task(func(): last[0] = null))

func _take(msg: Dictionary) -> void:
    match str(msg.get("type", "")):
        "welcome":
            _agree(int(msg.get("version", 1)), msg.get("capabilities", []), str(msg.get("server", "")))
        "incompatible":
            problem = EliResult.bad("incompatible", str(msg.get("reason", "")))
            print("ELI link: %s" % problem.sentence())
        "eli_world_state":
            _set_connected(true)
            if not _whole(msg):
                return
            world_state_received.emit(msg)
            var last := [_shown]        # the only hold on the one before, once _shown is the new one
            _shown = msg
            _let_go(last)

# A world message made whole: each record that came by its id alone ({"id", "kept": true}) is the one
# held from the message before. False when one came by an id nothing is held for (the two ends no
# longer agree on what was sent): the message is not shown and the link is opened anew, which brings
# every record whole.
func _whole(msg: Dictionary) -> bool:
    var records = msg.get("objects")
    if typeof(records) != TYPE_ARRAY:
        _held = {}
        return true
    var now := {}
    var out := []
    for record in records:
        if typeof(record) != TYPE_DICTIONARY:
            out.append(record)
            continue
        var ident := str(record.get("id", ""))
        if record.get("kept") == true:
            if not _held.has(ident):
                push_warning("ELI link: the record %s came by its id and is not held; opening the link anew" % ident)
                _held = {}
                if _socket != null:
                    _socket.close()
                return false
            record = _held[ident]
        if not ident.is_empty() and not now.has(ident):       # an id twice: ELI keeps it by the first
            now[ident] = record
        out.append(record)
    msg["objects"] = out
    _held = now
    return true

func _agree(version: int, has: Array, from: String) -> void:
    protocol = version
    capabilities = has
    server = from
    problem = null
    if version < 2:
        problem = EliResult.bad("unsupported", "This ELI v3 is older: presence and talking only")
    print("ELI link: world protocol %d%s" % [version, "" if from.is_empty() else " (%s)" % from])
    _tell_agreed()
    if can("props"):
        report_body.call_deferred()

func _tell_agreed() -> void:
    if connected and protocol != 0 and not _agreed_told:
        _agreed_told = true
        agreed.emit()

# Bytes ELI v3 serves: a picture ELI took or looked at for you ("pictures"), a file of a model
# ELI brought in ("models").
func fetch(path: String, capability: String = "pictures") -> EliResult:
    if not can(capability):
        return EliResult.bad("unsupported")
    return await _request(HTTPClient.METHOD_GET, path, PackedByteArray(), "application/octet-stream", 60.0)

# Once a link is agreed: the real things ELI VR can draw, for ELI to place in its rooms.
func report_body() -> EliResult:
    if not can("props"):
        return EliResult.bad("unsupported")
    var body := JSON.stringify({"surface": SURFACE, "props": EliProps.catalogue()})
    return await _post("/v1/world/body", body.to_utf8_buffer(), "application/json", 15.0)

func _open() -> void:
    _retry = RETRY_SECONDS
    _socket = WebSocketPeer.new()
    # ELI's world can carry many objects and books; the default 64 KB is not enough. The hello tells
    # ELI this size, and ELI sends no message larger (its books fill what the rest leaves).
    _socket.inbound_buffer_size = INBOUND_BYTES
    if not _token.is_empty():
        _socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + _token])
    var url := base_url.replace("http://", "ws://").replace("https://", "wss://") + "/v1/world/ws"
    if _socket.connect_to_url(url) != OK:
        _socket = null
        problem = EliResult.bad("unreachable", "", 0, true)

func _set_connected(value: bool) -> void:
    if value == connected:
        return
    connected = value
    if connected and problem != null and problem.kind == "unreachable":
        problem = null
    print("ELI link: %s" % ("connected" if connected else "lost"))
    link_changed.emit(connected)
    _tell_agreed()                      # a welcome that came before ELI's world did

# What the status line says about the link itself, or "" when it is whole.
func status() -> String:
    if not enabled:
        return ""
    if problem != null and (not connected or problem.kind != "unsupported"):
        return problem.sentence()
    return "" if connected else "ELI is not running"

## ELI VR is ending: ELI is told the session is over, sent now rather than on a later frame, since
## none may follow. Called by the exit button, by the window being closed and, as the last resort, by
## the link leaving the tree however the app ends; told once, and the link is not opened again. The
## socket closes with the process (or this node), which ELI's world sees as well.
func end_session(summary: String) -> void:
    if not enabled or _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    enabled = false
    send_event("vr_session_ended", summary, {})
    _socket.poll()                      # the event goes out now

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        end_session("The user closed ELI VR")

func _exit_tree() -> void:
    end_session("ELI VR closed")
    _drop_reading()
    for task in _letting_go:
        WorkerThreadPool.wait_for_task_completion(task)
    _letting_go.clear()

func send_event(event_type: String, summary: String, payload: Dictionary = {}) -> void:
    if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    _socket.send_text(JSON.stringify({
        "type": "vr_event",
        "event_type": event_type,
        "summary": summary,
        "payload": payload,
    }))

# --- speech and conversation ---------------------------------------------------

func transcribe(wav: PackedByteArray) -> EliResult:
    var r: EliResult = await _post("/v1/voice/stt?ext=wav", wav, "audio/wav", 60.0)
    if not r.ok:
        return r
    var data = _json(r.payload)
    if typeof(data) != TYPE_DICTIONARY:
        return EliResult.bad("bad_reply", "", r.status)
    var text := str(data.get("text", "")).strip_edges()
    if not bool(data.get("ok", false)) or text.is_empty():
        return EliResult.bad("not_heard", str(data.get("error", "")), r.status, true)
    return EliResult.good(text)

# One sentence to ELI from inside the room. It answers, or it builds. The
# payload is {"kind": "chat" | "build", "text": ..., "results": [...]}.
func say(message: String) -> EliResult:
    if not can("say"):
        return await _chat(message)
    var body := JSON.stringify({"text": message, "session_id": _session})
    # A local model can take a while on a long answer.
    var r: EliResult = await _post("/v1/world/say", body.to_utf8_buffer(), "application/json", 300.0)
    if not r.ok:
        return r
    var data = _json(r.payload)
    if typeof(data) != TYPE_DICTIONARY:
        return EliResult.bad("bad_reply", "", r.status)
    data["text"] = str(data.get("text", "")).strip_edges()
    return EliResult.good(data)

# The same, for an ELI v3 that only has plain conversation. The turn is the
# owner's: this client is a surface of theirs, not another user.
func _chat(message: String) -> EliResult:
    var body := JSON.stringify({"message": message, "session_id": _session, "surface_id": SURFACE})
    var r: EliResult = await _post("/v1/chat", body.to_utf8_buffer(), "application/json", 300.0)
    if not r.ok:
        return r
    var data = _json(r.payload)
    if typeof(data) != TYPE_DICTIONARY:
        return EliResult.bad("bad_reply", "", r.status)
    return EliResult.good({"kind": "chat", "text": str(data.get("response", "")).strip_edges(), "results": []})

func speak(text: String) -> EliResult:
    var body := JSON.stringify({"text": text})
    var r: EliResult = await _post("/v1/voice/tts", body.to_utf8_buffer(), "application/json", 120.0)
    if not r.ok:
        return EliResult.bad("no_voice", r.detail, r.status, r.retryable)
    if (r.payload as PackedByteArray).is_empty():
        return EliResult.bad("no_voice", "", r.status)
    var stream := AudioStreamWAV.load_from_buffer(r.payload)
    return EliResult.good(stream) if stream != null else EliResult.bad("no_voice", "", r.status)

# --- the room ---------------------------------------------------------------------

# What the user and ELI can see now. ELI keeps it only while it is fresh.
func report_scene(scene: Dictionary) -> EliResult:
    if not can("scene"):
        return EliResult.bad("unsupported")
    return await _post("/v1/world/scene", JSON.stringify({"scene": scene}).to_utf8_buffer(), "application/json", 10.0)

# The user moving or changing a thing with their own hands.
func edit(edits: Array, room: String, summary: String = "") -> EliResult:
    if not can("building"):
        return EliResult.bad("unsupported")
    var body := JSON.stringify({"edits": edits, "room": room, "summary": summary})
    return await _answer(await _post("/v1/world/edit", body.to_utf8_buffer(), "application/json", 20.0))

func undo() -> EliResult:
    if not can("undo"):
        return EliResult.bad("unsupported")
    return await _answer(await _post("/v1/world/undo", PackedByteArray(), "application/json", 20.0))

# ELI making one thing in its own room, unasked.
func compose() -> EliResult:
    if not can("building"):
        return EliResult.bad("unsupported")
    return await _answer(await _post("/v1/world/compose", PackedByteArray(), "application/json", 300.0))

# How a game ELI set went (EliPlay): the score is kept by ELI's world, the pieces leave, ELI remembers.
func played(game_id: String, result: Dictionary) -> EliResult:
    if not can("games"):
        return EliResult.bad("unsupported")
    var body := JSON.stringify({"game": game_id, "result": result})
    return await _answer(await _post("/v1/world/played", body.to_utf8_buffer(), "application/json", 30.0))

# --- its mind ---------------------------------------------------------------------

# Which model is ELI's mind now, and which ones ELI could use. No model is
# assumed here: the payload is ELI's own list, by name.
func mind() -> EliResult:
    if not can("mind"):
        return EliResult.bad("unsupported")
    return await _answer(await _request(HTTPClient.METHOD_GET, "/v1/world/mind", PackedByteArray(), "application/json", 15.0))

# Have ELI load this model. The model is loaded before ELI answers, which can take a while.
func use_model(model_name: String) -> EliResult:
    if not can("mind"):
        return EliResult.bad("unsupported")
    var body := JSON.stringify({"model": model_name})
    return await _answer(await _post("/v1/world/mind", body.to_utf8_buffer(), "application/json", 600.0))

func _answer(r: EliResult) -> EliResult:
    if not r.ok:
        return r
    var data = _json(r.payload)
    return EliResult.good(data) if typeof(data) == TYPE_DICTIONARY else EliResult.bad("bad_reply", "", r.status)

func _json(body) -> Variant:
    var text := (body as PackedByteArray).get_string_from_utf8()
    return JSON.parse_string(text) if not text.is_empty() else null

func _post(path: String, body: PackedByteArray, content_type: String, timeout: float) -> EliResult:
    return await _request(HTTPClient.METHOD_POST, path, body, content_type, timeout)

# Every request ends as a result with a kind: an answer, or which failure.
func _request(method: int, path: String, body: PackedByteArray, content_type: String, timeout: float) -> EliResult:
    if not enabled:
        return EliResult.bad("disabled")
    var http := HTTPRequest.new()
    http.timeout = timeout
    add_child(http)
    var headers := PackedStringArray(["Content-Type: " + content_type])
    if not _token.is_empty():
        headers.append("Authorization: Bearer " + _token)
    if http.request_raw(base_url + path, headers, method, body) != OK:
        http.queue_free()
        return EliResult.bad("unreachable", "", 0, true)
    var result: Array = await http.request_completed
    http.queue_free()
    var outcome := int(result[0])
    if outcome == HTTPRequest.RESULT_TIMEOUT:
        return EliResult.bad("timeout", "", 0, true)
    if outcome != HTTPRequest.RESULT_SUCCESS:
        return EliResult.bad("unreachable", "", 0, true)
    var code := int(result[1])
    if code >= 200 and code < 300:
        var good := EliResult.good(result[3])
        good.status = code
        return good
    return _failure(code, result[3])

# ELI says why in the body: {"detail": {"kind": ..., "detail": ...}} from the
# world routes, {"detail": "..."} from the older ones.
func _failure(code: int, body: PackedByteArray) -> EliResult:
    var kind := ""
    var words := ""
    var data = _json(body)
    if typeof(data) == TYPE_DICTIONARY:
        var said = data.get("detail", "")
        if typeof(said) == TYPE_DICTIONARY:
            kind = str(said.get("kind", ""))
            words = str(said.get("detail", ""))
        else:
            words = str(said)
    if kind == "failed" or kind.is_empty():
        match code:
            401: kind = "unauthorised"
            403: kind = "forbidden"
            404, 405: kind = "unsupported"
            408, 504: kind = "timeout"
            503: kind = "model_unavailable"
            _: kind = "bad_request" if code < 500 else "server_error"
    return EliResult.bad(kind, words, code, code in [408, 429, 502, 503, 504])
