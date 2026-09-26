class_name Guest
extends Node3D
## A tea party guest: a wobbly jelly-bean body with white glove hands, googly eyes that slosh
## around when the head moves, a mouth that flaps when they talk, eyebrows for their mood, a hat
## and a face accessory. Everything is procedural: no rig, no imported animation.
##
## Poses are blended every frame from a base state (sit / stand / drink / ghost) plus a gesture
## (cheer, point, plead, laugh...). When a guest dies they turn green, shake, and then every body
## part becomes a RigidBody3D pinned to its neighbours: a real ragdoll that flops over chairs,
## tables and other corpses. The ghost that rises afterwards is a fresh translucent bean.

const SIT_BACK := 0.30          # the seated body sits this far behind the root (the chair goes there)
const LOCAL_LAYER := 1 << 19    # parts your own first-person camera leaves out
const SEAT_Y := 0.52
const BODY_R := 0.3
const BODY_H := 0.92
const HEAD_R := 0.3
const ARM_L := 0.42
const LEG_L := 0.5
## Physics layers: 1 world, 16 ragdolls, 32 flying props, 64 living guests' hitboxes.
const L_WORLD := 1
const L_RAGDOLL := 16
const L_PROPS := 32
const L_HITBOX := 64

## Faceplants send the table's cups flying (the table view listens for this).
signal splashed_table(guest: Guest)

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

var _rig: Node3D
var _hips: Node3D
var _chest: Node3D
var _body: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hand_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _neck: Node3D
var _head: Node3D
var _mouth: MeshInstance3D
var _brows: Array[MeshInstance3D] = []
var _eyes: Array[Dictionary] = []
var _body_mat: StandardMaterial3D
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
var _ragdoll_parts: Array[RigidBody3D] = []
var _corpse_head: Node3D
var _corpse_eyes: Array[Dictionary] = []
var _hl := false
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
	cap.radius = 0.4
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 1.25, -SIT_BACK)
	_area.add_child(shape)
	add_child(_area)
	_t = randf() * 10.0


# ---------------------------------------------------------------- building

func _skin() -> Dictionary:
	return Cosmetics.entry(&"skin", StringName(str(look.get("skin", &"cream"))))


func _build_rig(ghost: bool) -> void:
	var skin := _skin()
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = skin.get("body", Color("ffe3b8"))
	_body_mat.roughness = 0.45
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.35
	_body_mat.rim_tint = 0.3
	var accent: Color = skin.get("accent", Color("ff8fab"))
	var glove := Mats.solid(Color("fbfbf7"), 0.5)
	var ink := Mats.solid(Color("1d1128"), 0.4)
	var ghost_mat := Mats.ghost()
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	model = _rig
	_hips = Node3D.new()
	_hips.position = Vector3(0, SEAT_Y, 0)
	_rig.add_child(_hips)
	_body = Mats.mesh(_hips, _capsule(BODY_R, BODY_H), ghost_mat if ghost else _body_mat, Vector3(0, BODY_H * 0.5 - 0.05, 0))
	_chest = Node3D.new()
	_chest.position = Vector3(0, 0.72, 0)
	_hips.add_child(_chest)
	if not ghost:
		Mats.mesh(_chest, Mats.torus(0.2, 0.3, 24), Mats.solid(accent, 0.5), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	_arm_l = _limb(_chest, Vector3(BODY_R + 0.04, 0, 0), ARM_L, 0.075, ghost_mat if ghost else _body_mat, glove if not ghost else ghost_mat, 0.1)
	_arm_r = _limb(_chest, Vector3(-BODY_R - 0.04, 0, 0), ARM_L, 0.075, ghost_mat if ghost else _body_mat, glove if not ghost else ghost_mat, 0.1)
	_hand_r = Node3D.new()
	_hand_r.position = Vector3(0, -ARM_L - 0.02, 0)
	_arm_r.add_child(_hand_r)
	if not ghost:
		_leg_l = _limb(_hips, Vector3(0.14, 0.02, 0), LEG_L, 0.09, _body_mat, Mats.solid(Color("3a2a3f"), 0.5), 0.11, true)
		_leg_r = _limb(_hips, Vector3(-0.14, 0.02, 0), LEG_L, 0.09, _body_mat, Mats.solid(Color("3a2a3f"), 0.5), 0.11, true)
	else:
		_leg_l = null
		_leg_r = null
	_neck = Node3D.new()
	_neck.position = Vector3(0, BODY_H - 0.1 - 0.72, 0)
	_chest.add_child(_neck)
	_head = Node3D.new()
	_head.position = Vector3(0, HEAD_R * 0.85, 0)
	_neck.add_child(_head)
	head_anchor = _head
	Mats.mesh(_head, Mats.sphere(HEAD_R, HEAD_R * 1.9, 28), ghost_mat if ghost else _body_mat)
	# Googly eyes.
	_eyes.clear()
	for side in [1.0, -1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.115 * side, 0.06, HEAD_R * 0.86)
		_head.add_child(eye)
		Mats.mesh(eye, Mats.sphere(0.092, 0.184, 16), Mats.solid(Color.WHITE, 0.2), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55))
		var pupil := Mats.mesh(eye, Mats.sphere(0.048, 0.096, 12), ink, Vector3(0, 0, 0.04), Vector3.ZERO, Vector3(1, 1, 0.5))
		_eyes.append({"node": pupil, "off": Vector2(randf_range(-0.3, 0.3), -0.3), "vel": Vector2.ZERO})
	_brows.clear()
	for side in [1.0, -1.0]:
		var b := Mats.mesh(_head, Mats.box(Vector3(0.11, 0.025, 0.03)), ink, Vector3(0.115 * side, 0.185, HEAD_R * 0.9))
		_brows.append(b)
	_mouth = Mats.mesh(_head, Mats.sphere(0.06, 0.12, 12), Mats.solid(Color("3b0d1e"), 0.5), Vector3(0, -0.1, HEAD_R * 0.93), Vector3.ZERO, Vector3(1.3, 0.3, 0.4))
	if not ghost:
		_build_face(StringName(str(look.get("face", &"none"))))
	var hat := Hats.build(StringName(str(look.get("hat", &"none"))))
	if hat:
		hat.scale = Vector3.ONE * 0.56
		hat.position = Vector3(0, HEAD_R * 0.78, 0.0)
		_head.add_child(hat)
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
		sph.radius = HEAD_R + 0.04
		hs.shape = sph
		_hitbox.add_child(hs)
		_head.add_child(_hitbox)
		var bb := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = BODY_R
		cap.height = BODY_H
		bb.shape = cap
		var body_box := StaticBody3D.new()
		body_box.collision_layer = L_HITBOX
		body_box.collision_mask = 0
		body_box.set_meta(&"guest", self)
		body_box.add_child(bb)
		_body.add_child(body_box)
		_body_box = body_box
	for m in [_body]:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not ghost else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pose.clear()
	if is_local:
		_apply_local_layers()


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 6
	return c


## An arm or leg: a pivot at the joint with a capsule hanging down its -Y and a round end.
func _limb(parent: Node3D, at: Vector3, length: float, radius: float, mat: Material, end_mat: Material, end_r: float, shoe: bool = false) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	Mats.mesh(pivot, _capsule(radius, length), mat, Vector3(0, -length * 0.5, 0))
	if shoe:
		Mats.mesh(pivot, Mats.sphere(end_r, end_r * 1.6), end_mat, Vector3(0, -length + 0.02, 0.05), Vector3.ZERO, Vector3(1, 0.8, 1.6))
	else:
		Mats.mesh(pivot, Mats.sphere(end_r), end_mat, Vector3(0, -length, 0))
	return pivot


func _build_face(id: StringName) -> void:
	var z := HEAD_R * 0.93
	match id:
		&"moustache":
			var m := Mats.solid(Color("3b2416"), 0.7)
			for side in [1.0, -1.0]:
				Mats.mesh(_head, Mats.sphere(0.06, 0.12), m, Vector3(0.06 * side, -0.045, z + 0.01), Vector3(0, 0, -25 * side), Vector3(1.6, 0.6, 0.6))
				Mats.mesh(_head, Mats.sphere(0.03), m, Vector3(0.13 * side, -0.01, z - 0.02))
		&"monocle":
			Mats.mesh(_head, Mats.torus(0.085, 0.105, 20), Mats.gold(), Vector3(-0.115, 0.06, z + 0.03), Vector3(90, 0, 0))
			Mats.mesh(_head, Mats.cylinder(0.006, 0.006, 0.3, 6), Mats.gold(), Vector3(-0.2, -0.08, z - 0.02), Vector3(0, 0, 25))
		&"glasses":
			var g := Mats.solid(Color("2a1f33"), 0.4)
			for side in [1.0, -1.0]:
				Mats.mesh(_head, Mats.torus(0.09, 0.11, 20), g, Vector3(0.115 * side, 0.06, z + 0.03), Vector3(90, 0, 0))
			Mats.mesh(_head, Mats.box(Vector3(0.05, 0.015, 0.015)), g, Vector3(0, 0.07, z + 0.05))
		&"blush":
			for side in [1.0, -1.0]:
				Mats.mesh(_head, Mats.sphere(0.05), Mats.solid(Color("ff7aa2"), 0.8), Vector3(0.19 * side, -0.05, z - 0.06), Vector3.ZERO, Vector3(1.2, 0.7, 0.3))
		&"nose":
			Mats.mesh(_head, Mats.sphere(0.06), Mats.solid(Color("ff2e4d"), 0.2), Vector3(0, -0.01, z + 0.04))
		&"shades":
			var s := Mats.solid(Color("111118"), 0.1, 0.4)
			for side in [1.0, -1.0]:
				Mats.mesh(_head, Mats.box(Vector3(0.14, 0.09, 0.02)), s, Vector3(0.115 * side, 0.065, z + 0.06))
			Mats.mesh(_head, Mats.box(Vector3(0.1, 0.02, 0.02)), s, Vector3(0, 0.09, z + 0.06))
		&"beard":
			Mats.mesh(_head, Mats.cylinder(0.0, 0.2, 0.42, 16), Mats.solid(Color("f2f2f2"), 0.9), Vector3(0, -0.36, z - 0.12), Vector3(180, 0, 0), Vector3(1, 1, 0.6))


func _build_tags() -> void:
	_name_tag = _tag(Ui.display_font(), 34, Color("fff4e0"), 2.35)
	_name_tag.text = display_name
	_title_tag = _tag(Ui.body_font(700), 20, Color("ffc93c"), 2.35)
	_title_tag.text = Cosmetics.title_name(look.get("title", &"newcomer"))
	_title_tag.offset = Vector2(0, -30)
	_bubble = _tag(Ui.display_font(), 36, Color("1d1128"), 2.55)
	_bubble.outline_modulate = Color("fff4e0")
	_bubble.outline_size = 22
	_bubble.visible = false
	_mic = _tag(Ui.body_font(700), 22, Color("3ddc97"), 2.4)
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


## Your own guest: the head (and hat, and bubble) go on LOCAL_LAYER so the first-person camera
## doesn't see the inside of your own face; you never click yourself.
func set_local(on: bool) -> void:
	is_local = on
	_area.collision_layer = 0 if on else 4
	_name_tag.visible = not on
	_title_tag.visible = not on
	_apply_local_layers()


func _apply_local_layers() -> void:
	if not is_local:
		return
	# Everything but your arms and gloves: from inside your own head you only see your hands.
	_set_layers(_hips, LOCAL_LAYER)
	_set_layers(_arm_l, 1)
	_set_layers(_arm_r, 1)
	for l: Label3D in [_bubble, _mic]:
		l.layers = LOCAL_LAYER


func _set_layers(n: Node, layers: int) -> void:
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
	if _body_mat and not is_ghost:
		_body_mat.emission_enabled = on
		_body_mat.emission = Color("ffc93c")
		_body_mat.emission_energy_multiplier = 0.35


## This guest's own hit bodies (a thrown cake ignores its thrower).
func hitboxes() -> Array[PhysicsBody3D]:
	var out: Array[PhysicsBody3D] = []
	for b: PhysicsBody3D in [_hitbox, _body_box]:
		if b and is_instance_valid(b) and b.is_inside_tree():
			out.append(b)
	return out


func head_position() -> Vector3:
	return _head.global_position if _head and is_instance_valid(_head) else global_position + Vector3(0, 1.6, 0)


# ---------------------------------------------------------------- posing

## Upper-body gesture: cheer, no, point, think, yes, plead, laugh, sip, interact, shrug, wave.
## (Old KayKit clip names from earlier versions are mapped.)
func gesture(kind: StringName, seconds: float = -1.0) -> void:
	if not alive and not is_ghost:
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


## Point at a world position (accusations, toasts).
func point_at(world_pos: Vector3) -> void:
	_point_dir = (_chest.global_transform.affine_inverse() * world_pos).normalized() if _chest else Vector3.FORWARD
	gesture(&"point")


func _set_mood(m: StringName, seconds: float) -> void:
	_mood = m
	_mood_t = seconds


func _arm_q(dir: Vector3) -> Quaternion:
	return Quaternion(Vector3.DOWN, dir.normalized())


func _target_pose() -> Dictionary:
	var p := {}
	var stand := _state in [&"stand", &"drink"]
	var breathe := sin(_t * 2.2) * 0.012
	p["hip_y"] = SEAT_Y + breathe
	p["hip_z"] = -SIT_BACK if not stand else -0.05
	p["lean"] = 0.08 if not stand else 0.0
	p["twist"] = 0.0
	p["head"] = Vector3(0.05, _look_yaw, 0.0)
	if not stand:
		p["arm_l"] = _arm_q(Vector3(0.18, -0.6, 0.8))
		p["arm_r"] = _arm_q(Vector3(-0.18, -0.6, 0.8))
		p["leg_l"] = _arm_q(Vector3(0.05, -0.05, 1))
		p["leg_r"] = _arm_q(Vector3(-0.05, -0.05, 1))
	else:
		p["arm_l"] = _arm_q(Vector3(0.3, -1, 0.1))
		p["arm_r"] = _arm_q(Vector3(-0.3, -1, 0.1))
		p["leg_l"] = _arm_q(Vector3(0.05, -1, 0))
		p["leg_r"] = _arm_q(Vector3(-0.05, -1, 0))
	if _held_cup:
		p["arm_r"] = _arm_q(Vector3(-0.1, -0.35, 1))
	if _state == &"drink":
		p["arm_r"] = _arm_q(Vector3(0.55, 0.7, 0.55))
		p["head"] = Vector3(-0.35, 0, 0)
	if _state == &"ghost":
		p["hip_y"] = SEAT_Y + 0.9 + sin(_t * 1.6) * 0.12
		p["hip_z"] = -SIT_BACK
		var sway := sin(_t * 2.4) * 0.2
		p["arm_l"] = _arm_q(Vector3(0.25, 0.1 + sway, 1))
		p["arm_r"] = _arm_q(Vector3(-0.25, 0.1 - sway, 1))
		p["head"] = Vector3(0.1, sin(_t * 0.7) * 0.4, sin(_t * 1.3) * 0.15)
	# Gestures on top.
	var g := _gesture
	var k := _t * 9.0
	match g:
		&"cheer":
			p["arm_l"] = _arm_q(Vector3(0.4, 1, 0.1 + sin(k) * 0.3))
			p["arm_r"] = _arm_q(Vector3(-0.4, 1, 0.1 - sin(k) * 0.3))
			p["hip_y"] += absf(sin(k * 0.5)) * 0.06
		&"wave":
			p["arm_r"] = _arm_q(Vector3(-0.6 + sin(k) * 0.35, 0.9, 0.2))
		&"point":
			p["arm_r"] = _arm_q(_point_dir + Vector3(0, 0.15, 0))
			p["lean"] = 0.25
		&"no":
			p["arm_l"] = _arm_q(Vector3(0.9, -0.2, 0.5))
			p["arm_r"] = _arm_q(Vector3(-0.9, -0.2, 0.5))
			p["head"] = Vector3(0, sin(k * 1.2) * 0.45, 0)
		&"yes":
			p["arm_r"] = _arm_q(Vector3(-0.3, 0.3, 1))
			p["head"] = Vector3(sin(k) * 0.3, 0, 0)
		&"think":
			p["arm_r"] = _arm_q(Vector3(0.45, 0.45, 0.7))
			p["arm_l"] = _arm_q(Vector3(-0.3, -0.4, 0.9))
			p["head"] = Vector3(0.1, 0.2, 0.25)
		&"plead":
			p["arm_l"] = _arm_q(Vector3(-0.3, 0.25, 1))
			p["arm_r"] = _arm_q(Vector3(0.3, 0.25, 1))
			p["hip_y"] += sin(k) * 0.03
			p["lean"] = 0.3
		&"laugh":
			p["arm_l"] = _arm_q(Vector3(-0.3, -0.7, 0.7))
			p["arm_r"] = _arm_q(Vector3(0.3, -0.7, 0.7))
			p["head"] = Vector3(-0.4, 0, sin(k) * 0.1)
			p["hip_y"] += absf(sin(k)) * 0.07
			p["lean"] = -0.2
			_talk_open = maxf(_talk_open, 0.6 + 0.4 * sin(k * 1.3))
		&"sip":
			p["arm_r"] = _arm_q(Vector3(0.55, 0.7, 0.55))
			p["head"] = Vector3(-0.3, 0, 0)
		&"interact":
			p["arm_l"] = _arm_q(Vector3(-0.1, -0.2, 1))
			p["arm_r"] = _arm_q(Vector3(0.1, -0.2, 1))
			p["lean"] = 0.4
		&"shrug":
			p["arm_l"] = _arm_q(Vector3(1, 0.2, 0.3))
			p["arm_r"] = _arm_q(Vector3(-1, 0.2, 0.3))
			p["head"] = Vector3(0, 0, 0.25)
		&"spook":
			p["arm_l"] = _arm_q(Vector3(0.3, 0.6, 1))
			p["arm_r"] = _arm_q(Vector3(-0.3, 0.6, 1))
	if _shake > 0.0:
		p["twist"] = sin(_t * 60.0) * 0.12 * _shake
		p["head"] += Vector3(sin(_t * 47.0), sin(_t * 53.0), sin(_t * 41.0)) * 0.2 * _shake
		p["arm_l"] = _arm_q(Vector3(0.9, 0.2 + sin(_t * 30.0), 0.3))
		p["arm_r"] = _arm_q(Vector3(-0.9, 0.2 - sin(_t * 31.0), 0.3))
	return p


func _process(delta: float) -> void:
	_t += delta
	if not _ragdoll_parts.is_empty():
		_googly(_corpse_head, _corpse_eyes, delta)
	if _rig == null or not is_instance_valid(_rig) or (not alive and not is_ghost and _shake <= 0.0):
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
	# Bonk spring on the head.
	_bonk_v += (-_bonk * 60.0 - _bonk_v * 7.0) * delta
	_bonk += _bonk_v * delta
	_hips.position = Vector3(0, _pose["hip_y"], _pose["hip_z"])
	_hips.rotation = Vector3(_pose["lean"], _pose["twist"], 0)
	_arm_l.quaternion = _pose["arm_l"]
	_arm_r.quaternion = _pose["arm_r"]
	if _leg_l:
		_leg_l.quaternion = _pose["leg_l"]
		_leg_r.quaternion = _pose["leg_r"]
	_neck.rotation = _pose["head"] + _bonk
	if _held_cup and is_instance_valid(_held_cup):
		_cup_tilt = lerpf(_cup_tilt, -1.3 if _state == &"drink" else 0.0, w * 0.6)
		var yaw := global_rotation.y
		_held_cup.global_basis = Basis.from_euler(Vector3(_cup_tilt, yaw, 0))
	_face(delta)
	_googly(_head, _eyes, delta)


func _face(delta: float) -> void:
	# Mouth: flaps with voice / speech bubbles, wide open when shocked.
	var want := 0.0
	if _speaking:
		want = 0.3 + 0.7 * absf(sin(_t * 17.0) * sin(_t * 6.3))
	if _mood == &"shock":
		want = 1.0
	_talk_open = maxf(want, _talk_open - delta * 2.5)
	var open := _talk_open
	var smile := 1.3 if _mood != &"sad" else 0.9
	_mouth.scale = Vector3(smile - open * 0.4, 0.3 + open * 1.3, 0.4)
	# Brows by mood.
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
		_brows[i].position.y = 0.185 + lift + (0.03 if _mood == &"sly" and i == 0 else 0.0)
	# Blink (squash the pupils' eyes).
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
	if head == null or not is_instance_valid(head) or delta <= 0.0:
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
		(e["node"] as Node3D).position = Vector3(off.x * 0.045, off.y * 0.045, 0.04)


## A cake to the face: the head snaps back, the eyes spin, and frosting stays on.
func bonk(from_dir: Vector3, frosting: Color) -> void:
	if not alive or _head == null:
		return
	var local := _neck.global_transform.basis.inverse() * from_dir
	_bonk_v += Vector3(-local.z * 9.0 - 3.0, local.x * 6.0, randf_range(-6, 6))
	for e in _eyes:
		e["vel"] = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	_set_mood(&"shock", 0.8)
	var blob := Mats.mesh(_head, Mats.sphere(0.1), Mats.solid(frosting, 0.6), Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.15), HEAD_R * 0.85), Vector3.ZERO, Vector3(1.3, 1.0, 0.45))
	blob.scale = Vector3.ONE * 0.1
	blob.create_tween().tween_property(blob, "scale", Vector3(1.3, 1.0, 0.45), 0.12)
	if is_local:
		_set_layers(blob, LOCAL_LAYER)
	Sfx.play_at(&"bonk", head_position())


# ---------------------------------------------------------------- moments

func _hand_pos() -> Vector3:
	return _hand_r.global_position


## Stand, raise the cup to the lips, glug. Returns seconds until done.
func drink(cup: Node3D) -> float:
	_state = &"stand"
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if cup and is_instance_valid(cup):
			_hold(cup))
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		_state = &"drink")
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		Sfx.play_at(&"gulp", head_position(), -2.0)
		_talk_open = 0.8)
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		_state = &"stand")
	return 2.1


func _hold(cup: Node3D) -> void:
	_held_cup = cup
	var gt := cup.global_transform
	cup.get_parent().remove_child(cup)
	_hand_r.add_child(cup)
	cup.global_transform = gt
	_cup_tilt = 0.0
	cup.create_tween().tween_property(cup, "position", Vector3(0, -0.1, 0.0), 0.25).set_trans(Tween.TRANS_SINE)


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


func stand() -> void:
	_state = &"stand"


func sit_back_down() -> void:
	_state = &"sit"
	_set_mood(&"happy", 1.5)


func cheer() -> void:
	gesture(&"cheer")


## Poisoned: turn green, shake, gasp... then go limp as a ragdoll. Returns seconds until down.
func die(style: StringName = &"") -> float:
	if not alive:
		return 0.0
	alive = false
	if style == &"":
		style = StringName(str(look.get("death", &"swoon")))
	_state = &"stand"
	_set_mood(&"shock", 99.0)
	_shake = 1.0
	Sfx.play_at(&"gasp", head_position())
	var green := Color("7bd14a")
	var tw := create_tween()
	tw.tween_property(_body_mat, "albedo_color", green, 0.6)
	var t := 0.9
	if style == &"monologue":
		_shake = 0.0
		say("Avenge... meeee...", 1.5, Color("5c1a33"))
		gesture(&"cheer", 1.6)
		t = 1.7
	if style == &"stagger":
		t = 1.3
	_dying = style
	tw.parallel().tween_interval(t)
	tw.tween_callback(func() -> void:
		_shake = 0.0
		if _dying != &"":
			_go_ragdoll(style))
	return t + 1.2


func _go_ragdoll(style: StringName) -> void:
	_dying = &""
	var world := get_parent() as Node3D
	if world == null or _rig == null or not is_instance_valid(_rig) or _leg_l == null:
		return
	_release_held()
	_knock_chair()
	var parts := {}
	# body (hips holds the body mesh; its children are chest etc. which we split off first)
	var detach := func(node: Node3D, key: String, shape: Shape3D, shape_pos: Vector3, mass: float) -> RigidBody3D:
		var rb := RigidBody3D.new()
		rb.collision_layer = L_RAGDOLL
		rb.collision_mask = L_WORLD | L_RAGDOLL | L_PROPS
		rb.mass = mass
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.35
		pm.friction = 0.8
		rb.physics_material_override = pm
		rb.angular_damp = 1.5
		rb.linear_damp = 0.2
		var gt := node.global_transform
		world.add_child(rb)
		rb.global_transform = gt
		node.get_parent().remove_child(node)
		rb.add_child(node)
		node.transform = Transform3D.IDENTITY
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = shape_pos
		rb.add_child(cs)
		parts[key] = rb
		_ragdoll_parts.append(rb)
		return rb
	var arm_shape := CapsuleShape3D.new()
	arm_shape.radius = 0.08
	arm_shape.height = ARM_L + 0.1
	var leg_shape := CapsuleShape3D.new()
	leg_shape.radius = 0.1
	leg_shape.height = LEG_L + 0.1
	var head_shape := SphereShape3D.new()
	head_shape.radius = HEAD_R
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = BODY_R
	body_shape.height = BODY_H
	var head_rb: RigidBody3D = detach.call(_head, "head", head_shape, Vector3.ZERO, 1.2)
	var arm_l_rb: RigidBody3D = detach.call(_arm_l, "arm_l", arm_shape, Vector3(0, -ARM_L * 0.5, 0), 0.5)
	var arm_r_rb: RigidBody3D = detach.call(_arm_r, "arm_r", arm_shape, Vector3(0, -ARM_L * 0.5, 0), 0.5)
	var leg_l_rb: RigidBody3D = detach.call(_leg_l, "leg_l", leg_shape, Vector3(0, -LEG_L * 0.5, 0), 0.8)
	var leg_r_rb: RigidBody3D = detach.call(_leg_r, "leg_r", leg_shape, Vector3(0, -LEG_L * 0.5, 0), 0.8)
	var body_rb: RigidBody3D = detach.call(_hips, "body", body_shape, Vector3(0, BODY_H * 0.5 - 0.05, 0), 3.0)
	# The hat pops off.
	if _hat and is_instance_valid(_hat):
		var hat_shape := SphereShape3D.new()
		hat_shape.radius = 0.16
		var hat_rb: RigidBody3D = detach.call(_hat, "hat", hat_shape, Vector3(0, 0.1, 0), 0.2)
		hat_rb.collision_mask = L_WORLD | L_RAGDOLL | L_PROPS
		hat_rb.apply_central_impulse(Vector3(randf_range(-0.4, 0.4), 1.2, randf_range(-0.4, 0.4)))
		hat_rb.apply_torque_impulse(Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)))
	for pair in [[body_rb, head_rb, _neck_world()], [body_rb, arm_l_rb, arm_l_rb.global_position], [body_rb, arm_r_rb, arm_r_rb.global_position],
			[body_rb, leg_l_rb, leg_l_rb.global_position], [body_rb, leg_r_rb, leg_r_rb.global_position]]:
		var j := PinJoint3D.new()
		world.add_child(j)
		j.global_position = pair[2]
		j.node_a = j.get_path_to(pair[0])
		j.node_b = j.get_path_to(pair[1])
		j.set_param(PinJoint3D.PARAM_DAMPING, 1.0)
		j.set_param(PinJoint3D.PARAM_BIAS, 0.6)
	_corpse_head = _head
	_corpse_eyes = _eyes.duplicate()
	for e in _corpse_eyes:
		e["vel"] = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	# Everything below the rig is gone; the guest node keeps its tags.
	_rig.queue_free()
	_rig = null
	var away := global_transform.basis * Vector3(0, 0, -1)   # away from the table
	var up := Vector3.UP
	match style:
		&"keel":
			body_rb.apply_central_impulse((-away * 3.0 + up * 1.0))
			head_rb.apply_central_impulse(-away * 1.5)
			_splash_table()
		&"spin":
			body_rb.apply_central_impulse(up * 6.0 + away * 1.0)
			body_rb.apply_torque_impulse(Vector3(0, 6.0, 0))
		&"confetti":
			_confetti(head_rb.global_position)
			Sfx.play_at(&"magic", head_rb.global_position)
			body_rb.apply_central_impulse(up * 5.0 + away * 2.0)
		&"ascend":
			for rb in _ragdoll_parts:
				rb.gravity_scale = -0.12
			body_rb.apply_central_impulse(up * 1.0)
		&"yeet":
			body_rb.apply_central_impulse(away * 14.0 + up * 7.0)
			head_rb.apply_central_impulse(away * 3.0)
			Sfx.play_at(&"slide_whistle", head_rb.global_position)
		&"stagger":
			body_rb.apply_torque_impulse(Vector3(randf_range(-3, 3), 4.0, randf_range(-3, 3)))
			body_rb.apply_central_impulse(away * 2.0 + up)
		_:
			body_rb.apply_central_impulse(away * 3.5 + up * 1.5)
			head_rb.apply_central_impulse(away * 1.2 + up * 0.5)
	if style != &"yeet":
		Sfx.play_at(&"slide_whistle", head_rb.global_position, -4.0)
	var thud := create_tween()
	thud.tween_interval(0.7)
	thud.tween_callback(func() -> void:
		if is_instance_valid(body_rb):
			Sfx.play_at(&"thud", body_rb.global_position))


func _neck_world() -> Vector3:
	return _neck.global_position


## Hand a held cup back to the world (so it outlives this body); fling it if we're collapsing.
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


func _splash_table() -> void:
	splashed_table.emit(self)


## Tip the chair over with physics (it snaps back when the ghost appears).
func _knock_chair() -> void:
	if chair == null or not is_instance_valid(chair):
		return
	if _chair_home == Transform3D():
		_chair_home = chair.transform
	if chair is RigidBody3D:
		var rb := chair as RigidBody3D
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


## A translucent bean floats up above the chair; the body stays where it fell.
func become_ghost() -> void:
	if is_ghost:
		return
	if alive:
		alive = false
	if _dying != &"":
		_shake = 0.0
		_go_ragdoll(_dying)
	is_ghost = true
	_release_held(false)
	if _rig and is_instance_valid(_rig):
		_rig.queue_free()
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
		(l as Label3D).position.y = 3.3
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
