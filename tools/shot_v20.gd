extends SceneTree
## Captures de contrôle : lancer sous un serveur X avec -- <dossier>.
var out := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	_run.call_deferred()

func _snap(name: String) -> void:
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _run() -> void:
	root.size = Vector2i(1280, 1024)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	VisualStyle.set_detailed(true, false)
	main.camera.position = Vector3(0, 1.6, 0)
	main.camera.rotation = Vector3.ZERO
	main.camera.fov = 78
	main.menu.place_in_front_of(main.camera.global_transform)
	main.menu.skip_intro()
	main.set_process(false)
	main.menu.update_hover([main.menu._panels[3]])
	await _snap("menu_v20")
	main.start_game("bowling")
	await process_frame
	main.game._close_panel()
	var s = main.game._spectators[0]
	s.rotation.y = 0
	main.camera.global_position = s.global_position + Vector3(0.1, 1.7, 1.0)
	main.camera.look_at(s.global_position + Vector3(0, 1.6, 0))
	main.camera.fov = 60
	s.react("strike")
	await _snap("personnage_v20")
	main.game._sign.celebrate("strike")
	main.camera.global_position = main.game._sign.global_position + Vector3(0, 0, 2.0)
	main.camera.look_at(main.game._sign.global_position)
	main.camera.fov = 65
	for i in 20:
		await process_frame
	await _snap("reussite_v20")
	main.queue_free()
	await process_frame
	quit()
