extends Node
## Ragdoll stability at a real table: every guest is knocked down from several directions, then
## every death style runs. Fails on launches (a body flung faster than the hit could explain),
## falling through the floor, leaving the room, jitter after landing, or never settling.
##   godot --headless --path . -- --qa --tool=res://tools/ragdoll_test.gd
const STYLES := [&"swoon", &"keel", &"spin", &"confetti", &"stagger", &"yeet"]
var fails := 0
var w: Node3D
var rb: RoomBuilder


func _ready() -> void:
	Profile.ephemeral = true
	_run()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("RAGDOLL FAIL ", what)


func _table(n: int) -> Array[Guest]:
	if w:
		w.queue_free()
		await get_tree().process_frame
	w = Node3D.new()
	w.name = "World"
	get_tree().root.add_child(w)
	rb = RoomBuilder.new()
	w.add_child(rb.build(&"parlor", n))
	var gs: Array[Guest] = []
	for i in n:
		var g := Guest.new()
		w.add_child(g)
		g.transform = rb.seats[i]
		g.setup(i, {"id": 0, "name": "Bean %d" % i, "cos": {"hat": &"top_hat"}})
		g.chair = rb.chairs[i]
		gs.append(g)
	await get_tree().create_timer(0.3).timeout
	return gs


func _body(g: Guest) -> RigidBody3D:
	return g.ragdoll_body()


## Samples a body for `secs`: peak speed, lowest point, and whether it came to rest.
func _watch(b: RigidBody3D, secs: float) -> Dictionary:
	var peak := 0.0
	var low := 99.0
	var far := 0.0
	var late_peak := 0.0
	var t := 0.0
	while t < secs and is_instance_valid(b):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var v := b.linear_velocity.length()
		peak = maxf(peak, v)
		low = minf(low, b.global_position.y)
		far = maxf(far, Vector2(b.global_position.x, b.global_position.z).length())
		if t > secs - 1.0:
			late_peak = maxf(late_peak, v + b.angular_velocity.length() * 0.3)
	return {"peak": peak, "low": low, "far": far, "late": late_peak}


func _run() -> void:
	await get_tree().process_frame
	# Knockdowns: 4 directions x every seat, recovering in between.
	var gs := await _table(6)
	var dirs := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-0.7, 0.2, 0.7), Vector3(0, -0.3, 1)]
	var knocks := 0
	for d: Vector3 in dirs:
		for g in gs:
			var world_dir := g.global_basis * d
			g.knockdown(world_dir, 1.6)
		await get_tree().physics_frame
		for g in gs:
			var b := _body(g)
			_check(b != null, "knockdown made a body")
			if b == null:
				continue
			knocks += 1
			var r := await _watch(b, 0.05)
			_check(r["peak"] < 6.0, "knockdown launch %.1f m/s" % r["peak"])
		await get_tree().create_timer(2.4).timeout
		for g in gs:
			_check(not g.is_down(), "%s recovered" % g.display_name)
			_check(g._hips.get_parent() == g._rig and g._waist.get_parent() == g._hips, "%s rig reassembled" % g.display_name)
	print("RAGDOLL knockdowns: %d" % knocks)
	# Deaths: each style on a fresh table, watched until it should have settled.
	for style: StringName in STYLES:
		gs = await _table(4)
		for g in gs:
			g.die(style)
		await get_tree().create_timer(1.8).timeout
		for g in gs:
			var b := _body(g)
			_check(b != null, "%s: a body" % style)
			if b == null:
				continue
			var r := await _watch(b, 5.0 if style != &"yeet" else 6.0)
			_check(r["low"] > -0.05, "%s: fell through the floor (y %.2f)" % [style, r["low"]])
			_check(r["far"] < 7.0, "%s: left the room (%.1f m)" % [style, r["far"]])
			_check(r["late"] < 0.6, "%s: still jittering after landing (%.2f)" % [style, r["late"]])
			_check(r["peak"] < (20.0 if style == &"yeet" else 9.0), "%s: launched at %.1f m/s" % [style, r["peak"]])
			print("RAGDOLL %s seat %d peak %.1f low %.2f far %.1f late %.2f" % [style, g.seat, r["peak"], r["low"], r["far"], r["late"]])
	print("RAGDOLL %s (%d failures)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
