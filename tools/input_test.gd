extends Node
## Drives the local seat with real mouse events (not Session calls) to check the clicks work:
## pick up the teapot, pour into the target cup, drag a tray card onto it, play an item on
## the table, ready up. Prints "INPUT OK <step>" / "INPUT FAIL <step>".
##   godot --headless --path . -- --qa --tool=res://tools/input_test.gd

var _step := ""
var _fails := 0


func _ready() -> void:
	Profile.ephemeral = true
	Profile.xp = 2000
	Profile.settings["tutorial_seen"] = true
	_run()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Net.solo()
	Net.set_rule("pour_time", 40.0)
	Net.set_rule("item_turn_time", 30.0)
	Net.set_rule("talk_time", 30.0)
	Net.set_rule("items_enabled", [Defs.Item.SWAP])
	await get_tree().create_timer(0.3).timeout
	Net.start_match()
	while Session.phase != Defs.Phase.POUR:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var table := get_tree().current_scene.get_node("World") as TableView
	var cam := table.camera
	# 1. Click the teapot, then click the target cup.
	var pot := table.pots[Session.my_seat]
	var target := table.pour_target()
	var cup := table.cup_at_seat(target)
	var pp := cam.unproject_position(pot.global_position + Vector3(0, 0.2, 0))
	await _click(pp)
	_check("teapot picked up", table._held == pot)
	await _move(cam.unproject_position(cup.global_position + Vector3(0, 0.1, 0)))
	var cp := cam.unproject_position(cup.global_position + Vector3(0, 0.1, 0))
	await _click(cp)
	await get_tree().create_timer(3.0).timeout
	_check("tea poured", table.tea_poured)
	# 2. Drag the first tray card onto the cup.
	var hud := _find(get_tree().root, GameHud) as GameHud
	var tray: HBoxContainer = hud.get("_tray")
	var card: TrayCard = null
	for c in tray.get_children():
		if c is TrayCard and not (c as TrayCard).is_spike:
			card = c
			break
	_check("tray has cards", card != null)
	if card:
		var from := card.get_global_rect().get_center()
		var to := cam.unproject_position(cup.global_position + Vector3(0, 0.1, 0))
		await _press(from, true)
		await _move(from.lerp(to, 0.5))
		await _move(to)
		await _press(to, false)
		await get_tree().create_timer(0.5).timeout
		_check("card dropped and pour sent", bool(Session.seat_info(Session.my_seat).get("poured", false)))
	# 3. Wait for my item turn, click the swap card then two cups.
	var t := 0.0
	while not Session.is_my_turn() and t < 60.0 and Session.phase != Defs.Phase.TALK:
		await get_tree().process_frame
		t += get_process_delta_time()
	if Session.is_my_turn():
		await get_tree().create_timer(0.3).timeout
		var items: HBoxContainer = hud.get("_items")
		var ic: TrayCard = null
		for c in items.get_children():
			if c is TrayCard:
				ic = c
		_check("item card present", ic != null)
		if ic:
			var before_a: int = int(Session.cup_of(Session.my_seat)["id"])
			await _click(ic.get_global_rect().get_center())
			_check("targeting started", table.targeting >= 0)
			var other := table.pour_target()
			var mp := cam.unproject_position(table.cup_at_seat(Session.my_seat).global_position + Vector3(0, 0.1, 0))
			await _click(mp)
			await _click(cam.unproject_position(table.cup_at_seat(other).global_position + Vector3(0, 0.1, 0)))
			await get_tree().create_timer(0.6).timeout
			_check("swap moved my cup", int(Session.cup_of(Session.my_seat)["id"]) != before_a)
	else:
		print("INPUT SKIP item turn (not reached)")
	# 4. Ready up with the button.
	while Session.phase != Defs.Phase.TALK and Session.running:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	if Session.am_alive():
		var ready_btn: Button = hud.get("_ready")
		await _click(ready_btn.get_global_rect().get_center())
		await get_tree().create_timer(0.4).timeout
		_check("ready button", bool(Session.seat_info(Session.my_seat).get("ready", false)))
	print("INPUT DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("INPUT %s %s" % ["OK" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _press(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _move(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _click(pos: Vector2) -> void:
	await _move(pos)
	await _press(pos, true)
	await _press(pos, false)


func _find(n: Node, type: Variant) -> Node:
	for c in n.get_children():
		if is_instance_of(c, type):
			return c
		var f := _find(c, type)
		if f:
			return f
	return null
