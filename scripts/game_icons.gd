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
	return root
