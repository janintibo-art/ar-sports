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
	var game = null
	main.start_game("billard")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game._open_panel()
	await _snap("80_billard_reglages")
	game._close_panel()
	game.settings["variant"] = "8"
	game._rack_balls()
	_cam(main, Vector3(0, 1.65, 0.2), Vector3(0, 0.7, -1.25))
	await _snap("81_billard_depart")
	_cam(main, Vector3(0.0, 1.9, -0.7), Vector3(0, 0.8, -1.25))
	await _snap("82_billard_dessus")
	game._st_bot = true
	game.start_match()
	for i in 90 * 9:
		await physics_frame
	_cam(main, Vector3(0, 1.65, 0.2), Vector3(0, 0.7, -1.25))
	await _snap("83_billard_partie")
	_cam(main, Vector3(1.3, 1.5, -0.2), Vector3(0.0, 0.8, -1.4))
	await _snap("84_billard_cote")
	_cam(main, Vector3(2.0, 1.6, -0.3), Vector3(0.3, 1.2, -2.0))
	await _snap("85_billard_tableau")
	_cam(main, Vector3(0, 1.6, 0.3), Vector3(0, 1.4, -3.0))
	await _snap("86_billard_decor")
	quit()
