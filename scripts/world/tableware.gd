class_name Tableware
extends RefCounted
## Procedural china: teacups (with saucer) and teapots. Sized for the KayKit guests
## (table top at ~0.78). Both are plain meshes; TeaCup / Teapot add behaviour.


## A cup on its saucer, origin at the saucer's base. `s` scales the whole thing.
static func build_cup(body: Color, rim: Color, s: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "China"
	root.scale = Vector3.ONE * s
	var china := Mats.porcelain(body)
	var trim := Mats.porcelain(rim)
	Mats.mesh(root, Mats.cylinder(0.2, 0.15, 0.025, 28), china, Vector3(0, 0.0125, 0))
	Mats.mesh(root, Mats.torus(0.17, 0.2, 28), trim, Vector3(0, 0.024, 0), Vector3.ZERO, Vector3(1, 0.25, 1))
	Mats.mesh(root, Mats.cylinder(0.125, 0.075, 0.15, 24), china, Vector3(0, 0.1, 0))
	Mats.mesh(root, Mats.torus(0.115, 0.135, 24), trim, Vector3(0, 0.172, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	Mats.mesh(root, Mats.cylinder(0.1, 0.09, 0.02, 20), trim, Vector3(0, 0.035, 0))
	Mats.mesh(root, Mats.torus(0.035, 0.06, 12), china, Vector3(0.14, 0.11, 0), Vector3(90, 0, 0))
	return root


## A round teapot, origin at its base; the spout points +X.
static func build_teapot(body: Color, trim: Color, s: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Pot"
	root.scale = Vector3.ONE * s
	var china := Mats.porcelain(body)
	var accent := Mats.porcelain(trim)
	Mats.mesh(root, Mats.sphere(0.2, 0.34, 24), china, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.1, 1, 1.1))
	Mats.mesh(root, Mats.torus(0.18, 0.225, 24), accent, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.1, 0.35, 1.1))
	Mats.mesh(root, Mats.cylinder(0.11, 0.13, 0.05, 20), accent, Vector3(0, 0.345, 0))
	Mats.mesh(root, Mats.sphere(0.045), accent, Vector3(0, 0.395, 0))
	Mats.mesh(root, Mats.cylinder(0.025, 0.05, 0.26, 12), china, Vector3(0.27, 0.23, 0), Vector3(0, 0, -55))
	Mats.mesh(root, Mats.torus(0.07, 0.1, 16), china, Vector3(-0.23, 0.2, 0), Vector3(90, 0, 0), Vector3(1, 1, 1.3))
	Mats.mesh(root, Mats.cylinder(0.14, 0.14, 0.02, 20), accent, Vector3(0, 0.01, 0))
	return root


static func spout_tip(s: float = 1.0) -> Vector3:
	return Vector3(0.37, 0.31, 0) * s
