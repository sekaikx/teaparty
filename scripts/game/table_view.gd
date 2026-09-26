class_name TableView
extends Node3D
## The table: builds the room, seats the guests, lays the cups and teapots, turns Session events
## into animation, and handles the mouse (teapot, ingredient drops, item targets, ghost rattles).
## Must be named "World" in the scene (Sfx.play_at puts 3D sounds under it).

signal prompt_changed

const P := Defs.Phase

var layout := RoomBuilder.new()
var guests: Array[Guest] = []
var cups: Dictionary = {}
var pots: Array[Teapot] = []
var camera: Camera3D
var my_seat := -1

## Local pour progress for this round: tea poured (animation done) / card dropped.
var tea_poured := false
var card_dropped := false
var spiked := false
## Item targeting: index into private items, or -1.
var targeting := -1
var targets: Array[int] = []

var _held: Teapot
var _press_pos := Vector2.ZERO
var _sticky := false
var _hover_seat := -1
var _hover_pot: Teapot
var _orbit := 0.0
var _pitch := 0.0
var _death_cam_until := 0
var _zoom := 0.0
var _dragging_cam := false
var _shake := 0.0
var _drinking: Dictionary = {}
var _cam_base: Transform3D
var _bird_timer := 5.0


func build(roster: Array, rules: Dictionary, seat: int) -> void:
	name = "World"
	my_seat = seat
	add_child(layout.build(StringName(rules.get("room", &"parlor")), roster.size()))
	for i in roster.size():
		var info: Dictionary = roster[i]
		var g := Guest.new()
		add_child(g)
		g.transform = layout.seats[i]
		g.setup(i, info)
		g.chair = layout.chairs[i]
		g.place_tags(to_global(layout.card_spots[i] + Vector3(0, 0.3, 0)))
		guests.append(g)
		if not info.get("bot", false):
			Voice.attach(int(info["id"]), g.head_anchor)
		var cup := TeaCup.new()
		add_child(cup)
		cup.setup(i, StringName(str((info.get("cos", {}) as Dictionary).get("cup", &"porcelain"))))
		cup.seat = i
		cup.position = layout.cup_spots[i]
		cup.home = cup.position
		cup.rotation.y = randf() * TAU
		cups[i] = cup
		var pot := Teapot.new()
		add_child(pot)
		var ce := Cosmetics.entry(&"cup", StringName(str((info.get("cos", {}) as Dictionary).get("cup", &"porcelain"))))
		pot.setup(i, ce.get("body", Color.WHITE), ce.get("rim", Color("2e5f9a")))
		pot.position = layout.pot_spots[i]
		pot.home = pot.position
		pots.append(pot)
	if rules.get("mode", &"classic") == &"teams":
		for g in guests:
			g.set_name_color(Defs.TEAM_COLORS[g.seat % 2].lightened(0.45))
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	_place_camera(true)
	Sfx.music(layout.music)
	Sfx.ambience(layout.ambience)
	Voice.speaking_changed.connect(_on_speaking)
	Session.game_event.connect(_on_event)
	Session.state_changed.connect(_on_state)
	if my_seat >= 0:
		guests[my_seat].set_local(true)


func _exit_tree() -> void:
	Voice.detach_all()


func _on_speaking(peer: int, on: bool) -> void:
	for g in guests:
		if g.peer_id == peer:
			g.set_speaking(on)


# ---------------------------------------------------------------- camera

func _place_camera(snap: bool) -> void:
	var t: Transform3D
	var centre := Vector3(0, RoomBuilder.TABLE_Y + 0.05, 0)
	camera.cull_mask = 0xFFFFF & ~Guest.LOCAL_LAYER
	if my_seat >= 0 and my_seat < layout.seats.size():
		var s := layout.seats[my_seat]
		var alive := Session.am_alive() or Session.public.is_empty()
		if Time.get_ticks_msec() < _death_cam_until:
			# Watch your own collapse from across your shoulder.
			camera.cull_mask = 0xFFFFF
			var eye := s.origin + s.basis * Vector3(-1.6, 0, 1.7) + Vector3(0, 2.3, 0)
			t = Transform3D(Basis(), eye).looking_at(s.origin + s.basis * Vector3(0, 0, -0.4) + Vector3(0, 0.7, 0), Vector3.UP)
		elif alive:
			# First person from your seat (your head and hat are hidden from you).
			var eye := s.origin + s.basis * Vector3(0, 0, -0.55 - _zoom * 0.5) + Vector3(0, 2.2 + _zoom * 0.35, 0)
			t = Transform3D(Basis(), eye).looking_at(centre, Vector3.UP)
		else:
			# A ghost floats above its chair.
			var eye := s.origin + s.basis * Vector3(0, 0, -1.0 - _zoom * 0.5) + Vector3(0, 3.5 + _zoom * 0.35, 0)
			t = Transform3D(Basis(), eye).looking_at(centre, Vector3.UP)
		t.basis = Basis(Vector3.UP, _orbit) * t.basis * Basis(Vector3.RIGHT, _pitch)
	else:
		t = Transform3D(Basis(), Vector3(0, 7.5, 6.5)).looking_at(Vector3(0, 0.6, 0), Vector3.UP)
	_cam_base = t
	if snap:
		camera.global_transform = t


func shake(amount: float = 0.12) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_place_camera(false)
	var t := camera.global_transform.interpolate_with(_cam_base, clampf(delta * 5.0, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 0.35)
		t.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.2
	camera.global_transform = t
	if _held:
		var p := _table_point(get_viewport().get_mouse_position())
		if p != Vector3.INF:
			_held.follow(to_local(p), delta)
	_update_highlights()
	if layout.outdoor:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(4.0, 11.0)
			Sfx.play_at([&"bird_1", &"bird_2", &"bird_3"][randi() % 3], Vector3(randf_range(-9, 9), 5, randf_range(-9, 9)), -10.0)


# ---------------------------------------------------------------- what the player can do now

func can_pour_tea() -> bool:
	return Session.phase == P.POUR and Session.am_alive() and not tea_poured and not _poured_server()


func can_drop_card() -> bool:
	return Session.phase == P.POUR and Session.am_alive() and tea_poured and not card_dropped and not _poured_server()


func _poured_server() -> bool:
	return bool(Session.seat_info(my_seat).get("poured", false))


func can_rattle() -> bool:
	return not Session.am_alive() and my_seat >= 0 and Session.phase in [P.POUR, P.ITEMS, P.TALK] \
		and int(Session.seat_info(my_seat).get("rattles", 0)) > 0


func pour_target() -> int:
	return int(Session.private.get("target", -1))


func begin_targeting(item_index: int) -> void:
	targeting = item_index
	targets.clear()
	prompt_changed.emit()


func cancel_targeting() -> void:
	targeting = -1
	targets.clear()
	prompt_changed.emit()


func targeting_item() -> int:
	var items: Array = Session.private.get("items", [])
	return int(items[targeting]) if targeting >= 0 and targeting < items.size() else -1


func _valid_target(seat: int) -> bool:
	if not bool(Session.seat_info(seat).get("alive", false)):
		return false
	var item := targeting_item()
	if item < 0:
		return false
	if item in [Defs.Item.TOAST, Defs.Item.PEEK] and seat == my_seat:
		return false
	return not targets.has(seat)


func _update_highlights() -> void:
	var tgt := pour_target()
	for s: int in cups:
		var cup: TeaCup = cups[s]
		var on := false
		if can_pour_tea() or can_drop_card():
			on = cup.seat == tgt
		elif targeting >= 0:
			var item := targeting_item()
			on = Defs.ITEMS.get(item, {}).get("target", &"") == &"cup" and (cup.seat == _hover_seat and _valid_target(cup.seat) or targets.has(cup.seat))
		elif can_rattle():
			on = cup.seat == _hover_seat and bool(Session.seat_info(cup.seat).get("alive", false))
		cup.set_highlight(on)
	for p in pots:
		p.set_highlight(p.seat == my_seat and can_pour_tea() and (_held == p or int(Time.get_ticks_msec() / 450) % 2 == 0))
	for g in guests:
		var on := false
		if targeting >= 0 and Defs.ITEMS.get(targeting_item(), {}).get("target", &"") == &"guest":
			on = (g.seat == _hover_seat and _valid_target(g.seat)) or targets.has(g.seat)
		g.highlight(on)


# ---------------------------------------------------------------- picking

func _ray(screen: Vector2, mask: int) -> Dictionary:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, mask)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	return get_world_3d().direct_space_state.intersect_ray(q)


func _table_point(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, RoomBuilder.TABLE_Y).intersects_ray(from, dir)
	return hit if hit != null else Vector3.INF


## The seat under the mouse: its cup or its guest. Falls back to the nearest cup on screen.
func seat_at(screen: Vector2, fallback_px: float = 60.0) -> int:
	var hit := _ray(screen, 2 | 4)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col.has_meta(&"cup"):
			return (col.get_meta(&"cup") as TeaCup).seat
		if col.has_meta(&"guest"):
			return (col.get_meta(&"guest") as Guest).seat
	var best := -1
	var best_d := fallback_px
	for s: int in cups:
		var cup: TeaCup = cups[s]
		if camera.is_position_behind(cup.global_position):
			continue
		var d := camera.unproject_position(cup.global_position + Vector3(0, 0.12, 0)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = cup.seat
	return best


func cup_at_seat(seat: int) -> TeaCup:
	for id: int in cups:
		if (cups[id] as TeaCup).seat == seat:
			return cups[id]
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_hover_seat = seat_at(mm.position, 0.0)
		if _dragging_cam:
			_orbit = clampf(_orbit - mm.relative.x * 0.004, -1.2, 1.2)
			_pitch = clampf(_pitch - mm.relative.y * 0.003, -0.45, 0.35)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_dragging_cam = mb.pressed
				if mb.pressed and targeting >= 0:
					cancel_targeting()
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom - 0.2, -0.3, 1.6)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom + 0.2, -0.3, 1.6)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_left_press(mb.position)
				else:
					_left_release(mb.position)
	elif event.is_action_pressed(&"pause") and targeting >= 0:
		cancel_targeting()
		get_viewport().set_input_as_handled()


func _left_press(pos: Vector2) -> void:
	_press_pos = pos
	if _held:
		_drop_teapot(pos)
		return
	if can_pour_tea():
		var hit := _ray(pos, 2)
		if not hit.is_empty() and (hit["collider"] as Object).has_meta(&"teapot"):
			var pot: Teapot = (hit["collider"] as Object).get_meta(&"teapot")
			if pot.seat == my_seat and not pot.busy:
				_held = pot
				_sticky = false
				Sfx.play(&"card", -4.0)
				prompt_changed.emit()
				return
	var seat := seat_at(pos, 0.0)
	if targeting >= 0 and seat >= 0 and _valid_target(seat):
		targets.append(seat)
		Sfx.play(&"tick", -4.0)
		var need: int = Defs.ITEMS[targeting_item()]["targets"]
		if targets.size() >= need:
			Session.request_item(targeting, targets.duplicate())
			targeting = -1
			targets.clear()
		prompt_changed.emit()
		return
	if can_rattle() and seat >= 0 and bool(Session.seat_info(seat).get("alive", false)):
		Session.request_rattle(seat)


func _left_release(pos: Vector2) -> void:
	if _held == null:
		return
	if pos.distance_to(_press_pos) < 8.0 and not _sticky:
		_sticky = true   # click-click: keep holding until the next click
		return
	_drop_teapot(pos)


func _drop_teapot(pos: Vector2) -> void:
	var pot := _held
	_held = null
	var tgt := pour_target()
	var seat := seat_at(pos, 90.0)
	if seat == tgt and tgt >= 0:
		var cup := cup_at_seat(tgt)
		pot.pour_into(cup.position, func() -> void:
			cup.set_filled(true)
			tea_poured = true
			prompt_changed.emit())
	else:
		pot.put_back()
		prompt_changed.emit()


## The HUD calls this when a tray card is released over the table. Returns true if it was used.
func drop_card(screen: Vector2, card_index: int, spike: bool) -> bool:
	var seat := seat_at(screen, 80.0)
	if seat < 0:
		return false
	var cup := cup_at_seat(seat)
	if spike:
		if Session.phase != P.POUR or spiked or seat == my_seat or not bool(Session.seat_info(seat).get("alive", false)):
			return false
		Session.request_spike(seat)
		spiked = true
		cup.splash(Color("3a1a3a"))
		Sfx.play_at(&"plip", cup.global_position)
		prompt_changed.emit()
		return true
	if not can_drop_card() or seat != pour_target():
		return false
	var hand: Array = Session.private.get("hand", [])
	if card_index < 0 or card_index >= hand.size():
		return false
	var k: int = hand[card_index]
	Session.request_pour(card_index)
	card_dropped = true
	cup.splash(Defs.INGREDIENTS[k]["color"])
	Sfx.play_at(&"sugar" if k == Defs.Ingredient.SUGAR else &"plip", cup.global_position)
	prompt_changed.emit()
	return true


# ---------------------------------------------------------------- state and events

func _on_state() -> void:
	var cs: Array = Session.public.get("cups", [])
	for seat in cs.size():
		var id := int(cs[seat]["id"])
		if not cups.has(id):
			continue
		var cup: TeaCup = cups[id]
		cup.seat = seat
		var spot := layout.cup_spots[seat]
		if not _drinking.has(id) and cup.home.distance_to(spot) > 0.01:
			cup.move_home(spot)
		if Session.phase in [P.ITEMS, P.TALK] and bool(cs[seat]["tea"]) and not bool(cs[seat]["drunk"]) and not cup.is_filled():
			cup.set_filled(true)
	# Anyone dead outside the drinking moments is a ghost by now.
	if Session.phase in [P.DEAL, P.POUR, P.ITEMS, P.TALK]:
		for g in guests:
			if not bool(Session.seat_info(g.seat).get("alive", true)) and not g.is_ghost:
				g.become_ghost()
	# What a ghost sees.
	var view: Array = Session.private.get("ghost_view", [])
	for seat in view.size():
		var cup := cup_at_seat(seat)
		if cup and Session.phase in [P.POUR, P.ITEMS, P.TALK, P.DRINK]:
			cup.show_view(view[seat] if bool(Session.seat_info(seat).get("alive", false)) else [])
	if _poured_server():
		tea_poured = true
		card_dropped = true
	prompt_changed.emit()


func _on_event(ev: Dictionary) -> void:
	match String(ev.get("type", "")):
		"round":
			tea_poured = false
			card_dropped = false
			spiked = false
			targeting = -1
			for id: int in cups:
				(cups[id] as TeaCup).set_filled(false)
				(cups[id] as TeaCup).show_view([])
			for g in guests:
				if not g.alive and not g.is_ghost:
					g.become_ghost()
			Sfx.play(&"bell", -2.0)
		"pour":
			var s: int = ev["seat"]
			var t: int = ev["target"]
			var cup := cup_at_seat(t)
			if s == my_seat and tea_poured:
				pass
			elif cup and s < pots.size():
				pots[s].pour_into(cup.position, func() -> void:
					cup.set_filled(true)
					cup.splash())
		"spike_sound":
			Sfx.play(&"plip", -8.0, 0.2)
		"swap":
			var a := cup_at_seat(int(ev["a"]))
			var b := cup_at_seat(int(ev["b"]))
			guests[int(ev["seat"])].gesture(&"Interact")
			Sfx.play(&"slide")
			if a and b:
				var pa := layout.cup_spots[int(ev["b"])]
				var pb := layout.cup_spots[int(ev["a"])]
				a.seat = int(ev["b"])
				b.seat = int(ev["a"])
				a.move_home(pa)
				b.move_home(pb)
		"sniff":
			guests[int(ev["seat"])].gesture(&"Interact")
			var cup := cup_at_seat(int(ev["target"]))
			if cup:
				Sfx.play_at(&"sniff", cup.global_position)
		"peek":
			guests[int(ev["seat"])].gesture(&"ual/Idle_FoldArms")
			guests[int(ev["seat"])].say("*peeks*", 1.4)
			Sfx.play(&"page", -4.0)
		"toast":
			guests[int(ev["seat"])].gesture(&"Cheer")
			guests[int(ev["seat"])].say("A toast to %s!" % Session.seat_name(int(ev["target"])), 2.0)
			Sfx.play(&"toast")
		"drink":
			_play_drinks([ev], 0.6)
		"drink_all":
			var arr: Array = ev["drinks"]
			_play_drinks(arr, 0.0)
		"reveal":
			var list: Array = ev["cups"]
			var tw := create_tween()
			tw.tween_interval(3.2)
			tw.tween_callback(func() -> void:
				for r: Dictionary in list:
					var cup := cup_at_seat(int(r["seat"]))
					if cup and not r["toast"]:
						cup.show_view(r["kinds"]))
		"rattle":
			var cup := cup_at_seat(int(ev["target"]))
			if cup:
				cup.rattle()
			guests[int(ev["seat"])].gesture(&"Spellcast_Shoot")
		"emote":
			var e: Dictionary = Defs.EMOTES[int(ev["emote"])]
			var g := guests[int(ev["seat"])]
			g.say(e["line"], 2.4, Color(0.75, 0.88, 1.0) if g.is_ghost else Color("fff4d8"))
			g.gesture(e["clip"])
			Sfx.play_at(e["sound"], g.head_position(), -6.0, 0.15)
		"ready":
			guests[int(ev["seat"])].say("Ready!", 1.5, Color("b8e08a"))
			Sfx.play(&"tick", -6.0)
		"pass":
			guests[int(ev["seat"])].say("Pass." if not ev.get("timeout", false) else "...", 1.2)
		"countdown":
			Sfx.play(&"drumroll", -2.0)
		"spike_done", "pour_mine", "auto_pour", "sniff_result", "peek_result", "error", "note":
			pass


## Guests stand, drink, and the poisoned collapse. `delay` staggers a single toast drink.
func _play_drinks(drinks: Array, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		for d: Dictionary in drinks:
			var g := guests[int(d["seat"])]
			var cup: TeaCup = cups.get(int(d["cup"]))
			if cup:
				_drinking[cup.cup_id] = true
			g.drink(cup))
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void:
		Sfx.play(&"heartbeat", -2.0))
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void:
		var any_death := false
		for d: Dictionary in drinks:
			var g := guests[int(d["seat"])]
			var cup: TeaCup = cups.get(int(d["cup"]))
			if cup:
				g.release_cup(self, layout.cup_spots[cup.seat])
				cup.home = layout.cup_spots[cup.seat]
				cup.set_filled(false)
				_drinking.erase(cup.cup_id)
			if d["died"]:
				any_death = true
				var t := g.die()
				if g.seat == my_seat:
					_death_cam_until = Time.get_ticks_msec() + int((t + 1.6) * 1000.0)
			else:
				g.sit_back_down()
		if any_death:
			shake(0.18)
			Sfx.play(&"sting", -2.0)
		else:
			Sfx.play(&"clink", -3.0))
