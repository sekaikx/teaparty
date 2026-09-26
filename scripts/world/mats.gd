class_name Mats
extends RefCounted
## Shared materials for the procedural props (one per colour / finish, cached).

static var _cache: Dictionary = {}


static func solid(color: Color, roughness: float = 0.6, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [color.to_html(), roughness, metallic, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


static func porcelain(color: Color) -> StandardMaterial3D:
	var m := solid(color, 0.18, 0.0)
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	return m


static func gold() -> StandardMaterial3D:
	return solid(Color("d9a531"), 0.3, 0.9)


static func cloth(color: Color) -> StandardMaterial3D:
	var key := "cloth_" + color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.rim_enabled = true
	m.rim = 0.25
	_cache[key] = m
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := solid(color, 0.5, 0.0, energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Translucent, rim-lit ghost skin (material_override on a guest's meshes).
static func ghost() -> ShaderMaterial:
	if _cache.has("ghost"):
		return _cache["ghost"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 3.0 + VERTEX.y * 4.0);
	ALBEDO = tint.rgb * (0.12 + pow(rim, 2.0) * 0.9) * flicker;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_cache["ghost"] = m
	return m


## Soft pulsing outline shell for highlighted cups / guests.
static func highlight(color: Color) -> StandardMaterial3D:
	var key := "hl_" + color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = 0.025
	_cache[key] = m
	return m


static func mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func cylinder(top: float, bottom: float, height: float, segments: int = 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func sphere(radius: float, height: float = -1.0, segments: int = 20) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	s.radial_segments = segments
	s.rings = maxi(6, segments / 2)
	return s


static func torus(inner: float, outer: float, rings: int = 16) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = rings
	t.ring_segments = 8
	return t


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static var _softboxes: Dictionary = {}


## A pillowy rounded box (a superellipsoid): chunky, soft-cornered and readable, the building
## block of the guests. `size` is the full extent, `round` 0 = sharp box .. 1 = sphere,
## `taper` scales the top face relative to the bottom (x, z), `bulge` puffs the middle.
static func softbox(size: Vector3, round_amt: float = 0.45, taper: Vector2 = Vector2.ONE, bulge: float = 0.0) -> ArrayMesh:
	var key := "%s_%.2f_%s_%.2f" % [size, round_amt, taper, bulge]
	if _softboxes.has(key):
		return _softboxes[key]
	var e := clampf(round_amt, 0.08, 1.0)
	var lat := 14
	var lon := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[PackedVector3Array] = []
	for i in lat + 1:
		var row := PackedVector3Array()
		var v := PI * i / lat - PI / 2.0
		for j in lon + 1:
			var u := TAU * j / lon
			var cv := cos(v)
			var sv := sin(v)
			var x := _spow(cv, e) * _spow(cos(u), e)
			var y := _spow(sv, e)
			var z := _spow(cv, e) * _spow(sin(u), e)
			var t := (y + 1.0) * 0.5
			var tx := lerpf(1.0, taper.x, t)
			var tz := lerpf(1.0, taper.y, t)
			var b := 1.0 + bulge * (1.0 - y * y)
			row.append(Vector3(x * size.x * 0.5 * tx * b, y * size.y * 0.5, z * size.z * 0.5 * tz * b))
		pts.append(row)
	for i in lat:
		for j in lon:
			var a := pts[i][j]
			var b2 := pts[i + 1][j]
			var c := pts[i + 1][j + 1]
			var d := pts[i][j + 1]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b2)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)
	st.index()
	st.generate_normals()
	var m := st.commit()
	_softboxes[key] = m
	return m


static func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)
