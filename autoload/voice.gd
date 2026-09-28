extends Node
## Push-to-talk voice chat over the game's own ENet connection (no extra service).
##
## Hold V: the microphone (AudioStreamMicrophone on the muted "Mic" bus, read through its
## AudioEffectCapture) is mixed to mono, resampled to 16 kHz and mu-law encoded (16 kB/s), then
## sent to the host on its own ENet channel. The host relays each packet to whoever may hear it:
## in the lobby everyone; in a match the living are heard by all, ghosts only by other ghosts
## (unless the lobby rule lets ghosts talk to the living). Playback is one AudioStreamGenerator
## per speaker, positioned at their seat when the table registers an anchor (attach()).

signal speaking_changed(peer_id: int, on: bool)

const RATE := 16000
const PACKET := 320            # samples per packet (20 ms)
const HOLD := 0.35             # seconds a speaker stays "speaking" after their last packet
## Channel 0 (kept for simplicity; SteamPeer carries the channel in its packet header).
const CHANNEL := 0

var transmitting := false
var mic_error := ""
## Live input level 0..1 (for the meters), and whether any sound has come in since the mic opened.
var level := 0.0
var heard_input := false
## Settings > Test microphone: keep the mic open and (optionally) play it back to yourself.
var testing := false
var hear_myself := false
## QA: transmit as if push-to-talk were held.
var force_talk := false
var _silent_for := 0.0
var _loop: AudioStreamGeneratorPlayback
var _loop_player: AudioStreamPlayer

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _phase := 0.0
var _acc := 0.0
var _acc_n := 0
var _out := PackedByteArray()
var _sinks: Dictionary = {}       # peer -> {player, playback}
var _anchors: Dictionary = {}     # peer -> Node3D
var _speaking: Dictionary = {}    # peer -> seconds left
var _decode := PackedFloat32Array()
var _encode := PackedByteArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tables()


func _process(delta: float) -> void:
	var enabled := bool(Profile.settings.get("mic", true))
	var mp := multiplayer.multiplayer_peer
	# Only once actually connected (while a join is still connecting there's nobody to send to).
	var online := mp != null and not (mp is OfflineMultiplayerPeer) \
		and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and (not Net.is_solo or force_talk)
	var want := enabled and online and (force_talk or (Input.is_action_pressed(&"push_to_talk") and not _typing()))
	# The microphone stays open for the whole session (opening it on every key press cut off the
	# start of each sentence); only what's said while the key is held is sent.
	_set_mic(testing or (enabled and online))
	if want != transmitting:
		transmitting = want
		if want and _capture:
			_capture.clear_buffer()
		if not want:
			_flush()
		_mark(_me(), want)
	_pump_mic(delta)
	for peer: int in _speaking.keys():
		if peer == _me() and transmitting:
			continue
		_speaking[peer] -= delta
		if _speaking[peer] <= 0.0:
			_speaking.erase(peer)
			speaking_changed.emit(peer, false)


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _me() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1


func is_speaking(peer: int) -> bool:
	return _speaking.has(peer)


func _mark(peer: int, on: bool) -> void:
	if on:
		var was := _speaking.has(peer)
		_speaking[peer] = HOLD
		if not was:
			speaking_changed.emit(peer, true)
	elif _speaking.has(peer):
		_speaking.erase(peer)
		speaking_changed.emit(peer, false)


# ---------------------------------------------------------------- microphone

func _set_mic(on: bool) -> void:
	if on and _mic == null:
		if not ProjectSettings.get_setting("audio/driver/enable_input", false):
			mic_error = "Microphone input is disabled in the project settings."
			return
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = &"Mic"
		add_child(_mic)
		_capture = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Mic"), 0) as AudioEffectCapture
	if _mic == null:
		return
	if on and not _mic.playing:
		if _capture:
			_capture.clear_buffer()
		heard_input = false
		_silent_for = 0.0
		_mic.play()
	elif not on and _mic.playing:
		_mic.stop()
		_flush()
		level = 0.0


## Is the microphone open but giving nothing but silence? (Unplugged, wrong device, or blocked
## by Windows' microphone privacy setting.)
func seems_silent() -> bool:
	return _mic != null and _mic.playing and _silent_for > 2.0 and not heard_input


func _pump_mic(delta: float) -> void:
	if _capture == null or _mic == null or not _mic.playing:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		_silent_for += delta
		return
	var frames := _capture.get_buffer(n)
	var peak := 0.0
	for f in frames:
		peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
	level = maxf(peak, level * 0.85)
	if peak > 0.004:
		heard_input = true
		_silent_for = 0.0
	else:
		_silent_for += delta
	if testing and hear_myself:
		_loopback(frames)
	if not transmitting:
		return
	var step := AudioServer.get_mix_rate() / RATE
	for f in frames:
		# Box-filter decimation: average the input frames that fall into each output sample.
		_acc += (f.x + f.y) * 0.5
		_acc_n += 1
		_phase += 1.0
		if _phase >= step:
			_phase -= step
			_out.append(_encode[clampi(int((_acc / _acc_n) * 32767.0) + 32768, 0, 65535) >> 4])
			_acc = 0.0
			_acc_n = 0
			if _out.size() >= PACKET:
				_flush()


func _flush() -> void:
	if _out.is_empty():
		return
	var pkt := _out
	_out = PackedByteArray()
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp is OfflineMultiplayerPeer or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if Net.is_host():
		_relay(_me(), pkt)
	else:
		_up.rpc_id(1, pkt)


@rpc("any_peer", "call_remote", "unreliable_ordered", CHANNEL)
func _up(pkt: PackedByteArray) -> void:
	if not Net.is_host() or pkt.size() > PACKET * 4:
		return
	_relay(multiplayer.get_remote_sender_id(), pkt)


## Host: send a speaker's packet to everyone allowed to hear them (and play it locally).
func _relay(from: int, pkt: PackedByteArray) -> void:
	if from != _me() and _can_hear(from, _me()):
		_play(from, pkt)
	for peer in multiplayer.get_peers():
		if peer != from and _can_hear(from, peer):
			_down.rpc_id(peer, from, pkt)


@rpc("authority", "call_remote", "unreliable_ordered", CHANNEL)
func _down(from: int, pkt: PackedByteArray) -> void:
	_play(from, pkt)


func _can_hear(speaker: int, listener: int) -> bool:
	if not Session.running:
		return true
	var ss: int = -1
	var ls: int = -1
	for i in Session.roster.size():
		var id := int(Session.roster[i]["id"])
		if id == speaker:
			ss = i
		if id == listener:
			ls = i
	if ss < 0 or ls < 0:
		return true
	var speaker_alive := bool(Session.seat_info(ss).get("alive", true))
	var listener_alive := bool(Session.seat_info(ls).get("alive", true))
	if speaker_alive:
		return true
	return not listener_alive or bool(Session.match_rules.get("ghosts_talk_to_living", false))


## Settings: hear your own microphone (a short delay, so you can tell it's working).
func _loopback(frames: PackedVector2Array) -> void:
	if _loop_player == null:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = AudioServer.get_mix_rate()
		gen.buffer_length = 0.3
		_loop_player = AudioStreamPlayer.new()
		_loop_player.stream = gen
		_loop_player.bus = &"Voice"
		add_child(_loop_player)
		_loop_player.play()
		_loop = _loop_player.get_stream_playback()
	var n := mini(frames.size(), _loop.get_frames_available())
	for i in n:
		_loop.push_frame(frames[i])


func stop_test() -> void:
	testing = false
	hear_myself = false
	if _loop_player:
		_loop_player.queue_free()
		_loop_player = null
		_loop = null


# ---------------------------------------------------------------- playback

## The table registers each guest's head so their voice comes from their seat.
func attach(peer: int, anchor: Node3D) -> void:
	_anchors[peer] = anchor
	if _sinks.has(peer):
		(_sinks[peer]["player"] as Node).queue_free()
		_sinks.erase(peer)


func detach_all() -> void:
	_anchors.clear()
	for peer: int in _sinks:
		(_sinks[peer]["player"] as Node).queue_free()
	_sinks.clear()


func _sink(peer: int) -> AudioStreamGeneratorPlayback:
	if _sinks.has(peer) and is_instance_valid(_sinks[peer]["player"]):
		return _sinks[peer]["playback"]
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.4
	var player: Node
	var anchor: Node3D = _anchors.get(peer)
	if anchor and is_instance_valid(anchor):
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = gen
		p3.bus = &"Voice"
		p3.unit_size = 6.0
		p3.max_db = 6.0
		anchor.add_child(p3)
		p3.play()
		player = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = gen
		p2.bus = &"Voice"
		add_child(p2)
		p2.play()
		player = p2
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback()
	_sinks[peer] = {"player": player, "playback": pb}
	return pb


## QA (tools/mic_test.gd): keep every decoded sample that arrives.
var qa_record := false
var qa_rx := PackedFloat32Array()


func _play(from: int, pkt: PackedByteArray) -> void:
	_mark(from, true)
	if qa_record:
		for b in pkt:
			qa_rx.append(_decode[b])
	var pb := _sink(from)
	if pb == null:
		return
	var n := mini(pkt.size(), pb.get_frames_available())
	for i in n:
		var v := _decode[pkt[i]]
		pb.push_frame(Vector2(v, v))


# ---------------------------------------------------------------- mu-law

func _build_tables() -> void:
	_decode.resize(256)
	for b in 256:
		var u := ~b & 0xFF
		var sign := u & 0x80
		var exponent := (u >> 4) & 0x07
		var mantissa := u & 0x0F
		var mag := ((mantissa << 3) + 0x84) << exponent
		mag -= 0x84
		_decode[b] = (-mag if sign else mag) / 32768.0
	# 12-bit index (16-bit sample >> 4, offset binary) -> mu-law byte.
	_encode.resize(4096)
	for i in 4096:
		var s := (i << 4) - 32768
		_encode[i] = _mulaw(s)


static func _mulaw(sample: int) -> int:
	var sign := 0
	if sample < 0:
		sign = 0x80
		sample = -sample
	sample = mini(sample, 32635) + 0x84
	var exponent := 7
	var mask := 0x4000
	while exponent > 0 and (sample & mask) == 0:
		exponent -= 1
		mask >>= 1
	var mantissa := (sample >> (exponent + 3)) & 0x0F
	return ~(sign | (exponent << 4) | mantissa) & 0xFF
