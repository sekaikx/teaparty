class_name CoinIcon
extends Control
## A drawn gold coin with an ink outline.

var px := 20


func _init(p_px: int = 20) -> void:
	px = p_px
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, r * 0.15), r, Ui.INK)
	draw_circle(c, r, Ui.INK)
	draw_circle(c, r * 0.8, Ui.YELLOW)
	draw_circle(c, r * 0.5, Ui.YELLOW.darkened(0.15))
	draw_arc(c, r * 0.62, -2.4, -0.9, 8, Color(1, 1, 1, 0.7), maxf(1.5, r * 0.12))
