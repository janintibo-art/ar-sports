extends SceneTree
## Captures : xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s tools/shot_grenouille.gd -- <dossier>

var out := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _cam(main: Node, pos: Vector3, look: Vector3) -> void:
	var cam: Camera3D = main.camera
	cam.global_position = pos
	cam.look_at(look)
	cam.fov = 80


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("capture ", name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	var room_floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	room_floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.42, 0.38)
	room_floor.material_override = fm
	room_floor.position.y = -0.002
	main.add_child(room_floor)
	await process_frame
	main.show_menu()
	for i in 400:
		await process_frame
	_cam(main, Vector3(0, 1.4, 0.2), Vector3(0, 1.3, -1.5))
	await _snap("80_menu")
	main.start_game("grenouille")
	await process_frame
	var game = main.game
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.3, -1))
	game._open_panel()
	await _snap("81_reglages")
	game._close_panel()
	game.start_match()
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0.1, 1.6, 0.2), Vector3(0, 0.8, -1.5))
	await _snap("82_bar_vue")
	_cam(main, Vector3(0, 1.3, -0.5), Vector3(0, 0.7, -1.6))
	await _snap("83_meuble")
	_cam(main, Vector3(0.3, 1.5, 0.2), Vector3(0.36, 0.95, -0.2))
	await _snap("84_support")
	game.settings["dist"] = 3.0
	game.start_match()
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0.1, 1.6, 0.3), Vector3(0, 0.8, -3.0))
	await _snap("85_classique")
	main.open_switcher()
	_cam(main, Vector3(0, 1.4, 0.2), Vector3(0, 1.3, -1.5))
	await _snap("86_switcher")
	quit()
