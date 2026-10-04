class_name GameIcons
extends RefCounted
## Pictogrammes 3D des jeux (menu, logo), bâtis en code. Taille d'environ 0,14 m.


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"bowling":
			var pin := MeshInstance3D.new()
			pin.mesh = BowlingArt.pin_mesh()
			var pm := StandardMaterial3D.new()
			pm.vertex_color_use_as_albedo = true
			pm.roughness = 0.35
			pin.material_override = pm
			pin.scale = Vector3.ONE * 0.34
			pin.position = Vector3(-0.025, -0.065, 0)
			root.add_child(pin)
			root.add_child(BowlingArt.sphere(0.04, BowlingArt.mat(Color(0.15, 0.3, 0.95), 0.25, 0.3), Vector3(0.05, -0.03, 0.035), 18))
		"flechettes":
			var rings := [[0.068, Color(0.07, 0.07, 0.08)], [0.056, Color(0.85, 0.12, 0.12)], [0.044, Color(0.94, 0.88, 0.7)],
				[0.032, Color(0.1, 0.55, 0.25)], [0.017, Color(0.85, 0.12, 0.12)]]
			for i in rings.size():
				var disc := BowlingArt.cylinder(rings[i][0], rings[i][0], 0.006, BowlingArt.mat(rings[i][1], 0.7), Vector3(0, 0, 0.003 * (i + 1)), 28)
				disc.rotation_degrees = Vector3(90, 0, 0)
				root.add_child(disc)
			var dart := Dart.new()
			dart.flight_color = Color(1.0, 0.8, 0.2)
			var b := Basis.from_euler(Vector3(deg_to_rad(-18.0), deg_to_rad(28.0), 0.0)).scaled(Vector3.ONE * 0.7)
			dart.basis = b
			dart.position = Vector3(0.012, 0.01, 0.02) - b * dart.tip_local
			root.add_child(dart)
		"petanque":
			var steel := BowlingArt.mat(Color(0.72, 0.74, 0.8), 0.18, 0.95)
			root.add_child(BowlingArt.sphere(0.042, steel, Vector3(-0.04, -0.025, 0), 22))
			root.add_child(BowlingArt.sphere(0.042, BowlingArt.mat(Color(0.6, 0.62, 0.68), 0.22, 0.95), Vector3(0.048, -0.03, 0.02), 22))
			root.add_child(BowlingArt.sphere(0.014, BowlingArt.mat(Color(1.0, 0.82, 0.15), 0.4), Vector3(0.0, 0.045, 0.03), 14))
		"pingpong":
			var holder := Node3D.new()
			holder.rotation_degrees = Vector3(0, 0, 22)
			root.add_child(holder)
			var blade := BowlingArt.cylinder(0.062, 0.062, 0.012, BowlingArt.mat(Color(0.85, 0.12, 0.12), 0.5), Vector3(0, 0.02, 0), 28)
			blade.rotation_degrees = Vector3(90, 0, 0)
			holder.add_child(blade)
			holder.add_child(BowlingArt.box(Vector3(0.022, 0.075, 0.014), BowlingArt.mat(Color(0.75, 0.5, 0.25), 0.5), Vector3(0, -0.06, 0)))
			root.add_child(BowlingArt.sphere(0.02, BowlingArt.mat(Color(1, 1, 1), 0.3), Vector3(0.06, 0.04, 0.045), 14))
		"molkky":
			var wood := BowlingArt.mat(Color(0.85, 0.62, 0.32), 0.6)
			var num := [7, 9, 12]
			for i in 3:
				var pin := BowlingArt.cylinder(0.026, 0.026, 0.07, wood, Vector3((i - 1) * 0.052, -0.03 + (0.012 if i == 1 else 0.0), 0.0), 14)
				root.add_child(pin)
				var l := BowlingArt.label(str(num[i]), 0.03, Color(0.25, 0.1, 0.0), 0)
				l.position = Vector3((i - 1) * 0.052, -0.03 + (0.012 if i == 1 else 0.0), 0.028)
				root.add_child(l)
			var stick := BowlingArt.cylinder(0.022, 0.022, 0.1, BowlingArt.mat(Color(0.95, 0.75, 0.4), 0.5), Vector3(0.0, 0.05, 0.02), 14)
			stick.rotation_degrees = Vector3(0, 0, 70)
			root.add_child(stick)
		"grenouille":
			var green := BowlingArt.mat(Color(0.25, 0.65, 0.2), 0.55)
			var body := BowlingArt.sphere(0.05, green, Vector3(0, -0.02, 0), 16)
			body.scale = Vector3(1.3, 0.85, 0.8)
			root.add_child(body)
			var head := BowlingArt.sphere(0.04, green, Vector3(0, 0.015, 0.02), 14)
			head.scale = Vector3(1.4, 0.8, 0.8)
			root.add_child(head)
			for sx in [-1.0, 1.0]:
				root.add_child(BowlingArt.sphere(0.018, green, Vector3(sx * 0.03, 0.05, 0.0), 10))
				root.add_child(BowlingArt.sphere(0.011, BowlingArt.unshaded(Color(1, 1, 1)), Vector3(sx * 0.03, 0.055, 0.016), 8))
				root.add_child(BowlingArt.sphere(0.005, BowlingArt.unshaded(Color(0.02, 0.02, 0.03)), Vector3(sx * 0.03, 0.057, 0.025), 6))
			var mouth := BowlingArt.cylinder(0.03, 0.03, 0.01, BowlingArt.mat(Color(0.8, 0.1, 0.15), 0.5), Vector3(0, -0.015, 0.05), 16)
			mouth.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(mouth)
			var puck := BowlingArt.cylinder(0.022, 0.022, 0.008, BowlingArt.mat(Color(0.8, 0.8, 0.88), 0.2, 0.95), Vector3(0.05, 0.04, 0.06), 16)
			puck.rotation_degrees = Vector3(70, 0, 20)
			root.add_child(puck)
		"palet":
			var board := BowlingArt.box(Vector3(0.15, 0.012, 0.1), BowlingArt.mat(Color(0.45, 0.3, 0.15), 0.7), Vector3(0, -0.04, 0))
			board.rotation_degrees = Vector3(-35, 0, 0)
			root.add_child(board)
			var hole := BowlingArt.cylinder(0.014, 0.014, 0.014, BowlingArt.unshaded(Color(0.02, 0.02, 0.03)), Vector3(0, -0.04, 0.0), 12)
			hole.rotation_degrees = Vector3(-35, 0, 0)
			root.add_child(hole)
			var puck := BowlingArt.cylinder(0.034, 0.034, 0.012, BowlingArt.mat(Color(0.8, 0.8, 0.88), 0.2, 0.95), Vector3(0.03, 0.04, 0.05), 20)
			puck.rotation_degrees = Vector3(55, 20, 0)
			root.add_child(puck)
		"billard":
			root.add_child(BowlingArt.box(Vector3(0.17, 0.014, 0.1), BowlingArt.mat(Color(0.05, 0.45, 0.28), 0.9), Vector3(0, -0.05, 0)))
			for sy in [-1.0, 1.0]:
				root.add_child(BowlingArt.box(Vector3(0.18, 0.02, 0.012), BowlingArt.mat(Color(0.4, 0.22, 0.1), 0.6), Vector3(0, -0.045, sy * 0.055)))
			root.add_child(BowlingArt.sphere(0.02, BowlingArt.mat(Color(0.05, 0.05, 0.06), 0.15, 0.2), Vector3(-0.03, -0.03, 0.0), 14))
			root.add_child(BowlingArt.sphere(0.02, BowlingArt.mat(Color(0.9, 0.15, 0.15), 0.15, 0.2), Vector3(0.0, -0.03, 0.0), 14))
			root.add_child(BowlingArt.sphere(0.02, BowlingArt.mat(Color(0.95, 0.95, 0.9), 0.15, 0.2), Vector3(0.04, -0.03, 0.025), 14))
			var cue := BowlingArt.cylinder(0.004, 0.009, 0.17, BowlingArt.mat(Color(0.85, 0.65, 0.35), 0.4), Vector3(0.04, 0.0, 0.0), 8)
			cue.rotation_degrees = Vector3(0, 0, 65)
			root.add_child(cue)
		"babyfoot":
			root.add_child(BowlingArt.box(Vector3(0.17, 0.012, 0.1), BowlingArt.mat(Color(0.1, 0.55, 0.25), 0.8), Vector3(0, -0.05, 0)))
			root.add_child(BowlingArt.box(Vector3(0.002, 0.003, 0.1), BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, -0.043, 0)))
			for rx in [-0.055, 0.0, 0.055]:
				var rod := BowlingArt.cylinder(0.004, 0.004, 0.14, BowlingArt.mat(Color(0.8, 0.8, 0.85), 0.2, 0.9), Vector3(rx, -0.02, 0), 8)
				rod.rotation_degrees = Vector3(90, 0, 0)
				root.add_child(rod)
				var col := Color(0.9, 0.2, 0.2) if rx <= 0.0 else Color(0.2, 0.4, 0.95)
				for zz in [-0.025, 0.025]:
					root.add_child(BowlingArt.box(Vector3(0.012, 0.03, 0.014), BowlingArt.mat(col, 0.5), Vector3(rx, -0.03, zz)))
			root.add_child(BowlingArt.sphere(0.011, BowlingArt.mat(Color(1, 1, 1), 0.3), Vector3(0.025, -0.036, 0.01), 10))
		"tir":
			var rings := [[0.062, Color(0.95, 0.95, 0.95)], [0.048, Color(0.1, 0.1, 0.12)], [0.034, Color(0.9, 0.15, 0.15)], [0.02, Color(0.95, 0.85, 0.3)]]
			for i in rings.size():
				var disc := BowlingArt.cylinder(rings[i][0], rings[i][0], 0.006, BowlingArt.mat(rings[i][1], 0.7), Vector3(0, 0, 0.003 * (i + 1)), 28)
				disc.rotation_degrees = Vector3(90, 0, 0)
				root.add_child(disc)
			var cross := BowlingArt.unshaded(Color(0.1, 1.0, 0.4))
			root.add_child(BowlingArt.box(Vector3(0.16, 0.003, 0.003), cross, Vector3(0, 0, 0.03)))
			root.add_child(BowlingArt.box(Vector3(0.003, 0.16, 0.003), cross, Vector3(0, 0, 0.03)))
			var clay := BowlingArt.sphere(0.02, BowlingArt.mat(Color(1.0, 0.5, 0.1), 0.6), Vector3(0.055, 0.05, 0.04), 12)
			clay.scale = Vector3(1.0, 0.3, 1.0)
			root.add_child(clay)
	return root
