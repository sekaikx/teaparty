extends Node
## Steam online play on Valve's servers, using the free "Spacewar" test app (App ID 480), with
## no Steam store page needed. Two pieces:
##   GodotSteam (GDExtension; install it from Godot's AssetLib) - Steam init, your name, lobbies,
##     invites and the friends overlay. Used through Engine.get_singleton("Steam") so the game
##     still runs (with LAN / solo only) when it's missing.
##   addons/steam-multiplayer-peer (bundled) - SteamMultiplayerPeer, which carries the game's
##     RPCs over Steam Networking Sockets (Valve's relay: no port forwarding, NAT-friendly).
##
## Everyone on Spacewar shares one lobby list, so our lobbies carry a "tag" and the browser
## filters on it. Join by code = the lobby ID.

signal status_changed
signal lobby_created(lobby_id: int)
signal lobby_entered(lobby_id: int, owner_id: int)
signal lobby_failed(reason: String)
signal lobby_list(lobbies: Array)

const APP_ID := 480
const TAG := "teaparty-v2"
## Steam enum values (stable across SDK versions).
const LOBBY_PRIVATE := 0
const LOBBY_FRIENDS := 1
const LOBBY_PUBLIC := 2
const COMPARE_EQUAL := 0
const DISTANCE_WORLDWIDE := 3
const RESULT_OK := 1
const ENTER_SUCCESS := 1

var steam: Object
var available := false
var reason := "Steam is not set up yet."
var steam_id := 0
var persona := ""
var lobby_id := 0
var _pending_join := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--no-steam" in OS.get_cmdline_user_args():
		reason = "Steam disabled (--no-steam)."
		return
	if not Engine.has_singleton("Steam"):
		reason = "GodotSteam isn't installed. In Godot open AssetLib, search \"GodotSteam\", install the GDExtension, restart the editor."
		return
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		reason = "addons/steam-multiplayer-peer is missing."
		return
	steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	var id: int = int(steam.call("getSteamID")) if steam.has_method("getSteamID") else 0
	if id == 0:
		var res: Variant = _init_steam()
		var ok: bool = typeof(res) == TYPE_BOOL and bool(res)
		if typeof(res) == TYPE_DICTIONARY:
			ok = int((res as Dictionary).get("status", 1)) == 0
			if not ok:
				reason = "Steam didn't start: %s. Is the Steam app running and are you logged in?" % (res as Dictionary).get("verbal", "unknown")
		id = int(steam.call("getSteamID"))
		if not ok and id == 0:
			if reason == "Steam is not set up yet.":
				reason = "Steam didn't start. Is the Steam app running and are you logged in?"
			status_changed.emit()
			return
	steam_id = id
	persona = String(steam.call("getPersonaName"))
	available = steam_id != 0
	reason = "" if available else "Steam started but you're not logged in."
	_connect(&"lobby_created", _on_lobby_created)
	_connect(&"lobby_joined", _on_lobby_joined)
	_connect(&"lobby_match_list", _on_lobby_match_list)
	_connect(&"join_requested", _on_join_requested)
	# Launched from a friend's invite ("+connect_lobby <id>").
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			_pending_join = int(args[i + 1])
	status_changed.emit()


func _init_steam() -> Variant:
	var n := -1
	if steam.has_method(&"get_method_argument_count"):
		n = int(steam.call(&"get_method_argument_count", &"steamInitEx"))
	if steam.has_method(&"steamInitEx"):
		match n:
			3:
				return steam.call(&"steamInitEx", false, APP_ID, false)
			2:
				return steam.call(&"steamInitEx", APP_ID, false)
			0:
				return steam.call(&"steamInitEx")
			_:
				return steam.call(&"steamInitEx", APP_ID, false)
	if steam.has_method(&"steamInit"):
		return steam.call(&"steamInit")
	return false


func _connect(sig: StringName, cb: Callable) -> void:
	if steam.has_signal(sig):
		steam.connect(sig, cb)


func _process(_delta: float) -> void:
	if available:
		steam.call(&"run_callbacks")
		if _pending_join != 0 and is_inside_tree():
			var id := _pending_join
			_pending_join = 0
			join_lobby(id)


func friendly_name() -> String:
	return persona if available else ""


# ---------------------------------------------------------------- lobbies

func create_lobby(public: bool, max_members: int) -> void:
	if not available:
		lobby_failed.emit(reason)
		return
	steam.call(&"createLobby", LOBBY_PUBLIC if public else LOBBY_FRIENDS, max_members)


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		lobby_failed.emit("Steam couldn't create a lobby (error %d)." % result)
		return
	lobby_id = id
	steam.call(&"setLobbyData", id, "tag", TAG)
	steam.call(&"setLobbyData", id, "name", "%s's tea party" % persona)
	steam.call(&"setLobbyData", id, "host", str(steam_id))
	steam.call(&"setLobbyJoinable", id, true)
	lobby_created.emit(id)


func join_lobby(id: int) -> void:
	if not available:
		lobby_failed.emit(reason)
		return
	Net.join_steam_pending()
	steam.call(&"joinLobby", id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		lobby_failed.emit("Couldn't join that tea party (it may be full or gone). Code %d." % response)
		return
	lobby_id = id
	var owner := int(steam.call(&"getLobbyOwner", id))
	if owner == steam_id:
		return   # our own lobby: we're the host already
	lobby_entered.emit(id, owner)


func _on_join_requested(id: int, _friend: int) -> void:
	# Accepted an invite (or "Join game") in the Steam overlay.
	if Net.in_lobby:
		Net.leave()
	join_lobby(id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		steam.call(&"leaveLobby", lobby_id)
	lobby_id = 0


func invite_friends() -> void:
	if available and lobby_id != 0:
		steam.call(&"activateGameOverlayInviteDialog", lobby_id)


func set_lobby_joinable(on: bool) -> void:
	if available and lobby_id != 0:
		steam.call(&"setLobbyJoinable", lobby_id, on)


## Public tea parties on Spacewar (ours only, thanks to the tag).
func refresh_lobbies() -> void:
	if not available:
		lobby_list.emit([])
		return
	steam.call(&"addRequestLobbyListDistanceFilter", DISTANCE_WORLDWIDE)
	steam.call(&"addRequestLobbyListStringFilter", "tag", TAG, COMPARE_EQUAL)
	steam.call(&"requestLobbyList")


func _on_lobby_match_list(lobbies: Array) -> void:
	var out: Array = []
	for id: Variant in lobbies:
		var lid := int(id)
		out.append({"id": lid, "name": String(steam.call(&"getLobbyData", lid, "name")),
			"members": int(steam.call(&"getNumLobbyMembers", lid)), "max": int(steam.call(&"getLobbyMemberLimit", lid))})
	lobby_list.emit(out)


## A new SteamMultiplayerPeer (host or client).
func make_peer() -> MultiplayerPeer:
	return ClassDB.instantiate(&"SteamMultiplayerPeer") as MultiplayerPeer
