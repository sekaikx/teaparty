extends Node
## The microphone end to end, with a real audio driver and a real network connection:
##   --mic-local   opens the mic (as Settings > TEST MIC does) and checks sound comes in
##   --mic-host    hosts on ENet, records every voice packet that arrives, checks it's the tone
##   --mic-join    joins 127.0.0.1 and transmits (as if push-to-talk were held) until stopped
## Run with a microphone that plays a steady tone (tools use a PulseAudio null sink + sox):
##   xvfb-run -a godot --path . -- --qa --tool=res://tools/mic_test.gd --mic-host &
##   xvfb-run -a godot --path . -- --qa --tool=res://tools/mic_test.gd --mic-join
const PORT := 24691


func _ready() -> void:
	Profile.ephemeral = true
	Profile.settings["mic"] = true
	var args := OS.get_cmdline_user_args()
	if "--mic-local" in args:
		_local()
	elif "--mic-host" in args:
		_host()
	elif "--mic-join" in args:
		_join()


func _local() -> void:
	Voice.testing = true
	await get_tree().create_timer(2.5).timeout
	var ok := Voice.heard_input and Voice.level > 0.05
	print("MICTEST local %s level=%.3f heard=%s error='%s' device=%s" % ["OK" if ok else "FAIL", Voice.level, Voice.heard_input, Voice.mic_error, AudioServer.input_device])
	get_tree().quit(0 if ok else 1)


func _host() -> void:
	Net.host_game(PORT)
	Voice.qa_record = true
	var t := 0.0
	while t < 25.0 and Voice.qa_rx.size() < 16000 * 2:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var rx := Voice.qa_rx
	var n := rx.size()
	var rms := 0.0
	var crossings := 0
	for i in n:
		rms += rx[i] * rx[i]
		if i > 0 and (rx[i - 1] < 0.0) != (rx[i] < 0.0):
			crossings += 1
	rms = sqrt(rms / maxf(n, 1))
	var freq := crossings / 2.0 / (n / 16000.0) if n > 0 else 0.0
	var ok := n >= 16000 * 2 and rms > 0.05 and absf(freq - 440.0) < 25.0
	# Stay up until the client is done (leaving would send it back to the menu mid-test).
	await get_tree().create_timer(4.0).timeout
	print("MICTEST host %s received=%.1fs rms=%.3f pitch=%.0fHz (sent a 440 Hz tone)" % ["OK" if ok else "FAIL", n / 16000.0, rms, freq])
	get_tree().quit(0 if ok else 1)


func _join() -> void:
	# The host checks what arrives; this side just transmits until the test script stops it.
	Net.join_game("127.0.0.1", PORT)
	Voice.force_talk = true
