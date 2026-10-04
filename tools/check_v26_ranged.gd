extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		count += arrays[Mesh.ARRAY_INDEX].size() / 3
		var used := {}
		for index in arrays[Mesh.ARRAY_INDEX]: used[index] = true
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			assert(used.has(index))
			assert(arrays[Mesh.ARRAY_VERTEX][index].is_finite())
	return count

func _run() -> void:
	var counts := {}
	for detailed in [true, false]:
		for kind in ["bow", "arrow", "knife"]:
			var art: Node3D
			var copy: Node3D
			match kind:
				"bow":
					art = RangedArt.bow(detailed)
					copy = RangedArt.bow(detailed)
				"arrow":
					art = RangedArt.arrow(0.7, Color.BLUE, detailed)
					copy = RangedArt.arrow(0.7, Color.BLUE, detailed)
				"knife":
					art = RangedArt.knife(detailed)
					copy = RangedArt.knife(detailed)
			assert(art.get_child_count() == 1)
			var visual: MeshInstance3D = art.get_child(0)
			assert(visual.mesh == copy.get_child(0).mesh)
			assert(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(visual.mesh.get_surface_count() <= 4)
			var triangles := _triangles(visual.mesh)
			assert(triangles > 50 and triangles < 1200)
			var bounds := visual.mesh.get_aabb()
			if kind == "bow":
				assert(bounds.position.y < -0.60 and bounds.end.y > 0.60)
				assert(bounds.size.x < 0.08)
			elif kind == "knife":
				assert(is_equal_approx(bounds.position.z, -0.14))
				assert(bounds.end.z <= 0.161 and bounds.size.y < 0.04)
			else:
				assert(bounds.position.z < -0.04 and is_equal_approx(bounds.end.z, 0.7))
			if detailed: counts[kind] = triangles
			else: assert(triangles < counts[kind])
			print("RANGED ", kind, " detailed=", detailed, " triangles=", triangles)
			art.free()
			copy.free()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("tir")
	main.game.start_discipline("arc")
	await process_frame
	var arc = main.game._child
	assert(arc._bow_string.size() == 2 and arc._preview.size() == 24)
	assert(arc._bow.get_child_count() == 3)
	var player = arc._new_arrow(arc.PLAYER)
	var ai = arc._new_arrow(arc.AI)
	assert(player.node.get_child(0).mesh != ai.node.get_child(0).mesh)
	main.game.show_choice()
	main.game.start_discipline("couteau")
	await process_frame
	var knives = main.game._child
	assert(knives._knives.size() == knives.PER_ROUND)
	for knife in knives._knives:
		assert(knife.node.get_child_count() == 1)
	main.queue_free()
	await process_frame
	print("SELFTEST ranged_v26=OK")
	quit()
