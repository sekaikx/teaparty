class_name FakeSteam
extends Object
## A stand-in for the GodotSteam singleton for testing Steam online play without a Steam client:
## the P2P and lobby calls the game makes, carried over local UDP between game processes.
## Steam id N listens on UDP port 31000 + N % 1000. A lobby id is the host's Steam id.
##   godot --path . -- --qa --steam-host --fake-steam=1 &
##   godot --path . -- --qa --steam-join=1 --fake-steam=2

signal lobby_created(result: int, lobby_id: int)
signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
signal lobby_match_list(lobbies: Array)
signal join_requested(lobby_id: int, friend_id: int)
signal lobby_invite(inviter: int, lobby: int, game: int)
signal persona_state_change(steam_id: int, flags: int)
signal p2p_session_request(remote_id: int)
signal p2p_session_connect_fail(remote_id: int, error: int)

var id := 0
var _sock := PacketPeerUDP.new()
var _queue: Array[Dictionary] = []


func _init(p_id: int) -> void:
	id = p_id
	_sock.bind(port_of(id), "127.0.0.1")


static func port_of(steam_id: int) -> int:
	return 31000 + steam_id % 1000


func is_fake() -> bool:
	return true


func getSteamID() -> int:
	return id


func getPersonaName() -> String:
	return "SteamTester%d" % id


func run_callbacks() -> void:
	_pump()


func _pump() -> void:
	while _sock.get_available_packet_count() > 0:
		var raw := _sock.get_packet()
		if raw.size() < 8:
			continue
		var from := raw.decode_s64(0)
		_queue.append({"data": raw.slice(8), "remote_steam_id": from})


# ---------------------------------------------------------------- P2P

func allowP2PPacketRelay(_on: bool) -> bool:
	return true


func acceptP2PSessionWithUser(_other: int) -> bool:
	return true


func closeP2PSessionWithUser(_other: int) -> bool:
	return true


func sendP2PPacket(to: int, data: PackedByteArray, _kind: int, _channel: int) -> bool:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_s64(0, id)
	raw.append_array(data)
	# Local UDP datagrams top out around 64 KB; that's plenty for this game's messages.
	_sock.set_dest_address("127.0.0.1", port_of(to))
	return _sock.put_packet(raw) == OK


func getAvailableP2PPacketSize(_channel: int) -> int:
	_pump()
	return (_queue[0]["data"] as PackedByteArray).size() if not _queue.is_empty() else 0


func readP2PPacket(_size: int, _channel: int) -> Dictionary:
	return _queue.pop_front() if not _queue.is_empty() else {}


# ---------------------------------------------------------------- lobbies

func createLobby(_kind: int, _max: int) -> void:
	lobby_created.emit.call_deferred(1, id)


func setLobbyData(_lobby: int, _key: String, _value: String) -> bool:
	return true


func setLobbyJoinable(_lobby: int, _on: bool) -> bool:
	return true


func joinLobby(lobby: int) -> void:
	lobby_joined.emit.call_deferred(lobby, 0, false, 1)


func getLobbyOwner(lobby: int) -> int:
	return lobby


func leaveLobby(_lobby: int) -> void:
	pass


# ---------------------------------------------------------------- friends (for UI tests)

const FAKE_FRIENDS := [["Clara", 1, 480], ["Dev", 1, 0], ["Eli", 3, 0], ["Finn", 0, 0], ["Baron Jam IRL", 0, 0]]


func getFriendCount(_flags: int) -> int:
	return FAKE_FRIENDS.size()


func getFriendByIndex(i: int, _flags: int) -> int:
	return 900 + i


func getFriendPersonaName(fid: int) -> String:
	return String(FAKE_FRIENDS[fid - 900][0]) if fid >= 900 and fid - 900 < FAKE_FRIENDS.size() else "Host%d" % fid


func getFriendPersonaState(fid: int) -> int:
	return int(FAKE_FRIENDS[fid - 900][1])


func getFriendGamePlayed(fid: int) -> Dictionary:
	var g := int(FAKE_FRIENDS[fid - 900][2])
	return {"id": g} if g != 0 else {}


func inviteUserToLobby(_lobby: int, _friend: int) -> bool:
	return true


func isOverlayEnabled() -> bool:
	return false
