class_name MenuBackdrop
extends Node3D
## Behind the menus: the parlour with a few guests idling at the table and a slow camera orbit.

var _cam: Camera3D
var _t := 0.0
var _guests: Array[Guest] = []
var _chatter := 3.0


func _ready() -> void:
	name = "World"
	var rb := RoomBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Every room is open to everyone, so the menu shows a different one each time.
	var room: StringName = [&"parlor", &"garden", &"banquet"][rng.randi_range(0, 2)]
	add_child(rb.build(room, 5))
	for i in 5:
		var g := Guest.new()
		add_child(g)
		g.transform = rb.seats[i]
		var look := Cosmetics.random_look(rng) if i > 0 else Profile.look()
		g.setup(i, {"id": 0, "name": Defs.BOT_NAMES[rng.randi_range(0, Defs.BOT_NAMES.size() - 1)] if i > 0 else Profile.player_name, "cos": look})
		g.show_tags(false)
		g.chair = rb.chairs[i]
		_guests.append(g)
		var cup := TeaCup.new()
		add_child(cup)
		cup.setup(i, StringName(str(look.get("cup", &"porcelain"))))
		cup.position = rb.cup_spots[i]
		cup.set_filled(true)
		var pot := Teapot.new()
		add_child(pot)
		pot.setup(i, Color("f4f1ea"), Color("2e5f9a"))
		pot.position = rb.pot_spots[i]
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	Sfx.music(&"waltz")
	Sfx.ambience(rb.ambience)


func _process(delta: float) -> void:
	_t += delta * 0.06
	var eye := Vector3(sin(_t) * 6.2, 5.0, cos(_t) * 6.2)
	_cam.global_transform = Transform3D(Basis(), eye).looking_at(Vector3(0, 0.9, 0), Vector3.UP)
	_chatter -= delta
	if _chatter <= 0.0 and not _guests.is_empty():
		_chatter = randf_range(2.5, 5.5)
		var g := _guests[randi() % _guests.size()]
		var e: Dictionary = Defs.EMOTES[randi() % Defs.EMOTES.size()]
		g.gesture(e["clip"])
		g.say(e["line"], 2.0)
