class_name SteamPeer
extends MultiplayerPeerExtension
## Godot's high-level multiplayer (RPCs) over Steam P2P, using only GodotSteam's own networking
## functions (sendP2PPacket / readP2PPacket, relayed by Valve, so no port forwarding).
## This replaces the separate steam-multiplayer-peer addon. That addon shipped its own older
## steam_api64.dll, and Windows can only load one, so GodotSteam failed with "Error 127".
##
## Star topology: every client talks only to the host (peer 1); Godot's SceneMultiplayer relays
## client-to-client traffic through the host (server relay). Packets carry a small header:
##   [KIND_DATA, godot channel, transfer mode, payload...]  or  [KIND_CTRL, command]

const KIND_DATA := 0
const KIND_CTRL := 1
const CTRL_HELLO := 1     # client -> host: let me in
const CTRL_WELCOME := 2   # host -> client: you're in
const CTRL_BYE := 3       # either way: leaving
const CTRL_PING := 4
## Steam P2P send types (EP2PSend).
const SEND_UNRELIABLE := 0
const SEND_RELIABLE := 2
const UNRELIABLE_MAX := 1150
const STEAM_CHANNEL := 0
const TIMEOUT := 20.0
const PING_EVERY := 2.0

var steam: Object
var _server := false
var _uid := 0
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _host_steam := 0
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refuse := false
## Godot peer id <-> Steam id, and when we last heard from each peer.
var _by_uid: Dictionary = {}
var _by_steam: Dictionary = {}
var _heard: Dictionary = {}
var _inbox: Array[Dictionary] = []
var _current: Dictionary = {}
var _ping_t := 0.0


func _init(p_steam: Object = null) -> void:
	steam = p_steam if p_steam else (Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null)


## Everyone derives the same Godot id from a Steam id (2 .. 2^31-1; 1 is the host).
static func uid_for(steam_id: int) -> int:
	return 2 + absi(steam_id) % 2147483600


func create_host(_port: int = 0) -> Error:
	if steam == null:
		return ERR_UNAVAILABLE
	_server = true
	_uid = 1
	_status = MultiplayerPeer.CONNECTION_CONNECTED
	_setup()
	return OK


func create_client(host_steam_id: int, _port: int = 0) -> Error:
	if steam == null or host_steam_id == 0:
		return ERR_UNAVAILABLE
	_server = false
	_host_steam = host_steam_id
	_uid = uid_for(int(steam.call(&"getSteamID")))
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	_setup()
	_add(1, host_steam_id, false)
	_send_ctrl(host_steam_id, CTRL_HELLO)
	return OK


func _setup() -> void:
	if steam.has_method(&"allowP2PPacketRelay"):
		steam.call(&"allowP2PPacketRelay", true)
	if steam.has_signal(&"p2p_session_request") and not steam.is_connected(&"p2p_session_request", _on_session_request):
		steam.connect(&"p2p_session_request", _on_session_request)
	if steam.has_signal(&"p2p_session_connect_fail") and not steam.is_connected(&"p2p_session_connect_fail", _on_session_fail):
		steam.connect(&"p2p_session_connect_fail", _on_session_fail)


func _on_session_request(remote_id: int) -> void:
	if (_server and not _refuse) or remote_id == _host_steam:
		steam.call(&"acceptP2PSessionWithUser", remote_id)


func _on_session_fail(remote_id: int, _err: int = 0) -> void:
	if _by_steam.has(remote_id):
		_drop(int(_by_steam[remote_id]))


func _add(uid: int, steam_id: int, announce: bool = true) -> void:
	_by_uid[uid] = steam_id
	_by_steam[steam_id] = uid
	_heard[uid] = Time.get_ticks_msec() / 1000.0
	if announce:
		peer_connected.emit(uid)


func _drop(uid: int) -> void:
	if not _by_uid.has(uid):
		return
	var sid: int = _by_uid[uid]
	_by_uid.erase(uid)
	_by_steam.erase(sid)
	_heard.erase(uid)
	if steam and steam.has_method(&"closeP2PSessionWithUser"):
		steam.call(&"closeP2PSessionWithUser", sid)
	if not _server and uid == 1:
		_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	peer_disconnected.emit(uid)


# ---------------------------------------------------------------- sending

func _send_raw(steam_id: int, data: PackedByteArray, reliable: bool) -> bool:
	var kind := SEND_RELIABLE if reliable or data.size() > UNRELIABLE_MAX else SEND_UNRELIABLE
	return bool(steam.call(&"sendP2PPacket", steam_id, data, kind, STEAM_CHANNEL))


func _send_ctrl(steam_id: int, cmd: int) -> void:
	_send_raw(steam_id, PackedByteArray([KIND_CTRL, cmd]), cmd != CTRL_PING)


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var data := PackedByteArray([KIND_DATA, _channel, _mode])
	data.append_array(buffer)
	var reliable := _mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE
	if _target > 0:
		if not _by_uid.has(_target):
			return ERR_INVALID_PARAMETER
		_send_raw(int(_by_uid[_target]), data, reliable)
		return OK
	# 0 = everyone we're linked to (clients: just the host), negative = everyone but that peer.
	for uid: int in _by_uid:
		if _target < 0 and uid == -_target:
			continue
		_send_raw(int(_by_uid[uid]), data, reliable)
	return OK


# ---------------------------------------------------------------- receiving

func _poll() -> void:
	if steam == null or _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var guard := 0
	while guard < 512:
		guard += 1
		var size := int(steam.call(&"getAvailableP2PPacketSize", STEAM_CHANNEL))
		if size <= 0:
			break
		var pkt: Dictionary = steam.call(&"readP2PPacket", size, STEAM_CHANNEL)
		var data: PackedByteArray = pkt.get("data", PackedByteArray())
		var from := int(pkt.get("remote_steam_id", pkt.get("steam_id_remote", pkt.get("steam_id_from", 0))))
		if data.size() >= 2 and from != 0:
			_handle(from, data)
	var now := Time.get_ticks_msec() / 1000.0
	_ping_t -= get_process_delta()
	if _ping_t <= 0.0:
		_ping_t = PING_EVERY
		for uid: int in _by_uid.keys():
			if now - float(_heard.get(uid, now)) > TIMEOUT:
				_drop(uid)
			elif _status == MultiplayerPeer.CONNECTION_CONNECTED:
				_send_ctrl(int(_by_uid[uid]), CTRL_PING)
			elif not _server:
				_send_ctrl(_host_steam, CTRL_HELLO)   # still connecting: knock again


static func get_process_delta() -> float:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_process_delta_time() if ml else 0.016


func _handle(from: int, data: PackedByteArray) -> void:
	var uid := int(_by_steam.get(from, 0))
	if uid != 0:
		_heard[uid] = Time.get_ticks_msec() / 1000.0
	if data[0] == KIND_CTRL:
		match int(data[1]):
			CTRL_HELLO:
				if _server and not _refuse:
					if uid == 0:
						_add(uid_for(from), from)
					_send_ctrl(from, CTRL_WELCOME)
			CTRL_WELCOME:
				if not _server and from == _host_steam and _status == MultiplayerPeer.CONNECTION_CONNECTING:
					_status = MultiplayerPeer.CONNECTION_CONNECTED
					peer_connected.emit(1)
			CTRL_BYE:
				if uid != 0:
					_drop(uid)
		return
	if uid == 0 or data.size() < 3:
		return   # data from someone we never let in
	_inbox.append({"from": uid, "channel": int(data[1]), "mode": int(data[2]), "data": data.slice(3)})


func _get_available_packet_count() -> int:
	return _inbox.size()


func _get_packet_script() -> PackedByteArray:
	if _inbox.is_empty():
		return PackedByteArray()
	_current = _inbox.pop_front()
	return _current["data"]


func _get_packet_peer() -> int:
	return int(_inbox[0]["from"]) if not _inbox.is_empty() else int(_current.get("from", 0))


func _get_packet_channel() -> int:
	return int(_inbox[0]["channel"]) if not _inbox.is_empty() else int(_current.get("channel", 0))


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return (int(_inbox[0]["mode"]) if not _inbox.is_empty() else int(_current.get("mode", 2))) as MultiplayerPeer.TransferMode


# ---------------------------------------------------------------- the rest of the contract

func _get_max_packet_size() -> int:
	return 512 * 1024


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _is_server() -> bool:
	return _server


func _is_server_relay_supported() -> bool:
	return true


func _get_unique_id() -> int:
	return _uid


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _by_uid.has(peer):
		_send_ctrl(int(_by_uid[peer]), CTRL_BYE)
		_drop(peer)


func _close() -> void:
	if steam:
		for uid: int in _by_uid.keys():
			_send_ctrl(int(_by_uid[uid]), CTRL_BYE)
			if steam.has_method(&"closeP2PSessionWithUser"):
				steam.call(&"closeP2PSessionWithUser", int(_by_uid[uid]))
	_by_uid.clear()
	_by_steam.clear()
	_heard.clear()
	_inbox.clear()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
