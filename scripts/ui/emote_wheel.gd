class_name EmoteWheel
extends Control
## Hold Q (or middle mouse): a ring of emotes around the cursor; point at one and let go.

signal chosen(index: int)

const RADIUS := 178.0
const INNER := 48.0

var _center := Vector2.ZERO
var _pick := -1
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = Ui.display_font()


func open() -> void:
	# Local coordinates: the HUD can be scaled (Settings > HUD size).
	_center = get_local_mouse_position()
	var vs := size
	_center = _center.clamp(Vector2(RADIUS + 40, RADIUS + 40), vs - Vector2(RADIUS + 40, RADIUS + 40))
	_pick = -1
	visible = true
	Sfx.play(&"pop", -8.0)
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
	var d := get_local_mouse_position() - _center
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
	draw_circle(_center + Vector2(0, 6), RADIUS + 44, Ui.INK)
	draw_circle(_center, RADIUS + 44, Ui.INK)
	draw_circle(_center, RADIUS + 40, Color(Ui.PLUM, 0.95))
	draw_circle(_center, INNER, Ui.PLUM_DARK)
	var cols := [Ui.YELLOW, Ui.PINK, Ui.ORANGE, Ui.LILAC, Ui.MINT, Ui.SKY, Ui.YELLOW, Ui.PINK]
	for i in n:
		var a := -PI / 2.0 + TAU * i / n
		var pos := _center + Vector2.from_angle(a) * RADIUS
		var on := i == _pick
		var r := 44.0 if on else 37.0
		draw_circle(pos + Vector2(0, 4), r + 3, Ui.INK)
		draw_circle(pos, r + 3, Ui.INK)
		draw_circle(pos, r, cols[i % cols.size()] if on else Ui.CREAM)
		var text: String = Defs.EMOTES[i]["name"]
		var fs := 16 if on else 14
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, pos + Vector2(-w * 0.5, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.INK)
	var hint := "EMOTE"
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_string(_font, _center + Vector2(-hw * 0.5, 6), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.YELLOW)
