class_name SettingsPanel
extends Control
## Volumes, microphone and window settings (saved in the profile).

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.hs.add_backdrop(self, 0.5)
	var p := UiKit.panel()
	add_child(UiKit.center(p))
	var v := UiKit.vbox(8)
	p.add_child(v)
	v.add_child(UiKit.title("Settings", 30))
	v.add_child(UiKit.hs.rule(2, 4))
	for pair in [["Master volume", "master"], ["Music", "music"], ["Sounds", "sfx"], ["Voices", "voice"]]:
		var h := UiKit.hbox(10)
		var l := UiKit.label(pair[0], 14, UiKit.hs.text_soft, &"sans", 800)
		l.custom_minimum_size.x = 140
		h.add_child(l)
		var key: String = pair[1]
		h.add_child(UiKit.slider(0.0, 1.0, 0.05, float(Profile.settings.get(key, 1.0)), func(val: float) -> void:
			Profile.set_setting(key, val)))
		v.add_child(h)
	v.add_child(UiKit.check("Microphone (push-to-talk on %s)" % Keys.label(&"push_to_talk"), bool(Profile.settings.get("mic", true)), func(on: bool) -> void:
		Profile.set_setting("mic", on)))
	var devices := AudioServer.get_input_device_list()
	if devices.size() > 1:
		var current := devices.find(AudioServer.input_device)
		v.add_child(UiKit.option(devices, maxi(current, 0), func(i: int) -> void:
			AudioServer.input_device = devices[i]))
	v.add_child(UiKit.check("Fullscreen", bool(Profile.settings.get("fullscreen", false)), func(on: bool) -> void:
		Profile.set_setting("fullscreen", on)))
	v.add_child(UiKit.hs.rule(4, 2))
	v.add_child(UiKit.label("Controls", 16, Color(), &"serif", 650))
	for line in [
		"Left mouse: pick up the teapot, pour, click item cards and targets",
		"Drag cards from your hidden tray onto a cup (hover the tray or hold Tab to look)",
		"Right-drag: look around the table   Wheel: zoom",
		"%s: push to talk   %s / middle mouse: emote wheel   Enter: ready to drink" % [Keys.label(&"push_to_talk"), Keys.label(&"emote_wheel")],
	]:
		v.add_child(UiKit.label(line, 13))
	v.add_child(UiKit.button("Done", func() -> void: closed.emit()))
