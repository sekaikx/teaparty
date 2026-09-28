extends Node
## Screenshots of the throw-out role reveal: starts a solo match, and at the first vote injects a
## vote_result for one guest (as the host would), then captures the sequence.
##   xvfb-run -a godot --rendering-driver vulkan --path . -- --qa --tool=res://tools/reveal_shots.gd
var out := "/tmp/claude-0/reveal"
var _done := false


func _ready() -> void:
	Profile.ephemeral = true
	DirAccess.make_dir_recursive_absolute(out)
	var role := &"poisoner"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--as="):
			role = StringName(a.get_slice("=", 1))
	await get_tree().create_timer(1.0).timeout
	Net.solo(5)
	await get_tree().create_timer(1.0).timeout
	Net.start_match()
	while Session.phase != Defs.Phase.TALK:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	var target := 1 if Session.my_seat != 1 else 2
	Session.game_event.emit({"type": "vote_result", "ejected": target, "role": role, "votes": {0: target, 2: target, 3: target}, "tally": {}})
	var prev := 0.0
	for t in [0.6, 1.6, 2.7, 3.9, 4.8, 6.0]:
		await get_tree().create_timer(t - prev).timeout
		prev = t
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%.1f.png" % [out, role, t])
	print("REVEAL shots done")
	get_tree().quit()
