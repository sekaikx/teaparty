class_name Guest
extends Node3D
## A tea party guest: a chunky, pillowy little person, big square-ish head with googly eyes,
## ears, nose and a hair tuft; a barrel torso in their shirt colour; stubby shorts; upper arms,
## forearms and white mitten hands; thighs, shins and big boots. Every part is a "soft box"
## (Mats.softbox), so the silhouette reads as a person, not a capsule, and it tumbles like a
## sack of cushions.
##
## Poses are procedural (shoulders / elbows / hips / knees / neck blended every frame from a
## state + a gesture). Physics is part of the act:
##   knockdown()  a cake to the face topples you: 11 rigid bodies on cone-twist joints flop out
##                of the chair, then you snap back into your seat (with a boing).
##   die()        poisoned: turn green, shake, then ragdoll for good; the body stays on the floor.
##   become_ghost()  a translucent version floats up above the chair.

const SIT_BACK := 0.30          # the seated body sits this far behind the root (the chair goes there)
const LOCAL_LAYER := 1 << 19    # parts your own first-person camera leaves out
const SEAT_Y := 0.64            # pelvis height when seated
const STAND_Y := 0.86           # pelvis height when standing
const HEAD_R := 0.29            # half-size of the head (face features sit on +Z at this depth)
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
var _brows: Array[MeshInstance3D] = []
var _eyes: Array[Dictionary] = []
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


func _mat(c: Color, rough: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	# A bold ink outline (inverted hull), the comic look.
	m.next_pass = Mats.outline()
	return m


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
	var shirt_col: Color = skin.get("body", Color("ffe3b8"))
	var accent: Color = skin.get("accent", Color("ff8fab"))
	var tone: Color = TONES[_hash() % TONES.size()]
	var hair_col: Color = HAIR[(_hash() / 7) % HAIR.size()]
	var build: Array = BUILDS[(_hash() / 13) % BUILDS.size()]
	var belly: float = build[0]
	var head_k: float = build[1]
	var outfit: StringName = OUTFITS[(_hash() / 29) % OUTFITS.size()]
	var hairstyle: StringName = HAIRSTYLES[(_hash() / 61) % HAIRSTYLES.size()]
	var g := Mats.ghost()
	_shirt = _mat(shirt_col)
	_skin_mat = _mat(tone, 0.6)
	var shirt: Material = g if ghost else _shirt
	var skin_m: Material = g if ghost else _skin_mat
	var pants: Material = g if ghost else _mat(shirt_col.darkened(0.55).lerp(Color("2d2a4a"), 0.35), 0.7)
	var glove: Material = g if ghost else _mat(Color("fbfaf4"), 0.5)
	var boot: Material = g if ghost else _mat(Color("3a2a30"), 0.6)
	var ink := Mats.solid(Color("1d1128"), 0.4)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	model = _rig
	# Pelvis (shorts) and legs.
	_hips = _pivot(_rig, Vector3(0, SEAT_Y, -SIT_BACK), "Hips")
	_part(_hips, Vector3(0.5 * belly, 0.27, 0.33), pants, Vector3.ZERO, 0.4, Vector2(1.06, 1.0))
	if not ghost and outfit == &"dress":
		# A flared skirt over the hips (the legs still move freely under it).
		Mats.mesh(_hips, Mats.softbox(Vector3(0.62 * belly, 0.34, 0.46), 0.5, Vector2(0.72, 0.8), 0.04), _mat(shirt_col.darkened(0.15)), Vector3(0, -0.08, 0.01))
	if not ghost:
		_hip_l = _pivot(_hips, Vector3(0.13, -0.07, 0), "HipL")
		_hip_r = _pivot(_hips, Vector3(-0.13, -0.07, 0), "HipR")
		for hp: Node3D in [_hip_l, _hip_r]:
			_part(hp, Vector3(0.22, 0.38, 0.23), pants, Vector3(0, -0.16, 0), 0.4, Vector2(1.12, 1.1))
			var kn := _pivot(hp, Vector3(0, -0.34, 0), "Knee")
			_part(kn, Vector3(0.17, 0.36, 0.18), skin_m, Vector3(0, -0.16, 0), 0.45, Vector2(1.15, 1.15))
			var an := _pivot(kn, Vector3(0, -0.34, 0), "Ankle")
			_part(an, Vector3(0.2, 0.15, 0.34), boot, Vector3(0, -0.05, 0.07), 0.35, Vector2(0.95, 0.9))
			if hp == _hip_l:
				_kn_l = kn
			else:
				_kn_r = kn
	else:
		_hip_l = null
		_hip_r = null
		_kn_l = null
		_kn_r = null
		Mats.mesh(_hips, Mats.cylinder(0.24, 0.02, 0.6, 16), g, Vector3(0, -0.4, -0.05))
	# Torso: a barrel chest in the shirt colour, collar and a bow tie in the accent colour.
	_waist = _pivot(_hips, Vector3(0, 0.1, 0), "Waist")
	_part(_waist, Vector3(0.6 * belly, 0.58, 0.4 * belly), shirt, Vector3(0, 0.29, 0), 0.56, Vector2(1.08, 0.96), 0.13)
	if not ghost:
		_build_outfit(outfit, shirt_col, accent, belly)
	# Arms.
	_sh_l = _pivot(_waist, Vector3(0.36, 0.48, 0), "ShoulderL")
	_sh_r = _pivot(_waist, Vector3(-0.36, 0.48, 0), "ShoulderR")
	for sh: Node3D in [_sh_l, _sh_r]:
		_part(sh, Vector3(0.19, 0.34, 0.19), shirt, Vector3(0, -0.13, 0), 0.5, Vector2(1.15, 1.15))
		var el := _pivot(sh, Vector3(0, -0.3, 0), "Elbow")
		_part(el, Vector3(0.14, 0.3, 0.14), skin_m, Vector3(0, -0.13, 0), 0.5)
		var hand := _pivot(el, Vector3(0, -0.29, 0), "Hand")
		_part(hand, Vector3(0.21, 0.2, 0.15), glove, Vector3(0, -0.08, 0.01), 0.55, Vector2(1.0, 1.0), 0.1)
		var side := 1.0 if sh == _sh_l else -1.0
		_part(hand, Vector3(0.07, 0.11, 0.07), glove, Vector3(-0.1 * side, -0.02, 0.05), 0.6)
		if sh == _sh_l:
			_el_l = el
		else:
			_el_r = el
			_hand_r = hand
	# Neck and the big head.
	_neck = _pivot(_waist, Vector3(0, 0.56, 0), "Neck")
	_part(_neck, Vector3(0.17, 0.14, 0.17), skin_m, Vector3(0, 0.03, 0), 0.6)
	_head = _pivot(_neck, Vector3(0, 0.08, 0), "Head")
	head_anchor = _head
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, 0.27, 0)
	_head.add_child(face)
	_part(face, Vector3(0.6, 0.58, 0.54), skin_m, Vector3.ZERO, 0.62, Vector2(0.95, 0.95), 0.06)
	face.scale = Vector3.ONE * head_k
	if not ghost:
		for side in [1.0, -1.0]:
			_part(face, Vector3(0.07, 0.13, 0.09), skin_m, Vector3(0.3 * side, -0.01, -0.01), 0.6)
			# Warm cheeks.
			Mats.mesh(face, Mats.sphere(0.05), Mats.solid(tone.lerp(Color("ff6f8a"), 0.45), 0.8), Vector3(0.19 * side, -0.08, HEAD_R - 0.035), Vector3.ZERO, Vector3(1.3, 0.8, 0.3))
		_part(face, Vector3(0.1, 0.1, 0.08), _mat(tone.darkened(0.12)), Vector3(0, -0.04, HEAD_R - 0.01), 0.7)
		_build_hair(face, hairstyle, _mat(hair_col, 0.8), 1.0)
	# Googly eyes.
	_eyes.clear()
	for side in [1.0, -1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.12 * side, 0.07, HEAD_R - 0.02)
		face.add_child(eye)
		Mats.mesh(eye, Mats.sphere(0.095, 0.19, 16), Mats.solid(Color.WHITE, 0.2), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55))
		var pupil := Mats.mesh(eye, Mats.sphere(0.05, 0.1, 12), ink, Vector3(0, 0, 0.04), Vector3.ZERO, Vector3(1, 1, 0.5))
		_eyes.append({"node": pupil, "off": Vector2(randf_range(-0.3, 0.3), -0.3), "vel": Vector2.ZERO})
	_brows.clear()
	for side in [1.0, -1.0]:
		_brows.append(Mats.mesh(face, Mats.softbox(Vector3(0.13, 0.035, 0.03), 0.5), ink if not ghost else g, Vector3(0.12 * side, 0.19, HEAD_R)))
	_mouth = Mats.mesh(face, Mats.sphere(0.06, 0.12, 12), Mats.solid(Color("3b0d1e"), 0.5), Vector3(0, -0.14, HEAD_R - 0.02), Vector3.ZERO, Vector3(1.9, 0.45, 0.4))
	if not ghost:
		_build_face(face, StringName(str(look.get("face", &"none"))))
	var hat := Hats.build(StringName(str(look.get("hat", &"none"))))
	if hat:
		hat.scale = Vector3.ONE * 0.56
		hat.position = Vector3(0, 0.24, -0.02)
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
		sph.radius = 0.34
		hs.shape = sph
		_hitbox.add_child(hs)
		face.add_child(_hitbox)
		_body_box = StaticBody3D.new()
		_body_box.collision_layer = L_HITBOX
		_body_box.collision_mask = 0
		_body_box.set_meta(&"guest", self)
		RoomBuilder._box_shape(_body_box, Vector3(0.6, 0.6, 0.38), Vector3(0, 0.29, 0))
		_waist.add_child(_body_box)
	if ghost:
		_set_shadows(_rig, false)
	_pose.clear()
	if is_local:
		_apply_local_layers()


## The outfit over the barrel chest: a bow tie, a waistcoat with buttons, a dress collar or a
## striped cardigan. Always the colours from the wardrobe ("body" + "accent").
func _build_outfit(outfit: StringName, shirt_col: Color, accent: Color, belly: float) -> void:
	var acc := _mat(accent)
	var dark := _mat(shirt_col.darkened(0.35))
	var vest := _mat(accent.darkened(0.25).lerp(Color("3a2a4a"), 0.3))
	match outfit:
		&"waistcoat":
			# The waistcoat: a darker wrap over the front and sides, open in a V at the top.
			Mats.mesh(_waist, Mats.softbox(Vector3(0.62 * belly, 0.44, 0.41 * belly), 0.52, Vector2(1.06, 0.97), 0.13), vest, Vector3(0, 0.24, 0.002))
			for side in [1.0, -1.0]:
				Mats.mesh(_waist, Mats.softbox(Vector3(0.1, 0.2, 0.04), 0.4, Vector2(0.4, 1.0)), _shirt, Vector3(0.05 * side, 0.46, 0.2 * belly), Vector3(0, 0, 25 * side))
			for i in 3:
				Mats.mesh(_waist, Mats.sphere(0.022), Mats.gold(), Vector3(0.0, 0.16 + i * 0.1, 0.215 * belly))
			# A pocket watch chain.
			Mats.mesh(_waist, Mats.torus(0.05, 0.062, 12), Mats.gold(), Vector3(0.12 * belly, 0.2, 0.2 * belly), Vector3(80, 0, 20))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.14, 0.06, 0.05), 0.5), acc, Vector3(0, 0.5, 0.2))
		&"dress":
			# A round collar and a ribbon.
			Mats.mesh(_waist, Mats.torus(0.12, 0.17, 18), _mat(Color("fff6e6")), Vector3(0, 0.56, 0.02), Vector3(8, 0, 0))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.52 * belly, 0.06, 0.36 * belly), 0.5), acc, Vector3(0, 0.05, 0))
			Mats.mesh(_waist, Mats.sphere(0.045), acc, Vector3(0, 0.07, 0.2 * belly))
		&"cardigan":
			# Three bands around the belly (sized past its curve so they show) and a button strip.
			for i in 3:
				var y := 0.14 + i * 0.13
				var bulge := 1.0 + 0.13 * (1.0 - pow((y - 0.29) / 0.29, 2.0))
				Mats.mesh(_waist, Mats.softbox(Vector3(0.63 * belly * bulge, 0.05, 0.43 * belly * bulge), 0.5, Vector2(1.03, 1.0)), acc, Vector3(0, y, 0))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.06, 0.5, 0.05), 0.5), dark, Vector3(0, 0.27, 0.225 * belly))
			for i in 3:
				Mats.mesh(_waist, Mats.sphere(0.022), _mat(Color("fff6e6")), Vector3(0, 0.15 + i * 0.12, 0.25 * belly))
		_:
			# The classic: belt and a bow tie.
			Mats.mesh(_waist, Mats.softbox(Vector3(0.5 * belly, 0.05, 0.34 * belly), 0.5), _mat(accent.darkened(0.2)), Vector3(0, 0.03, 0))
			Mats.mesh(_waist, Mats.softbox(Vector3(0.1, 0.07, 0.05), 0.5), acc, Vector3(0, 0.5, 0.2))
			for side in [1.0, -1.0]:
				Mats.mesh(_waist, Mats.softbox(Vector3(0.1, 0.09, 0.04), 0.4, Vector2(0.5, 1.0)), acc, Vector3(0.07 * side, 0.5, 0.2), Vector3(0, 0, 90 * side))


## Hairstyles (hats sit over the top; the back and sides still show).
func _build_hair(face: Node3D, style: StringName, hair: Material, k: float) -> void:
	match style:
		&"side_part":
			_part(face, Vector3(0.62 * k, 0.14, 0.52 * k), hair, Vector3(0.02, 0.26 * k, -0.02), 0.45, Vector2(0.85, 0.9))
			_part(face, Vector3(0.22, 0.12, 0.3), hair, Vector3(0.2 * k, 0.24 * k, 0.12), 0.6)
		&"bun":
			_part(face, Vector3(0.6 * k, 0.12, 0.5 * k), hair, Vector3(0, 0.26 * k, -0.04), 0.5, Vector2(0.8, 0.85))
			Mats.mesh(face, Mats.sphere(0.12), hair, Vector3(0, 0.28 * k, -0.24 * k))
		&"curls":
			for i in 7:
				var a := TAU * i / 7.0
				Mats.mesh(face, Mats.sphere(0.1), hair, Vector3(cos(a) * 0.2 * k, 0.27 * k + sin(a * 2.0) * 0.02, sin(a) * 0.16 * k - 0.04))
		&"bald":
			for side in [1.0, -1.0]:
				_part(face, Vector3(0.08, 0.16, 0.2), hair, Vector3(0.29 * k * side, 0.02, -0.08), 0.6)
		&"long":
			_part(face, Vector3(0.62 * k, 0.14, 0.52 * k), hair, Vector3(0, 0.26 * k, -0.04), 0.45, Vector2(0.85, 0.9))
			_part(face, Vector3(0.6 * k, 0.5, 0.14), hair, Vector3(0, -0.02, -0.25 * k), 0.5, Vector2(1.0, 0.9))
		_:
			_part(face, Vector3(0.58 * k, 0.14, 0.4 * k), hair, Vector3(0, 0.25 * k, -0.08), 0.5, Vector2(0.8, 0.9))
			_part(face, Vector3(0.14, 0.12, 0.12), hair, Vector3(0.08, 0.32 * k, 0.08), 0.6)


func _set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_shadows(c, on)


func _build_face(face: Node3D, id: StringName) -> void:
	var z := HEAD_R
	match id:
		&"moustache":
			var m := Mats.solid(Color("3b2416"), 0.7)
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.sphere(0.065, 0.13), m, Vector3(0.07 * side, -0.09, z + 0.02), Vector3(0, 0, -22 * side), Vector3(1.6, 0.6, 0.6))
				Mats.mesh(face, Mats.sphere(0.032), m, Vector3(0.15 * side, -0.05, z - 0.01))
		&"monocle":
			Mats.mesh(face, Mats.torus(0.09, 0.11, 20), Mats.gold(), Vector3(-0.12, 0.07, z + 0.04), Vector3(90, 0, 0))
			Mats.mesh(face, Mats.cylinder(0.006, 0.006, 0.3, 6), Mats.gold(), Vector3(-0.21, -0.07, z - 0.01), Vector3(0, 0, 25))
		&"glasses":
			var gl := Mats.solid(Color("2a1f33"), 0.4)
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.torus(0.095, 0.115, 20), gl, Vector3(0.12 * side, 0.07, z + 0.04), Vector3(90, 0, 0))
			Mats.mesh(face, Mats.box(Vector3(0.05, 0.015, 0.015)), gl, Vector3(0, 0.08, z + 0.06))
		&"blush":
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.sphere(0.055), Mats.solid(Color("ff7aa2"), 0.8), Vector3(0.2 * side, -0.07, z - 0.03), Vector3.ZERO, Vector3(1.2, 0.7, 0.3))
		&"nose":
			Mats.mesh(face, Mats.sphere(0.065), Mats.solid(Color("ff2e4d"), 0.2), Vector3(0, -0.03, z + 0.05))
		&"shades":
			var s := Mats.solid(Color("111118"), 0.1, 0.4)
			for side in [1.0, -1.0]:
				Mats.mesh(face, Mats.softbox(Vector3(0.16, 0.1, 0.03), 0.4), s, Vector3(0.12 * side, 0.075, z + 0.06))
			Mats.mesh(face, Mats.box(Vector3(0.1, 0.02, 0.02)), s, Vector3(0, 0.1, z + 0.06))
		&"beard":
			Mats.mesh(face, Mats.softbox(Vector3(0.46, 0.34, 0.2), 0.6, Vector2(1.1, 1.0)), Mats.solid(Color("f2f2f2"), 0.9), Vector3(0, -0.3, z - 0.06))


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


func show_tags(on: bool) -> void:
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
		return _head.global_transform * Vector3(0, 0.27, 0)
	return global_position + Vector3(0, 1.6, 0)


func is_down() -> bool:
	return _ragdolling


# ---------------------------------------------------------------- posing

## Upper-body gesture: cheer, no, point, think, yes, plead, laugh, sip, interact, shrug, wave, spook.
func gesture(kind: StringName, seconds: float = -1.0) -> void:
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
	if _shake > 0.0:
		p["twist"] = sin(_t * 60.0) * 0.14 * _shake
		p["head"] += Vector3(sin(_t * 47.0), sin(_t * 53.0), sin(_t * 41.0)) * 0.22 * _shake
		_arm(p, "l", Vector3(0.9, 0.2 + sin(_t * 30.0), 0.3), 1.0 + sin(_t * 25.0))
		_arm(p, "r", Vector3(-0.9, 0.2 - sin(_t * 31.0), 0.3), 1.0 + sin(_t * 27.0))
	return p


func _process(delta: float) -> void:
	_t += delta
	if not _ragdoll_parts.is_empty() and _corpse_head:
		_googly(_corpse_head, _corpse_eyes, delta)
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
		_brows[i].position.y = 0.19 + lift + (0.03 if _mood == &"sly" and i == 0 else 0.0)
	_blink -= delta
	if _blink <= 0.0:
		_blink = randf_range(2.0, 5.0)
		for e in _eyes:
			var eye: Node3D = (e["node"] as Node3D).get_parent()
			var tw := eye.create_tween()
			tw.tween_property(eye, "scale:y", 0.1, 0.06)
			tw.tween_property(eye, "scale:y", 1.0, 0.08)


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
			node.position = Vector3(off.x * 0.045, off.y * 0.045, 0.04)


## A cake to the face without toppling: the head snaps back and the eyes spin.
func bonk(from_dir: Vector3, frosting: Color) -> void:
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
	var blob := Mats.mesh(face, Mats.sphere(0.11), Mats.solid(frosting, 0.6), Vector3(randf_range(-0.14, 0.14), randf_range(-0.08, 0.14), HEAD_R), Vector3.ZERO, Vector3(1.3, 1.0, 0.45))
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
	bodies["head"].apply_central_impulse(dir * 3.5 + Vector3.UP * 1.0)
	bodies["torso"].apply_central_impulse(dir * 5.0 + Vector3.UP * 1.5)
	bodies["pelvis"].apply_central_impulse(dir * 2.0)
	for k in ["fore_l", "fore_r"]:
		bodies[k].apply_central_impulse(Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
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
	if bodies.is_empty():
		for rb in _ragdoll_parts:
			if is_instance_valid(rb):
				rb.apply_central_impulse(Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
		return
	var away := global_transform.basis * Vector3(0, 0, -1)
	var up := Vector3.UP
	var torso: RigidBody3D = bodies["torso"]
	var head: RigidBody3D = bodies["head"]
	var pelvis: RigidBody3D = bodies["pelvis"]
	match style:
		&"keel":
			torso.apply_central_impulse(-away * 5.0 + up * 1.5)
			head.apply_central_impulse(-away * 2.5)
			_splash_table()
		&"spin":
			pelvis.apply_central_impulse(up * 6.0)
			torso.apply_torque_impulse(Vector3(0, 8.0, 0))
		&"confetti":
			_confetti(head.global_position)
			Sfx.play_at(&"magic", head.global_position)
			torso.apply_central_impulse(up * 7.0 + away * 2.0)
		&"ascend":
			for rb in _ragdoll_parts:
				rb.gravity_scale = -0.12
			torso.apply_central_impulse(up * 1.5)
		&"yeet":
			torso.apply_central_impulse(away * 18.0 + up * 9.0)
			pelvis.apply_central_impulse(away * 10.0 + up * 5.0)
			head.apply_central_impulse(away * 4.0)
		&"stagger":
			torso.apply_torque_impulse(Vector3(randf_range(-3, 3), 5.0, randf_range(-3, 3)))
			torso.apply_central_impulse(away * 3.0 + up)
		_:
			torso.apply_central_impulse(away * 5.0 + up * 2.0)
			head.apply_central_impulse(away * 1.8 + up * 0.6)
	Sfx.play_at(&"slide_whistle", head.global_position, -2.0 if style == &"yeet" else -5.0)
	var thud := create_tween()
	thud.tween_interval(0.7)
	thud.tween_callback(func() -> void:
		if is_instance_valid(torso):
			Sfx.play_at(&"thud", torso.global_position))


## Turns the rig into rigid bodies on cone-twist joints. `temporary` keeps a record so
## _recover() can put every part back. Returns the bodies by name.
func _go_ragdoll(temporary: bool) -> Dictionary:
	var world := get_parent() as Node3D
	if world == null or _rig == null or not is_instance_valid(_rig) or _hip_l == null or _ragdolling:
		return {}
	_ragdolling = true
	_gesture = &""
	_release_held()
	_knock_chair()
	_detached.clear()
	var bodies := {}
	var make := func(node: Node3D, key: String, size: Vector3, offset: Vector3, mass: float) -> RigidBody3D:
		var rb := RigidBody3D.new()
		rb.collision_layer = L_RAGDOLL
		rb.collision_mask = L_WORLD | L_RAGDOLL | L_PROPS
		rb.mass = mass
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.25
		pm.friction = 0.9
		rb.physics_material_override = pm
		rb.angular_damp = 2.0
		rb.linear_damp = 0.25
		var gt := node.global_transform
		_detached.append({"node": node, "parent": node.get_parent(), "local": node.transform})
		world.add_child(rb)
		rb.global_transform = gt.orthonormalized()
		node.get_parent().remove_child(node)
		rb.add_child(node)
		node.transform = Transform3D(Basis.from_scale(gt.basis.get_scale()), Vector3.ZERO)
		RoomBuilder._box_shape(rb, size, offset)
		bodies[key] = rb
		_ragdoll_parts.append(rb)
		return rb
	if _hat and is_instance_valid(_hat):
		var hat_rb: RigidBody3D = make.call(_hat, "hat", Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0), 0.2)
		hat_rb.apply_central_impulse(Vector3(randf_range(-0.5, 0.5), 1.4, randf_range(-0.5, 0.5)))
		hat_rb.apply_torque_impulse(Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)))
	make.call(_head, "head", Vector3(0.56, 0.54, 0.5), Vector3(0, 0.27, 0), 1.6)
	make.call(_el_l, "fore_l", Vector3(0.14, 0.44, 0.14), Vector3(0, -0.21, 0), 0.5)
	make.call(_el_r, "fore_r", Vector3(0.14, 0.44, 0.14), Vector3(0, -0.21, 0), 0.5)
	make.call(_sh_l, "up_l", Vector3(0.15, 0.3, 0.15), Vector3(0, -0.14, 0), 0.6)
	make.call(_sh_r, "up_r", Vector3(0.15, 0.3, 0.15), Vector3(0, -0.14, 0), 0.6)
	make.call(_kn_l, "shin_l", Vector3(0.17, 0.42, 0.22), Vector3(0, -0.2, 0.03), 0.8)
	make.call(_kn_r, "shin_r", Vector3(0.17, 0.42, 0.22), Vector3(0, -0.2, 0.03), 0.8)
	make.call(_hip_l, "thigh_l", Vector3(0.2, 0.34, 0.22), Vector3(0, -0.16, 0), 1.0)
	make.call(_hip_r, "thigh_r", Vector3(0.2, 0.34, 0.22), Vector3(0, -0.16, 0), 1.0)
	make.call(_waist, "torso", Vector3(0.56, 0.6, 0.34), Vector3(0, 0.3, 0), 4.0)
	make.call(_hips, "pelvis", Vector3(0.46, 0.25, 0.3), Vector3.ZERO, 3.0)
	# Joints: [parent body, child body, pivot node (position), swing, twist]
	var spec := [
		["torso", "head", bodies["head"], 45.0, 30.0],
		["torso", "up_l", bodies["up_l"], 85.0, 40.0], ["torso", "up_r", bodies["up_r"], 85.0, 40.0],
		["up_l", "fore_l", bodies["fore_l"], 70.0, 10.0], ["up_r", "fore_r", bodies["fore_r"], 70.0, 10.0],
		["pelvis", "thigh_l", bodies["thigh_l"], 65.0, 20.0], ["pelvis", "thigh_r", bodies["thigh_r"], 65.0, 20.0],
		["thigh_l", "shin_l", bodies["shin_l"], 60.0, 5.0], ["thigh_r", "shin_r", bodies["shin_r"], 60.0, 5.0],
		["pelvis", "torso", bodies["torso"], 30.0, 20.0],
	]
	_joints.clear()
	for sp: Array in spec:
		var a: RigidBody3D = bodies[sp[0]]
		var b: RigidBody3D = bodies[sp[1]]
		var j := ConeTwistJoint3D.new()
		world.add_child(j)
		# Twist axis (X) along the child limb.
		var along := (b.global_basis * Vector3.DOWN).normalized()
		if sp[1] == "head" or sp[1] == "torso":
			along = (b.global_basis * Vector3.UP).normalized()
		var side := along.cross(Vector3.FORWARD)
		if side.length() < 0.1:
			side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		j.global_transform = Transform3D(Basis(along, side, along.cross(side).normalized()), b.global_position)
		j.node_a = j.get_path_to(a)
		j.node_b = j.get_path_to(b)
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(sp[3]))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(sp[4]))
		j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		j.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 1.0)
		_joints.append(j)
	if not temporary:
		_corpse_head = _head
		_corpse_eyes = _eyes.duplicate()
		for e in _corpse_eyes:
			e["vel"] = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	else:
		_corpse_head = _head
		_corpse_eyes = _eyes
	return bodies


## Back to the seat after a knockdown: every part glides home, then the rig takes over again.
func _recover() -> void:
	if not _ragdolling or not alive:
		return
	_recovering = true
	for rb in _ragdoll_parts:
		if is_instance_valid(rb):
			rb.freeze = true
	for j in _joints:
		if is_instance_valid(j):
			j.queue_free()
	_joints.clear()
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
