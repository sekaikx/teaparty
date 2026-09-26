extends Node
## Screenshots of the menus a match doesn't reach:
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/ui_shots.gd --shots=DIR

var shots := "/tmp/claude-0/ui"


func _ready() -> void:
	Profile.ephemeral = true
	Profile.xp = 700
	Profile.coins = 420
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(shots)
	_run()


func _run() -> void:
	var app := get_parent()
	await get_tree().create_timer(1.5).timeout
	(app.get("_screen") as MainMenu).online_requested.emit()
	await _shot("online", 1.0)
	app.call(&"_close_overlay")
	app.call(&"_open_tutorial")
	await _shot("tutorial_1", 1.0)
	var t := _find(app, Tutorial)
	if t:
		t.set("_page", 1)
		t.call(&"_show")
		await _shot("tutorial_2", 0.8)
	app.call(&"_close_overlay")
	app.call(&"_open_wardrobe")
	await _shot("wardrobe_hats", 2.0)
	var w := _find(app, Wardrobe) as Wardrobe
	if w:
		w.set("_category", &"face")
		w.call(&"_refresh")
		await _shot("wardrobe_faces", 0.8)
		w.set("_category", &"death")
		w.call(&"_refresh")
		w.call(&"_preview_death")
		await _shot("wardrobe_death", 1.8)
	app.call(&"_close_overlay")
	app.call(&"_open_settings")
	await _shot("settings", 1.0)
	app.call(&"_close_overlay")
	Net.solo()
	await _shot("lobby", 1.2)
	# A made-up 6-guest result with a full set of awards.
	var seats: Array = []
	for i in 6:
		seats.append({"name": ["Sir Crumpet", "Duchess Earl", "Countess Chai", "Guest 1", "Colonel Scone", "Lady Marmalade"][i],
			"alive": i == 4, "died_round": i + 1, "kills": i % 3, "team": -1, "role": &"guest"})
	var awards: Array = []
	for spec: Array in [["MASTER POISONER", "2 guests poisoned"], ["SHARPSHOOTER", "4 cake(s) to the face"], ["GUARDIAN ANGEL", "knocked away 3 deadly cup(s)"],
			["BUTTERFINGERS", "spilled 3 cup(s)"], ["CAKE MAGNET", "took 3 cake(s) to the face"], ["FIRST TO FALL", "down in round 1"]]:
		awards.append({"seat": awards.size() % 6, "title": spec[0], "desc": spec[1]})
	var r := ResultsScreen.new()
	app.call(&"_set_screen", r)
	r.show_result({"winners": [4], "seats": seats, "reason": "Colonel Scone is the last guest standing.", "awards": awards,
		"award": {"xp": 45, "coins": 25, "levels": 0, "level": 3, "titles": [], "unlocks": []}}, 3)
	await _shot("results", 1.0)
	get_tree().quit()


func _find(n: Node, type: Variant) -> Node:
	for c in n.get_children():
		if is_instance_of(c, type):
			return c
		var f := _find(c, type)
		if f:
			return f
	return null


func _shot(key: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, key])
