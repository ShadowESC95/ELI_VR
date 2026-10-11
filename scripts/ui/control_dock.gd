class_name ControlDock
extends CanvasLayer

var app: Node
var panel: PanelContainer
var room_select: OptionButton
var env_select: OptionButton
var theme_select: OptionButton
var quality_select: OptionButton

func setup(p_app: Node, registry, config) -> void:
    app = p_app
    panel = PanelContainer.new()
    panel.position = Vector2(22,22)
    panel.size = Vector2(390,700)
    add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    panel.add_child(root)

    var title := Label.new()
    title.text = "ELI VR // STANDALONE"
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color("#63ddff"))
    root.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "F1 hide/show • right mouse + WASD in flat mode"
    subtitle.add_theme_font_size_override("font_size", 13)
    root.add_child(subtitle)

    room_select = _select(root, "ROOM", registry.room_ids(), registry.rooms, "name", str(config.get_value("world.room","core_room")))
    room_select.item_selected.connect(func(_i): app.change_room(str(room_select.get_item_metadata(room_select.selected))))

    var env_label := Label.new()
    env_label.text = "ENVIRONMENT OVERRIDE"
    root.add_child(env_label)
    env_select = OptionButton.new()
    env_select.add_item("(ROOM DEFAULT)")
    env_select.set_item_metadata(0, "")
    var current_env := str(config.get_value("world.environment_override",""))
    var env_selected := 0
    for env_id in registry.environment_ids():
        env_select.add_item(str(registry.environment(env_id).get("name",env_id)))
        env_select.set_item_metadata(env_select.item_count-1, env_id)
        if str(env_id) == current_env:
            env_selected = env_select.item_count-1
    env_select.select(env_selected)
    env_select.item_selected.connect(func(_i): app.change_environment(str(env_select.get_item_metadata(env_select.selected))))
    root.add_child(env_select)

    var theme_label := Label.new()
    theme_label.text = "VISUAL THEME"
    root.add_child(theme_label)

    theme_select = OptionButton.new()
    var current_theme: String = str(config.get_value("world.theme", "frontier"))
    var theme_selected: int = 0
    for theme_id in registry.theme_ids():
        var t: Dictionary = registry.theme(str(theme_id))
        theme_select.add_item(str(t.get("display_name", theme_id)))
        theme_select.set_item_metadata(theme_select.item_count - 1, theme_id)
        if str(theme_id) == current_theme:
            theme_selected = theme_select.item_count - 1
    theme_select.select(theme_selected)
    theme_select.item_selected.connect(
        func(_i):
            app.change_theme(
                str(theme_select.get_item_metadata(theme_select.selected))
            )
    )
    root.add_child(theme_select)

    quality_select = OptionButton.new()
    var q_label := Label.new()
    q_label.text = "QUALITY"
    root.add_child(q_label)
    var quality_modes: Array[String] = ["auto", "low", "medium", "high", "ultra"]
    for q in quality_modes:
        quality_select.add_item(q.to_upper())
        quality_select.set_item_metadata(quality_select.item_count - 1, q)
    var configured_quality: String = str(config.get_value("graphics.quality", "auto"))
    if configured_quality.begins_with("auto/"):
        configured_quality = "auto"
    quality_select.select(maxi(0, quality_modes.find(configured_quality)))
    quality_select.item_selected.connect(func(_i): app.change_quality(str(quality_select.get_item_metadata(quality_select.selected))))
    root.add_child(quality_select)

    var desktop_toggle := CheckButton.new()
    desktop_toggle.text = "Live desktop surface"
    desktop_toggle.button_pressed = bool(config.get_value("desktop.enabled",true))
    desktop_toggle.toggled.connect(func(v): app.set_desktop_enabled(v))
    root.add_child(desktop_toggle)

    var portals_toggle := CheckButton.new()
    portals_toggle.text = "Room portals"
    portals_toggle.button_pressed = bool(config.get_value("world.portals",true))
    portals_toggle.toggled.connect(func(v): app.set_portals_enabled(v))
    root.add_child(portals_toggle)

    var console_toggle := CheckButton.new()
    console_toggle.text = "Spatial console"
    console_toggle.button_pressed = bool(config.get_value("world.spatial_console",true))
    console_toggle.toggled.connect(func(v): app.set_spatial_console_enabled(v))
    root.add_child(console_toggle)

    var exit_button := Button.new()
    exit_button.text = "Exit ELI VR"
    exit_button.pressed.connect(func(): app.request_exit())
    root.add_child(exit_button)

    var help := RichTextLabel.new()
    help.fit_content = true
    help.bbcode_enabled = true
    help.text = "[color=#63ddff]XR[/color]\nTrigger: select  • sticks: move/turn\n\n[color=#63ddff]Flat[/color]\nRight mouse: look\nWASD/QE: move\nF1: settings\nF2: desktop\nF3: performance HUD\nF5: rebuild room"
    root.add_child(help)

func _select(parent: VBoxContainer, label_text: String, ids: Array, source: Dictionary, name_key: String, current: String) -> OptionButton:
    var l := Label.new()
    l.text = label_text
    parent.add_child(l)
    var o := OptionButton.new()
    var selected := 0
    for id in ids:
        var display: String = str(source.get(id,{}).get(name_key,id)) if not name_key.is_empty() else str(id).replace("_"," ").to_upper()
        o.add_item(display)
        o.set_item_metadata(o.item_count-1,id)
        if str(id) == current:
            selected = o.item_count-1
    o.select(selected)
    parent.add_child(o)
    return o
