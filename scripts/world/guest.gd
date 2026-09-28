class_name Guest
extends Node3D
## A tea party guest: a jelly bean. One smooth sculpted vinyl body (bean_mesh) whose domed top is
## the head, big glossy eyes with sloshing pupils, blushing cheeks, noodle arms with round mitts,
## stubby legs and little shoes, plus a collar accessory, a hair nub and the wardrobe hat.
##
## Poses are procedural (shoulders / elbows / hips / knees / neck blended every frame from a
## state + a gesture). Physics is part of the act:
##   knockdown()  a cake to the face topples you: the bean becomes one rolling rigid body with
##                floppy limbs, then you snap back into your seat (with a boing).
##   die()        poisoned: turn green, shake, then ragdoll for good; the body stays on the floor.
##   become_ghost()  a translucent version floats up above the chair.

const SIT_BACK := 0.30          # the seated body sits this far behind the root (the chair goes there)
const LOCAL_LAYER := 1 << 19    # parts your own first-person camera leaves out
const SEAT_Y := 0.64            # pelvis height when seated
const STAND_Y := 0.54           # pelvis height when standing (short bean legs)
## The bean's side profile, (height, radius) pairs in waist space from the seat up. Above NECK_Y
## it is a dome of radius BEAN_R centred on the neck (the head), flattened FLAT front to back.
const BEAN_PROFILE := [Vector2(-0.2, 0.0), Vector2(-0.188, 0.12), Vector2(-0.15, 0.21), Vector2(-0.08, 0.28),
	Vector2(0.02, 0.318), Vector2(0.14, 0.332), Vector2(0.28, 0.326), Vector2(0.42, 0.312)]
const NECK_Y := 0.54
const BEAN_R := 0.305
const FLAT := 0.9
## Physics layers: 1 world, 16 ragdolls, 32 flying props, 64 living guests' hitboxes.
const L_WORLD := 1
const L_RAGDOLL := 16
const L_PROPS := 32
const L_HITBOX := 64
## Cartoon skin tones (saturated enough to read as skin under the warm lights, never mannequin-white).
const TONES := [Color("f1b58a"), Color("e39a68"), Color("c98150"), Color("a8663c"), Color("7c4a2c"), Color("e8a97e"), Color("d99b74")]
const HAIR := [Color("3b2416"), Color("1d1a1f"), Color("e8b84f"), Color("b8452a"), Color("7a4a2b"), Color("c9c9d4"), Color("5a3a7a")]
## Per-guest variety, from the name: build (belly / head size), outfit and hairstyle.
const BUILDS := [[1.0, 1.0], [1.14, 1.04], [0.9, 1.08], [1.06, 0.94]]
const OUTFITS := [&"bowtie", &"waistcoat", &"dress", &"cardigan"]
const HAIRSTYLES := [&"tuft", &"side_part", &"bun", &"curls", &"bald", &"long"]

## Faceplants send the table's cups flying (the table view listens for this).
signal splashed_table(guest: Guest)
## A knockdown finished and the guest is back in their seat.
signal recovered(guest: Guest)

var seat := -1
var peer_id := 0
var display_name := ""
var look: Dictionary = {}
var alive := true
var is_ghost := false
var is_local := false
var chair: Node3D
var head_anchor: Node3D
var model: Node3D

# rig
var _rig: Node3D
var _hips: Node3D
var _waist: Node3D
var _neck: Node3D
var _head: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _hand_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _kn_l: Node3D
var _kn_r: Node3D
var _mouth: MeshInstance3D
## The closed mouth: a little curved line (flipped for a frown); _mouth is the open one.
var _smile: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _brows: Array[MeshInstance3D] = []
var _eyes: Array[Dictionary] = []
## The big jelly shapes (bottom, belly, head) that squash and stretch.
var _jelly_parts: Array[MeshInstance3D] = []
var _wobble := 0.0
var _belly := 1.0
var _shirt: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _hat: Node3D
var _hitbox: StaticBody3D
var _body_box: StaticBody3D
var _area: Area3D

var _name_tag: Label3D
var _title_tag: Label3D
var _bubble: Label3D
var _bubble_tw: Tween
var _mic: Label3D
var _head_tag: Label3D

var _state := &"sit"
var _gesture := &""
var _gesture_t := 0.0
var _gesture_len := 0.0
var _point_dir := Vector3.FORWARD
var _mood := &"normal"
var _mood_t := 0.0
var _talk_open := 0.0
var _speaking := false
var _t := 0.0
var _blink := 3.0
var _look_yaw := 0.0
var _look_t := 2.0
var _shake := 0.0
var _bonk := Vector3.ZERO
var _bonk_v := Vector3.ZERO
var _prev_head_pos := Vector3.ZERO
var _prev_head_vel := Vector3.ZERO
var _pose: Dictionary = {}
var _held_cup: Node3D
var _cup_tilt := 0.0
var _chair_home := Transform3D()
var _hl := false
## Ragdoll state: parts, joints, and what to put back where after a knockdown.
var _ragdoll_parts: Array[RigidBody3D] = []
var _joints: Array[Joint3D] = []
var _detached: Array[Dictionary] = []
var _ragdolling := false
var _flop_t := 0.0
var _flop_limbs: Array = []
var _pass_through: Array[PhysicsBody3D] = []
var _pass_check := 0.0
var _recovering := false
var _recover_tw: Tween
var _corpse_head: Node3D
var _corpse_eyes: Array[Dictionary] = []
## Set while the poison shakes a guest, until the ragdoll takes over.
var _dying := &""


func setup(p_seat: int, info: Dictionary) -> void:
	seat = p_seat
	peer_id = int(info.get("id", 0))
	display_name = String(info.get("name", "Guest"))
	look = info.get("cos", {})
	name = "Guest%d" % seat
	_build_rig(false)
	_build_tags()
	_area = Area3D.new()
	_area.collision_layer = 4
	_area.collision_mask = 0
	_area.set_meta(&"guest", self)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.5
	shape.shape = cap
	shape.position = Vector3(0, 1.2, -SIT_BACK)
	_area.add_child(shape)
	add_child(_area)
	_t = randf() * 10.0


# ---------------------------------------------------------------- building

func _skin() -> Dictionary:
	return Cosmetics.entry(&"skin", StringName(str(look.get("skin", &"cream"))))


func _hash() -> int:
	return absi(hash(display_name))


## One chunky part: a soft box centred at `pos` under `parent`.
func _part(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, round_amt: float = 0.45, taper: Vector2 = Vector2.ONE, bulge: float = 0.0) -> MeshInstance3D:
	return Mats.mesh(parent, Mats.softbox(size, round_amt, taper, bulge), mat, pos)


func _pivot(parent: Node3D, pos: Vector3, n: String) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


func _build_rig(ghost: bool) -> void:
	var skin := _skin()
	var body_col: Color = skin.get("body", Color("ffe3b8"))
	var accent: Color = skin.get("accent", Color("ff8fab"))
	# Picked in the wardrobe; a look without them (an older client) falls back to the name.
	var hair_col: Color = HAIR[(_hash() / 7) % HAIR.size()]
	if Cosmetics.DYES.has(_look_id(&"dye")):
		hair_col = Cosmetics.DYES[_look_id(&"dye")]["color"]
	var build: Array = BUILDS[(_hash() / 13) % BUILDS.size()]
	if Cosmetics.SHAPES.has(_look_id(&"shape")):
		var sh: Dictionary = Cosmetics.SHAPES[_look_id(&"shape")]
		build = [float(sh["belly"]), float(sh["eyes"])]
	var belly: float = build[0]
	var eye_k: float = build[1]
	_belly = belly
	var outfit: StringName = OUTFITS[(_hash() / 29) % OUTFITS.size()]
	if Cosmetics.COLLARS.has(_look_id(&"collar")):
		outfit = _look_id(&"collar")
	var hairstyle: StringName = HAIRSTYLES[(_hash() / 61) % HAIRSTYLES.size()]
	if Cosmetics.HAIRDOS.has(_look_id(&"hair")):
		hairstyle = _look_id(&"hair")
	var eye_style := _look_id(&"eyes")
	var g := Mats.ghost()
	_shirt = _vinyl(body_col, true)
	_skin_mat = _shirt
	var skin_m: Material = g if ghost else _shirt
	var limb: Material = skin_m
	var glove: Material = g if ghost else _vinyl(Color("fbf8f2"), false)
	var shoe: Material = g if ghost else _vinyl(body_col.darkened(0.55).lerp(Color("2d2233"), 0.55), false, 0.5)
	var ink := Mats.solid(Color("1d1128"), 0.35)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	model = _rig
	_jelly_parts.clear()
	# The seat of the bean, and two stubby noodle legs.
	_hips = _pivot(_rig, Vector3(0, SEAT_Y, -SIT_BACK), "Hips")
	_hip_l = null
	_hip_r = null
	_kn_l = null
	_kn_r = null
	if not ghost:
		_hip_l = _pivot(_hips, Vector3(0.13 * belly, -0.1, 0.03), "HipL")
		_hip_r = _pivot(_hips, Vector3(-0.13 * belly, -0.1, 0.03), "HipR")
		for hp: Node3D in [_hip_l, _hip_r]:
			_limb(hp, 0.095, 0.3, -0.09, limb)
			var kn := _pivot(hp, Vector3(0, -0.19, 0), "Knee")
			_limb(kn, 0.09, 0.28, -0.08, limb)
			var an := _pivot(kn, Vector3(0, -0.18, 0), "Ankle")
			_part(an, Vector3(0.21, 0.14, 0.3), shoe, Vector3(0, -0.03, 0.06), 0.8, Vector2(0.95, 0.85))
			if hp == _hip_l:
				_kn_l = kn
			else:
				_kn_r = kn
	# The bean itself: one smooth sculpted body from the seat to the top of the head.
	_waist = _pivot(_hips, Vector3(0, 0.1, 0), "Waist")
	var body := Mats.mesh(_waist, bean_mesh(belly), skin_m)
	body.name = "Bean"
	_jelly_parts.append(body)
	if not ghost:
		_build_pattern(_look_id(&"pattern"), body_col, accent, belly)
		_build_outfit(outfit, body_col, accent, belly)
	# Noodle arms with round mitts, coming out of the sides.
	_sh_l = _pivot(_waist, Vector3(0.29 * belly, 0.3, 0), "ShoulderL")
	_sh_r = _pivot(_waist, Vector3(-0.29 * belly, 0.3, 0), "ShoulderR")
	for sh: Node3D in [_sh_l, _sh_r]:
		var el := _pivot(sh, Vector3(0, -0.18, 0), "Elbow")
		var hand := _pivot(el, Vector3(0, -0.18, 0), "Hand")
		# (A ghost is just the glowing bean: overlapping translucent limbs look like a mess.)
		if not ghost:
			_limb(sh, 0.07, 0.27, -0.09, limb)
			_limb(el, 0.066, 0.25, -0.08, limb)
			Mats.mesh(hand, Mats.sphere(0.088, 0.17, 18), glove, Vector3(0, -0.05, 0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
			var side := 1.0 if sh == _sh_l else -1.0
			Mats.mesh(hand, Mats.sphere(0.04), glove, Vector3(-0.07 * side, -0.0, 0.05))
		if sh == _sh_l:
			_el_l = el
		else:
			_el_r = el
			_hand_r = hand
	# The top of the bean is the head: a dome centred on the neck, so turning and nodding just
	# slides the face over the surface.
	_neck = _pivot(_waist, Vector3(0, NECK_Y, 0), "Neck")
	_head = _pivot(_neck, Vector3.ZERO, "Head")
	head_anchor = _head
	var face := Node3D.new()
	face.name = "Face"
	_head.add_child(face)
	if not ghost:
		var blush := Mats.solid(body_col.lerp(Color("ff5f86"), 0.5), 0.9)
		for side in [1.0, -1.0]:
			Mats.mesh(_on_face(face, 0.185 * side, -0.035, -0.012), Mats.sphere(0.05, 0.1, 16), blush, Vector3.ZERO, Vector3.ZERO, Vector3(1.35, 0.8, 0.25))
		var hair_mat := _vinyl(hair_col, false, 0.45)
		if _look_id(&"dye") == &"rainbow":
			hair_mat = _vinyl(hair_col, false, 0.3)
			hair_mat.emission_enabled = true
			hair_mat.emission = Color("ff5fa2")
			hair_mat.emission_energy_multiplier = 0.25
		_build_hair(face, hairstyle, hair_mat, 1.0)
	# Big glossy eyes: a white, a black pupil that sloshes about, and a glint.
	_eyes.clear()
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color("fffdf8")
	_eye_mat.roughness = 0.2
	_eye_mat.emission = Color("fff1c4")
	var white: Material = _eye_mat
	var glint := Mats.glow(Color.WHITE, 1.2)
	for side in [1.0, -1.0]:
		var eye := _on_face(face, 0.1 * side, 0.055, -0.03)
		eye.scale = Vector3.ONE * eye_k
		Mats.mesh(eye, Mats.sphere(0.078, 0.156, 20), white, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.18, 0.62))
		var pupil := Node3D.new()
		eye.add_child(pupil)
		Mats.mesh(pupil, Mats.sphere(0.05, 0.1, 16), ink, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.12, 0.5))
		Mats.mesh(pupil, Mats.sphere(0.015, 0.03, 8), glint, Vector3(0.018, 0.024, 0.024))
		if not ghost:
			_build_eye_style(eye, pupil, eye_style, side, body_col, ink, glint)
		_eyes.append({"node": pupil, "off": Vector2(randf_range(-0.3, 0.3), -0.3), "vel": Vector2.ZERO})
	_brows.clear()
	for side in [1.0, -1.0]:
		var bp := _on_face(face, 0.1 * side, 0.155, 0.0)
		var brow := Mats.mesh(bp, Mats.softbox(Vector3(0.11, 0.028, 0.03), 0.6), ink if not ghost else g)
		_brows.append(brow)
	var mp := _on_face(face, 0.0, -0.075, -0.008)
	var lip := Mats.solid(Color("3b0d1e"), 0.5)
	_mouth = Mats.mesh(mp, Mats.sphere(0.05, 0.1, 14), lip, Vector3.ZERO, Vector3.ZERO, Vector3(1.9, 0.45, 0.4))
	_smile = Mats.mesh(mp, smile_mesh(), lip, Vector3(0, 0.012, 0.01))
	if not ghost:
		_build_face(face, StringName(str(look.get("face", &"none"))))
	var hat := Hats.build(StringName(str(look.get("hat", &"none"))))
	if hat:
		hat.scale = Vector3.ONE * 0.52 * belly
		hat.position = Vector3(0, BEAN_R - 0.035, -0.01)
		face.add_child(hat)
		if ghost:
			_ghostify(hat)
	_hat = hat
	if not ghost:
		_hitbox = StaticBody3D.new()
		_hitbox.collision_layer = L_HITBOX
		_hitbox.collision_mask = 0
		_hitbox.set_meta(&"guest", self)
		var hs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.31
		hs.shape = sph
		_hitbox.add_child(hs)
		face.add_child(_hitbox)
		_body_box = StaticBody3D.new()
		_body_box.collision_layer = L_HITBOX
		_body_box.collision_mask = 0
		_body_box.set_meta(&"guest", self)
		RoomBuilder._box_shape(_body_box, Vector3(0.62 * belly, 0.5, 0.56), Vector3(0, 0.1, 0))
		_waist.add_child(_body_box)
	if ghost:
		_set_shadows(_rig, false)
	_pose.clear()
	if is_local:
		_apply_local_layers()


## Soft vinyl-toy skin: satin, a gentle rim light, a touch of subsurface glow. The body uses the
## bean mesh's vertex colours (a soft shade towards the bottom).
func _vinyl(c: Color, shaded: bool, rough: float = 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.vertex_color_use_as_albedo = shaded
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.55
	m.clearcoat_enabled = true
	m.clearcoat = 0.3
	m.clearcoat_roughness = 0.35
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.2
	return m


## A noodle limb segment: a capsule hanging down from its pivot (same radius as its neighbour,
## so arms and legs read as one smooth tube).
func _limb(parent: Node3D, radius: float, length: float, centre_y: float, mat: Material) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	c.radial_segments = 16
	c.rings = 6
	return Mats.mesh(parent, c, mat, Vector3(0, centre_y, 0))


## Where the head dome's surface is at (x, y) (head space, +Z = the face), with `lift` pushing
## the point out along the normal. Returns a pivot there whose +Z is the surface normal.
func _on_face(face: Node3D, x: float, y: float, lift: float = 0.0) -> Node3D:
	var n := _face_normal(x, y)
	var p := _face_point(x, y) + n * lift
	var pv := Node3D.new()
	face.add_child(pv)
	pv.position = p
	var up := Vector3.UP - n * n.y
	pv.basis = Basis(up.cross(n).normalized(), up.normalized(), n) if up.length() > 0.01 else Basis()
	return pv


func _face_point(x: float, y: float) -> Vector3:
	# The body's own cross-section at this height (the dome above the neck, the plump middle below).
	var rr := bean_radius(NECK_Y + y) * _belly
	return Vector3(x, y, sqrt(maxf(rr * rr - x * x, 0.0)) * FLAT)


func _face_normal(x: float, y: float) -> Vector3:
	var e := 0.01
	var dx := _face_point(x + e, y) - _face_point(x - e, y)
	var dy := _face_point(x, y + e) - _face_point(x, y - e)
	var n := dx.cross(dy).normalized()
	return n if n.z > 0.0 else -n


static var _smile_mesh: ArrayMesh


## A small curved tube, the closed-mouth smile.
static func smile_mesh() -> ArrayMesh:
	if _smile_mesh:
		return _smile_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var sides := 8
	var r := 0.07
	var tube := 0.011
	var rows: Array[PackedVector3Array] = []
	for i in steps + 1:
		var a := lerpf(-PI * 0.78, -PI * 0.22, float(i) / steps)
		var c := Vector3(cos(a) * r, sin(a) * r + r * 0.6, 0)
		var out := Vector3(cos(a), sin(a), 0)
		var row := PackedVector3Array()
		for k in sides + 1:
			var b := TAU * k / sides
			row.append(c + (out * cos(b) + Vector3(0, 0, 1) * sin(b)) * tube)
		rows.append(row)
	for i in steps:
		for k in sides:
			st.add_vertex(rows[i][k])
			st.add_vertex(rows[i + 1][k + 1])
			st.add_vertex(rows[i + 1][k])
			st.add_vertex(rows[i][k])
			st.add_vertex(rows[i][k + 1])
			st.add_vertex(rows[i + 1][k + 1])
	st.index()
	st.generate_normals()
	_smile_mesh = st.commit()
	return _smile_mesh


static var _beans: Dictionary = {}


## The bean body: a lathe of BEAN_PROFILE (a rounded seat, a plump middle) topped by a dome of
## BEAN_R around the neck, flattened a little front to back. Vertex colours shade the bottom.
static func bean_mesh(belly: float) -> ArrayMesh:
	var key := snappedf(belly, 0.01)
	if _beans.has(key):
		return _beans[key]
	var prof: Array[Vector2] = []   # (radius, height)
	var pts: Array = BEAN_PROFILE.duplicate()
	pts.append(Vector2(NECK_Y, BEAN_R))
	var n := pts.size()
	for i in n - 1:
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p0: Vector2 = pts[i - 1] if i > 0 else p1 * 2.0 - p2
		var p3: Vector2 = pts[i + 2] if i + 2 < n else p2 + Vector2(0.12, 0.0)
		for k in 5:
			var q := p1.cubic_interpolate(p2, p0, p3, k / 5.0)
			prof.append(Vector2(maxf(q.y, 0.0), q.x))
	for k in 15:
		var a := PI * 0.5 * k / 14.0
		prof.append(Vector2(BEAN_R * cos(a), NECK_Y + BEAN_R * sin(a)))
	prof[0].x = 0.0
	var segs := 40
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for j in prof.size():
		var d := prof[mini(j + 1, prof.size() - 1)] - prof[maxi(j - 1, 0)]
		var pn := Vector2(d.y, -d.x).normalized()   # outward, in the (radius, height) plane
		var y := prof[j].y
		var shade := lerpf(0.72, 1.0, smoothstep(-0.2, 0.4, y))
		for i in segs + 1:
			var th := TAU * i / segs
			var r := prof[j].x
			verts.append(Vector3(cos(th) * r * belly, y, sin(th) * r * belly * FLAT))
			norms.append(Vector3(pn.x * cos(th) / belly, pn.y, pn.x * sin(th) / (belly * FLAT)).normalized())
			cols.append(Color(shade, shade, shade))
			uvs.append(Vector2(float(i) / segs, float(j) / (prof.size() - 1)))
	var idx := PackedInt32Array()
	var w := segs + 1
	for j in prof.size() - 1:
		for i in segs:
			var a := j * w + i
			var b := (j + 1) * w + i
			idx.append_array([a, b + 1, b, a, a + 1, b + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_beans[key] = m
	return m


## The bean's radius at height `y` (waist space), for collars and scarves.
static func bean_radius(y: float) -> float:
	if y >= NECK_Y:
		return sqrt(maxf(BEAN_R * BEAN_R - (y - NECK_Y) * (y - NECK_Y), 0.0))
	var pts: Array = BEAN_PROFILE.duplicate()
	pts.append(Vector2(NECK_Y, BEAN_R))
	var n := pts.size()
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if y <= b.x:
			# The same spline as bean_mesh(), so accessories sit right on the surface.
			var p0: Vector2 = pts[i - 1] if i > 0 else a * 2.0 - b
			var p3: Vector2 = pts[i + 2] if i + 2 < n else b + Vector2(0.12, 0.0)
			var t := clampf((y - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0)
			return maxf(cubic_interpolate(a.y, b.y, p0.y, p3.y, t), 0.0)
	return BEAN_R


## Accessories at the collar line, in the wardrobe accent colour: a bow tie, a ruffled collar,
## a pearl necklace, or a scarf.
func _build_outfit(outfit: StringName, _body_col: Color, accent: Color, belly: float) -> void:
	var acc := _vinyl(accent, false, 0.5)
	var y := 0.33
	var r := bean_radius(y)
	var ring := func(a: float, out: float, dy: float) -> Vector3:
		return Vector3(cos(a) * (r + out) * belly, y + dy, sin(a) * (r + out) * belly * FLAT)
	match outfit:
		&"waistcoat":
			var frill := _vinyl(Color("fff6e6"), false, 0.6)
			for i in 9:
				var a := PI * (0.12 + 0.76 * i / 8.0)
				Mats.mesh(_waist, Mats.sphere(0.06, 0.08, 12), frill, ring.call(a, -0.01, 0.0), Vector3.ZERO, Vector3(1.25, 0.8, 1.25))
			Mats.mesh(_waist, Mats.sphere(0.03), Mats.gold(), ring.call(PI * 0.5, 0.01, -0.07))
		&"dress":
			var pearl := Mats.porcelain(Color("fbf6ee"))
			for i in 13:
				var a := PI * (0.1 + 0.8 * i / 12.0)
				Mats.mesh(_waist, Mats.sphere(0.024), pearl, ring.call(a, 0.012, -0.05 * sin(a)))
			Mats.mesh(_waist, Mats.sphere(0.04), acc, ring.call(PI * 0.5, 0.02, -0.1))
		&"cardigan":
			var sc := Mats.mesh(_waist, Mats.torus(r * belly - 0.035, r * belly + 0.05, 28), acc, Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 1, FLAT))
			sc.name = "Scarf"
			Mats.mesh(_waist, Mats.softbox(Vector3(0.09, 0.22, 0.045), 0.6), acc, ring.call(PI * 0.35, 0.03, -0.12), Vector3(0, 0, -10))
		&"tie":
			var knot: Vector3 = ring.call(PI * 0.5, 0.01, -0.01)
			Mats.mesh(_waist, Mats.softbox(Vector3(0.06, 0.05, 0.04), 0.6), acc, knot)
			var yb := y - 0.15
			var zb := bean_radius(yb) * belly * FLAT + 0.012
			var tilt := rad_to_deg(atan2(zb - knot.z, 0.15))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.08, 0.22, 0.02), 0.5, Vector2(1.2, 0.55)), acc, Vector3(0, y - 0.13, (knot.z + zb) * 0.5), Vector3(tilt, 0, 0))
		&"rose":
			var at: Vector3 = ring.call(PI * 0.3, 0.02, -0.08)
			var petal := _vinyl(Color("e0284f"), false, 0.5)
			for i in 5:
				var a := TAU * i / 5.0
				Mats.mesh(_waist, Mats.sphere(0.028), petal, at + Vector3(cos(a) * 0.022, sin(a) * 0.022, 0.0))
			Mats.mesh(_waist, Mats.sphere(0.024), _vinyl(Color("a3123a"), false), at + Vector3(0, 0, 0.015))
			Mats.mesh(_waist, Mats.sphere(0.03), _vinyl(Color("3f8f3a"), false), at + Vector3(0.03, -0.035, -0.005), Vector3.ZERO, Vector3(1.4, 0.6, 0.5))
			_build_outfit(&"bowtie", _body_col, accent, belly)
		&"medal":
			var at: Vector3 = ring.call(PI * 0.5, 0.02, -0.09)
			Mats.mesh(_waist, Mats.softbox(Vector3(0.05, 0.08, 0.015), 0.4), acc, at + Vector3(0, 0.04, -0.005), Vector3(-15, 0, 0))
			Mats.mesh(_waist, Mats.cylinder(0.045, 0.045, 0.015, 20), Mats.gold(), at + Vector3(0, -0.02, 0.01), Vector3(75, 0, 0))
			Mats.mesh(_waist, Mats.sphere(0.018), Mats.solid(Color("c0303a"), 0.2, 0.3), at + Vector3(0, -0.02, 0.022))
		&"cape":
			var cloak := _vinyl(Color("1d1128"), false, 0.6)
			var lining := _vinyl(accent, false, 0.5)
			# A tall villain's collar standing up behind the head, lined in the accent colour.
			for side in [1.0, -1.0]:
				var a: float = PI * (1.5 + 0.28 * side)
				var cp := Node3D.new()
				_waist.add_child(cp)
				cp.position = ring.call(a, 0.0, 0.12)
				cp.rotation = Vector3(deg_to_rad(-25.0), -a + PI * 0.5, 0)
				Mats.mesh(cp, Mats.softbox(Vector3(0.24, 0.26, 0.025), 0.4, Vector2(1.35, 0.8)), cloak, Vector3.ZERO)
				Mats.mesh(cp, Mats.softbox(Vector3(0.2, 0.22, 0.01), 0.4, Vector2(1.35, 0.8)), lining, Vector3(0, 0, 0.018))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.5 * belly, 0.48, 0.05), 0.5, Vector2(0.8, 1.15)), cloak, Vector3(0, y - 0.22, -(bean_radius(y - 0.2) * belly * FLAT + 0.035)), Vector3(8, 0, 0))
			Mats.mesh(_waist, Mats.sphere(0.028), Mats.gold(), ring.call(PI * 0.5, 0.015, 0.0))
		_:
			var at: Vector3 = ring.call(PI * 0.5, 0.01, 0.0)
			Mats.mesh(_waist, Mats.sphere(0.035, 0.06), acc, at)
			for side in [1.0, -1.0]:
				Mats.mesh(_waist, Mats.softbox(Vector3(0.1, 0.09, 0.045), 0.55, Vector2(0.5, 1.0)), acc, at + Vector3(0.065 * side, 0, -0.012), Vector3(0, 0, 90 * side))


func _look_id(key: StringName) -> StringName:
	return StringName(str(look.get(String(key), "")))


## Eye styles: lashes, lids and extra sparkle on the googly eyes.
func _build_eye_style(eye: Node3D, pupil: Node3D, style: StringName, side: float, body_col: Color, ink: Material, glint: Material) -> void:
	var lid := _vinyl(body_col.darkened(0.22), false, 0.45)
	match style:
		&"lashes":
			for k in 3:
				var a := deg_to_rad(95.0 - k * 28.0)
				var p := Vector3(cos(a) * 0.085 * side, sin(a) * 0.1, 0.03)
				Mats.mesh(eye, Mats.softbox(Vector3(0.018, 0.07, 0.016), 0.5), ink, p, Vector3(0, 0, rad_to_deg(a - PI * 0.5) * side))
		&"sleepy":
			Mats.mesh(eye, Mats.sphere(0.086, 0.172, 20), lid, Vector3(0, 0.035, 0.01), Vector3.ZERO, Vector3(1.06, 0.72, 0.72))
			Mats.mesh(eye, Mats.softbox(Vector3(0.17, 0.014, 0.02), 0.6), ink, Vector3(0, -0.01, 0.06))
		&"suspicious":
			Mats.mesh(eye, Mats.sphere(0.086, 0.172, 20), lid, Vector3(0, 0.05, 0.01), Vector3(0, 0, 18 * side), Vector3(1.08, 0.66, 0.72))
			Mats.mesh(eye, Mats.softbox(Vector3(0.17, 0.014, 0.02), 0.6), ink, Vector3(0, 0.0, 0.06), Vector3(0, 0, 18 * side))
		&"sparkle":
			Mats.mesh(pupil, Mats.sphere(0.012, 0.024, 8), glint, Vector3(-0.02, -0.022, 0.028))
			for k in 4:
				Mats.mesh(pupil, Mats.box(Vector3(0.058, 0.011, 0.006)), glint, Vector3(0.012, 0.018, 0.03), Vector3(0, 0, 45 * k))
		&"beady":
			eye.scale *= 0.7
			pupil.scale = Vector3(1.25, 1.25, 1.0)


## A pattern on the body, below the collar.
func _build_pattern(pattern: StringName, body_col: Color, accent: Color, belly: float) -> void:
	var on_body := func(a: float, y: float, out: float = 0.0) -> Vector3:
		var r := bean_radius(y) + out
		return Vector3(cos(a) * r * belly, y, sin(a) * r * belly * FLAT)
	var decal := func(pos: Vector3, size: float, mat: Material, flat: float = 0.25) -> MeshInstance3D:
		var n := Vector3(pos.x, 0.0, pos.z / (FLAT * FLAT)).normalized()
		var mi := Mats.mesh(_waist, Mats.sphere(size, size * 2.0, 14), mat, pos)
		mi.basis = Basis.looking_at(-n, Vector3.UP).scaled(Vector3(1, 1, flat))
		return mi
	match pattern:
		&"spots":
			var m := _vinyl(accent, false, 0.5)
			var k := 0
			for y in [0.02, 0.14, 0.26]:
				for i in 7:
					var a := TAU * (i + (0.5 if k % 2 == 1 else 0.0)) / 7.0
					decal.call(on_body.call(a, y), 0.04, m)
				k += 1
		&"belly":
			decal.call(on_body.call(PI * 0.5, 0.1, -0.02), 0.17, _vinyl(body_col.lightened(0.45), false, 0.5), 0.3)
		&"stripes":
			var m := _vinyl(accent, false, 0.5)
			for y in [-0.04, 0.08, 0.2]:
				var r := bean_radius(y) * belly
				Mats.mesh(_waist, Mats.torus(r - 0.012, r + 0.014, 32), m, Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 1, FLAT))
		&"heart":
			var m := _vinyl(accent, false, 0.45)
			var hp := Node3D.new()
			_waist.add_child(hp)
			hp.position = on_body.call(PI * 0.5, 0.14, -0.012)
			hp.rotation_degrees.x = -12.0
			for side in [1.0, -1.0]:
				Mats.mesh(hp, Mats.sphere(0.055), m, Vector3(0.045 * side, 0.03, 0), Vector3.ZERO, Vector3(1, 1, 0.35))
			Mats.mesh(hp, Mats.softbox(Vector3(0.09, 0.09, 0.035), 0.35), m, Vector3(0, -0.012, 0), Vector3(0, 0, 45))
		&"stars":
			var m := Mats.glow(Color("fff1a8"), 0.9)
			var rng := RandomNumberGenerator.new()
			rng.seed = _hash()
			for i in 16:
				decal.call(on_body.call(rng.randf() * TAU, rng.randf_range(-0.05, 0.28)), rng.randf_range(0.012, 0.024), m)


## A little something on top of the bean (hats sit over it).
func _build_hair(face: Node3D, style: StringName, hair: Material, _k: float) -> void:
	var top := BEAN_R
	match style:
		&"side_part":
			Mats.mesh(face, Mats.torus(0.022, 0.07, 14), hair, Vector3(0.02, top + 0.03, 0.03), Vector3(0, 0, 90))
		&"bun":
			Mats.mesh(face, Mats.sphere(0.09), hair, Vector3(0, top - 0.02, -0.12))
		&"curls":
			for i in 3:
				Mats.mesh(face, Mats.sphere(0.05), hair, Vector3(-0.065 + i * 0.065, top - 0.005 - absf(i - 1) * 0.015, 0.04))
		&"bald":
			# A leaf sprout.
			Mats.mesh(face, Mats.cylinder(0.01, 0.014, 0.09, 6), _vinyl(Color("3f8f3a"), false), Vector3(0, top + 0.04, 0))
			Mats.mesh(face, Mats.sphere(0.05, 0.02), _vinyl(Color("5fbf4a"), false), Vector3(0.045, top + 0.085, 0), Vector3(0, 0, -30), Vector3(1.4, 1.0, 0.8))
		&"long":
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.sphere(0.07), hair, Vector3(0.27 * side * _belly, 0.1, -0.08))
		&"pigtails":
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.sphere(0.075), hair, Vector3(0.24 * side * _belly, top - 0.06, -0.06), Vector3.ZERO, Vector3(0.9, 1.25, 0.9))
				Mats.mesh(face, Mats.sphere(0.03), _vinyl(Color("ff5f86"), false), Vector3(0.2 * side * _belly, top - 0.02, -0.05))
		&"mohawk":
			for i in 5:
				var a := deg_to_rad(-60.0 + i * 30.0)
				Mats.mesh(face, Mats.sphere(0.045), hair, Vector3(0, cos(a) * (top + 0.02), sin(a) * (top + 0.02)), Vector3(rad_to_deg(a), 0, 0), Vector3(0.45, 1.6, 0.9))
		&"afro":
			for i in 14:
				var a := TAU * i / 7.0
				var ring := 0 if i < 7 else 1
				var up := 0.55 if ring == 0 else 0.85
				var d := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up) - 0.15).normalized()
				Mats.mesh(face, Mats.sphere(0.085), hair, d * (top + 0.01))
			Mats.mesh(face, Mats.sphere(0.1), hair, Vector3(0, top + 0.03, -0.03))
		&"none":
			pass
		_:
			Mats.mesh(face, Mats.cylinder(0.016, 0.042, 0.1, 10), hair, Vector3(0.02, top + 0.03, 0.02), Vector3(0, 0, -18))


func _set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_shadows(c, on)


func _build_face(face: Node3D, id: StringName) -> void:
	match id:
		&"moustache":
			var m := _vinyl(Color("3b2416"), false, 0.7)
			for side in [1.0, -1.0]:
				Mats.mesh(_on_face(face, 0.055 * side, -0.045, 0.012), Mats.sphere(0.052, 0.1), m, Vector3.ZERO, Vector3(0, 0, -22 * side), Vector3(1.6, 0.6, 0.6))
				Mats.mesh(_on_face(face, 0.12 * side, -0.02, 0.0), Mats.sphere(0.026), m)
		&"monocle":
			var pv := _on_face(face, -0.1, 0.055, 0.02)
			Mats.mesh(pv, Mats.torus(0.078, 0.094, 24), Mats.gold(), Vector3.ZERO, Vector3(90, 0, 0))
			Mats.mesh(pv, Mats.cylinder(0.005, 0.005, 0.26, 6), Mats.gold(), Vector3(-0.07, -0.13, -0.03), Vector3(0, 0, 25))
		&"glasses":
			var gl := Mats.solid(Color("2a1f33"), 0.35)
			for side in [1.0, -1.0]:
				Mats.mesh(_on_face(face, 0.1 * side, 0.055, 0.022), Mats.torus(0.076, 0.094, 24), gl, Vector3.ZERO, Vector3(90, 0, 0))
			Mats.mesh(_on_face(face, 0.0, 0.065, 0.02), Mats.box(Vector3(0.04, 0.013, 0.013)), gl)
		&"blush":
			for side in [1.0, -1.0]:
				Mats.mesh(_on_face(face, 0.18 * side, -0.035, -0.004), Mats.sphere(0.048), Mats.solid(Color("ff7aa2"), 0.8), Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 0.75, 0.3))
		&"nose":
			Mats.mesh(_on_face(face, 0.0, -0.01, 0.02), Mats.sphere(0.05), Mats.solid(Color("ff2e4d"), 0.2))
		&"shades":
			var s := Mats.solid(Color("111118"), 0.1, 0.4)
			for side in [1.0, -1.0]:
				Mats.mesh(_on_face(face, 0.1 * side, 0.06, 0.03), Mats.softbox(Vector3(0.14, 0.085, 0.025), 0.45), s)
			Mats.mesh(_on_face(face, 0.0, 0.08, 0.03), Mats.box(Vector3(0.07, 0.016, 0.016)), s)
		&"freckles":
			var fm := Mats.solid(Color("a0522d"), 0.8)
			for side in [1.0, -1.0]:
				for p: Vector2 in [Vector2(0.15, -0.01), Vector2(0.19, -0.05), Vector2(0.14, -0.06)]:
					Mats.mesh(_on_face(face, p.x * side, p.y, -0.004), Mats.sphere(0.011), fm, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.4))
		&"lipstick":
			var red := Mats.solid(Color("d61f4c"), 0.25)
			_mouth.material_override = red
			_smile.material_override = red
		&"plaster":
			var pl := _vinyl(Color("e3a36b"), false, 0.8)
			var pp := _on_face(face, -0.16, 0.16, 0.012)
			for k in [40.0, -40.0]:
				Mats.mesh(pp, Mats.softbox(Vector3(0.17, 0.05, 0.016), 0.5), pl, Vector3.ZERO, Vector3(0, 0, k))
		&"eyepatch":
			var bl := Mats.solid(Color("15121a"), 0.5)
			Mats.mesh(_on_face(face, 0.1, 0.055, 0.035), Mats.cylinder(0.075, 0.075, 0.02, 20), bl, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 1, 1.15))
		&"pipe":
			var wood := Mats.solid(Color("6b3b1f"), 0.5)
			var mp := _on_face(face, -0.07, -0.095, 0.01)
			Mats.mesh(mp, Mats.cylinder(0.014, 0.014, 0.14, 8), wood, Vector3(-0.05, -0.02, 0.05), Vector3(70, 0, 40))
			Mats.mesh(mp, Mats.cylinder(0.042, 0.034, 0.08, 14), wood, Vector3(-0.11, 0.0, 0.1))
			var bub := StandardMaterial3D.new()
			bub.albedo_color = Color(0.8, 0.95, 1.0, 0.35)
			bub.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bub.roughness = 0.05
			bub.rim_enabled = true
			Mats.mesh(mp, Mats.sphere(0.05), bub, Vector3(-0.17, 0.09, 0.12))
			Mats.mesh(mp, Mats.sphere(0.028), bub, Vector3(-0.23, 0.17, 0.1))
		&"beard":
			Mats.mesh(_on_face(face, 0.0, -0.15, -0.05), Mats.softbox(Vector3(0.4, 0.26, 0.16), 0.7, Vector2(1.1, 1.0)), _vinyl(Color("f2f2f2"), false, 0.9))


func _build_tags() -> void:
	_name_tag = _tag(Ui.display_font(), 34, Color("fff4e0"), 2.35)
	_name_tag.text = display_name
	_title_tag = _tag(Ui.body_font(700), 20, Color("ffc93c"), 2.35)
	_title_tag.text = Cosmetics.title_name(look.get("title", &"newcomer"))
	_title_tag.offset = Vector2(0, -30)
	_bubble = _tag(Ui.display_font(), 36, Color("1d1128"), 2.45)
	_bubble.outline_modulate = Color("fff4e0")
	_bubble.outline_size = 22
	_bubble.visible = false
	# A name over the head in the guest's own colour (the meeting, the vote, or on hover).
	_head_tag = _tag(Ui.display_font(), 30, _skin().get("body", Color.WHITE), 2.2)
	_head_tag.text = display_name
	_head_tag.outline_size = 14
	_head_tag.visible = false
	_mic = _tag(Ui.body_font(700), 22, Color("3ddc97"), 2.3)
	_mic.text = "talking..."
	_mic.offset = Vector2(0, 34)
	_mic.visible = false


func _tag(font: Font, size: int, color: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = size
	l.fixed_size = true
	l.pixel_size = 0.00085
	l.outline_size = 12
	l.outline_modulate = Color("1d1128")
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.position = Vector3(0, y, -SIT_BACK)
	add_child(l)
	return l


## Name and title on a place card at `pos` (global) instead of over the head.
func place_tags(pos: Vector3) -> void:
	_name_tag.global_position = pos
	_title_tag.global_position = pos


func show_head_tag(on: bool) -> void:
	if _head_tag == null:
		return
	var up := on and not is_local and alive
	if up == _head_tag.visible:
		return
	_head_tag.visible = up
	# One name at a time: the place card steps aside while the name is over the head.
	_name_tag.visible = _tags_wanted and not up and not is_local
	_title_tag.visible = _name_tag.visible


var _tags_wanted := true


func show_tags(on: bool) -> void:
	_tags_wanted = on
	_name_tag.visible = on
	_title_tag.visible = on


func set_name_color(c: Color) -> void:
	_name_tag.modulate = c


## Your own guest: everything but your arms goes on LOCAL_LAYER so the first-person camera
## doesn't see the inside of your own head; you never click yourself.
func set_local(on: bool) -> void:
	is_local = on
	_area.collision_layer = 0 if on else 4
	_name_tag.visible = not on
	_title_tag.visible = not on
	_apply_local_layers()


func _apply_local_layers() -> void:
	if not is_local or _rig == null:
		return
	_set_layers(_rig, LOCAL_LAYER)
	_set_layers(_sh_l, 1)
	_set_layers(_sh_r, 1)
	for l: Label3D in [_bubble, _mic]:
		l.layers = LOCAL_LAYER


func _set_layers(n: Node, layers: int) -> void:
	if n == null:
		return
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layers
	for c in n.get_children():
		_set_layers(c, layers)


func set_speaking(on: bool) -> void:
	_speaking = on
	_mic.visible = on and not is_local


## A floating line over the guest's head (emotes, chatter, "Ready!").
func say(text: String, seconds: float = 2.6, color: Color = Color("1d1128")) -> void:
	_bubble.text = text
	_bubble.modulate = color
	_bubble.visible = true
	_bubble.scale = Vector3.ONE * 0.4
	if _bubble_tw and _bubble_tw.is_valid():
		_bubble_tw.kill()
	_bubble_tw = create_tween()
	_bubble_tw.tween_property(_bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_bubble_tw.tween_interval(seconds)
	_bubble_tw.tween_property(_bubble, "scale", Vector3.ONE * 0.01, 0.15)
	_bubble_tw.tween_callback(func() -> void: _bubble.visible = false)
	_talk_open = 1.0


func highlight(on: bool) -> void:
	if on == _hl:
		return
	_hl = on
	_name_tag.outline_modulate = Color("ffc93c") if on else Color("1d1128")
	_name_tag.outline_size = 24 if on else 12
	if _shirt and not is_ghost:
		_shirt.emission_enabled = on
		_shirt.emission = Color("ffc93c")
		_shirt.emission_energy_multiplier = 0.35


## Lights out: the eye whites glow (energy 0 = normal), so in the dark you see pairs of eyes.
func set_eye_glow(energy: float) -> void:
	if _eye_mat == null:
		return
	_eye_mat.emission_enabled = energy > 0.01
	_eye_mat.emission_energy_multiplier = energy


## This guest's own hit bodies (a thrown cake ignores its thrower).
func hitboxes() -> Array[PhysicsBody3D]:
	var out: Array[PhysicsBody3D] = []
	for b: PhysicsBody3D in [_hitbox, _body_box]:
		if b and is_instance_valid(b) and b.is_inside_tree():
			out.append(b)
	return out


## Centre of the face (for cakes, the camera and voice).
func head_position() -> Vector3:
	if _head and is_instance_valid(_head) and _head.is_inside_tree():
		return _head.global_transform * Vector3(0, 0.04, 0.12)
	return global_position + Vector3(0, 1.3, 0)


func is_down() -> bool:
	return _ragdolling


# ---------------------------------------------------------------- posing

## Upper-body gesture: cheer, no, point, think, yes, plead, laugh, sip, interact, shrug, wave, spook.
## Jelly: a slow breathing squash, plus a springy jiggle after every bump (wobble()).
func _squash(delta: float) -> void:
	_wobble = maxf(0.0, _wobble - delta * 1.4)
	var b := sin(_t * 2.1) * 0.012 + sin(_t * 17.0) * _wobble * 0.07
	# The whole bean (face and arms included) squashes together, so nothing floats off it.
	if _waist and is_instance_valid(_waist) and not _ragdolling:
		_waist.scale = Vector3(1.0 - b * 0.6, 1.0 + b, 1.0 - b * 0.6)


func wobble(amount: float = 1.0) -> void:
	_wobble = maxf(_wobble, amount)


func gesture(kind: StringName, seconds: float = -1.0) -> void:
	wobble(0.6)
	if (not alive and not is_ghost) or _ragdolling:
		return
	var map := {&"Cheer": &"cheer", &"Interact": &"interact", &"ual/Idle_FoldArms": &"think", &"Spellcast_Shoot": &"point",
		&"ual/No": &"no", &"ual/Yes": &"yes", &"Block": &"plead", &"ual/Consume": &"sip"}
	kind = map.get(kind, kind)
	_gesture = kind
	_gesture_t = 0.0
	_gesture_len = seconds if seconds > 0.0 else {&"cheer": 1.8, &"laugh": 2.0, &"plead": 2.2, &"think": 2.4, &"point": 1.8}.get(kind, 1.5)
	match kind:
		&"laugh", &"cheer":
			_set_mood(&"happy", _gesture_len)
		&"point", &"no":
			_set_mood(&"angry", _gesture_len)
		&"plead":
			_set_mood(&"sad", _gesture_len)
		&"shock":
			_set_mood(&"shock", _gesture_len)
		&"think":
			_set_mood(&"sly", _gesture_len)


## Point at a world position (accusations, toasts, cake throws).
func point_at(world_pos: Vector3) -> void:
	if _waist and is_instance_valid(_waist) and _waist.is_inside_tree():
		_point_dir = (_waist.global_transform.affine_inverse() * world_pos - _sh_r.position).normalized()
	gesture(&"point")


func _set_mood(m: StringName, seconds: float) -> void:
	_mood = m
	_mood_t = seconds


func _aim(dir: Vector3) -> Quaternion:
	return Quaternion(Vector3.DOWN, dir.normalized())


func _arm(p: Dictionary, side: String, dir: Vector3, bend: float) -> void:
	p["sh_" + side] = _aim(dir)
	p["el_" + side] = bend


func _target_pose() -> Dictionary:
	var p := {}
	var stand := _state in [&"stand", &"drink", &"raise"]
	var breathe := sin(_t * 2.2) * 0.01
	p["hip_y"] = (STAND_Y if stand else SEAT_Y) + breathe
	p["hip_z"] = -SIT_BACK if not stand else -0.05
	p["lean"] = 0.1 if not stand else 0.0
	p["twist"] = 0.0
	p["head"] = Vector3(0.08, _look_yaw, 0.0)
	if not stand:
		_arm(p, "l", Vector3(0.12, -0.8, 0.55), 0.95)
		_arm(p, "r", Vector3(-0.12, -0.8, 0.55), 0.95)
		p["hp_l"] = _aim(Vector3(0.06, -0.05, 1))
		p["hp_r"] = _aim(Vector3(-0.06, -0.05, 1))
		var kick := sin(_t * 1.7) * 0.18
		p["kn_l"] = 1.45 + kick
		p["kn_r"] = 1.45 - kick
	else:
		_arm(p, "l", Vector3(0.22, -1, 0.05), 0.25)
		_arm(p, "r", Vector3(-0.22, -1, 0.05), 0.25)
		p["hp_l"] = _aim(Vector3(0.04, -1, 0.02))
		p["hp_r"] = _aim(Vector3(-0.04, -1, 0.02))
		p["kn_l"] = 0.06
		p["kn_r"] = 0.06
	if _held_cup:
		_arm(p, "r", Vector3(-0.15, -0.35, 1), 1.25)
	if _state == &"raise":
		_arm(p, "r", Vector3(-0.2, 0.25, 1), 0.7)
		p["head"] = Vector3(-0.05, 0, 0)
	if _state == &"drink":
		_arm(p, "r", Vector3(0.1, -0.2, 1), 2.2)
		p["head"] = Vector3(-0.4, 0, 0)
	if _state == &"ghost":
		p["hip_y"] = SEAT_Y + 1.0 + sin(_t * 1.6) * 0.12
		p["hip_z"] = -SIT_BACK
		var sway := sin(_t * 2.4) * 0.2
		_arm(p, "l", Vector3(0.25, 0.1 + sway, 1), 0.3)
		_arm(p, "r", Vector3(-0.25, 0.1 - sway, 1), 0.3)
		p["head"] = Vector3(0.1, sin(_t * 0.7) * 0.4, sin(_t * 1.3) * 0.15)
	var k := _t * 9.0
	match _gesture:
		&"cheer":
			_arm(p, "l", Vector3(0.45, 1, 0.1 + sin(k) * 0.3), 0.3)
			_arm(p, "r", Vector3(-0.45, 1, 0.1 - sin(k) * 0.3), 0.3)
			p["hip_y"] += absf(sin(k * 0.5)) * 0.05
		&"wave":
			_arm(p, "r", Vector3(-0.6 + sin(k) * 0.35, 0.9, 0.2), 0.6)
		&"point":
			_arm(p, "r", _point_dir + Vector3(0, 0.1, 0), 0.05)
			p["lean"] = 0.25
		&"no":
			_arm(p, "l", Vector3(0.9, -0.3, 0.4), 1.3)
			_arm(p, "r", Vector3(-0.9, -0.3, 0.4), 1.3)
			p["head"] = Vector3(0, sin(k * 1.2) * 0.45, 0)
		&"yes":
			_arm(p, "r", Vector3(-0.2, -0.2, 1), 1.4)
			p["head"] = Vector3(sin(k) * 0.3, 0, 0)
		&"think":
			_arm(p, "r", Vector3(0.15, -0.55, 0.8), 2.3)
			_arm(p, "l", Vector3(-0.2, -0.75, 0.6), 1.7)
			p["head"] = Vector3(0.1, 0.2, 0.25)
		&"plead":
			_arm(p, "l", Vector3(-0.15, -0.15, 1), 1.9)
			_arm(p, "r", Vector3(0.15, -0.15, 1), 1.9)
			p["hip_y"] += sin(k) * 0.03
			p["lean"] = 0.35
		&"laugh":
			_arm(p, "l", Vector3(-0.15, -0.9, 0.4), 1.9)
			_arm(p, "r", Vector3(0.15, -0.9, 0.4), 1.9)
			p["head"] = Vector3(-0.45, 0, sin(k) * 0.1)
			p["hip_y"] += absf(sin(k)) * 0.06
			p["lean"] = -0.25
			_talk_open = maxf(_talk_open, 0.6 + 0.4 * sin(k * 1.3))
		&"sip":
			_arm(p, "r", Vector3(0.1, -0.2, 1), 2.2)
			p["head"] = Vector3(-0.35, 0, 0)
		&"interact":
			_arm(p, "l", Vector3(-0.1, -0.4, 1), 0.4)
			_arm(p, "r", Vector3(0.1, -0.4, 1), 0.4)
			p["lean"] = 0.4
		&"shrug":
			_arm(p, "l", Vector3(0.9, -0.6, 0.2), 1.6)
			_arm(p, "r", Vector3(-0.9, -0.6, 0.2), 1.6)
			p["head"] = Vector3(0, 0, 0.25)
		&"spook":
			_arm(p, "l", Vector3(0.3, 0.6, 1), 0.3)
			_arm(p, "r", Vector3(-0.3, 0.6, 1), 0.3)
		&"shock":
			# Hands to the cheeks, leaning back.
			_arm(p, "l", Vector3(0.35, 0.55, 0.6), 2.3)
			_arm(p, "r", Vector3(-0.35, 0.55, 0.6), 2.3)
			p["lean"] = -0.3
			p["hip_y"] += absf(sin(k * 0.7)) * 0.03
	if _shake > 0.0:
		p["twist"] = sin(_t * 60.0) * 0.14 * _shake
		p["head"] += Vector3(sin(_t * 47.0), sin(_t * 53.0), sin(_t * 41.0)) * 0.22 * _shake
		_arm(p, "l", Vector3(0.9, 0.2 + sin(_t * 30.0), 0.3), 1.0 + sin(_t * 25.0))
		_arm(p, "r", Vector3(-0.9, 0.2 - sin(_t * 31.0), 0.3), 1.0 + sin(_t * 27.0))
	return p


func _process(delta: float) -> void:
	if _hat and is_instance_valid(_hat):
		var prop := _hat.get_node_or_null("Propeller") as Node3D
		if prop:
			prop.rotation.y += delta * float(prop.get_meta(&"spin", 8.0))
	_t += delta
	if not _ragdoll_parts.is_empty() and _corpse_head:
		_googly(_corpse_head, _corpse_eyes, delta)
		if _ragdolling or not alive:
			_flop(delta)
	_squash(delta)
	if _rig == null or not is_instance_valid(_rig) or _ragdolling or (not alive and not is_ghost and _shake <= 0.0):
		return
	if _gesture != &"":
		_gesture_t += delta
		if _gesture_t >= _gesture_len:
			_gesture = &""
	if _mood_t > 0.0:
		_mood_t -= delta
		if _mood_t <= 0.0 and alive:
			_mood = &"normal"
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(1.5, 4.0)
		_look_yaw = randf_range(-0.5, 0.5)
	var target := _target_pose()
	var w := 1.0 - exp(-14.0 * delta)
	for key: String in target:
		var v: Variant = target[key]
		if not _pose.has(key):
			_pose[key] = v
		elif v is Quaternion:
			_pose[key] = (_pose[key] as Quaternion).slerp(v, w)
		else:
			_pose[key] = lerp(_pose[key], v, w)
	_bonk_v += (-_bonk * 60.0 - _bonk_v * 7.0) * delta
	_bonk += _bonk_v * delta
	if _recovering:
		return
	_hips.position = Vector3(0, _pose["hip_y"], _pose["hip_z"])
	_waist.rotation = Vector3(_pose["lean"], _pose["twist"], 0)
	_sh_l.quaternion = _pose["sh_l"]
	_sh_r.quaternion = _pose["sh_r"]
	_el_l.quaternion = Quaternion(Vector3.RIGHT, -float(_pose["el_l"]))
	_el_r.quaternion = Quaternion(Vector3.RIGHT, -float(_pose["el_r"]))
	if _hip_l:
		_hip_l.quaternion = _pose["hp_l"]
		_hip_r.quaternion = _pose["hp_r"]
		_kn_l.quaternion = Quaternion(Vector3.RIGHT, float(_pose["kn_l"]))
		_kn_r.quaternion = Quaternion(Vector3.RIGHT, float(_pose["kn_r"]))
	_neck.rotation = _pose["head"] + _bonk
	if _held_cup and is_instance_valid(_held_cup):
		_cup_tilt = lerpf(_cup_tilt, -1.3 if _state == &"drink" else 0.0, w * 0.6)
		_held_cup.global_basis = Basis.from_euler(Vector3(_cup_tilt, global_rotation.y, 0))
	_face(delta)
	_googly(_head, _eyes, delta)


func _face(delta: float) -> void:
	var want := 0.0
	if _speaking:
		want = 0.3 + 0.7 * absf(sin(_t * 17.0) * sin(_t * 6.3))
	if _mood == &"shock":
		want = 1.0
	_talk_open = maxf(want, _talk_open - delta * 2.5)
	var open := _talk_open
	var smile := 1.9 if _mood != &"sad" else 1.2
	_mouth.scale = Vector3(smile - open * 0.6, 0.4 + open * 1.8, 0.4)
	_mouth.visible = open > 0.12
	if _smile:
		_smile.visible = not _mouth.visible
		_smile.rotation.z = PI if _mood in [&"sad", &"angry"] else 0.0
		_smile.position.y = -0.01 if _smile.rotation.z > 0.0 else 0.012
	var tilt := 0.0
	var lift := 0.0
	match _mood:
		&"angry":
			tilt = 0.45
		&"sad":
			tilt = -0.4
		&"shock":
			lift = 0.05
		&"sly":
			tilt = 0.2
		&"happy":
			lift = 0.02
	for i in _brows.size():
		var side := 1.0 if i == 0 else -1.0
		_brows[i].rotation.z = tilt * side
		_brows[i].position.y = lift + (0.03 if _mood == &"sly" and i == 0 else 0.0)
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.0, 5.0)
		for e in _eyes:
			var eye: Node3D = (e["node"] as Node3D).get_parent()
			var sy := eye.scale.x
			var tw := eye.create_tween()
			tw.tween_property(eye, "scale:y", sy * 0.1, 0.06)
			tw.tween_property(eye, "scale:y", sy, 0.08)


## Googly pupils: a damped spring pulled by gravity and flung by the head's acceleration.
func _googly(head: Node3D, eyes: Array[Dictionary], delta: float) -> void:
	if head == null or not is_instance_valid(head) or not head.is_inside_tree() or delta <= 0.0:
		return
	var pos := head.global_position
	var vel := (pos - _prev_head_pos) / delta
	var acc := (vel - _prev_head_vel) / delta
	_prev_head_pos = pos
	_prev_head_vel = vel
	if acc.length() > 400.0:
		acc = Vector3.ZERO
	var inv := head.global_transform.basis.inverse()
	var g := inv * Vector3(0, -9.8, 0)
	var a := inv * acc
	for e in eyes:
		var off: Vector2 = e["off"]
		var v: Vector2 = e["vel"]
		var force := Vector2(g.x - a.x, g.y - a.y) * 0.9 - off * 6.0 - v * 2.2
		v += force * delta
		off += v * delta
		if off.length() > 1.0:
			var n := off.normalized()
			off = n
			v = v - n * v.dot(n) * 1.6
		e["off"] = off
		e["vel"] = v
		var node := e["node"] as Node3D
		if is_instance_valid(node):
			node.position = Vector3(off.x * 0.026, off.y * 0.03, 0.026)


## A cake to the face without toppling: the head snaps back and the eyes spin.
func bonk(from_dir: Vector3, frosting: Color) -> void:
	wobble(1.0)
	if not alive or _head == null or _ragdolling:
		return
	var local := _neck.global_transform.basis.inverse() * from_dir
	_bonk_v += Vector3(-local.z * 9.0 - 3.0, local.x * 6.0, randf_range(-6, 6))
	for e in _eyes:
		e["vel"] = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	_set_mood(&"shock", 0.8)
	frost(frosting)
	Sfx.play_at(&"bonk", head_position())


## Frosting stays on the face for the rest of the round.
func frost(frosting: Color) -> void:
	if _head == null or not is_instance_valid(_head):
		return
	var face := _head.get_node_or_null("Face") as Node3D
	if face == null:
		return
	var at := _on_face(face, randf_range(-0.13, 0.13), randf_range(-0.08, 0.12), -0.01)
	var blob := Mats.mesh(at, Mats.sphere(0.1), Mats.solid(frosting, 0.6), Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 1.0, 0.45))
	blob.scale = Vector3.ONE * 0.1
	blob.create_tween().tween_property(blob, "scale", Vector3(1.3, 1.0, 0.45), 0.12)
	if is_local:
		_set_layers(blob, LOCAL_LAYER)


# ---------------------------------------------------------------- the cup

## Stand and raise the cup for the toast (the countdown).
func raise_cup(cup: Node3D) -> void:
	if not alive or _ragdolling:
		return
	_state = &"raise"
	if cup and is_instance_valid(cup) and _held_cup != cup:
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(func() -> void:
			if alive and not _ragdolling and is_instance_valid(cup):
				_hold(cup))


## Drink whatever's in the held cup (or nothing, if it got knocked away).
func sip() -> float:
	if not alive or _ragdolling:
		return 0.0
	_state = &"drink"
	if _held_cup == null:
		say("*sips air*", 1.2)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		if _held_cup:
			Sfx.play_at(&"gulp", head_position(), -2.0)
		_talk_open = 0.8)
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if alive and not _ragdolling:
			_state = &"stand")
	return 1.3


## Raise and drink in one go (a forced toast).
func drink(cup: Node3D) -> float:
	raise_cup(cup)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(sip)
	return 2.1


func _hold(cup: Node3D) -> void:
	_held_cup = cup
	var gt := cup.global_transform
	cup.get_parent().remove_child(cup)
	_hand_r.add_child(cup)
	cup.global_transform = gt
	_cup_tilt = 0.0
	cup.create_tween().tween_property(cup, "position", Vector3(0, -0.14, 0.05), 0.25).set_trans(Tween.TRANS_SINE)


func holding() -> Node3D:
	return _held_cup


## Put a held cup back on the table (`parent` local `pos`).
func release_cup(parent: Node3D, pos: Vector3) -> void:
	if _held_cup == null or not is_instance_valid(_held_cup):
		_held_cup = null
		return
	var cup := _held_cup
	_held_cup = null
	var gt := cup.global_transform
	cup.get_parent().remove_child(cup)
	parent.add_child(cup)
	cup.global_transform = gt
	var tw := cup.create_tween()
	tw.tween_property(cup, "position", pos, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cup, "rotation", Vector3.ZERO, 0.35)


## Hand a held cup back to the world (so it outlives this body); fling it if we're falling.
func _release_held(fling: bool = true) -> void:
	if _held_cup and is_instance_valid(_held_cup):
		var world := get_parent() as Node3D
		var gt := _held_cup.global_transform
		_held_cup.get_parent().remove_child(_held_cup)
		world.add_child(_held_cup)
		_held_cup.global_transform = gt
		if fling and _held_cup.has_method(&"fling"):
			_held_cup.call(&"fling", Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)))
	_held_cup = null


func stand() -> void:
	_state = &"stand"


func sit_back_down() -> void:
	_state = &"sit"
	_set_mood(&"happy", 1.5)


func cheer() -> void:
	gesture(&"cheer")


# ---------------------------------------------------------------- ragdoll

## Knocked clean off the chair (a cake to the face, mostly). Flops for `seconds`, then snaps
## back to the seat. Anything held goes flying.
func knockdown(from_dir: Vector3, seconds: float = 2.2) -> void:
	if not alive or _ragdolling or _rig == null:
		return
	_set_mood(&"shock", seconds + 0.5)
	Sfx.play_at(&"bonk", head_position())
	var dir := from_dir.normalized() if from_dir.length() > 0.01 else global_transform.basis * Vector3(0, 0, -1)
	var bodies := _go_ragdoll(true)
	if bodies.is_empty():
		return
	var body: RigidBody3D = bodies["body"]
	# Knocked backwards off the chair: a shove plus a tumble about the sideways axis.
	var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.05 else global_basis * Vector3(0, 0, -1)
	_launch(body, flat * 2.4 + Vector3.UP * 1.4, Vector3.UP.cross(flat) * 4.5 + Vector3(0, randf_range(-1.5, 1.5), 0))
	Sfx.play_at(&"slide_whistle", head_position(), -8.0, 0.25)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(_recover)


## Poisoned: turn green, shake, gasp... then go limp for good. Returns seconds until down.
func die(style: StringName = &"") -> float:
	if not alive:
		return 0.0
	alive = false
	if style == &"":
		style = StringName(str(look.get("death", &"swoon")))
	_set_mood(&"shock", 99.0)
	Sfx.play_at(&"gasp", head_position())
	var green := Color("7bd14a")
	var tw := create_tween()
	tw.tween_property(_skin_mat, "albedo_color", green, 0.6)
	if _ragdolling:
		# Already on the floor from a cake: this is where they stay.
		if _recover_tw and _recover_tw.is_valid():
			_recover_tw.kill()
		_recovering = false
		_finish_death(style, {})
		return 0.8
	_state = &"stand"
	_shake = 1.0
	var t := 0.9
	if style == &"monologue":
		_shake = 0.0
		say("Avenge... meeee...", 1.5, Color("5c1a33"))
		gesture(&"cheer", 1.6)
		t = 1.7
	elif style == &"stagger":
		t = 1.3
	_dying = style
	tw.parallel().tween_interval(t)
	tw.tween_callback(func() -> void:
		_shake = 0.0
		if _dying != &"":
			_dying = &""
			_finish_death(style, _go_ragdoll(false)))
	return t + 1.2


func _finish_death(style: StringName, bodies: Dictionary) -> void:
	_ragdolling = true
	_knock_chair()
	_x_eyes()
	if bodies.is_empty():
		var down := ragdoll_body()
		if down:
			_launch(down, Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5)), down.angular_velocity)
		return
	var away := global_transform.basis * Vector3(0, 0, -1)
	var up := Vector3.UP
	var torso: RigidBody3D = bodies["body"]
	var head: Node3D = _head
	var side := away.cross(up).normalized()
	# Velocities, not impulses: predictable whatever the body's mass (the tip-over axis is up x dir).
	match style:
		&"keel":
			# Face-first into the tea.
			_launch(torso, -away * 0.9 + up * 0.4, up.cross(-away) * 3.5)
			_splash_table()
		&"spin":
			_launch(torso, up * 3.6, Vector3(0, 14.0, 0))
		&"confetti":
			_confetti(head.global_position)
			Sfx.play_at(&"magic", head.global_position)
			_launch(torso, up * 4.2 + away * 1.0, side * 5.0)
		&"ascend":
			torso.gravity_scale = -0.12
			_launch(torso, up * 0.5, Vector3(randf_range(-0.5, 0.5), 0.8, 0))
		&"yeet":
			_launch(torso, away * 7.5 + up * 5.0, side * 9.0)
		&"stagger":
			_launch(torso, away * 1.1 + up * 0.4, Vector3(randf_range(-1, 1), 5.0, randf_range(-1, 1)) + up.cross(away) * 1.5)
		_:
			# A swoon: tip over backwards off the chair.
			_launch(torso, away * 1.3 + up * 0.7, up.cross(away) * 3.2)
	Sfx.play_at(&"slide_whistle", head.global_position, -2.0 if style == &"yeet" else -5.0)
	var thud := create_tween()
	thud.tween_interval(0.7)
	thud.tween_callback(func() -> void:
		if is_instance_valid(torso):
			Sfx.play_at(&"thud", torso.global_position))


## Turns the bean into one rigid body (the bean rolls and tumbles like a jelly sweet; a capsule
## can't tangle or explode the way a chain of jointed limbs does) and lets the arms and legs flop
## procedurally (_flop). `temporary` keeps a record so _recover() can put everything back.
## Returns {"body": RigidBody3D}.
func _go_ragdoll(temporary: bool) -> Dictionary:
	var world := get_parent() as Node3D
	if world == null or _rig == null or not is_instance_valid(_rig) or _hip_l == null or _ragdolling:
		return {}
	_ragdolling = true
	_gesture = &""
	_release_held()
	_knock_chair()
	_detached.clear()
	_flop_t = 0.0
	_waist.scale = Vector3.ONE
	# The limbs to flop belong to this body (a ghost rig built later has its own).
	_flop_limbs = [[_sh_l, 1.0, _el_l, 0.35, true], [_sh_r, -1.0, _el_r, 0.35, true], [_hip_l, 1.0, _kn_l, 0.25, false], [_hip_r, -1.0, _kn_r, 0.25, false]]
	var rb := RigidBody3D.new()
	rb.name = "BeanBody"
	rb.collision_layer = L_RAGDOLL
	rb.collision_mask = L_WORLD | L_RAGDOLL | L_PROPS
	rb.mass = 6.0
	rb.continuous_cd = true
	rb.angular_damp = 1.6
	rb.linear_damp = 0.15
	rb.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.75
	rb.physics_material_override = pm
	var gt := _waist.global_transform.orthonormalized()
	world.add_child(rb)
	rb.global_transform = gt
	# Never start inside our own chair (that is what used to fling guests across the room).
	if chair is PhysicsBody3D:
		rb.add_collision_exception_with(chair as PhysicsBody3D)
	_pass_through.clear()
	for node: Node3D in [_waist, _hip_l, _hip_r]:
		var ngt := node.global_transform
		_detached.append({"node": node, "parent": node.get_parent(), "local": node.transform})
		node.get_parent().remove_child(node)
		rb.add_child(node)
		node.global_transform = ngt
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3 * _belly
	cap.height = maxf(1.02, cap.radius * 2.0 + 0.1)
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position = Vector3(0, 0.33, 0)
	rb.add_child(cs)
	# A small ball for the legs, so the feet don't sink through the floor.
	var legs := SphereShape3D.new()
	legs.radius = 0.15
	var ls := CollisionShape3D.new()
	ls.shape = legs
	ls.position = Vector3(0, -0.3, 0.06)
	rb.add_child(ls)
	_ragdoll_parts.append(rb)
	# Anything the body starts inside (the table edge, a neighbour) is passed through until the
	# bean is clear of it, instead of being shoved out at speed.
	_push_clear(rb)
	for body in _overlapping(rb):
		rb.add_collision_exception_with(body)
		_pass_through.append(body)
	if _hat and is_instance_valid(_hat):
		var hat_rb := RigidBody3D.new()
		hat_rb.collision_layer = L_RAGDOLL
		hat_rb.collision_mask = L_WORLD | L_PROPS
		hat_rb.mass = 0.2
		hat_rb.continuous_cd = true
		hat_rb.angular_damp = 1.0
		var hgt := _hat.global_transform
		_detached.append({"node": _hat, "parent": _hat.get_parent(), "local": _hat.transform})
		world.add_child(hat_rb)
		hat_rb.global_transform = hgt.orthonormalized()
		_hat.get_parent().remove_child(_hat)
		hat_rb.add_child(_hat)
		_hat.transform = Transform3D(Basis.from_scale(hgt.basis.get_scale()), Vector3.ZERO)
		RoomBuilder._box_shape(hat_rb, Vector3(0.26, 0.16, 0.26), Vector3(0, 0.08, 0))
		hat_rb.add_collision_exception_with(rb)
		_ragdoll_parts.append(hat_rb)
		_launch(hat_rb, Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)), Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)))
	_corpse_head = _head
	if not temporary:
		_corpse_eyes = _eyes.duplicate()
		for e in _corpse_eyes:
			e["vel"] = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	else:
		_corpse_eyes = _eyes
	return {"body": rb}


## The moving bodies (chairs, other ragdolls) that `rb`'s shapes overlap; static ones too with
## `include_static`.
func _overlapping(rb: RigidBody3D, include_static: bool = false) -> Array[PhysicsBody3D]:
	var out: Array[PhysicsBody3D] = []
	if not rb.is_inside_tree():
		return out
	var space := rb.get_world_3d().direct_space_state
	for c in rb.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.collision_mask = L_WORLD | L_RAGDOLL
		q.exclude = [rb.get_rid()]
		for hit: Dictionary in space.intersect_shape(q, 16):
			var body := hit.get("collider") as PhysicsBody3D
			if body and body != chair and not out.has(body) and (include_static or not body is StaticBody3D):
				out.append(body)
	return out


## Slides a fresh body back out of the room's static geometry (the table edge), away from the
## table, so the physics never has to shove it out.
func _push_clear(rb: RigidBody3D) -> void:
	var back := global_basis * Vector3(0, 0, -1)
	for i in 10:
		var hits := _overlapping(rb, true).filter(func(b: PhysicsBody3D) -> bool: return b is StaticBody3D)
		if hits.is_empty():
			return
		rb.global_position += back * 0.04 + Vector3.UP * 0.01


## Sets a ragdoll's motion directly (a freshly made body ignores impulses until its first step).
func _launch(rb: RigidBody3D, lin: Vector3, ang: Vector3) -> void:
	rb.linear_velocity = lin
	rb.angular_velocity = ang


## The rigid body while down (null otherwise).
func ragdoll_body() -> RigidBody3D:
	return _ragdoll_parts[0] if not _ragdoll_parts.is_empty() and is_instance_valid(_ragdoll_parts[0]) else null


## While ragdolling: arms and legs hang towards the ground with a lag, so they swing and trail as
## the bean tumbles, and settle limp once it stops. No joints, so nothing can jitter or tangle.
func _flop(delta: float) -> void:
	if _ragdoll_parts.is_empty() or _recovering:
		return
	var rb := _ragdoll_parts[0]
	if not is_instance_valid(rb):
		return
	_flop_t += delta
	_pass_check -= delta
	if _pass_check <= 0.0 and not _pass_through.is_empty():
		_pass_check = 0.1
		var still := _overlapping(rb)
		for body in _pass_through.duplicate():
			if not is_instance_valid(body):
				_pass_through.erase(body)
			elif not still.has(body):
				rb.remove_collision_exception_with(body)
				_pass_through.erase(body)
	var spin := rb.angular_velocity.length() + rb.linear_velocity.length() * 0.5
	var w := 1.0 - exp(-(5.0 if alive else 3.0) * delta)
	for l: Array in _flop_limbs:
		var pv: Node3D = l[0]
		var bend: Node3D = l[2]
		if pv == null or not is_instance_valid(pv) or not pv.is_inside_tree():
			continue
		var side: float = l[1]
		var down := (pv.get_parent() as Node3D).global_basis.inverse() * Vector3.DOWN
		var wiggle := Vector3(sin(_flop_t * 13.0 + side), cos(_flop_t * 11.0 - side), sin(_flop_t * 9.0)) * minf(spin * 0.08, 0.6)
		var want := _aim(down.normalized() + Vector3(side * float(l[3]), 0, 0.15) + wiggle)
		pv.quaternion = pv.quaternion.slerp(want, w)
		if bend and is_instance_valid(bend):
			var knee := 0.35 + sin(_flop_t * 7.0 + side) * minf(spin * 0.1, 0.5)
			bend.quaternion = bend.quaternion.slerp(Quaternion(Vector3.RIGHT, -knee if l[4] else knee), w)


## Dead: the pupils become little X's.
func _x_eyes() -> void:
	for e in _eyes:
		var pupil := e["node"] as Node3D
		if pupil == null or not is_instance_valid(pupil):
			continue
		pupil.visible = false
		var eye := pupil.get_parent() as Node3D
		if eye.get_node_or_null("X"):
			continue
		var x := Node3D.new()
		x.name = "X"
		x.position = Vector3(0, 0, 0.03)
		eye.add_child(x)
		for a in [45.0, -45.0]:
			Mats.mesh(x, Mats.box(Vector3(0.11, 0.024, 0.012)), Mats.solid(Color("1d1128"), 0.4), Vector3.ZERO, Vector3(0, 0, a))
		if is_local:
			_set_layers(x, LOCAL_LAYER)


## Back to the seat after a knockdown: every part glides home, then the rig takes over again.
func _recover() -> void:
	wobble(1.0)
	if not _ragdolling or not alive:
		return
	_recovering = true
	for rb in _ragdoll_parts:
		if is_instance_valid(rb):
			rb.freeze = true
	_recover_tw = create_tween().set_parallel(true)
	for i in range(_detached.size() - 1, -1, -1):
		var d: Dictionary = _detached[i]
		var node: Node3D = d["node"]
		var parent: Node3D = d["parent"]
		if not is_instance_valid(node) or not is_instance_valid(parent):
			continue
		var gt := node.global_transform
		node.get_parent().remove_child(node)
		parent.add_child(node)
		node.global_transform = gt
		_recover_tw.tween_property(node, "transform", d["local"], 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recover_tw.chain().tween_callback(func() -> void:
		for rb in _ragdoll_parts:
			if is_instance_valid(rb):
				rb.queue_free()
		_ragdoll_parts.clear()
		_detached.clear()
		_ragdolling = false
		_recovering = false
		_corpse_head = null
		if chair and is_instance_valid(chair) and _chair_home != Transform3D():
			if chair is RigidBody3D:
				(chair as RigidBody3D).freeze = true
			chair.transform = _chair_home
		_state = &"sit"
		_set_mood(&"angry", 1.5)
		say(["HOW DARE YOU", "MY DIGNITY", "I'M FINE", "ow.", "RUDE!!"][randi() % 5], 1.4)
		Sfx.play_at(&"boing", head_position(), -3.0)
		recovered.emit(self))
	Sfx.play_at(&"whoosh", head_position(), -6.0)


func _splash_table() -> void:
	splashed_table.emit(self)


## Tip the chair over with physics (it snaps back when they sit / the ghost appears).
func _knock_chair() -> void:
	if chair == null or not is_instance_valid(chair):
		return
	if _chair_home == Transform3D():
		_chair_home = chair.transform
	if chair is RigidBody3D:
		var rb := chair as RigidBody3D
		if not rb.freeze:
			return
		rb.freeze = false
		rb.apply_central_impulse(chair.global_transform.basis * Vector3(0, 1.5, -3.0))
		rb.apply_torque_impulse(chair.global_transform.basis * Vector3(-1.2, randf_range(-0.5, 0.5), 0))


func _confetti(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 120
	p.lifetime = 2.4
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -3.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.04)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color("ff5c8a"))
	g.add_point(0.33, Color("ffc93c"))
	g.add_point(0.66, Color("4cc9f0"))
	g.set_color(g.get_point_count() - 1, Color("3ddc97"))
	p.color_initial_ramp = g
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## A translucent guest floats up above the chair; the body stays where it fell.
func become_ghost() -> void:
	if is_ghost:
		return
	if _dying != &"":
		var style := _dying
		_dying = &""
		_shake = 0.0
		_finish_death(style, _go_ragdoll(false))
	if _recovering and _recover_tw and _recover_tw.is_valid():
		_recover_tw.kill()
	alive = false
	is_ghost = true
	_release_held(false)
	# The corpse keeps its parts; the old rig (whatever is left of it) goes.
	if _rig and is_instance_valid(_rig):
		_rig.queue_free()
	_joints.clear()
	_detached.clear()
	_ragdolling = false
	_recovering = false
	if chair and is_instance_valid(chair) and _chair_home != Transform3D():
		if chair is RigidBody3D:
			(chair as RigidBody3D).freeze = true
		chair.transform = _chair_home
	_build_rig(true)
	_state = &"ghost"
	_mood = &"normal"
	_name_tag.modulate = Color(0.75, 0.9, 1.0, 0.9)
	_title_tag.text = "ghost"
	for l in [_bubble, _mic]:
		(l as Label3D).position.y = 3.4
	if is_local:
		_rig.visible = false
	Sfx.play_at(&"ghost", global_position + Vector3(0, 1.5, 0), -4.0)


func _ghostify(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = Mats.ghost()
	for c in n.get_children():
		_ghostify(c)


## The wardrobe resets its preview.
func clear_corpse() -> void:
	for rb in _ragdoll_parts:
		if is_instance_valid(rb):
			rb.queue_free()
	_ragdoll_parts.clear()
	for j in _joints:
		if is_instance_valid(j):
			j.queue_free()
	_joints.clear()
