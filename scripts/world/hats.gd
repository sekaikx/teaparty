class_name Hats
extends RefCounted
## Procedural hats, modelled for a head about 1.1 wide; Guest scales them to its bean head and
## sets the position, so every hat sits on the crown the same way.


static func build(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Hat"
	match id:
		&"top_hat":
			var felt := Mats.solid(Color("1d1a1f"), 0.7)
			Mats.mesh(root, Mats.cylinder(0.62, 0.62, 0.04, 28), felt, Vector3(0, 0.02, 0))
			Mats.mesh(root, Mats.cylinder(0.36, 0.33, 0.62, 24), felt, Vector3(0, 0.33, 0))
			Mats.mesh(root, Mats.cylinder(0.345, 0.345, 0.09, 24), Mats.solid(Color("8e2a3a"), 0.5), Vector3(0, 0.1, 0))
		&"bowler":
			var felt := Mats.solid(Color("3b2a1e"), 0.65)
			Mats.mesh(root, Mats.cylinder(0.5, 0.52, 0.035, 28), felt, Vector3(0, 0.02, 0))
			Mats.mesh(root, Mats.sphere(0.38, 0.5), felt, Vector3(0, 0.1, 0))
			Mats.mesh(root, Mats.cylinder(0.385, 0.385, 0.07, 24), Mats.solid(Color("1a1410"), 0.5), Vector3(0, 0.07, 0))
		&"party":
			var cone := Mats.cylinder(0.0, 0.3, 0.7, 20)
			Mats.mesh(root, cone, Mats.solid(Color("e05a8a"), 0.5), Vector3(0.1, 0.3, 0), Vector3(0, 0, -12))
			Mats.mesh(root, Mats.sphere(0.08), Mats.solid(Color("f7d154"), 0.4), Vector3(0.17, 0.67, 0))
			for i in 3:
				Mats.mesh(root, Mats.torus(0.2 - i * 0.06, 0.24 - i * 0.06), Mats.solid(Color("f7d154"), 0.5), Vector3(0.1 + 0.03 * i, 0.12 + i * 0.16, 0), Vector3(0, 0, -12))
		&"bonnet":
			var straw := Mats.solid(Color("e8cf8e"), 0.9)
			Mats.mesh(root, Mats.cylinder(0.66, 0.7, 0.04, 28), straw, Vector3(0, -0.02, 0.06), Vector3(-18, 0, 0))
			Mats.mesh(root, Mats.sphere(0.46, 0.42), straw, Vector3(0, 0.08, -0.05))
			Mats.mesh(root, Mats.torus(0.44, 0.5), Mats.solid(Color("7fb0d8"), 0.5), Vector3(0, 0.05, -0.04))
			Mats.mesh(root, Mats.sphere(0.1), Mats.solid(Color("f28aa0"), 0.5), Vector3(0.4, 0.14, 0.12))
			Mats.mesh(root, Mats.sphere(0.08), Mats.solid(Color("fff2a8"), 0.5), Vector3(0.46, 0.08, 0.02))
		&"fez":
			Mats.mesh(root, Mats.cylinder(0.26, 0.32, 0.36, 20), Mats.solid(Color("b3242d"), 0.6), Vector3(0, 0.16, 0))
			Mats.mesh(root, Mats.cylinder(0.012, 0.012, 0.3, 6), Mats.solid(Color("1a1a1a")), Vector3(0.18, 0.28, 0), Vector3(0, 0, 50))
			Mats.mesh(root, Mats.sphere(0.05), Mats.solid(Color("1a1a1a")), Vector3(0.3, 0.2, 0))
		&"flower_crown":
			Mats.mesh(root, Mats.torus(0.42, 0.5, 24), Mats.solid(Color("5c8a3a"), 0.8), Vector3(0, 0.0, 0))
			var colors := [Color("f28aa0"), Color("fff2a8"), Color("b89bf0"), Color("ffffff"), Color("f6a55c")]
			for i in 10:
				var a := TAU * i / 10.0
				Mats.mesh(root, Mats.sphere(0.09), Mats.solid(colors[i % colors.size()], 0.6), Vector3(cos(a) * 0.46, 0.04, sin(a) * 0.46))
		&"witch":
			var felt := Mats.solid(Color("2d2140"), 0.7)
			Mats.mesh(root, Mats.cylinder(0.75, 0.75, 0.03, 28), felt, Vector3(0, 0.02, 0))
			Mats.mesh(root, Mats.cylinder(0.12, 0.36, 0.5, 20), felt, Vector3(0, 0.27, 0))
			Mats.mesh(root, Mats.cylinder(0.0, 0.12, 0.35, 16), felt, Vector3(0.08, 0.66, 0), Vector3(0, 0, -25))
			Mats.mesh(root, Mats.cylinder(0.37, 0.37, 0.07, 24), Mats.solid(Color("7fbf4d"), 0.5), Vector3(0, 0.07, 0))
		&"teacup":
			var cup := Tableware.build_cup(Color("f4f1ea"), Color("c0506a"), 1.9)
			cup.position = Vector3(0, 0.02, 0)
			cup.rotation_degrees = Vector3(0, 0, -8)
			root.add_child(cup)
		&"crown":
			var g := Mats.gold()
			Mats.mesh(root, Mats.cylinder(0.36, 0.34, 0.2, 24), g, Vector3(0, 0.1, 0))
			for i in 8:
				var a := TAU * i / 8.0
				Mats.mesh(root, Mats.cylinder(0.0, 0.07, 0.2, 6), g, Vector3(cos(a) * 0.33, 0.29, sin(a) * 0.33))
				Mats.mesh(root, Mats.sphere(0.04), Mats.solid([Color("c0303a"), Color("2e6ad0")][i % 2], 0.2, 0.2), Vector3(cos(a) * 0.36, 0.12, sin(a) * 0.36))
			Mats.mesh(root, Mats.cylinder(0.3, 0.3, 0.16, 20), Mats.cloth(Color("7a1d2c")), Vector3(0, 0.18, 0))
		&"beret":
			var felt := Mats.solid(Color("c0303a"), 0.85)
			Mats.mesh(root, Mats.sphere(0.5, 0.26, 24), felt, Vector3(0.08, 0.1, 0), Vector3(0, 0, -12), Vector3(1, 1, 0.95))
			Mats.mesh(root, Mats.cylinder(0.02, 0.03, 0.08, 8), felt, Vector3(0.1, 0.25, 0))
		&"chef":
			var cot := Mats.solid(Color("fbfaf5"), 0.9)
			Mats.mesh(root, Mats.cylinder(0.36, 0.36, 0.26, 24), cot, Vector3(0, 0.13, 0))
			for i in 6:
				var a := TAU * i / 6.0
				Mats.mesh(root, Mats.sphere(0.22), cot, Vector3(cos(a) * 0.22, 0.42, sin(a) * 0.22))
			Mats.mesh(root, Mats.sphere(0.26), cot, Vector3(0, 0.5, 0))
		&"bunny", &"cat":
			var fur := Mats.solid(Color("f4f1ea") if id == &"bunny" else Color("ff9a3c"), 0.8)
			var inner := Mats.solid(Color("ff9fbf"), 0.7)
			for side in [1.0, -1.0]:
				if id == &"bunny":
					Mats.mesh(root, Mats.sphere(0.11, 0.22), fur, Vector3(0.17 * side, 0.4, 0), Vector3(0, 0, -10 * side), Vector3(1, 3.4, 0.55))
					Mats.mesh(root, Mats.sphere(0.07, 0.14), inner, Vector3(0.17 * side, 0.4, 0.045), Vector3(0, 0, -10 * side), Vector3(1, 4.0, 0.3))
				else:
					Mats.mesh(root, Mats.cylinder(0.0, 0.22, 0.36, 4), fur, Vector3(0.3 * side, 0.12, 0), Vector3(0, 45, -20 * side), Vector3(1, 1, 0.45))
					Mats.mesh(root, Mats.cylinder(0.0, 0.13, 0.24, 4), inner, Vector3(0.3 * side, 0.1, 0.05), Vector3(0, 45, -20 * side), Vector3(1, 1, 0.3))
		&"pirate":
			var felt := Mats.solid(Color("1d1a1f"), 0.7)
			Mats.mesh(root, Mats.sphere(0.36, 0.44), felt, Vector3(0, 0.12, 0))
			for i in 3:
				var a := TAU * i / 3.0 + PI * 0.5
				var b := Mats.mesh(root, Mats.softbox(Vector3(0.66, 0.26, 0.05), 0.4, Vector2(0.7, 1.0)), felt, Vector3(cos(a) * 0.32, 0.2, sin(a) * 0.32))
				b.rotation = Vector3(0, -a + PI * 0.5, 0)
				b.rotate_object_local(Vector3.RIGHT, deg_to_rad(-22))
			Mats.mesh(root, Mats.sphere(0.07), Mats.solid(Color("f4f1ea"), 0.5), Vector3(0, 0.25, 0.45))
			Mats.mesh(root, Mats.torus(0.3, 0.33), Mats.gold(), Vector3(0, 0.05, 0))
		&"propeller":
			Mats.mesh(root, Mats.sphere(0.4, 0.4, 24), Mats.solid(Color("3f7fff"), 0.5), Vector3(0, 0.02, 0))
			Mats.mesh(root, Mats.torus(0.36, 0.41), Mats.solid(Color("ffd23f"), 0.5), Vector3(0, 0.03, 0))
			Mats.mesh(root, Mats.cylinder(0.02, 0.02, 0.2, 8), Mats.solid(Color("e0455f"), 0.4), Vector3(0, 0.3, 0))
			var blades := Node3D.new()
			blades.name = "Propeller"
			blades.position = Vector3(0, 0.4, 0)
			root.add_child(blades)
			for side in [1.0, -1.0]:
				Mats.mesh(blades, Mats.softbox(Vector3(0.36, 0.02, 0.1), 0.6), Mats.solid(Color("e0455f"), 0.4), Vector3(0.18 * side, 0, 0), Vector3(12 * side, 0, 0))
			blades.set_meta(&"spin", 9.0)
		&"viking":
			var steel := Mats.solid(Color("a9b1bd"), 0.35, 0.7)
			Mats.mesh(root, Mats.sphere(0.4, 0.4, 24), steel, Vector3(0, 0.02, 0))
			Mats.mesh(root, Mats.torus(0.37, 0.43), Mats.solid(Color("7a5a2e"), 0.6, 0.3), Vector3(0, 0.03, 0))
			var horn := Mats.solid(Color("f3e6c8"), 0.5)
			for side in [1.0, -1.0]:
				Mats.mesh(root, Mats.cylinder(0.035, 0.08, 0.28, 12), horn, Vector3(0.38 * side, 0.2, 0), Vector3(0, 0, -55 * side))
				Mats.mesh(root, Mats.cylinder(0.0, 0.035, 0.18, 10), horn, Vector3(0.5 * side, 0.4, 0), Vector3(0, 0, -15 * side))
		&"halo":
			Mats.mesh(root, Mats.torus(0.3, 0.37, 32), Mats.glow(Color("ffe58a"), 1.6), Vector3(0, 0.38, 0))
		&"cloche":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.85, 0.95, 1.0, 0.28)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.metallic = 0.2
			glass.rim_enabled = true
			glass.rim = 0.6
			Mats.mesh(root, Mats.cylinder(0.5, 0.52, 0.03, 28), Mats.solid(Color("dcdcdc"), 0.3, 0.8), Vector3(0, 0.0, 0))
			var dome := Mats.mesh(root, Mats.sphere(0.46, 0.8, 24), glass, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
			dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Mats.mesh(root, Mats.sphere(0.06), Mats.solid(Color("dcdcdc"), 0.3, 0.8), Vector3(0, 0.54, 0))
			Mats.mesh(root, Mats.cylinder(0.2, 0.22, 0.14, 20), Mats.solid(Color("f7c6d9"), 0.6), Vector3(0, 0.1, 0))
			Mats.mesh(root, Mats.sphere(0.06), Mats.solid(Color("d61f4c"), 0.3), Vector3(0, 0.22, 0))
		_:
			root.queue_free()
			return null
	return root
