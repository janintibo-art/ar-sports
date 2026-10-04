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

	var game = main.game
	assert(game != null)
	assert(game.has_meta("babyfoot_players_v41"))
	assert(game.has_meta("babyfoot_ball_v41"))

	# La physique reste inchangée.
	assert(is_equal_approx(float(game.get("BR")), 0.017))

	var rods = game.get("_rods")
	assert(rods.size() == 8)
	var player_count := 0
	for r in rods:
		assert(is_instance_valid(r.pivot))
		for man in r.pivot.get_children():
			var art = man.get_node_or_null("PlayerArtV41")
			assert(is_instance_valid(art))
			assert(art.get_child_count() >= 7)
			player_count += 1

	assert(player_count == 22)
	assert(int(game.get_meta("babyfoot_players_v41_count")) == 22)

	var ball = game.get("_ball_node")
	assert(is_instance_valid(ball))
	var ball_art = ball.get_node_or_null("BallArtV41")
	assert(is_instance_valid(ball_art))
	assert(ball_art.get_child_count() == 6)
	assert(int(game.get_meta("babyfoot_ball_v41_patches")) == 6)

	main.queue_free()
	await process_frame
	print("SELFTEST babyfoot_players_v41=OK")
	quit()
