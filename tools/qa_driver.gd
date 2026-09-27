extends Node
## QA harness, added by app.gd when run with `-- --qa ...`:
##   --solo                 play a match against bots (the local seat is auto-played)
##   --host / --join=IP     two-process network test (host waits for one client, adds bots)
##   --steam-host / --steam-join=HOST_ID  the same over SteamPeer (use with --fake-steam=N)
##   --room=garden          room and --mode=butler
##   --speed=N              run timers N times faster
##   --shots=DIR            save screenshots at each phase into DIR (needs a real renderer)
##   --matches=N            play N matches back to back (lobby between)
##   --pace                 keep the real timers and print how long each phase takes + cake stats
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
var _steam := false
var _steam_join := 0
var _started := false
var _took: Dictionary = {}
var _serve: Dictionary = {}
var _pace := false
var _phase_time: Dictionary = {}
var _cake_stats: Dictionary = {}
var _rounds := 0


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
		elif a == "--steam-host":
			_is_host = true
			_steam = true
		elif a.begins_with("--steam-join="):
			_steam_join = int(a.get_slice("=", 1))
	Session.speed = speed
	Session.match_over.connect(_on_over)
	_pace = "--pace" in OS.get_cmdline_user_args()
	Session.game_event.connect(_count_event)
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
		if _steam:
			var err := Net.host_steam(false)
			print("QA STEAM HOST %s" % error_string(err))
		else:
			Net.host_game()
		Net.roster_changed.connect(_host_roster)
	elif _steam_join != 0:
		Net.joined_lobby.connect(func() -> void:
			print("QA STEAM JOINED")
			await get_tree().create_timer(0.5).timeout
			Net.set_ready(true))
		Steamworks.join_lobby(_steam_join)
	elif _join_ip != "":
		Net.joined_lobby.connect(func() -> void:
			await get_tree().create_timer(0.5).timeout
			Net.set_ready(true))
		Net.join_game(_join_ip)


func _count_event(ev: Dictionary) -> void:
	match String(ev.get("type", "")):
		"cake":
			var k := String(ev.get("hit", "miss")) + ("_ghost" if ev.get("ghost", false) else "")
			_cake_stats[k] = int(_cake_stats.get(k, 0)) + 1
			if ev.get("spilled", false):
				_cake_stats["spilled"] = int(_cake_stats.get("spilled", 0)) + 1
		"round":
			_rounds += 1
		"moments":
			for m: Dictionary in ev.get("list", []):
				var t := "moment " + String(m["title"])
				_cake_stats[t] = int(_cake_stats.get(t, 0)) + 1
		"talking_points":
			if _pace and _rounds == 1:
				print("QA TALKING POINTS %s" % str(ev["lines"]))


func _apply_rules() -> void:
	if "--night" in OS.get_cmdline_user_args():
		Net.set_rule("night", true)
	if _pace:
		Net.set_rule("room", room)
		Net.set_rule("mode", mode)
		return
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
	if _pace:
		var total := 0.0
		var parts: Array[String] = []
		for ph: int in _phase_time:
			total += float(_phase_time[ph])
			parts.append("%s %.0fs" % [Defs.Phase.keys()[ph], float(_phase_time[ph]) / maxi(_rounds, 1)])
		print("QA PACE rounds=%d match=%.0fs per-round avg: %s" % [_rounds, total, ", ".join(parts)])
		print("QA CAKES %s awards=%s" % [str(_cake_stats), str(res.get("awards", []))])
	_shot("results", 2.5)
	await get_tree().create_timer(3.5).timeout
	if matches_done >= matches_wanted:
		print("QA DONE %d matches" % matches_done)
		get_tree().quit(0)
	elif Net.is_host():
		await get_tree().create_timer(1.0).timeout
		Net.start_match()


func _process(delta: float) -> void:
	if Session.running:
		_phase_time[Session.phase] = float(_phase_time.get(Session.phase, 0.0)) + delta * speed
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
		if _pace:
			# Roughly how long a first-time player takes to act in each phase.
			_wait = ({Defs.Phase.POUR: 8.0, Defs.Phase.ITEMS: 6.0, Defs.Phase.TALK: 15.0} as Dictionary).get(ph, 0.5) / speed
		if ph == Defs.Phase.POUR or ph == Defs.Phase.DEAL:
			_brain.new_round(Session.public)
		var key := "%s_r%d" % [Defs.PHASE_NAMES[ph].to_lower().replace(" ", "_").replace("!", ""), int(Session.public.get("round", 0))]
		if ph in [Defs.Phase.INTRO, Defs.Phase.POUR, Defs.Phase.ITEMS]:
			_shot(key, 1.2)
		elif ph == Defs.Phase.TALK:
			_shot(key, 6.0)
		elif ph == Defs.Phase.DRINK:
			_shot(key + "_drinking", 5.0 / speed + 2.6)
		elif ph == Defs.Phase.REVEAL:
			_shot(key, 4.5)
		elif ph == Defs.Phase.VOTE:
			_shot(key, 1.0)
		elif ph == Defs.Phase.EJECT:
			_shot(key, 2.2)
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
				if _serve.is_empty():
					_serve = _brain.choose_serve(priv, pub)
				if _serve.is_empty():
					return
				if table and not table.tea_poured and not _took.has("pour%d" % pub.get("round", 0)):
					_took["pour%d" % pub.get("round", 0)] = true
					table.serve_to = int(_serve["target"])
					var cup := table.cup_at_seat(table.serve_to)
					table.pots[Session.my_seat].pour_into(cup.position, func() -> void:
						cup.set_filled(true)
						table.tea_poured = true)
					return
				if table and not table.tea_poured:
					return
				Session.request_pour(int(_serve["index"]), int(_serve["target"]))
				_serve = {}
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
				var c := _brain.next_claim(priv, pub)
				if not c.is_empty():
					Session.request_claim(c)
					_wait = 1.5 / speed
					return
				if randf() < 0.3:
					Session.request_emote(randi() % Defs.EMOTES.size())
				Session.request_ready_up()
		Defs.Phase.VOTE:
			if Session.am_alive() and not bool(Session.seat_info(Session.my_seat).get("voted", false)):
				Session.request_vote(_brain.choose_vote(pub))


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
