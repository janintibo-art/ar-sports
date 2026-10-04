class_name PingArt
extends RefCounted
## Matériaux et géométries d'équipement partagés ; aucun calcul de collision.
static var _rubber: ImageTexture
static var _ball: StandardMaterial3D
static var _paddles := {}

static func rubber_texture() -> ImageTexture:
	if _rubber == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in 64:
			for x in 64:
				var value := 0.92 if x % 4 == 1 and y % 4 == 1 else 1.0
				img.set_pixel(x, y, Color(value, value, value))
		img.generate_mipmaps()
		_rubber = ImageTexture.create_from_image(img)
	return _rubber

static func ball_material() -> StandardMaterial3D:
	if _ball == null:
		var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
		var base := Color(1.0, 0.55, 0.1)
		for y in 64:
			for x in 128:
				var shade := 0.98 + float((x * 17 + y * 31) % 11) / 500.0
				if y == 32: shade = 0.83
				img.set_pixel(x, y, base * Color(shade, shade, shade))
		img.generate_mipmaps()
		_ball = BowlingArt.mat(Color.WHITE, 0.7)
		_ball.albedo_texture = ImageTexture.create_from_image(img)
		_ball.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _ball

static func paddle(radius: float, color: Color, luminous: bool, detailed: bool) -> Node3D:
	var key := str(radius) + color.to_html() + str(luminous) + str(detailed)
	if not _paddles.has(key):
		var wood := BowlingArt.surface_material("wood", Color(0.78, 0.55, 0.3))
		var edge := BowlingArt.mat(Color(0.27, 0.15, 0.07), 0.7)
		var front := BowlingArt.glow(color, 0.6) if luminous else BowlingArt.mat(color, 0.75)
		front.albedo_texture = rubber_texture()
		front.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var back := BowlingArt.mat(Color(0.08, 0.08, 0.09), 0.8)
		back.albedo_texture = rubber_texture()
		var parts: Array[MeshInstance3D] = []
		var segments := 40 if detailed else 24
		for item in [[0.008, wood, 0.0], [0.004, front, -0.006], [0.004, back, 0.006]]:
			var disk := BowlingArt.cylinder(radius, radius, item[0], item[1], Vector3(0, 0, item[2]), segments)
			disk.rotation_degrees.x = 90
			parts.append(disk)
		parts.append(BowlingArt.capsule(0.013, 0.11, wood, Vector3(0, -radius - 0.045, 0)))
		parts.append(BowlingArt.box(Vector3(0.03, 0.03, 0.01), wood, Vector3(0, -radius + 0.005, 0)))
		if detailed:
			var middle := BowlingArt.cylinder(radius + 0.0003, radius + 0.0003, 0.0015, edge, Vector3.ZERO, segments)
			middle.rotation_degrees.x = 90
			parts.append(middle)
			for y in [-radius - 0.04, -radius - 0.075]:
				parts.append(BowlingArt.box(Vector3(0.024, 0.005, 0.022), edge, Vector3(0, y, 0)))
			parts.append(BowlingArt.box(Vector3(0.027, 0.008, 0.022), edge, Vector3(0, -radius - 0.095, 0)))
		var grouped := GunArt.batch(parts)
		_paddles[key] = grouped.get_child(0).mesh
		grouped.free()
	var root := Node3D.new()
	root.name = "Habillage"
	var visual := MeshInstance3D.new()
	visual.mesh = _paddles[key]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(visual)
	return root
