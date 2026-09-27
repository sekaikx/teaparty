extends Node
## Studio renders of the guest rig: front / side / back, standing, a knockdown, the recovery.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/char_closeup.gd
var out := "/tmp/claude-0/closeup"
const NAMES := ["Lady Crumpet", "Sir Scone", "Vicar Treacle", "Duchess Earl", "Baron Jam", "Miss Bergamot", "Auntie Oolong", "Colonel Scone", "Countess Chai"]
var offset := 0
func _ready() -> void:
	Profile.ephemeral = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--offset="):
			offset = int(a.get_slice("=", 1))
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
	get_tree().root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6b5b95")
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.environment.ambient_light_energy = 0.6
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(20, 0.2, 20)
	fs.shape = bs
	floor_body.add_child(fs)
	floor_body.position.y = -0.1
	w.add_child(floor_body)
	Mats.mesh(w, Mats.box(Vector3(20, 0.2, 20)), Mats.solid(Color("e8d5b0")), Vector3(0, -0.1, 0))
	var looks := [
		{"hat": &"top_hat", "face": &"moustache", "skin": &"cream"},
		{"hat": &"none", "face": &"glasses", "skin": &"berry"},
		{"hat": &"party", "face": &"nose", "skin": &"mint"},
	]
	var gs: Array[Guest] = []
	for i in 3:
		var g := Guest.new()
		w.add_child(g)
		g.position = Vector3((i - 1) * 1.3, 0, 0)
		if i == 1:
			g.name = "second"
		g.setup(i, {"id": 0, "name": NAMES[i + offset], "cos": looks[i]})
		g.stand()
		gs.append(g)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.fov = 40
	cam.current = true
	cam.global_transform = Transform3D(Basis(), Vector3(0, 1.3, 5.2)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	await _shot("0_front", 1.2)
	cam.global_transform = Transform3D(Basis(), Vector3(4.5, 1.3, 2.4)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	await _shot("1_three_quarter", 0.2)
	cam.global_transform = Transform3D(Basis(), Vector3(0, 1.5, 1.9)).looking_at(gs[1].head_position(), Vector3.UP)
	await _shot("2_face", 0.2)
	gs[0].gesture(&"cheer"); gs[1].gesture(&"point"); gs[2].gesture(&"plead")
	cam.global_transform = Transform3D(Basis(), Vector3(0, 1.3, 5.2)).looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	await _shot("3_gestures", 0.6)
	gs[1].knockdown(Vector3(0, 0, -1))
	gs[0].die()
	await _shot("4_knock_a", 0.35)
	await _shot("5_knock_b", 0.8)
	await _shot("6_down", 1.2)
	await _shot("7_recovered", 1.8)
	get_tree().quit()
func _shot(n: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
