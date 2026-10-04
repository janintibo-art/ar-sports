extends SceneTree
## Captures d'écran pour vérifier le rendu (hors casque) :
## xvfb-run godot --rendering-driver opengl3 -s tools/shot.gd -- <dossier>

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
	cam.fov = 90


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("capture ", name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	# Faux salon : sol moquette et mur, pour juger le rendu comme en passthrough
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
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.3, -1))
	main.menu.place_in_front_of(main.camera.global_transform)
	await _snap("01_menu")
	main.start_game("bowling")
	var game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	game._open_panel()
	await _snap("02_reglages")
	game.settings["players"] = 3
	game._close_panel()
	game.start_match()
	for i in 90:
		await physics_frame
	_cam(main, Vector3(0, 1.6, 0.2), Vector3(0, 0.6, -3.5))
	await _snap("03_vue_joueur")
	_cam(main, Vector3(-0.6, 1.5, 0.9), Vector3(-1.4, 1.1, -0.2))
	await _snap("04_decor_gauche")
	_cam(main, Vector3(0.3, 1.3, 0.6), Vector3(1.3, 1.2, -0.7))
	await _snap("05_sonia")
	_cam(main, Vector3(0, 0.9, -3.0), Vector3(0, 0.3, -4.6))
	await _snap("06_quilles")
	_cam(main, Vector3(0, 1.6, -2.0), Vector3(0, 1.8, -5.8))
	await _snap("07_tableau")
	# un lancer pour voir l'impact
	game._launch(game.to_global(Vector3(0.02, 0.13, -0.6)), game.global_basis * Vector3(0.0, 0, -7.0))
	for i in 55:
		await physics_frame
	_cam(main, Vector3(0.9, 1.0, -3.2), Vector3(0, 0.2, -4.6))
	await _snap("08_impact")
	quit()
