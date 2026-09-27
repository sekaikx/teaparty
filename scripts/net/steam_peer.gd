class_name SteamPeer
extends MultiplayerPeerExtension
## Godot's high-level multiplayer (RPCs) over Steam, using only GodotSteam's own networking.
## Two transports, both relayed by Valve (no port forwarding):
##   Networking Messages (sendMessageToUser / receiveMessagesOnChannel): Valve's current API, used
##     first when this GodotSteam has it.
##   the older P2P API (sendP2PPacket / readP2PPacket): the fallback, and always listened to.
## Every step is logged (Steamworks.net_log -> user://net_log.txt) so a failed join can be read.
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
## Networking Messages send flags.
const MSG_UNRELIABLE := 0
const MSG_RELIABLE := 8
const MSG_AUTO_RESTART := 32
const RESULT_OK := 1
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
## Networking Messages available (and not failing)?
var _msgs := false
## Which transport actually WORKS with each Steam id: "msg" once something arrived over Networking
## Messages from them, otherwise the older P2P API. (A Messages send can report OK and still time
## out later, 5003, as seen in real logs; P2P got through in the same session.)
var _via: Dictionary = {}
var _hello_tries := 0


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


static func log_line(text: String) -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var sw: Node = ml.root.get_node_or_null("Steamworks") if ml else null
	if sw and sw.has_method(&"net_log"):
		sw.call(&"net_log", text)
	else:
		print("[SteamPeer] ", text)


func _setup() -> void:
	_msgs = steam.has_method(&"sendMessageToUser") and steam.has_method(&"receiveMessagesOnChannel")
	log_line("%s: transport %s, my id %s" % ["host" if _server else "client", "messages+p2p" if _msgs else "p2p", str(steam.call(&"getSteamID"))])
	if steam.has_method(&"allowP2PPacketRelay"):
		steam.call(&"allowP2PPacketRelay", true)
	if steam.has_signal(&"network_messages_session_request") and not steam.is_connected(&"network_messages_session_request", _on_msg_request):
		steam.connect(&"network_messages_session_request", _on_msg_request)
	if steam.has_signal(&"network_messages_session_failed") and not steam.is_connected(&"network_messages_session_failed", _on_msg_failed):
		steam.connect(&"network_messages_session_failed", _on_msg_failed)
	if steam.has_signal(&"p2p_session_request") and not steam.is_connected(&"p2p_session_request", _on_session_request):
		steam.connect(&"p2p_session_request", _on_session_request)
	if steam.has_signal(&"p2p_session_connect_fail") and not steam.is_connected(&"p2p_session_connect_fail", _on_session_fail):
		steam.connect(&"p2p_session_connect_fail", _on_session_fail)


func _on_session_request(remote_id: int) -> void:
	log_line("p2p session request from %d" % remote_id)
	if (_server and not _refuse) or remote_id == _host_steam:
		steam.call(&"acceptP2PSessionWithUser", remote_id)


func _on_msg_request(remote_id: int) -> void:
	log_line("messages session request from %d" % remote_id)
	if (_server and not _refuse) or remote_id == _host_steam:
		steam.call(&"acceptSessionWithUser", remote_id)


func _on_msg_failed(reason: int, remote_id: int, _state: int = 0, debug: String = "") -> void:
	# Normal when Networking Messages can't reach someone: the P2P api carries the game instead.
	if _via.get(remote_id, "") == "msg":
		log_line("messages session with %d failed (%d): %s" % [remote_id, reason, debug])


func _on_session_fail(remote_id: int, err: int = 0) -> void:
	log_line("p2p session with %d failed (error %d)" % [remote_id, err])
	if _by_steam.has(remote_id) and _status == MultiplayerPeer.CONNECTION_CONNECTED:
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

## Data goes over ONE transport per peer (so nothing arrives twice): Messages only once that peer
## has been heard over Messages, else P2P.
func _send_raw(steam_id: int, data: PackedByteArray, reliable: bool) -> bool:
	var rel := reliable or data.size() > UNRELIABLE_MAX
	if _msgs and _via.get(steam_id, "") == "msg":
		var res := int(steam.call(&"sendMessageToUser", steam_id, data, (MSG_RELIABLE if rel else MSG_UNRELIABLE) | MSG_AUTO_RESTART, STEAM_CHANNEL))
		if res == RESULT_OK:
			return true
		log_line("sendMessageToUser -> %d (result %d), using the p2p api" % [steam_id, res])
	return _send_p2p(steam_id, data, rel)


func _send_p2p(steam_id: int, data: PackedByteArray, rel: bool) -> bool:
	return bool(steam.call(&"sendP2PPacket", steam_id, data, SEND_RELIABLE if rel else SEND_UNRELIABLE, STEAM_CHANNEL))


## Handshakes and pings go over BOTH transports: they're harmless if they arrive twice, and they
## let each side discover which transport really works.
func _send_ctrl(steam_id: int, cmd: int) -> void:
	var data := PackedByteArray([KIND_CTRL, cmd])
	var rel := cmd != CTRL_PING
	_send_p2p(steam_id, data, rel)
	if _msgs:
		steam.call(&"sendMessageToUser", steam_id, data, (MSG_RELIABLE if rel else MSG_UNRELIABLE) | MSG_AUTO_RESTART, STEAM_CHANNEL)


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
	if _msgs:
		for round_ in 16:
			var msgs: Array = steam.call(&"receiveMessagesOnChannel", STEAM_CHANNEL, 64)
			for m: Variant in msgs:
				if typeof(m) != TYPE_DICTIONARY:
					continue
				var md: Dictionary = m
				var data: PackedByteArray = md.get("payload", md.get("data", PackedByteArray()))
				var from := _sender_of(md)
				if data.size() >= 2 and from != 0:
					_handle(from, data, "msg")
			if msgs.size() < 64:
				break
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
			_handle(from, data, "p2p")
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
				_hello_tries += 1
				log_line("still calling the host %d (try %d)" % [_host_steam, _hello_tries])
				_send_ctrl(_host_steam, CTRL_HELLO)   # still connecting: knock again


## The sender of a Networking Messages message, whatever this GodotSteam version calls it.
static func _sender_of(m: Dictionary) -> int:
	for key in ["remote_steam_id", "steam_id", "sender", "identity_peer"]:
		if m.has(key) and (typeof(m[key]) == TYPE_INT):
			return int(m[key])
	var ident := str(m.get("identity", m.get("identity_peer", "")))
	# "steamid:7656119..." (or a bare number)
	var digits := ident.get_slice(":", 1) if ident.contains(":") else ident
	return int(digits) if digits.is_valid_int() else 0


static func get_process_delta() -> float:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_process_delta_time() if ml else 0.016


## The transport a peer's handshake first arrived on is the one we use for their data from then on.
func _learn(from: int, via: String) -> void:
	if not _via.has(from):
		_via[from] = via
		log_line("talking to %d over %s" % [from, "Networking Messages" if via == "msg" else "the P2P api"])


func _handle(from: int, data: PackedByteArray, via: String = "p2p") -> void:
	var uid := int(_by_steam.get(from, 0))
	if uid != 0:
		_heard[uid] = Time.get_ticks_msec() / 1000.0
	if data[0] == KIND_CTRL:
		match int(data[1]):
			CTRL_HELLO:
				if _server and not _refuse:
					_learn(from, via)
					if uid == 0:
						log_line("hello from %d: welcome" % from)
						_add(uid_for(from), from)
					_send_ctrl(from, CTRL_WELCOME)
			CTRL_WELCOME:
				if not _server and from == _host_steam and _status == MultiplayerPeer.CONNECTION_CONNECTING:
					_learn(from, via)
					log_line("the host let us in")
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
