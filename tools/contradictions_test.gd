extends Node
## The meeting board's "doesn't add up" checks against a made-up meeting.
##   godot --headless --path . -- --qa --tool=res://tools/contradictions_test.gd
func _ready() -> void:
	var h := GameHud.new()
	var I := Defs.Ingredient
	# Ada (0) died: her cup held POISON + PLAIN. Baron (1) says SUGAR into Ada's: a lie. Clara (2)
	# says PLAIN into Ada's: fits. Dev (3) also says PLAIN into Ada's: one too many. Eli (4) saw
	# Finn (5) pour into Ada's, but Finn says he poured into Clara's.
	h.set("_revealed", [{"seat": 0, "kinds": [I.NOTHING, I.POISON], "died": true}])
	h.set("_said", [
		{"seat": 1, "kind": &"poured", "a": 0, "k": I.SUGAR},
		{"seat": 2, "kind": &"poured", "a": 0, "k": I.NOTHING},
		{"seat": 3, "kind": &"poured", "a": 0, "k": I.NOTHING},
		{"seat": 5, "kind": &"poured", "a": 2, "k": I.SUGAR},
		{"seat": 4, "kind": &"saw", "a": 5, "b": 0},
	])
	var out: Array = h.call(&"_contradictions")
	for l in out:
		print("CONTRA ", l)
	print("CONTRA count=%d %s" % [out.size(), "OK" if out.size() == 3 else "FAIL"])
	h.free()
	get_tree().quit(0 if out.size() == 3 else 1)
