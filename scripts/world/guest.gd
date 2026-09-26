class_name Guest
extends Node3D
## One guest at the table: a KayKit character (Knight / Rogue from Woods) with a tint, a hat,
## a name card, speech bubbles and a speaking indicator.
##
## Animation: an AnimationTree with two full-body slots cross-faded by a Blend2 (sit, stand,
## drink, die ...) and a filtered upper-body OneShot on top, so gestures and emotes play while
## seated without moving the legs. Extra clips come from Woods' retargeted UAL library ("ual/...").
## After dying the body lies in its death pose until the next round, then a ghost floats above
## the chair.

const MODELS := {
	&"knight": {"scene": "res://assets/models/characters/Knight.glb",
		"hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "Knight_Helmet"]},
	&"rogue": {"scene": "res://assets/models/characters/Rogue_Hooded.glb",
		"hide": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]},
}
const UAL := "res://assets/animations/ual_library.res"
const UPPER_BONES := ["Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm",
	"LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
## KayKit sit pose puts the hips 0.40 behind the root: the chair goes there.
const SIT_BACK := 0.40
## Render layer for the parts of your own guest your own camera shouldn't see.
const LOCAL_LAYER := 1 << 19

var seat := -1
var peer_id := 0
var display_name := ""
var look: Dictionary = {}
var alive := true
var is_ghost := false

var model: Node3D
var head_anchor: Node3D
var hand_anchor: Node3D
var _ap: AnimationPlayer
var _tree: AnimationTree
var _slot := 0
var _xfade: Tween
var _name_tag: Label3D
var _title_tag: Label3D
var is_local := false
var _bubble: Label3D
var _bubble_tw: Tween
var _mic: Label3D
var _ghost: Node3D
var _hl: bool = false
var _meshes: Array[MeshInstance3D] = []
var _held_cup: Node3D
## The chair this guest sits on (knocked over when they collapse).
var chair: Node3D
var _chair_home := Transform3D()
var _skel_path := ""


func setup(p_seat: int, info: Dictionary) -> void:
	seat = p_seat
	peer_id = int(info.get("id", 0))
	display_name = String(info.get("name", "Guest"))
	look = info.get("cos", {})
	name = "Guest%d" % seat
	_build_model()
	_build_tags(info)
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.set_meta(&"guest", self)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.0
	shape.shape = cap
	shape.position = Vector3(0, 1.2, -SIT_BACK)
	area.add_child(shape)
	add_child(area)


func _build_model() -> void:
	var skin := Cosmetics.entry(&"skin", StringName(str(look.get("skin", &"knight"))))
	var def: Dictionary = MODELS.get(skin.get("model", &"knight"), MODELS[&"knight"])
	model = (load(def["scene"]) as PackedScene).instantiate() as Node3D
	add_child(model)
	for n: String in def["hide"]:
		var h := model.find_child(n, true, false)
		if h is Node3D:
			(h as Node3D).visible = false
	var tint: Color = skin.get("tint", Color.WHITE)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		_meshes.append(mi)
		if tint != Color.WHITE:
			for s in mi.mesh.get_surface_count():
				var base := mi.mesh.surface_get_material(s)
				if base is StandardMaterial3D:
					var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					mat.albedo_color = tint
					mi.set_surface_override_material(s, mat)
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	head_anchor = _attach(skel, "Head")
	hand_anchor = _attach(skel, "RightHand")
	var hat := Hats.build(StringName(str(look.get("hat", &"none"))))
	if hat:
		head_anchor.add_child(hat)
	_ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ap.add_animation_library(&"ual", load(UAL) as AnimationLibrary)
	for clip: StringName in [&"Sit_Chair_Idle", &"Idle", &"Lie_Idle", &"ual/Sitting_Idle", &"Unarmed_Idle", &"Spellcasting", &"ual/Dance"]:
		if _ap.has_animation(clip):
			_ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_skel_path = String(_ap.get_node(_ap.root_node).get_path_to(skel))
	_build_tree()
	base(&"Sit_Chair_Idle", 0.0)
	# Desynchronise idle breathing between guests.
	_tree.set("parameters/Seek%s/seek_request" % ("A" if _slot == 0 else "B"), randf() * 3.0)


func _attach(skel: Skeleton3D, bone: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var n := Node3D.new()
	ba.add_child(n)
	return n


func _build_tags(_info: Dictionary) -> void:
	var hs := HudStyle.new()
	_name_tag = _tag(hs.font(&"serif", 650, 48), 40, Color("f6ecd6"), 2.95)
	_name_tag.text = display_name
	_title_tag = _tag(hs.font(&"sans", 750), 26, Color("e3bf73"), 2.95)
	_title_tag.text = Cosmetics.title_name(look.get("title", &"newcomer"))
	_title_tag.offset = Vector2(0, -38)
	_bubble = _tag(hs.font(&"sans", 800), 40, Color("fff4d8"), 2.75)
	_bubble.outline_size = 14
	_bubble.visible = false
	_mic = _tag(hs.font(&"sans", 900), 24, Color("9fe08a"), 2.75)
	_mic.text = "(( speaking ))"
	_mic.offset = Vector2(0, 40)
	_mic.visible = false


func _tag(font: Font, size: int, color: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = size
	l.fixed_size = true
	l.pixel_size = 0.00085
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.06, 0.03, 0.85)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, y, -SIT_BACK)
	add_child(l)
	return l


## The local player's own guest: seen from inside, so the head, hat, name card and bubble go on
## LOCAL_LAYER, which the table camera leaves out (except for the death cam).
func set_local(on: bool) -> void:
	is_local = on
	_name_tag.visible = not on
	_title_tag.visible = not on
	for mi in _meshes:
		if String(mi.name).contains("Head") or String(mi.name).contains("Helmet"):
			mi.layers = LOCAL_LAYER
	for l: Label3D in [_bubble, _mic]:
		l.layers = LOCAL_LAYER
	_set_layers(head_anchor, LOCAL_LAYER)


func _set_layers(n: Node, layers: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layers
	for c in n.get_children():
		_set_layers(c, layers)


## Put the name and title on a place card at `pos` (global) instead of over the head.
func place_tags(pos: Vector3) -> void:
	_name_tag.global_position = pos
	_title_tag.global_position = pos
	_name_tag.font_size = 34
	_title_tag.font_size = 22
	_title_tag.offset = Vector2(0, -30)


## Hide or show the name card (the menu backdrop keeps things clean).
func show_tags(on: bool) -> void:
	_name_tag.visible = on
	_title_tag.visible = on


func set_name_color(c: Color) -> void:
	_name_tag.modulate = c


func set_speaking(on: bool) -> void:
	_mic.visible = on and not is_local


## A floating line over the guest's head (emotes, bot chatter, "Ready!").
func say(text: String, seconds: float = 2.6, color: Color = Color("fff4d8")) -> void:
	_bubble.text = text
	_bubble.modulate = color
	_bubble.visible = true
	_bubble.scale = Vector3.ONE * 0.6
	_bubble.visible = true
	if _bubble_tw and _bubble_tw.is_valid():
		_bubble_tw.kill()
	_bubble_tw = create_tween()
	_bubble_tw.tween_property(_bubble, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tw.tween_interval(seconds)
	_bubble_tw.tween_callback(func() -> void: _bubble.visible = false)


# ---------------------------------------------------------------- animation tree

func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	for slot: StringName in [&"A", &"B"]:
		bt.add_node(slot, AnimationNodeAnimation.new(), Vector2(0, 0 if slot == &"A" else 150))
		bt.add_node(StringName("Seek" + slot), AnimationNodeTimeSeek.new(), Vector2(150, 0 if slot == &"A" else 150))
		bt.connect_node(StringName("Seek" + slot), 0, slot)
	var mix := AnimationNodeBlend2.new()
	bt.add_node(&"Mix", mix, Vector2(300, 60))
	bt.connect_node(&"Mix", 0, &"SeekA")
	bt.connect_node(&"Mix", 1, &"SeekB")
	bt.add_node(&"Speed", AnimationNodeTimeScale.new(), Vector2(450, 60))
	bt.connect_node(&"Speed", 0, &"Mix")
	bt.add_node(&"Upper", AnimationNodeAnimation.new(), Vector2(450, 250))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.25
	shot.fadeout_time = 0.35
	shot.filter_enabled = true
	for b: String in UPPER_BONES:
		shot.set_filter_path(NodePath("%s:%s" % [_skel_path, b]), true)
	bt.add_node(&"Gesture", shot, Vector2(650, 100))
	bt.connect_node(&"Gesture", 0, &"Speed")
	bt.connect_node(&"Gesture", 1, &"Upper")
	bt.connect_node(&"output", 0, &"Gesture")
	_tree = AnimationTree.new()
	_tree.tree_root = bt
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_ap)
	_tree.active = true


## Cross-fade the full body to `clip` (restarted from its first frame). One-shot clips rest on
## their last frame (a death pose stays down).
func base(clip: StringName, fade: float = 0.3, speed: float = 1.0) -> void:
	if not _ap.has_animation(clip):
		return
	var bt := _tree.tree_root as AnimationNodeBlendTree
	_slot = 1 - _slot
	var slot_name := "A" if _slot == 0 else "B"
	(bt.get_node(StringName(slot_name)) as AnimationNodeAnimation).animation = clip
	_tree.set("parameters/Seek%s/seek_request" % slot_name, 0.0)
	_tree.set("parameters/Speed/scale", speed)
	if _xfade and _xfade.is_valid():
		_xfade.kill()
	if fade <= 0.0:
		_tree.set("parameters/Mix/blend_amount", float(_slot))
	else:
		_xfade = create_tween()
		_xfade.tween_property(_tree, "parameters/Mix/blend_amount", float(_slot), fade)


## Upper body only (works while seated).
func gesture(clip: StringName) -> void:
	if not _ap.has_animation(clip) or is_ghost:
		return
	var bt := _tree.tree_root as AnimationNodeBlendTree
	(bt.get_node(&"Upper") as AnimationNodeAnimation).animation = clip
	_tree.set("parameters/Gesture/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func clip_length(clip: StringName) -> float:
	return _ap.get_animation(clip).length if _ap.has_animation(clip) else 0.5


# ---------------------------------------------------------------- moments

func highlight(on: bool) -> void:
	if on == _hl:
		return
	_hl = on
	_name_tag.outline_modulate = Color("c9891f") if on else Color(0.1, 0.06, 0.03, 0.85)
	_name_tag.outline_size = 18 if on else 10


## Stand, raise the cup to your lips, drink. The cup is carried by the guest (not the hand bone,
## whose retargeted sip stays low) and stays in front of them until release_cup().
## Returns seconds until the drink is done.
func drink(cup: Node3D) -> float:
	base(&"Sit_Chair_StandUp", 0.2)
	var up := clip_length(&"Sit_Chair_StandUp")
	var tw := create_tween()
	tw.tween_interval(up * 0.6)
	tw.tween_callback(func() -> void:
		if cup and is_instance_valid(cup):
			_hold(cup))
	tw.tween_interval(up * 0.4)
	tw.tween_callback(func() -> void: base(&"Idle", 0.3))
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		gesture(&"ual/Consume")
		if _held_cup:
			var sip := _held_cup.create_tween()
			sip.tween_property(_held_cup, "position", Vector3(-0.12, 1.5, 0.42), 0.35).set_trans(Tween.TRANS_SINE)
			sip.parallel().tween_property(_held_cup, "rotation:x", -1.0, 0.35)
			sip.tween_interval(0.7)
			sip.tween_property(_held_cup, "position", Vector3(-0.3, 1.1, 0.5), 0.35).set_trans(Tween.TRANS_SINE)
			sip.parallel().tween_property(_held_cup, "rotation:x", 0.0, 0.35))
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void: Sfx.play_at(&"gulp", global_position + Vector3(0, 1.5, 0), -3.0))
	return up + 1.6


func _hold(cup: Node3D) -> void:
	_held_cup = cup
	var gt := cup.global_transform
	cup.get_parent().remove_child(cup)
	add_child(cup)
	cup.global_transform = gt
	var tw := create_tween()
	tw.tween_property(cup, "position", Vector3(-0.3, 1.1, 0.5), 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cup, "rotation", Vector3.ZERO, 0.35)


## Give a held cup back to the table (to `parent` at local `pos`).
func release_cup(parent: Node3D, pos: Vector3) -> void:
	if _held_cup == null or not is_instance_valid(_held_cup):
		return
	var cup := _held_cup
	_held_cup = null
	var gt := cup.global_transform
	cup.get_parent().remove_child(cup)
	parent.add_child(cup)
	cup.global_transform = gt
	var tw := cup.create_tween()
	tw.tween_property(cup, "position", pos, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(cup, "rotation", Vector3.ZERO, 0.4)


func sit_back_down() -> void:
	base(&"Sit_Chair_Down", 0.25)
	var tw := create_tween()
	tw.tween_interval(clip_length(&"Sit_Chair_Down") * 0.95)
	tw.tween_callback(func() -> void: base(&"Sit_Chair_Idle", 0.2))


func cheer() -> void:
	base(&"Cheer", 0.25)
	var tw := create_tween()
	tw.tween_interval(clip_length(&"Cheer"))
	tw.tween_callback(sit_back_down)


## The collapse, in the guest's chosen style. Returns seconds until they are down.
func die(style: StringName = &"") -> float:
	alive = false
	if style == &"":
		style = StringName(str(look.get("death", &"swoon")))
	Sfx.play_at(&"gasp", global_position + Vector3(0, 1.5, 0))
	var tw := create_tween()
	tw.tween_interval(0.01)
	var t := 0.0
	_knock_chair()
	# Clips that fall forwards turn away from the table first.
	if style in [&"", &"swoon", &"stagger", &"confetti"] or not (style in [&"keel", &"monologue", &"spin", &"ascend"]):
		create_tween().tween_property(model, "rotation:y", PI, 0.3).set_trans(Tween.TRANS_SINE)
	match style:
		&"keel":
			base(&"Death_A", 0.15)
			t = clip_length(&"Death_A")
		&"stagger":
			base(&"Hit_A", 0.1)
			tw.tween_interval(clip_length(&"Hit_A") * 0.8)
			tw.tween_callback(func() -> void: base(&"Hit_B", 0.1))
			tw.tween_interval(clip_length(&"Hit_B") * 0.8)
			tw.tween_callback(func() -> void: base(&"Death_B", 0.15))
			t = clip_length(&"Hit_A") * 0.8 + clip_length(&"Hit_B") * 0.8 + clip_length(&"Death_B")
		&"monologue":
			base(&"Spellcasting", 0.2)
			say("Avenge... me...", 1.6, Color("f0b0b0"))
			tw.tween_interval(1.8)
			tw.tween_callback(func() -> void: base(&"Death_A", 0.2))
			t = 1.8 + clip_length(&"Death_A")
		&"spin":
			base(&"Death_B", 0.15)
			var spin := create_tween()
			spin.tween_property(model, "rotation:y", TAU * 2.0 + PI, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t = clip_length(&"Death_B")
		&"confetti":
			_confetti()
			base(&"Death_B", 0.15)
			Sfx.play_at(&"magic", global_position + Vector3(0, 1.4, 0))
			t = clip_length(&"Death_B")
		&"ascend":
			base(&"Death_A", 0.15)
			t = clip_length(&"Death_A")
			tw.tween_interval(t)
			tw.tween_callback(func() -> void:
				become_ghost()
				_ghost.position.y = 0.0
				var up := _ghost.create_tween()
				up.tween_property(_ghost, "position:y", 1.3, 1.5).set_trans(Tween.TRANS_SINE))
		_:
			base(&"Death_B", 0.15)
			t = clip_length(&"Death_B")
	var thud := create_tween()
	thud.tween_interval(maxf(0.2, t - 0.6))
	thud.tween_callback(func() -> void: Sfx.play_at(&"thud", global_position + Vector3(0, 0.5, 0)))
	return t


## Tip the chair over backwards (restored when the ghost appears).
func _knock_chair() -> void:
	if chair == null or not is_instance_valid(chair):
		return
	if _chair_home == Transform3D():
		_chair_home = chair.transform
	var back := chair.transform.basis * Vector3(0, 0, -0.55)
	var tw := chair.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(chair, "position", chair.position + back, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(chair, "rotation:x", chair.rotation.x - 1.45, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: Sfx.play_at(&"thud", chair.global_position, -8.0))


func _confetti() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 90
	p.lifetime = 2.2
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
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
	g.set_color(0, Color("f28aa0"))
	g.add_point(0.33, Color("f7d154"))
	g.add_point(0.66, Color("7fd0f0"))
	g.set_color(g.get_point_count() - 1, Color("9fe08a"))
	p.color_initial_ramp = g
	p.position = Vector3(0, 1.6, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## The body leaves and a translucent copy floats above the chair.
func become_ghost() -> void:
	if is_ghost:
		return
	is_ghost = true
	alive = false
	if _held_cup and is_instance_valid(_held_cup):
		_held_cup.visible = false
	base(&"Unarmed_Idle", 0.4, 0.6)
	if chair and is_instance_valid(chair) and _chair_home != Transform3D():
		chair.transform = _chair_home
	for mi in _meshes:
		mi.material_override = Mats.ghost()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if head_anchor.get_child_count() > 0:
		for c in head_anchor.get_children():
			_ghostify(c)
	_ghost = model
	var bob := model.create_tween().set_loops()
	bob.tween_property(model, "position:y", 1.1, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(model, "position:y", 0.9, 1.6).set_trans(Tween.TRANS_SINE)
	model.position = Vector3(0, 1.0, -SIT_BACK)
	model.rotation = Vector3.ZERO
	_name_tag.modulate = Color(0.7, 0.85, 1.0, 0.8)
	_title_tag.text = "ghost"
	for l in [_bubble, _mic]:
		(l as Label3D).position.y = 3.6
	if is_local:
		model.visible = false
	Sfx.play_at(&"ghost", global_position + Vector3(0, 1.5, 0), -4.0)


func _ghostify(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = Mats.ghost()
	for c in n.get_children():
		_ghostify(c)


## Head position for the camera / voice.
func head_position() -> Vector3:
	return head_anchor.global_position if head_anchor else global_position + Vector3(0, 1.6, 0)
