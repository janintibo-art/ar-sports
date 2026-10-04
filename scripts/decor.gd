class_name Decor
extends RefCounted
## Petits éléments de décor construits en code : arbres, bancs, lampadaires,
## plantes, enseignes néon. Servent à habiller les terrains de jeu.


static func tree(height: float = 3.2, seed_value: int = 1) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bark := BowlingArt.mat(Color(0.38, 0.3, 0.24), 0.9)
	n.add_child(BowlingArt.cylinder(0.09, 0.14, height * 0.62, bark, Vector3(0, height * 0.31, 0), 10))
	for i in (4 if VisualStyle.detailed else 1):
		var c := Color(0.22 + rng.randf() * 0.1, 0.5 + rng.randf() * 0.15, 0.2 + rng.randf() * 0.08)
		var r := (0.38 + rng.randf() * 0.2) * height / 3.0
		var pos := Vector3(rng.randf_range(-0.35, 0.35), height * 0.68 + rng.randf_range(0.0, 0.45), rng.randf_range(-0.35, 0.35))
		n.add_child(BowlingArt.sphere(r, BowlingArt.mat(c, 0.95), pos, 12))
	n.add_child(local_blob(1.6))
	return n


static func bush(radius: float = 0.35) -> Node3D:
	var n := Node3D.new()
	var g := BowlingArt.mat(Color(0.2, 0.45, 0.2), 0.95)
	n.add_child(BowlingArt.sphere(radius, g, Vector3(0, radius * 0.7, 0), 10))
	n.add_child(BowlingArt.sphere(radius * 0.7, BowlingArt.mat(Color(0.26, 0.52, 0.22), 0.95), Vector3(radius * 0.7, radius * 0.5, 0.1), 10))
	n.add_child(local_blob(radius * 3.0))
	return n


static func bench() -> Node3D:
	var n := Node3D.new()
	var wood := BowlingArt.surface_material("wood", Color(0.5, 0.33, 0.17))
	var metal := BowlingArt.mat(Color(0.15, 0.16, 0.18), 0.4, 0.7)
	n.add_child(BowlingArt.box(Vector3(1.3, 0.05, 0.4), wood, Vector3(0, 0.45, 0)))
	n.add_child(BowlingArt.box(Vector3(1.3, 0.3, 0.04), wood, Vector3(0, 0.72, -0.19)))
	for sx in [-0.55, 0.55]:
		n.add_child(BowlingArt.box(Vector3(0.05, 0.45, 0.4), metal, Vector3(sx, 0.225, 0)))
	n.add_child(local_blob(1.5))
	return n


static func lamp(height: float = 2.6, color: Color = Color(1.0, 0.85, 0.5)) -> Node3D:
	var n := Node3D.new()
	var metal := BowlingArt.mat(Color(0.12, 0.13, 0.15), 0.4, 0.6)
	n.add_child(BowlingArt.cylinder(0.03, 0.05, height, metal, Vector3(0, height / 2.0, 0), 10))
	n.add_child(BowlingArt.cylinder(0.12, 0.12, 0.03, metal, Vector3(0, 0.015, 0), 14))
	n.add_child(BowlingArt.sphere(0.12, BowlingArt.glow(color, 2.0), Vector3(0, height + 0.08, 0), 14))
	if not VisualStyle.detailed:
		return n
	var h := BowlingArt.halo(Vector2(0.6, 0.6), color * Color(1, 1, 1, 0.22))
	h.position = Vector3(0, height + 0.08, 0.02)
	n.add_child(h)
	var h2 := BowlingArt.halo(Vector2(0.6, 0.6), color * Color(1, 1, 1, 0.22))
	h2.position = Vector3(0, height + 0.08, 0.02)
	h2.rotation_degrees.y = 90
	n.add_child(h2)
	return n


static func plant(height: float = 0.9) -> Node3D:
	var n := Node3D.new()
	n.add_child(BowlingArt.cylinder(0.17, 0.12, 0.3, BowlingArt.mat(Color(0.7, 0.35, 0.22), 0.8), Vector3(0, 0.15, 0), 14))
	var leaf := BowlingArt.mat(Color(0.18, 0.5, 0.24), 0.8)
	for i in (7 if VisualStyle.detailed else 3):
		var a := TAU * i / 7.0
		var l := BowlingArt.capsule(0.035, height * 0.7, leaf, Vector3(cos(a) * 0.07, 0.3 + height * 0.3, sin(a) * 0.07))
		l.rotation = Vector3(sin(a) * 0.45, 0, -cos(a) * 0.45)
		n.add_child(l)
	n.add_child(local_blob(0.6))
	return n


## Enseigne néon encadrée, ampoules qui défilent. Face vers +Z.
static func neon_sign(text: String, color: Color, width: float = 1.4, height: float = 0.42) -> Node3D:
	var n := Node3D.new()
	n.add_child(BowlingArt.gradient_panel(Vector2(width, height), color.darkened(0.8), Color(0.02, 0.02, 0.06)))
	n.add_child(BowlingArt.box(Vector3(width + 0.04, height + 0.04, 0.04), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.03)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [height / 2.0, -height / 2.0]:
		n.add_child(BowlingArt.box(Vector3(width + 0.06, 0.025, 0.06), chrome, Vector3(0, y, -0.005)))
	for x in [width / 2.0, -width / 2.0]:
		n.add_child(BowlingArt.box(Vector3(0.025, height + 0.06, 0.06), chrome, Vector3(x, 0, -0.005)))
	var halo := BowlingArt.halo(Vector2(width * 0.95, height * 1.2), color * Color(1, 1, 1, 0.5))
	halo.position = Vector3(0, 0, 0.005)
	n.add_child(halo)
	var t := BowlingArt.neon_label(text, height * 0.5, color)
	t.position = Vector3(0, 0, 0.02)
	n.add_child(t)
	if not VisualStyle.detailed:
		return n
	var m := Marquee.new()
	m.base_color = color.lightened(0.3)
	m.setup(Marquee.rectangle_points(width - 0.06, height - 0.06, 0.07, 0.03), 0.014)
	n.add_child(m)
	return n


## Tapis / dalle de sol sombre sous une zone de jeu (ancre visuellement le décor).
static func rug(size: Vector2, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := BowlingArt.floor_quad(size.x, size.y, BowlingArt.surface_material("fabric", color, size * 3.0), pos)
	return mi


static func local_blob(diameter: float) -> MeshInstance3D:
	var shadow := BowlingArt.make_blob(diameter)
	shadow.top_level = false
	shadow.position.y = 0.002
	return shadow


## Décors secondaires, toujours hors des trajectoires et sans collisions.
## En mode léger, ces accessoires ne sont pas créés.
static func sport_corner(kind: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Ambiance_" + kind
	n.position = pos
	if not VisualStyle.detailed:
		return n
	var wood := BowlingArt.surface_material("wood", Color(0.34, 0.19, 0.095))
	var brass := BowlingArt.mat(Color(0.78, 0.59, 0.25), 0.3, 0.7)
	match kind:
		"pub":
			# Petit meuble de pub, bouteilles stylisées et deux tabourets.
			n.add_child(BowlingArt.box(Vector3(1.25, 0.82, 0.32), wood, Vector3(0, 0.41, 0)))
			n.add_child(BowlingArt.box(Vector3(1.34, 0.06, 0.4), wood, Vector3(0, 0.85, 0)))
			n.add_child(BowlingArt.box(Vector3(1.1, 0.018, 0.02), brass, Vector3(0, 0.67, 0.17)))
			for i in 5:
				var glass := BowlingArt.mat(Color(0.12 + i * 0.03, 0.36, 0.24), 0.22)
				var x := -0.43 + i * 0.21
				n.add_child(BowlingArt.cylinder(0.035, 0.04, 0.18, glass, Vector3(x, 0.97, 0), 10))
				n.add_child(BowlingArt.cylinder(0.015, 0.024, 0.07, glass, Vector3(x, 1.095, 0), 8))
				n.add_child(BowlingArt.box(Vector3(0.045, 0.052, 0.008), BowlingArt.mat(Color(0.92, 0.84, 0.61)), Vector3(x, 0.98, 0.037)))
			for x in [-0.47, 0.47]:
				n.add_child(BowlingArt.cylinder(0.14, 0.14, 0.06, BowlingArt.mat(Color(0.44, 0.10, 0.12)), Vector3(x, 0.60, 0.65), 16))
				n.add_child(BowlingArt.cylinder(0.025, 0.04, 0.57, brass, Vector3(x, 0.285, 0.65), 10))
				var shadow := local_blob(0.4)
				shadow.position = Vector3(x, 0.002, 0.65)
				n.add_child(shadow)
		"village":
			# Façade basse de café, volets provençaux, pots de fleurs.
			n.add_child(BowlingArt.box(Vector3(2.7, 1.8, 0.13), BowlingArt.mat(Color(0.78, 0.68, 0.5), 0.95), Vector3(0, 0.9, 0)))
			var shutter := BowlingArt.surface_material("wood", Color(0.19, 0.40, 0.48))
			for x in [-0.78, 0.78]:
				n.add_child(BowlingArt.box(Vector3(0.48, 0.64, 0.025), BowlingArt.mat(Color(0.10, 0.17, 0.21)), Vector3(x, 1.1, 0.082)))
				for side in [-1.0, 1.0]:
					n.add_child(BowlingArt.box(Vector3(0.17, 0.66, 0.035), shutter, Vector3(x + side * 0.34, 1.1, 0.088)))
				var flowers := flower_box()
				flowers.position = Vector3(x, 0.70, 0.14)
				n.add_child(flowers)
		"retro":
			# Jukebox : coque bois et chrome, disque, touches lumineuses.
			n.add_child(BowlingArt.box(Vector3(0.58, 1.15, 0.28), wood, Vector3(0, 0.575, 0)))
			var front := BowlingArt.rounded_panel(Vector2(0.49, 0.98), Color(0.22, 0.10, 0.28), Color(0.03, 0.04, 0.10), 0.08)
			front.position = Vector3(0, 0.59, 0.15)
			n.add_child(front)
			var record := BowlingArt.cylinder(0.16, 0.16, 0.012, BowlingArt.mat(Color(0.04, 0.04, 0.05)), Vector3(0, 0.80, 0.17), 24)
			record.rotation.x = PI / 2
			n.add_child(record)
			var hub := BowlingArt.sphere(0.035, BowlingArt.mat(Color(0.9, 0.23, 0.35)), Vector3(0, 0.8, 0.185), 10)
			hub.scale.z = 0.2
			n.add_child(hub)
			for i in 7:
				n.add_child(BowlingArt.box(Vector3(0.36, 0.012, 0.012), brass, Vector3(0, 0.22 + i * 0.03, 0.17)))
			for side in [-1.0, 1.0]:
				n.add_child(BowlingArt.box(Vector3(0.025, 0.92, 0.025), BowlingArt.unshaded(Color(0.25, 0.8, 0.92)), Vector3(side * 0.23, 0.59, 0.17)))
		"fair":
			# Guirlande et panneau festif, pas d'objets devant les cibles.
			n.add_child(bunting(3.2, 9))
			for side in [-1.0, 1.0]:
				n.add_child(BowlingArt.cylinder(0.035, 0.04, 1.8, wood, Vector3(side * 1.65, -0.9, 0), 10))
		"garden":
			var box := flower_box()
			n.add_child(box)
	return n


static func flower_box() -> Node3D:
	var n := Node3D.new()
	n.add_child(BowlingArt.box(Vector3(0.52, 0.12, 0.18), BowlingArt.mat(Color(0.63, 0.30, 0.19)), Vector3(0, 0.06, 0)))
	var stem := BowlingArt.mat(Color(0.14, 0.36, 0.14))
	for i in 5:
		var x := -0.20 + i * 0.1
		n.add_child(BowlingArt.cylinder(0.006, 0.006, 0.17, stem, Vector3(x, 0.19, 0), 6))
		var color := Color(0.97, 0.65, 0.17) if i % 2 == 0 else Color(0.92, 0.25, 0.38)
		var blossom := BowlingArt.sphere(0.039, BowlingArt.mat(color), Vector3(x, 0.29, 0), 8)
		blossom.scale.y = 0.55
		n.add_child(blossom)
	return n


static func bunting(width: float, count: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var x := -width * 0.5 + (i + 0.5) * width / count
		var drop := -0.08 * (1.0 - pow(2.0 * x / width, 2))
		var col := Color.from_hsv(float(i % 5) / 5.0, 0.72, 0.95)
		for p in [Vector3(x - 0.1, drop, 0), Vector3(x + 0.1, drop, 0), Vector3(x, drop - 0.23, 0)]:
			st.set_normal(Vector3.BACK)
			st.set_color(col)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := BowlingArt.mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi
