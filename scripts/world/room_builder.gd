class_name RoomBuilder
extends RefCounted
## Builds a room around an elliptical table and returns where everything goes.
## Rooms: the Parlour (round table, fireplace), the Garden Party (lawn, hedges, bunting) and the
## Royal Banquet (long table for eight, candles). Furniture, garden and village models come
## from Woods (KayKit Furniture Bits / Medieval Hexagon, Quaternius Stylized Nature, all CC0).

const TABLE_Y := 0.8
const FURN := "res://assets/models/furniture/"
const GARDEN := "res://assets/models/garden/"
const VILLAGE := "res://assets/models/village/"

## Filled by build().
var root: Node3D
var seats: Array[Transform3D] = []
var cup_spots: Array[Vector3] = []
var pot_spots: Array[Vector3] = []
var table_radii := Vector2(1.45, 1.45)
var music := &"evening"
var ambience := &""
var candles: Array[OmniLight3D] = []
var chairs: Array[Node3D] = []
## Where each guest's place card stands on the table.
var card_spots: Array[Vector3] = []
var outdoor := false


func build(room: StringName, count: int) -> Node3D:
	root = Node3D.new()
	root.name = "Room"
	var cloth := Color("f3ecdc")
	var trim := Color("b2453a")
	match room:
		&"garden":
			table_radii = Vector2(2.2, 1.35) if count > 4 else Vector2(1.8, 1.25)
			cloth = Color("fbf8f0")
			trim = Color("7fb0d8")
			outdoor = true
			music = &"waltz"
			_garden()
		&"banquet":
			table_radii = Vector2(3.1, 1.45) if count > 6 else Vector2(2.6, 1.4)
			cloth = Color("7a1d2c")
			trim = Color("d9a531")
			music = &"tavern"
			ambience = &"murmur"
			_banquet()
		_:
			table_radii = Vector2(1.45, 1.45) if count <= 6 else Vector2(1.9, 1.6)
			music = &"evening"
			ambience = &"fire"
			_parlor()
	_table(cloth, trim)
	_place_seats(room, count)
	return root


# ---------------------------------------------------------------- seats and table

func _place_seats(room: StringName, count: int) -> void:
	seats.clear()
	cup_spots.clear()
	pot_spots.clear()
	chairs.clear()
	card_spots.clear()
	var angles: Array[float] = []
	if room == &"banquet" and count == 8:
		for a in [0.0, 42.0, 90.0, 138.0, 180.0, 222.0, 270.0, 318.0]:
			angles.append(deg_to_rad(a))
	else:
		for i in count:
			angles.append(TAU * i / count + PI / 2.0)
	var chair := _load(FURN + "chair_A_wood.gltf")
	for a in angles:
		var edge := Vector3(cos(a) * table_radii.x, 0, sin(a) * table_radii.y)
		var out := Vector3(cos(a) / table_radii.x, 0, sin(a) / table_radii.y).normalized()   # ellipse normal
		var pos := edge + out * 0.32
		var basis := Basis.looking_at(out, Vector3.UP)   # -Z outwards, so +Z (the guest's face) looks at the table
		var xf := Transform3D(basis, pos)
		seats.append(xf)
		cup_spots.append(Vector3(edge.x, TABLE_Y, edge.z) - out * 0.42 + Vector3(0, 0.02, 0))
		pot_spots.append(Vector3(edge.x, TABLE_Y, edge.z) - out * 0.55 + basis * Vector3(-0.55, 0, 0) + Vector3(0, 0.02, 0))
		card_spots.append(Vector3(edge.x, TABLE_Y, edge.z) - out * 0.16 + basis * Vector3(0.42, 0, 0))
		_place_card(Vector3(edge.x, TABLE_Y, edge.z) - out * 0.16 + basis * Vector3(0.42, 0, 0), basis)
		if chair:
			var c := chair.instantiate() as Node3D
			c.transform = xf * Transform3D(Basis(), Vector3(0, 0, -Guest.SIT_BACK + 0.05))
			root.add_child(c)
			chairs.append(c)
		else:
			chairs.append(null)


## A folded paper place card on the table (the guest's name floats over it).
func _place_card(pos: Vector3, basis: Basis) -> void:
	var card := Node3D.new()
	card.position = pos
	card.basis = basis
	root.add_child(card)
	var paper := Mats.solid(Color("f6eedb"), 0.9)
	Mats.mesh(card, Mats.box(Vector3(0.3, 0.14, 0.006)), paper, Vector3(0, 0.06, 0.03), Vector3(-25, 0, 0))
	Mats.mesh(card, Mats.box(Vector3(0.3, 0.14, 0.006)), paper, Vector3(0, 0.06, -0.03), Vector3(25, 0, 0))
	Mats.mesh(card, Mats.box(Vector3(0.26, 0.004, 0.006)), Mats.gold(), Vector3(0, 0.02, 0.058), Vector3(-25, 0, 0))


func _table(cloth: Color, trim: Color) -> void:
	var t := Node3D.new()
	t.name = "Table"
	root.add_child(t)
	var sx := table_radii.x
	var sz := table_radii.y
	# Cloth top + skirt (hides the legs), a scalloped trim and a lace runner.
	Mats.mesh(t, Mats.cylinder(1.0, 1.0, 0.05, 48), Mats.cloth(cloth), Vector3(0, TABLE_Y - 0.025, 0), Vector3.ZERO, Vector3(sx + 0.08, 1, sz + 0.08))
	Mats.mesh(t, Mats.cylinder(1.0, 1.05, TABLE_Y - 0.05, 48), Mats.cloth(cloth.darkened(0.08)), Vector3(0, (TABLE_Y - 0.05) * 0.5, 0), Vector3.ZERO, Vector3(sx + 0.08, 1, sz + 0.08))
	Mats.mesh(t, Mats.cylinder(1.0, 1.0, 0.06, 48), Mats.cloth(trim), Vector3(0, TABLE_Y - 0.09, 0), Vector3.ZERO, Vector3(sx + 0.1, 1, sz + 0.1))
	Mats.mesh(t, Mats.cylinder(1.0, 1.0, 0.01, 40), Mats.cloth(Color(1, 1, 1).lerp(cloth, 0.3)), Vector3(0, TABLE_Y + 0.006, 0), Vector3.ZERO, Vector3(sx * 0.45, 1, sz * 0.45))
	# Centrepiece: a cake stand with little cakes, and candles.
	var stand := Node3D.new()
	t.add_child(stand)
	stand.position = Vector3(0, TABLE_Y, 0)
	var china := Mats.porcelain(Color("f7f3ea"))
	Mats.mesh(stand, Mats.cylinder(0.05, 0.08, 0.5, 12), Mats.gold(), Vector3(0, 0.25, 0))
	for tier in 3:
		var r := 0.38 - tier * 0.1
		var y := 0.08 + tier * 0.2
		Mats.mesh(stand, Mats.cylinder(r, r * 0.9, 0.025, 24), china, Vector3(0, y, 0))
		var cakes := 6 - tier * 2
		for k in cakes:
			var a := TAU * k / cakes + tier
			var c: Color = [Color("f28aa0"), Color("f7d154"), Color("9fd08a"), Color("c9a07a")][(k + tier) % 4]
			Mats.mesh(stand, Mats.cylinder(0.05, 0.055, 0.05, 10), Mats.solid(c, 0.7), Vector3(cos(a) * r * 0.65, y + 0.04, sin(a) * r * 0.65))
			Mats.mesh(stand, Mats.sphere(0.02), Mats.solid(Color("c0303a"), 0.4), Vector3(cos(a) * r * 0.65, y + 0.08, sin(a) * r * 0.65))
	var n_candles := 2 if sx < 2.0 else 4
	for i in n_candles:
		var x := (-1.0 if i % 2 == 0 else 1.0) * (0.75 + 0.9 * (i / 2)) * (sx / 1.45 if sx > 1.6 else 1.0)
		if sx < 1.6:
			x = (-1.0 if i % 2 == 0 else 1.0) * 0.62
		_candle(t, Vector3(x, TABLE_Y, 0))


func _candle(parent: Node3D, pos: Vector3) -> void:
	var c := Node3D.new()
	c.position = pos
	parent.add_child(c)
	Mats.mesh(c, Mats.cylinder(0.07, 0.09, 0.04, 16), Mats.gold(), Vector3(0, 0.02, 0))
	Mats.mesh(c, Mats.cylinder(0.03, 0.03, 0.26, 10), Mats.solid(Color("f6efd9"), 0.6), Vector3(0, 0.17, 0))
	var flame := Mats.mesh(c, Mats.sphere(0.022, 0.07), Mats.glow(Color("ffc56a"), 4.0), Vector3(0, 0.33, 0))
	var tw := flame.create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector3(0.85, 1.2, 0.85), 0.21)
	tw.tween_property(flame, "scale", Vector3(1.05, 0.9, 1.05), 0.17)
	var light := OmniLight3D.new()
	light.light_color = Color("ffb35c")
	light.light_energy = 0.9
	light.omni_range = 3.2
	light.position = Vector3(0, 0.4, 0)
	light.shadow_enabled = false
	c.add_child(light)
	candles.append(light)


# ---------------------------------------------------------------- rooms

func _environment(bg: Color, ambient: Color, ambient_energy: float, sky: bool) -> void:
	var env := Environment.new()
	if sky:
		var mat := ProceduralSkyMaterial.new()
		mat.sky_top_color = Color("6fa4d8")
		mat.sky_horizon_color = Color("d9e6ef")
		mat.ground_horizon_color = Color("a9b890")
		mat.ground_bottom_color = Color("4a5a3a")
		mat.sun_angle_max = 30.0
		var s := Sky.new()
		s.sky_material = mat
		env.background_mode = Environment.BG_SKY
		env.sky = s
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


func _parlor() -> void:
	_environment(Color("1a120c"), Color("6b4a33"), 0.55, false)
	var floor_mat := Mats.solid(Color("5a3a24"), 0.7)
	Mats.mesh(root, Mats.box(Vector3(14, 0.1, 14)), floor_mat, Vector3(0, -0.05, 0))
	# Floorboards: thin darker strips.
	for i in 14:
		Mats.mesh(root, Mats.box(Vector3(0.02, 0.005, 14)), Mats.solid(Color("3e2717"), 0.8), Vector3(-7 + i, 0.001, 0))
	var rug := _load(FURN + "rug_rectangle_stripes_A.gltf")
	if rug:
		var r := rug.instantiate() as Node3D
		r.scale = Vector3(2.0, 1, 2.6)
		root.add_child(r)
	var paper := Mats.solid(Color("3d5a48"), 0.9)
	var wainscot := Mats.solid(Color("4a2e1c"), 0.6)
	var rail := Mats.solid(Color("c9a26b"), 0.4, 0.3)
	for side in 4:
		var w := Node3D.new()
		w.rotation.y = side * PI / 2.0
		root.add_child(w)
		Mats.mesh(w, Mats.box(Vector3(14, 5, 0.2)), paper, Vector3(0, 2.5, -7))
		Mats.mesh(w, Mats.box(Vector3(14, 1.3, 0.24)), wainscot, Vector3(0, 0.65, -6.98))
		Mats.mesh(w, Mats.box(Vector3(14, 0.08, 0.3)), rail, Vector3(0, 1.32, -6.95))
		# Wallpaper stripes.
		for k in 20:
			Mats.mesh(w, Mats.box(Vector3(0.08, 3.6, 0.01)), Mats.solid(Color("4c6b57"), 0.9), Vector3(-6.6 + k * 0.7, 3.2, -6.89))
	Mats.mesh(root, Mats.box(Vector3(14, 0.2, 14)), Mats.solid(Color("2a1c12"), 0.9), Vector3(0, 5.0, 0))
	# Fireplace on the north wall.
	var fp := Node3D.new()
	fp.position = Vector3(0, 0, -6.6)
	root.add_child(fp)
	var stone := Mats.solid(Color("8a7f74"), 0.9)
	Mats.mesh(fp, Mats.box(Vector3(3.2, 2.4, 0.8)), stone, Vector3(0, 1.2, 0))
	Mats.mesh(fp, Mats.box(Vector3(3.6, 0.2, 1.0)), Mats.solid(Color("4a2e1c"), 0.5), Vector3(0, 2.45, 0.05))
	Mats.mesh(fp, Mats.box(Vector3(1.8, 1.3, 0.1)), Mats.solid(Color("140c08"), 1.0), Vector3(0, 0.75, 0.36))
	for k in 3:
		Mats.mesh(fp, Mats.cylinder(0.08, 0.08, 1.1, 8), Mats.solid(Color("3a2414"), 0.9), Vector3(0, 0.2 + k * 0.08, 0.3), Vector3(0, k * 35, 90))
	var embers := Mats.mesh(fp, Mats.sphere(0.35, 0.4), Mats.glow(Color("ff7a2a"), 3.0), Vector3(0, 0.35, 0.3), Vector3.ZERO, Vector3(1.4, 0.8, 0.6))
	var fire := OmniLight3D.new()
	fire.light_color = Color("ff8a3a")
	fire.light_energy = 2.2
	fire.omni_range = 9.0
	fire.shadow_enabled = true
	fire.position = Vector3(0, 0.9, 1.0)
	fp.add_child(fire)
	var ftw := fire.create_tween().set_loops()
	ftw.tween_property(fire, "light_energy", 2.6, 0.23)
	ftw.tween_property(fire, "light_energy", 1.9, 0.31)
	ftw.tween_property(fire, "light_energy", 2.3, 0.17)
	var etw := embers.create_tween().set_loops()
	etw.tween_property(embers, "scale", Vector3(1.5, 0.9, 0.6), 0.4)
	etw.tween_property(embers, "scale", Vector3(1.35, 0.75, 0.6), 0.35)
	# Portrait over the mantel.
	Mats.mesh(fp, Mats.box(Vector3(1.4, 1.0, 0.06)), Mats.gold(), Vector3(0, 3.4, 0.2))
	Mats.mesh(fp, Mats.box(Vector3(1.2, 0.8, 0.02)), Mats.solid(Color("5b3a52"), 0.8), Vector3(0, 3.4, 0.24))
	Mats.mesh(fp, Mats.sphere(0.2), Mats.solid(Color("e8c9a8"), 0.8), Vector3(0, 3.45, 0.26), Vector3.ZERO, Vector3(1, 1.2, 0.2))
	# Shelves with books on the side walls.
	var shelf := _load(FURN + "shelf_A_small.gltf")
	var books := _load(FURN + "book_set.gltf")
	for side in [-1, 1]:
		for k in 3:
			for row in 2:
				var p := Vector3(side * 6.7, 1.8 + row * 0.9, -2.5 + k * 2.5)
				if shelf:
					var s := shelf.instantiate() as Node3D
					s.position = p
					s.rotation.y = -side * PI / 2.0
					s.scale = Vector3.ONE * 1.6
					root.add_child(s)
				if books:
					var b := books.instantiate() as Node3D
					b.position = p + Vector3(0, 0.02, 0)
					b.rotation.y = -side * PI / 2.0
					b.scale = Vector3.ONE * 1.4
					root.add_child(b)
	# Tall windows on the south wall with a blue evening glow.
	for x in [-3.0, 3.0]:
		Mats.mesh(root, Mats.box(Vector3(1.6, 2.6, 0.05)), Mats.glow(Color("33507a"), 0.8), Vector3(x, 2.6, 6.88))
		Mats.mesh(root, Mats.box(Vector3(1.8, 2.8, 0.04)), Mats.solid(Color("4a2e1c")), Vector3(x, 2.6, 6.9))
		Mats.mesh(root, Mats.box(Vector3(0.06, 2.6, 0.08)), Mats.solid(Color("4a2e1c")), Vector3(x, 2.6, 6.84))
		Mats.mesh(root, Mats.box(Vector3(1.6, 0.06, 0.08)), Mats.solid(Color("4a2e1c")), Vector3(x, 2.6, 6.84))
	# Chandelier over the table.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, 3.6, 0)
	root.add_child(lamp)
	Mats.mesh(root, Mats.torus(0.5, 0.58, 24), Mats.gold(), Vector3(0, 3.9, 0))
	Mats.mesh(root, Mats.cylinder(0.02, 0.02, 1.1, 6), Mats.gold(), Vector3(0, 4.45, 0))
	for k in 6:
		var a := TAU * k / 6
		Mats.mesh(root, Mats.sphere(0.05), Mats.glow(Color("ffd9a0"), 3.0), Vector3(cos(a) * 0.54, 4.02, sin(a) * 0.54))


func _garden() -> void:
	_environment(Color.WHITE, Color.WHITE, 0.9, true)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	Mats.mesh(root, Mats.box(Vector3(60, 0.1, 60)), Mats.solid(Color("6f9a45"), 0.95), Vector3(0, -0.05, 0))
	# Mown stripes.
	for i in 12:
		Mats.mesh(root, Mats.box(Vector3(2.0, 0.004, 30)), Mats.solid(Color("7aa84e"), 0.95), Vector3(-12 + i * 4, 0.002, 0))
	var hedge := _load(GARDEN + "hedge.glb")
	var bush := _load(GARDEN + "bush.glb")
	var flowers := [_load(GARDEN + "flowers.glb"), _load(GARDEN + "flowers_b.glb")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 26:
		var a := TAU * i / 26.0
		var r := 9.0
		var n := hedge if i % 3 != 0 else bush
		if n:
			var h := n.instantiate() as Node3D
			h.position = Vector3(cos(a) * r, 0, sin(a) * r)
			h.rotation.y = -a
			h.scale = Vector3(1.6, 1.3 + rng.randf() * 0.3, 1.6)
			root.add_child(h)
	for i in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.5, 7.8)
		var f: PackedScene = flowers[i % 2]
		if f:
			var fl := f.instantiate() as Node3D
			fl.position = Vector3(cos(a) * r, 0, sin(a) * r)
			fl.rotation.y = rng.randf() * TAU
			fl.scale = Vector3.ONE * rng.randf_range(0.6, 0.9)
			root.add_child(fl)
	var oak := _load(GARDEN + "oak.glb")
	if oak:
		for p in [Vector3(-11, 0, -8), Vector3(12, 0, -6), Vector3(-9, 0, 11)]:
			var o := oak.instantiate() as Node3D
			o.position = p
			o.scale = Vector3.ONE * 1.4
			root.add_child(o)
	var path := _load(GARDEN + "path_stone.glb")
	if path:
		for k in 4:
			var ps := path.instantiate() as Node3D
			ps.position = Vector3(0, 0.01, 4.5 + k * 2.1)
			root.add_child(ps)
	var house := _load(VILLAGE + "building_home_A_yellow.gltf")
	if house:
		var hs := house.instantiate() as Node3D
		hs.position = Vector3(3, 0, -17)
		hs.scale = Vector3.ONE * 9.0
		root.add_child(hs)
	var well := _load(VILLAGE + "building_well_red.gltf")
	if well:
		var w := well.instantiate() as Node3D
		w.position = Vector3(-7.5, 0, 3.5)
		w.scale = Vector3.ONE * 3.0
		root.add_child(w)
	# Bunting on poles around the table.
	var poles: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector3(cos(a) * 4.6, 0, sin(a) * 3.8)
		poles.append(p)
		Mats.mesh(root, Mats.cylinder(0.05, 0.06, 3.2, 8), Mats.solid(Color("f3ecdc"), 0.6), p + Vector3(0, 1.6, 0))
	var flag_cols := [Color("e05a8a"), Color("f7d154"), Color("7fb0d8"), Color("9fd08a"), Color("f3ecdc")]
	for i in poles.size():
		var a := poles[i] + Vector3(0, 3.1, 0)
		var b := poles[(i + 1) % poles.size()] + Vector3(0, 3.1, 0)
		var n := 9
		for k in n:
			var t := (k + 0.5) / n
			var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.45, 0)
			var flag := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.28, 0.32, 0.01)
			flag.mesh = pm
			flag.material_override = Mats.cloth(flag_cols[(i + k) % flag_cols.size()])
			flag.position = p - Vector3(0, 0.16, 0)
			flag.rotation = Vector3(0, -atan2(b.z - a.z, b.x - a.x), PI)
			root.add_child(flag)


func _banquet() -> void:
	_environment(Color("0d0a10"), Color("5a4250"), 0.5, false)
	Mats.mesh(root, Mats.box(Vector3(18, 0.1, 14)), Mats.solid(Color("6d6660"), 0.85), Vector3(0, -0.05, 0))
	for i in 9:
		for k in 7:
			if (i + k) % 2 == 0:
				Mats.mesh(root, Mats.box(Vector3(2, 0.004, 2)), Mats.solid(Color("5d5650"), 0.85), Vector3(-8 + i * 2, 0.002, -6 + k * 2))
	Mats.mesh(root, Mats.box(Vector3(2.2, 0.02, 14)), Mats.cloth(Color("8e2233")), Vector3(0, 0.01, 0))
	Mats.mesh(root, Mats.box(Vector3(9.0, 0.022, 4.4)), Mats.cloth(Color("8e2233")), Vector3(0, 0.011, 0))
	var wall := Mats.solid(Color("7b6f66"), 0.95)
	for side in 4:
		var w := Node3D.new()
		w.rotation.y = side * PI / 2.0
		root.add_child(w)
		var d := 7.0 if side % 2 == 0 else 9.0
		Mats.mesh(w, Mats.box(Vector3(20, 7, 0.4)), wall, Vector3(0, 3.5, -d))
		for k in 5:
			var x := -8.0 + k * 4.0
			if absf(x) > (9.0 if side % 2 == 0 else 7.0):
				continue
			Mats.mesh(w, Mats.cylinder(0.35, 0.4, 7.0, 16), Mats.solid(Color("8f8378"), 0.9), Vector3(x, 3.5, -d + 0.5))
			# Banners between pillars.
			if k < 4:
				Mats.mesh(w, Mats.box(Vector3(1.1, 2.6, 0.04)), Mats.cloth(Color("7a1d2c")), Vector3(x + 2.0, 4.2, -d + 0.25))
				Mats.mesh(w, Mats.box(Vector3(0.4, 0.4, 0.05)), Mats.gold(), Vector3(x + 2.0, 4.6, -d + 0.23), Vector3(0, 0, 45))
	Mats.mesh(root, Mats.box(Vector3(20, 0.4, 16)), Mats.solid(Color("2a2320"), 0.9), Vector3(0, 7.0, 0))
	for x in [-1.8, 1.8]:
		var ch := Node3D.new()
		ch.position = Vector3(x, 4.6, 0)
		root.add_child(ch)
		Mats.mesh(ch, Mats.torus(0.8, 0.9, 32), Mats.gold())
		Mats.mesh(ch, Mats.cylinder(0.02, 0.02, 2.4, 6), Mats.gold(), Vector3(0, 1.2, 0))
		for k in 8:
			var a := TAU * k / 8
			Mats.mesh(ch, Mats.cylinder(0.025, 0.025, 0.16, 8), Mats.solid(Color("f6efd9")), Vector3(cos(a) * 0.85, 0.1, sin(a) * 0.85))
			Mats.mesh(ch, Mats.sphere(0.03, 0.08), Mats.glow(Color("ffc56a"), 4.0), Vector3(cos(a) * 0.85, 0.22, sin(a) * 0.85))
		var l := OmniLight3D.new()
		l.light_color = Color("ffc98a")
		l.light_energy = 2.0
		l.omni_range = 9.0
		l.shadow_enabled = true
		ch.add_child(l)
	var barrel := _load(VILLAGE + "barrel.gltf")
	var crate := _load(VILLAGE + "crate_A_big.gltf")
	for p in [Vector3(-7.8, 0, -5.8), Vector3(-7.0, 0, -6.1), Vector3(7.6, 0, 5.6)]:
		if barrel:
			var b := barrel.instantiate() as Node3D
			b.position = p
			b.scale = Vector3.ONE * 4.0
			root.add_child(b)
	if crate:
		var c := crate.instantiate() as Node3D
		c.position = Vector3(7.8, 0, -5.8)
		c.scale = Vector3.ONE * 3.0
		root.add_child(c)
	# A throne at the head of the hall.
	var throne := Node3D.new()
	throne.position = Vector3(0, 0, -6.2)
	root.add_child(throne)
	Mats.mesh(throne, Mats.box(Vector3(1.6, 0.3, 1.2)), Mats.solid(Color("5d5650")), Vector3(0, 0.15, 0))
	Mats.mesh(throne, Mats.box(Vector3(1.1, 2.6, 0.2)), Mats.gold(), Vector3(0, 1.6, -0.4))
	Mats.mesh(throne, Mats.box(Vector3(1.0, 0.5, 0.9)), Mats.cloth(Color("7a1d2c")), Vector3(0, 0.55, 0))


static func _load(path: String) -> PackedScene:
	return load(path) as PackedScene if ResourceLoader.exists(path) else null
