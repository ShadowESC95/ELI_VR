class_name EliVoice
extends Node

# Push to talk. While the button is held the microphone is recorded; on
# release the clip goes to ELI, and his answer comes back as text and speech.
# The microphone is only open while the button is down.

signal state_changed(state: String)   # idle | listening | thinking | speaking
signal heard(text: String)
signal replied(text: String)
signal built(reply: Dictionary)       # he changed the room: what he did, edit by edit
signal failed(result)                 # an EliResult saying which failure it was

const MIN_SECONDS := 0.35
const MAX_SECONDS := 30.0
const MIC_BUS := "EliMic"

var link
var presence
var state := "idle"

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _frames := PackedVector2Array()

func setup(p_link, p_presence) -> void:
    link = p_link
    presence = p_presence

    var bus := AudioServer.get_bus_index(MIC_BUS)
    if bus == -1:
        bus = AudioServer.bus_count
        AudioServer.add_bus(bus)
        AudioServer.set_bus_name(bus, MIC_BUS)
        # Muted, or the user hears their own voice back.
        AudioServer.set_bus_mute(bus, true)
        AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
    _capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture

    _mic = AudioStreamPlayer.new()
    _mic.name = "EliMicrophone"
    _mic.stream = AudioStreamMicrophone.new()
    _mic.bus = MIC_BUS
    add_child(_mic)

func start_listening() -> void:
    if state != "idle" or link == null:
        return
    if not link.connected:
        failed.emit(EliResult.bad("unreachable", "", 0, true))
        return
    _frames.clear()
    _capture.clear_buffer()
    _mic.play()
    _set_state("listening")

func stop_listening() -> void:
    if state != "listening":
        return
    _drain()
    _mic.stop()
    var rate := AudioServer.get_mix_rate()
    if float(_frames.size()) / rate < MIN_SECONDS:
        _set_state("idle")
        return
    converse(_to_wav(_frames, int(rate)))

func _process(_delta: float) -> void:
    if state != "listening":
        return
    _drain()
    if float(_frames.size()) / AudioServer.get_mix_rate() >= MAX_SECONDS:
        stop_listening()

func _drain() -> void:
    var available := _capture.get_frames_available()
    if available > 0:
        _frames.append_array(_capture.get_buffer(available))

# One turn of conversation from a recorded clip. Also the way in for tests.
func converse(wav: PackedByteArray) -> void:
    _set_state("thinking")
    var caught: EliResult = await link.transcribe(wav)
    if not caught.ok:
        _fail(caught)
        return
    await converse_text(str(caught.payload))

# The same from words already in hand.
func converse_text(text: String) -> void:
    _set_state("thinking")
    heard.emit(text)

    var answer: EliResult = await link.say(text)
    if not answer.ok:
        _fail(answer)
        return
    var reply: Dictionary = answer.payload
    var words := str(reply.get("text", ""))
    replied.emit(words)
    if str(reply.get("kind", "")) == "build":
        built.emit(reply)
    if words.is_empty():
        _set_state("idle")
        return

    var speech: EliResult = await link.speak(words)
    if speech.ok and presence != null:
        _set_state("speaking")
        await presence.say(speech.payload)
    elif not speech.ok:
        failed.emit(speech)         # he answered; the words are on the status line
    _set_state("idle")

func _fail(result: EliResult) -> void:
    print("ELI: %s%s" % [result.sentence(), "" if result.detail.is_empty() else " (%s)" % result.detail])
    failed.emit(result)
    _set_state("idle")

func _set_state(value: String) -> void:
    if value == state:
        return
    state = value
    state_changed.emit(state)

# Mono 16-bit PCM at the mixer's rate. ELI's speech-to-text takes any rate.
func _to_wav(frames: PackedVector2Array, rate: int) -> PackedByteArray:
    var pcm := StreamPeerBuffer.new()
    pcm.big_endian = false
    for frame in frames:
        var sample := clampf((frame.x + frame.y) * 0.5, -1.0, 1.0)
        pcm.put_16(int(sample * 32767.0))
    var data := pcm.data_array

    var wav := StreamPeerBuffer.new()
    wav.big_endian = false
    wav.put_data("RIFF".to_ascii_buffer())
    wav.put_32(36 + data.size())
    wav.put_data("WAVEfmt ".to_ascii_buffer())
    wav.put_32(16)          # fmt chunk size
    wav.put_16(1)           # PCM
    wav.put_16(1)           # mono
    wav.put_32(rate)
    wav.put_32(rate * 2)    # bytes per second
    wav.put_16(2)           # bytes per sample frame
    wav.put_16(16)          # bits per sample
    wav.put_data("data".to_ascii_buffer())
    wav.put_32(data.size())
    wav.put_data(data)
    return wav.data_array
