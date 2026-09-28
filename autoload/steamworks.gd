extends Node
## Steam online play on Valve's servers, using the free "Spacewar" test app (App ID 480), with
## no Steam store page needed. Two pieces:
##   GodotSteam (GDExtension; install it from Godot's AssetLib) - Steam init, your name, lobbies,
##     invites and the friends overlay. Used through Engine.get_singleton("Steam") so the game
##     still runs (with LAN / solo only) when it's missing.
##   scripts/net/steam_peer.gd (SteamPeer) - carries the game's RPCs over GodotSteam's own P2P
##     functions (Valve's relay: no port forwarding, NAT-friendly). No second Steam addon, so there
##     is only one steam_api64.dll (GodotSteam's) and no DLL version clash.
##
## Everyone on Spacewar shares one lobby list, so our lobbies carry a "tag" and the browser
## filters on it. Join by code = the lobby ID.

signal status_changed
signal lobby_created(lobby_id: int)
signal lobby_entered(lobby_id: int, owner_id: int)
signal lobby_failed(reason: String)
signal lobby_list(lobbies: Array)
## A friend invited you (in-game popup): their name and the lobby.
signal invited(from_name: String, lobby_id: int)
signal friends_changed

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
## The last lines of the connection log (also in user://net_log.txt).
var log_lines: Array[String] = []
const FRIEND_FLAG_IMMEDIATE := 4
const PERSONA_OFFLINE := 0


## One line of the connection log: printed, kept for the UI, and written to user://net_log.txt so a
## failed join can be looked at afterwards (Windows: %APPDATA%\Godot\app_userdata\Tea Party).
func net_log(text: String) -> void:
	var line := "%s %s" % [Time.get_time_string_from_system(), text]
	print("[Net] ", line)
	log_lines.append(line)
	if log_lines.size() > 60:
		log_lines.remove_at(0)
	var f := FileAccess.open("user://net_log.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://net_log.txt") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--no-steam" in OS.get_cmdline_user_args():
		reason = "Steam disabled (--no-steam)."
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fake-steam="):
			# Testing only: tools/fake_steam.gd stands in for GodotSteam over local UDP.
			steam = (load("res://tools/fake_steam.gd") as GDScript).new(int(a.get_slice("=", 1)))
	if steam == null and not Engine.has_singleton("Steam"):
		if OS.has_feature("template"):
			var dir := OS.get_executable_path().get_base_dir()
			reason = "Steam files are missing next to the game. Copy steam_api64.dll and libgodotsteam.windows.template_release.x86_64.dll from the project's addons/godotsteam/win64 folder into %s" % dir
		else:
			reason = "GodotSteam isn't installed. In Godot open AssetLib, search \"GodotSteam\", install the GDExtension, restart the editor."
		print("[Steam] ", reason)
		return
	if steam == null:
		steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	_ensure_appid_file()
	# Fake Steam (tests) is always "running"; real GodotSteam must be initialised before any call.
	var id: int = int(steam.call("getSteamID")) if steam.has_method(&"is_fake") else 0
	if id == 0:
		var res: Variant = _init_steam()
		var ok: bool = typeof(res) == TYPE_BOOL and bool(res)
		if typeof(res) == TYPE_DICTIONARY:
			ok = int((res as Dictionary).get("status", 1)) == 0
			if not ok:
				reason = "Steam didn't start: %s. Is the Steam app running and are you logged in?" % (res as Dictionary).get("verbal", "unknown")
		if not ok:
			if reason == "Steam is not set up yet.":
				reason = "Steam didn't start. Is the Steam app running and are you logged in?"
			print("[Steam] ", reason)
			status_changed.emit()
			return
		id = int(steam.call("getSteamID"))
	steam_id = id
	persona = String(steam.call("getPersonaName"))
	# On a Discord call everyone knows each other by their Steam / Discord names, not "Guest 819".
	if persona != "" and (Profile.player_name == "Guest" or Profile.player_name.begins_with("Guest ")):
		Profile.player_name = persona.left(24)
		Profile.save_profile()
	# Start Valve's relay network now so the first connection doesn't have to wait for it.
	if steam.has_method(&"initRelayNetworkAccess"):
		steam.call(&"initRelayNetworkAccess")
	var f := FileAccess.open("user://net_log.txt", FileAccess.WRITE)
	if f:
		f.close()
	net_log("steam ok: %s (%d), app %s" % [persona, steam_id, str(steam.call(&"getAppID")) if steam.has_method(&"getAppID") else "?"])
	available = steam_id != 0
	reason = "" if available else "Steam started but you're not logged in."
	print("[Steam] ", "connected as %s (%d)" % [persona, steam_id] if available else reason)
	_connect(&"lobby_created", _on_lobby_created)
	_connect(&"lobby_joined", _on_lobby_joined)
	_connect(&"lobby_match_list", _on_lobby_match_list)
	_connect(&"join_requested", _on_join_requested)
	_connect(&"lobby_invite", _on_lobby_invite)
	_connect(&"persona_state_change", func(_id: int, _flags: int) -> void: friends_changed.emit())
	# Launched from a friend's invite ("+connect_lobby <id>").
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			_pending_join = int(args[i + 1])
	status_changed.emit()


## An exported game looks for steam_appid.txt next to the .exe (the editor finds the project's).
## Write it there if it's missing, so a fresh build works online without a manual copy.
func _ensure_appid_file() -> void:
	if not OS.has_feature("template"):
		return
	var path := OS.get_executable_path().get_base_dir().path_join("steam_appid.txt")
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(str(APP_ID))
		f.close()
		print("[Steam] wrote ", path)
	else:
		print("[Steam] couldn't write ", path, " (copy steam_appid.txt there by hand)")


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


## Mirrors a local achievement to Steam (needs the achievement set up on the game's Steam page;
## harmless otherwise).
func unlock_achievement(id: String) -> void:
	if not available or steam == null:
		return
	if steam.has_method("setAchievement"):
		steam.call("setAchievement", id)
	if steam.has_method("storeStats"):
		steam.call("storeStats")


func friendly_name() -> String:
	return persona if available else ""


# ---------------------------------------------------------------- lobbies

func create_lobby(public: bool, max_members: int) -> void:
	if not available:
		lobby_failed.emit(reason)
		return
	# Always a public lobby so anyone with the code can join; "listed" decides whether it shows
	# up in FIND PUBLIC PARTIES. (A friends-only lobby refuses a code from a non-friend.)
	_listed = public
	net_log("creating a lobby (listed: %s)" % public)
	steam.call(&"createLobby", LOBBY_PUBLIC, max_members)


var _listed := false


func _on_lobby_created(result: int, id: int) -> void:
	if result != RESULT_OK:
		net_log("lobby create failed: %d" % result)
		lobby_failed.emit("Steam couldn't create a lobby (error %d)." % result)
		return
	lobby_id = id
	net_log("lobby %d created" % id)
	steam.call(&"setLobbyData", id, "listed", "1" if _listed else "0")
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
	net_log("joining lobby %d" % id)
	steam.call(&"joinLobby", id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	net_log("lobby %d joined, response %d" % [id, response])
	if response != ENTER_SUCCESS:
		var why := {2: "that party doesn't exist any more", 3: "you're not allowed in", 4: "it's full", 5: "Steam had an error",
			6: "you're banned from it", 7: "you need a Steam account in good standing", 9: "the host blocked you"}.get(response, "error %d" % response) as String
		lobby_failed.emit("Couldn't join that tea party: %s." % why)
		return
	lobby_id = id
	var owner := int(steam.call(&"getLobbyOwner", id))
	net_log("the host is %d" % owner)
	if owner == steam_id:
		if not (Net.is_steam and Net.is_host()):
			lobby_failed.emit("That's your own party. Steam can't connect you to yourself: to test online, use a second PC (or a friend) with a DIFFERENT Steam account.")
		return   # our own lobby: we're the host already
	lobby_entered.emit(id, owner)


func _on_lobby_invite(inviter: int, lobby: int, _game: int) -> void:
	var nm := String(steam.call(&"getFriendPersonaName", inviter)) if steam.has_method(&"getFriendPersonaName") else "A friend"
	net_log("invite from %s to lobby %d" % [nm, lobby])
	invited.emit(nm, lobby)


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


func overlay_works() -> bool:
	return available and steam.has_method(&"isOverlayEnabled") and bool(steam.call(&"isOverlayEnabled"))


## Your Steam friends: [{id, name, online, in_game}], online ones first, Tea Party players first.
func friends() -> Array:
	var out: Array = []
	if not available or not steam.has_method(&"getFriendCount"):
		return out
	var n := int(steam.call(&"getFriendCount", FRIEND_FLAG_IMMEDIATE))
	for i in n:
		var fid := int(steam.call(&"getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE))
		if fid == 0:
			continue
		var state := int(steam.call(&"getFriendPersonaState", fid))
		var game: Dictionary = steam.call(&"getFriendGamePlayed", fid)
		var gid := int(game.get("id", game.get("game_id", game.get("app_id", 0))))
		out.append({"id": fid, "name": String(steam.call(&"getFriendPersonaName", fid)), "online": state != PERSONA_OFFLINE,
			"in_game": gid == APP_ID})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["in_game"] != b["in_game"]:
			return a["in_game"]
		if a["online"] != b["online"]:
			return a["online"]
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


## Send a friend a Steam invite to your lobby (shows up in their Steam chat, and as a popup if
## they're already in Tea Party).
func invite(friend_id: int) -> bool:
	if not available or lobby_id == 0:
		return false
	var ok := bool(steam.call(&"inviteUserToLobby", lobby_id, friend_id))
	net_log("invite %d -> %s" % [friend_id, ok])
	return ok


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
	steam.call(&"addRequestLobbyListStringFilter", "listed", "1", COMPARE_EQUAL)
	steam.call(&"requestLobbyList")


func _on_lobby_match_list(lobbies: Array) -> void:
	var out: Array = []
	for id: Variant in lobbies:
		var lid := int(id)
		out.append({"id": lid, "name": String(steam.call(&"getLobbyData", lid, "name")),
			"members": int(steam.call(&"getNumLobbyMembers", lid)), "max": int(steam.call(&"getLobbyMemberLimit", lid))})
	lobby_list.emit(out)


## A new Steam peer (host or client).
func make_peer() -> MultiplayerPeer:
	return SteamPeer.new(steam)
