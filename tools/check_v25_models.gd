extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		count += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return count

func _run() -> void:
	var original := VisualStyle.detailed
	var counts := {}
	for shotgun in [false, true]:
		for detailed in [true, false]:
			var art := GunArt.build(shotgun, detailed)
			assert(art.get_child_count() == 1)
			var visual: MeshInstance3D = art.get_child(0)
			assert(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(visual.mesh.get_surface_count() <= 5)
			var triangles := _triangles(visual.mesh)
			assert(triangles > 100 and triangles < 2500)
			var bounds := visual.mesh.get_aabb()
			assert(bounds.position.z < -0.69)
			assert(bounds.end.z > 0.44 and bounds.end.z < 0.47)
			assert(bounds.size.x < 0.1 and bounds.size.y < 0.2)
			for surface in visual.mesh.get_surface_count():
				var arrays := visual.mesh.surface_get_arrays(surface)
				var used := {}
				for index in arrays[Mesh.ARRAY_INDEX]:
					used[index] = true
				for index in arrays[Mesh.ARRAY_VERTEX].size():
					var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
					if point.z > 0.14 and absf(arrays[Mesh.ARRAY_NORMAL][index].x) > 0.9:
						assert(used.has(index), "Face de crosse absente des indices")
				for point in arrays[Mesh.ARRAY_VERTEX]:
					assert(point.is_finite())
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					assert(normal.is_finite() and normal.length() > 0.9)
			if detailed:
				counts[shotgun] = triangles
			else:
				assert(triangles < counts[shotgun])
			print("MODELS shotgun=", shotgun, " detailed=", detailed, " triangles=", triangles, " surfaces=", visual.mesh.get_surface_count())
			art.free()
	var stock := GunArt._stock(0.04)
	var arrays := stock.mesh.surface_get_arrays(0)
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		if absf(normal.x) > 0.9:
			assert(normal.x * point.x > 0.0)
	stock.free()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for detailed in [true, false]:
		VisualStyle.set_detailed(detailed, false)
		main.start_game("tir")
		for id in ["carabine", "balltrap"]:
			main.game.start_discipline(id)
			await process_frame
			var game = main.game._child
			assert(not game._gun.visible)
			var art = game._gun.get_node("Habillage")
			assert(art.get_meta("detailed") == detailed)
			assert(art.get_meta("shotgun") == (id == "balltrap"))
			assert(art.get_child_count() == 1)
			if id == "carabine":
				assert(game.MUZZLE == 0.7 and not game._dot.visible)
			else:
				assert(game.MUZZLE == 0.8 and not game._flash.visible)
				assert(is_equal_approx(game._flash.position.z, -game.MUZZLE))
			main.game.show_choice()
	VisualStyle.set_detailed(original, false)
	main.queue_free()
	await process_frame
	print("SELFTEST models_v25=OK")
	quit()
