class_name FriendsPanel
extends Control
## Invite Steam friends from inside the game (no Steam overlay needed): your friends list, the
## ones already in Tea Party first, each with an INVITE button. The invite arrives in their Steam
## chat, and as a JOIN popup if they have Tea Party open.

var _list: VBoxContainer
var _note: Label
var _sent: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.backdrop(self, 0.6)
	var p := Ui.panel(Ui.PLUM, 26, Vector4(24, 18, 24, 18))
	p.custom_minimum_size = Vector2(620, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(10)
	p.add_child(v)
	var head := Ui.hbox(10)
	v.add_child(head)
	var t := Ui.title("INVITE FRIENDS", 36, Ui.YELLOW)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Ui.button("CLOSE", func() -> void: queue_free(), Ui.PLUM_LIGHT, 18, Vector2(110, 46)))
	v.add_child(Ui.wrap(Ui.label("They get the invite in Steam chat. Tell them to open Tea Party first: then a JOIN button pops up in their game. Or send them the party code.", 15, Ui.MUTED), 580))
	var code := Ui.hbox(8)
	v.add_child(code)
	code.add_child(Ui.label("Party code:", 17, Ui.CREAM, 700))
	code.add_child(Ui.chip(Net.steam_code(), Ui.CREAM, Ui.INK, 17))
	code.add_child(Ui.button("COPY", func() -> void:
		DisplayServer.clipboard_set(Net.steam_code())
		_note.text = "Code copied. Paste it to your friends on Discord.", Ui.SKY, 16, Vector2(90, 40)))
	if Steamworks.overlay_works():
		code.add_child(Ui.button("STEAM OVERLAY", func() -> void: Steamworks.invite_friends(), Ui.LILAC, 16, Vector2(0, 40)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = Ui.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_note = Ui.wrap(Ui.label("", 15, Ui.YELLOW, 700), 580)
	v.add_child(_note)
	Steamworks.friends_changed.connect(_fill)
	_fill()
	Ui.pop_in(p)


func _fill() -> void:
	if not is_instance_valid(_list):
		return
	for c in _list.get_children():
		c.queue_free()
	var fr := Steamworks.friends()
	if fr.is_empty():
		_list.add_child(Ui.wrap(Ui.label("No Steam friends found. Is Steam open? Or use the party code.", 16, Ui.CREAM), 560))
		return
	for f: Dictionary in fr:
		var row := Ui.card(Ui.CREAM if f["online"] else Color("c9c0d8"), Vector4(12, 4, 12, 4))
		var h := Ui.hbox(8)
		row.add_child(h)
		var nm := Ui.label(String(f["name"]), 17, Ui.INK, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var state := "IN TEA PARTY" if f["in_game"] else ("online" if f["online"] else "offline")
		h.add_child(Ui.chip(state, Ui.MINT if f["in_game"] else (Ui.SKY if f["online"] else Ui.PLUM_LIGHT), Ui.INK, 13))
		var id := int(f["id"])
		var sent := _sent.has(id)
		var b := Ui.button("SENT!" if sent else "INVITE", func() -> void:
			if Steamworks.invite(id):
				_sent[id] = true
				_note.text = "Invite sent to %s." % f["name"]
				Sfx.play(&"pop", -4.0)
			else:
				_note.text = "Steam wouldn't send that invite. Send them the code instead."
			_fill(), Ui.MINT if not sent else Ui.PLUM_LIGHT, 16, Vector2(110, 40))
		b.disabled = sent
		h.add_child(b)
		_list.add_child(row)
