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
	var table = game.get("_table")
	assert(is_instance_valid(table))
	assert(table.has_meta("table_art_v36"))

	var deco = table.get_node_or_null("TableArtV36")
	assert(is_instance_valid(deco))
	assert(deco.get_child_count() >= 15)

	# Les constantes physiques/dimensions utiles restent inchangées.
	assert(is_equal_approx(float(game.get("PX")), 0.95))
	assert(is_equal_approx(float(game.get("PZ")), 0.475))
	assert(is_equal_approx(float(game.get("TABLE_Y")), 0.80))
	assert(is_equal_approx(float(table.get_meta("table_art_v36_px")), float(game.get("PX"))))
	assert(is_equal_approx(float(table.get_meta("table_art_v36_pz")), float(game.get("PZ"))))

	main.queue_free()
	await process_frame
	print("SELFTEST billard_table_v36=OK")
	quit()
