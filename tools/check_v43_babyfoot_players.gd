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
	await process_frame

	var game = main.game
	assert(game != null)
	assert(game.has_meta("babyfoot_player_detail_v43"))

	# La physique reste strictement identique.
	assert(is_equal_approx(float(game.get("BR")), 0.017))
	assert(is_equal_approx(float(game.get("BODY_R")), 0.021))
	assert(is_equal_approx(float(game.get("FR")), 0.018))

	var rods = game.get("_rods")
	assert(rods.size() == 8)

	var count := 0
	for r in rods:
		assert(is_instance_valid(r.pivot))
		for man in r.pivot.get_children():
			var details = man.get_node_or_null("PlayerDetailV43")
			assert(is_instance_valid(details))
			assert(details.get_child_count() == 5)
			count += 1

	assert(count == 22)
	assert(int(game.get_meta("babyfoot_player_detail_v43_count")) == 22)

	main.queue_free()
	await process_frame
	print("SELFTEST babyfoot_player_detail_v43=OK")
	quit()
