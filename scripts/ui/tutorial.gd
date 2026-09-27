class_name Tutorial
extends Control
## "How to play" in five illustrated cards. Shown once before your first match, and from the
## title screen / pause menu any time.

signal closed

const PAGES := [
	{"title": "1. A POISONER IS AT THE TABLE", "color": Color("ff5c8a"),
		"icons": [["ing", Defs.Ingredient.POISON], ["arrow"], ["ghost"]],
		"text": "One guest is secretly the POISONER (two with 8 guests). Only they know. Everyone else is an innocent guest. Guests win by voting the poisoner out. The poisoner wins by poisoning guests until it's 1 on 1."},
	{"title": "2. SERVE IN THE DARK", "color": Color("ffc93c"),
		"icons": [["pot"], ["arrow"], ["cup"]],
		"text": "Lights out! Click your teapot, click ANY other guest's cup, then drag one card from your tray into it. The poisoner has POISON. Guests have PLAIN, SUGAR and maybe the ANTIDOTE (it cancels poison). Nobody sees where anyone pours..."},
	{"title": "3. ...BUT YOU GLIMPSE ONE POUR", "color": Color("c3a6ff"),
		"icons": [["item", Defs.Item.PEEK], ["item", Defs.Item.SNIFF], ["item", Defs.Item.SWAP]],
		"text": "When the lights come back you learn ONE thing: \"You saw Baron pour into Ada's cup.\" Then items: SNIFF a cup for poison, WATCH a guest to see where they poured, SWAP two cups."},
	{"title": "4. THE TOAST", "color": Color("4cc9f0"),
		"icons": [["key", "F"], ["cup"], ["ing", Defs.Ingredient.ANTIDOTE]],
		"text": "Everyone raises their cup and drinks. Scared yours is poisoned? Press F to throw a cake at it and it spills. Whoever drank poison falls. The game never says who poured it."},
	{"title": "5. THE MEETING + THE VOTE", "color": Color("3ddc97"),
		"icons": [["key", "V"], ["arrow"], ["ghost"]],
		"text": "Now talk (Discord, or hold V). \"Where did YOU pour?\" \"I saw Clara pour into Ada's cup!\" \"No, I poured sugar into Baron's!\" Someone is lying. Then vote: most votes gets thrown out and their role is shown. Dead guests stay quiet, like Among Us."},
]

var _page := 0
var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.8)
	_show()


func _show() -> void:
	if _card:
		_card.queue_free()
	var pg: Dictionary = PAGES[_page]
	_card = Ui.panel(Ui.PLUM, 30, Vector4(34, 28, 34, 28))
	_card.custom_minimum_size = Vector2(720, 0)
	var v := Ui.vbox(18)
	_card.add_child(v)
	var t := Ui.title(pg["title"], 46, pg["color"])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var art := Ui.hbox(18)
	art.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(art)
	for ic: Array in pg["icons"]:
		art.add_child(_art(ic))
	var body := Ui.wrap(Ui.label(pg["text"], 21, Ui.CREAM, 600), 650)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var dots := Ui.hbox(8)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(dots)
	for i in PAGES.size():
		dots.add_child(Ui.chip(" ", Ui.YELLOW if i == _page else Ui.PLUM_LIGHT, Ui.INK, 8))
	var nav := Ui.hbox(12)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(nav)
	if _page > 0:
		nav.add_child(Ui.button("BACK", func() -> void:
			_page -= 1
			_show(), Ui.LILAC))
	nav.add_child(Ui.button("SKIP", _close, Ui.PLUM_LIGHT))
	var last := _page == PAGES.size() - 1
	nav.add_child(Ui.button("LET'S PARTY!" if last else "NEXT", func() -> void:
		if last:
			_close()
		else:
			_page += 1
			_show(), Ui.MINT if last else Ui.YELLOW, 24, Vector2(220, 60)))
	add_child(Ui.center(_card))
	Ui.pop_in(_card)
	Sfx.play(&"page", -4.0)


func _art(ic: Array) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.box(Ui.CREAM, 20, 4, 6, Ui.INK, Vector4(10, 10, 10, 10)))
	match String(ic[0]):
		"ing":
			box.add_child(TeaIcon.make(TeaIcon.Kind.INGREDIENT, ic[1], 92))
		"item":
			box.add_child(TeaIcon.make(TeaIcon.Kind.ITEM, ic[1], 92))
		"key":
			var l := Ui.title(String(ic[1]), 56, Ui.INK)
			l.custom_minimum_size = Vector2(92, 92)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.add_child(l)
		"arrow":
			box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var a := Ui.title(">", 70, Ui.YELLOW)
			box.add_child(a)
		_:
			box.add_child(Doodle.make(String(ic[0]), 92))
	return box


func _close() -> void:
	Sfx.play(&"pop", -3.0)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_close()
		get_viewport().set_input_as_handled()
