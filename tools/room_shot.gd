extends Node
## A look at a room with guests seated (and at night):
##   xvfb-run -a godot --rendering-driver vulkan --path . -- --qa --tool=res://tools/room_shot.gd --room=greenhouse
func _ready() -> void:
	Profile.ephemeral = true
	var room := &"greenhouse"
	var night := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room = StringName(a.get_slice("=", 1))
		if a == "--night":
			night = true
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	await get_tree().process_frame
	for c in get_parent().get_children():
		if c is MenuBackdrop:
			c.free()
	var w := Node3D.new()
	w.name = "World"
	get_tree().root.add_child(w)
	var rb := RoomBuilder.new()
	rb.night = night
	w.add_child(rb.build(room, 6))
	for i in 6:
		var g := Guest.new()
		w.add_child(g)
		g.transform = rb.seats[i]
		g.setup(i, {"id": 0, "name": Defs.BOT_NAMES[i], "cos": {"skin": Cosmetics.SKINS.keys()[i], "hat": [&"top_hat", &"bowler", &"party", &"flower_crown", &"fez", &"witch"][i]}})
		g.chair = rb.chairs[i]
		var cup := TeaCup.new()
		w.add_child(cup)
		cup.setup(i, &"rose")
		cup.position = rb.cup_spots[i]
		cup.set_filled(true)
	var cam := Camera3D.new()
	cam.fov = 55.0
	w.add_child(cam)
	for view in [[Vector3(4.6, 3.4, 5.2), Vector3(0, 1.0, 0), "a"], [Vector3(0, 1.6, 2.6), Vector3(0, 1.3, -3.0), "b"]]:
		cam.global_transform = Transform3D(Basis(), view[0]).looking_at(view[1], Vector3.UP)
		cam.current = true
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/room_%s_%s.png" % [room, view[2]])
	print("ROOMSHOT ok")
	get_tree().quit()
