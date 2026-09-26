class_name LobbyScreen
extends Control
## The table before the party: who's coming, bots, and the host's rules (room, mode, and custom
## rules once the host reaches the level for them). Voice chat works here too.

signal wardrobe_requested

var _guests: VBoxContainer
var _rules: VBoxContainer
var _start: Button
var _ready_btn: Button
var _why: Label
var _me_ready := false
var _shown_key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiKit.hbox(18)
	add_child(UiKit.center(row))

	var left := UiKit.panel()
	left.custom_minimum_size = Vector2(420, 460)
	row.add_child(left)
	var lv := UiKit.vbox(6)
	left.add_child(lv)
	lv.add_child(UiKit.title("The guest list", 28))
	var where := "Solo table (just you and the bots)" if Net.is_solo else ("Hosting on %s  port %d" % [_addresses(), Net.DEFAULT_PORT] if Net.is_host() else "Joined a table")
	lv.add_child(UiKit.wrap(UiKit.label(where, 13, UiKit.hs.text_soft), 380))
	lv.add_child(UiKit.hs.rule(4, 4))
	_guests = UiKit.vbox(4)
	_guests.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(_guests)
	var bh := UiKit.hbox(8)
	lv.add_child(bh)
	if Net.is_host():
		bh.add_child(UiKit.button("Add bot", func() -> void: Net.add_bot()))
		bh.add_child(UiKit.button("Remove bot", func() -> void: Net.remove_bot()))
	bh.add_child(UiKit.button("Wardrobe", func() -> void: wardrobe_requested.emit()))
	lv.add_child(UiKit.label("Hold %s to talk in the lobby." % Keys.label(&"push_to_talk"), 12, UiKit.hs.text_soft))

	var right := UiKit.panel()
	right.custom_minimum_size = Vector2(440, 460)
	row.add_child(right)
	var rv := UiKit.vbox(6)
	right.add_child(rv)
	rv.add_child(UiKit.title("House rules", 28))
	rv.add_child(UiKit.hs.rule(4, 4))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	_rules = UiKit.vbox(6)
	_rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rules)
	_why = UiKit.wrap(UiKit.label("", 13, UiKit.hs.accent), 400)
	rv.add_child(_why)
	var ah := UiKit.hbox(10)
	rv.add_child(ah)
	ah.add_child(UiKit.button("Leave", func() -> void: Net.leave()))
	ah.add_child(UiKit.spacer(0, 0, true))
	if Net.is_host():
		_start = UiKit.button("Start the party", func() -> void: Net.start_match(), true)
		ah.add_child(_start)
	else:
		_ready_btn = UiKit.button("I'm ready", func() -> void:
			_me_ready = not _me_ready
			Net.set_ready(_me_ready), true)
		ah.add_child(_ready_btn)

	Net.roster_changed.connect(_refresh)
	Net.rules_changed.connect(_on_rules_changed)
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
	for c in _guests.get_children():
		c.queue_free()
	var ids := Net.roster.keys()
	ids.sort()
	for id: int in ids:
		var p: Dictionary = Net.roster[id]
		var row := UiKit.panel(&"row")
		var h := UiKit.hbox(8)
		row.add_child(h)
		var name_text := "%s%s" % [p["name"], "  (host)" if id == 1 else ""]
		var nm := UiKit.label(name_text, 16, Color(), &"serif", 650)
		nm.custom_minimum_size.x = 190
		h.add_child(nm)
		h.add_child(UiKit.label("Lv %d  %s" % [int(p.get("level", 1)), Cosmetics.title_name((p.get("cos", {}) as Dictionary).get("title", &"newcomer"))], 12, UiKit.hs.text_soft))
		h.add_child(UiKit.spacer(0, 0, true))
		var state := "bot" if p["bot"] else ("ready" if p.get("ready", false) or id == 1 else "not ready")
		h.add_child(UiKit.label(state, 12, UiKit.hs.good if state != "not ready" else UiKit.hs.accent, &"sans", 850))
		_guests.add_child(row)
	var seats := Net.max_seats()
	for i in range(ids.size(), seats):
		_guests.add_child(UiKit.label("  an empty chair", 13, Color(UiKit.hs.text_soft, 0.6)))
	var why := Net.can_start() if Net.is_host() else ("You're ready. Waiting for the host." if _me_ready else "Press I'm ready when you're set.")
	_why.text = why
	if _start:
		_start.disabled = why != ""
	if _ready_btn:
		_ready_btn.text = "Not ready" if _me_ready else "I'm ready"


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
	# Room.
	var rooms: Array = Defs.ROOMS.keys()
	var room_names: Array = []
	for id: StringName in rooms:
		var e: Dictionary = Defs.ROOMS[id]
		room_names.append("%s (%d seats)%s" % [e["name"], e["seats"], "" if Profile.is_unlocked_room(id) or not host else "  - level %d" % e["level"]])
	_rules.add_child(_row("Room", _pick(room_names, rooms.find(StringName(r["room"])), host, func(i: int) -> void:
		if Profile.is_unlocked_room(rooms[i]):
			Net.set_rule("room", rooms[i])
		else:
			_refresh_rules())))
	_rules.add_child(UiKit.wrap(UiKit.label(String(Defs.ROOMS[StringName(r["room"])]["desc"]), 12, UiKit.hs.text_soft), 380))
	var modes: Array = Defs.MODES.keys()
	var mode_names: Array = []
	for id: StringName in modes:
		var e: Dictionary = Defs.MODES[id]
		mode_names.append("%s%s" % [e["name"], "" if Profile.is_unlocked_mode(id) or not host else "  - level %d" % e["level"]])
	_rules.add_child(_row("Mode", _pick(mode_names, modes.find(StringName(r["mode"])), host, func(i: int) -> void:
		if Profile.is_unlocked_mode(modes[i]):
			Net.set_rule("mode", modes[i])
		else:
			_refresh_rules())))
	_rules.add_child(UiKit.wrap(UiKit.label(String(Defs.MODES[StringName(r["mode"])]["desc"]), 12, UiKit.hs.text_soft), 380))
	_rules.add_child(_num("Max guests", "max_players", 3, 8, 1, host))
	_rules.add_child(UiKit.hs.rule(6, 4))
	var custom := host and Profile.custom_rules_unlocked()
	if host and not custom:
		_rules.add_child(UiKit.wrap(UiKit.label("Custom rules unlock at level %d. (You are level %d.)" % [Defs.CUSTOM_RULES_LEVEL, Profile.level()], 13, UiKit.hs.accent), 380))
	_rules.add_child(UiKit.label("Custom rules", 16, Color(), &"serif", 650))
	_rules.add_child(_num("Tray size", "hand_size", 1, 5, 1, custom))
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
			_rules.add_child(UiKit.check("Item: %s" % Defs.item_name(it), on, func(v: bool) -> void:
				var list: Array = (Net.rules.get("items_enabled", []) as Array).duplicate()
				if v and not list.has(it):
					list.append(it)
				elif not v:
					list.erase(it)
				Net.set_rule("items_enabled", list)))
		else:
			_rules.add_child(UiKit.label("Item: %s  -  %s" % [Defs.item_name(it), "on" if on else "off"], 13))


func _row(label_text: String, control: Control) -> HBoxContainer:
	var h := UiKit.hbox(8)
	var l := UiKit.label(label_text, 14, UiKit.hs.text_soft, &"sans", 800)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func _pick(names: Array, selected: int, editable: bool, cb: Callable) -> Control:
	if not editable:
		return UiKit.label(String(names[maxi(selected, 0)]), 14, Color(), &"serif", 650)
	return UiKit.option(names, selected, cb)


func _num(label_text: String, key: String, minv: float, maxv: float, step: float, editable: bool) -> HBoxContainer:
	var v := float(Net.rules.get(key, minv))
	var value_label := UiKit.label(_fmt(v, step), 14, UiKit.hs.accent, &"sans", 850)
	value_label.custom_minimum_size.x = 44
	if not editable:
		return _row(label_text, value_label)
	var h := UiKit.hbox(6)
	var s := UiKit.slider(minv, maxv, step, v, func(nv: float) -> void:
		value_label.text = _fmt(nv, step)
		Net.set_rule(key, int(nv) if step >= 1.0 else nv))
	h.add_child(s)
	h.add_child(value_label)
	return _row(label_text, h)


func _flag(label_text: String, key: String, editable: bool) -> Control:
	var on := bool(Net.rules.get(key, false))
	if not editable:
		return _row(label_text, UiKit.label("yes" if on else "no", 14, UiKit.hs.accent, &"sans", 850))
	return UiKit.check(label_text, on, func(v: bool) -> void: Net.set_rule(key, v))


static func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v
