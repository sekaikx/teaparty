class_name Doodle
extends Control
## Little drawings for the tutorial: a teapot, a teacup, a ghost.

var what := "cup"


static func make(p_what: String, px: float) -> Doodle:
	var d := Doodle.new()
	d.what = p_what
	d.custom_minimum_size = Vector2(px, px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var ink := Ui.INK
	var w := s * 0.05
	match what:
		"pot":
			draw_circle(c + Vector2(0, s * 0.06), s * 0.3, ink)
			draw_circle(c + Vector2(0, s * 0.06), s * 0.26, Ui.SKY)
			draw_line(c + Vector2(s * 0.22, 0), c + Vector2(s * 0.42, -s * 0.16), ink, w * 2.2)
			draw_line(c + Vector2(s * 0.22, 0), c + Vector2(s * 0.42, -s * 0.16), Ui.SKY, w)
			draw_arc(c + Vector2(-s * 0.3, s * 0.06), s * 0.12, PI / 2, PI * 1.5, 12, ink, w * 1.4)
			draw_circle(c + Vector2(0, -s * 0.26), s * 0.06, ink)
		"cup":
			var pts := PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.15), c + Vector2(s * 0.3, -s * 0.15), c + Vector2(s * 0.2, s * 0.22), c + Vector2(-s * 0.2, s * 0.22)])
			_poly(pts, Ui.CREAM)
			draw_polyline(pts + PackedVector2Array([pts[0]]), ink, w)
			draw_line(pts[0].lerp(pts[1], 0.08), pts[0].lerp(pts[1], 0.92), Color("8a4a1f"), w * 1.6)
			draw_arc(c + Vector2(s * 0.3, s * 0.02), s * 0.1, -PI / 2, PI / 2, 10, ink, w)
			draw_line(c + Vector2(-s * 0.38, s * 0.26), c + Vector2(s * 0.38, s * 0.26), ink, w)
		"ghost":
			var body := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				body.append(c + Vector2(cos(a), sin(a)) * s * 0.28 + Vector2(0, -s * 0.02))
			for i in 7:
				body.append(c + Vector2(s * 0.28 - i * s * 0.093, s * 0.3 + (s * 0.05 if i % 2 == 0 else -s * 0.02)))
			_poly(body, Color("dbe8ff"))
			draw_polyline(body + PackedVector2Array([body[0]]), ink, w)
			draw_circle(c + Vector2(-s * 0.1, -s * 0.06), s * 0.06, ink)
			draw_circle(c + Vector2(s * 0.1, -s * 0.06), s * 0.06, ink)
			draw_circle(c + Vector2(0, s * 0.1), s * 0.05, ink)


## draw_colored_polygon, skipping shapes that can't be triangulated (degenerate at tiny sizes).
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)
