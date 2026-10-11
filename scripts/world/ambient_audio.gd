class_name AmbientAudioManager
extends Node

var player: AudioStreamPlayer
var assets: Dictionary = {}
var volume_db := -18.0

func setup(config) -> void:
    player = AudioStreamPlayer.new()
    player.name = "AmbientPlayer"
    add_child(player)
    volume_db = float(config.get_value("audio.ambient_volume_db", -18.0))
    player.volume_db = volume_db
    var f := FileAccess.open("res://config/rooms/environment_assets.json", FileAccess.READ)
    if f:
        var parsed = JSON.parse_string(f.get_as_text())
        if typeof(parsed) == TYPE_DICTIONARY:
            assets = parsed

func play_environment(environment_id: String) -> void:
    var asset: Dictionary = assets.get(environment_id, {})
    var path := str(asset.get("ambient", ""))
    if path.is_empty() or not ResourceLoader.exists(path):
        player.stop()
        return
    var stream = load(path)
    if stream == null:
        return
    stream.set("loop", true)
    player.stream = stream
    player.play()
