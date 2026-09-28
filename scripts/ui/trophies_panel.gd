class_name TrophiesPanel
extends Control
## Every achievement, unlocked (with the date) or still to get.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.8)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(760, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(8)
	p.add_child(v)
	var got := 0
	for a: Dictionary in Achievements.LIST:
		if Profile.achievements.has(a["id"]):
			got += 1
	v.add_child(Ui.title("TROPHIES  %d / %d" % [got, Achievements.LIST.size()], 40, Ui.YELLOW))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	for a: Dictionary in Achievements.LIST:
		var on := Profile.achievements.has(a["id"])
		var card := Ui.card(Ui.YELLOW.lerp(Ui.CREAM, 0.5) if on else Color(Ui.CREAM, 0.35), Vector4(12, 6, 12, 8))
		card.custom_minimum_size = Vector2(350, 0)
		var cv := Ui.vbox(2)
		card.add_child(cv)
		cv.add_child(Ui.label(("* " if on else "") + String(a["name"]), 17, Ui.INK, 800))
		cv.add_child(Ui.wrap(Ui.label(String(a["desc"]), 14, Color(Ui.INK, 0.75), 700), 320))
		if on:
			cv.add_child(Ui.label("Unlocked %s" % String(Profile.achievements[a["id"]]), 12, Color(Ui.INK, 0.6), 700))
		grid.add_child(card)
	v.add_child(Ui.button("DONE", func() -> void: closed.emit(), Ui.MINT))


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
