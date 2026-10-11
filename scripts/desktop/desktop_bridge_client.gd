class_name DesktopBridgeClient
extends Node

signal frame_updated(texture: Texture2D)
signal state_changed(state: String)

const RAW_MAGIC: int = 0x454c4952 # "ELIR"

var host: String = "127.0.0.1"
var port: int = 47831
var peer: StreamPeerTCP = StreamPeerTCP.new()
var texture: ImageTexture
var _state: String = "disconnected"
var reconnect_timer: float = 0.0

var frame_mode: String = "header"
var legacy_size: int = -1
var raw_width: int = 0
var raw_height: int = 0
var raw_size: int = 0
var _pending: PackedByteArray = PackedByteArray()

func configure(p_host: String, p_port: int) -> void:
    var requested: String = p_host.strip_edges().to_lower()
    if requested not in ["127.0.0.1", "::1", "[::1]", "localhost"]:
        push_warning("ELI VR desktop bridge is local-only; refusing host: %s" % p_host)
        host = "127.0.0.1"
    else:
        host = p_host
    port = p_port

func start() -> void:
    _connect()

func stop() -> void:
    peer.disconnect_from_host()
    _reset_frame_state()
    _set_state("disconnected")

func _process(delta: float) -> void:
    # The socket only moves past "connecting" when it is polled.
    peer.poll()
    var status: int = peer.get_status()
    if status == StreamPeerTCP.STATUS_CONNECTED:
        _set_state("connected")
        _read_frames()
        return
    if status == StreamPeerTCP.STATUS_CONNECTING:
        _set_state("connecting")
        return
    reconnect_timer -= delta
    if reconnect_timer <= 0.0:
        reconnect_timer = 2.0
        _connect()

func _connect() -> void:
    peer = StreamPeerTCP.new()
    peer.big_endian = true
    _reset_frame_state()
    var err: int = peer.connect_to_host(host, port)
    if err != OK:
        _set_state("disconnected")

func _reset_frame_state() -> void:
    frame_mode = "header"
    legacy_size = -1
    raw_width = 0
    raw_height = 0
    raw_size = 0
    _pending = PackedByteArray()

func _read_frames() -> void:
    # A frame is far bigger than the socket buffer, so it never shows up as
    # one read. Take what has arrived each tick and build the frame here.
    var budget: int = 64
    while budget > 0:
        budget -= 1
        if frame_mode == "header":
            if not _take(4):
                return
            var first: int = _be32(0)
            _pending = PackedByteArray()
            if first == RAW_MAGIC:
                frame_mode = "raw_meta"
            elif first > 0 and first <= 32_000_000:
                legacy_size = first
                frame_mode = "jpeg"
            else:
                _drop()
                return

        if frame_mode == "raw_meta":
            if not _take(12):
                return
            raw_width = _be32(0)
            raw_height = _be32(4)
            raw_size = _be32(8)
            _pending = PackedByteArray()
            if (
                raw_width <= 0 or raw_height <= 0
                or raw_width > 8192 or raw_height > 8192
                or raw_size != raw_width * raw_height * 4
            ):
                _drop()
                return
            frame_mode = "raw"

        if frame_mode == "raw":
            if not _take(raw_size):
                return
            var image: Image = Image.create_from_data(
                raw_width,
                raw_height,
                false,
                Image.FORMAT_RGBA8,
                _pending
            )
            _pending = PackedByteArray()
            _publish(image)
            frame_mode = "header"
            continue

        if frame_mode == "jpeg":
            if not _take(legacy_size):
                return
            var image: Image = Image.new()
            if image.load_jpg_from_buffer(_pending) == OK:
                _publish(image)
            _pending = PackedByteArray()
            frame_mode = "header"
            legacy_size = -1
            continue

func _take(count: int) -> bool:
    var missing: int = count - _pending.size()
    if missing > 0:
        var available: int = peer.get_available_bytes()
        if available <= 0:
            return false
        var result: Array = peer.get_data(mini(missing, available))
        if int(result[0]) != OK:
            _drop()
            return false
        _pending.append_array(result[1])
    return _pending.size() >= count

func _be32(offset: int) -> int:
    return (
        (_pending[offset] << 24) | (_pending[offset + 1] << 16)
        | (_pending[offset + 2] << 8) | _pending[offset + 3]
    )

func _drop() -> void:
    peer.disconnect_from_host()
    _reset_frame_state()

func _publish(image: Image) -> void:
    if texture == null:
        texture = ImageTexture.create_from_image(image)
    else:
        if texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
            texture = ImageTexture.create_from_image(image)
        else:
            texture.update(image)
    frame_updated.emit(texture)

func _set_state(value: String) -> void:
    if value == _state:
        return
    _state = value
    state_changed.emit(_state)

func status_text() -> String:
    return _state
