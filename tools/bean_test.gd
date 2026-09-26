extends Node
## Close-up render of beans: sitting, emotes, drinking, a cake to the face, ragdoll deaths,
## ghosts.  xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/bean_test.gd
var out := "/tmp/claude-0/beans"
func _ready() -> void:
	Profile.ephemeral = true
	DirAccess.make_dir_recursive_absolute(out)
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()
func _run() -> void:
	await get_tree().process_frame
	for c in get_parent().get_children():
		if c is MenuBackdrop:
			c.free()
	var w := Node3D.new()
	w.name = "World"
	get_tree().root.add_child(w)
	var rb := RoomBuilder.new()
	w.add_child(rb.build(&"parlor", 4))
	var gs: Array[Guest] = []
	var cups: Array[TeaCup] = []
	var looks := [
		{"hat": &"top_hat", "face": &"moustache", "skin": &"cream", "death": &"keel"},
		{"hat": &"crown", "face": &"glasses", "skin": &"berry", "death": &"yeet"},
		{"hat": &"party", "face": &"nose", "skin": &"mint", "death": &"spin"},
		{"hat": &"witch", "face": &"shades", "skin": &"grape", "death": &"confetti"},
	]
	for i in 4:
		var g := Guest.new()
		w.add_child(g)
		g.transform = rb.seats[i]
		g.setup(i, {"id": 0, "name": "Bean %d" % i, "cos": looks[i]})
		g.chair = rb.chairs[i]
		g.place_tags(rb.card_spots[i] + Vector3(0, 0.3, 0))
		gs.append(g)
		var c := TeaCup.new()
		w.add_child(c)
		c.setup(i, &"rose")
		c.position = rb.cup_spots[i]
		c.home = c.position
		c.set_filled(true)
		cups.append(c)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(2.6, 2.4, 3.4)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await _shot("0_seated", 1.0)
	gs[1].gesture(&"cheer"); gs[2].gesture(&"point"); gs[3].gesture(&"plead"); gs[0].gesture(&"laugh")
	gs[1].say("CHEERS!"); gs[3].say("PLEASE SPARE ME")
	await _shot("1_emotes", 0.7)
	var from := gs[0].head_position() + Vector3(0, 0, 0.3)
	var to := gs[2].head_position()
	Cake.throw_from(w, from, to, 3, func(c: Cake) -> void:
		gs[2].frost(c.frosting)
		gs[2].knockdown(to - from))
	await _shot("2_cake", 0.3)
	await _shot("3_knocked", 0.9)
	await _shot("3b_knocked", 1.0)
	await _shot("3c_recovering", 1.6)
	await _shot("3d_recovered", 1.0)
	for i in 4:
		gs[i].drink(cups[i])
	await _shot("4_drinking", 1.2)
	await get_tree().create_timer(1.2).timeout
	for i in 4:
		gs[i].release_cup(w, rb.cup_spots[i])
	gs[0].die()
	gs[1].die()
	gs[2].sit_back_down()
	gs[3].die()
	await _shot("5_dying", 0.5)
	await _shot("6_ragdoll", 1.2)
	await _shot("7_down", 2.0)
	cam.global_transform = Transform3D(Basis(), Vector3(0, 4.2, 3.6)).looking_at(Vector3(0, 0.3, 0), Vector3.UP)
	await _shot("8_overhead", 0.3)
	for i in [0, 1, 3]:
		gs[i].become_ghost()
	cam.global_transform = Transform3D(Basis(), Vector3(2.6, 2.4, 3.4)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	await _shot("9_ghosts", 1.5)
	get_tree().quit()
func _shot(n: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
