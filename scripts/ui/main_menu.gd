class_name MainMenu
extends Control
## Title screen: your name and progress, then solo / host / join, the wardrobe and settings.

signal wardrobe_requested
signal settings_requested

var _ip: LineEdit
var _port: LineEdit
var _name: LineEdit
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig := TextureRect.new()
	vig.texture = UiKit.hs.tex("vignette")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	var title := UiKit.title("Tea Party", 84, UiKit.hs.light)
	UiKit.pin(title, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0, 18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03, 0.85))
	add_child(title)
	var sub := UiKit.label("Pour. Bluff. Swap. Drink. Somebody collapses.", 18, UiKit.hs.gold, &"serif", 500)
	UiKit.pin(sub, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0, 124))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var p := UiKit.panel()
	UiKit.pin(p, Vector2(0, 0.5), Vector2(0, 0.5), Vector2(48, 60))
	add_child(p)
	var v := UiKit.vbox(4)
	p.add_child(v)
	var nh := UiKit.hbox(8)
	v.add_child(nh)
	nh.add_child(UiKit.label("Your name", 14, UiKit.hs.text_soft))
	_name = UiKit.line_edit(Profile.player_name, "Your name", 200)
	_name.max_length = 24
	_name.text_changed.connect(func(t: String) -> void:
		Profile.player_name = t.strip_edges() if t.strip_edges() != "" else "Guest"
		Profile.save_profile())
	nh.add_child(_name)
	var prog := Profile.level_progress()
	v.add_child(UiKit.label("Level %d  -  %s" % [Profile.level(), Cosmetics.title_name(Profile.equipped[&"title"])], 15, UiKit.hs.accent, &"serif", 650))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 10)
	bar.max_value = prog.y
	bar.value = prog.x
	UiKit.hs.style_bar(bar)
	v.add_child(bar)
	var ch := UiKit.hbox(12)
	v.add_child(ch)
	ch.add_child(UiKit.label("%d / %d XP" % [prog.x, prog.y], 12, UiKit.hs.text_soft))
	UiKit.hs.coin_label(ch, Profile.coins, 14)
	v.add_child(UiKit.hs.rule(6, 4))
	v.add_child(UiKit.menu_button("Play with bots", func() -> void: Net.solo()))
	v.add_child(UiKit.menu_button("Host a table", func() -> void:
		var port := int(_port.text) if _port.text.is_valid_int() else Net.DEFAULT_PORT
		if Net.host_game(port) != OK:
			_status.text = "Could not open port %d." % port))
	var jh := UiKit.hbox(6)
	v.add_child(jh)
	_ip = UiKit.line_edit(str(Profile.settings.get("last_ip", "127.0.0.1")), "Host address", 150)
	jh.add_child(_ip)
	_port = UiKit.line_edit(str(Net.DEFAULT_PORT), "Port", 70)
	jh.add_child(_port)
	jh.add_child(UiKit.button("Join", func() -> void:
		Profile.set_setting("last_ip", _ip.text.strip_edges())
		_status.text = "Knocking on the door..."
		Net.join_game(_ip.text, int(_port.text) if _port.text.is_valid_int() else Net.DEFAULT_PORT)))
	v.add_child(UiKit.hs.rule(6, 4))
	v.add_child(UiKit.menu_button("Wardrobe", func() -> void: wardrobe_requested.emit()))
	v.add_child(UiKit.menu_button("Settings", func() -> void: settings_requested.emit()))
	v.add_child(UiKit.menu_button("Quit", func() -> void: get_tree().quit()))
	_status = UiKit.wrap(UiKit.label("", 13, UiKit.hs.accent), 300)
	v.add_child(_status)

	var how := UiKit.panel(&"paper")
	UiKit.pin(how, Vector2(1, 0.5), Vector2(1, 0.5), Vector2(-48, 60))
	add_child(how)
	var hv := UiKit.vbox(4)
	how.add_child(hv)
	hv.add_child(UiKit.title("How it plays", 22))
	for line in [
		"Everyone gets a hidden tray: poison, antidote, sugar or plain.",
		"Pour tea for the guest on your left and secretly drop one in.",
		"Play an item: swap two cups, sniff one, force a toast, peek at a tray.",
		"Talk it out (hold V): bluff, accuse, beg.",
		"Everyone drinks at once. The poisoned collapse and haunt the table.",
		"More poison every round. Last guest alive wins.",
	]:
		hv.add_child(UiKit.wrap(UiKit.label("-  " + line, 14), 320))


func show_status(text: String) -> void:
	if _status:
		_status.text = text
