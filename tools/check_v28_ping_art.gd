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
	var counts := {}
	for detailed in [true, false]:
		for luminous in [false, true]:
			var color := Color.BLUE if luminous else Color.RED
			var art := PingArt.paddle(PingPaddle.RADIUS, color, luminous, detailed)
			var copy := PingArt.paddle(PingPaddle.RADIUS, color, luminous, detailed)
			assert(art.get_child_count() == 1)
			var visual: MeshInstance3D = art.get_child(0)
			assert(visual.mesh == copy.get_child(0).mesh)
			assert(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(visual.mesh.get_surface_count() <= 4)
			var triangles := _triangles(visual.mesh)
			assert(triangles < 2200)
			if detailed: counts[luminous] = triangles
			else: assert(triangles < counts[luminous])
			var bounds := visual.mesh.get_aabb()
			assert(bounds.size.x <= 0.192 and bounds.size.z <= 0.028)
			assert(bounds.position.y >= -0.196 and bounds.end.y <= 0.096)
			var found := false
			for surface in visual.mesh.get_surface_count():
				var material: StandardMaterial3D = visual.mesh.surface_get_material(surface)
				if material.albedo_color == color:
					found = true
					assert(material.albedo_texture == PingArt.rubber_texture())
					assert(material.emission_enabled == luminous)
			assert(found)
			print("PING_ART detailed=", detailed, " luminous=", luminous, " triangles=", triangles)
			art.free()
			copy.free()
	assert(PingArt.rubber_texture().get_image().has_mipmaps())
	assert(PingArt.ball_material().albedo_texture.get_image().has_mipmaps())
	assert(PingPaddle.RADIUS == 0.095)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("pingpong")
	await process_frame
	var game = main.game
	assert(game.BALL_R == 0.028)
	assert(is_equal_approx(game._ball.mesh.radius, game.BALL_R))
	assert(game._ball.material_override == PingArt.ball_material())
	assert(game._player_paddle.get_child_count() == 1)
	assert(game._ai_paddle.glow)
	main.queue_free()
	await process_frame
	print("SELFTEST ping_art_v28=OK")
	quit()
