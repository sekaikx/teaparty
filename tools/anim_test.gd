extends Node
## Renders guests drinking and dying to PNGs:
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/anim_test.gd
var out := "/tmp/claude-0/anim"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for c in get_parent().get_children():
		if c is MenuBackdrop:
			c.queue_free()
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()
func _run() -> void:
	await get_tree().process_frame
	var world := Node3D.new()
	world.name = "World"
	get_tree().root.add_child(world)
	var rb := RoomBuilder.new()
	world.add_child(rb.build(&"parlor", 4))
	var gs: Array[Guest] = []
	var cups: Array[TeaCup] = []
	for i in 4:
		var g := Guest.new()
		world.add_child(g)
		g.transform = rb.seats[i]
		g.setup(i, {"id": 0, "name": "G%d" % i, "cos": {"hat": [&"top_hat", &"crown", &"fez", &"bonnet"][i], "skin": [&"knight", &"rogue", &"knight_rose", &"rogue_plum"][i], "death": [&"swoon", &"keel", &"stagger", &"confetti"][i]}})
		g.chair = rb.chairs[i]
		g.place_tags(rb.card_spots[i] + Vector3(0, 0.3, 0))
		gs.append(g)
		var c := TeaCup.new()
		world.add_child(c)
		c.setup(i, &"rose")
		c.position = rb.cup_spots[i]
		c.home = c.position
		c.set_filled(true)
		cups.append(c)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(3.2, 2.6, 3.2)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await get_tree().process_frame
	await _shot("0_seated", 0.5)
	for i in 4:
		gs[i].drink(cups[i])
	await _shot("1_standing", 0.9)
	await _shot("2_sip", 0.8)
	await _shot("3_after", 1.2)
	for i in 4:
		gs[i].release_cup(world, rb.cup_spots[i])
		if i % 2 == 0:
			gs[i].die()
		else:
			gs[i].sit_back_down()
	await _shot("4_dying", 0.8)
	await _shot("5_dead", 2.5)
	for i in 4:
		if i % 2 == 0:
			gs[i].become_ghost()
	await _shot("6_ghosts", 1.5)
	get_tree().quit()
func _shot(n: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
