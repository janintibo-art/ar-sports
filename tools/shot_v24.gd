extends SceneTree
var out := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	_run.call_deferred()

func _snap(name: String) -> void:
	for i in 5: await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _run() -> void:
	root.size = Vector2i(1280, 1024)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	VisualStyle.set_comfort(1.0, 1.0, false)
	main.camera.position = Vector3(0, 1.6, 0)
	main.camera.rotation = Vector3.ZERO
	main.camera.fov = 78
	main.menu.place_in_front_of(main.camera.global_transform)
	main.menu.skip_intro()
	main.open_comfort()
	main._on_comfort_pressed("tab_audio")
	await _snap("audio_v24")
	main.queue_free()
	await process_frame
	quit()
