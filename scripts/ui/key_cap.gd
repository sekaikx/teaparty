extends PanelContainer
class_name KeyCap
## A small keyboard key glyph. press() gives a tactile dip.

var style: HudStyle
var _label: Label


func setup(hud_style: HudStyle, key_text: String, icon: Texture2D = null) -> KeyCap:
	style = hud_style
	custom_minimum_size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", style.key_box(false))
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(12, 16)
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		add_child(tr)
	else:
		_label = Label.new()
		_label.text = key_text
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		style.label(_label, &"sans", 800, 13, style.key_text, 0)
		add_child(_label)
	return self


func press() -> void:
	add_theme_stylebox_override("panel", style.key_box(true))
	var t := get_tree().create_timer(0.12)
	t.timeout.connect(func() -> void: add_theme_stylebox_override("panel", style.key_box(false)))
