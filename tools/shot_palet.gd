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
	main.start_game("palet")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game._open_panel()
	await _snap("70_palet_reglages")
	game._close_panel()
	for vv in ["breton", "trous", "cible"]:
		game.settings["variant"] = vv
		game.settings["points"] = int(game.VARIANTS[vv]["default"])
		game._clear_balls()
		game._st_bot = true
		game.start_match()
		for i in 90 * 9:
			await physics_frame
		_cam(main, Vector3(0, 1.65, 0.3), Vector3(0, 0.3, -5.0))
		await _snap("71_palet_%s_vue" % vv)
		_cam(main, Vector3(0.0, 1.3, -3.3), Vector3(0, 0.0, -5.0))
		await _snap("72_palet_%s_pres" % vv)
	game._st_bot = false
	game.settings["variant"] = "breton"
	game.start_match()
	for i in 60:
		await physics_frame
	_cam(main, Vector3(0.3, 1.5, 0.2), Vector3(0.38, 1.0, -0.2))
	await _snap("73_palet_support")
	_cam(main, Vector3(2.4, 1.6, -0.5), Vector3(0.3, 1.2, -3.0))
	await _snap("74_palet_tableau")
	_cam(main, Vector3(0, 1.7, 0.4), Vector3(0, 1.2, -5.5))
	await _snap("75_palet_decor")
	quit()
