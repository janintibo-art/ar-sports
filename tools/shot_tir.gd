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
	main.start_game("tir")
	await process_frame
	var tir = main.game
	tir.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	await _snap("110_tir_choix")
	tir.start_discipline("carabine")
	await process_frame
	var game = tir._child
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game.show_setup()
	await _snap("111_carabine_reglages")
	game._close_panel()
	game._st_bot = true
	game.settings["mode"] = "ordi"
	game._apply_layout()
	game.start_match()
	for i in 90 * 12:
		await physics_frame
	_cam(main, Vector3(0, 1.6, 0.3), Vector3(0, 1.3, -10))
	await _snap("112_carabine_vue")
	_cam(main, Vector3(0.3, 1.45, -4), Vector3(0, 1.3, -10))
	await _snap("113_carabine_cible")
	game.settings["mode"] = "gallery"
	game._apply_layout()
	game._gallery_time = 30.0
	game.start_match()
	for i in 90 * 6:
		await physics_frame
	_cam(main, Vector3(0, 1.6, 0.3), Vector3(0, 1.4, -8))
	await _snap("114_stand_vue")
	_cam(main, Vector3(0.3, 1.5, -3), Vector3(0, 1.4, -8))
	await _snap("115_stand_proche")
	quit()
