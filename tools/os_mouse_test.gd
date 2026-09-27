extends Node
## Real OS mouse clicks (xdotool) at the window's real resolution: does clicking where the
## teapot is DRAWN pick it up? Catches scaling/DPI mismatches between the screen and the game.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/os_mouse_test.gd
var fails := 0


func _check(what: String, ok: bool) -> void:
	print("OSMOUSE %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _os_click(vp_pos: Vector2, button: int = 1) -> void:
	var win := DisplayServer.window_get_position()
	var wsize := Vector2(DisplayServer.window_get_size())
	var vis := get_viewport().get_visible_rect().size
	var p := Vector2(win) + vp_pos * (wsize / vis)
	OS.execute("xdotool", ["mousemove", str(int(p.x)), str(int(p.y))])
	await get_tree().create_timer(0.2).timeout
	OS.execute("xdotool", ["click", str(button)])
	await get_tree().create_timer(0.35).timeout


func _ready() -> void:
	Profile.ephemeral = true
	Profile.settings["murder_rules_seen"] = true
	await get_tree().create_timer(0.5).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().create_timer(1.0).timeout
	print("OSMOUSE window %s visible %s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])
	Net.solo(5)
	Net.set_rule("pour_time", 60.0)
	Net.start_match()
	while Session.phase != Defs.Phase.POUR:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var table := get_tree().current_scene.get_node("World") as TableView
	var cam := table.camera
	var pot := table.pots[Session.my_seat]
	await _os_click(cam.unproject_position(pot.global_position + Vector3(0, 0.15, 0)))
	_check("real click on the teapot picks it up", table._held == pot)
	var target := (Session.my_seat + 3) % Session.seat_count()
	var cup := table.cup_at_seat(target)
	await _os_click(cam.unproject_position(cup.global_position + Vector3(0, 0.08, 0)))
	await get_tree().create_timer(2.5).timeout
	_check("real click on a cup serves that cup", table.serve_to == target and table.tea_poured)
	# Touchpad style: click a tray card (no drag), then click the cup.
	var hud0: GameHud = null
	for c in get_tree().root.find_children("*", "GameHud", true, false):
		hud0 = c
	var tray: HBoxContainer = hud0.get("_tray")
	var card: TrayCard = null
	for c in tray.get_children():
		if c is TrayCard:
			card = c
			break
	if card:
		await _os_click(card.get_global_rect().get_center())
		await _os_click(cam.unproject_position(cup.global_position + Vector3(0, 0.08, 0)))
		await get_tree().create_timer(0.5).timeout
		_check("click card, click cup pours it", bool(Session.seat_info(Session.my_seat).get("poured", false)))
	# The HUD: a real click on the pause menu's button area (Esc opens it).
	OS.execute("xdotool", ["key", "Escape"])
	await get_tree().create_timer(0.4).timeout
	var hud: GameHud = null
	for c in get_tree().root.find_children("*", "GameHud", true, false):
		hud = c
	var pause: Control = hud.get("_pause")
	_check("Esc opens the pause menu", pause.visible)
	var back: Button = null
	for b in pause.find_children("*", "Button", true, false):
		if (b as Button).text.contains("BACK"):
			back = b
	if back:
		await _os_click(back.get_global_rect().get_center())
		_check("real click on BACK TO THE TABLE closes it", not pause.visible)
	# Right-drag look: the cursor is captured while you look and comes back where it was.
	var before := get_viewport().get_mouse_position()
	OS.execute("xdotool", ["mousedown", "3"])
	await get_tree().create_timer(0.2).timeout
	_check("cursor captured while looking", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	OS.execute("xdotool", ["mousemove_relative", "--", "200", "0"])
	await get_tree().create_timer(0.2).timeout
	OS.execute("xdotool", ["mouseup", "3"])
	await get_tree().create_timer(0.3).timeout
	_check("cursor visible again after looking", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_check("cursor back where it was", get_viewport().get_mouse_position().distance_to(before) < 6.0)
	print("OSMOUSE DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
