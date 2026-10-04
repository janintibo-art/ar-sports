extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("babyfoot")
	await process_frame
	await process_frame
	await process_frame

	var game = main.game
	assert(game != null)
	assert(game.has_meta("babyfoot_field_v45"))

	var table = game.get("_table")
	assert(is_instance_valid(table))
	var art = table.get_node_or_null("FieldArtV45")
	assert(is_instance_valid(art))
	assert(art.get_child_count() == 15)

	# Les dimensions et constantes physiques doivent rester inchangées.
	assert(is_equal_approx(float(game.get("L")), 1.2))
	assert(is_equal_approx(float(game.get("W")), 0.68))
	assert(is_equal_approx(float(game.get("GOAL_W")), 0.22))
	assert(is_equal_approx(float(game.get("BR")), 0.017))
	assert(is_equal_approx(float(game.get("BODY_R")), 0.015))
	assert(is_equal_approx(float(game.get("FR")), 0.018))

	assert(is_equal_approx(float(game.get_meta("babyfoot_field_v45_l")), 1.2))
	assert(is_equal_approx(float(game.get_meta("babyfoot_field_v45_w")), 0.68))
	assert(int(game.get_meta("babyfoot_field_v45_children")) == 15)

	main.queue_free()
	await process_frame
	print("SELFTEST babyfoot_field_v45=OK")
	quit()
