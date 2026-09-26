class_name EmoteWheel
extends Control
## Hold Q (or middle mouse): a ring of emotes around the cursor; point at one and let go.

signal chosen(index: int)

const RADIUS := 150.0
const INNER := 48.0

var _center := Vector2.ZERO
var _pick := -1
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = UiKit.hs.font(&"serif", 650, 36)


func open() -> void:
	_center = get_viewport().get_mouse_position()
	var vs := get_viewport_rect().size
	_center = _center.clamp(Vector2(RADIUS + 40, RADIUS + 40), vs - Vector2(RADIUS + 40, RADIUS + 40))
	_pick = -1
	visible = true
	Sfx.play(&"open", -8.0)
	queue_redraw()


func close(fire: bool) -> void:
	if not visible:
		return
	visible = false
	if fire and _pick >= 0:
		chosen.emit(_pick)


func _process(_delta: float) -> void:
	if not visible:
		return
	var d := get_viewport().get_mouse_position() - _center
	var n := Defs.EMOTES.size()
	var p := -1
	if d.length() > INNER:
		p = int(round(fposmod(d.angle() + PI / 2.0, TAU) / (TAU / n))) % n
	if p != _pick:
		_pick = p
		if p >= 0:
			Sfx.play(&"tick", -10.0)
		queue_redraw()


func _draw() -> void:
	var n := Defs.EMOTES.size()
	draw_circle(_center, RADIUS + 34, Color(0.09, 0.055, 0.03, 0.55))
	draw_arc(_center, RADIUS + 34, 0, TAU, 64, Color("e3bf73"), 2.0)
	draw_circle(_center, INNER, Color(0.09, 0.055, 0.03, 0.7))
	for i in n:
		var a := -PI / 2.0 + TAU * i / n
		var pos := _center + Vector2.from_angle(a) * RADIUS
		var on := i == _pick
		draw_circle(pos, 40 if on else 34, Color("f5e6c4") if on else Color("e8d6ae"))
		draw_arc(pos, 40 if on else 34, 0, TAU, 32, Color("97461f") if on else Color("6b5540"), 2.5 if on else 1.5)
		var text: String = Defs.EMOTES[i]["name"]
		var fs := 15
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, pos + Vector2(-w * 0.5, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("3a2a1c"))
	var hint := "Emotes"
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(_font, _center + Vector2(-hw * 0.5, 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f5e6c4"))
