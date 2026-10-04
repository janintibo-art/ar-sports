extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		count += arrays[Mesh.ARRAY_INDEX].size() / 3
	return count

func _run() -> void:
	var original := VisualStyle.detailed
	var detailed_count := 0
	for detailed in [true, false]:
		VisualStyle.set_detailed(detailed, false)
		var dart := Dart.new()
		var other := Dart.new()
		root.add_child(dart)
		root.add_child(other)
		assert(dart._model.get_child_count() == 4)
		assert(dart._flights.size() == 2)
		assert(dart._flights[0].mesh == other._flights[0].mesh)
		var body: MeshInstance3D = dart._model.get_child(0).get_child(0)
		assert(body.mesh == other._model.get_child(0).get_child(0).mesh)
		assert(body.mesh.get_surface_count() == 3)
		var count := _triangles(body.mesh)
		assert(count < 900)
		if detailed: detailed_count = count
		else: assert(count < detailed_count)
		print("DART_BODY detailed=", detailed, " triangles=", count)
		dart.flight_color = Color.BLUE
		other.flight_color = Color.GREEN
		for f in dart._flights:
			assert(f.material_override.albedo_color == Color.BLUE)
			assert(f.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for f in other._flights:
			assert(f.material_override.albedo_color == Color.GREEN)
		assert(dart._shaft.material_override.albedo_color == Color.BLUE)
		var tip := Vector3(0.4, 1.5, -2)
		var basis := Basis(Vector3.UP, 0.3)
		dart.place_tip(tip, basis)
		assert(dart.tip_global().is_equal_approx(tip))
		dart.stick(tip, basis)
		dart._process(0.02)
		assert(dart.tip_global().is_equal_approx(tip))
		dart.queue_free()
		other.queue_free()
		await process_frame
	var board := Dartboard.new()
	root.add_child(board)
	var face: MeshInstance3D = board._content.get_node("Face")
	assert(face.material_override.albedo_texture == DartArt.grain_texture())
	assert(DartArt.grain_texture().get_image().has_mipmaps())
	var arrays := face.mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size())
	board.face_scale = 1.5
	assert(board._content.scale == Vector3.ONE * 1.5)
	for number in Dartboard.NUMBERS:
		for mult in [1, 2, 3]:
			assert(Dartboard.score_at(Dartboard.segment_center(number, mult))["value"] == number * mult)
	assert(Dartboard.score_at(Vector2.ZERO)["value"] == 50)
	assert(Dartboard.score_at(Vector2(0.5, 0))["value"] == 0)
	VisualStyle.set_detailed(original, false)
	board.queue_free()
	await process_frame
	print("SELFTEST darts_art_v27=OK")
	quit()
