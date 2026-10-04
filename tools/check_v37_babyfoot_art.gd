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
	assert(game.has_meta("babyfoot_art_v37"))

	# Les constantes de gameplay doivent rester identiques.
	assert(is_equal_approx(float(game.get("L")), 1.2))
	assert(is_equal_approx(float(game.get("W")), 0.68))
	assert(is_equal_approx(float(game.get("GOAL_W")), 0.22))
	assert(is_equal_approx(float(game.get("BR")), 0.017))
	assert(is_equal_approx(float(game.get("TABLE_Y")), 0.85))

	var table = game.get("_table")
	assert(is_instance_valid(table))
	var deco = table.get_node_or_null("BabyfootArtV37")
	assert(is_instance_valid(deco))
	assert(deco.get_child_count() >= 20)

	var rods = game.get("_rods")
	assert(rods.size() == 8)
	for r in rods:
		assert(is_instance_valid(r.node))
		var art = r.node.get_node_or_null("RodArtV37")
		assert(is_instance_valid(art))
		assert(art.get_child_count() == 5)

	assert(int(game.get_meta("babyfoot_art_v37_rods")) == 8)

	main.queue_free()
	await process_frame
	print("SELFTEST babyfoot_art_v37=OK")
	quit()
