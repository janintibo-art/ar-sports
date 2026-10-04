extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var existed := FileAccess.file_exists(VisualStyle.SAVE_PATH)
	var previous_bytes := FileAccess.get_file_as_bytes(VisualStyle.SAVE_PATH) if existed else PackedByteArray()
	var original := [VisualStyle.detailed, VisualStyle.ui_scale, VisualStyle.distance_factor]
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.skip_intro()
	main.start_game("comfort")
	assert(main._comfort_open and main._comfort.visible and not main.menu.visible)
	for card in main.menu._panels:
		assert(card.collision_layer == 0)
	main._on_comfort_pressed("size_1.3")
	main._on_comfort_pressed("distance_1.25")
	assert(is_equal_approx(VisualStyle.ui_scale, 1.3))
	assert(is_equal_approx(main._comfort.scale.x, 1.3))
	var cfg := ConfigFile.new()
	assert(cfg.load(VisualStyle.SAVE_PATH) == OK)
	assert(is_equal_approx(float(cfg.get_value("comfort", "scale")), 1.3))
	VisualStyle.set_detailed(false)
	VisualStyle.load_preferences()
	assert(not VisualStyle.detailed and is_equal_approx(VisualStyle.ui_scale, 1.3))
	main._on_comfort_pressed("close")
	assert(not main._comfort_open and main.menu.visible)
	assert(is_equal_approx(main.menu.scale.x, 1.3))
	assert(main._comfort._buttons[0].collision_layer == 0)
	var panel = load("res://scripts/ui_panel.gd").new()
	main.add_child(panel)
	panel.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)), 0.8)
	assert(is_equal_approx(panel.scale.x, 1.3))
	assert(is_equal_approx(panel.global_position.z, -1.0))
	main.open_comfort()
	main._on_comfort_pressed("reset")
	assert(is_equal_approx(VisualStyle.ui_scale, 1.0) and is_equal_approx(VisualStyle.distance_factor, 1.0))
	main.close_comfort()
	VisualStyle.set_comfort(100, -100, false)
	assert(is_equal_approx(VisualStyle.ui_scale, 1.3) and is_equal_approx(VisualStyle.distance_factor, 0.85))
	VisualStyle.detailed = original[0]
	VisualStyle.set_comfort(original[1], original[2], false)
	if existed:
		var file := FileAccess.open(VisualStyle.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(VisualStyle.SAVE_PATH)
	main.queue_free()
	await process_frame
	print("SELFTEST comfort_v21=OK")
	quit(0)
