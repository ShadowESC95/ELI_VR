class_name XRSessionPolicy
extends Node

var config
var interface: OpenXRInterface

func setup(_app: Node, p_config, p_interface: XRInterface) -> void:
    config = p_config
    if p_interface is OpenXRInterface:
        interface = p_interface
        for signal_name in ["session_focussed", "session_visible", "session_stopping", "session_loss_pending"]:
            if interface.has_signal(signal_name): interface.connect(signal_name, Callable(self, "_on_state").bind(signal_name))

func _on_state(signal_name: String) -> void:
    if not bool(config.get_value("xr.pause_when_unfocused", true)): return
    if signal_name == "session_focussed": get_tree().paused = false
    elif signal_name in ["session_visible", "session_stopping", "session_loss_pending"]: get_tree().paused = true
