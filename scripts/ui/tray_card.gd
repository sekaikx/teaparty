class_name TrayCard
extends PanelContainer
## A card in your hidden tray (an ingredient, or the butler's vial) or an item card. Tray cards
## show their back until you uncover the tray (hover or Tab) so a stream never sees your hand.
## Tray cards are dragged onto the table; item cards are clicked.

signal drag_started(card: TrayCard)
signal clicked(card: TrayCard)

const W := 104.0
const H := 138.0

var index := -1
var is_item := false
var is_spike := false
var value := 0
var revealed := true
var enabled := true:
	set(v):
		enabled = v
		modulate = Color(1, 1, 1, 1.0 if v else 0.5)

var _icon: TeaIcon
var _name: Label
var _band: PanelContainer
var _selected := false


func setup(p_index: int, p_value: int, item: bool, spike: bool = false) -> TrayCard:
	index = p_index
	value = p_value
	is_item = item
	is_spike = spike
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := Ui.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_band = PanelContainer.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_band)
	_name = Ui.label("", 15, Ui.INK, 700)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_band.add_child(_name)
	_icon = TeaIcon.make(TeaIcon.Kind.ITEM if item else (TeaIcon.Kind.SPIKE if spike else TeaIcon.Kind.INGREDIENT), p_value, 72)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_icon)
	tooltip_text = _desc()
	_style()
	mouse_entered.connect(func() -> void: _lift(true))
	mouse_exited.connect(func() -> void: _lift(false))
	resized.connect(func() -> void: pivot_offset = Vector2(size.x * 0.5, size.y))
	return self


func _desc() -> String:
	if is_spike:
		return "BUTLER'S VIAL\nDrop it in any other guest's cup: one extra poison, once a round."
	if is_item:
		return "%s\n%s" % [Defs.item_name(value).to_upper(), Defs.ITEMS[value]["desc"]]
	return "%s\n%s" % [Defs.ingredient_name(value).to_upper(), Defs.INGREDIENTS[value]["desc"]]


func _colour() -> Color:
	if is_spike:
		return Color("7a3fa0")
	if is_item:
		return [Ui.SKY, Ui.MINT, Ui.YELLOW, Ui.LILAC][value % 4]
	return {Defs.Ingredient.POISON: Color("7bd14a"), Defs.Ingredient.ANTIDOTE: Ui.SKY,
		Defs.Ingredient.SUGAR: Color("ffffff"), Defs.Ingredient.NOTHING: Color("e8c89a")}.get(value, Ui.CREAM)


func _style() -> void:
	var face := revealed or is_item
	var col := _colour() if face else Ui.PINK
	add_theme_stylebox_override("panel", Ui.box(Ui.CREAM if face else Ui.PINK, 16, 4, 6 if not _selected else 2, Ui.YELLOW if _selected else Ui.INK, Vector4(6, 6, 6, 8)))
	_band.add_theme_stylebox_override("panel", Ui.box(col if face else Ui.PINK.darkened(0.15), 10, 3, 0, Ui.INK, Vector4(4, 1, 4, 3)))
	if is_spike:
		_name.text = "VIAL" if face else "?"
	elif is_item:
		_name.text = Defs.item_name(value).replace("Force a ", "").to_upper()
	else:
		_name.text = Defs.ingredient_name(value).to_upper() if face else "?"
	_name.add_theme_color_override("font_color", Ui.CREAM if (face and col.get_luminance() < 0.45) else Ui.INK)


func set_revealed(on: bool) -> void:
	if on == revealed or is_item:
		return
	revealed = on
	_icon.kind = (TeaIcon.Kind.SPIKE if is_spike else TeaIcon.Kind.INGREDIENT) if on else TeaIcon.Kind.BACK
	_icon.queue_redraw()
	_style()


func set_selected(on: bool) -> void:
	_selected = on
	_style()
	position.y = -16.0 if on else 0.0


func _lift(on: bool) -> void:
	if not enabled:
		return
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * (1.1 if on else 1.0), 0.14)
	tw.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-4, 4)) if on else 0.0, 0.14)
	if on:
		Sfx.play(&"card", -12.0, 0.2)


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		accept_event()
		if is_item:
			Sfx.play(&"card", -3.0)
			clicked.emit(self)
		else:
			drag_started.emit(self)
