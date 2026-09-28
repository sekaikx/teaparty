class_name SettingsPanel
extends Control
## Volumes, microphone and window settings (saved in the profile).

signal closed

var _meter: ProgressBar
var _hear: Control
var _mic_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.75)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(620, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(7)
	p.add_child(v)
	v.add_child(Ui.title("SETTINGS", 40, Ui.LILAC))
	for pair in [["Everything", "master"], ["Music", "music"], ["Sounds", "sfx"], ["Voice chat", "voice"]]:
		var h := Ui.hbox(12)
		var l := Ui.label(pair[0], 18, Ui.CREAM, 700)
		l.custom_minimum_size.x = 160
		h.add_child(l)
		var key: String = pair[1]
		var s := Ui.slider(0.0, 1.0, 0.05, float(Profile.settings.get(key, 1.0)), func(val: float) -> void: Profile.set_setting(key, val))
		s.custom_minimum_size.x = 320
		h.add_child(s)
		v.add_child(h)
	v.add_child(Ui.check("Microphone (push to talk: %s)" % Keys.label(&"push_to_talk"), bool(Profile.settings.get("mic", true)), func(on: bool) -> void:
		Profile.set_setting("mic", on)))
	# Test your microphone: a live level bar, and optionally hear yourself.
	var mh := Ui.hbox(10)
	var devices := AudioServer.get_input_device_list()
	if devices.size() > 1:
		var current := devices.find(AudioServer.input_device)
		var opt := Ui.option(devices, maxi(current, 0), func(i: int) -> void:
			AudioServer.input_device = devices[i]
			Profile.set_setting("mic_device", devices[i]))
		opt.custom_minimum_size.x = 200
		mh.add_child(opt)
	mh.add_child(Ui.button("TEST MIC", func() -> void:
		Voice.testing = not Voice.testing
		_mic_state(), Ui.SKY, 16, Vector2(120, 38)))
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.max_value = 1.0
	_meter.custom_minimum_size = Vector2(150, 18)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(_meter)
	_hear = Ui.check("Hear myself", false, func(on: bool) -> void: Voice.hear_myself = on)
	mh.add_child(_hear)
	v.add_child(mh)
	_mic_note = Ui.wrap(Ui.label("", 14, Ui.MUTED, 700), 580)
	v.add_child(_mic_note)
	_mic_state()
	v.add_child(Ui.check("Fullscreen (F11 or Alt+Enter)", bool(Profile.settings.get("fullscreen", true)), func(on: bool) -> void:
		Profile.set_setting("fullscreen", on)))
	v.add_child(Ui.check("Low graphics (for laptops: smoother, less pretty)", String(Profile.settings.get("quality", "high")) == "low", func(on: bool) -> void:
		Profile.set_setting("quality", "low" if on else "high")))
	var sh := Ui.hbox(12)
	var sl := Ui.label("Camera speed", 18, Ui.CREAM, 700)
	sl.custom_minimum_size.x = 160
	sh.add_child(sl)
	var sens := Ui.slider(0.3, 2.0, 0.05, float(Profile.settings.get("look_sens", 1.0)), func(val: float) -> void: Profile.set_setting("look_sens", val))
	sens.custom_minimum_size.x = 320
	sh.add_child(sens)
	v.add_child(sh)
	v.add_child(Ui.check("Screen shake", bool(Profile.settings.get("shake", true)), func(on: bool) -> void:
		Profile.set_setting("shake", on)))
	v.add_child(Ui.check("Cap at 60 FPS (a cooler, quieter laptop)", int(Profile.settings.get("max_fps", 0)) == 60, func(on: bool) -> void:
		Profile.set_setting("max_fps", 60 if on else 0)))
	v.add_child(Ui.title("CONTROLS", 24, Ui.YELLOW))
	for line in [
		"Click: teapot, cups, items, targets  -  drag a card from your tray (TAB) onto a cup",
		"%s talk  -  %s emotes  -  %s throw cake  -  ENTER / T chat  -  %s ready to vote" % [Keys.label(&"push_to_talk"), Keys.label(&"emote_wheel"), Keys.label(&"throw_cake"), Keys.label(&"ready_up")],
		"Right-drag to look around, wheel to lean in  -  F11 / Alt+Enter: fullscreen",
	]:
		v.add_child(Ui.label(line, 15, Ui.CREAM, 600))
	v.add_child(Ui.button("DONE", func() -> void: closed.emit(), Ui.MINT))


func _mic_state() -> void:
	_meter.modulate.a = 1.0 if Voice.testing else 0.35
	_hear.visible = Voice.testing
	if Voice.mic_error != "":
		_mic_note.text = Voice.mic_error
	elif Voice.testing:
		_mic_note.text = "Say something: the bar should move. Nothing? Check the device above, and Windows Settings > Privacy > Microphone > let desktop apps use your microphone."
	else:
		_mic_note.text = "In a match, hold %s to talk (the mic stays ready, so nothing gets cut off)." % Keys.label(&"push_to_talk")


func _process(_delta: float) -> void:
	if _meter:
		_meter.value = sqrt(Voice.level) if Voice.testing else 0.0
		if Voice.testing and Voice.seems_silent():
			_mic_note.text = "No sound from this microphone. Pick another device above, check it isn't muted, and in Windows Settings > Privacy > Microphone allow desktop apps."


func _exit_tree() -> void:
	Voice.stop_test()
