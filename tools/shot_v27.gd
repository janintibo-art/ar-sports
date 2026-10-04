extends SceneTree
var out := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	_run.call_deferred()

func _snap(name: String) -> void:
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _run() -> void:
	root.size = Vector2i(1024, 1024)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.menu.visible = false
	main.menu.set_active(false)
	main.left_hand.visible = false
	main.right_hand.visible = false
	main.camera.position = Vector3(1.5, 1.9, -1)
	main.camera.look_at(Vector3(0, 1.5, -1))
	main.camera.fov = 50
	var dart := Dart.new()
	dart.flight_color = Color(0.12, 0.65, 0.9)
	main.add_child(dart)
	dart.position = Vector3(0, 1.5, -1)
	dart.scale = Vector3.ONE * 5
	await _snap("flechette_v27")
	main.remove_child(dart)
	dart.queue_free()
	var board := Dartboard.new()
	main.add_child(board)
	board.position = Vector3(0, 1.5, -1)
	main.camera.position = Vector3(0, 1.5, 0.4)
	main.camera.look_at(board.position)
	main.camera.fov = 42
	await _snap("cible_flechettes_v27")
	main.queue_free()
	await process_frame
	quit()
