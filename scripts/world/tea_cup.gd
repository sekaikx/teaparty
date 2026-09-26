class_name TeaCup
extends Node3D
## One teacup on the table. Cups move between seats (swaps) and get picked up to drink.
## Clickable through its Area3D (layer 2, meta "cup" = self).

const SCALE := 1.15

var cup_id := -1
var seat := -1
var home := Vector3.ZERO

var _china: Node3D
var _tea: MeshInstance3D
var _steam: GPUParticles3D
var _shell: Node3D
var _view: Node3D
var _drops: Node3D
var _rattle_tw: Tween


func setup(p_id: int, cos_id: StringName) -> void:
	cup_id = p_id
	name = "Cup%d" % p_id
	var e := Cosmetics.entry(&"cup", cos_id)
	_china = Tableware.build_cup(e.get("body", Color.WHITE), e.get("rim", Color("2e5f9a")), SCALE)
	add_child(_china)
	_tea = Mats.mesh(self, Mats.cylinder(0.118, 0.1, 0.01, 20), Mats.solid(Color("7a3f1a"), 0.15), Vector3(0, 0.155, 0) * SCALE)
	_tea.visible = false
	_steam = _make_steam()
	add_child(_steam)
	_shell = Node3D.new()
	_shell.visible = false
	add_child(_shell)
	Mats.mesh(_shell, Mats.cylinder(0.15, 0.1, 0.2, 20), Mats.highlight(Color("f0c75a")), Vector3(0, 0.1, 0) * SCALE)
	Mats.mesh(_shell, Mats.cylinder(0.24, 0.24, 0.03, 24), Mats.highlight(Color("f0c75a")), Vector3(0, 0.015, 0) * SCALE)
	_drops = Node3D.new()
	add_child(_drops)
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.input_ray_pickable = true
	area.set_meta(&"cup", self)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.26
	cyl.height = 0.35
	shape.shape = cyl
	shape.position = Vector3(0, 0.15, 0)
	area.add_child(shape)
	add_child(area)


func _make_steam() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 2.2
	p.emitting = false
	p.position = Vector3(0, 0.2, 0) * SCALE
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.16
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.22))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	quad.material = m
	p.draw_pass_1 = quad
	return p


static var _dot: Texture2D


static func _soft_dot() -> Texture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	_dot = t
	return t


func set_filled(on: bool) -> void:
	_tea.visible = on
	_steam.emitting = on


func is_filled() -> bool:
	return _tea.visible


func set_highlight(on: bool) -> void:
	_shell.visible = on


## Small splash where an ingredient went in. `color` only for the dropper (others see a plain splash).
func splash(color: Color = Color("7a3f1a")) -> void:
	var drop := Mats.mesh(_drops, Mats.sphere(0.03), Mats.solid(color, 0.3), Vector3(0, 0.45, 0))
	var tw := create_tween()
	tw.tween_property(drop, "position:y", 0.17 * SCALE, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(drop.queue_free)
	tw.tween_property(_tea, "scale", Vector3(1.15, 1, 1.15), 0.08)
	tw.tween_property(_tea, "scale", Vector3.ONE, 0.2)


## The ghosts' rattle: a jittery shake with a clatter.
func rattle() -> void:
	if _rattle_tw and _rattle_tw.is_valid():
		_rattle_tw.kill()
	_rattle_tw = create_tween()
	for i in 10:
		_rattle_tw.tween_property(_china, "rotation", Vector3(randf_range(-0.12, 0.12), randf_range(-0.3, 0.3), randf_range(-0.12, 0.12)), 0.045)
		_rattle_tw.parallel().tween_property(_china, "position", Vector3(randf_range(-0.02, 0.02), randf_range(0.0, 0.04), randf_range(-0.02, 0.02)), 0.045)
	_rattle_tw.tween_property(_china, "rotation", Vector3.ZERO, 0.08)
	_rattle_tw.parallel().tween_property(_china, "position", Vector3.ZERO, 0.08)
	Sfx.play_at(&"rattle", global_position)


## Slide across the table to a new home (swaps). Arcs up a little so cups don't clip.
func move_home(target: Vector3, seconds: float = 0.9) -> void:
	home = target
	var mid := (position + target) * 0.5 + Vector3(0, 0.45, 0)
	var tw := create_tween()
	tw.tween_property(self, "position", mid, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: Sfx.play_at(&"clink", global_position, -6.0))


## What a ghost sees: a little floating row of coloured motes (one per ingredient).
func show_view(kinds: Array) -> void:
	if _view:
		_view.queue_free()
		_view = null
	if kinds.is_empty():
		return
	_view = Node3D.new()
	add_child(_view)
	var n := kinds.size()
	for i in n:
		var k: int = kinds[i]
		var c: Color = Defs.INGREDIENTS[k]["color"]
		var mote := Mats.mesh(_view, Mats.sphere(0.045), Mats.glow(c, 1.5), Vector3((i - (n - 1) * 0.5) * 0.11, 0.42, 0))
		var tw := mote.create_tween().set_loops()
		tw.tween_property(mote, "position:y", 0.47, 0.8 + i * 0.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mote, "position:y", 0.42, 0.8 + i * 0.1).set_trans(Tween.TRANS_SINE)
