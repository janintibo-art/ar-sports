extends SceneTree
var out := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	_run.call_deferred()

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
	main.camera.position = Vector3(0.15, 1.65, -1.65)
	main.camera.look_at(Vector3(0, 1.46, -1))
	main.camera.fov = 46
	var player := PingArt.paddle(PingPaddle.RADIUS, Color(0.85, 0.12, 0.12), false, true)
	main.add_child(player)
	player.position = Vector3(-0.13, 1.5, -1)
	var ai := PingArt.paddle(PingPaddle.RADIUS, Color(0.2, 0.5, 1), true, true)
	main.add_child(ai)
	ai.position = Vector3(0.13, 1.5, -1)
	var ball := BowlingArt.sphere(0.028, PingArt.ball_material(), Vector3(0, 1.68, -1), 20)
	main.add_child(ball)
	for i in 8: await process_frame
	root.get_texture().get_image().save_png(out.path_join("equipement_pingpong_v28.png"))
	main.queue_free()
	await process_frame
	quit()
