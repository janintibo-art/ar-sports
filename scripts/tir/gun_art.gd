class_name GunArt
extends RefCounted
## Modèles statiques légers : cinq matériaux partagés, géométrie regroupée.
static var _wood: StandardMaterial3D
static var _metal: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _steel: StandardMaterial3D
static var _sight: StandardMaterial3D

static func build(shotgun: bool, detailed: bool) -> Node3D:
	if _wood == null:
		_wood = BowlingArt.surface_material("wood", Color(0.48, 0.28, 0.13))
		_metal = BowlingArt.mat(Color(0.16, 0.18, 0.21), 0.3, 0.72)
		_dark = BowlingArt.mat(Color(0.035, 0.04, 0.05), 0.82)
		_steel = BowlingArt.mat(Color(0.48, 0.5, 0.54), 0.27, 0.78)
		_sight = BowlingArt.unshaded(Color(1.0, 0.78, 0.22))
	var parts: Array[MeshInstance3D] = []
	var thickness := 0.045 if shotgun else 0.04
	parts.append(_stock(thickness))
	parts.append(BowlingArt.box(Vector3(thickness + 0.009, 0.07, 0.018), _dark, Vector3(0, -0.031, 0.445)))
	parts.append(BowlingArt.capsule(thickness * 0.52, 0.32 if shotgun else 0.39, _wood, Vector3(0, -0.028, -0.3)))
	parts[-1].rotation_degrees.x = 90
	parts.append(BowlingArt.box(Vector3(thickness, 0.055 if shotgun else 0.05, 0.18), _metal, Vector3(0, 0, -0.025)))
	for x in ([-0.014, 0.014] if shotgun else [0.0]):
		var radius := 0.014 if shotgun else 0.011
		var chamber := BowlingArt.cylinder(radius * 1.1, radius * 1.1, 0.13, _metal, Vector3(x, 0.012 if shotgun else 0.008, -0.15), 12 if detailed else 8)
		chamber.rotation_degrees.x = 90
		parts.append(chamber)
		var barrel := BowlingArt.cylinder(radius, radius, 0.62 if shotgun else 0.5, _metal, Vector3(x, 0.012 if shotgun else 0.008, -0.5 if shotgun else -0.45), 12 if detailed else 8)
		barrel.rotation_degrees.x = 90
		parts.append(barrel)
		var mouth := BowlingArt.cylinder(radius * 0.7, radius * 0.7, 0.001, _dark, Vector3(x, barrel.position.y, -0.811 if shotgun else -0.701), 12 if detailed else 8)
		mouth.rotation_degrees.x = 90
		parts.append(mouth)
	# Pontet et détente ; aucun corps physique ni collision ajoutés.
	parts.append(BowlingArt.box(Vector3(0.012, 0.045, 0.009), _metal, Vector3(0, -0.055, -0.025)))
	parts.append(BowlingArt.box(Vector3(0.012, 0.008, 0.08), _metal, Vector3(0, -0.077, 0.011)))
	parts.append(BowlingArt.box(Vector3(0.012, 0.045, 0.009), _metal, Vector3(0, -0.055, 0.046)))
	parts.append(BowlingArt.box(Vector3(0.007, 0.028, 0.006), _steel, Vector3(0, -0.049, 0.005)))
	parts[-1].rotation_degrees.x = -18
	if shotgun:
		parts.append(BowlingArt.box(Vector3(0.008, 0.012, 0.64), _metal, Vector3(0, 0.03, -0.5)))
		parts.append(BowlingArt.sphere(0.008, _sight, Vector3(0, 0.035, -0.8), 6))
	else:
		parts.append(BowlingArt.box(Vector3(0.012, 0.03, 0.012), _metal, Vector3(0, 0.04, -0.66)))
		parts.append(BowlingArt.box(Vector3(0.03, 0.02, 0.012), _metal, Vector3(0, 0.04, 0)))
	if detailed:
		for side in [-1.0, 1.0]:
			parts.append(BowlingArt.box(Vector3(0.002, 0.03, 0.09), _steel, Vector3(side * (thickness * 0.5 + 0.001), 0, -0.02)))
			for z in [-0.055, 0.015]:
				var screw := BowlingArt.cylinder(0.003, 0.003, 0.003, _dark, Vector3(side * (thickness * 0.5 + 0.003), 0, z), 6)
				screw.rotation_degrees.z = 90
				parts.append(screw)
		for i in 6:
			parts.append(BowlingArt.box(Vector3(thickness + 0.004, 0.004, 0.006), _dark, Vector3(0, -0.049, -0.2 - i * 0.022)))
		parts.append(BowlingArt.box(Vector3(0.008, 0.006, 0.08), _steel, Vector3(0, 0.029, -0.01)))
	var result := batch(parts)
	result.set_meta("shotgun", shotgun)
	result.set_meta("detailed", detailed)
	return result

static func _stock(thickness: float) -> MeshInstance3D:
	var profile := PackedVector2Array([Vector2(0.065, 0.012), Vector2(0.24, 0.012), Vector2(0.445, 0.025), Vector2(0.445, -0.105), Vector2(0.30, -0.09), Vector2(0.145, -0.038), Vector2(0.095, -0.091), Vector2(0.06, -0.078)])
	var triangles := Geometry2D.triangulate_polygon(profile)
	assert(triangles.size() == (profile.size() - 2) * 3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in range(0, triangles.size(), 3):
			for corner in ([0, 1, 2] if side < 0 else [2, 1, 0]):
				var p := profile[triangles[i + corner]]
				st.set_uv(Vector2(p.x * 3.0, p.y * 3.0))
				st.add_vertex(Vector3(side * thickness / 2.0, p.y, p.x))
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var vertices := [Vector3(-thickness / 2.0, a.y, a.x), Vector3(thickness / 2.0, a.y, a.x), Vector3(thickness / 2.0, b.y, b.x), Vector3(-thickness / 2.0, b.y, b.x)]
		for j in [2, 1, 0, 3, 2, 0]:
			st.set_uv(Vector2(vertices[j].z * 3.0, vertices[j].y * 3.0))
			st.add_vertex(vertices[j])
	st.generate_normals()
	st.index()
	var result := MeshInstance3D.new()
	result.mesh = st.commit()
	result.material_override = _wood
	return result

static func batch(parts: Array[MeshInstance3D]) -> Node3D:
	var groups := {}
	for part in parts:
		var material: Material = part.material_override
		if not groups.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[material] = st
		groups[material].append_from(part.mesh, 0, part.transform)
	var combined := ArrayMesh.new()
	for material in groups:
		groups[material].set_material(material)
		groups[material].commit(combined)
	var root := Node3D.new()
	root.name = "Habillage"
	var visual := MeshInstance3D.new()
	visual.mesh = combined
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(visual)
	for part in parts:
		part.free()
	return root
