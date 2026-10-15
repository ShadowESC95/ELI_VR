extends CanvasLayer

## Shown in place of the rooms when this copy has no licence. A key activated here is kept in the
## folder every ELI product shares, so ELI v3 and ELI Legal see it too.

const LicenceClass = preload("res://scripts/core/licence.gd")

signal licensed

var _key: LineEdit
var _reason: Label
var _activate: Button

func setup(got: Dictionary) -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color("#0b1118")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 0)
    centre.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)

    var title := Label.new()
    title.text = "ELI VR needs a licence"
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("#63ddff"))
    box.add_child(title)

    _reason = _wrapped(box, "")
    _wrapped(box, "Activate an ELI VR key, or an ELI v3 key that includes ELI VR. A key already activated in ELI v3 or ELI Legal counts here too.")

    _key = LineEdit.new()
    _key.placeholder_text = "ELIV3-…"
    _key.text_submitted.connect(func(_t): _on_activate())
    box.add_child(_key)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    box.add_child(row)
    _activate = Button.new()
    _activate.text = "Activate"
    _activate.pressed.connect(_on_activate)
    row.add_child(_activate)
    var quit := Button.new()
    quit.text = "Quit"
    quit.pressed.connect(func(): get_tree().quit(3))
    row.add_child(quit)

    _wrapped(box, "Buy one: %s" % LicenceClass.BUY).add_theme_color_override("font_color", Color("#9fb3c8"))
    _show(got)
    _key.grab_focus.call_deferred()

func _wrapped(box: VBoxContainer, text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(label)
    return label

func _show(got: Dictionary) -> void:
    var reason := str(got.get("reason", ""))
    _reason.text = reason.substr(0, 1).to_upper() + reason.substr(1) + "." if not reason.is_empty() else ""

func _on_activate() -> void:
    if _key.text.strip_edges().is_empty():
        return
    _activate.disabled = true
    var got := LicenceClass.activate(_key.text)
    _activate.disabled = false
    if LicenceClass.granted(got):
        print("ELI VR licensed: %s" % got.get("reason", ""))
        licensed.emit()
        return
    _show(got)
