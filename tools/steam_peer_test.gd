extends Node
## SteamPeer against a fake GodotSteam (in-process packet bus): a host and two clients, each with
## its own SceneMultiplayer. Checks joining, RPCs both ways, client-to-client relay through the host,
## lost unreliable packets and leaving.
##   godot --headless --path . -- --qa --tool=res://tools/steam_peer_test.gd

class BusSteam:
	extends Object
	signal p2p_session_request(remote_id: int)
	static var bus: Dictionary = {}
	var id := 0
	var drop_unreliable := 0.1
	func _init(p_id: int) -> void:
		id = p_id
		bus[id] = []
	func getSteamID() -> int:
		return id
	func allowP2PPacketRelay(_on: bool) -> bool:
		return true
	func acceptP2PSessionWithUser(_other: int) -> bool:
		return true
	func closeP2PSessionWithUser(_other: int) -> bool:
		return true
	func sendP2PPacket(to: int, data: PackedByteArray, kind: int, _channel: int) -> bool:
		if not bus.has(to):
			return false
		if kind == 0 and randf() < drop_unreliable:
			return true   # lost on the wire
		(bus[to] as Array).append({"data": data.duplicate(), "remote_steam_id": id})
		return true
	func getAvailableP2PPacketSize(_channel: int) -> int:
		var q: Array = bus[id]
		return (q[0]["data"] as PackedByteArray).size() if not q.is_empty() else 0
	func readP2PPacket(_size: int, _channel: int) -> Dictionary:
		return (bus[id] as Array).pop_front()


## Like the real log from two Windows PCs: Networking Messages "succeeds" (returns OK) but
## never delivers anything (the session times out, 5003); the P2P api works.
class HalfSteam:
	extends BusSteam
	signal network_messages_session_request(remote_id: int)
	func sendMessageToUser(_to: int, _data: PackedByteArray, _flags: int, _channel: int) -> int:
		return 1
	func receiveMessagesOnChannel(_channel: int, _max_messages: int) -> Array:
		return []
	func acceptSessionWithUser(_other: int) -> bool:
		return true


## The same bus, but speaking only Valve's Networking Messages API, with the sender reported as an
## identity string ("steamid:...") like some GodotSteam versions do.
class MsgSteam:
	extends Object
	signal network_messages_session_request(remote_id: int)
	static var bus: Dictionary = {}
	var id := 0
	var drop_unreliable := 0.1
	func _init(p_id: int) -> void:
		id = p_id
		bus[id] = []
	func getSteamID() -> int:
		return id
	func acceptSessionWithUser(_other: int) -> bool:
		return true
	func sendMessageToUser(to: int, data: PackedByteArray, flags: int, _channel: int) -> int:
		if not bus.has(to):
			return 3
		if (flags & 8) == 0 and randf() < drop_unreliable:
			return 1
		(bus[to] as Array).append({"payload": data.duplicate(), "identity": "steamid:%d" % id, "size": data.size()})
		return 1
	func receiveMessagesOnChannel(_channel: int, max_messages: int) -> Array:
		var q: Array = bus[id]
		var out := q.slice(0, max_messages)
		bus[id] = q.slice(max_messages)
		return out
	func getAvailableP2PPacketSize(_channel: int) -> int:
		return 0
	func readP2PPacket(_size: int, _channel: int) -> Dictionary:
		return {}
	func sendP2PPacket(_to: int, _data: PackedByteArray, _kind: int, _channel: int) -> bool:
		return false


class Box:
	extends Node
	var got: Array = []
	var api: SceneMultiplayer
	@rpc("any_peer", "call_remote", "reliable")
	func msg(text: String) -> void:
		got.append([multiplayer.get_remote_sender_id(), text])
	@rpc("any_peer", "call_remote", "unreliable")
	func blip(n: int) -> void:
		got.append([multiplayer.get_remote_sender_id(), "blip%d" % n])


var fails := 0


func _check(what: String, ok: bool) -> void:
	print("STEAMPEER %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _make(n: String) -> Box:
	var b := Box.new()
	b.name = "Box"
	var holder := Node.new()
	holder.name = n
	get_tree().root.add_child(holder)
	holder.add_child(b)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, holder.get_path())
	b.api = api
	return b


func _ready() -> void:
	await get_tree().process_frame
	print("STEAMPEER --- p2p api")
	await _run(BusSteam.new(76561198000000001), BusSteam.new(76561198000000002), BusSteam.new(76561198000000003), "p2p")
	print("STEAMPEER --- messages api silently broken, p2p works (the real-world case)")
	await _run(HalfSteam.new(76561198000000021), HalfSteam.new(76561198000000022), HalfSteam.new(76561198000000023), "half")
	print("STEAMPEER --- networking messages api")
	await _run(MsgSteam.new(76561198000000011), MsgSteam.new(76561198000000012), MsgSteam.new(76561198000000013), "msg")
	print("STEAMPEER DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run(hs: Object, c1s: Object, c2s: Object, tag: String) -> void:
	var host := _make("H" + tag)
	var c1 := _make("C1" + tag)
	var c2 := _make("C2" + tag)
	var hp := SteamPeer.new(hs)
	var hid: int = hs.get("id")
	_check("host created", hp.create_host() == OK)
	host.api.multiplayer_peer = hp
	var p1 := SteamPeer.new(c1s)
	var p2 := SteamPeer.new(c2s)
	_check("client 1 created", p1.create_client(hid) == OK)
	_check("client 2 created", p2.create_client(hid) == OK)
	c1.api.multiplayer_peer = p1
	c2.api.multiplayer_peer = p2
	var connected := [0]
	c1.api.connected_to_server.connect(func() -> void: connected[0] += 1)
	c2.api.connected_to_server.connect(func() -> void: connected[0] += 1)
	await _frames(30)
	_check("both clients connected", connected[0] == 2)
	_check("host sees 2 peers", host.api.get_peers().size() == 2)
	_check("client 1 knows client 2 (relay)", c1.api.get_peers().has(SteamPeer.uid_for(int(c2s.get("id")))))
	c1.msg.rpc_id(1, "hi host")
	host.msg.rpc("hello all")
	c1.msg.rpc_id(SteamPeer.uid_for(int(c2s.get("id"))), "psst c2")
	c2.msg.rpc("to everyone from c2")
	for i in 50:
		c1.blip.rpc_id(1, i)
	await _frames(30)
	_check("host got client 1's rpc", host.got.has([SteamPeer.uid_for(int(c1s.get("id"))), "hi host"]))
	_check("clients got the host broadcast", c1.got.has([1, "hello all"]) and c2.got.has([1, "hello all"]))
	_check("client 2 got client 1's rpc through the host", c2.got.has([SteamPeer.uid_for(int(c1s.get("id"))), "psst c2"]))
	_check("client 2 broadcast reached host and client 1", host.got.has([SteamPeer.uid_for(int(c2s.get("id"))), "to everyone from c2"]) and c1.got.has([SteamPeer.uid_for(int(c2s.get("id"))), "to everyone from c2"]))
	var blips := 0
	for g: Array in host.got:
		if String(g[1]).begins_with("blip"):
			blips += 1
	_check("unreliable packets mostly arrive (%d/50), none crash" % blips, blips > 30 and blips <= 50)
	var big := "x".repeat(40000)
	c2.msg.rpc_id(1, big)
	await _frames(10)
	_check("a 40 KB reliable rpc arrives", host.got.has([SteamPeer.uid_for(int(c2s.get("id"))), big]))
	var gone := [false]
	host.api.peer_disconnected.connect(func(id: int) -> void: gone[0] = id == SteamPeer.uid_for(int(c2s.get("id"))))
	c2.api.multiplayer_peer.close()
	await _frames(10)
	_check("host notices client 2 leaving", gone[0] and host.api.get_peers().size() == 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
