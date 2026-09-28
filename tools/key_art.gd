extends Node
## Renders the key art (the boot splash and the loading screen) from the game itself: the
## candlelit parlour at night, guests around the table, the poisoner in front with a glowing
## green cup, and the logo. Writes assets/splash/key_art.png (1920x1080).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan --path . -- --qa --tool=res://tools/key_art.gd
const OUT := "res://assets/splash/key_art.png"


func _ready() -> void:
	Profile.ephemeral = true
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()


func _run() -> void:
	await get_tree().process_frame
	for c in get_parent().get_children():
		if c is MenuBackdrop:
			c.free()
	get_window().size = Vector2i(1920, 1080)
	var w := Node3D.new()
	w.name = "World"
	get_tree().root.add_child(w)
	var rb := RoomBuilder.new()
	rb.night = true
	w.add_child(rb.build(&"parlor", 6))
	var looks := [
		{"hat": &"top_hat", "face": &"monocle", "skin": &"grape"},
		{"hat": &"flower_crown", "face": &"blush", "skin": &"berry"},
		{"hat": &"fez", "face": &"glasses", "skin": &"lemon"},
		{"hat": &"bowler", "face": &"moustache", "skin": &"cream"},
		{"hat": &"party", "face": &"nose", "skin": &"mint"},
		{"hat": &"witch", "face": &"none", "skin": &"matcha"},
	]
	var names := ["Countess Chai", "Lady Marmalade", "Colonel Scone", "Sir Crumpet", "Miss Bergamot", "Madame Lapsang"]
	var gs: Array[Guest] = []
	for i in 6:
		var g := Guest.new()
		w.add_child(g)
		g.transform = rb.seats[i]
		g.setup(i, {"id": 0, "name": names[i], "cos": looks[i]})
		g.chair = rb.chairs[i]
		g.show_tags(false)
		gs.append(g)
		var cup := TeaCup.new()
		w.add_child(cup)
		cup.setup(i, &"skull" if i == 0 else &"rose")
		cup.position = rb.cup_spots[i]
		cup.set_filled(true)
		var pot := Teapot.new()
		w.add_child(pot)
		pot.setup(i, Color("f4f1ea"), Color("2e5f9a"))
		pot.position = rb.pot_spots[i]
	# The poisoner (seat 0, nearest the camera) raises a glowing cup and smirks.
	var poison_cup := TeaCup.new()
	w.add_child(poison_cup)
	poison_cup.setup(9, &"skull")
	poison_cup.set_filled(true)
	poison_cup.position = rb.cup_spots[0] + Vector3(0, 0.3, 0)
	gs[0].raise_cup(poison_cup)
	var glow := OmniLight3D.new()
	glow.light_color = Color("7dff5a")
	glow.light_energy = 1.6
	glow.omni_range = 1.4
	w.add_child(glow)
	gs[2].gesture(&"cheer", 99.0)
	gs[3].gesture(&"think", 99.0)
	gs[4].gesture(&"laugh", 99.0)
	gs[1].gesture(&"plead", 99.0)
	var cam := Camera3D.new()
	cam.fov = 50.0
	w.add_child(cam)
	# From across the table, facing the poisoner (a little left of them, so they sit right of the logo).
	var p0 := rb.seats[0].origin
	var toward := Vector3(p0.x, 0, p0.z).normalized()
	var side := toward.cross(Vector3.UP)
	var eye := -toward * 0.95 + side * 0.9 + Vector3(0, 1.6, 0)
	cam.global_transform = Transform3D(Basis(), eye).looking_at(p0 - side * 0.35 + Vector3(0, 1.12, 0), Vector3.UP)
	cam.current = true
	# The logo.
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var box := Ui.vbox(4)
	layer.add_child(box)
	box.position = Vector2(60, 40)
	var t := Ui.title("TEA PARTY", 150, Ui.YELLOW)
	box.add_child(t)
	var sub := Ui.chip("MURDER AT TEATIME", Ui.PINK, Ui.CREAM, 34)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(sub)
	# Darker along the bottom, where the loading bar and tips sit.
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.02, 0.09, 0.0))
	g.set_color(1, Color(0.05, 0.02, 0.09, 0.8))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.55)
	gt.fill_to = Vector2(0, 1.0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	layer.move_child(shade, 0)
	await get_tree().create_timer(2.5).timeout
	glow.global_position = gs[0].holding().global_position + Vector3(0, 0.25, 0) if gs[0].holding() else rb.cup_spots[0] + Vector3(0, 0.5, 0)
	gs[0]._set_mood(&"sly", 99.0)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_size() != Vector2i(1920, 1080):
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/splash"))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("KEYART OK %s" % img.get_size())
	get_tree().quit()
