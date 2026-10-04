extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("billard")
	await process_frame
	await process_frame

	var game = main.game
	assert(game != null)
	var cue = game.get("_cue")
	assert(is_instance_valid(cue))
	assert(cue.has_meta("cue_art_v30"))

	var cue_tip := float(game.get("CUE_TIP"))
	var cue_back := float(game.get("CUE_BACK"))
	assert(is_equal_approx(float(cue.get_meta("cue_tip_distance")), cue_tip))
	assert(is_equal_approx(float(cue.get_meta("cue_back_distance")), cue_back))
	assert(is_equal_approx(float(cue.get_meta("cue_total_length")), cue_tip + cue_back))
	assert(is_equal_approx(cue_tip, 0.6))
	assert(is_equal_approx(cue_back, 0.4))
	assert(cue.get_child_count() >= 6)

	for child in cue.get_children():
		assert(child is MeshInstance3D)
		assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	main.queue_free()
	await process_frame
	print("SELFTEST billard_cue_v30=OK")
	quit()
