extends Node
## Connections and the lobby. ENet, host-authoritative: the host (peer 1) owns the roster,
## the lobby rules and, once a match starts, the game itself (Session).
##   Net.solo()                      host a private table for you and bots
##   Net.host_game(port)             open a table others can join on your LAN / over port forward
##   Net.join_game(ip, port)
##   Net.host_steam(public) / Steamworks.join_lobby(id)   online over Steam (Spacewar, App ID 480)
## The roster maps peer id -> {id, name, level, cos, bot, ready}. Bots use ids from BOT_ID_BASE.

signal roster_changed
signal rules_changed
signal joined_lobby
signal connection_failed(reason: String)
signal left_lobby(reason: String)
## What a Steam join is doing right now ("Calling the host..."), for the online panel.
signal join_progress(text: String)
## A text chat line: {name, text, ghost, seat, id}.
signal chat_received(msg: Dictionary)

const CHAT_MAX := 140
var _chat_ready: Dictionary = {}

const DEFAULT_PORT := 24565
const MAX_PEERS := 7
const BOT_ID_BASE := 1_000_000

var roster: Dictionary = {}
var rules: Dictionary = Defs.default_rules()
var is_solo := false
var is_steam := false
var in_lobby := false
var _next_bot := 0
var _bot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		_fail(STEAM_NO_ANSWER if is_steam else "Could not reach that table."))
	multiplayer.server_disconnected.connect(func() -> void: leave("The host closed the table."))
	_bot_rng.randomize()
	Steamworks.lobby_entered.connect(_on_steam_lobby_entered)
	Steamworks.lobby_failed.connect(func(reason: String) -> void: _fail(reason))


## Host a tea party on Steam: friends join from the invite overlay, the browser or the code.
func host_steam(public: bool) -> Error:
	if not Steamworks.available:
		_fail(Steamworks.reason)
		return ERR_UNAVAILABLE
	_reset()
	var peer := Steamworks.make_peer()
	var err: Error = peer.call(&"create_host", 0)
	if err != OK:
		_fail("Couldn't open a Steam connection (%s)." % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_steam = true
	_enter_as_host()
	Steamworks.create_lobby(public, int(rules["max_players"]))
	return OK


var joining := false
var _join_serial := 0
const JOIN_TIMEOUT := 25.0
const STEAM_NO_ANSWER := "The host didn't answer over Steam. Check: the host is still in the lobby, both of you have Steam open (and are not in Offline Mode), and the host's firewall allows Tea Party. Then try the code again. (Details: net_log.txt in the game's data folder.)"


func join_steam_pending() -> void:
	if multiplayer.multiplayer_peer and not is_solo:
		leave()
	joining = true
	join_progress.emit("Joining the Steam lobby...")


func _on_steam_lobby_entered(_lobby: int, owner: int) -> void:
	_reset()
	joining = true
	var peer := Steamworks.make_peer()
	var err: Error = peer.call(&"create_client", owner, 0)
	if err != OK:
		_fail("Couldn't connect to the host over Steam (%s)." % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	is_steam = true
	join_progress.emit("In the lobby. Calling the host over Steam's relay...")
	# If the host never answers, say so instead of "Joining..." forever.
	_join_serial += 1
	var serial := _join_serial
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(func() -> void:
		if serial == _join_serial and joining and not in_lobby:
			_fail(STEAM_NO_ANSWER))
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if serial == _join_serial and joining and not in_lobby:
			join_progress.emit("Still calling the host... (Steam can take a few seconds the first time)"))


## The code friends type to join (the Steam lobby id).
func steam_code() -> String:
	return str(Steamworks.lobby_id) if is_steam and Steamworks.lobby_id != 0 else ""


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1


func _me() -> Dictionary:
	var nm := Steamworks.friendly_name() if Steamworks.available and Profile.use_steam_name else Profile.player_name
	return {"id": my_id(), "name": nm, "level": Profile.level(), "cos": Profile.look(),
		"bot": false, "ready": false}


# ---------------------------------------------------------------- open / close

func solo(bots: int = 3) -> void:
	_reset()
	is_solo = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enter_as_host()
	for i in bots:
		add_bot()


## PLAY NOW: straight into a 6-guest party with bots, no lobby.
func quick_play() -> void:
	solo(5)
	start_match.call_deferred()


func host_game(port: int = DEFAULT_PORT) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		_fail("Could not open port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_enter_as_host()
	return OK


func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		_fail("Could not connect (%s)." % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave(reason: String = "") -> void:
	var was := in_lobby or multiplayer.multiplayer_peer != null
	Session.abort()
	if is_steam:
		Steamworks.leave_lobby()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_reset()
	if was:
		left_lobby.emit(reason)


func _reset() -> void:
	roster.clear()
	rules = Defs.default_rules()
	is_solo = false
	is_steam = false
	joining = false
	in_lobby = false
	_next_bot = 0


func _enter_as_host() -> void:
	roster[1] = _me()
	roster[1]["id"] = 1
	in_lobby = true
	# Rooms / modes the host has not unlocked fall back to the defaults.
	if not Profile.is_unlocked_room(StringName(rules["room"])):
		rules["room"] = &"parlor"
	joined_lobby.emit()
	roster_changed.emit()
	rules_changed.emit()


func _fail(reason: String) -> void:
	print("[Net] ", reason)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	if is_steam:
		Steamworks.leave_lobby()
	_reset()
	connection_failed.emit(reason)


# ---------------------------------------------------------------- text chat (for players without a mic)

## Send a chat line. Everyone at the table sees it; a ghost's line only reaches other ghosts
## (the dead don't talk to the living).
func send_chat(text: String) -> void:
	var t := text.replace("\n", " ").replace("\r", " ").strip_edges().left(CHAT_MAX)
	if t == "":
		return
	if multiplayer.multiplayer_peer == null or is_host():
		_host_chat(my_id(), t)
	else:
		_rq_chat.rpc_id(1, t)


@rpc("any_peer", "reliable")
func _rq_chat(text: String) -> void:
	if is_host():
		_host_chat(multiplayer.get_remote_sender_id(), String(text).replace("\n", " ").strip_edges().left(CHAT_MAX))


func _host_chat(from_id: int, text: String) -> void:
	if text == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_chat_ready.get(from_id, 0.0)):
		return
	_chat_ready[from_id] = now + 0.6
	var nm := String(roster.get(from_id, {}).get("name", "Guest"))
	var seat := Session.seat_of_peer(from_id)
	if seat >= 0:
		nm = Session.seat_name(seat)
	var ghost := Session.running and seat >= 0 and not Session.seat_alive_host(seat)
	var msg := {"id": from_id, "name": nm, "text": text, "ghost": ghost, "seat": seat}
	if not ghost or multiplayer.multiplayer_peer == null or is_solo:
		if multiplayer.multiplayer_peer == null or is_solo:
			_chat(msg)
		else:
			_chat.rpc(msg)
		return
	# Ghost line: only to the other ghosts (and the host, if they're a ghost too).
	for id: int in roster:
		if id >= BOT_ID_BASE:
			continue
		var s := Session.seat_of_peer(id)
		if s >= 0 and not Session.seat_alive_host(s):
			if id == my_id():
				_chat(msg)
			else:
				_chat.rpc_id(id, msg)


@rpc("authority", "call_local", "reliable")
func _chat(msg: Dictionary) -> void:
	chat_received.emit(msg)


# ---------------------------------------------------------------- peers

func _on_connected() -> void:
	_register.rpc_id(1, _me())


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if roster.has(id):
		roster.erase(id)
		Session.on_peer_left(id)
		_broadcast_roster()


@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if Session.running or _seat_count() >= int(rules["max_players"]):
		_rejected.rpc_id(id, "That table is full or already mid-party.")
		return
	roster[id] = {"id": id, "name": String(info.get("name", "Guest")).left(24), "level": int(info.get("level", 1)),
		"cos": info.get("cos", {}), "bot": false, "ready": false}
	_broadcast_roster()
	_set_rules.rpc_id(id, rules)


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


func _broadcast_roster() -> void:
	roster_changed.emit()
	if not is_solo:
		_set_roster.rpc(roster)


@rpc("authority", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	if not in_lobby:
		in_lobby = true
		joining = false
		if is_steam:
			Steamworks.net_log("in the host's lobby")
		joined_lobby.emit()
	roster_changed.emit()


@rpc("authority", "reliable")
func _set_rules(r: Dictionary) -> void:
	rules = r
	rules_changed.emit()


# ---------------------------------------------------------------- lobby (host)

func _seat_count() -> int:
	return roster.size()


func max_seats() -> int:
	return mini(int(rules["max_players"]), int(Defs.ROOMS[StringName(rules["room"])]["seats"]))


func add_bot() -> void:
	if not is_host() or _seat_count() >= max_seats():
		return
	var id := BOT_ID_BASE + _next_bot
	_next_bot += 1
	var names: Array = Defs.BOT_NAMES.duplicate()
	for p: Dictionary in roster.values():
		names.erase(p["name"])
	var bot_name: String = names[_bot_rng.randi_range(0, names.size() - 1)] if not names.is_empty() else "Bot %d" % _next_bot
	roster[id] = {"id": id, "name": bot_name, "level": _bot_rng.randi_range(1, 12),
		"cos": Cosmetics.random_look(_bot_rng), "bot": true, "ready": true}
	_broadcast_roster()


func remove_bot() -> void:
	if not is_host():
		return
	var ids := roster.keys()
	ids.sort()
	for i in range(ids.size() - 1, -1, -1):
		if roster[ids[i]]["bot"]:
			roster.erase(ids[i])
			_broadcast_roster()
			return


func set_rule(key: String, value: Variant) -> void:
	if not is_host():
		return
	rules[key] = value
	if key == "room" or key == "max_players":
		while _seat_count() > max_seats() and _has_bots():
			remove_bot()
	rules_changed.emit()
	if not is_solo:
		_set_rules.rpc(rules)


func _has_bots() -> bool:
	for p: Dictionary in roster.values():
		if p["bot"]:
			return true
	return false


## Guests toggle ready; the host can start once everyone is.
func set_ready(on: bool) -> void:
	if is_host():
		_ready_changed(on)
	else:
		_ready_changed.rpc_id(1, on)


@rpc("any_peer", "reliable")
func _ready_changed(on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if roster.has(id):
		roster[id]["ready"] = on
		_broadcast_roster()


## Keeps the roster's look / name in sync when the player changes it in the lobby.
func refresh_me() -> void:
	if not in_lobby:
		return
	if is_host():
		_update_me(_me())
	else:
		_update_me.rpc_id(1, _me())


@rpc("any_peer", "reliable")
func _update_me(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if roster.has(id):
		roster[id]["name"] = String(info.get("name", "Guest")).left(24)
		roster[id]["cos"] = info.get("cos", {})
		roster[id]["level"] = int(info.get("level", 1))
		_broadcast_roster()


func can_start() -> String:
	if not is_host():
		return "Only the host can start."
	if _seat_count() < 3:
		return "Need at least 3 guests (add bots)."
	for id: int in roster:
		if id != 1 and not roster[id]["ready"]:
			return "Waiting for everyone to be ready."
	return ""


func start_match() -> void:
	if can_start() != "":
		return
	var players: Array = []
	var ids := roster.keys()
	ids.sort()
	for id: int in ids:
		players.append(roster[id])
	# Shuffle seating so the host is not always seat 0.
	for i in range(players.size() - 1, 0, -1):
		var j := _bot_rng.randi_range(0, i)
		var t: Variant = players[i]
		players[i] = players[j]
		players[j] = t
	Steamworks.set_lobby_joinable(false)
	Session.host_start(players, rules.duplicate(true))
