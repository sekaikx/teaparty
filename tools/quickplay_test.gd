extends Node
## PLAY NOW should put you at a 6-seat table with no lobby, and PLAY AGAIN should restart.
##   godot --headless --path . -- --qa --tool=res://tools/quickplay_test.gd
func _ready() -> void:
	Profile.ephemeral = true
	await get_tree().create_timer(0.5).timeout
	Net.quick_play()
	await get_tree().create_timer(1.0).timeout
	var ok := Session.running and Session.seat_count() == 6
	print("QUICKPLAY %s running=%s seats=%d" % ["OK" if ok else "FAIL", Session.running, Session.seat_count()])
	get_tree().quit(0 if ok else 1)
