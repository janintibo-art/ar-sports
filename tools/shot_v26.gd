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
	main.camera.position = Vector3(1.35, 1.7, -0.7)
	main.camera.look_at(Vector3(0, 1.5, -1))
	main.camera.fov = 58
	var bow := RangedArt.bow(true)
	main.add_child(bow)
	bow.position = Vector3(0, 1.5, -1)
	for side in [-1.0, 1.0]:
		var a := Vector3(0, side * 0.62, 0.14)
		var b := Vector3(0, 0, 0.14)
		var string := BowlingArt.box(Vector3(0.003, 0.003, a.distance_to(b)), BowlingArt.unshaded(Color(0.95, 0.95, 0.85)), (a + b) / 2)
		string.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT)
		bow.add_child(string)
	await _snap("arc_v26")
	main.remove_child(bow)
	bow.queue_free()
	main.camera.position = Vector3(1.2, 1.8, -1.0)
	main.camera.look_at(Vector3(0, 1.5, -1))
	main.camera.fov = 58
	var knife := RangedArt.knife(true)
	main.add_child(knife)
	knife.position = Vector3(0, 1.5, -1)
	knife.scale = Vector3.ONE * 3
	await _snap("couteau_v26")
	main.remove_child(knife)
	knife.queue_free()
	var arrow := RangedArt.arrow(0.7, Color(0.25, 0.65, 1), true)
	main.add_child(arrow)
	arrow.position = Vector3(0, 1.5, -1.3)
	await _snap("fleche_v26")
	main.queue_free()
	await process_frame
	quit()
