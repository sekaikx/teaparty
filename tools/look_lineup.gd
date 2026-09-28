extends Node
## One studio lineup per wardrobe category: every item on its own bean, front on.
##   xvfb-run -a godot --rendering-driver vulkan --path . -- --qa --tool=res://tools/look_lineup.gd [--cat=hat]
var out := "/tmp/claude-0/lineup"


func _ready() -> void:
	Profile.ephemeral = true
	DirAccess.make_dir_recursive_absolute(out)
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cat="):
			only = a.get_slice("=", 1)
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
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	Mats.mesh(w, Mats.box(Vector3(30, 0.2, 20)), Mats.solid(Color("e8d5b0")), Vector3(0, -0.1, 0))
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.fov = 32
	cam.current = true
	var base := {"hat": &"none", "face": &"none", "skin": &"cream", "shape": &"classic", "eyes": &"classic",
		"hair": &"tuft", "dye": &"brown", "collar": &"bowtie", "pattern": &"none", "cup": &"porcelain", "death": &"swoon"}
	var skins := [&"cream", &"mint", &"berry", &"sky", &"lemon", &"grape", &"tangerine", &"lavender"]
	var gs: Array[Guest] = []
	for cat: StringName in Cosmetics.CATEGORIES:
		if cat in [&"cup", &"death"] or (only != "" and String(cat) != only):
			continue
		var ids: Array = Cosmetics.CATEGORIES[cat].keys()
		var n := ids.size()
		var per := mini(n, 5)
		for page in ceili(float(n) / per):
			for g in gs:
				g.queue_free()
			gs.clear()
			var chunk := ids.slice(page * per, (page + 1) * per)
			for i in chunk.size():
				var look := base.duplicate()
				look[String(cat)] = chunk[i]
				if cat != &"skin":
					look["skin"] = skins[i % skins.size()]
				var g := Guest.new()
				w.add_child(g)
				g.position = Vector3((i - (chunk.size() - 1) * 0.5) * 0.95, 0, 0)
				g.setup(i, {"id": 0, "name": "Bean %d" % i, "cos": look})
				g.show_tags(false)
				g.stand()
				gs.append(g)
			var wide := chunk.size() * 0.95
			var close := cat in [&"eyes", &"face", &"hair", &"dye"]
			var y := 1.25 if close else 0.95
			cam.global_transform = Transform3D(Basis(), Vector3(0, y + 0.15, wide * 1.25 + (0.2 if close else 0.9))).looking_at(Vector3(0, y, 0), Vector3.UP)
			await get_tree().create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, cat, page])
			print("LINEUP %s %d: %s" % [cat, page, str(chunk)])
	get_tree().quit()
