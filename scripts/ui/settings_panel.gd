class_name SettingsPanel
extends Control
## Volumes, microphone and window settings (saved in the profile).

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.75)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(620, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(12)
	p.add_child(v)
	v.add_child(Ui.title("SETTINGS", 46, Ui.LILAC))
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
	var devices := AudioServer.get_input_device_list()
	if devices.size() > 1:
		var dh := Ui.hbox(12)
		dh.add_child(Ui.label("Microphone", 18, Ui.CREAM, 700))
		var current := devices.find(AudioServer.input_device)
		dh.add_child(Ui.option(devices, maxi(current, 0), func(i: int) -> void: AudioServer.input_device = devices[i]))
		v.add_child(dh)
	v.add_child(Ui.check("Fullscreen", bool(Profile.settings.get("fullscreen", false)), func(on: bool) -> void:
		Profile.set_setting("fullscreen", on)))
	v.add_child(Ui.title("CONTROLS", 26, Ui.YELLOW))
	for line in [
		"Left click: teapot, cups, item cards, targets",
		"Drag cards from your secret tray onto a cup (hover it or hold TAB to see them)",
		"%s talk  -  %s emotes  -  %s throw cake  -  ENTER ready" % [Keys.label(&"push_to_talk"), Keys.label(&"emote_wheel"), Keys.label(&"throw_cake")],
		"Right-drag to look around, wheel to lean in",
	]:
		v.add_child(Ui.label(line, 16, Ui.CREAM, 600))
	v.add_child(Ui.button("DONE", func() -> void: closed.emit(), Ui.MINT))
