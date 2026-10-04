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
	assert(game is BillardGame)
	var cue: Node3D = game.get("_cue")
	assert(is_instance_valid(cue))
	assert(cue.has_meta("cue_art_v30"))
	assert(is_equal_approx(float(cue.get_meta("cue_tip_distance")), game.CUE_TIP))
	assert(is_equal_approx(float(cue.get_meta("cue_back_distance")), game.CUE_BACK))
	assert(is_equal_approx(float(cue.get_meta("cue_total_length")), game.CUE_TIP + game.CUE_BACK))
	assert(game.CUE_TIP == 0.6)
	assert(game.CUE_BACK == 0.4)
	assert(cue.get_child_count() >= 6)

	for child in cue.get_children():
		assert(child is MeshInstance3D)
		assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	main.queue_free()
	await process_frame
	print("SELFTEST billard_cue_v30=OK")
	quit()
