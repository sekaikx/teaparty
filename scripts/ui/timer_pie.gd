class_name TimerPie
extends Control
## A countdown pie with the seconds in the middle; it turns red and throbs near the end.

var fraction := 0.0
var seconds := 0


func _init() -> void:
	custom_minimum_size = Vector2(50, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if seconds <= 0:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var hurry := seconds <= 5
	var col := Ui.PINK if hurry else Ui.MINT
	if hurry:
		r *= 1.0 + 0.06 * sin(Time.get_ticks_msec() / 90.0)
	draw_circle(c + Vector2(0, 4), r + 3, Ui.INK)
	draw_circle(c, r + 3, Ui.INK)
	draw_circle(c, r, Ui.PLUM_DARK)
	if fraction > 0.02:
		var pts := PackedVector2Array([c])
		var n := 32
		for i in n + 1:
			var a := -PI / 2.0 + TAU * fraction * i / n
			pts.append(c + Vector2.from_angle(a) * r)
		_poly(pts, col)
	var f := Ui.display_font()
	var t := str(seconds)
	var fs := 22
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string_outline(f, c + Vector2(-w.x * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Ui.INK)
	draw_string(f, c + Vector2(-w.x * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.CREAM)


## draw_colored_polygon, skipping shapes that can't be triangulated (degenerate at tiny sizes).
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)
