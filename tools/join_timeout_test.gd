extends Node
## Joining a lobby whose host never answers must end in a clear message, not "Joining..." forever.
##   godot --headless --path . -- --qa --fake-steam=7 --tool=res://tools/join_timeout_test.gd
func _ready() -> void:
	Profile.ephemeral = true
	var got := [""]
	var steps: Array[String] = []
	Net.connection_failed.connect(func(r: String) -> void: got[0] = r)
	Net.join_progress.connect(func(t: String) -> void: steps.append(t))
	await get_tree().create_timer(0.3).timeout
	var t0 := Time.get_ticks_msec()
	Steamworks.join_lobby(9)   # fake lobby 9: nobody is listening there
	while got[0] == "" and Time.get_ticks_msec() - t0 < 40000:
		await get_tree().process_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("JOINTIMEOUT progress: %s" % str(steps))
	var ok: bool = String(got[0]).contains("didn't answer") and secs < 30.0
	print("JOINTIMEOUT %s after %.0fs: %s" % ["OK" if ok else "FAIL", secs, got[0].left(60)])
	get_tree().quit(0 if ok else 1)
