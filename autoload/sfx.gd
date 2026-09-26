extends Node
## Sounds, music and ambience. Creates the audio buses (Music, SFX, Voice and a muted Mic bus
## with a capture effect for voice chat) so no bus layout file is needed.
##   Sfx.play(&"clink")                 2D one-shot
##   Sfx.play_at(&"rattle", position)   3D one-shot
##   Sfx.music(&"waltz")                crossfades the music bed
##   Sfx.ambience(&"fire")              one looping room tone

const SOUNDS := {
	&"click": "res://audio/ui/click_wood.ogg", &"page": "res://audio/ui/page_turn.ogg",
	&"open": "res://audio/ui/paper_open.ogg", &"close": "res://audio/ui/paper_close.ogg",
	&"discover": "res://audio/ui/discover.ogg", &"secret": "res://audio/ui/secret.ogg",
	&"tick": "res://audio/ui/tick.ogg", &"coins": "res://audio/ui/coins_pay.ogg",
	&"voice_01": "res://audio/ui/voice_01.ogg", &"voice_02": "res://audio/ui/voice_02.ogg",
	&"voice_03": "res://audio/ui/voice_03.ogg", &"voice_04": "res://audio/ui/voice_04.ogg",
	&"voice_05": "res://audio/ui/voice_05.ogg",
	&"pour": "res://audio/sfx/pour.ogg", &"clink": "res://audio/sfx/clink.ogg",
	&"toast": "res://audio/sfx/toast.ogg", &"plip": "res://audio/sfx/plip.ogg",
	&"sugar": "res://audio/sfx/sugar.ogg", &"gulp": "res://audio/sfx/gulp.ogg",
	&"gasp": "res://audio/sfx/gasp.ogg", &"thud": "res://audio/sfx/thud.ogg",
	&"rattle": "res://audio/sfx/rattle.ogg", &"ghost": "res://audio/sfx/ghost.ogg",
	&"heartbeat": "res://audio/sfx/heartbeat.ogg", &"drumroll": "res://audio/sfx/drumroll.ogg",
	&"sniff": "res://audio/sfx/sniff.ogg", &"card": "res://audio/sfx/card.ogg",
	&"slide": "res://audio/sfx/slide.ogg", &"bell": "res://audio/sfx/bell.ogg",
	&"fanfare": "res://audio/sfx/fanfare.ogg", &"sting": "res://audio/sfx/sting.ogg",
	&"coin": "res://audio/sfx/coin.ogg", &"gift": "res://audio/sfx/gift.ogg",
	&"sit_down": "res://audio/sfx/sit_down.ogg", &"stand_up": "res://audio/sfx/stand_up.ogg",
	&"chest": "res://audio/sfx/chest_open.ogg", &"magic": "res://audio/sfx/rune_wake.ogg",
	&"flutter": "res://audio/sfx/wing_flutter.ogg",
	&"bird_1": "res://audio/ambience/bird_01.ogg", &"bird_2": "res://audio/ambience/bird_03.ogg",
	&"bird_3": "res://audio/ambience/bird_05.ogg", &"owl": "res://audio/ambience/owl_01.ogg",
}
const MUSIC := {
	&"waltz": "res://audio/music/waltz_loop.ogg",
	&"evening": "res://audio/music/evening_bed_loop.ogg",
	&"tavern": "res://audio/music/tavern_tune_loop.ogg",
}
const AMBIENCE := {
	&"fire": "res://audio/ambience/fire_crackle_loop.ogg",
	&"crickets": "res://audio/ambience/crickets_loop.ogg",
	&"murmur": "res://audio/ambience/murmur_loop.ogg",
}

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := &""
var _amb: AudioStreamPlayer
var _amb_id := &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _looper(&"Music")
	_music_b = _looper(&"Music")
	_amb = _looper(&"SFX")


func _looper(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func _make_buses() -> void:
	for n: StringName in [&"Music", &"SFX", &"Voice", &"Mic"]:
		if AudioServer.get_bus_index(n) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, &"Master")
	var mic := AudioServer.get_bus_index(&"Mic")
	if AudioServer.get_bus_effect_count(mic) == 0:
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 0.5
		AudioServer.add_bus_effect(mic, cap)
	# Muted after the capture effect, so you never hear your own microphone.
	AudioServer.set_bus_mute(mic, true)


func stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path: String = SOUNDS.get(id, MUSIC.get(id, AMBIENCE.get(id, "")))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if (MUSIC.has(id) or AMBIENCE.has(id)) and s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	_cache[id] = s
	return s


func play(id: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	var s := stream(id)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


## A positional one-shot in the current 3D scene (falls back to 2D without one).
func play_at(id: StringName, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.05) -> void:
	var s := stream(id)
	var scene := get_tree().current_scene
	if s == null:
		return
	var parent: Node = scene.get_node_or_null("World") if scene else null
	if parent == null or not (parent is Node3D):
		play(id, volume_db, pitch_jitter)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = 4.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func music(id: StringName, fade: float = 1.5) -> void:
	if id == _music_id:
		return
	_music_id = id
	var out := _music_a if _music_a.playing and _music_a.volume_db > -60.0 else _music_b
	var into := _music_b if out == _music_a else _music_a
	var tw := create_tween().set_parallel(true)
	tw.tween_property(out, "volume_db", -80.0, fade)
	var s := stream(id) if id != &"" else null
	if s:
		into.stream = s
		into.volume_db = -60.0
		into.play()
		tw.tween_property(into, "volume_db", -6.0, fade)


func ambience(id: StringName) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	var s := stream(id) if id != &"" else null
	if s == null:
		create_tween().tween_property(_amb, "volume_db", -80.0, 1.0)
		return
	_amb.stream = s
	_amb.volume_db = -40.0
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", -12.0, 1.5)
