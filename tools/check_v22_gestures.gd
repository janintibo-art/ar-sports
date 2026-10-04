extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var existed := FileAccess.file_exists(VisualStyle.SAVE_PATH)
	var bytes := FileAccess.get_file_as_bytes(VisualStyle.SAVE_PATH) if existed else PackedByteArray()
	var original := [VisualStyle.detailed, VisualStyle.ui_scale, VisualStyle.distance_factor, VisualStyle.throw_gain, VisualStyle.cue_gain, VisualStyle.rod_gain]
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.skip_intro()
	main.open_comfort()
	main._on_comfort_pressed("tab_gestures")
	assert(main._comfort_tab == "gestures")
	main._on_comfort_pressed("throw_1.2")
	main._on_comfort_pressed("cue_1.25")
	main._on_comfort_pressed("rod_0.75")
	VisualStyle.set_comfort(1.15, 1.25)
	VisualStyle.set_detailed(false)
	VisualStyle.load_preferences()
	assert(is_equal_approx(VisualStyle.throw_gain, 1.2) and is_equal_approx(VisualStyle.cue_gain, 1.25) and is_equal_approx(VisualStyle.rod_gain, 0.75))
	assert(is_equal_approx(VisualStyle.ui_scale, 1.15) and not VisualStyle.detailed)
	main.right_hand._history.assign([{"t": 0.0, "p": Vector3.ZERO}, {"t": 1.0, "p": Vector3(1, 2, 3)}])
	assert(main.right_hand.throw_velocity().is_equal_approx(Vector3(1, 2, 3) * 1.2))
	VisualStyle.set_gestures(0.8, 1.0, 1.0, false)
	assert(main.right_hand.throw_velocity().is_equal_approx(Vector3(1, 2, 3) * 0.8))
	main.close_comfort()
	main.start_game("billard")
	var billiard = main.game
	var speeds: Array[float] = []
	for gain in [0.75, 1.0, 1.25]:
		VisualStyle.set_gestures(1.0, gain, 1.0, false)
		billiard.start_match()
		billiard.state = billiard.State.AIM
		var position: Vector3 = billiard._w(billiard._cue_ball.pos)
		assert(billiard._check_strike(position, Vector3(1.6, 0, 0), Vector3.RIGHT))
		speeds.append(billiard._cue_ball.vel.length())
	assert(speeds[0] < speeds[1] and speeds[1] < speeds[2])
	billiard.start_match()
	billiard.state = billiard.State.AIM
	assert(not billiard._check_strike(billiard._w(billiard._cue_ball.pos), Vector3(0.1, 0, 0), Vector3.RIGHT))
	main.start_game("babyfoot")
	var baby = main.game
	var rod = baby._rods[0]
	rod.theta = 0
	VisualStyle.set_gestures(1.0, 1.0, 0.75, false)
	baby.apply_hand(rod, 0.0, 0.2, 0.01)
	var calm: float = absf(rod.omega)
	VisualStyle.set_gestures(1.0, 1.0, 1.25, false)
	baby.apply_hand(rod, 0.0, 0.2, 0.01)
	assert(absf(rod.omega) > calm)
	baby._apply_sweep(rod, 0.2)
	assert(is_equal_approx(absf(rod.omega), 6.0), "Le bot de test doit garder sa vitesse")
	main.show_menu()
	main.open_comfort()
	main._on_comfort_pressed("tab_gestures")
	main._on_comfort_pressed("reset")
	assert(is_equal_approx(VisualStyle.throw_gain, 1.0) and is_equal_approx(VisualStyle.cue_gain, 1.0) and is_equal_approx(VisualStyle.rod_gain, 1.0))
	assert(is_equal_approx(VisualStyle.ui_scale, 1.15), "Reset Gestes ne doit pas changer les menus")
	VisualStyle.detailed = original[0]
	VisualStyle.set_comfort(original[1], original[2], false)
	VisualStyle.set_gestures(original[3], original[4], original[5], false)
	if existed:
		var file := FileAccess.open(VisualStyle.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	else:
		DirAccess.remove_absolute(VisualStyle.SAVE_PATH)
	main.queue_free()
	await process_frame
	print("SELFTEST gestures_v22=OK")
	quit(0)
