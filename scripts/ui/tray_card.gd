class_name TrayCard
extends PanelContainer
## A card in the hidden tray (ingredient / butler's vial) or an item card. Tray cards are drawn
## face down until the tray is uncovered (hover or Tab), so streams don't leak your hand.
## Tray cards are dragged onto the table; item cards are clicked.

signal drag_started(card: TrayCard)
signal clicked(card: TrayCard)

var index := -1
var is_item := false
var is_spike := false
var value := 0
var revealed := true
var enabled := true:
	set(v):
		enabled = v
		modulate = Color(1, 1, 1, 1.0 if v else 0.55)

var _icon: TeaIcon
var _name: Label
var _hover := false


func setup(p_index: int, p_value: int, item: bool, spike: bool = false) -> TrayCard:
	index = p_index
	value = p_value
	is_item = item
	is_spike = spike
	custom_minimum_size = Vector2(92, 118)
	add_theme_stylebox_override("panel", UiKit.hs.row_box())
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := UiKit.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_icon = TeaIcon.make(TeaIcon.Kind.ITEM if item else (TeaIcon.Kind.SPIKE if spike else TeaIcon.Kind.INGREDIENT), p_value, 58)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_icon)
	var n := "Butler's vial" if spike else (Defs.item_name(p_value) if item else Defs.ingredient_name(p_value))
	_name = UiKit.label(n, 13, Color(), &"serif", 650)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.wrap(_name, 80)
	v.add_child(_name)
	var desc := "Drop into any other guest's cup: one extra poison, once a round." if spike else \
		(String(Defs.ITEMS[p_value]["desc"]) if item else String(Defs.INGREDIENTS[p_value]["desc"]))
	tooltip_text = desc
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))
	return self


func set_revealed(on: bool) -> void:
	if on == revealed or is_item:
		return
	revealed = on
	_icon.kind = (TeaIcon.Kind.SPIKE if is_spike else TeaIcon.Kind.INGREDIENT) if on else TeaIcon.Kind.BACK
	_icon.queue_redraw()
	_name.text = ("Butler's vial" if is_spike else Defs.ingredient_name(value)) if on else "?"


func _set_hover(on: bool) -> void:
	_hover = on
	add_theme_stylebox_override("panel", UiKit.hs.row_box(on and enabled))
	var tw := create_tween()
	tw.tween_property(self, "position:y", -10.0 if on and enabled else 0.0, 0.12)


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
