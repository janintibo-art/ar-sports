extends SceneTree
## Régressions v18 : intro, taille des textes, panneaux, ombres et navigation.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.show_intro_at(3.3)
	assert(main.menu.intro_running(), "Intro arrêtée avant la dernière carte")
	assert(not main.menu.click(main.menu._panels[0]), "Carte cliquable pendant l'intro")
	main.menu.skip_intro()
	assert(main.menu._panels[-1].visible and main.menu._panels[-1].scale.x > 0.99)
	var label := BowlingArt.label("arc · carabine · ball-trap · couteau", 0.036)
	BowlingArt.fit_label(label, 0.26)
	assert(label.pixel_size * ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x <= 0.261)
	label.free()
	var panel = load("res://scripts/ui_panel.gd").new()
	main.add_child(panel)
	panel.set_title("Réglages")
	panel.add_row("", [{"id": "a", "text": "Une option", "width": 0.2}])
	panel.build()
	var old = panel._buttons[0]
	panel.build()
	assert(not old.is_inside_tree(), "Ancien bouton encore actif après reconstruction")
	panel.hide_panel()
	assert(panel._buttons[0].collision_layer == 0)
	panel.queue_free()
	var tree := Decor.tree()
	tree.position = Vector3(2, 0, -3)
	main.add_child(tree)
	var shadow = tree.get_child(tree.get_child_count() - 1)
	assert(not shadow.top_level and absf(shadow.global_position.x - 2.0) < 0.001)
	tree.queue_free()
	main.start_game("bowling")
	var previous = main.game
	main.start_game("pingpong")
	assert(not previous.is_inside_tree(), "Ancien jeu encore présent")
	main.game._close_panel()
	assert(not main.left_hand.laser_enabled)
	await process_frame
	assert(not main.left_hand.laser_enabled, "Ancien jeu a réactivé le laser")
	main.show_menu()
	assert(main.menu.process_mode == Node.PROCESS_MODE_INHERIT)
	main.queue_free()
	await process_frame
	print("SELFTEST visual_ui=OK")
	quit(0)
