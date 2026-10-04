class_name DartArt
extends RefCounted
## Géométrie partagée ; les matériaux colorés restent propres à chaque fléchette.
static var _bodies := {}
static var _wing: Mesh
static var _grain: ImageTexture

static func body(detailed: bool) -> Node3D:
	if not _bodies.has(detailed):
		var steel := BowlingArt.mat(Color(0.78, 0.8, 0.85), 0.25, 0.9)
		var brass := BowlingArt.mat(Color(0.85, 0.68, 0.25), 0.3, 0.85)
		var dark := BowlingArt.mat(Color(0.25, 0.22, 0.12), 0.4, 0.8)
		var parts: Array[MeshInstance3D] = []
		parts.append(BowlingArt.cylinder(0.0003, 0.0018, 0.032, steel, Vector3(0, 0.062, 0), 8))
		parts.append(BowlingArt.cylinder(0.0033, 0.004, 0.044, brass, Vector3(0, 0.024, 0), 12 if detailed else 8))
		for y in ([0.006, 0.012, 0.018, 0.024, 0.03, 0.036] if detailed else [0.008, 0.02, 0.032]):
			parts.append(BowlingArt.cylinder(0.0041, 0.0041, 0.0015, dark, Vector3(0, y, 0), 12 if detailed else 8))
		var grouped := GunArt.batch(parts)
		_bodies[detailed] = grouped.get_child(0).mesh
		grouped.free()
	var result := Node3D.new()
	result.name = "Corps"
	var visual := MeshInstance3D.new()
	visual.mesh = _bodies[detailed]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.add_child(visual)
	return result

static func wing_mesh() -> Mesh:
	if _wing == null:
		var part := RangedArt._prism(PackedVector2Array([Vector2(-0.009, -0.034), Vector2(0.009, -0.034), Vector2(0.017, -0.049), Vector2(0.013, -0.074), Vector2(-0.013, -0.074), Vector2(-0.017, -0.049)]), 0.0008, null)
		_wing = part.mesh
		part.free()
	return _wing

static func grain_texture() -> ImageTexture:
	if _grain == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var hash_value := (x * 73856093) ^ (y * 19349663)
				var value := 0.94 + 0.06 * float(posmod(hash_value, 101)) / 100.0
				img.set_pixel(x, y, Color(value, value, value))
		img.generate_mipmaps()
		_grain = ImageTexture.create_from_image(img)
	return _grain
