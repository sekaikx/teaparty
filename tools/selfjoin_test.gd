extends Node
## Joining your own Steam lobby (one account, two copies) should explain itself, not hang.
##   godot --headless --path . -- --qa --fake-steam=5 --tool=res://tools/selfjoin_test.gd
func _ready() -> void:
	Profile.ephemeral = true
	var got := [""]
	Net.connection_failed.connect(func(r: String) -> void: got[0] = r)
	await get_tree().create_timer(0.3).timeout
	Steamworks.join_lobby(Steamworks.steam_id)
	await get_tree().create_timer(1.0).timeout
	var ok := String(got[0]).contains("your own party")
	print("SELFJOIN %s %s" % ["OK" if ok else "FAIL", got[0]])
	get_tree().quit(0 if ok else 1)
