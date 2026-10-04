class_name RangedArt
extends RefCounted
## Habillages statiques partagés ; la corde et les trajectoires restent dans les jeux.
static var _wood: StandardMaterial3D
static var _steel: StandardMaterial3D
static var _grip: StandardMaterial3D
static var _trim: StandardMaterial3D
static var _feathers := {}
static var _meshes := {}

static func _materials() -> void:
	if _wood != null: return
	_wood = BowlingArt.surface_material("wood", Color(0.55, 0.34, 0.16))
	_steel = BowlingArt.mat(Color(0.72, 0.76, 0.82), 0.24, 0.85)
	_grip = BowlingArt.mat(Color(0.16, 0.095, 0.055), 0.82)
	_trim = BowlingArt.mat(Color(0.67, 0.49, 0.21), 0.38, 0.65)

static func _finish(key: String, parts: Array[MeshInstance3D]) -> Node3D:
	var result := GunArt.batch(parts)
	_meshes[key] = result.get_child(0).mesh
	return result

static func _cached(key: String) -> Node3D:
	var result := Node3D.new()
	result.name = "Habillage"
	var visual := MeshInstance3D.new()
	visual.mesh = _meshes[key]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.add_child(visual)
	return result

static func bow(detailed: bool) -> Node3D:
	_materials()
	var key := "bow_" + str(detailed)
	if _meshes.has(key): return _cached(key)
	var parts: Array[MeshInstance3D] = []
	var segments := 32 if detailed else 12
	for i in segments:
		var t0 := -1.0 + 2.0 * i / segments
		var t1 := -1.0 + 2.0 * (i + 1) / segments
		var a := Vector3(0, t0 * 0.62, 0.14 * t0 * t0)
		var b := Vector3(0, t1 * 0.62, 0.14 * t1 * t1)
		var width := lerpf(0.028, 0.011, absf((t0 + t1) / 2.0))
		var segment := BowlingArt.box(Vector3(width, 0.014, a.distance_to(b) + 0.001), _wood, (a + b) / 2.0)
		segment.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT)
		parts.append(segment)
	parts.append(BowlingArt.capsule(0.018, 0.135, _grip))
	for side in [-1.0, 1.0]:
		parts.append(BowlingArt.box(Vector3(0.017, 0.023, 0.025), _trim, Vector3(0, side * 0.61, 0.136)))
	if detailed:
		for i in 9:
			parts.append(BowlingArt.box(Vector3(0.037, 0.003, 0.033), _trim, Vector3(0, -0.048 + i * 0.012, 0)))
	return _finish(key, parts)

static func arrow(length: float, color: Color, detailed: bool) -> Node3D:
	_materials()
	var key := "arrow_" + str(length) + color.to_html() + str(detailed)
	if _meshes.has(key): return _cached(key)
	if not _feathers.has(color): _feathers[color] = BowlingArt.mat(color, 0.72)
	var parts: Array[MeshInstance3D] = []
	var shaft := BowlingArt.cylinder(0.004, 0.004, length, _wood, Vector3(0, 0, length / 2.0), 8 if detailed else 6)
	shaft.rotation_degrees.x = 90
	parts.append(shaft)
	var tip := BowlingArt.cylinder(0.0, 0.007, 0.05, _steel, Vector3(0, 0, -0.02), 6)
	tip.rotation_degrees.x = -90
	parts.append(tip)
	for i in 3:
		var vane := _prism(PackedVector2Array([Vector2(length - 0.12, 0), Vector2(length - 0.10, 0.022), Vector2(length - 0.025, 0.016), Vector2(length - 0.025, 0)]), 0.002, _feathers[color])
		vane.rotation_degrees.z = i * 120.0
		parts.append(vane)
	if detailed:
		for z in [length - 0.13, length - 0.02]:
			var binding := BowlingArt.cylinder(0.005, 0.005, 0.012, _grip, Vector3(0, 0, z), 8)
			binding.rotation_degrees.x = 90
			parts.append(binding)
	return _finish(key, parts)

static func knife(detailed: bool) -> Node3D:
	_materials()
	var key := "knife_" + str(detailed)
	if _meshes.has(key): return _cached(key)
	var parts: Array[MeshInstance3D] = []
	parts.append(_prism(PackedVector2Array([Vector2(-0.14, 0.001), Vector2(-0.08, 0.016), Vector2(0.035, 0.014), Vector2(0.04, -0.013), Vector2(-0.08, -0.016), Vector2(-0.14, -0.001)]), 0.004, _steel))
	var handle := BowlingArt.capsule(0.012, 0.12, _wood, Vector3(0, 0, 0.1))
	handle.rotation_degrees.x = 90
	parts.append(handle)
	parts.append(BowlingArt.box(Vector3(0.03, 0.036, 0.012), _trim, Vector3(0, 0, 0.04)))
	parts.append(BowlingArt.box(Vector3(0.024, 0.024, 0.008), _steel, Vector3(0, 0, 0.155)))
	if detailed:
		for side in [-1.0, 1.0]:
			for z in [0.075, 0.125]:
				var rivet := BowlingArt.cylinder(0.0025, 0.0025, 0.002, _trim, Vector3(side * 0.012, 0, z), 6)
				rivet.rotation_degrees.z = 90
				parts.append(rivet)
		for z in [0.062, 0.092, 0.122]:
			parts.append(BowlingArt.box(Vector3(0.024, 0.003, 0.004), _grip, Vector3(0, -0.009, z)))
	return _finish(key, parts)

## Profil (z, y) extrudé sur x. Indices explicites pour le regroupement.
static func _prism(profile: PackedVector2Array, thickness: float, material: Material) -> MeshInstance3D:
	if Geometry2D.is_polygon_clockwise(profile): profile.reverse()
	var indices := Geometry2D.triangulate_polygon(profile)
	assert(indices.size() == (profile.size() - 2) * 3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in range(0, indices.size(), 3):
			for corner in ([0, 1, 2] if side < 0 else [2, 1, 0]):
				var p := profile[indices[i + corner]]
				st.set_uv(p)
				st.add_vertex(Vector3(side * thickness / 2, p.y, p.x))
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var points := [Vector3(-thickness / 2, a.y, a.x), Vector3(thickness / 2, a.y, a.x), Vector3(thickness / 2, b.y, b.x), Vector3(-thickness / 2, b.y, b.x)]
		for j in [2, 1, 0, 3, 2, 0]:
			st.set_uv(Vector2(points[j].z, points[j].y))
			st.add_vertex(points[j])
	st.generate_normals()
	st.index()
	var result := MeshInstance3D.new()
	result.mesh = st.commit()
	result.material_override = material
	return result
