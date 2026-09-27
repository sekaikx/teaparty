class_name Ui
extends RefCounted
## Tea Party's own look: a plum night, candy colours, chunky ink outlines with a hard drop
## shadow, and bouncy buttons. Lilita One for shouty headings, Fredoka for everything else.
## Every screen is built from these helpers; theme() makes plain Controls match.

const INK := Color("1d1128")
const PLUM := Color("3b2159")
const PLUM_DARK := Color("27143d")
const PLUM_LIGHT := Color("54307c")
const CREAM := Color("fff4e0")
const PINK := Color("ff5c8a")
const MINT := Color("3ddc97")
const YELLOW := Color("ffc93c")
const SKY := Color("4cc9f0")
const ORANGE := Color("ff8c42")
const LILAC := Color("c3a6ff")
const RED := Color("ff4d4d")
const MUTED := Color("b9a3d6")

static var _fonts: Dictionary = {}
static var _theme: Theme


static func display_font() -> Font:
	return _font("res://assets/fonts/LilitaOne.woff2")


static func body_font(weight: int = 600) -> Font:
	var w := 700 if weight >= 650 else (600 if weight >= 550 else 500)
	return _font("res://assets/fonts/Fredoka-%d.woff2" % w)


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f := load(path) as FontFile
		if f == null:
			f = ThemeDB.fallback_font as FontFile
		_fonts[path] = f
	return _fonts[path]


# ---------------------------------------------------------------- boxes

static func box(bg: Color, radius: int = 18, border: int = 4, shadow: int = 6, border_col: Color = INK, pad: Vector4 = Vector4(18, 12, 18, 12)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.shadow_color = Color(INK, 0.85) if shadow > 0 else Color(0, 0, 0, 0)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, shadow)
	if shadow > 0:
		sb.shadow_size = 1
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	sb.corner_detail = 10
	return sb


## True while the player is typing in a text box (chat, names): game hotkeys must stay quiet.
static func typing() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.gui_get_focus_owner() is LineEdit


static func panel(bg: Color = PLUM, radius: int = 26, pad: Vector4 = Vector4(26, 22, 26, 22)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, 5, 8, INK, pad))
	return p


## A light card for list rows (ink text on cream).
static func card(bg: Color = CREAM, pad: Vector4 = Vector4(14, 8, 14, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 16, 3, 4, INK, pad))
	return p


static func chip(text: String, bg: Color, fg: Color = INK, size: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 14, 3, 3, INK, Vector4(12, 3, 12, 5)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, fg, 700)
	p.add_child(l)
	return p


# ---------------------------------------------------------------- text

static func label(text: String, size: int = 18, color: Color = CREAM, weight: int = 600, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Shouty heading: Lilita One, thick ink outline and a hard shadow.
static func title(text: String, size: int = 44, color: Color = YELLOW) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 10))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


# ---------------------------------------------------------------- buttons

## A chunky candy button: coloured fill, ink border and a hard shadow that it presses into.
static func button(text: String, cb: Callable = Callable(), color: Color = MINT, font_size: int = 22, min_size: Vector2 = Vector2(0, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", font_size)
	var fg := INK if color.get_luminance() > 0.45 else CREAM
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	b.add_theme_constant_override("outline_size", 0)
	var pad := Vector4(22, 8, 22, 10)
	b.add_theme_stylebox_override("normal", box(color, 18, 4, 6, INK, pad))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 18, 4, 6, INK, pad))
	var pressed := box(color.darkened(0.08), 18, 4, 2, INK, Vector4(pad.x, pad.y + 4, pad.z, pad.w - 4))
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(color.lerp(PLUM_LIGHT, 0.6), 18, 4, 3, INK, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			Sfx.play(&"pop", -4.0, 0.12)
			cb.call())
	return b


## Hover wobble and press squash for any control.
static func juice(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and (c as BaseButton).disabled:
			return
		Sfx.play(&"tick", -16.0, 0.2)
		var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE * 1.06, 0.14)
		tw.parallel().tween_property(c, "rotation", deg_to_rad(randf_range(-2.0, 2.0)), 0.14))
	c.mouse_exited.connect(func() -> void:
		var tw := c.create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "scale", Vector2.ONE, 0.12)
		tw.parallel().tween_property(c, "rotation", 0.0, 0.12))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(func() -> void:
			c.create_tween().tween_property(c, "scale", Vector2(1.08, 0.9), 0.06))
		(c as BaseButton).button_up.connect(func() -> void:
			c.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).tween_property(c, "scale", Vector2.ONE, 0.35))


static func tab(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", 19)
	set_tab(b, false)
	return b


static func set_tab(b: Button, on: bool) -> void:
	b.set_pressed_no_signal(on)
	var bg := YELLOW if on else PLUM_LIGHT
	var fg := INK if on else CREAM
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, fg)
	var pad := Vector4(16, 4, 16, 6)
	for s in ["normal", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, box(bg, 14, 3, 3 if on else 2, INK, pad))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.1), 14, 3, 3, INK, pad))


# ---------------------------------------------------------------- inputs

static func line_edit(text: String, placeholder: String, width: float = 220.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(width, 44)
	return e


static func option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(String(items[i]), i)
	o.selected = selected
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(func(i: int) -> void:
		Sfx.play(&"pop", -6.0)
		cb.call(i))
	return o


static func slider(minv: float, maxv: float, step: float, value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(190, 28)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	return s


static func check(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(v: bool) -> void:
		Sfx.play(&"tick", -6.0)
		cb.call(v))
	return c


static func bar(fill: Color = MINT, height: float = 16.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.max_value = 1.0
	b.add_theme_stylebox_override("background", box(PLUM_DARK, 10, 3, 0, INK, Vector4.ZERO))
	b.add_theme_stylebox_override("fill", box(fill, 10, 3, 0, INK, Vector4.ZERO))
	return b


## A drawn coin + amount.
static func coin(parent: Control, amount: int, size: int = 20) -> Label:
	var h := hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	h.add_child(CoinIcon.new(size))
	var l := label(str(amount), size, YELLOW, 700, 6)
	h.add_child(l)
	return l


# ---------------------------------------------------------------- layout

static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
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


## Keep `c` at a point of its parent: `anchor` and `pivot` are fractions of the parent and of c,
## `offset` is in pixels; c is sized to its minimum size. Survives resizes.
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


static func backdrop(root: Control, alpha: float = 0.6) -> void:
	var dim := ColorRect.new()
	dim.color = Color(PLUM_DARK, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)


static func fade_in(c: CanvasItem, seconds: float = 0.2) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, seconds)


## Pop a control in with an elastic scale.
static func pop_in(c: Control, delay: float = 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.6
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- theme

## Project-wide defaults so plain Controls (LineEdit, OptionButton, popups, tooltips, sliders,
## scrollbars, check buttons) look like the rest.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font(600)
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	for cls in ["LineEdit"]:
		t.set_stylebox("normal", cls, box(CREAM, 14, 3, 3, INK, Vector4(12, 6, 12, 6)))
		t.set_stylebox("focus", cls, box(Color.WHITE, 14, 3, 3, PINK, Vector4(12, 6, 12, 6)))
		t.set_color("font_color", cls, INK)
		t.set_color("font_placeholder_color", cls, Color(INK, 0.4))
		t.set_color("caret_color", cls, PINK)
		t.set_color("selection_color", cls, Color(SKY, 0.5))
	for cls in ["OptionButton", "MenuButton"]:
		var pad := Vector4(14, 6, 30, 8)
		t.set_stylebox("normal", cls, box(CREAM, 14, 3, 3, INK, pad))
		t.set_stylebox("hover", cls, box(Color.WHITE, 14, 3, 3, INK, pad))
		t.set_stylebox("pressed", cls, box(YELLOW, 14, 3, 1, INK, pad))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(c, cls, INK)
		t.set_color("icon_normal_color", cls, INK)
	t.set_stylebox("panel", "PopupMenu", box(CREAM, 14, 3, 5, INK, Vector4(8, 8, 8, 8)))
	t.set_stylebox("hover", "PopupMenu", box(YELLOW, 10, 0, 0, INK, Vector4(8, 4, 8, 4)))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font("font", "PopupMenu", body_font(600))
	t.set_stylebox("panel", "TooltipPanel", box(CREAM, 12, 3, 4, INK, Vector4(12, 8, 12, 8)))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", body_font(600))
	t.set_font_size("font_size", "TooltipLabel", 16)
	t.set_stylebox("slider", "HSlider", box(PLUM_DARK, 8, 3, 0, INK, Vector4(0, 5, 0, 5)))
	t.set_stylebox("grabber_area", "HSlider", box(PINK, 8, 3, 0, INK, Vector4(0, 5, 0, 5)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(PINK.lightened(0.1), 8, 3, 0, INK, Vector4(0, 5, 0, 5)))
	var knob := _knob_texture()
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_stylebox("scroll", "VScrollBar", box(PLUM_DARK, 8, 0, 0, INK, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber", "VScrollBar", box(LILAC, 8, 2, 0, INK, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(YELLOW, 8, 2, 0, INK, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(PINK, 8, 2, 0, INK, Vector4(4, 4, 4, 4)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckButton", CREAM)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	_theme = t
	return t


static func _knob_texture() -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d <= 13.0:
				img.set_pixel(x, y, INK if d > 10.0 else YELLOW)
	return ImageTexture.create_from_image(img)
