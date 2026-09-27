class_name LobbyScreen
extends Control
## Before the party: who's coming (invite friends on Steam, add bots), and the host's house rules.
## Voice chat works here too.

signal wardrobe_requested

var _guests: VBoxContainer
var _rules: VBoxContainer
var _start: Button
var _ready_btn: Button
var _why: Label
var _code_row: HBoxContainer
var _me_ready := false
var _shown_key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.backdrop(self, 0.45)
	var outer := Ui.vbox(14)
	add_child(Ui.center(outer))
	var title := Ui.title("THE GUEST LIST", 58, Ui.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	var row := Ui.hbox(18)
	outer.add_child(row)

	var left := Ui.panel(Ui.PLUM, 26)
	left.custom_minimum_size = Vector2(460, 470)
	row.add_child(left)
	var lv := Ui.vbox(10)
	left.add_child(lv)
	var where := "SOLO: YOU + BOTS"
	if Net.is_steam:
		where = "ON STEAM"
	elif not Net.is_solo:
		where = "LAN: %s  PORT %d" % [_addresses(), Net.DEFAULT_PORT] if Net.is_host() else "LAN PARTY"
	lv.add_child(Ui.chip(where, Ui.SKY if Net.is_steam else Ui.LILAC, Ui.INK, 16))
	_code_row = Ui.hbox(8)
	lv.add_child(_code_row)
	_guests = Ui.vbox(6)
	_guests.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(_guests)
	var bh := Ui.hbox(8)
	lv.add_child(bh)
	if Net.is_steam:
		bh.add_child(Ui.button("INVITE FRIENDS", func() -> void: add_child(FriendsPanel.new()), Ui.SKY, 18, Vector2(0, 48)))
	if Net.is_host():
		bh.add_child(Ui.button("+ BOT", func() -> void: Net.add_bot(), Ui.MINT, 18, Vector2(0, 48)))
		bh.add_child(Ui.button("- BOT", func() -> void: Net.remove_bot(), Ui.LILAC, 18, Vector2(0, 48)))
	bh.add_child(Ui.button("WARDROBE", func() -> void: wardrobe_requested.emit(), Ui.YELLOW, 18, Vector2(0, 48)))
	lv.add_child(Ui.label("Hold %s to talk" % Keys.label(&"push_to_talk"), 15, Ui.MUTED))

	var right := Ui.panel(Ui.PLUM, 26)
	right.custom_minimum_size = Vector2(480, 470)
	row.add_child(right)
	var rv := Ui.vbox(10)
	right.add_child(rv)
	rv.add_child(Ui.title("HOUSE RULES", 32, Ui.PINK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	_rules = Ui.vbox(8)
	_rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rules)
	_why = Ui.wrap(Ui.label("", 16, Ui.YELLOW, 700), 440)
	rv.add_child(_why)

	var ah := Ui.hbox(14)
	ah.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(ah)
	ah.add_child(Ui.button("LEAVE", func() -> void: Net.leave(), Ui.PLUM_LIGHT, 22, Vector2(160, 64)))
	if Net.is_host():
		_start = Ui.button("START THE PARTY!", func() -> void: Net.start_match(), Ui.MINT, 32, Vector2(420, 76))
		ah.add_child(_start)
	else:
		_ready_btn = Ui.button("I'M READY", func() -> void:
			_me_ready = not _me_ready
			Net.set_ready(_me_ready), Ui.MINT, 32, Vector2(420, 76))
		ah.add_child(_ready_btn)

	Net.roster_changed.connect(_refresh)
	Net.rules_changed.connect(_on_rules_changed)
	Steamworks.lobby_created.connect(func(_id: int) -> void: _refresh())
	_refresh()
	_refresh_rules()


func _addresses() -> String:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return ", ".join(out) if not out.is_empty() else "this computer"


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in _code_row.get_children():
		c.queue_free()
	var code := Net.steam_code()
	if code != "":
		_code_row.add_child(Ui.label("PARTY CODE", 15, Ui.MUTED, 700))
		var e := Ui.line_edit(code, "", 230)
		e.editable = false
		_code_row.add_child(e)
		_code_row.add_child(Ui.button("COPY", func() -> void:
			DisplayServer.clipboard_set(code)
			Sfx.play(&"pop"), Ui.YELLOW, 16, Vector2(90, 44)))
	elif Net.is_steam and Net.is_host():
		_code_row.add_child(Ui.label("Opening a Steam lobby...", 15, Ui.MUTED))
	for c in _guests.get_children():
		c.queue_free()
	var ids := Net.roster.keys()
	ids.sort()
	var palette := [Ui.YELLOW, Ui.PINK, Ui.MINT, Ui.SKY, Ui.LILAC, Ui.ORANGE, Ui.CREAM, Color("ff9fbd")]
	for i in ids.size():
		var id: int = ids[i]
		var p: Dictionary = Net.roster[id]
		var row := Ui.card(Ui.CREAM)
		var h := Ui.hbox(10)
		row.add_child(h)
		var skin := Cosmetics.entry(&"skin", StringName(str((p.get("cos", {}) as Dictionary).get("skin", &"cream"))))
		var dot := Ui.chip(String(p["name"]).left(1).to_upper(), skin.get("body", palette[i % palette.size()]), Ui.INK, 18)
		h.add_child(dot)
		var nv := Ui.vbox(0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nv)
		nv.add_child(Ui.label("%s%s" % [p["name"], "  (host)" if id == 1 else ""], 19, Ui.INK, 700))
		nv.add_child(Ui.label("Lv %d  -  %s" % [int(p.get("level", 1)), Cosmetics.title_name((p.get("cos", {}) as Dictionary).get("title", &"newcomer"))], 14, Color(Ui.INK, 0.6)))
		var ready := bool(p.get("ready", false)) or id == 1
		h.add_child(Ui.chip("BOT" if p["bot"] else ("READY" if ready else "NOT READY"), Ui.LILAC if p["bot"] else (Ui.MINT if ready else Ui.PINK), Ui.INK, 14))
		_guests.add_child(row)
	for i in range(ids.size(), Net.max_seats()):
		_guests.add_child(Ui.label("   (empty chair)", 16, Color(Ui.MUTED, 0.6)))
	var why := Net.can_start() if Net.is_host() else ("You're ready. Waiting for the host..." if _me_ready else "Press I'M READY when you're set.")
	_why.text = why
	if _start:
		_start.disabled = why != ""
	if _ready_btn:
		_ready_btn.text = "NOT READY" if _me_ready else "I'M READY"


## The host's own sliders already show their value; rebuilding mid-drag would drop the slider,
## so the host only rebuilds when the room or mode changes.
func _on_rules_changed() -> void:
	var key := "%s|%s" % [Net.rules.get("room"), Net.rules.get("mode")]
	if Net.is_host() and key == _shown_key:
		_refresh()
		return
	_refresh_rules()
	_refresh()


func _refresh_rules() -> void:
	if not is_inside_tree():
		return
	_shown_key = "%s|%s" % [Net.rules.get("room"), Net.rules.get("mode")]
	for c in _rules.get_children():
		c.queue_free()
	var r := Net.rules
	var host := Net.is_host()
	var rooms: Array = Defs.ROOMS.keys()
	var room_names: Array = []
	for id: StringName in rooms:
		var e: Dictionary = Defs.ROOMS[id]
		room_names.append("%s (%d seats)%s" % [e["name"], e["seats"], ""])
	_rules.add_child(_row("Room", _pick(room_names, rooms.find(StringName(r["room"])), host, func(i: int) -> void:
		if Profile.is_unlocked_room(rooms[i]):
			Net.set_rule("room", rooms[i])
		else:
			_refresh_rules())))
	_rules.add_child(Ui.wrap(Ui.label(String(Defs.ROOMS[StringName(r["room"])]["desc"]), 14, Ui.MUTED), 420))
	var modes: Array = Defs.MODES.keys()
	var mode_names: Array = []
	for id: StringName in modes:
		var e: Dictionary = Defs.MODES[id]
		mode_names.append("%s%s" % [e["name"], ""])
	_rules.add_child(_row("Mode", _pick(mode_names, modes.find(StringName(r["mode"])), host, func(i: int) -> void:
		if Profile.is_unlocked_mode(modes[i]):
			Net.set_rule("mode", modes[i])
		else:
			_refresh_rules())))
	_rules.add_child(Ui.wrap(Ui.label(String(Defs.MODES[StringName(r["mode"])]["desc"]), 14, Ui.MUTED), 420))
	_rules.add_child(_num("Max guests", "max_players", 3, 8, 1, host))
	_rules.add_child(_flag("Night party (moonlight and candles)", "night", host))
	_rules.add_child(_flag("Helium voices (squeaky voice chat)", "helium", host))
	var custom := host and Profile.custom_rules_unlocked()
	_rules.add_child(Ui.title("CUSTOM RULES", 22, Ui.SKY))
	if host and not custom:
		_rules.add_child(Ui.wrap(Ui.label("Unlocks at level %d (you're level %d)." % [Defs.CUSTOM_RULES_LEVEL, Profile.level()], 15, Ui.YELLOW), 420))
	_rules.add_child(_num("Cards in your tray", "hand_size", 1, 5, 1, custom))
	_rules.add_child(_num("Pour time (s)", "pour_time", 10, 60, 5, custom))
	_rules.add_child(_num("Item turn (s)", "item_turn_time", 6, 30, 1, custom))
	_rules.add_child(_num("Talk time (s)", "talk_time", 15, 180, 5, custom))
	_rules.add_child(_num("Items per round", "items_per_round", 0, 2, 1, custom))
	_rules.add_child(_num("Laced pot from round", "laced_round", 2, 12, 1, custom))
	_rules.add_child(_num("Last round", "max_rounds", 3, 15, 1, custom))
	_rules.add_child(_num("Poison strength", "poison_scale", 0.5, 2.0, 0.25, custom))
	_rules.add_child(_num("Ghost rattles", "ghost_rattles", 0, 8, 1, custom))
	_rules.add_child(_flag("Ghosts see inside cups", "ghosts_see_cups", custom))
	_rules.add_child(_flag("Ghosts can talk to the living", "ghosts_talk_to_living", custom))
	var enabled: Array = r.get("items_enabled", [])
	for it: int in Defs.ITEMS:
		var on := enabled.has(it)
		if custom:
			_rules.add_child(Ui.check("Item: %s" % Defs.item_name(it), on, func(v: bool) -> void:
				var list: Array = (Net.rules.get("items_enabled", []) as Array).duplicate()
				if v and not list.has(it):
					list.append(it)
				elif not v:
					list.erase(it)
				Net.set_rule("items_enabled", list)))
		else:
			_rules.add_child(_row("Item: %s" % Defs.item_name(it), Ui.label("on" if on else "off", 16, Ui.YELLOW, 700)))


func _row(label_text: String, control: Control) -> HBoxContainer:
	var h := Ui.hbox(10)
	var l := Ui.label(label_text, 16, Ui.CREAM, 600)
	l.custom_minimum_size.x = 180
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func _pick(names: Array, selected: int, editable: bool, cb: Callable) -> Control:
	if not editable:
		return Ui.label(String(names[maxi(selected, 0)]), 16, Ui.YELLOW, 700)
	return Ui.option(names, selected, cb)


func _num(label_text: String, key: String, minv: float, maxv: float, step: float, editable: bool) -> HBoxContainer:
	var v := float(Net.rules.get(key, minv))
	var value_label := Ui.label(_fmt(v, step), 17, Ui.YELLOW, 700)
	value_label.custom_minimum_size.x = 44
	if not editable:
		return _row(label_text, value_label)
	var h := Ui.hbox(8)
	var s := Ui.slider(minv, maxv, step, v, func(nv: float) -> void:
		value_label.text = _fmt(nv, step)
		Net.set_rule(key, int(nv) if step >= 1.0 else nv))
	h.add_child(s)
	h.add_child(value_label)
	return _row(label_text, h)


func _flag(label_text: String, key: String, editable: bool) -> Control:
	var on := bool(Net.rules.get(key, false))
	if not editable:
		return _row(label_text, Ui.label("yes" if on else "no", 16, Ui.YELLOW, 700))
	return Ui.check(label_text, on, func(v: bool) -> void: Net.set_rule(key, v))


static func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v
