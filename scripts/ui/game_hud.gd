class_name GameHud
extends CanvasLayer
## Everything drawn over the table: the phase banner and clock, the guest list, the event feed,
## the hidden tray (drag ingredients onto the table), item cards, prompts, private results
## (sniff / peek), the countdown, the reveal board, the emote wheel and the pause menu.

signal leave_requested
signal settings_requested

const P := Defs.Phase

var table: TableView

var _root: Control
var _phase: Label
var _round: Label
var _clock: ProgressBar
var _clock_label: Label
var _guests: VBoxContainer
var _feed: VBoxContainer
var _prompt: Label
var _prompt_box: PanelContainer
var _tray_panel: PanelContainer
var _tray: HBoxContainer
var _tray_title: Label
var _items_panel: PanelContainer
var _items: HBoxContainer
var _pass: Button
var _ready: Button
var _big: Label
var _big_tw: Tween
var _note: PanelContainer
var _note_body: VBoxContainer
var _note_tw: Tween
var _reveal: PanelContainer
var _reveal_rows: VBoxContainer
var _emotes: EmoteWheel
var _pause: Control
var _ptt: Label
var _role: PanelContainer
var _drag: TrayCard
var _drag_ghost: TeaIcon
var _tray_sig := ""
var _items_sig := ""
var _last_phase := -1


func setup(p_table: TableView) -> void:
	table = p_table
	layer = 5
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_banner()
	_build_guests()
	_build_feed()
	_build_bottom()
	_build_big()
	_build_note()
	_build_reveal()
	_emotes = EmoteWheel.new()
	_root.add_child(_emotes)
	_emotes.chosen.connect(func(i: int) -> void: Session.request_emote(i))
	_build_pause()
	Session.state_changed.connect(_refresh)
	Session.game_event.connect(_on_event)
	table.prompt_changed.connect(_refresh_prompt)
	Voice.speaking_changed.connect(func(_p: int, _on: bool) -> void: _refresh_guests())
	_refresh()


# ---------------------------------------------------------------- layout

func _build_banner() -> void:
	var top := UiKit.panel(&"note")
	UiKit.pin(top, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0, 10))
	top.custom_minimum_size = Vector2(380, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var v := UiKit.vbox(2)
	top.add_child(v)
	var h := UiKit.hbox(10)
	v.add_child(h)
	_phase = UiKit.title("", 22)
	_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_phase)
	_round = UiKit.label("", 14, UiKit.hs.text_soft)
	h.add_child(_round)
	var h2 := UiKit.hbox(8)
	v.add_child(h2)
	_clock = ProgressBar.new()
	_clock.show_percentage = false
	_clock.custom_minimum_size = Vector2(0, 12)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clock.max_value = 1.0
	UiKit.hs.style_bar(_clock)
	h2.add_child(_clock)
	_clock_label = UiKit.label("", 14, UiKit.hs.accent, &"sans", 800)
	_clock_label.custom_minimum_size.x = 34
	h2.add_child(_clock_label)


func _build_guests() -> void:
	var p := UiKit.panel(&"note")
	UiKit.pin(p, Vector2.ZERO, Vector2.ZERO, Vector2(12, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_guests = UiKit.vbox(3)
	p.add_child(_guests)


func _build_feed() -> void:
	_feed = UiKit.vbox(4)
	UiKit.pin(_feed, Vector2(1, 0), Vector2(1, 0), Vector2(-12, 12))
	_feed.custom_minimum_size = Vector2(318, 0)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)


func _build_bottom() -> void:
	# Tray bottom-left, items and buttons bottom-right: the middle stays clear for your own cup.
	_prompt_box = UiKit.panel(&"chip")
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt_box)
	UiKit.pin(_prompt_box, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -44))
	_prompt = UiKit.label("", 16, Color(), &"sans", 750)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompt)
	_tray_panel = UiKit.panel(&"paper")
	_tray_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_tray_panel)
	UiKit.pin(_tray_panel, Vector2(0, 1), Vector2(0, 1), Vector2(14, -40))
	var tv := UiKit.vbox(4)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray_panel.add_child(tv)
	_tray_title = UiKit.label("Your tray  (hover or hold Tab)", 12, UiKit.hs.text_soft, &"sans", 800)
	tv.add_child(_tray_title)
	_tray = UiKit.hbox(6)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.custom_minimum_size = Vector2(92, 118)
	tv.add_child(_tray)
	var right := UiKit.hbox(10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	UiKit.pin(right, Vector2(1, 1), Vector2(1, 1), Vector2(-14, -40))
	var bv := UiKit.vbox(8)
	bv.alignment = BoxContainer.ALIGNMENT_END
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(bv)
	_pass = UiKit.button("Pass", func() -> void:
		table.cancel_targeting()
		Session.request_pass())
	_pass.custom_minimum_size = Vector2(140, 38)
	bv.add_child(_pass)
	_ready = UiKit.button("Ready to drink", func() -> void: Session.request_ready_up())
	_ready.custom_minimum_size = Vector2(140, 38)
	bv.add_child(_ready)
	_items_panel = UiKit.panel(&"paper")
	_items_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(_items_panel)
	var iv := UiKit.vbox(4)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_panel.add_child(iv)
	iv.add_child(UiKit.label("Items", 12, UiKit.hs.text_soft, &"sans", 800))
	_items = UiKit.hbox(6)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.custom_minimum_size = Vector2(92, 118)
	iv.add_child(_items)
	_ptt = UiKit.label("", 13, UiKit.hs.light, &"sans", 800)
	_root.add_child(_ptt)
	UiKit.pin(_ptt, Vector2(0, 1), Vector2(0, 1), Vector2(16, -12))


func _build_big() -> void:
	_big = UiKit.title("", 64, UiKit.hs.light)
	UiKit.pin(_big, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, -150))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_constant_override("outline_size", 14)
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.8))
	_big.visible = false
	_root.add_child(_big)


func _build_note() -> void:
	_note = UiKit.panel(&"paper")
	UiKit.pin(_note, Vector2(1, 0.5), Vector2(1, 0.5), Vector2(-16, -20))
	_note.custom_minimum_size = Vector2(330, 0)
	_note.visible = false
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_note)
	_note_body = UiKit.vbox(6)
	_note.add_child(_note_body)


func _build_reveal() -> void:
	_reveal = UiKit.panel()
	UiKit.pin(_reveal, Vector2(1, 0.5), Vector2(1, 0.5), Vector2(-16, -10))
	_reveal.custom_minimum_size = Vector2(350, 0)
	_reveal.visible = false
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reveal)
	var v := UiKit.vbox(6)
	_reveal.add_child(v)
	v.add_child(UiKit.title("The reveal", 24))
	v.add_child(UiKit.hs.rule(2, 2))
	_reveal_rows = UiKit.vbox(4)
	v.add_child(_reveal_rows)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	UiKit.hs.add_backdrop(_pause, 0.45)
	var p := UiKit.panel()
	var v := UiKit.vbox(4)
	p.add_child(v)
	v.add_child(UiKit.title("Paused", 30))
	v.add_child(UiKit.label("The party carries on without you.", 13, UiKit.hs.text_soft))
	v.add_child(UiKit.hs.rule())
	v.add_child(UiKit.menu_button("Back to the table", func() -> void: _pause.visible = false))
	v.add_child(UiKit.menu_button("Settings", func() -> void: settings_requested.emit()))
	v.add_child(UiKit.menu_button("How to play", func() -> void: _show_help()))
	v.add_child(UiKit.menu_button("Leave the party", func() -> void: leave_requested.emit()))
	_pause.add_child(UiKit.center(p))


func _show_help() -> void:
	_pause.visible = false
	_note_show([
		UiKit.title("How it plays", 20),
		UiKit.wrap(UiKit.label(
			"1. Pour: pick up your teapot, pour for the guest on your left, then drag one ingredient from your hidden tray into their cup.\n"
			+ "2. Items: on your turn click an item card, then its targets (cups or guests). Swap moves cups, Sniff smells for poison (sugar hides it), a Toast makes a guest drink now, Peek shows a tray.\n"
			+ "3. Talk: hold V to speak, Q for emotes. Bluff, accuse, beg.\n"
			+ "4. Everyone drinks. More poison than antidote in your cup and you collapse, then haunt the table as a ghost who can rattle cups.\n"
			+ "Right-drag to look around, scroll to zoom.", 13), 300)], 14.0)


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	var total := maxf(Session.phase_total, 0.01)
	_clock.value = clampf(Session.phase_left / total, 0.0, 1.0) if Session.phase_total > 0.0 else 0.0
	_clock_label.text = str(ceili(Session.phase_left)) if Session.phase_left > 0.0 and Session.phase in [P.POUR, P.ITEMS, P.TALK] else ""
	var mouse := get_viewport().get_mouse_position()
	var show := Input.is_action_pressed(&"peek_tray") or _tray_panel.get_global_rect().has_point(mouse) or _drag != null
	for c in _tray.get_children():
		if c is TrayCard:
			(c as TrayCard).set_revealed(show)
	if _drag_ghost:
		_drag_ghost.global_position = mouse - _drag_ghost.size * 0.5
	var mic := "on" if Profile.settings.get("mic", true) else "muted"
	_ptt.text = ("Speaking..." if Voice.transmitting else "Hold %s to talk (mic %s)   %s emotes   Esc menu" % [Keys.label(&"push_to_talk"), mic, Keys.label(&"emote_wheel")])
	if Input.is_action_just_pressed(&"emote_wheel") and not _pause.visible:
		_emotes.open()
	if Input.is_action_just_released(&"emote_wheel"):
		_emotes.close(true)
	if Input.is_action_just_pressed(&"ready_up") and Session.phase == P.TALK and Session.am_alive():
		Session.request_ready_up()


func _input(event: InputEvent) -> void:
	if _drag and event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var card := _drag
		_drag = null
		if _drag_ghost:
			_drag_ghost.queue_free()
			_drag_ghost = null
		card.modulate.a = 1.0
		if not _tray_panel.get_global_rect().has_point((event as InputEventMouseButton).position):
			if table.drop_card((event as InputEventMouseButton).position, card.index, card.is_spike):
				card.queue_free()
			else:
				Sfx.play(&"close", -8.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and table.targeting < 0 and _drag == null:
		_pause.visible = not _pause.visible
		Sfx.play(&"open" if _pause.visible else &"close", -6.0)
		get_viewport().set_input_as_handled()


func _start_drag(card: TrayCard) -> void:
	if card.is_spike:
		if Session.phase != P.POUR or table.spiked:
			return
	elif not table.can_drop_card():
		_flash_prompt()
		return
	_drag = card
	card.modulate.a = 0.35
	_drag_ghost = TeaIcon.make(TeaIcon.Kind.SPIKE if card.is_spike else TeaIcon.Kind.INGREDIENT, card.value, 64)
	_drag_ghost.size = Vector2(64, 64)
	_root.add_child(_drag_ghost)
	Sfx.play(&"card", -4.0)


func _flash_prompt() -> void:
	var tw := _prompt_box.create_tween()
	tw.tween_property(_prompt_box, "modulate", Color(1.3, 0.8, 0.7), 0.1)
	tw.tween_property(_prompt_box, "modulate", Color.WHITE, 0.3)


# ---------------------------------------------------------------- state

func _refresh() -> void:
	var ph := Session.phase
	_phase.text = Defs.PHASE_NAMES.get(ph, "")
	var r := int(Session.public.get("round", 0))
	_round.text = ("Round %d%s" % [r, "  -  laced pot" if Session.public.get("laced", false) else ""]) if r > 0 else ""
	_refresh_guests()
	_refresh_tray()
	_refresh_items()
	_refresh_prompt()
	var alive := Session.am_alive()
	_pass.visible = ph == P.ITEMS and Session.is_my_turn()
	_ready.visible = ph == P.TALK and alive
	var ready := bool(Session.seat_info(Session.my_seat).get("ready", false))
	_ready.disabled = ready
	_ready.text = "Ready!" if ready else "Ready to drink"
	_tray_panel.visible = alive and ph in [P.DEAL, P.POUR, P.ITEMS, P.TALK]
	_items_panel.visible = alive and ph != P.MATCH_END
	if ph != _last_phase:
		_last_phase = ph
		if ph == P.INTRO:
			call_deferred(&"_show_role")
		if ph == P.TALK:
			Sfx.play(&"page", -4.0)


func _refresh_guests() -> void:
	for c in _guests.get_children():
		c.queue_free()
	var turn := int(Session.public.get("turn", -1))
	for i in Session.seat_count():
		var s := Session.seat_info(i)
		var h := UiKit.hbox(6)
		_guests.add_child(h)
		var alive := bool(s.get("alive", true))
		var name_col := UiKit.hs.text if alive else Color("6f7f9a")
		if int(s.get("team", -1)) >= 0:
			name_col = Defs.TEAM_COLORS[int(s["team"])] if alive else name_col
		var nm := UiKit.label(("%s%s" % [s.get("name", "?"), "  (you)" if i == Session.my_seat else ""]), 14, name_col, &"serif", 650)
		nm.custom_minimum_size.x = 170
		h.add_child(nm)
		var tags: Array[String] = []
		if not alive:
			tags.append("ghost")
		elif Session.phase == P.POUR and s.get("poured", false):
			tags.append("poured")
		elif Session.phase == P.ITEMS and i == turn:
			tags.append("choosing...")
		elif Session.phase == P.TALK and s.get("ready", false):
			tags.append("ready")
		if Voice.is_speaking(int(s.get("id", 0))):
			tags.append("speaking")
		if s.get("bot", false):
			tags.append("bot")
		h.add_child(UiKit.label(", ".join(tags), 12, UiKit.hs.accent if "speaking" in tags else UiKit.hs.text_soft, &"sans", 800))


func _refresh_tray() -> void:
	var hand: Array = Session.private.get("hand", [])
	var spike := bool(Session.private.get("spike", false)) and not table.spiked and Session.phase == P.POUR
	var sig := "%s|%s|%d" % [str(hand), spike, Session.public.get("round", 0)]
	if sig == _tray_sig:
		return
	_tray_sig = sig
	for c in _tray.get_children():
		c.queue_free()
	for i in hand.size():
		var card := TrayCard.new().setup(i, int(hand[i]), false)
		card.drag_started.connect(_start_drag)
		_tray.add_child(card)
	if spike:
		var sc := TrayCard.new().setup(-1, 0, false, true)
		sc.drag_started.connect(_start_drag)
		_tray.add_child(sc)
	if hand.is_empty() and not spike:
		_tray.add_child(UiKit.wrap(UiKit.label("Empty until the next deal.", 13, UiKit.hs.text_soft), 90))


func _refresh_items() -> void:
	var items: Array = Session.private.get("items", [])
	var my_turn := Session.is_my_turn()
	var sig := "%s|%s|%d" % [str(items), my_turn, table.targeting]
	if sig == _items_sig:
		return
	_items_sig = sig
	for c in _items.get_children():
		c.queue_free()
	for i in items.size():
		var card := TrayCard.new().setup(i, int(items[i]), true)
		card.enabled = my_turn
		if table.targeting == i:
			card.add_theme_stylebox_override("panel", UiKit.hs.row_box(true))
			card.modulate = Color(1.15, 1.05, 0.85)
		card.clicked.connect(func(c: TrayCard) -> void:
			if table.targeting == c.index:
				table.cancel_targeting()
			else:
				table.begin_targeting(c.index)
			_items_sig = ""
			_refresh_items())
		_items.add_child(card)
	if items.is_empty():
		_items.add_child(UiKit.wrap(UiKit.label("No items. One more each round.", 13, UiKit.hs.text_soft), 90))


func _refresh_prompt() -> void:
	_refresh_items()
	var t := _prompt_text()
	_prompt.text = t
	_prompt_box.visible = t != ""


func _prompt_text() -> String:
	var ph := Session.phase
	var target := Session.seat_name(table.pour_target())
	if Session.my_seat < 0:
		return "You are watching."
	if not Session.am_alive():
		var left := int(Session.seat_info(Session.my_seat).get("rattles", 0))
		if ph in [P.POUR, P.ITEMS, P.TALK]:
			return "You are a ghost. You see what is in every cup. Click a cup to rattle it (%d left)." % left if left > 0 else "You are a ghost. Out of rattles for this round; hold V to talk to the other ghosts."
		return ""
	match ph:
		P.INTRO:
			return "The guests take their seats..."
		P.DEAL:
			return "Dealing ingredients into your hidden tray..."
		P.POUR:
			if bool(Session.seat_info(Session.my_seat).get("poured", false)):
				if bool(Session.private.get("spike", false)) and not table.spiked:
					return "Poured. As the butler you may drag your vial into any other guest's cup."
				return "Poured. Waiting for the others..."
			if table._held:
				return "Carry the teapot to %s's cup and click to pour." % target
			if not table.tea_poured:
				return "Pick up your teapot and pour tea for %s (the glowing cup)." % target
			return "Now drag one ingredient from your tray into %s's cup." % target
		P.ITEMS:
			if Session.is_my_turn():
				if table.targeting >= 0:
					var item := table.targeting_item()
					var need: int = Defs.ITEMS[item]["targets"]
					var what := "cups" if Defs.ITEMS[item]["target"] == &"cup" else "guests"
					return "%s: click %d %s (%d chosen). Right-click to cancel." % [Defs.item_name(item), need, what if need > 1 else what.trim_suffix("s"), table.targets.size()]
				return "Your turn: click an item card to play it, or Pass."
			var turn := int(Session.public.get("turn", -1))
			return "%s is deciding..." % Session.seat_name(turn) if turn >= 0 else ""
		P.TALK:
			if bool(Session.seat_info(Session.my_seat).get("ready", false)):
				return "You're ready. Keep talking while the others decide."
			return "Talk it out! Hold V to speak, Q for emotes. Ready up when you're done."
		P.DRINK:
			return "Raise your cups..."
	return ""


func _show_role() -> void:
	if _role:
		_role.queue_free()
	var role: StringName = Session.private.get("role", &"guest")
	var team := int(Session.private.get("team", -1))
	var mode: StringName = Session.match_rules.get("mode", &"classic")
	var head := "Welcome to the party"
	var body := "Last guest standing wins. Pour for the guest on your left, lie with a straight face."
	if mode == &"teams" and team >= 0:
		head = "Team %s" % Defs.TEAM_NAMES[team]
		body = "Your teammates' names are in your team's colour. Keep them alive; poison the rest."
	elif mode == &"butler":
		if role == &"butler":
			head = "You are the Butler"
			body = "From round 2 you may spike any cup with an extra poison. Survive to the final two and the house is yours."
		else:
			head = "A butler is among you"
			body = "Someone at this table is the hidden butler, spiking cups. Poison the butler and the guests win."
	_role = UiKit.panel()
	var v := UiKit.vbox(6)
	_role.add_child(v)
	v.add_child(UiKit.title(head, 30))
	v.add_child(UiKit.wrap(UiKit.label(body, 15), 380))
	var c := UiKit.center(_role)
	_root.add_child(c)
	UiKit.fade_in(_role, 0.4)
	Sfx.play(&"secret", -3.0)
	var tw := c.create_tween()
	tw.tween_interval(3.6)
	tw.tween_property(_role, "modulate:a", 0.0, 0.5)
	tw.tween_callback(c.queue_free)


# ---------------------------------------------------------------- events

func _on_event(ev: Dictionary) -> void:
	var name_of := func(s: Variant) -> String: return Session.seat_name(int(s))
	match String(ev.get("type", "")):
		"round":
			_reveal.visible = false
			_note.visible = false
			var laced := bool(ev.get("laced", false))
			big("Round %d" % int(ev["round"]), "The pot is laced! Every cup starts with poison." if laced else "", 2.2)
			_log("-- Round %d --" % int(ev["round"]), UiKit.hs.gold)
			if laced:
				_log("The pot is laced: only antidotes save you now.", Color("b8e08a"))
		"pour":
			_log("%s poured for %s." % [name_of.call(ev["seat"]), name_of.call(ev["target"])])
		"pour_mine":
			_log("You dropped %s into %s's cup." % [Defs.ingredient_name(int(ev["k"])), name_of.call(ev["target"])], UiKit.hs.gold)
		"auto_pour":
			_log("Too slow! %s went in for you." % Defs.ingredient_name(int(ev["k"])), Color("f0b0a0"))
		"spike_done":
			_log("You spiked %s's cup." % name_of.call(ev["target"]), Color("d8a8e8"))
		"spike_sound":
			_log("Somewhere, a quiet drip...", Color("c8b8d8"))
		"swap":
			_log("%s swapped %s's and %s's cups." % [name_of.call(ev["seat"]), name_of.call(ev["a"]), name_of.call(ev["b"])])
		"sniff":
			_log("%s sniffed %s's cup." % [name_of.call(ev["seat"]), name_of.call(ev["target"])])
		"sniff_result":
			var who: String = name_of.call(ev["target"])
			var smell := String(ev["smell"])
			var line := {"poison": "smells of bitter almonds. Poison!", "clean": "smells like perfectly ordinary tea.",
				"sweet": "is so sweet you can't smell a thing. Sugar."}[smell] as String
			_note_show([UiKit.title("You sniff %s's cup..." % who, 20),
				UiKit.wrap(UiKit.label("It %s" % line, 15, Color("5f8a2c") if smell == "poison" else Color()), 290)], 7.0)
			Sfx.play(&"secret", -4.0)
		"peek":
			_log("%s peeked at %s's tray." % [name_of.call(ev["seat"]), name_of.call(ev["target"])])
		"peek_result":
			var row := UiKit.hbox(4)
			for k: int in ev["hand"]:
				row.add_child(TeaIcon.make(TeaIcon.Kind.INGREDIENT, k, 40))
			for k: int in ev["items"]:
				row.add_child(TeaIcon.make(TeaIcon.Kind.ITEM, k, 40))
			var names: Array[String] = []
			for k: int in ev["hand"]:
				names.append(Defs.ingredient_name(k))
			var items: Array[String] = []
			for k: int in ev["items"]:
				items.append(Defs.item_name(k))
			_note_show([UiKit.title("%s's tray" % name_of.call(ev["target"]), 20), row,
				UiKit.wrap(UiKit.label("Still holding: %s.\nItems: %s." % [", ".join(names) if not names.is_empty() else "nothing", ", ".join(items) if not items.is_empty() else "none"], 14), 290)], 8.0)
			Sfx.play(&"secret", -4.0)
		"toast":
			_log("%s raised a toast to %s! Drink up." % [name_of.call(ev["seat"]), name_of.call(ev["target"])], UiKit.hs.gold)
		"drink":
			var who: String = name_of.call(ev["seat"])
			var died := bool(ev["died"])
			var tw := create_tween()
			tw.tween_interval(4.3)
			tw.tween_callback(func() -> void:
				_log("%s drank... %s" % [who, "and collapsed!" if died else "and lived."], Color("f0a0a0") if died else Color("b8e08a"))
				if died:
					big("%s collapses!" % who, "", 2.0))
		"drink_all":
			var died: Array[String] = []
			for d: Dictionary in ev["drinks"]:
				if d["died"]:
					died.append(Session.seat_name(int(d["seat"])))
			var tw := create_tween()
			tw.tween_interval(3.9)
			tw.tween_callback(func() -> void:
				if Session.phase != P.REVEAL:
					return
				if died.is_empty():
					big("Everyone lives!", "...for now.", 2.4)
					_log("Everyone survived the round.", Color("b8e08a"))
				else:
					big(" & ".join(died) + (" collapses!" if died.size() == 1 else " collapse!"), "", 2.6)
					for n in died:
						_log("%s has fallen and joins the ghosts." % n, Color("f0a0a0")))
		"reveal":
			var list: Array = ev["cups"]
			var tw := create_tween()
			tw.tween_interval(4.2)
			tw.tween_callback(func() -> void: _show_reveal(list))
		"rattle":
			_log("The ghost of %s rattles %s's cup..." % [name_of.call(ev["seat"]), name_of.call(ev["target"])], Color("a8c8f0"))
		"ready":
			pass
		"pass":
			if ev.get("timeout", false):
				_log("%s ran out of time." % name_of.call(ev["seat"]))
		"countdown":
			_countdown()
		"error":
			_log(String(ev["text"]), Color("f0b0a0"))
			Sfx.play(&"close", -4.0)
		"note":
			_log(String(ev["text"]))


func _countdown() -> void:
	var tw := create_tween()
	for n in ["3", "2", "1", "Drink!"]:
		tw.tween_callback(func() -> void:
			big(n, "", 0.8)
			Sfx.play(&"clink" if n == "Drink!" else &"tick", -2.0))
		tw.tween_interval(0.95)


func big(text: String, sub: String = "", seconds: float = 2.0) -> void:
	_big.text = text + ("\n" + sub if sub != "" else "")
	_big.visible = true
	_big.modulate.a = 1.0
	_big.pivot_offset = _big.size * 0.5
	_big.scale = Vector2.ONE * 0.7
	if _big_tw and _big_tw.is_valid():
		_big_tw.kill()
	_big_tw = create_tween()
	_big_tw.tween_property(_big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_big_tw.tween_interval(seconds)
	_big_tw.tween_property(_big, "modulate:a", 0.0, 0.4)
	_big_tw.tween_callback(func() -> void: _big.visible = false)


func _log(text: String, color: Color = Color()) -> void:
	var chip := UiKit.panel(&"chip")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.wrap(UiKit.label(text, 13, color if color != Color() and color.get_luminance() < 0.5 else UiKit.hs.text, &"sans", 750), 290)
	if color != Color() and color.get_luminance() >= 0.5:
		chip.self_modulate = color.lerp(Color.WHITE, 0.55)
	chip.add_child(l)
	_feed.add_child(chip)
	while _feed.get_child_count() > 7:
		_feed.get_child(0).free()
	var tw := chip.create_tween()
	tw.tween_interval(16.0)
	tw.tween_property(chip, "modulate:a", 0.0, 1.0)
	tw.tween_callback(chip.queue_free)


func _note_show(parts: Array, seconds: float) -> void:
	for c in _note_body.get_children():
		c.queue_free()
	for p: Control in parts:
		_note_body.add_child(p)
	_note.visible = true
	UiKit.fade_in(_note, 0.2)
	if _note_tw and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = create_tween()
	_note_tw.tween_interval(seconds)
	_note_tw.tween_callback(func() -> void: _note.visible = false)


func _show_reveal(list: Array) -> void:
	if Session.phase != P.REVEAL:
		return
	for c in _reveal_rows.get_children():
		c.queue_free()
	for r: Dictionary in list:
		var h := UiKit.hbox(6)
		var nm := UiKit.label(Session.seat_name(int(r["seat"])) + (" (toast)" if r["toast"] else ""), 14, Color(), &"serif", 650)
		nm.custom_minimum_size.x = 140
		h.add_child(nm)
		var icons := UiKit.hbox(2)
		icons.custom_minimum_size.x = 120
		for k: int in r["kinds"]:
			icons.add_child(TeaIcon.make(TeaIcon.Kind.INGREDIENT, k, 28))
		if (r["kinds"] as Array).is_empty():
			icons.add_child(UiKit.label("(empty)", 12, UiKit.hs.text_soft))
		h.add_child(icons)
		h.add_child(UiKit.label("collapsed" if r["died"] else "lived", 13, Color("97461f") if r["died"] else UiKit.hs.good, &"sans", 850))
		_reveal_rows.add_child(h)
	_reveal.visible = true
	UiKit.fade_in(_reveal, 0.3)
	Sfx.play(&"page", -3.0)
