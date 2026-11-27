extends CanvasLayer

## The licence screen: in place of the rooms when this copy has no licence, or opened from the
## control dock ("Licence…") to see this computer's activation code, enter another key, or
## deactivate this computer so the licence can move to another. Only an ELI VR key, or an ELI v3
## key with ELI VR included, opens ELI VR.

const LicenceClass = preload("res://scripts/core/licence.gd")

signal licensed
signal closed

var _key: LineEdit
var _reason: Label
var _activate: Button
var _deactivate: Button
var _manage := false

func setup(got: Dictionary, manage := false) -> void:
    _manage = manage
    var backdrop := ColorRect.new()
    backdrop.color = Color("#0b1118")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(660, 0)
    centre.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    panel.add_child(box)

    var title := Label.new()
    title.text = "ELI VR licence" if manage else "ELI VR needs a licence"
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color("#63ddff"))
    box.add_child(title)

    _reason = _wrapped(box, "")
    if not manage:
        _wrapped(box, "Every ELI product starts with a seven-day trial from its first use; after it, a licence is needed. ELI VR opens with an ELI VR key, or an ELI v3 key sold with ELI VR included. Keys for other ELI products don't open it.")
    _wrapped(box, "The first time a key is entered on a computer it is activated with ELI's licence server (this needs the internet once), and counts as one of the computers the licence is for.").add_theme_color_override("font_color", Color("#9fb3c8"))

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
    _deactivate = Button.new()
    _deactivate.text = "Deactivate this computer"
    _deactivate.tooltip_text = "Give this computer's seat back, so the licence can be activated on another computer"
    _deactivate.pressed.connect(_on_deactivate)
    _deactivate.visible = manage and LicenceClass.granted(got) and not LicenceClass.on_trial(got)
    row.add_child(_deactivate)
    var leave := Button.new()
    leave.text = "Close" if manage else "Quit"
    leave.pressed.connect(_on_leave)
    row.add_child(leave)

    _code_section(box)
    _wrapped(box, "Buy one: %s" % LicenceClass.BUY).add_theme_color_override("font_color", Color("#9fb3c8"))
    _show(got)
    _key.grab_focus.call_deferred()

## This computer's activation code, for activating it from another device when it cannot go online.
func _code_section(box: VBoxContainer) -> void:
    var info := LicenceClass.code()
    var code := str(info.get("activation_code", ""))
    if code.is_empty():
        return
    _wrapped(box, "No internet on this computer? Activate it from any other device at %s with this computer's activation code, then enter the key you are given there:" % info.get("activate_page", "")).add_theme_color_override("font_color", Color("#9fb3c8"))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    box.add_child(row)
    var shown := LineEdit.new()
    shown.text = code
    shown.editable = false
    shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(shown)
    var copy := Button.new()
    copy.text = "Copy"
    copy.pressed.connect(func(): DisplayServer.clipboard_set(code))
    row.add_child(copy)

func _wrapped(box: VBoxContainer, text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(label)
    return label

func _show(got: Dictionary) -> void:
    var reason := str(got.get("reason", ""))
    if reason.is_empty():
        _reason.text = ""
        return
    reason = reason.substr(0, 1).to_upper() + reason.substr(1)
    _reason.text = reason if reason.ends_with(".") or reason.contains("\n") else reason + "."

func _on_leave() -> void:
    if _manage:
        closed.emit()
    else:
        get_tree().quit(3)

func _on_activate() -> void:
    if _key.text.strip_edges().is_empty():
        return
    _activate.disabled = true
    _reason.text = "Activating…"
    await get_tree().process_frame
    var got := LicenceClass.activate(_key.text)
    _activate.disabled = false
    if LicenceClass.granted(got):
        print("ELI VR licensed: %s" % got.get("reason", ""))
        licensed.emit()
        return
    _show(got)

func _on_deactivate() -> void:
    _deactivate.disabled = true
    _reason.text = "Deactivating…"
    await get_tree().process_frame
    var got := LicenceClass.deactivate()
    _deactivate.disabled = false
    if bool(got.get("deactivated", false)):
        print("ELI VR deactivated on this computer")
        licensed.emit()  # reload: the app now asks for a key (or runs on another one held)
        return
    _show(got)
