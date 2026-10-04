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
	for i in 4:
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
	var wood := BowlingArt.mat(Color(0.5, 0.33, 0.17), 0.7)
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
	for i in 7:
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
