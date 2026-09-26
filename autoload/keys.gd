extends Node
## Input actions, registered in code so project.godot stays short.

const BINDINGS := {
	&"push_to_talk": [KEY_V],
	&"emote_wheel": [KEY_Q],
	&"peek_tray": [KEY_TAB],
	&"pause": [KEY_ESCAPE],
	&"ready_up": [KEY_ENTER, KEY_KP_ENTER],
}


func _enter_tree() -> void:
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Middle mouse also opens the emote wheel.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event(&"emote_wheel", mb)


static func label(action: StringName) -> String:
	var evs := InputMap.action_get_events(action)
	for e in evs:
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	return "?"
