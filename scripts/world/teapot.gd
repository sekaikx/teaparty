class_name Teapot
extends Node3D
## A guest's teapot. pour_into() plays the whole lift - tilt - stream - return; the local
## player can also drag it (follow()) before letting it pour. Clickable (layer 8, meta "teapot").

const SCALE := 0.85

signal poured

var seat := -1
var home := Vector3.ZERO
var busy := false
var held := false

var _pot: Node3D
var _stream: MeshInstance3D
var _shell: MeshInstance3D


func setup(p_seat: int, body: Color, trim: Color) -> void:
	seat = p_seat
	name = "Teapot%d" % p_seat
	_pot = Tableware.build_teapot(body, trim, SCALE)
	add_child(_pot)
	_stream = Mats.mesh(self, Mats.cylinder(0.018, 0.012, 1.0, 8), Mats.solid(Color("8a4a1f"), 0.1))
	_stream.visible = false
	_shell = Mats.mesh(_pot, Mats.sphere(0.24, 0.4), Mats.highlight(Color("f0c75a")), Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.1, 1, 1.1))
	_shell.visible = false
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.set_meta(&"teapot", self)
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	shape.shape = sph
	shape.position = Vector3(0, 0.18, 0)
	area.add_child(shape)
	add_child(area)


func set_highlight(on: bool) -> void:
	_shell.visible = on


## While held by the local player: hover at `point` (a spot on the table).
func follow(point: Vector3, delta: float) -> void:
	held = true
	position = position.lerp(point + Vector3(0, 0.35, 0), clampf(delta * 14.0, 0.0, 1.0))
	_pot.rotation.z = lerpf(_pot.rotation.z, -0.15, clampf(delta * 8.0, 0.0, 1.0))


func put_back() -> void:
	held = false
	var tw := create_tween()
	tw.tween_property(self, "position", home, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_pot, "rotation", Vector3.ZERO, 0.3)


## Lift, carry to the cup, tilt and pour, then go home. `cup_pos` is the cup's local position
## (same parent as the teapot). Calls `on_filled` when the tea lands.
func pour_into(cup_pos: Vector3, on_filled: Callable = Callable()) -> void:
	if busy:
		return
	busy = true
	held = false
	var to_cup := (cup_pos - position)
	to_cup.y = 0
	var yaw := atan2(-to_cup.z, to_cup.x)   # spout (+X) towards the cup
	var dir := to_cup.normalized() if to_cup.length() > 0.01 else Vector3.RIGHT
	var stand := cup_pos - dir * 0.34 * SCALE + Vector3(0, 0.3, 0)
	var tw := create_tween()
	tw.tween_property(self, "position", stand, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "rotation:y", yaw, 0.35)
	tw.tween_property(_pot, "rotation:z", -0.95, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_show_stream(cup_pos)
		Sfx.play_at(&"pour", global_position, -2.0))
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void:
		_stream.visible = false
		if on_filled.is_valid():
			on_filled.call())
	tw.tween_property(_pot, "rotation:z", 0.0, 0.3)
	tw.tween_property(self, "position", home, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "rotation:y", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		busy = false
		poured.emit())


func _show_stream(cup_pos: Vector3) -> void:
	var tip := _pot.global_transform * Tableware.spout_tip()
	var target := get_parent_node_3d().global_transform * (cup_pos + Vector3(0, 0.17, 0))
	var length := tip.distance_to(target)
	_stream.visible = true
	_stream.global_position = (tip + target) * 0.5
	_stream.global_basis = _basis_along((tip - target).normalized())
	_stream.scale = Vector3(1, maxf(length, 0.01), 1)


static func _basis_along(up: Vector3) -> Basis:
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)
