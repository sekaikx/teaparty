extends Node
## Screenshots of the menus that a match doesn't reach:
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
	app.call(&"_open_wardrobe")
	await _shot("wardrobe_hats", 2.5)
	var w := _find(app, Wardrobe) as Wardrobe
	if w:
		w.set("_category", &"death")
		w.call(&"_refresh")
		w.call(&"_preview_death")
		await _shot("wardrobe_death", 1.2)
		w.set("_category", &"title")
		w.call(&"_refresh")
		await _shot("wardrobe_titles", 0.6)
	app.call(&"_close_overlay")
	app.call(&"_open_settings")
	await _shot("settings", 1.0)
	app.call(&"_close_overlay")
	var res := {"winners": [2], "reason": "Lady Marmalade is the last guest standing.", "rounds": 4, "mode": &"classic",
		"seats": [
			{"name": "You", "alive": false, "died_round": 3, "kills": 1, "role": &"guest", "team": -1},
			{"name": "Sir Crumpet", "alive": false, "died_round": 1, "kills": 0, "role": &"guest", "team": -1},
			{"name": "Lady Marmalade", "alive": true, "died_round": -1, "kills": 2, "role": &"guest", "team": -1},
			{"name": "Baron Jam", "alive": false, "died_round": 4, "kills": 1, "role": &"guest", "team": -1},
		],
		"award": {"xp": 100, "coins": 70, "levels": 1, "level": 5, "titles": ["Poisoner"], "unlocks": ["Room: Royal Banquet"]}}
	Session.my_seat = 0
	app.call(&"_show_results", res)
	await _shot("results", 2.5)
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
