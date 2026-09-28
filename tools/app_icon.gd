extends Node
## Renders the app icon (the .exe / window / Steam icon) from the real game
## character: a sly jelly bean in a top hat raising a cup of suspicious tea, on a rounded plum
## tile with an ink outline. Writes assets/icons/icon_*.png and icon.ico (PNG entries).
## (The boot splash / loading screen art comes from tools/key_art.gd.)
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/app_icon.gd
const OUT := "res://assets/icons/"
const SIZE := 1024


func _ready() -> void:
	Profile.ephemeral = true
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()


func _studio(vp: SubViewport) -> Guest:
	var w := Node3D.new()
	vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a3e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0dc")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.shadow_enabled = true
	w.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7dff9a")
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-10, 150, 0)
	w.add_child(rim)
	var rim2 := DirectionalLight3D.new()
	rim2.light_color = Color("ff8fd0")
	rim2.light_energy = 1.0
	rim2.rotation_degrees = Vector3(-15, -150, 0)
	w.add_child(rim2)
	var g := Guest.new()
	w.add_child(g)
	g.setup(0, {"id": 0, "name": "Lady Crumpet", "cos": {"hat": &"top_hat", "face": &"none", "skin": &"berry"}})
	var cup := TeaCup.new()
	w.add_child(cup)
	cup.setup(0, &"rose")
	cup.set_filled(true)
	cup.position = Vector3(-0.3, 1.0, 0.3)
	g.raise_cup(cup)
	var cam := Camera3D.new()
	cam.fov = 26.0
	w.add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(0.62, 1.4, 3.25)).looking_at(Vector3(-0.12, 1.13, -0.1), Vector3.UP)
	cam.current = true
	return g


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var g := _studio(vp)
	await get_tree().create_timer(1.6).timeout
	g._set_mood(&"sly", 99.0)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var bean := vp.get_texture().get_image()
	bean.convert(Image.FORMAT_RGBA8)
	var tile := _tile(bean)
	tile.save_png(ProjectSettings.globalize_path(OUT + "icon_1024.png"))
	var pngs: Array[PackedByteArray] = []
	for s in [16, 24, 32, 48, 64, 128, 256]:
		var im := tile.duplicate() as Image
		im.resize(s, s, Image.INTERPOLATE_LANCZOS)
		im.save_png(ProjectSettings.globalize_path(OUT + "icon_%d.png" % s))
		pngs.append(im.save_png_to_buffer())
	_write_ico(ProjectSettings.globalize_path(OUT + "icon.ico"), pngs, [16, 24, 32, 48, 64, 128, 256])
	print("APPICON OK")
	get_tree().quit()


## The rounded plum tile: a radial glow, the bean, an ink outline and a soft inner highlight.
func _tile(bean: Image) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var r := SIZE * 0.2
	var ink := Color("1d1128")
	var c0 := Color("8a4fd0")
	var c1 := Color("2a1440")
	var glow := Color("7dff9a")
	for y in SIZE:
		for x in SIZE:
			var d := _round_rect_sdf(Vector2(x + 0.5, y + 0.5), r)
			if d > 1.0:
				continue
			var p := Vector2(x, y) / SIZE
			var t := clampf(p.distance_to(Vector2(0.42, 0.36)) / 0.8, 0.0, 1.0)
			var col := c0.lerp(c1, t)
			# A poison-green glow low behind the cup.
			var gl := clampf(1.0 - p.distance_to(Vector2(0.28, 0.62)) / 0.35, 0.0, 1.0)
			col = col.lerp(glow, gl * gl * 0.35)
			var a := clampf(1.0 - d, 0.0, 1.0)
			if d > -SIZE * 0.028:
				col = ink
			img.set_pixel(x, y, Color(col, a))
	# The bean on top, clipped to the tile's inner edge.
	for y in SIZE:
		for x in SIZE:
			var b := bean.get_pixel(x, y)
			if b.a <= 0.0:
				continue
			var d := _round_rect_sdf(Vector2(x + 0.5, y + 0.5), r)
			if d > -SIZE * 0.028:
				continue
			var base := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(base.lerp(b, b.a), base.a))
	return img


func _round_rect_sdf(p: Vector2, r: float) -> float:
	var h := SIZE * 0.5 - 6.0
	var q := (p - Vector2(SIZE, SIZE) * 0.5).abs() - Vector2(h - r, h - r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## A Windows .ico whose entries are PNGs (supported since Vista; Godot's exporter reads it).
func _write_ico(path: String, pngs: Array[PackedByteArray], sizes: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_16(0)
	f.store_16(1)
	f.store_16(pngs.size())
	var offset := 6 + 16 * pngs.size()
	for i in pngs.size():
		var s: int = sizes[i]
		f.store_8(0 if s >= 256 else s)
		f.store_8(0 if s >= 256 else s)
		f.store_8(0)
		f.store_8(0)
		f.store_16(1)
		f.store_16(32)
		f.store_32(pngs[i].size())
		f.store_32(offset)
		offset += pngs[i].size()
	for p in pngs:
		f.store_buffer(p)
	f.close()
