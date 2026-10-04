extends SceneTree
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.skip_intro()
	var original := [VisualStyle.ui_scale, VisualStyle.distance_factor, VisualStyle.throw_gain, VisualStyle.cue_gain, VisualStyle.rod_gain, VisualStyle.detailed]
	main.open_comfort()
	main._on_comfort_pressed("tab_guide")
	assert(main._comfort_tab == "guide" and main._guide_page == 0)
	assert(not main.menu.visible)
	assert(QuickGuide.PAGES.size() == 13)
	var seen := {}
	for i in QuickGuide.PAGES.size():
		var page: Dictionary = QuickGuide.PAGES[i]
		assert(not seen.has(page["title"]))
		seen[page["title"]] = true
		assert(main._guide_page == i)
		assert(main._comfort._title.contains(page["title"]))
		assert(main._comfort._buttons.size() == 7)
		var labels := 0
		for child in main._comfort._root.get_children():
			if child is Label3D and child.text == page["text"]:
				labels += 1
				assert(child.vertical_alignment == VERTICAL_ALIGNMENT_TOP)
				var font := ThemeDB.fallback_font
				for line in String(page["text"]).split("\n"):
					assert(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, child.font_size).x * child.pixel_size <= 0.83)
				assert(child.position.y < main._comfort._buttons[0].position.y - 0.04)
				assert(child.position.y - 0.26 > main._comfort._buttons[4].position.y + 0.04)
		assert(labels == 1)
		for button in main._comfort._buttons:
			assert(button.collision_layer == 2)
			assert(button.get_meta("ui_id") != "reset")
		main._on_comfort_pressed("guide_next")
	assert(main._guide_page == 0)
	main._on_comfort_pressed("guide_previous")
	assert(main._guide_page == 12)
	main._on_comfort_pressed("tab_menus")
	main._on_comfort_pressed("tab_gestures")
	main._on_comfort_pressed("tab_guide")
	assert(main._guide_page == 12)
	assert(original == [VisualStyle.ui_scale, VisualStyle.distance_factor, VisualStyle.throw_gain, VisualStyle.cue_gain, VisualStyle.rod_gain, VisualStyle.detailed])
	main._on_comfort_pressed("close")
	assert(main.menu.visible and not main._comfort.visible)
	for button in main._comfort._buttons:
		assert(button.collision_layer == 0)
	main.start_game("bowling")
	main.open_comfort()
	assert(not main._comfort_open)
	main.show_menu()
	main.queue_free()
	await process_frame
	print("SELFTEST guide_v23=OK")
	quit()
