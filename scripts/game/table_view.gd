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
## Whose cup you're serving this round (you pick it with the teapot).
var serve_to := -1
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
## Where the cursor was when you started looking around (it's hidden and locked meanwhile).
var _look_from := Vector2.ZERO
var _shake := 0.0
var _drinking: Dictionary = {}
var _cam_base: Transform3D
var _bird_timer := 5.0
## Slow-motion and camera focus on whoever just collapsed.
var _focus := Vector3.INF
var _focus_until := 0
var _arrow: Node3D
var _arrow_target := Vector3.INF
## Lights out (serving): 0 = lamps on .. 1 = dark. Every room light, the ambient light and the
## sky go right down (the same in every renderer); what should still show in the dark stays:
## your own candle, the others' glowing eyes, a glint on each cup rim, and a thin blue moonlight
## so the guests read as silhouettes.
var _dark := 0.0
var _dark_on := false
var _dark_tw: Tween
var _env: Environment
var _env_base := {}
var _light_base: Dictionary = {}
var _my_candle: Node3D
var _my_light: OmniLight3D
var _moon: DirectionalLight3D
var _heart_t := 0.0


func build(roster: Array, rules: Dictionary, seat: int) -> void:
	name = "World"
	my_seat = seat
	layout.night = bool(rules.get("night", false))
	add_child(layout.build(StringName(rules.get("room", &"parlor")), roster.size()))
	for i in roster.size():
		var info: Dictionary = roster[i]
		var g := Guest.new()
		add_child(g)
		g.transform = layout.seats[i]
		g.setup(i, info)
		g.chair = layout.chairs[i]
		g.splashed_table.connect(_on_splash)
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
	_arrow = _make_arrow()
	add_child(_arrow)
	if Net.is_host():
		Session.world_probe = self


# ---------------------------------------------------------------- host hit tests (cakes)

## What a cake landing at `point` hits: {"kind": "cup" | "head" | "miss", "seat"}. Cups win
## ties (they're the small, meaningful target). The thrower can't bonk themselves.
func hit_test(point: Vector3, thrower: int) -> Dictionary:
	var best := {"kind": "miss", "seat": -1}
	var best_d := 0.34
	for id: int in cups:
		var cup: TeaCup = cups[id]
		if cup.is_flung() or not bool(Session.seat_info(cup.seat).get("alive", false)):
			continue
		var d := (cup.global_position + Vector3(0, 0.12, 0)).distance_to(point)
		if d < best_d:
			best_d = d
			best = {"kind": "cup", "seat": cup.seat}
	if best["kind"] == "cup":
		return best
	best_d = 0.42
	for g in guests:
		if g.seat == thrower or not g.alive or g.is_down():
			continue
		var d := g.head_position().distance_to(point)
		if d < best_d:
			best_d = d
			best = {"kind": "head", "seat": g.seat}
	return best


func cup_point(seat: int) -> Vector3:
	var cup := cup_at_seat(seat)
	return cup.global_position + Vector3(0, 0.12, 0) if cup else Vector3.ZERO


func head_point(seat: int) -> Vector3:
	return guests[seat].head_position() if seat >= 0 and seat < guests.size() else Vector3.ZERO


func _throw_origin(g: Guest) -> Vector3:
	if g.is_ghost:
		return g.global_transform * Vector3(0, 2.4, -Guest.SIT_BACK + 0.3)
	return g.head_position() + g.global_transform.basis * Vector3(-0.35, -0.15, 0.35)


## A cake event from the host: fly it, then apply what the host decided.
func _cake(ev: Dictionary) -> void:
	var g := guests[int(ev["seat"])]
	var to: Vector3 = ev["to"]
	var kind := String(ev.get("hit", "miss"))
	var victim := int(ev.get("victim", -1))
	if kind == "head" and victim >= 0:
		to = guests[victim].head_position()
	elif kind == "cup" and victim >= 0:
		to = cup_point(victim)
	if not g.is_ghost:
		g.point_at(to)
	var from := _throw_origin(g)
	var landed := func(c: Cake) -> void:
		var dir := (to - from).normalized()
		match kind:
			"cup":
				var cup := cup_at_seat(victim)
				if cup:
					var holder := guests[victim]
					if holder.holding() == cup:
						holder._release_held(false)
					cup.fling(Vector3(dir.x * 3.0, 3.5, dir.z * 3.0))
				Cake.splat(self, to, c.frosting)
				Sfx.play_at(&"clink", to, 0.0)
				_float_text(to + Vector3(0, 0.4, 0), "SPILLED!", Color("4cc9f0"))
			"head":
				var v := guests[victim]
				v.frost(c.frosting)
				v.knockdown(dir)
				if bool(ev.get("spilled", false)):
					_float_text(v.head_position() + Vector3(0, 0.5, 0), "DROPPED IT!", Color("4cc9f0"))
			_:
				Cake.splat(self, to, c.frosting)
	Cake.throw_from(self, from, to, int(ev["seed"]), landed, bool(ev.get("ghost", false)))


## A short-lived label in the world ("SPILLED!", "POISONED BY ...").
func _float_text(at: Vector3, text: String, color: Color, seconds: float = 1.6, size: int = 44) -> Label3D:
	var l := Label3D.new()
	l.font = Ui.display_font()
	l.font_size = size
	l.fixed_size = true
	l.pixel_size = 0.00085
	l.outline_size = 16
	l.outline_modulate = Color("1d1128")
	l.modulate = color
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 6
	add_child(l)
	l.global_position = at
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y + 0.3, seconds)
	if seconds > 0.0:
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	return l


## "POISONED BY LORD BISCUIT" / "...BY THE LACED POT" / "...BY THE BUTLER" (+ who swapped it in).
static func blame_text(blame: Dictionary) -> String:
	var names: Array[String] = []
	for by: int in blame.get("poisoners", []):
		if by == -1:
			names.append("THE LACED POT")
		elif by == -2:
			names.append("THE BUTLER")
		else:
			names.append(Session.seat_name(by).to_upper())
	var t := "POISONED BY " + (" & ".join(names) if not names.is_empty() else "???")
	var sw := int(blame.get("swapped_by", -1))
	if sw >= 0:
		t += "\n(cup swapped in by %s)" % Session.seat_name(sw)
	return t


var _blame_labels: Array[Label3D] = []


## The coach's bouncing arrow that floats over whatever you should click next.
func _make_arrow() -> Node3D:
	var a := Node3D.new()
	var body := Node3D.new()
	body.name = "Bob"
	a.add_child(body)
	var fill := Mats.glow(Color("ffc93c"), 1.2)
	var ink := Mats.highlight(Color("1d1128"))
	Mats.mesh(body, Mats.cylinder(0.0, 0.16, 0.22, 16), fill, Vector3(0, 0.11, 0), Vector3(180, 0, 0))
	Mats.mesh(body, Mats.cylinder(0.06, 0.06, 0.22, 12), fill, Vector3(0, 0.33, 0))
	var shell := Mats.mesh(body, Mats.cylinder(0.0, 0.19, 0.27, 16), Mats.solid(Color("1d1128")), Vector3(0, 0.11, 0), Vector3(180, 0, 0))
	shell.material_override = ink
	var tw := body.create_tween().set_loops()
	tw.tween_property(body, "position:y", 0.18, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	a.visible = false
	return a


func _update_arrow(delta: float) -> void:
	var target := Vector3.INF
	if can_pour_tea():
		if _held:
			if _hover_seat >= 0 and _hover_seat != my_seat and bool(Session.seat_info(_hover_seat).get("alive", false)):
				var cup := cup_at_seat(_hover_seat)
				if cup:
					target = cup.global_position + Vector3(0, 0.35, 0)
		else:
			target = pots[my_seat].global_position + Vector3(0, 0.38, 0)
	elif can_drop_card():
		var cup := cup_at_seat(pour_target())
		if cup:
			target = cup.global_position + Vector3(0, 0.35, 0)
	_arrow.visible = target != Vector3.INF
	if target != Vector3.INF:
		_arrow.global_position = target if _arrow_target == Vector3.INF else _arrow.global_position.lerp(target, clampf(delta * 10.0, 0, 1))
		_arrow.rotation.y += delta * 2.0
	_arrow_target = target


func _on_splash(g: Guest) -> void:
	# A faceplant into the table sends the nearby (empty) cups flying.
	if not Session.phase in [P.DRINK, P.REVEAL]:
		return
	for id: int in cups:
		var cup: TeaCup = cups[id]
		var d := cup.global_position.distance_to(g.global_position)
		if d < 1.8:
			cup.fling(Vector3(randf_range(-2, 2), randf_range(3.5, 6.0), randf_range(-2, 2)))
	Sfx.play(&"toast", -2.0)


## Mouse-aimed cupcake (F).
func throw_cake() -> void:
	if Session.my_seat < 0 or Session.cakes_left() <= 0:
		return
	var m := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(m)
	var dir := camera.project_ray_normal(m)
	# Aim assist: snap to a cup or face the cursor is roughly over (cups first, they're small).
	var snap := _snap_target(from, dir)
	if snap != Vector3.INF:
		Session.request_throw(snap)
		return
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0, Guest.L_WORLD | Guest.L_HITBOX | Guest.L_RAGDOLL)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	Session.request_throw(hit["position"] if not hit.is_empty() else from + dir * 6.0)


func _snap_target(from: Vector3, dir: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var drinking := Session.phase == P.DRINK
	var pts: Array[Array] = []
	if drinking:
		for id: int in cups:
			var cup: TeaCup = cups[id]
			if not cup.is_flung() and bool(Session.seat_info(cup.seat).get("alive", false)):
				pts.append([cup.global_position + Vector3(0, 0.12, 0), 0.22])
	for g in guests:
		if g.alive and not g.is_down() and g.seat != my_seat:
			pts.append([g.head_position(), 0.3])
	for pr: Array in pts:
		var p: Vector3 = pr[0]
		var along := (p - from).dot(dir)
		if along <= 0.2:
			continue
		var off := (from + dir * along).distance_to(p)
		if off < float(pr[1]) and along < best_d:
			best_d = along
			best = p
	return best


func _exit_tree() -> void:
	Voice.detach_all()
	Engine.time_scale = 1.0


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
			var eye := s.origin + s.basis * Vector3(-1.4, 0, 1.2) + Vector3(0, 2.4, 0)
			t = Transform3D(Basis(), eye).looking_at(s.origin + s.basis * Vector3(0, 0, -1.0) + Vector3(0, 0.3, 0), Vector3.UP)
		elif alive:
			# First person from your bean's eyes (your own head and hat are hidden from you).
			var eye := s.origin + s.basis * Vector3(0, 0, -0.32 - _zoom * 0.6) + Vector3(0, 1.64 + _zoom * 0.5, 0)
			t = Transform3D(Basis(), eye).looking_at(centre, Vector3.UP)
		else:
			# A ghost floats above its chair.
			var eye := s.origin + s.basis * Vector3(0, 0, -0.8 - _zoom * 0.5) + Vector3(0, 2.9 + _zoom * 0.35, 0)
			t = Transform3D(Basis(), eye).looking_at(centre, Vector3.UP)
		if Time.get_ticks_msec() < _focus_until and _focus != Vector3.INF and Time.get_ticks_msec() >= _death_cam_until:
			# Turn to watch whoever is collapsing.
			var look := Transform3D(Basis(), t.origin).looking_at(_focus, Vector3.UP)
			t.basis = t.basis.slerp(look.basis, 0.75)
		t.basis = Basis(Vector3.UP, _orbit) * t.basis * Basis(Vector3.RIGHT, _pitch)
	else:
		t = Transform3D(Basis(), Vector3(0, 7.5, 6.5)).looking_at(Vector3(0, 0.6, 0), Vector3.UP)
	_cam_base = t
	if snap:
		camera.global_transform = t


func shake(amount: float = 0.12) -> void:
	if not bool(Profile.settings.get("shake", true)):
		return
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
	_update_arrow(delta)
	if _dark > 0.0:
		_dark_tick(delta)
	# Who's who: names over heads while people are talking about each other.
	var names_up := Session.phase in [P.TALK, P.VOTE, P.REVEAL, P.EJECT, P.INTRO] and not _dark_on
	for g in guests:
		g.show_head_tag(names_up or g.seat == _hover_seat or Voice.is_speaking(g.peer_id))
	if Input.is_action_just_pressed(&"throw_cake") and not Ui.typing():
		throw_cake()
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
	return serve_to if serve_to >= 0 else int(Session.private.get("target", -1))


func _servable(seat: int) -> bool:
	return seat >= 0 and seat != my_seat and bool(Session.seat_info(seat).get("alive", false))


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
	if item in [Defs.Item.TOAST, Defs.Item.PEEK, Defs.Item.INSPECT] and seat == my_seat:
		return false
	if item == Defs.Item.PROTECT:
		if seat == int(Session.private.get("last_protect", -1)):
			return false
		if seat == my_seat and bool(Session.private.get("self_protected", false)):
			return false
	return not targets.has(seat)


func _update_highlights() -> void:
	var tgt := pour_target()
	for s: int in cups:
		var cup: TeaCup = cups[s]
		var on := false
		if can_pour_tea():
			on = _held != null and _servable(cup.seat) and (cup.seat == _hover_seat or int(Time.get_ticks_msec() / 500) % 2 == 0)
		elif can_drop_card():
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
		if not _dragging_cam:
			_hover_seat = seat_at(mm.position, 0.0)
		if _dragging_cam:
			var sens := float(Profile.settings.get("look_sens", 1.0))
			_orbit = clampf(_orbit - mm.relative.x * 0.004 * sens, -1.2, 1.2)
			_pitch = clampf(_pitch - mm.relative.y * 0.003 * sens, -0.45, 0.35)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_set_looking(mb.pressed)
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


## Right-drag to look: hide and lock the cursor so it can't slide off the window or hit the
## screen edge, then put it back exactly where it was.
func _set_looking(on: bool) -> void:
	if on == _dragging_cam:
		return
	_dragging_cam = on
	if on:
		_look_from = get_viewport().get_mouse_position()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().warp_mouse(_look_from)


func _notification(what: int) -> void:
	# Alt-Tab / losing focus mid-look must never leave the cursor locked.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		if _dragging_cam:
			_dragging_cam = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _left_press(pos: Vector2) -> void:
	_press_pos = pos
	if _held:
		_drop_teapot(pos)
		return
	if can_pour_tea():
		var hit := _ray(pos, 8)
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
	var seat := seat_at(pos, 90.0)
	if _servable(seat):
		serve_to = seat
		var cup := cup_at_seat(seat)
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
	Session.request_pour(card_index, serve_to)
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
		if Session.phase in [P.ITEMS, P.DRINK] and bool(cs[seat]["tea"]) and not bool(cs[seat]["drunk"]) and not cup.is_filled():
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
			for l in _blame_labels:
				if is_instance_valid(l):
					l.queue_free()
			_blame_labels.clear()
			for g in guests:
				g.release_cup(self, layout.cup_spots[g.seat])
			_drinking.clear()
			for id: int in cups:
				(cups[id] as TeaCup).restore()
				(cups[id] as TeaCup).position = layout.cup_spots[(cups[id] as TeaCup).seat]
			tea_poured = false
			card_dropped = false
			spiked = false
			serve_to = -1
			targeting = -1
			for id: int in cups:
				(cups[id] as TeaCup).set_filled(false)
				(cups[id] as TeaCup).show_view([])
			for g in guests:
				if not g.alive and not g.is_ghost:
					g.become_ghost()
			Sfx.play(&"bell", -2.0)
		"pour":
			# In the dark you only HEAR a pour (a soft trickle), never where.
			if int(ev["seat"]) != my_seat:
				Sfx.play(&"plip", -12.0, 0.3)
		"lights_on":
			for id: int in cups:
				var cup: TeaCup = cups[id]
				if bool(Session.seat_info(cup.seat).get("alive", false)):
					cup.set_filled(true)
		"vote_result":
			var ej := int(ev.get("ejected", -1))
			if ej >= 0 and ej < guests.size():
				var g := guests[ej]
				var caught := StringName(ev.get("role", &"")) == &"poisoner"
				_focus = g.head_position()
				_focus_until = Time.get_ticks_msec() + 3500
				var head := g.head_position()
				get_tree().create_timer(0.8).timeout.connect(func() -> void:
					g.die(&"yeet")
					shake(0.2)
					Sfx.play(&"sting", -2.0)
					_blame_labels.append(_float_text(head + Vector3(0, 0.75, 0), "WAS THE POISONER!" if caught else "WAS INNOCENT...",
						Color("ff5d8f") if caught else Color("c3a6ff"), 0.0, 34)))
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
			guests[int(ev["seat"])].point_at(guests[int(ev["target"])].head_position())
			guests[int(ev["seat"])].say("A TOAST TO %s!" % Session.seat_name(int(ev["target"])).to_upper(), 2.0)
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
			guests[int(ev["seat"])].gesture(&"spook")
		"emote":
			var e: Dictionary = Defs.EMOTES[int(ev["emote"])]
			var g := guests[int(ev["seat"])]
			g.say(e["line"], 2.4, Color("3a5a9a") if g.is_ghost else Ui.INK)
			g.gesture(e["clip"])
			Sfx.play_at(e["sound"], g.head_position(), -6.0, 0.15)
		"ready":
			guests[int(ev["seat"])].say("READY!", 1.5, Color("1f7a4d"))
			Sfx.play(&"tick", -6.0)
		"pass":
			guests[int(ev["seat"])].say("pass" if not ev.get("timeout", false) else "zzz...", 1.2)
		"countdown":
			Sfx.play(&"drumroll", -2.0)
			# Everyone stands and raises their cup for the toast (knock them away with cakes!).
			for g in guests:
				if g.alive:
					g.raise_cup(cup_at_seat(g.seat))
		"cake":
			_cake(ev)
		"item_step":
			var g := guests[int(ev["seat"])]
			g.say(String(Defs.ITEMS[int(ev["item"])]["name"]).to_upper() + "!", 1.2, Color("7b2ff7"))
		"locked":
			guests[int(ev["seat"])].say("locked in", 1.0, Color("1f7a4d"))
			Sfx.play(&"tick", -8.0)
		"spike_done", "pour_mine", "auto_pour", "sniff_result", "peek_result", "error", "note", "locked_mine":
			pass


## Guests stand, drink, and the poisoned collapse. `delay` staggers a single toast drink.
func _play_drinks(drinks: Array, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		for d: Dictionary in drinks:
			var g := guests[int(d["seat"])]
			var cup: TeaCup = cups.get(int(d["cup"]))
			if cup and not cup.is_flung():
				_drinking[cup.cup_id] = true
			if bool(d.get("toast", false)) or g.holding() == null:
				g.drink(cup if cup and not cup.is_flung() else null)
			else:
				g.sip())
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void:
		Sfx.play(&"heartbeat", -2.0))
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		var any_death := false
		var n_dead := 0
		for d: Dictionary in drinks:
			var g := guests[int(d["seat"])]
			var cup: TeaCup = cups.get(int(d["cup"]))
			if cup and g.holding() == cup:
				g.release_cup(self, layout.cup_spots[cup.seat])
				cup.home = layout.cup_spots[cup.seat]
			if cup:
				cup.set_filled(false)
				_drinking.erase(cup.cup_id)
			if d["died"]:
				# One at a time, a beat apart: "who's next?" is the clip.
				var beat := 0.75 * n_dead
				n_dead += 1
				any_death = true
				get_tree().create_timer(beat).timeout.connect(func() -> void:
					_focus = g.head_position()
					_focus_until = Time.get_ticks_msec() + 1800
					var head := g.head_position()
					var t := g.die()
					if beat > 0.0:
						shake(0.12)
						Sfx.play(&"sting", -6.0)
					var role := StringName(d.get("role", &""))
					_blame_labels.append(_float_text(head + Vector3(0, 0.75, 0), "POISONED!" + ("\n(they were a POISONER)" if role == &"poisoner" else "\nWHO DID IT?"), Color("ff5d8f"), 0.0, 30))
					if g.seat == my_seat:
						_death_cam_until = Time.get_ticks_msec() + int((t + 1.8) * 1000.0))
			elif g.alive and not g.is_down():
				g.sit_back_down()
		if any_death:
			shake(0.18)
			Sfx.play(&"sting", -2.0)
			_slow_mo()
		else:
			Sfx.play(&"clink", -3.0))
	# Anyone still standing (their cup got knocked away) sits back down.
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		for g in guests:
			if g.alive and not g.is_down() and not g.is_ghost:
				if g.holding():
					g.release_cup(self, layout.cup_spots[g.seat])
				g.sit_back_down())


## A beat of slow motion when someone goes down (for the clips).
func _slow_mo() -> void:
	var tw := get_tree().create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.85)
	tw.tween_callback(func() -> void: Engine.time_scale = 0.35)
	tw.tween_interval(1.1)
	tw.tween_method(func(v: float) -> void: Engine.time_scale = v, 0.35, 1.0, 0.5)


# ---------------------------------------------------------------- lights out

## Lights out while everyone serves, back on (with a flicker) when the pours are done.
func set_lights_out(on: bool) -> void:
	if on == _dark_on:
		return
	_dark_on = on
	_dark_setup()
	if _dark_tw and _dark_tw.is_valid():
		_dark_tw.kill()
	_dark_tw = create_tween()
	if on:
		Sfx.play(&"candle_out", -3.0)
		_blow_candles(true)
		_dark_tw.tween_method(_apply_dark, _dark, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		# The lamps stutter back on.
		_dark_tw.tween_method(_apply_dark, _dark, 0.35, 0.12)
		_dark_tw.tween_method(_apply_dark, 0.35, 0.85, 0.1)
		_dark_tw.tween_method(_apply_dark, 0.85, 0.15, 0.12)
		_dark_tw.tween_method(_apply_dark, 0.15, 0.6, 0.08)
		_dark_tw.tween_method(_apply_dark, 0.6, 0.0, 0.25)
		_dark_tw.tween_callback(func() -> void: _blow_candles(false))
		Sfx.play(&"switch", -4.0)


func is_dark() -> bool:
	return _dark_on


func _dark_setup() -> void:
	if _env == null:
		for n in layout.root.find_children("*", "WorldEnvironment", true, false):
			_env = (n as WorldEnvironment).environment
			_env_base = {"ambient": _env.ambient_light_energy, "bg": _env.background_energy_multiplier}
			break
		for n in layout.root.find_children("*", "Light3D", true, false):
			if not n.has_meta(&"flicker"):
				_light_base[n] = (n as Light3D).light_energy
	if _my_candle == null and my_seat >= 0 and my_seat < layout.pot_spots.size():
		# Your own little chamberstick, next to your teapot: in the dark it's all you can see by.
		_my_candle = Node3D.new()
		_my_candle.name = "MyCandle"
		var spot := layout.pot_spots[my_seat]
		var inward := Vector3(-spot.x, 0, -spot.z).normalized()
		_my_candle.position = spot + inward.cross(Vector3.UP) * 0.32 + Vector3(0, 0, 0)
		add_child(_my_candle)
		Mats.mesh(_my_candle, Mats.cylinder(0.06, 0.075, 0.025, 16), Mats.gold(), Vector3(0, 0.012, 0))
		Mats.mesh(_my_candle, Mats.cylinder(0.022, 0.024, 0.14, 10), Mats.solid(Color("f6efd9"), 0.6), Vector3(0, 0.095, 0))
		var flame := Mats.mesh(_my_candle, Mats.sphere(0.018, 0.055), Mats.glow(Color("ffc56a"), 4.0), Vector3(0, 0.19, 0))
		flame.name = "Flame"
		_my_light = OmniLight3D.new()
		_my_light.light_color = Color("ffb35a")
		_my_light.omni_range = 1.5
		_my_light.omni_attenuation = 2.0
		_my_light.shadow_enabled = true
		_my_light.position = Vector3(0, 0.28, 0)
		_my_candle.add_child(_my_light)
		_my_candle.visible = false
	if _moon == null:
		_moon = DirectionalLight3D.new()
		_moon.name = "Moonlight"
		_moon.light_color = Color("7f9cff")
		_moon.light_energy = 0.0
		_moon.shadow_enabled = false
		_moon.rotation_degrees = Vector3(-35, 150, 0)
		add_child(_moon)


func _apply_dark(k: float) -> void:
	_dark = k
	var dim := lerpf(1.0, 0.03, k)
	if _env:
		_env.ambient_light_energy = float(_env_base["ambient"]) * lerpf(1.0, 0.05, k)
		_env.background_energy_multiplier = float(_env_base["bg"]) * lerpf(1.0, 0.2, k)
	for l: Light3D in _light_base:
		if is_instance_valid(l):
			l.light_energy = float(_light_base[l]) * dim
	layout.light_k = lerpf(1.0, 0.1, k)
	if _my_candle:
		_my_candle.visible = k > 0.02 and Session.am_alive()
		_my_light.light_energy = 0.4 * k
	if _moon:
		_moon.light_energy = 0.05 * k
	for g in guests:
		g.set_eye_glow(k * 1.6 if not g.is_local else 0.0)
	for id: int in cups:
		var cup: TeaCup = cups[id]
		var live := bool(Session.seat_info(cup.seat).get("alive", false)) and cup.seat != my_seat
		cup.set_glint(k * 2.2 if live else 0.0)


## A flickering candle, and a slow heartbeat while it's dark.
func _dark_tick(delta: float) -> void:
	if _my_light and _dark_on:
		_my_light.light_energy = 0.4 * _dark * (0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.019) * sin(Time.get_ticks_msec() * 0.0071))
	if _dark_on and _dark > 0.9:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 1.6
			Sfx.play(&"heartbeat", -16.0)


## Puffs the table candles out (with a wisp of smoke) or lights them again.
func _blow_candles(out: bool) -> void:
	for l in layout.candles:
		if is_instance_valid(l):
			l.visible = not out
	for f in layout.flames:
		if not is_instance_valid(f):
			continue
		f.visible = not out
		if out:
			_smoke(f.global_position)


func _smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 1.6
	p.explosiveness = 0.6
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, 0.05, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.85, 0.85, 0.9, 0.35)
	m.albedo_texture = TeaCup._soft_dot()
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
