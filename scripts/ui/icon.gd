class_name TeaIcon
extends Control
## Hand-drawn icons for ingredients and items (no image files): vials, a sugar cube, a tea
## leaf, crossed arrows, a nose, two clinking cups, an eye. Also the face-down card back.

enum Kind { INGREDIENT, ITEM, BACK, SPIKE }

var kind := Kind.INGREDIENT
var value := 0
var ink := Color("3a2a1c")


static func make(p_kind: Kind, p_value: int, px: float = 48.0) -> TeaIcon:
	var t := TeaIcon.new()
	t.kind = p_kind
	t.value = p_value
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var c := o + Vector2(s, s) * 0.5
	var w := maxf(1.5, s * 0.045)
	match kind:
		Kind.BACK:
			_back(o, s, w)
		Kind.SPIKE:
			_vial(c, s, Color("3a1a3a"), w)
			_x(c + Vector2(0, s * 0.1), s * 0.1, Color("e8c0e8"), w)
		Kind.INGREDIENT:
			match value:
				Defs.Ingredient.POISON:
					_vial(c, s, Defs.INGREDIENTS[value]["color"], w)
					_skull(c + Vector2(0, s * 0.1), s * 0.12)
				Defs.Ingredient.ANTIDOTE:
					_vial(c, s, Defs.INGREDIENTS[value]["color"], w)
					var k := s * 0.09
					draw_rect(Rect2(c + Vector2(-k * 0.35, s * 0.1 - k), Vector2(k * 0.7, k * 2)), Color.WHITE)
					draw_rect(Rect2(c + Vector2(-k, s * 0.1 - k * 0.35), Vector2(k * 2, k * 0.7)), Color.WHITE)
				Defs.Ingredient.SUGAR:
					var r := s * 0.22
					var pts := PackedVector2Array([c + Vector2(-r, -r * 0.4), c + Vector2(0, -r), c + Vector2(r, -r * 0.4),
						c + Vector2(r, r * 0.6), c + Vector2(0, r), c + Vector2(-r, r * 0.6)])
					draw_colored_polygon(pts, Color("fbf8f0"))
					draw_polyline(pts + PackedVector2Array([pts[0]]), ink, w)
					draw_line(c + Vector2(-r, -r * 0.4), c + Vector2(0, r * 0.2), ink, w * 0.7)
					draw_line(c + Vector2(r, -r * 0.4), c + Vector2(0, r * 0.2), ink, w * 0.7)
					draw_line(c + Vector2(0, r * 0.2), c + Vector2(0, r), ink, w * 0.7)
				_:
					# A tea leaf.
					var leaf := PackedVector2Array()
					for i in 17:
						var t := float(i) / 16.0
						leaf.append(c + Vector2(lerpf(-s * 0.28, s * 0.28, t), -sin(t * PI) * s * 0.16).rotated(-0.6))
					for i in range(15, 0, -1):
						var t := float(i) / 16.0
						leaf.append(c + Vector2(lerpf(-s * 0.28, s * 0.28, t), sin(t * PI) * s * 0.16).rotated(-0.6))
					draw_colored_polygon(leaf, Color("8a9a5b"))
					draw_polyline(leaf + PackedVector2Array([leaf[0]]), ink, w)
					draw_line(c + Vector2(-s * 0.3, 0).rotated(-0.6), c + Vector2(s * 0.26, 0).rotated(-0.6), ink, w * 0.7)
		Kind.ITEM:
			match value:
				Defs.Item.SWAP:
					_arrow(c + Vector2(-s * 0.26, -s * 0.1), c + Vector2(s * 0.26, -s * 0.1), Color("97461f"), w * 1.4)
					_arrow(c + Vector2(s * 0.26, s * 0.12), c + Vector2(-s * 0.26, s * 0.12), Color("2e6a93"), w * 1.4)
				Defs.Item.SNIFF:
					var nose := PackedVector2Array([c + Vector2(-s * 0.05, -s * 0.28), c + Vector2(s * 0.12, s * 0.1),
						c + Vector2(s * 0.02, s * 0.16), c + Vector2(-s * 0.1, s * 0.12)])
					draw_polyline(nose, ink, w * 1.2)
					for i in 3:
						var y := -s * 0.18 + i * s * 0.13
						var pts := PackedVector2Array()
						for k in 9:
							pts.append(c + Vector2(s * 0.18 + k * s * 0.025, y + sin(k * 1.2) * s * 0.02))
						draw_polyline(pts, Color("5f8a2c"), w)
				Defs.Item.TOAST:
					_cup(c + Vector2(-s * 0.13, s * 0.05), s * 0.2, -0.35, w)
					_cup(c + Vector2(s * 0.13, s * 0.05), s * 0.2, 0.35, w)
					for i in 3:
						var a := -PI / 2 + (i - 1) * 0.5
						draw_line(c + Vector2(0, -s * 0.18) + Vector2.from_angle(a) * s * 0.06, c + Vector2(0, -s * 0.18) + Vector2.from_angle(a) * s * 0.14, Color("c9891f"), w)
				Defs.Item.PEEK:
					var eye := PackedVector2Array()
					for i in 17:
						var t := float(i) / 16.0
						eye.append(c + Vector2(lerpf(-s * 0.32, s * 0.32, t), -sin(t * PI) * s * 0.18))
					for i in range(15, 0, -1):
						var t := float(i) / 16.0
						eye.append(c + Vector2(lerpf(-s * 0.32, s * 0.32, t), sin(t * PI) * s * 0.18))
					draw_colored_polygon(eye, Color("fbf8f0"))
					draw_polyline(eye + PackedVector2Array([eye[0]]), ink, w)
					draw_circle(c, s * 0.11, Color("2e6a93"))
					draw_circle(c, s * 0.05, ink)


func _vial(c: Vector2, s: float, col: Color, w: float) -> void:
	var body := Rect2(c + Vector2(-s * 0.2, -s * 0.12), Vector2(s * 0.4, s * 0.42))
	draw_rect(body, col)
	draw_rect(body, ink, false, w)
	draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.3), Vector2(s * 0.16, s * 0.18)), col.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.3), Vector2(s * 0.16, s * 0.18)), ink, false, w)
	draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.38), Vector2(s * 0.2, s * 0.08)), Color("8a5a2b"))
	draw_line(body.position + Vector2(s * 0.06, s * 0.06), body.position + Vector2(s * 0.06, s * 0.3), Color(1, 1, 1, 0.5), w)


func _skull(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color.WHITE)
	draw_rect(Rect2(c + Vector2(-r * 0.6, r * 0.5), Vector2(r * 1.2, r * 0.7)), Color.WHITE)
	draw_circle(c + Vector2(-r * 0.4, -r * 0.05), r * 0.28, ink)
	draw_circle(c + Vector2(r * 0.4, -r * 0.05), r * 0.28, ink)


func _x(c: Vector2, r: float, col: Color, w: float) -> void:
	draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w * 1.3)
	draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, w * 1.3)


func _arrow(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var h := (b - a).length() * 0.25
	draw_colored_polygon(PackedVector2Array([b + d * h * 0.3, b - d * h + n * h * 0.6, b - d * h - n * h * 0.6]), col)


func _cup(c: Vector2, r: float, tilt: float, w: float) -> void:
	var pts := PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r, -r * 0.6), Vector2(r * 0.7, r * 0.6), Vector2(-r * 0.7, r * 0.6)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p.rotated(tilt))
	draw_colored_polygon(out, Color("fbf8f0"))
	draw_polyline(out + PackedVector2Array([out[0]]), ink, w)
	draw_line(out[0].lerp(out[1], 0.1), out[0].lerp(out[1], 0.9), Color("97461f"), w * 1.4)


func _back(o: Vector2, s: float, w: float) -> void:
	var r := Rect2(o + Vector2(s * 0.12, s * 0.06), Vector2(s * 0.76, s * 0.88))
	draw_rect(r, Color("6b2e22"))
	draw_rect(r.grow(-s * 0.05), Color("d9b77a"), false, w)
	var c := r.get_center()
	for i in 4:
		var a := i * PI / 2 + PI / 4
		draw_line(c, c + Vector2.from_angle(a) * s * 0.18, Color("d9b77a"), w)
	draw_circle(c, s * 0.06, Color("d9b77a"))
