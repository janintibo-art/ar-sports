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
	for t in [0.4, 1.2, 2.4, 2.8]:
		main.menu.show_intro_at(t)
		await _snap("00_intro_%02d" % int(t * 10))
	main.menu.skip_intro()
	await _snap("01_menu")
	main.menu.update_hover([main.menu._panels[1]])
	await _snap("01b_menu_survol")
	main.menu.update_hover([])
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
	game._scoreboard.announce("STRIKE !", Color(1, 0.8, 0.1), 30.0, true)
	game._sign.celebrate("strike")
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0, 1.6, -2.0), Vector3(0, 1.8, -5.8))
	await _snap("09_tableau_strike")
	_cam(main, Vector3(0, 1.5, -3.5), Vector3(0, 1.8, -5.8))
	await _snap("10_tableau_proche")
	game.settings["players"] = 1
	game.start_match()
	for i in 30:
		await physics_frame
	_cam(main, Vector3(0, 1.6, -2.0), Vector3(0, 1.8, -5.8))
	await _snap("11_tableau_1joueur")
	game.settings["players"] = 4
	game.start_match()
	for i in 30:
		await physics_frame
	await _snap("12_tableau_4joueurs")
	# un lancer pour voir l'impact
	game._launch(game.to_global(Vector3(0.02, 0.13, -0.6)), game.global_basis * Vector3(0.0, 0, -7.0))
	for i in 55:
		await physics_frame
	_cam(main, Vector3(0.9, 1.0, -3.2), Vector3(0, 0.2, -4.6))
	await _snap("08_impact")
	# ---- fléchettes
	main.start_game("flechettes")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game._open_panel()
	await _snap("20_darts_reglages")
	main.open_switcher()
	await _snap("30_changer_de_jeu")
	main.close_switcher()
	game._close_panel()
	game.settings["players"] = 2
	game.settings["mode"] = "501"
	game.settings["level"] = "normal"
	game._assist_override = 0.0
	game.start_match()
	for i in 30:
		await physics_frame
	_cam(main, Vector3(0.1, 1.6, 0.5), Vector3(-0.2, 1.3, -2.0))
	await _snap("21_darts_vue")
	await game._st_throw(20, 3)
	await game._st_throw(19, 2)
	await game._st_throw(25, 2)
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0.1, 1.6, 0.5), Vector3(-0.2, 1.3, -2.0))
	await _snap("22_darts_impacts")
	_cam(main, Vector3(0, 1.5, -0.6), Vector3(0, 1.5, -2.0))
	await _snap("23_darts_cible")
	_cam(main, Vector3(-0.3, 1.5, 0.0), Vector3(-1.0, 1.5, -2.0))
	await _snap("24_darts_tableau")
	for i in 150:
		await physics_frame
	_cam(main, Vector3(0.3, 1.6, 0.4), Vector3(0.3, 1.0, -0.2))
	await _snap("25_darts_porte")
	# ---- ping-pong
	main.start_game("pingpong")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game._open_panel()
	await _snap("40_pp_reglages")
	game._close_panel()
	game.settings["level"] = "normal"
	game.start_match()
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0, 1.65, 0.3), Vector3(0, 0.9, -2.2))
	await _snap("41_pp_vue")
	_cam(main, Vector3(0.9, 1.5, -0.2), Vector3(0, 0.9, -2.6))
	await _snap("42_pp_cote")
	game._toss()
	game._st_bot = true
	for i in 100:
		await physics_frame
	_cam(main, Vector3(0, 1.65, 0.3), Vector3(0, 0.9, -2.2))
	await _snap("43_pp_echange")
	for i in 160:
		await physics_frame
	_cam(main, Vector3(0.2, 1.7, -2.2), Vector3(0, 1.2, -4.4))
	await _snap("44_pp_adversaire")
	# ---- pétanque
	main.start_game("petanque")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	game._open_panel()
	await _snap("50_pet_reglages")
	game._close_panel()
	game.settings["level"] = "normal"
	game.start_match()
	for i in 30:
		await physics_frame
	_cam(main, Vector3(0, 1.65, 0.3), Vector3(0, 0.6, -5.0))
	await _snap("51_pet_depart")
	_cam(main, Vector3(0.3, 1.5, 0.2), Vector3(0.38, 1.0, -0.2))
	await _snap("52_pet_support")
	game._clear_balls()
	game._st_bot = true
	game.start_match()
	for i in 90 * 14:
		await physics_frame
	_cam(main, Vector3(0, 1.65, 0.3), Vector3(0, 0.3, -7.0))
	await _snap("53_pet_manche")
	var jz: float = game._jack.pos.z if game._jack else -7.0
	_cam(main, Vector3(0.3, 0.9, jz + 1.8), Vector3(0, 0.05, jz))
	await _snap("54_pet_pres")
	_cam(main, Vector3(2.4, 1.6, -0.5), Vector3(0.3, 1.2, -3.0))
	await _snap("55_pet_tableau")
	_cam(main, Vector3(0, 1.7, 0.4), Vector3(0, 1.2, -5.5))
	await _snap("56_pet_decor")
	_cam(main, Vector3(1.6, 1.6, -9.0), Vector3(0, 1.3, -12.5))
	await _snap("57_pet_fond")
	game._st_bot = false
	game.show_pause()
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	await _snap("58_pet_pause")
	game._close_panel()
	main.start_game("pingpong")
	game = main.game
	await process_frame
	game.place_in_front_of(Transform3D(Basis(), Vector3(0, 1.6, 0)))
	game._close_panel()
	game.start_match()
	for i in 20:
		await physics_frame
	_cam(main, Vector3(0, 1.8, 1.0), Vector3(0, 0.8, -2.3))
	await _snap("59_pp_decor")
	_cam(main, Vector3(0, 1.6, 0), Vector3(0, 1.4, -1))
	main.open_switcher()
	await _snap("60_switcher")
	quit()
