class_name Cake
extends Node3D
## A cupcake lobbed across the table. The host has already decided what it hits, so it flies an
## exact arc to that point (every player sees the same throw) and then calls `on_land`. A miss
## bounces off whatever is there and leaves a splat of frosting.

const FROSTINGS := [Color("ff8fb8"), Color("fff4e0"), Color("8ee3c0"), Color("c3a6ff"), Color("ffe066")]

var frosting := Color.WHITE
var on_land: Callable
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 0.5
var _spin := Vector3.ZERO
var _ghost := false


static func flight_time(from: Vector3, to: Vector3) -> float:
	return clampf(from.distance_to(to) / 7.0, 0.3, 0.9)


static func throw_from(world: Node3D, from: Vector3, to: Vector3, seed_value: int, landed: Callable, ghostly: bool = false) -> Cake:
	var c := Cake.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	c.frosting = FROSTINGS[rng.randi_range(0, FROSTINGS.size() - 1)]
	c._from = from
	c._to = to
	c._dur = flight_time(from, to)
	c._spin = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
	c.on_land = landed
	c._ghost = ghostly
	world.add_child(c)
	c.global_position = from
	Sfx.play_at(&"whoosh", from, -4.0, 0.2)
	return c


func _ready() -> void:
	var g := Mats.ghost() if _ghost else null
	Mats.mesh(self, Mats.cylinder(0.09, 0.07, 0.1, 12), g if g else Mats.solid(Color("c98a52"), 0.7), Vector3(0, -0.03, 0))
	Mats.mesh(self, Mats.sphere(0.095, 0.14, 12), g if g else Mats.solid(frosting, 0.5), Vector3(0, 0.05, 0))
	Mats.mesh(self, Mats.sphere(0.03), g if g else Mats.solid(Color("e0223a"), 0.3), Vector3(0, 0.12, 0))


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	var arc := sin(k * PI) * clampf(_from.distance_to(_to) * 0.18, 0.25, 1.0)
	global_position = _from.lerp(_to, k) + Vector3(0, arc, 0)
	rotation += _spin * delta
	if k >= 1.0:
		set_process(false)
		if on_land.is_valid():
			on_land.call(self)
		queue_free()


## Leave a splat where it landed.
static func splat(world: Node3D, at: Vector3, color: Color) -> void:
	Sfx.play_at(&"splat", at, -4.0, 0.2)
	var s := Mats.mesh(world, Mats.sphere(0.12, 0.08, 12), Mats.solid(color, 0.6), at, Vector3.ZERO, Vector3(1.4, 0.35, 1.4))
	world.get_tree().create_timer(25.0).timeout.connect(s.queue_free)
