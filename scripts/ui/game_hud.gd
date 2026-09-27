class_name GameHud
extends CanvasLayer
## Everything over the table, built so a first-timer always knows what to do:
##   top      the step tracker (1 SERVE > 2 ITEMS > 3 TOAST > 4 MEETING > 5 VOTE) + countdown,
##            and under it the coach: one big instruction ("CLICK YOUR TEAPOT") + a hint
##   left     who's at the table (poured / choosing / ready / ghost / talking)
##   right    what just happened
##   bottom   your secret tray (left), items + buttons (right), key hints (centre)
##   centre   stamps ("POISONED!", "ROUND 2"), sniff / peek results, the reveal board
## Plus the emote wheel, the role card and the pause menu.

signal leave_requested
signal settings_requested

const P := Defs.Phase
const STEPS := [[P.POUR, "SERVE"], [P.ITEMS, "ITEMS"], [P.DRINK, "TOAST"], [P.TALK, "MEETING"], [P.VOTE, "VOTE"]]
## Phases with a visible countdown.
const TIMED := [P.POUR, P.ITEMS, P.TALK, P.VOTE]

var table: TableView

var _root: Control
var _steps: Array[PanelContainer] = []
var _round_chip: PanelContainer
var _pie: TimerPie
var _coach: PanelContainer
var _coach_head: Label
var _coach_sub: Label
var _coach_text := ""
var _guests: VBoxContainer
var _feed: VBoxContainer
var _tray_panel: PanelContainer
var _tray: HBoxContainer
var _tray_title: Label
var _items_panel: PanelContainer
var _items: HBoxContainer
var _pass: Button
var _ready: Button
var _keys: HBoxContainer
var _cake_label: Label
var _stamp: Label
var _stamp_tw: Tween
var _note: PanelContainer
var _note_body: VBoxContainer
var _note_tw: Tween
var _reveal: PanelContainer
var _reveal_rows: VBoxContainer
var _emotes: EmoteWheel
var _pause: Control
var _drag: TrayCard
var _drag_ghost: TeaIcon
## Click-click carrying (for touchpads): a quick click on a card picks it up, the next click drops it.
var _drag_from := Vector2.ZERO
var _drag_sticky := false
## Frame-rate watch: suggest Low graphics once if the game is struggling.
var _fps_t := 0.0
var _fps_low := 0
var _fps_told := false
var _tray_sig := ""
var _items_sig := ""
var _guest_sig := ""
var _last_phase := -1
## What you did this round, so you don't have to remember it ("You put POISON in Ada's cup").
var _my_pour := ""
var _my_lock := ""
var _memo: Label
var _points: PanelContainer
var _points_box: VBoxContainer
var _moment: PanelContainer
var _moment_title: Label
var _moment_sub: Label
var _moment_q: Array = []
var _moment_busy := false
## Serving happens in the dark: a dim overlay over the table.
var _dark: ColorRect
var _dark_tw: Tween
## The meeting: claim buttons, and the vote panel.
var _claims: PanelContainer
var _claim_kind: OptionButton
var _claim_a: OptionButton
var _claim_b: OptionButton
var _claim_k: OptionButton
var _claim_sig := ""
var _vote: PanelContainer
var _vote_box: GridContainer
var _vote_sig := ""
var _talking: Array = []
var _chat: ChatBox
var _board: PanelContainer
var _board_box: VBoxContainer
## This round's meeting claims and the reveal, for the board.
var _said: Array = []
var _revealed: Array = []


func setup(p_table: TableView) -> void:
	table = p_table
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dark = ColorRect.new()
	_dark.color = Color(0.02, 0.0, 0.06, 0.0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dark)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_side()
	_build_bottom()
	_build_center()
	_build_meeting()
	_chat = ChatBox.new()
	_root.add_child(_chat)
	Ui.pin(_chat, Vector2(0, 1), Vector2(0, 1), Vector2(14, -14))
	Net.chat_received.connect(_on_chat_bubble)
	_emotes = EmoteWheel.new()
	_root.add_child(_emotes)
	_emotes.chosen.connect(func(i: int) -> void: Session.request_emote(i))
	_build_pause()
	Session.state_changed.connect(_refresh)
	Session.game_event.connect(_on_event)
	table.prompt_changed.connect(_refresh_coach)
	Voice.speaking_changed.connect(func(_p: int, _on: bool) -> void: _refresh_guests())
	_refresh()


# ---------------------------------------------------------------- layout

func _build_top() -> void:
	var top := Ui.vbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(top)
	Ui.pin(top, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0, 12))
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_round_chip = Ui.chip("ROUND 1", Ui.PINK, Ui.CREAM, 18)
	row.add_child(_round_chip)
	for i in STEPS.size():
		var chip := Ui.chip("%d  %s" % [i + 1, STEPS[i][1]], Ui.PLUM_LIGHT, Ui.MUTED, 18)
		row.add_child(chip)
		_steps.append(chip)
		if i < STEPS.size() - 1:
			row.add_child(Ui.label(">", 20, Ui.MUTED, 700, 6))
	_pie = TimerPie.new()
	row.add_child(_pie)
	_coach = PanelContainer.new()
	_coach.add_theme_stylebox_override("panel", Ui.box(Ui.YELLOW, 20, 4, 6, Ui.INK, Vector4(24, 8, 24, 10)))
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_coach)
	var cv := Ui.vbox(0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.add_child(cv)
	_coach_head = Ui.title("", 30, Ui.INK)
	_coach_head.remove_theme_constant_override("outline_size")
	_coach_head.remove_theme_constant_override("shadow_outline_size")
	_coach_head.add_theme_constant_override("shadow_offset_y", 0)
	_coach_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_coach_head)
	_coach_sub = Ui.label("", 16, Ui.INK, 600)
	_coach_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_coach_sub)
	_coach.resized.connect(func() -> void: _coach.pivot_offset = _coach.size * 0.5)


func _build_side() -> void:
	_guests = Ui.vbox(6)
	_guests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_guests)
	Ui.pin(_guests, Vector2(0, 0), Vector2(0, 0), Vector2(14, 14))
	_feed = Ui.vbox(6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.custom_minimum_size = Vector2(300, 0)
	_root.add_child(_feed)
	Ui.pin(_feed, Vector2(1, 0), Vector2(1, 0), Vector2(-14, 14))
	# The claims board: who said what at the meeting, and which stories don't add up.
	_board = Ui.panel(Color(Ui.PLUM_DARK, 0.94), 18, Vector4(14, 10, 14, 12))
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.custom_minimum_size = Vector2(330, 0)
	_board.visible = false
	_root.add_child(_board)
	Ui.pin(_board, Vector2(1, 0), Vector2(1, 0), Vector2(-14, 14))
	_board_box = Ui.vbox(4)
	_board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_board_box)


func _build_bottom() -> void:
	_tray_panel = Ui.panel(Ui.PLUM, 22, Vector4(14, 10, 14, 14))
	_tray_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_tray_panel)
	Ui.pin(_tray_panel, Vector2(0, 1), Vector2(0, 1), Vector2(14, -14))
	var tv := Ui.vbox(6)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray_panel.add_child(tv)
	_tray_title = Ui.label("YOUR SECRET TRAY  (hover or hold TAB)", 15, Ui.YELLOW, 700)
	tv.add_child(_tray_title)
	_tray = Ui.hbox(8)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.custom_minimum_size = Vector2(TrayCard.W, TrayCard.H)
	tv.add_child(_tray)
	_memo = Ui.wrap(Ui.label("", 14, Ui.CREAM, 700), 290)
	_memo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memo.visible = false
	tv.add_child(_memo)
	var right := Ui.hbox(12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	Ui.pin(right, Vector2(1, 1), Vector2(1, 1), Vector2(-14, -14))
	var bv := Ui.vbox(10)
	bv.alignment = BoxContainer.ALIGNMENT_END
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(bv)
	_pass = Ui.button("PASS", func() -> void:
		table.cancel_targeting()
		Session.request_pass(), Ui.LILAC, 22, Vector2(170, 56))
	bv.add_child(_pass)
	_ready = Ui.button("READY TO VOTE", func() -> void: Session.request_ready_up(), Ui.MINT, 20, Vector2(200, 60))
	bv.add_child(_ready)
	_items_panel = Ui.panel(Ui.PLUM, 22, Vector4(14, 10, 14, 14))
	_items_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(_items_panel)
	var iv := Ui.vbox(6)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_panel.add_child(iv)
	iv.add_child(Ui.label("YOUR ITEMS", 15, Ui.SKY, 700))
	_items = Ui.hbox(8)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.custom_minimum_size = Vector2(TrayCard.W, TrayCard.H)
	iv.add_child(_items)
	_keys = Ui.hbox(8)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_keys)
	Ui.pin(_keys, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -14))
	_keys.add_child(_key_chip(Keys.label(&"push_to_talk"), "TALK"))
	_keys.add_child(_key_chip(Keys.label(&"emote_wheel"), "EMOTES"))
	var cake := _key_chip(Keys.label(&"throw_cake"), "THROW CAKE")
	_cake_label = cake.get_meta(&"label")
	_keys.add_child(cake)
	_keys.add_child(_key_chip("RMB", "LOOK"))


func _key_chip(key: String, what: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.85), 14, 3, 3, Ui.INK, Vector4(6, 4, 12, 6)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Ui.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(Ui.chip(key, Ui.CREAM, Ui.INK, 15))
	var l := Ui.label(what, 15, Ui.CREAM, 700)
	h.add_child(l)
	p.set_meta(&"label", l)
	return p


func _build_center() -> void:
	_stamp = Ui.title("", 84, Ui.PINK)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.visible = false
	_root.add_child(_stamp)
	Ui.pin(_stamp, Vector2(0.5, 0.45), Vector2(0.5, 0.5))
	# Clip banner: the headline of the moment ("DOUBLE KILL!", "GHOST SAVE!").
	_moment = Ui.panel(Ui.YELLOW, 22, Vector4(28, 10, 28, 12))
	_moment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moment.visible = false
	var mv := Ui.vbox(0)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moment.add_child(mv)
	_moment_title = Ui.title("", 54, Ui.PINK)
	_moment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_moment_title)
	_moment_sub = Ui.label("", 19, Ui.INK, 700)
	_moment_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_moment_sub)
	_root.add_child(_moment)
	Ui.pin(_moment, Vector2(0.5, 0.72), Vector2(0.5, 0.5))
	# Notes: what YOU know (your pour, your glimpse, sniffs) and what to talk about.
	_points = Ui.panel(Color(Ui.PLUM_DARK, 0.92), 18, Vector4(14, 10, 14, 12))
	_points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.visible = false
	_points_box = Ui.vbox(6)
	_points_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.add_child(_points_box)
	_root.add_child(_points)
	Ui.pin(_points, Vector2(0, 0), Vector2(0, 0), Vector2(14, 236))
	_note = Ui.panel(Ui.CREAM, 22)
	_note.visible = false
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_note)
	Ui.pin(_note, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, 30))
	_note_body = Ui.vbox(8)
	_note.add_child(_note_body)
	_reveal = Ui.panel(Ui.PLUM, 22)
	_reveal.visible = false
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reveal)
	Ui.pin(_reveal, Vector2(1, 0.5), Vector2(1, 0.5), Vector2(-14, 20))
	var v := Ui.vbox(8)
	_reveal.add_child(v)
	v.add_child(Ui.title("THE POISONED CUPS", 26, Ui.YELLOW))
	_reveal_rows = Ui.vbox(6)
	v.add_child(_reveal_rows)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	Ui.backdrop(_pause, 0.7)
	var p := Ui.panel()
	var v := Ui.vbox(12)
	p.add_child(v)
	v.add_child(Ui.title("PAUSED", 48))
	v.add_child(Ui.label("(the party carries on without you)", 16, Ui.MUTED))
	v.add_child(Ui.button("BACK TO THE TABLE", func() -> void: _pause.visible = false, Ui.MINT))
	v.add_child(Ui.button("HOW TO PLAY", func() -> void:
		_pause.visible = false
		var t := Tutorial.new()
		_root.add_child(t), Ui.YELLOW))
	v.add_child(Ui.button("SETTINGS", func() -> void: settings_requested.emit(), Ui.SKY))
	v.add_child(Ui.button("LEAVE THE PARTY", func() -> void: leave_requested.emit(), Ui.PINK))
	_pause.add_child(Ui.center(p))


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_watch_fps(delta)
	var total := maxf(Session.phase_total, 0.01)
	_pie.fraction = clampf(Session.phase_left / total, 0.0, 1.0) if Session.phase in TIMED else 0.0
	_pie.seconds = ceili(Session.phase_left) if Session.phase in TIMED else 0
	_pie.queue_redraw()
	var mouse := get_viewport().get_mouse_position()
	var show := Input.is_action_pressed(&"peek_tray") or _tray_panel.get_global_rect().has_point(mouse) or _drag != null
	for c in _tray.get_children():
		if c is TrayCard:
			(c as TrayCard).set_revealed(show)
	if _drag_ghost:
		_drag_ghost.global_position = mouse - _drag_ghost.size * 0.5
	_cake_label.text = ("THROW CAKE x%d" if Session.am_alive() else "GHOST CAKE x%d") % Session.cakes_left()
	# Keep the chat above the tray while the tray is up.
	var lift := (_tray_panel.size.y + 12.0) if _tray_panel.visible else 0.0
	_chat.position.y = get_viewport().get_visible_rect().size.y - 14.0 - lift - _chat.size.y
	if Ui.typing():
		return
	if Input.is_action_just_pressed(&"emote_wheel") and not _pause.visible:
		_emotes.open()
	if Input.is_action_just_released(&"emote_wheel"):
		_emotes.close(true)
	if Input.is_action_just_pressed(&"ready_up") and Session.phase == P.TALK and Session.am_alive():
		Session.request_ready_up()


## Chat lines also pop up as a speech bubble over the guest who said them.
func _on_chat_bubble(msg: Dictionary) -> void:
	var seat := int(msg.get("seat", -1))
	if table and seat >= 0 and seat < table.guests.size():
		table.guests[seat].say(String(msg.get("text", "")).left(60), 4.0, Color("3a5a9a") if msg.get("ghost", false) else Ui.INK)


func _watch_fps(delta: float) -> void:
	if _fps_told or String(Profile.settings.get("quality", "high")) == "low":
		return
	_fps_t += delta
	if _fps_t < 1.0:
		return
	_fps_t = 0.0
	if Engine.get_frames_per_second() < 30.0 and Session.phase != P.INTRO:
		_fps_low += 1
	else:
		_fps_low = maxi(0, _fps_low - 1)
	if _fps_low >= 6:
		_fps_told = true
		var p := Ui.panel(Ui.YELLOW, 18, Vector4(16, 10, 16, 12))
		var h := Ui.hbox(10)
		p.add_child(h)
		h.add_child(Ui.label("The game is running slowly (%d FPS)." % Engine.get_frames_per_second(), 16, Ui.INK, 700))
		h.add_child(Ui.button("USE LOW GRAPHICS", func() -> void:
			Profile.set_setting("quality", "low")
			p.queue_free(), Ui.MINT, 16, Vector2(0, 40)))
		h.add_child(Ui.button("NO", func() -> void: p.queue_free(), Ui.PLUM_LIGHT, 16, Vector2(60, 40)))
		_root.add_child(p)
		Ui.pin(p, Vector2(0.5, 0), Vector2(0.5, 0), Vector2(0, 150))


func _input(event: InputEvent) -> void:
	var mbe := event as InputEventMouseButton
	if _drag and mbe and mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if _drag and mbe and mbe.button_index == MOUSE_BUTTON_LEFT:
		if not mbe.pressed and not _drag_sticky and mbe.position.distance_to(_drag_from) < 10.0:
			# Just a click on the card: keep carrying it until the next click.
			_drag_sticky = true
			get_viewport().set_input_as_handled()
			return
		if _drag_sticky and not mbe.pressed:
			get_viewport().set_input_as_handled()
			return
		if _drag_sticky and mbe.pressed:
			_drag_sticky = false
			_drop_drag(mbe.position)
			get_viewport().set_input_as_handled()
			return
	if _drag and event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drop_drag((event as InputEventMouseButton).position)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and _drag:
		_cancel_drag()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and table.targeting < 0 and _drag == null and not _chat.is_open():
		_pause.visible = not _pause.visible
		Sfx.play(&"pop", -6.0)
		get_viewport().set_input_as_handled()


func _cancel_drag() -> void:
	if _drag:
		_drag.modulate.a = 1.0
	_drag = null
	_drag_sticky = false
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _drop_drag(pos: Vector2) -> void:
	var card := _drag
	_drag = null
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
	card.modulate.a = 1.0
	if not _tray_panel.get_global_rect().has_point(pos):
		if table.drop_card(pos, card.index, card.is_spike):
			card.queue_free()
		else:
			Sfx.play(&"boing", -8.0)
			_wiggle_coach()


func _start_drag(card: TrayCard) -> void:
	if card.is_spike:
		if Session.phase != P.POUR or table.spiked:
			return
	elif not table.can_drop_card():
		_wiggle_coach()
		Sfx.play(&"boing", -8.0)
		return
	_drag = card
	_drag_from = get_viewport().get_mouse_position()
	_drag_sticky = false
	card.modulate.a = 0.35
	_drag_ghost = TeaIcon.make(TeaIcon.Kind.SPIKE if card.is_spike else TeaIcon.Kind.INGREDIENT, card.value, 80)
	_drag_ghost.size = Vector2(80, 80)
	_root.add_child(_drag_ghost)
	Sfx.play(&"card", -4.0)


func _wiggle_coach() -> void:
	var tw := _coach.create_tween()
	for i in 4:
		tw.tween_property(_coach, "rotation", deg_to_rad(4.0 if i % 2 == 0 else -4.0), 0.05)
	tw.tween_property(_coach, "rotation", 0.0, 0.05)


# ---------------------------------------------------------------- state

func _refresh() -> void:
	var ph := Session.phase
	var r := int(Session.public.get("round", 0))
	(_round_chip.get_child(0) as Label).text = ("ROUND %d%s" % [r, "  LACED POT" if Session.public.get("laced", false) else ""]) if r > 0 else "WELCOME"
	for i in STEPS.size():
		var on: bool = STEPS[i][0] == ph or (ph == P.REVEAL and STEPS[i][0] == P.DRINK) or (ph == P.DEAL and STEPS[i][0] == P.POUR) \
			or (ph == P.EJECT and STEPS[i][0] == P.VOTE)
		var chip := _steps[i]
		chip.add_theme_stylebox_override("panel", Ui.box(Ui.YELLOW if on else Ui.PLUM_LIGHT, 14, 3, 3 if on else 2, Ui.INK, Vector4(12, 3, 12, 5)))
		(chip.get_child(0) as Label).add_theme_color_override("font_color", Ui.INK if on else Ui.MUTED)
		chip.scale = Vector2.ONE * (1.12 if on else 1.0)
		chip.pivot_offset = chip.size * 0.5
	_refresh_guests()
	_refresh_tray()
	_refresh_items()
	_refresh_coach()
	var alive := Session.am_alive()
	_pass.visible = Session.is_my_turn()
	_ready.visible = ph == P.TALK and alive
	var ready := bool(Session.seat_info(Session.my_seat).get("ready", false))
	_ready.disabled = ready
	_ready.text = "READY!" if ready else "READY TO VOTE"
	_tray_panel.visible = alive and ph in [P.DEAL, P.POUR]
	_items_panel.visible = alive and ph in [P.DEAL, P.POUR, P.ITEMS]
	_refresh_notes()
	_refresh_meeting()
	if ph != _last_phase:
		_last_phase = ph
		if ph == P.INTRO:
			call_deferred(&"_show_role")
		_set_dark(ph == P.POUR)
		for i in STEPS.size():
			if STEPS[i][0] == ph:
				Ui.pop_in(_steps[i])
				Sfx.play(&"pop", -4.0)


func _refresh_guests() -> void:
	var rows: Array = []
	for i in Session.seat_count():
		var s := Session.seat_info(i)
		var tag := ""
		var alive := bool(s.get("alive", true))
		if not alive:
			var role := StringName(s.get("role", &""))
			tag = "POISONER" if role == &"poisoner" else ("OUT" if s.get("ejected", false) else "GHOST")
		elif Session.phase == P.POUR:
			tag = "SERVED" if s.get("poured", false) else "serving..."
		elif Session.phase == P.VOTE:
			tag = "VOTED" if s.get("voted", false) else "voting..."
		elif Session.phase == P.ITEMS and not Session.items_resolving():
			tag = "LOCKED IN" if s.get("item_done", false) else "choosing..."
		elif Session.phase == P.TALK:
			tag = "READY" if s.get("ready", false) else ""
		var talking := Voice.is_speaking(int(s.get("id", 0)))
		rows.append([String(s.get("name", "?")), tag, alive, talking, i == Session.my_seat, int(s.get("team", -1)), bool(s.get("bot", false))])
	var sig := str(rows)
	if sig == _guest_sig:
		return
	_guest_sig = sig
	for c in _guests.get_children():
		c.queue_free()
	for r: Array in rows:
		var bg: Color = Ui.PLUM if r[2] else Color("2c2a4a")
		if r[5] >= 0 and r[2]:
			bg = Defs.TEAM_COLORS[r[5]].darkened(0.3)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Ui.box(bg, 14, 3, 3, Ui.MINT if r[3] else Ui.INK, Vector4(10, 3, 12, 5)))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := Ui.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(h)
		var nm := Ui.label(("%s%s" % [r[0], " (you)" if r[4] else ""]), 16, Ui.CREAM if r[2] else Color("9aa6d6"), 700)
		nm.custom_minimum_size.x = 150
		h.add_child(nm)
		if r[3]:
			h.add_child(Ui.label("talking", 13, Ui.MINT, 700))
		if r[1] != "":
			var col := Ui.MINT if r[1] in ["SERVED", "READY", "LOCKED IN", "VOTED"] else (Ui.PINK if r[1] == "POISONER" else Ui.MUTED)
			h.add_child(Ui.label(r[1], 13, col, 700))
		_guests.add_child(p)


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
		_tray.add_child(Ui.wrap(Ui.label("Empty. New cards next round.", 15, Ui.MUTED), 110))


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
		card.clicked.connect(func(c: TrayCard) -> void:
			if table.targeting == c.index:
				table.cancel_targeting()
			else:
				table.begin_targeting(c.index)
			_items_sig = ""
			_refresh_items())
		_items.add_child(card)
		if table.targeting == i:
			card.set_selected.call_deferred(true)
	if items.is_empty():
		_items.add_child(Ui.wrap(Ui.label("No items. You get one each round.", 15, Ui.MUTED), 110))


## The coach: one big instruction and a hint, always about the thing you should do right now.
func _refresh_coach() -> void:
	_refresh_items()
	var c := _coach_text_for()
	var head: String = c[0]
	_coach.visible = head != ""
	if head != _coach_text and head != "":
		Ui.pop_in(_coach)
	_coach_text = head
	_coach_head.text = head
	_coach_sub.text = c[1]
	_coach_sub.visible = c[1] != ""
	_coach.add_theme_stylebox_override("panel", Ui.box(c[2], 20, 4, 6, Ui.INK, Vector4(24, 8, 24, 10)))


func _coach_text_for() -> Array:
	var ph := Session.phase
	var target := Session.seat_name(table.pour_target()).to_upper()
	var poisoner: bool = Session.private.get("role", &"guest") == &"poisoner"
	if Session.my_seat < 0:
		return ["YOU'RE WATCHING", "", Ui.LILAC]
	if not Session.am_alive():
		if ph in [P.DRINK] and Session.cakes_left() > 0:
			return ["GHOST CAKES! (F)", "Knock a cup out of someone's hands. You don't know which cups are deadly either.", Color("a7c7ff")]
		if ph == P.TALK and Session.can_last_words(Session.my_seat):
			return ["YOU WERE POISONED: YOUR LAST WORDS", "Say ONE thing with the bar below (true... or not). Then you're a ghost.", Color("a7c7ff")]
		if ph in [P.TALK, P.VOTE]:
			return ["YOU'RE DEAD: STAY QUIET", "Ghosts don't talk to the living (mute on Discord). Watch them squirm.", Color("a7c7ff")]
		if ph in [P.POUR, P.ITEMS] and int(Session.seat_info(Session.my_seat).get("rattles", 0)) > 0:
			return ["BOO. YOU'RE A GHOST", "Click a cup to rattle it (spooky, means nothing). Ghosts: stay quiet on voice.", Color("a7c7ff")]
		return ["", "", Ui.YELLOW]
	match ph:
		P.INTRO:
			return ["A POISONER IS AT THE TABLE", "Find them and vote them out before they poison everyone.", Ui.YELLOW]
		P.DEAL:
			if poisoner:
				return ["YOU ARE THE POISONER", "Nobody knows. Pour your poison into someone's cup, then lie.", Ui.PINK]
			return ["YOU'RE AN INNOCENT GUEST", "Watch closely in the dark. Remember what you see.", Ui.YELLOW]
		P.POUR:
			if bool(Session.seat_info(Session.my_seat).get("poured", false)):
				return ["SERVED. REMEMBER WHERE!", "Everyone is pouring in the dark. You'll glimpse ONE other guest's pour.", Ui.MINT]
			if table._held:
				return ["CLICK ANYONE'S CUP", "Pour into any other guest's cup. Nobody can see where (it's dark).", Ui.YELLOW]
			if not table.tea_poured:
				return ["LIGHTS OUT! CLICK YOUR TEAPOT", ("Serve someone POISON (tray, bottom left). Pick a victim." if poisoner else "Serve someone a cup. Plain, sugar, or the antidote if you have it."), Ui.YELLOW]
			return ["DRAG A CARD INTO %s'S CUP (or click card, click cup)" % target, ("POISON kills. Or pour something harmless to stay clean." if poisoner else "Remember what you poured: it's your alibi."), Ui.PINK]
		P.ITEMS:
			if Session.items_resolving():
				return ["PLAYING THE ITEMS...", "Sniffs and watches first (secret), then swaps (everyone sees).", Ui.LILAC]
			if Session.is_my_turn():
				if table.targeting >= 0:
					var item := table.targeting_item()
					var need: int = Defs.ITEMS[item]["targets"]
					var what := "CUPS" if Defs.ITEMS[item]["target"] == &"cup" else "GUEST"
					var picked := table.targets.size()
					return ["%s: CLICK %s" % [Defs.item_name(item).to_upper(), ("%d %s (%d/%d)" % [need, what, picked, need]) if need > 1 else "A " + what],
						String(Defs.ITEMS[item]["desc"]) + "  Right-click to cancel.", Ui.SKY]
				return ["USE AN ITEM (everyone picks at once)", "SNIFF a cup, WATCH where a guest poured, or SWAP two cups. Or PASS.", Ui.SKY]
			return ["LOCKED IN: %s" % _my_lock if _my_lock != "" else "LOCKED IN", "Waiting for the others...", Ui.MINT]
		P.DRINK:
			return ["THE TOAST! CAKE A CUP TO SAVE IT (F)", "Think yours is poisoned? Cake it and it spills. Hit a face and they drop theirs.", Ui.ORANGE]
		P.REVEAL:
			return ["", "", Ui.YELLOW]
		P.TALK:
			if bool(Session.seat_info(Session.my_seat).get("ready", false)):
				return ["READY TO VOTE", "Keep arguing until everyone's ready (or the clock runs out).", Ui.MINT]
			if poisoner:
				return ["MEETING: DON'T GET CAUGHT", "Say you poured somewhere else. Blame someone. Don't get caught.", Ui.PINK]
			return ["MEETING: WHO DID IT?", "Say where you poured and what you saw. Spot the lie. Then READY TO VOTE.", Ui.PINK]
		P.VOTE:
			if bool(Session.seat_info(Session.my_seat).get("voted", false)):
				return ["VOTE CAST", "Waiting for the others...", Ui.MINT]
			return ["VOTE: WHO'S THE POISONER?", "Click a name (or SKIP). Most votes gets thrown out.", Ui.PINK]
		P.EJECT:
			return ["", "", Ui.YELLOW]
	return ["", "", Ui.YELLOW]


## What you know this round, as lines for the notes panel.
func _evidence_lines() -> Array[String]:
	var out: Array[String] = []
	var nm := func(i: Variant) -> String: return Session.seat_name(int(i))
	for e: Dictionary in Session.private.get("evidence", []):
		match String(e.get("kind", "")):
			"poured":
				out.append("You poured %s into %s's cup." % [Defs.ingredient_name(int(e["k"])).to_upper(), nm.call(e["into"])])
			"saw":
				out.append("In the dark you SAW %s pour into %s's cup." % [nm.call(e["who"]), nm.call(e["into"])])
			"dark":
				out.append("The candle flickered: you didn't see anyone pour.")
			"sniff":
				out.append("You sniffed %s's cup: %s." % [nm.call(e["target"]), {"poison": "POISON", "clean": "clean", "sweet": "too sweet to tell"}.get(String(e["smell"]), "?")])
			"watch":
				out.append("You WATCHED %s: they poured into %s's cup." % [nm.call(e["who"]), nm.call(e["into"])])
	var partners: Array = Session.private.get("partners", [])
	if not partners.is_empty():
		var names: Array[String] = []
		for p: int in partners:
			names.append(Session.seat_name(p))
		out.push_front("Your fellow poisoner: %s." % ", ".join(names))
	return out


func _refresh_notes() -> void:
	var ph := Session.phase
	var show := Session.am_alive() and ph in [P.ITEMS, P.DRINK, P.REVEAL, P.TALK, P.VOTE]
	var lines := _evidence_lines()
	var sig := "%s|%s|%s" % [show, str(lines), str(_talking) if ph == P.TALK else ""]
	if sig == _points.get_meta(&"sig", ""):
		return
	_points.set_meta(&"sig", sig)
	for c in _points_box.get_children():
		c.queue_free()
	_points.visible = show and not lines.is_empty()
	if not _points.visible:
		return
	_points_box.add_child(Ui.label("WHAT YOU KNOW (only you):", 15, Ui.YELLOW, 800))
	for line in lines:
		_points_box.add_child(Ui.wrap(Ui.label("- " + line, 14, Ui.CREAM, 700), 300))
	if ph == P.TALK and not _talking.is_empty():
		_points_box.add_child(Ui.label("TALK ABOUT THIS:", 15, Ui.SKY, 800))
		for line: String in _talking.slice(0, 3):
			_points_box.add_child(Ui.wrap(Ui.label("- " + line, 14, Ui.CREAM, 700), 300))


func _show_role() -> void:
	var role: StringName = Session.private.get("role", &"guest")
	var n := int(Session.public.get("poisoners", 1))
	var head := "YOU'RE AN INNOCENT GUEST"
	var body := "%s at this table is a secret POISONER. Each round everyone serves a cup in the dark. Remember what you glimpse, catch the liar at the meeting, and vote them out." % ("Someone" if n == 1 else "Two guests")
	var col := Ui.MINT
	if role == &"poisoner":
		head = "YOU ARE THE POISONER"
		body = "Nobody knows. Each round, pour poison into someone's cup in the dark. At the meeting, lie about where you poured. Win when there are as many poisoners as guests left."
		var partners: Array = Session.private.get("partners", [])
		if not partners.is_empty():
			var names: Array[String] = []
			for p: int in partners:
				names.append(Session.seat_name(p))
			body += " Your partner in crime: %s." % ", ".join(names)
		col = Ui.PINK
	var p := Ui.panel()
	var v := Ui.vbox(8)
	p.add_child(v)
	v.add_child(Ui.title(head, 44, col))
	v.add_child(Ui.wrap(Ui.label(body, 20), 560))
	var c := Ui.center(p)
	_root.add_child(c)
	Ui.pop_in(p)
	Sfx.play(&"secret", -3.0)
	var tw := c.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(c.queue_free)


## Lights down while everyone serves (nobody can see where anyone pours).
func _set_dark(on: bool) -> void:
	if _dark_tw and _dark_tw.is_valid():
		_dark_tw.kill()
	_dark_tw = _dark.create_tween()
	_dark_tw.tween_property(_dark, "color:a", 0.74 if on else 0.0, 0.6)
	if on:
		stamp("LIGHTS OUT", Color("c3a6ff"), 1.0)
		Sfx.play(&"secret", -6.0)


# ---------------------------------------------------------------- the meeting: claims and votes

func _build_meeting() -> void:
	_claims = Ui.panel(Color(Ui.PLUM_DARK, 0.95), 18, Vector4(12, 8, 12, 10))
	_claims.visible = false
	_root.add_child(_claims)
	Ui.pin(_claims, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -70))
	var v := Ui.vbox(6)
	_claims.add_child(v)
	var quick := Ui.hbox(8)
	quick.name = "Quick"
	v.add_child(quick)
	var row := Ui.hbox(6)
	v.add_child(row)
	row.add_child(Ui.label("SAY:", 16, Ui.YELLOW, 800))
	_claim_kind = OptionButton.new()
	for k: String in ["I poured into...", "I saw ... pour into...", "It's ...!", "... is innocent"]:
		_claim_kind.add_item(k)
	_claim_kind.item_selected.connect(func(_i: int) -> void: _claim_layout())
	row.add_child(_claim_kind)
	_claim_a = OptionButton.new()
	row.add_child(_claim_a)
	_claim_b = OptionButton.new()
	row.add_child(_claim_b)
	_claim_k = OptionButton.new()
	for k: int in [Defs.Ingredient.NOTHING, Defs.Ingredient.SUGAR, Defs.Ingredient.ANTIDOTE]:
		_claim_k.add_item(Defs.ingredient_name(k).to_upper(), k)
	row.add_child(_claim_k)
	row.add_child(Ui.button("SAY IT", func() -> void: _say_custom(), Ui.YELLOW, 16, Vector2(100, 40)))
	_vote = Ui.panel(Ui.PLUM, 26, Vector4(24, 16, 24, 18))
	_vote.visible = false
	_root.add_child(_vote)
	Ui.pin(_vote, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, 40))
	var vv := Ui.vbox(10)
	_vote.add_child(vv)
	var t := Ui.title("WHO IS THE POISONER?", 36, Ui.PINK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vv.add_child(t)
	_vote_box = GridContainer.new()
	_vote_box.columns = 3
	_vote_box.add_theme_constant_override("h_separation", 10)
	_vote_box.add_theme_constant_override("v_separation", 10)
	vv.add_child(_vote_box)


func _names_into(ob: OptionButton, include_me: bool) -> void:
	var keep := ob.get_selected_id()
	ob.clear()
	for i in Session.seat_count():
		if bool(Session.seat_info(i).get("alive", false)) and (include_me or i != Session.my_seat):
			ob.add_item(Session.seat_name(i), i)
	for j in ob.item_count:
		if ob.get_item_id(j) == keep:
			ob.select(j)


func _claim_layout() -> void:
	var k := _claim_kind.selected
	_claim_b.visible = k == 1
	_claim_k.visible = k == 0


func _say_custom() -> void:
	var a := _claim_a.get_selected_id()
	match _claim_kind.selected:
		0:
			Session.request_claim({"kind": &"poured", "a": a, "k": _claim_k.get_selected_id()})
		1:
			Session.request_claim({"kind": &"saw", "a": a, "b": _claim_b.get_selected_id()})
		2:
			Session.request_claim({"kind": &"sus", "a": a})
		3:
			Session.request_claim({"kind": &"clear", "a": a})
	Sfx.play(&"pop", -6.0)


## True things you can say in one click (from your evidence).
func _truth_claims() -> Array:
	var out: Array = []
	for e: Dictionary in Session.private.get("evidence", []):
		match String(e.get("kind", "")):
			"poured":
				out.append({"kind": &"poured", "a": int(e["into"]), "k": int(e["k"])})
			"saw":
				out.append({"kind": &"saw", "a": int(e["who"]), "b": int(e["into"])})
			"watch":
				out.append({"kind": &"watch", "a": int(e["who"]), "b": int(e["into"])})
			"sniff":
				out.append({"kind": &"sniff", "a": int(e["target"]), "smell": String(e["smell"])})
	return out


## Everything said at this meeting, per guest, plus the stories that contradict the reveal or
## each other. This is the "wait, that doesn't add up" moment made visible.
func _refresh_board() -> void:
	_board.visible = Session.phase in [P.TALK, P.VOTE] and not _said.is_empty()
	_feed.visible = not _board.visible
	for c in _board_box.get_children():
		c.queue_free()
	var nm := func(i: int) -> String: return Session.seat_name(i)
	_board_box.add_child(Ui.label("WHO SAID WHAT", 17, Ui.YELLOW, 800))
	var latest := {}
	for c: Dictionary in _said:
		latest["%d_%s" % [int(c["seat"]), String(c["kind"])]] = c
	for key: String in latest:
		var c: Dictionary = latest[key]
		var line := "%s%s: %s" % [nm.call(int(c["seat"])), " (last words)" if c.get("last", false) else "", Defs.claim_text(c, nm)]
		_board_box.add_child(Ui.wrap(Ui.label(line, 13, Ui.CREAM, 700), 300))
	var odd := _contradictions()
	if not odd.is_empty():
		_board_box.add_child(Ui.label("DOESN'T ADD UP:", 16, Ui.PINK, 800))
		for line: String in odd:
			_board_box.add_child(Ui.wrap(Ui.label("! " + line, 13, Color("ffb3c8"), 700), 300))


func _contradictions() -> Array[String]:
	var out: Array[String] = []
	var nm := func(i: int) -> String: return Session.seat_name(i)
	var poured := {}   # seat -> latest "poured" claim
	for c: Dictionary in _said:
		if StringName(c["kind"]) == &"poured":
			poured[int(c["seat"])] = c
	# 1. The reveal: what really went into the poisoned cups.
	for r: Dictionary in _revealed:
		var cup := int(r["seat"])
		var kinds: Array = r["kinds"]
		var harmless := 0
		for k: int in kinds:
			if k != Defs.Ingredient.POISON:
				harmless += 1
		var into: Array = []
		for s: int in poured:
			if int(poured[s]["a"]) == cup:
				into.append(s)
				var k := int(poured[s].get("k", -1))
				if k >= 0 and k != Defs.Ingredient.POISON and not kinds.has(k):
					out.append("%s says %s went into %s's cup, but there was no %s in it." % [nm.call(s), Defs.ingredient_name(k).to_upper(), nm.call(cup), Defs.ingredient_name(k).to_lower()])
		if into.size() > harmless:
			out.append("%d guests say they poured into %s's cup, but only %d harmless drink%s went in." % [into.size(), nm.call(cup), harmless, "" if harmless == 1 else "s"])
	# 2. A sighting against someone's own story.
	for c: Dictionary in _said:
		if StringName(c["kind"]) in [&"saw", &"watch"]:
			var who := int(c["a"])
			if poured.has(who) and int(poured[who]["a"]) != int(c["b"]) and who != int(c["seat"]):
				out.append("%s says they poured into %s's cup, but %s says they saw them pour into %s's." % [nm.call(who), nm.call(int(poured[who]["a"])), nm.call(int(c["seat"])), nm.call(int(c["b"]))])
	return out


func _refresh_meeting() -> void:
	var ph := Session.phase
	var alive := Session.am_alive()
	var last := not alive and Session.can_last_words(Session.my_seat)
	_claims.visible = (alive or last) and ph == P.TALK
	_board.visible = ph in [P.TALK, P.VOTE] and not _said.is_empty()
	_feed.visible = not _board.visible
	if _claims.visible:
		var sig := str(Session.private.get("evidence", [])) + str(Session.public.get("seats", []).size())
		if sig != _claim_sig:
			_claim_sig = sig
			_names_into(_claim_a, false)
			_names_into(_claim_b, false)
			_claim_layout()
			var quick: HBoxContainer = _claims.get_node("VBoxContainer/Quick") if _claims.has_node("VBoxContainer/Quick") else null
			if quick == null:
				for c in _claims.get_child(0).get_children():
					if c.name == "Quick":
						quick = c
			if quick:
				for c in quick.get_children():
					c.queue_free()
				var nm := func(i: int) -> String: return Session.seat_name(i)
				for c: Dictionary in _truth_claims():
					var text := Defs.claim_text(c, nm)
					var claim := c
					quick.add_child(Ui.button(text, func() -> void:
						Session.request_claim(claim)
						Sfx.play(&"pop", -6.0), Ui.MINT, 14, Vector2(0, 38)))
				if Session.private.get("role", &"guest") == &"poisoner":
					quick.add_child(Ui.label("(the green lines are the TRUTH: don't say them!)", 13, Ui.PINK, 700))
	_vote.visible = alive and ph == P.VOTE and not bool(Session.seat_info(Session.my_seat).get("voted", false))
	if _vote.visible:
		var sig := str(Session.public.get("seats", []).map(func(x: Dictionary) -> bool: return x["alive"]))
		if sig != _vote_sig:
			_vote_sig = sig
			for c in _vote_box.get_children():
				c.queue_free()
			for i in Session.seat_count():
				if i == Session.my_seat or not bool(Session.seat_info(i).get("alive", false)):
					continue
				var seat := i
				_vote_box.add_child(Ui.button(Session.seat_name(i), func() -> void:
					Session.request_vote(seat)
					Sfx.play(&"stamp" if false else &"pop", -2.0), Ui.CREAM, 20, Vector2(220, 58)))
			_vote_box.add_child(Ui.button("SKIP", func() -> void: Session.request_vote(-1), Ui.LILAC, 20, Vector2(220, 58)))
	else:
		_vote_sig = ""


# ---------------------------------------------------------------- events

func _on_event(ev: Dictionary) -> void:
	var name_of := func(s: Variant) -> String: return Session.seat_name(int(s))
	match String(ev.get("type", "")):
		"round":
			_talking = []
			_said = []
			_revealed = []
			_moment_q.clear()
			_reveal.visible = false
			_note.visible = false
			_my_pour = ""
			_my_lock = ""
			stamp("ROUND %d" % int(ev["round"]), Ui.YELLOW, 1.6)
			_log("ROUND %d" % int(ev["round"]), Ui.YELLOW)
		"pour":
			if int(ev["seat"]) != Session.my_seat:
				_log("%s served a cup... somewhere" % name_of.call(ev["seat"]), Ui.MUTED)
		"pour_mine":
			_my_pour = "You put %s in %s's cup." % [Defs.ingredient_name(int(ev["k"])).to_upper(), name_of.call(ev["target"])]
			_log("You poured %s into %s's cup" % [Defs.ingredient_name(int(ev["k"])).to_upper(), name_of.call(ev["target"])], Ui.YELLOW)
		"auto_pour":
			_log("Too slow! %s went into %s's cup for you" % [Defs.ingredient_name(int(ev["k"])).to_upper(), name_of.call(ev["target"])], Ui.PINK)
		"sighting":
			if int(ev["who"]) < 0:
				_note_show([Ui.title("IN THE DARK...", 30, Ui.INK), Ui.wrap(Ui.label("The candle flickered. You didn't see anyone pour.", 18, Ui.INK), 380)], 4.0)
			else:
				_note_show([Ui.title("IN THE DARK YOU SAW...", 30, Ui.INK),
					Ui.title("%s" % String(name_of.call(ev["who"])).to_upper(), 40, Ui.PINK),
					Ui.wrap(Ui.label("pour something into %s's cup. Remember it for the meeting!" % name_of.call(ev["into"]), 18, Ui.INK), 380)], 6.0)
			Sfx.play(&"secret", -4.0)
		"lights_on":
			_set_dark(false)
		"watch_result":
			_note_show([Ui.title("YOU WATCHED %s..." % String(name_of.call(ev["who"])).to_upper(), 28, Ui.INK),
				Ui.wrap(Ui.label("They poured into %s's cup." % name_of.call(ev["into"]), 22, Ui.INK, 800), 380),
				Ui.wrap(Ui.label("If they say otherwise, they're lying.", 16, Ui.INK), 380)], 6.0)
			Sfx.play(&"secret", -4.0)
		"claim":
			var nm := func(i: int) -> String: return Session.seat_name(i)
			var text := Defs.claim_text(ev, nm)
			var who := int(ev["seat"])
			_said.append(ev)
			_refresh_board()
			_log("%s%s: \"%s\"" % [name_of.call(who), " (last words)" if ev.get("last", false) else "", text], Ui.CREAM if who != Session.my_seat else Ui.YELLOW)
			if table and who < table.guests.size():
				table.guests[who].say(text, 4.0)
		"vote_start":
			stamp("VOTE!", Ui.PINK, 1.2)
			Sfx.play(&"bell", -2.0)
		"voted":
			Sfx.play(&"tick", -6.0)
		"vote_result":
			_show_votes(ev)
		"spike_done":
			_log("You spiked %s's cup" % name_of.call(ev["target"]), Ui.LILAC)
		"spike_sound":
			_log("...a suspicious drip", Ui.LILAC)
		"swap":
			_log("%s SWAPPED %s's and %s's cups!" % [name_of.call(ev["seat"]), name_of.call(ev["a"]), name_of.call(ev["b"])], Ui.SKY)
		"sniff":
			_log("%s sniffed %s's cup" % [name_of.call(ev["seat"]), name_of.call(ev["target"])])
		"sniff_result":
			var who: String = name_of.call(ev["target"])
			var smell := String(ev["smell"])
			var head := {"poison": "POISON!", "clean": "SMELLS FINE", "sweet": "TOO SWEET TO TELL"}[smell] as String
			var line := {"poison": "It smells of bitter almonds. (An antidote in there would still save them.)",
				"clean": "Just tea. No poison in %s's cup right now." % who,
				"sweet": "Someone put sugar in. It hides everything."}[smell] as String
			var col := {"poison": Color("4f9e1f"), "clean": Color("1f7a4d"), "sweet": Color("b04a7a")}[smell] as Color
			_note_show([Ui.title("YOU SNIFF %s'S CUP..." % who.to_upper(), 26, Ui.INK), Ui.title(head, 48, col),
				Ui.wrap(Ui.label(line, 17, Ui.INK), 380)], 6.0)
			Sfx.play(&"secret", -4.0)
		"peek":
			_log("%s watched %s" % [name_of.call(ev["seat"]), name_of.call(ev["target"])])
		"peek_result":
			var row := Ui.hbox(6)
			for k: int in ev["hand"]:
				row.add_child(TeaIcon.make(TeaIcon.Kind.INGREDIENT, k, 56))
			for k: int in ev["items"]:
				row.add_child(TeaIcon.make(TeaIcon.Kind.ITEM, k, 56))
			var names: Array[String] = []
			for k: int in ev["hand"]:
				names.append(Defs.ingredient_name(k))
			_note_show([Ui.title("%s'S TRAY" % String(name_of.call(ev["target"])).to_upper(), 30, Ui.INK), row,
				Ui.wrap(Ui.label("Still holding: %s. So they poured something ELSE..." % (", ".join(names) if not names.is_empty() else "nothing"), 17, Ui.INK), 380)], 7.0)
			Sfx.play(&"secret", -4.0)
		"toast":
			_log("%s FORCES %s TO DRINK!" % [name_of.call(ev["seat"]), name_of.call(ev["target"])], Ui.YELLOW)
			stamp("A TOAST!", Ui.YELLOW, 1.2)
		"drink":
			var who: String = name_of.call(ev["seat"])
			var died := bool(ev["died"])
			var tw := create_tween()
			tw.tween_interval(3.0)
			tw.tween_callback(func() -> void:
				_log("%s drank... %s" % [who, "and DROPPED DEAD" if died else "and survived"], Ui.PINK if died else Ui.MINT)
				stamp("POISONED!" if died else "SAFE!", Ui.PINK if died else Ui.MINT, 1.8))
		"drink_all":
			var died: Array[String] = []
			for d: Dictionary in ev["drinks"]:
				if d["died"]:
					died.append(Session.seat_name(int(d["seat"])) + (" (a POISONER!)" if StringName(d.get("role", &"")) == &"poisoner" else ""))
			var tw := create_tween()
			tw.tween_interval(3.0)
			tw.tween_callback(func() -> void:
				if Session.phase != P.REVEAL:
					return
				if died.is_empty():
					stamp("EVERYONE LIVES!", Ui.MINT, 2.0)
					_log("Everyone survived. For now.", Ui.MINT)
				else:
					stamp("POISONED!", Ui.PINK, 2.2)
					for n in died:
						_log("%s was poisoned. Who did it?" % n, Ui.PINK))
		"reveal":
			var list: Array = ev["cups"]
			_revealed = list
			var tw := create_tween()
			tw.tween_interval(4.5)
			tw.tween_callback(func() -> void: _show_reveal(list))
		"rattle":
			_log("The ghost of %s rattles %s's cup..." % [name_of.call(ev["seat"]), name_of.call(ev["target"])], Color("a7c7ff"))
		"cake":
			var v := int(ev.get("victim", -1))
			match String(ev.get("hit", "miss")):
				"cup":
					_log("%s's cake SPILLED %s's tea!" % [name_of.call(ev["seat"]), name_of.call(v)], Ui.SKY)
					if v == Session.my_seat:
						stamp("YOUR CUP SPILLED!", Ui.SKY, 1.4)
				"head":
					_log("%s BONKED %s%s" % [name_of.call(ev["seat"]), name_of.call(v), " (cup dropped!)" if ev.get("spilled", false) else ""], Ui.ORANGE)
					if v == Session.my_seat:
						stamp("BONK!", Ui.ORANGE, 1.0)
		"locked_mine":
			var t: Array[String] = []
			for x: int in ev["targets"]:
				t.append(Session.seat_name(x))
			_my_lock = Defs.item_name(int(ev["item"])).to_upper() + ((" > " + ", ".join(t)) if not t.is_empty() else "")
		"item_step":
			_log("%s plays %s" % [name_of.call(ev["seat"]), Defs.item_name(int(ev["item"])).to_upper()], Ui.LILAC)
		"pass":
			if ev.get("timeout", false):
				_log("%s ran out of time" % name_of.call(ev["seat"]))
		"moments":
			for m: Dictionary in ev.get("list", []):
				_moment_q.append(m)
			if Session.phase == P.DRINK and not (ev.get("list", []) as Array).is_empty() and String(ev["list"][0]["title"]).ends_with("SAVE!"):
				_play_moments(0.0)
			else:
				_play_moments(3.8)
		"talking_points":
			_talking = ev.get("lines", [])
			_reveal.visible = false
			stamp("MEETING!", Ui.SKY, 1.2)
			_refresh_notes()
			Ui.pop_in(_points)
		"countdown":
			_countdown()
		"error":
			_log(String(ev["text"]), Ui.PINK)
			Sfx.play(&"boing", -4.0)
		"note":
			_log(String(ev["text"]))


func _countdown() -> void:
	var tw := create_tween()
	for n in ["3", "2", "1", "DRINK!"]:
		tw.tween_callback(func() -> void:
			stamp(n, Ui.YELLOW if n != "DRINK!" else Ui.PINK, 0.7)
			Sfx.play(&"clink" if n == "DRINK!" else &"tick", -2.0))
		tw.tween_interval(0.95)


## A huge comic stamp in the middle of the screen.
## Shows queued clip banners one after another.
func _play_moments(delay: float) -> void:
	if _moment_busy:
		return
	_moment_busy = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	while not _moment_q.is_empty():
		var m: Dictionary = _moment_q.pop_front()
		_moment_title.text = String(m.get("title", ""))
		_moment_sub.text = String(m.get("sub", ""))
		_moment.visible = true
		_moment.modulate.a = 1.0
		Ui.pop_in(_moment)
		Sfx.play(&"sting", -4.0)
		_log(String(m.get("title", "")) + " " + String(m.get("sub", "")), Ui.YELLOW)
		await get_tree().create_timer(1.8).timeout
		var tw := _moment.create_tween()
		tw.tween_property(_moment, "modulate:a", 0.0, 0.25)
		await tw.finished
		_moment.visible = false
	_moment_busy = false


func stamp(text: String, color: Color, seconds: float = 1.5) -> void:
	_stamp.text = text
	_stamp.add_theme_color_override("font_color", color)
	_stamp.visible = true
	_stamp.modulate.a = 1.0
	await get_tree().process_frame
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.scale = Vector2.ONE * 2.2
	_stamp.rotation = deg_to_rad(randf_range(-8, 8))
	if _stamp_tw and _stamp_tw.is_valid():
		_stamp_tw.kill()
	_stamp_tw = create_tween()
	_stamp_tw.tween_property(_stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tw.tween_interval(seconds)
	_stamp_tw.tween_property(_stamp, "modulate:a", 0.0, 0.3)
	_stamp_tw.tween_callback(func() -> void: _stamp.visible = false)


func _log(text: String, color: Color = Ui.CREAM) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.88), 12, 3, 3, Ui.INK, Vector4(10, 4, 10, 6)))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(Ui.wrap(Ui.label(text, 15, color, 600), 280))
	_feed.add_child(chip)
	Ui.pop_in(chip)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).free()
	var tw := chip.create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(chip, "modulate:a", 0.0, 0.8)
	tw.tween_callback(chip.queue_free)


func _note_show(parts: Array, seconds: float) -> void:
	for c in _note_body.get_children():
		c.queue_free()
	for p: Control in parts:
		if p is Label:
			(p as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note_body.add_child(p)
	_note.visible = true
	Ui.pop_in(_note)
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
	if list.is_empty():
		_reveal_rows.add_child(Ui.wrap(Ui.label("No cup was poisoned this round... or a cake got to it first.", 16, Ui.CREAM), 340))
	for r: Dictionary in list:
		var row := Ui.card(Ui.CREAM if not r["died"] else Color("ffd0dc"))
		var h := Ui.hbox(8)
		row.add_child(h)
		var role := StringName(r.get("role", &""))
		var nm := Ui.label(Session.seat_name(int(r["seat"])) + (" (the POISONER!)" if role == &"poisoner" else ""), 17, Ui.INK, 700)
		nm.custom_minimum_size.x = 150
		h.add_child(nm)
		var icons := Ui.hbox(2)
		icons.custom_minimum_size.x = 130
		for k: int in r["kinds"]:
			icons.add_child(TeaIcon.make(TeaIcon.Kind.INGREDIENT, k, 32))
		h.add_child(icons)
		h.add_child(Ui.label("DEAD" if r["died"] else "SAVED", 16, Color("c0184a") if r["died"] else Color("1f7a4d"), 700))
		_reveal_rows.add_child(row)
	_reveal_rows.add_child(Ui.wrap(Ui.label("Everyone who poured into these cups knows they did. Somebody poured the poison.", 14, Ui.MUTED, 700), 340))
	_reveal.visible = true
	Ui.pop_in(_reveal)
	Sfx.play(&"page", -3.0)


## Who voted for whom, and who got thrown out.
func _show_votes(ev: Dictionary) -> void:
	for c in _reveal_rows.get_children():
		c.queue_free()
	var by_target := {}
	var votes: Dictionary = ev.get("votes", {})
	for voter: int in votes:
		var t: int = votes[voter]
		var arr: Array = by_target.get(t, [])
		arr.append(Session.seat_name(voter))
		by_target[t] = arr
	for t: int in by_target:
		var row := Ui.card(Ui.CREAM if t != int(ev["ejected"]) else Color("ffd0dc"))
		var h := Ui.hbox(8)
		row.add_child(h)
		var nm := Ui.label(("SKIP" if t == -1 else Session.seat_name(t)) + "  x%d" % (by_target[t] as Array).size(), 17, Ui.INK, 800)
		nm.custom_minimum_size.x = 150
		h.add_child(nm)
		h.add_child(Ui.wrap(Ui.label("voted by " + ", ".join(by_target[t]), 14, Color(Ui.INK, 0.75), 700), 200))
		_reveal_rows.add_child(row)
	var ej := int(ev["ejected"])
	if ej < 0:
		_reveal_rows.add_child(Ui.wrap(Ui.label(String(ev.get("reason", "")), 16, Ui.YELLOW, 700), 340))
		stamp("NOBODY OUT", Ui.LILAC, 1.6)
	else:
		var caught := StringName(ev.get("role", &"")) == &"poisoner"
		_log("%s was thrown out of the party. %s" % [Session.seat_name(ej), "They WERE the poisoner!" if caught else "They were innocent."], Ui.PINK if caught else Ui.LILAC)
		stamp("THROWN OUT!", Ui.PINK, 1.4)
	(_reveal.get_child(0).get_child(0) as Label).text = "THE VOTE"
	_reveal.visible = true
	Ui.pop_in(_reveal)
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_callback(func() -> void:
		_reveal.visible = false
		(_reveal.get_child(0).get_child(0) as Label).text = "THE POISONED CUPS")
