extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.skip_intro()
	main.menu.set_active(true)
	for i in main.menu.GAMES.size():
		var card = main.menu._panels[i]
		main.menu.update_hover([card])
		assert(main.menu._help_title.text == main.menu.GAMES[i]["title"])
		assert(not main.menu._info.text.is_empty())
		var font: Font = ThemeDB.fallback_font
		for line in main.menu._info.text.split("\n"):
			assert(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * main.menu._info.pixel_size <= 0.841)
	main.menu.update_hover([])
	assert(main.menu._help_title.text == "Choisis un jeu")
	main.menu.show_intro_at(1.0)
	assert(not main.menu._help_bg.visible)
	main.menu.skip_intro()
	assert(main.menu._help_bg.visible)
	var original := VisualStyle.detailed
	var anchor := Node3D.new()
	main.add_child(anchor)
	VisualStyle.set_detailed(true, false)
	var burst := SuccessBurst.play(anchor, true)
	assert(burst._mesh.multimesh.instance_count == 40)
	var next := SuccessBurst.play(anchor, false)
	assert(not burst.is_inside_tree())
	assert(anchor.get_child_count() == 1)
	next._process(0.3)
	assert(next._age > 0.0)
	next._process(1.0)
	await process_frame
	assert(anchor.get_child_count() == 0)
	VisualStyle.set_detailed(false, false)
	var light := SuccessBurst.play(anchor, true)
	assert(light._mesh.multimesh.instance_count == 12)
	anchor.process_mode = Node.PROCESS_MODE_DISABLED
	var age := light._age
	await process_frame
	assert(light._age == age, "L'effet doit se suspendre avec le jeu")
	VisualStyle.set_detailed(original, false)
	main.queue_free()
	await process_frame
	print("SELFTEST feedback_v20=OK")
	quit(0)
