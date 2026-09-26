class_name Cake
extends RigidBody3D
## A cupcake lobbed across the table. Harmless, but it bonks heads, leaves frosting on faces and
## tablecloths, rattles cups and knocks corpses about. Every peer simulates its own copy.

const FROSTINGS := [Color("ff8fb8"), Color("fff4e0"), Color("8ee3c0"), Color("c3a6ff"), Color("ffe066")]

var thrower: Guest
var frosting := Color.WHITE
var _hit := false


static func throw_from(world: Node3D, from: Vector3, to: Vector3, p_thrower: Guest, seed_value: int) -> Cake:
	var c := Cake.new()
	c.thrower = p_thrower
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	c.frosting = FROSTINGS[rng.randi_range(0, FROSTINGS.size() - 1)]
	world.add_child(c)
	if p_thrower:
		for b in p_thrower.hitboxes():
			c.add_collision_exception_with(b)
	c.global_position = from
	var t := clampf(from.distance_to(to) / 8.0, 0.25, 0.9)
	var v := (to - from) / t - 0.5 * Vector3(0, -9.8, 0) * t
	c.linear_velocity = v
	c.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	Sfx.play_at(&"whoosh", from, -4.0, 0.2)
	return c


func _ready() -> void:
	collision_layer = Guest.L_PROPS
	collision_mask = Guest.L_WORLD | Guest.L_RAGDOLL | Guest.L_PROPS | Guest.L_HITBOX
	mass = 0.2
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.1
	cs.shape = sph
	add_child(cs)
	Mats.mesh(self, Mats.cylinder(0.09, 0.07, 0.1, 12), Mats.solid(Color("c98a52"), 0.7), Vector3(0, -0.03, 0))
	Mats.mesh(self, Mats.sphere(0.095, 0.14, 12), Mats.solid(frosting, 0.5), Vector3(0, 0.05, 0))
	Mats.mesh(self, Mats.sphere(0.03), Mats.solid(Color("e0223a"), 0.3), Vector3(0, 0.12, 0))
	body_entered.connect(_on_hit)
	get_tree().create_timer(6.0).timeout.connect(queue_free)


func _on_hit(body: Node) -> void:
	if _hit:
		return
	var g: Guest = body.get_meta(&"guest") if body.has_meta(&"guest") else null
	if g == thrower and g != null:
		return
	_hit = true
	if g:
		g.bonk(linear_velocity.normalized(), frosting)
		g.say(["OI!", "HEY!", "RUDE!", "MY FACE!", "*gasp*", "HOW DARE YOU"][randi() % 6], 1.4, Ui.INK)
		queue_free()
		return
	Sfx.play_at(&"splat", global_position, -4.0, 0.2)
	# Leave a splat where it landed.
	var world := get_parent() as Node3D
	var splat := Mats.mesh(world, Mats.sphere(0.12, 0.08, 12), Mats.solid(frosting, 0.6), global_position - Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1.4, 0.35, 1.4))
	world.get_tree().create_timer(20.0).timeout.connect(splat.queue_free)
	queue_free()
