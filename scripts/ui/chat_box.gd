class_name ChatBox
extends PanelContainer
## Text chat for players without a mic (lobby and match). ENTER or T opens it, ENTER sends,
## ESC closes. Lines fade after a while unless the chat is open. Ghost lines are blue (only
## ghosts see them).

const SHOW_LINES := 6
const FADE_AFTER := 14.0

var _lines: VBoxContainer
var _input: LineEdit
var _hint: Label
var _open := false
var _items: Array[Dictionary] = []   # {node, t}


func _ready() -> void:
	add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.0), 16, 0, 0, Ui.INK, Vector4(10, 8, 10, 8)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(340, 0)
	var v := Ui.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_lines = Ui.vbox(3)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_lines)
	_input = Ui.line_edit("", "Say something...  (ENTER send, ESC close)", 320)
	_input.max_length = Net.CHAT_MAX
	_input.visible = false
	_input.text_submitted.connect(func(t: String) -> void:
		Net.send_chat(t)
		_input.text = ""
		close())
	v.add_child(_input)
	_hint = Ui.label("%s: chat" % Keys.label(&"chat"), 13, Ui.MUTED, 700)
	v.add_child(_hint)
	Net.chat_received.connect(_on_chat)


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_input.visible = true
	_hint.visible = false
	_input.grab_focus()
	add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.92), 16, 3, 3, Ui.INK, Vector4(10, 8, 10, 8)))
	for it in _items:
		(it["node"] as Control).modulate.a = 1.0


func close() -> void:
	_open = false
	_input.release_focus()
	_input.visible = false
	_hint.visible = true
	add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.0), 16, 0, 0, Ui.INK, Vector4(10, 8, 10, 8)))


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _open and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and event.is_action_pressed(&"chat") and not Ui.typing() and not (event as InputEventKey).alt_pressed:
		open()
		get_viewport().set_input_as_handled()


func _on_chat(msg: Dictionary) -> void:
	var me := int(msg.get("id", 0)) == Net.my_id()
	var ghost := bool(msg.get("ghost", false))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PLUM_DARK, 0.85), 12, 2, 2, Ui.INK, Vector4(8, 3, 8, 4)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Ui.wrap(Ui.label("%s%s: %s" % ["(ghost) " if ghost else "", String(msg.get("name", "?")), String(msg.get("text", ""))], 15,
		Color("a7c7ff") if ghost else (Ui.YELLOW if me else Ui.CREAM), 700), 310)
	box.add_child(l)
	_lines.add_child(box)
	_items.append({"node": box, "t": 0.0})
	while _items.size() > SHOW_LINES:
		(_items.pop_front()["node"] as Node).queue_free()
	Sfx.play(&"tick", -10.0)


func _process(delta: float) -> void:
	for it in _items:
		it["t"] = float(it["t"]) + delta
		var node := it["node"] as Control
		if _open:
			node.modulate.a = 1.0
		else:
			node.modulate.a = clampf(1.0 - (float(it["t"]) - FADE_AFTER) / 2.0, 0.0, 1.0)
