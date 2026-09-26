extends Node
## QA harness, added by app.gd when run with `-- --qa ...`:
##   --solo                 play a match against bots (the local seat is auto-played)
##   --host / --join=IP     two-process network test (host waits for one client, adds bots)
##   --room=garden          room and --mode=butler
##   --speed=N              run timers N times faster
##   --shots=DIR            save screenshots at each phase into DIR (needs a real renderer)
##   --matches=N            play N matches back to back (lobby between)
## Prints "QA DONE <matches> matches" and quits; exit code 1 if a match never ended.

var shots := ""
var speed := 1.0
var room := &"parlor"
var mode := &"classic"
var matches_wanted := 1
var matches_done := 0
var _brain: BotBrain
var _wait := 0.0
var _last_phase := -1
var _shot_n := 0
var _deadline := 0.0
var _is_host := false
var _join_ip := ""
var _started := false
var _took: Dictionary = {}


func _ready() -> void:
	Profile.ephemeral = true
	Profile.xp = 2000   # everything unlocked for testing
	Profile.settings["tutorial_seen"] = true
	Profile.coins = 5000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(shots)
		elif a.begins_with("--speed="):
			speed = float(a.get_slice("=", 1))
		elif a.begins_with("--room="):
			room = StringName(a.get_slice("=", 1))
		elif a.begins_with("--mode="):
			mode = StringName(a.get_slice("=", 1))
		elif a.begins_with("--matches="):
			matches_wanted = int(a.get_slice("=", 1))
		elif a == "--host":
			_is_host = true
		elif a.begins_with("--join="):
			_join_ip = a.get_slice("=", 1)
	Session.speed = speed
	Session.match_over.connect(_on_over)
	_deadline = 600.0
	if "--solo" in OS.get_cmdline_user_args():
		_shot("title", 1.0)
		await get_tree().create_timer(1.5).timeout
		Net.solo()
		for i in 2:
			Net.add_bot()
		_apply_rules()
		await get_tree().create_timer(1.0).timeout
		_shot("lobby", 0.0)
		await get_tree().create_timer(0.8).timeout
		Net.start_match()
	elif _is_host:
		Net.host_game()
		Net.roster_changed.connect(_host_roster)
	elif _join_ip != "":
		Net.joined_lobby.connect(func() -> void:
			await get_tree().create_timer(0.5).timeout
			Net.set_ready(true))
		Net.join_game(_join_ip)


func _apply_rules() -> void:
	Net.set_rule("room", room)
	Net.set_rule("mode", mode)
	Net.set_rule("pour_time", 12.0)
	Net.set_rule("item_turn_time", 6.0)
	Net.set_rule("talk_time", 10.0)


func _host_roster() -> void:
	if _started or Net.roster.size() < 2:
		return
	for id: int in Net.roster:
		if id != 1 and not Net.roster[id].get("ready", false):
			return
	_started = true
	for i in 3:
		Net.add_bot()
	_apply_rules()
	await get_tree().create_timer(0.5).timeout
	Net.start_match()


func _on_over(res: Dictionary) -> void:
	matches_done += 1
	print("QA MATCH %d OVER: %s winners=%s award=%s" % [matches_done, res.get("reason", ""), str(res.get("winners", [])), str(res.get("award", {}))])
	_shot("results", 2.5)
	await get_tree().create_timer(3.5).timeout
	if matches_done >= matches_wanted:
		print("QA DONE %d matches" % matches_done)
		get_tree().quit(0)
	elif Net.is_host():
		await get_tree().create_timer(1.0).timeout
		Net.start_match()


func _process(delta: float) -> void:
	_deadline -= delta
	if _deadline <= 0.0:
		push_error("QA timeout: match did not finish")
		get_tree().quit(1)
		return
	if not Session.running or Session.my_seat < 0:
		return
	if _brain == null or _brain.seat != Session.my_seat:
		_brain = BotBrain.new(Session.my_seat, 99)
	var ph := Session.phase
	if ph != _last_phase:
		_last_phase = ph
		_wait = randf_range(0.5, 1.5) / speed
		if ph == Defs.Phase.POUR or ph == Defs.Phase.DEAL:
			_brain.new_round(Session.public)
		var key := "%s_r%d" % [Defs.PHASE_NAMES[ph].to_lower().replace(" ", "_").replace("!", ""), int(Session.public.get("round", 0))]
		if ph in [Defs.Phase.INTRO, Defs.Phase.POUR, Defs.Phase.ITEMS, Defs.Phase.TALK]:
			_shot(key, 1.2)
		elif ph == Defs.Phase.DRINK:
			_shot(key + "_drinking", 5.0 / speed + 2.6)
		elif ph == Defs.Phase.REVEAL:
			_shot(key, 4.5)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.4 / speed
	_autoplay()


## Plays the local seat with the bot brain, through the same requests a player's clicks send.
func _autoplay() -> void:
	var table := get_tree().current_scene.get_node_or_null("World") as TableView
	var priv := Session.private
	var pub := Session.public
	match Session.phase:
		Defs.Phase.POUR:
			if Session.am_alive() and not bool(Session.seat_info(Session.my_seat).get("poured", false)):
				if table and not table.tea_poured and not _took.has("pour%d" % pub.get("round", 0)):
					_took["pour%d" % pub.get("round", 0)] = true
					var cup := table.cup_at_seat(table.pour_target())
					table.pots[Session.my_seat].pour_into(cup.position, func() -> void:
						cup.set_filled(true)
						table.tea_poured = true)
					return
				if table and not table.tea_poured:
					return
				Session.request_pour(_brain.choose_pour(priv, pub))
				var sp := _brain.choose_spike(priv, pub)
				if sp >= 0:
					Session.request_spike(sp)
			elif not Session.am_alive() and int(Session.seat_info(Session.my_seat).get("rattles", 0)) > 0 and randf() < 0.3:
				var t := _brain.choose_rattle(priv, pub)
				if t >= 0:
					Session.request_rattle(t)
		Defs.Phase.ITEMS:
			if Session.is_my_turn():
				var choice := _brain.choose_item(priv, pub)
				if choice.is_empty():
					Session.request_pass()
				else:
					Session.request_item(choice["index"], choice["targets"])
				_wait = 2.0 / speed
		Defs.Phase.TALK:
			if Session.am_alive() and not bool(Session.seat_info(Session.my_seat).get("ready", false)):
				if randf() < 0.3:
					Session.request_emote(randi() % Defs.EMOTES.size())
				if randf() < 0.5:
					Session.request_throw(Vector3(randf_range(-1, 1), 1.3, randf_range(-1, 1)))
				Session.request_ready_up()


func _shot(key: String, after: float) -> void:
	if shots == "" or _took.has("shot_" + key):
		return
	_took["shot_" + key] = true
	await get_tree().create_timer(after).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_n += 1
	var path := "%s/%02d_%s.png" % [shots, _shot_n, key]
	img.save_png(path)
	print("QA SHOT ", path)
