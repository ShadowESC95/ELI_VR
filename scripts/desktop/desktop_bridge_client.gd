class_name DesktopBridgeClient
extends Node

## ELI VR's end of the link to the desktop helper on this computer (native/desktop_bridge on
## Windows, macOS and X11; native/desktop_portal_bridge on Wayland). It gives the helper's key,
## reads the screen off the main thread as tiles (all of them first, then only those that changed),
## and passes pointer lines back. The main thread is handed only the newest picture of each tile.

## The screen's size, and [Rect2i, Image] for each place on it that changed since last time.
signal tiles_arrived(screen_size: Vector2i, tiles: Array)
signal state_changed(state: String)

const TILE_MAGIC := 0x454c4954          # "ELIT"
const RETRY_SECONDS := 2.0

var host: String = "127.0.0.1"
var port: int = 47831

var _state: String = "disconnected"
var _thread: Thread
var _running := false
var _lock := Mutex.new()
var _outbox := PackedStringArray()      # pointer lines for the helper
var _arrived := {}                      # Rect2i -> [Rect2i, Image], newest wins
var _screen := Vector2i.ZERO
var _thread_state := "disconnected"
var _max_side := 0                      # the largest texture this GPU takes; a screen is held whole


func configure(p_host: String, p_port: int) -> void:
    var requested: String = p_host.strip_edges().to_lower()
    if requested not in ["127.0.0.1", "::1", "[::1]", "localhost"]:
        push_warning("ELI VR desktop bridge is local-only; refusing host: %s" % p_host)
        host = "127.0.0.1"
    else:
        host = p_host
    port = p_port
    var device := RenderingServer.get_rendering_device()
    _max_side = device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D) if device else 0

func start() -> void:
    if _running:
        return
    _running = true
    _thread = Thread.new()
    _thread.start(_run)

func stop() -> void:
    if not _running:
        return
    _running = false
    _thread.wait_to_finish()
    _thread = null
    _lock.lock()
    _outbox.clear()
    _arrived.clear()
    _thread_state = "disconnected"
    _lock.unlock()
    _set_state("disconnected")

func _exit_tree() -> void:
    stop()

## Pointer input for the desktop, one line of JSON to the helper: "move" with x, y (0..1 across
## and down the screen), "button" with button ("left", "right", "middle") and down, "scroll" with
## steps (up is negative). Dropped while there is no connection.
func send_input(event: Dictionary) -> bool:
    if _state != "connected":
        return false
    _lock.lock()
    _outbox.append(JSON.stringify(event) + "\n")
    _lock.unlock()
    return true

func status_text() -> String:
    return _state

func _process(_delta: float) -> void:
    _lock.lock()
    var state := _thread_state
    var screen := _screen
    var tiles: Array = _arrived.values()
    _arrived.clear()
    _lock.unlock()
    _set_state(state)
    if not tiles.is_empty():
        tiles_arrived.emit(screen, tiles)

func _set_state(value: String) -> void:
    if value == _state:
        return
    _state = value
    state_changed.emit(_state)

## Where the helper keeps the key it made when it started, readable by this account alone. The
## helpers keep it at the same place (native/desktop_bridge/src/key.rs, eli_portal_bridge.py).
static func key_path() -> String:
    match OS.get_name():
        "Windows":
            return OS.get_environment("LOCALAPPDATA").path_join("ELI VR").path_join("desktop-key")
        "macOS":
            return OS.get_environment("HOME").path_join("Library/Application Support/ELI VR/desktop-key")
    var run := OS.get_environment("XDG_RUNTIME_DIR")
    if not run.is_empty():
        return run.path_join("eli-vr-desktop-key")
    return OS.get_environment("HOME").path_join(".local/state/eli-vr-standalone/desktop-key")

# --- the reading thread ----------------------------------------------------------------------

var _peer: StreamPeerTCP
var _buffer := PackedByteArray()        # what has arrived of the item being read
var _need := 0                          # bytes that item needs
var _step := "head"                     # head, tile_head, tile
var _message_tiles := 0                 # tiles still to come in this message
var _message := {}                      # Rect2i -> [Rect2i, Image], this message's tiles
var _message_screen := Vector2i.ZERO
var _tile := Rect2i()

func _run() -> void:
    var next_try := 0.0
    while _running:
        var now := Time.get_ticks_msec() / 1000.0
        if _peer == null or _peer.get_status() in [StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR]:
            _set_thread_state("disconnected")
            if now >= next_try:
                next_try = now + RETRY_SECONDS
                _open()
            OS.delay_msec(20)
            continue
        _peer.poll()
        var status := _peer.get_status()
        if status == StreamPeerTCP.STATUS_CONNECTING:
            _set_thread_state("connecting")
            OS.delay_msec(5)
            continue
        if status != StreamPeerTCP.STATUS_CONNECTED:
            _peer = null
            continue
        _set_thread_state("connected")
        _send_waiting()
        if not _read_some():
            OS.delay_msec(1)
    if _peer:
        _peer.disconnect_from_host()
        _peer = null

func _open() -> void:
    _peer = StreamPeerTCP.new()
    _peer.big_endian = true
    _begin_message()
    if _peer.connect_to_host(host, port) != OK:
        _peer = null
        return
    var key := FileAccess.get_file_as_string(key_path()).strip_edges()
    _lock.lock()
    _outbox.clear()
    _outbox.append(JSON.stringify({"kind": "hello", "key": key}) + "\n")   # the first line, always
    _lock.unlock()

func _set_thread_state(value: String) -> void:
    _lock.lock()
    _thread_state = value
    _lock.unlock()

func _send_waiting() -> void:
    _lock.lock()
    var lines := _outbox
    _outbox = PackedStringArray()
    _lock.unlock()
    for line in lines:
        if _peer.put_data(line.to_utf8_buffer()) != OK:
            _peer = null
            return

## Read what has arrived. False when there was nothing to read.
func _read_some() -> bool:
    if _peer == null:
        return false
    var available := _peer.get_available_bytes()
    if available <= 0:
        return false
    while available > 0 and _peer != null:
        var take := mini(available, _need - _buffer.size())
        var got: Array = _peer.get_partial_data(take)
        if int(got[0]) != OK:
            _peer = null
            return true
        _buffer.append_array(got[1])
        available -= (got[1] as PackedByteArray).size()
        if _buffer.size() >= _need:
            _item_done()
    return true

func _begin_message() -> void:
    _step = "head"
    _need = 16
    _buffer = PackedByteArray()
    _message = {}

func _be32(at: int) -> int:
    return (_buffer[at] << 24) | (_buffer[at + 1] << 16) | (_buffer[at + 2] << 8) | _buffer[at + 3]

func _item_done() -> void:
    match _step:
        "head":
            var w := _be32(4)
            var h := _be32(8)
            if _be32(0) != TILE_MAGIC or w <= 0 or h <= 0 or (_max_side > 0 and maxi(w, h) > _max_side):
                _peer.disconnect_from_host()
                _peer = null
                return
            _message_screen = Vector2i(w, h)
            _message_tiles = _be32(12)
            _next_tile()
        "tile_head":
            _tile = Rect2i(_be32(0), _be32(4), _be32(8), _be32(12))
            if _tile.size.x <= 0 or _tile.size.y <= 0 or not Rect2i(Vector2i.ZERO, _message_screen).encloses(_tile):
                _peer.disconnect_from_host()
                _peer = null
                return
            _step = "tile"
            _need = _tile.size.x * _tile.size.y * 4
            _buffer = PackedByteArray()
        "tile":
            var image := Image.create_from_data(_tile.size.x, _tile.size.y, false, Image.FORMAT_RGBA8, _buffer)
            _message[_tile] = [_tile, image]
            _message_tiles -= 1
            _next_tile()

func _next_tile() -> void:
    if _message_tiles > 0:
        _step = "tile_head"
        _need = 16
        _buffer = PackedByteArray()
        return
    _lock.lock()
    if _message_screen != _screen:
        _arrived.clear()                # a new size: what came before no longer fits
        _screen = _message_screen
    _arrived.merge(_message, true)
    _lock.unlock()
    _begin_message()
