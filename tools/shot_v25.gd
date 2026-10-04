extends SceneTree
var out := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.menu.visible = false
	main.menu.set_active(false)
	main.left_hand.visible = false
	main.right_hand.visible = false
	main.camera.position = Vector3(1.35, 1.8, -1.15)
	main.camera.look_at(Vector3(0, 1.48, -1.18))
	main.camera.fov = 42
	for item in [[false, true, "carabine_v25"], [true, true, "balltrap_v25"], [false, false, "carabine_legere_v25"]]:
		var art := GunArt.build(item[0], item[1])
		main.add_child(art)
		art.position = Vector3(0, 1.5, -1)
		for i in 8: await process_frame
		root.get_texture().get_image().save_png(out.path_join(item[2] + ".png"))
		main.remove_child(art)
		art.queue_free()
	main.queue_free()
	await process_frame
	quit()
