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
	await _snap("menu_v19")
	main.start_game("bowling")
	await process_frame
	main.game._close_panel()
	var s = main.game._spectators[0]
	s.rotation.y = 0
	main.camera.global_position = s.global_position + Vector3(0.1, 1.7, 1.0)
	main.camera.look_at(s.global_position + Vector3(0, 1.6, 0))
	main.camera.fov = 60
	s.react("strike")
	await _snap("personnage_v19")
	main.start_game("billard")
	await process_frame
	main.game._close_panel()
	main.camera.global_position = Vector3(0, 1.7, 0.7)
	main.camera.look_at(main.game.to_global(Vector3(-0.25, 0.9, main.game.TZ)))
	main.camera.fov = 78
	await _snap("pub_v19")
	main.start_game("petanque")
	await process_frame
	main.game._close_panel()
	main.camera.global_position = Vector3(0, 1.8, -5)
	main.camera.look_at(main.game.to_global(Vector3(0, 1.2, -main.game.tlen)))
	await _snap("village_v19")
	main.queue_free()
	await process_frame
	quit()
