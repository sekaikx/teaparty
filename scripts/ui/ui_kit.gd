class_name UiKit
extends RefCounted
## Small builders over Woods' HudStyle (parchment, walnut frames, wooden plaque buttons) so
## every screen is made the same way.

static var hs: HudStyle = preload("res://scenes/ui/hud_style.tres")


static func label(text: String, size: int = 16, color: Color = Color(), kind: StringName = &"sans", weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	hs.label(l, kind, weight, size, hs.text if color == Color() else color, 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int = 30, color: Color = Color()) -> Label:
	return label(text, size, color, &"serif", 650)


static func wrap(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, cb: Callable = Callable(), big: bool = false) -> Button:
	var b := hs.action_button(text)
	if big:
		hs.style_plank_button(b)
	b.focus_mode = Control.FOCUS_NONE if not big else Control.FOCUS_ALL
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			Sfx.play(&"click", -4.0)
			cb.call())
	return b


static func menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	hs.style_menu_button(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		Sfx.play(&"click", -4.0)
		cb.call())
	return b


static func panel(kind: StringName = &"panel") -> PanelContainer:
	var p := PanelContainer.new()
	match kind:
		&"paper":
			p.add_theme_stylebox_override("panel", hs.paper_box())
		&"note":
			p.add_theme_stylebox_override("panel", hs.note_box())
		&"chip":
			p.add_theme_stylebox_override("panel", hs.chip_box())
		&"row":
			p.add_theme_stylebox_override("panel", hs.row_box())
		_:
			p.add_theme_stylebox_override("panel", hs.panel_box())
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(w: float = 0.0, h: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func center(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c


static func option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(String(items[i]), i)
	o.selected = selected
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(func(i: int) -> void:
		Sfx.play(&"click", -6.0)
		cb.call(i))
	return o


static func slider(minv: float, maxv: float, step: float, value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(180, 20)
	s.focus_mode = Control.FOCUS_NONE
	hs.style_slider(s)
	s.value_changed.connect(cb)
	return s


static func check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_override("font", hs.font(&"sans", 700))
	c.add_theme_color_override("font_color", hs.text)
	c.add_theme_color_override("font_hover_color", hs.accent)
	c.add_theme_color_override("font_pressed_color", hs.text)
	c.add_theme_color_override("font_hover_pressed_color", hs.accent)
	c.toggled.connect(func(v: bool) -> void:
		Sfx.play(&"tick", -6.0)
		cb.call(v))
	return c


static func line_edit(text: String, placeholder: String, width: float = 220.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(width, 32)
	e.add_theme_font_override("font", hs.font(&"sans", 700))
	return e


## Keeps `c` at a point of its parent: `anchor` and `pivot` are fractions (0..1) of the parent
## and of `c`, `offset` is in pixels. c is sized to its minimum size. Survives resizes.
static func pin(c: Control, anchor: Vector2, pivot: Vector2, offset: Vector2 = Vector2.ZERO) -> Control:
	var fix := func() -> void:
		if not c.is_inside_tree():
			return
		var p := c.get_parent_control()
		var ps := p.size if p else c.get_viewport_rect().size
		var want := c.get_combined_minimum_size()
		if c.size != want:
			c.size = want
		c.position = (ps * anchor - c.size * pivot + offset).round()
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.minimum_size_changed.connect(fix)
	c.resized.connect(fix)
	var hook := func() -> void:
		var p := c.get_parent_control()
		if p and not p.resized.is_connected(fix):
			p.resized.connect(fix)
		elif p == null and not c.get_viewport().size_changed.is_connected(fix):
			c.get_viewport().size_changed.connect(fix)
		fix.call_deferred()
	c.tree_entered.connect(hook)
	if c.is_inside_tree():
		hook.call()
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func fade_in(c: CanvasItem, seconds: float = 0.25) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, seconds)
