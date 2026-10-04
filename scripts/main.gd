extends Node3D
## Point d'entrée : démarre OpenXR, active le passthrough (réalité augmentée),
## crée les mains, le sol invisible et le menu, puis lance les jeux.

const GAMES := {
	"bowling": preload("res://scripts/bowling.gd"),
	"flechettes": preload("res://scripts/darts.gd"),
	"pingpong": preload("res://scripts/pingpong.gd"),
}

var xr_interface: XRInterface
var passthrough := false
var origin: XROrigin3D
var camera: XRCamera3D
var left_hand: Hand
var right_hand: Hand
var menu: GameMenu
var game = null
var environment: Environment
var _selftest := false
var _placed_once := false
var _switcher: UiPanel
var _switcher_open := false
var _switcher_lasers := [false, false]
var _current_id := ""
var _intro_done := false
var _xr_ok := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest = args.has("--selftest") or args.has("--selftest-darts") or args.has("--selftest-pingpong")
	_build_world()
	_start_xr()
	menu = GameMenu.new()
	menu.game_chosen.connect(start_game)
	add_child(menu)
	_switcher = UiPanel.new()
	_switcher.pressed.connect(_on_switcher_pressed)
	add_child(_switcher)
	_switcher.visible = false
	if _selftest:
		print("SELFTEST démarrage")
		_run_selftests("darts" if args.has("--selftest-darts") else ("pingpong" if args.has("--selftest-pingpong") else ""))
	else:
		show_menu()


## Auto-test : bowling, fléchettes, puis navigation entre les jeux. Quitte avec 1 en cas d'échec.
func _run_selftests(only: String) -> void:
	if only == "":
		start_game("bowling")
		game.enable_selftest()
		await game.selftest_finished
	if only in ["", "darts"]:
		start_game("flechettes")
		game.enable_selftest()
		var darts_ok: bool = await game.selftest_finished
		if not darts_ok:
			get_tree().quit(1)
			return
	if only in ["", "pingpong"]:
		start_game("pingpong")
		game.enable_selftest()
		var pp_ok: bool = await game.selftest_finished
		if not pp_ok:
			get_tree().quit(1)
			return
	if only != "":
		get_tree().quit(0)
		return
	var nav_ok := await _selftest_nav()
	print("SELFTEST nav=", "OK" if nav_ok else "ECHEC")
	get_tree().quit(0 if nav_ok else 1)


func _selftest_nav() -> bool:
	var ok := true
	start_game("bowling")
	await get_tree().process_frame
	open_switcher()
	ok = ok and _switcher_open
	_on_switcher_pressed("game_flechettes")
	await get_tree().process_frame
	ok = ok and game is DartsGame and _current_id == "flechettes" and not _switcher_open
	open_switcher()
	_on_switcher_pressed("game_petanque")
	ok = ok and _switcher_open
	_on_switcher_pressed("close")
	ok = ok and not _switcher_open
	open_switcher()
	_on_switcher_pressed("menu")
	await get_tree().process_frame
	ok = ok and game == null and menu.visible
	menu.set_active(true)
	menu.skip_intro()
	menu.click(menu._panels[0])
	await get_tree().process_frame
	ok = ok and game is BowlingGame
	return ok


func _build_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.25, 0.27, 0.3)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.6
	# Ciel invisible (passthrough) mais utilisé pour les reflets : boule et quilles brillent.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.6, 0.75)
	sky_mat.sky_horizon_color = Color(0.9, 0.85, 0.8)
	sky_mat.ground_bottom_color = Color(0.25, 0.2, 0.18)
	sky_mat.ground_horizon_color = Color(0.6, 0.55, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	add_child(sun)

	# Sol réel : un plan infini à y = 0 (référence « stage » du Quest).
	var floor_body := StaticBody3D.new()
	floor_body.name = "Sol"
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	var floor_mat := PhysicsMaterial.new()
	floor_mat.friction = 0.3
	floor_body.physics_material_override = floor_mat
	add_child(floor_body)

	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.near = 0.05
	camera.far = 50.0
	origin.add_child(camera)

	left_hand = Hand.new(&"left_hand")
	right_hand = Hand.new(&"right_hand")
	left_hand.position = Vector3(-0.25, 1.1, -0.3)
	right_hand.position = Vector3(0.25, 1.1, -0.3)
	for hand in [left_hand, right_hand]:
		origin.add_child(hand)
		hand.button_pressed.connect(_on_button_pressed.bind(hand))
		hand.button_released.connect(_on_button_released.bind(hand))


func _start_xr() -> void:
	if _selftest:
		return
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or not xr_interface.is_initialized():
		push_warning("OpenXR indisponible : mode écran.")
		return
	var vp := get_viewport()
	vp.use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_xr_ok = true
	xr_interface.session_begun.connect(_on_session_begun)
	xr_interface.pose_recentered.connect(_on_pose_recentered)


func _on_session_begun() -> void:
	_set_passthrough(true)
	# Fréquence d'affichage : 90 Hz si possible, physique calée dessus.
	var rates: Array = xr_interface.get_available_display_refresh_rates()
	if rates.has(90.0):
		xr_interface.display_refresh_rate = 90.0
	var rate: float = xr_interface.display_refresh_rate
	if rate > 0.0:
		Engine.physics_ticks_per_second = int(roundf(rate))
	# La tête n'est connue qu'une fois la session lancée.
	await get_tree().create_timer(0.3).timeout
	_place_current()
	if game == null:
		_start_intro_if_needed()


func _on_pose_recentered() -> void:
	_place_current()


func _set_passthrough(enable: bool) -> void:
	var modes: Array = xr_interface.get_supported_environment_blend_modes()
	if enable and XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		get_viewport().transparent_bg = true
		environment.background_color = Color(0, 0, 0, 0)
		passthrough = true
	else:
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		get_viewport().transparent_bg = false
		environment.background_color = Color(0.25, 0.27, 0.3)
		passthrough = false


# ---------------------------------------------------------------- navigation

func show_menu() -> void:
	close_switcher()
	if game:
		game.queue_free()
		game = null
	_current_id = ""
	menu.visible = true
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	if _intro_done:
		menu.skip_intro()
	elif not _xr_ok:
		_start_intro_if_needed()
	menu.set_active(true)
	left_hand.laser_enabled = true
	right_hand.laser_enabled = true
	_place_current()


## Le logo n'apparaît en grand qu'au tout premier affichage du menu.
func _start_intro_if_needed() -> void:
	if _intro_done:
		return
	_intro_done = true
	menu.play_intro()


func start_game(game_id: String) -> void:
	if game_id == "quit":
		quit_app()
		return
	if not GAMES.has(game_id):
		return
	close_switcher()
	_intro_done = true
	_current_id = game_id
	menu.visible = false
	menu.set_active(false)
	menu.update_hover([])
	left_hand.laser_enabled = false
	right_hand.laser_enabled = false
	if game:
		game.queue_free()
	game = GAMES[game_id].new()
	if game.has_method("set_hands"):
		game.set_hands(left_hand, right_hand)
	game.exit_requested.connect(show_menu)
	if game.has_signal("switch_requested"):
		game.switch_requested.connect(open_switcher)
	add_child(game)
	_place_current()


func _place_current() -> void:
	var head := camera.global_transform
	if _switcher_open:
		_switcher.place_in_front_of(head, 0.7)
	if game:
		game.place_in_front_of(head)
	else:
		menu.place_in_front_of(head)


# ---------------------------------------------------------------- changer de jeu

## Panneau « Changer de jeu » : bouton Menu de la manette gauche, ou depuis une pause.
func open_switcher(message: String = "") -> void:
	if game == null:
		return
	if not _switcher_open:
		_switcher_lasers = [left_hand.laser_enabled, right_hand.laser_enabled]
		if game.has_method("suspend_panel"):
			game.suspend_panel()
	_switcher.clear()
	_switcher.set_title("Changer de jeu", message if message != "" else "Le jeu en cours sera quitté")
	var rows: Array = [[], []]
	for i in GameMenu.GAMES.size():
		var g: Dictionary = GameMenu.GAMES[i]
		var ready: bool = g["ready"]
		var item := {
			"id": "game_" + String(g["id"]),
			"text": String(g["title"]) + ("" if ready else " (bientôt)"),
			"width": 0.32,
			"selected": g["id"] == _current_id,
			"color": (g["color"] as Color).darkened(0.25) if ready else Color(0.22, 0.23, 0.28),
		}
		rows[i / 2].append(item)
	_switcher.add_row("", rows[0])
	_switcher.add_row("", rows[1])
	_switcher.add_row("", [
		{"id": "menu", "text": "Menu principal", "width": 0.3, "color": Color(0.35, 0.35, 0.4)},
		{"id": "quit", "text": "Quitter", "width": 0.2, "color": Color(0.6, 0.2, 0.2)},
		{"id": "close", "text": "Fermer", "width": 0.2, "color": Color(0.15, 0.55, 0.3)},
	])
	_switcher.build()
	_switcher.show_panel()
	_switcher.place_in_front_of(camera.global_transform, 0.7)
	_switcher_open = true
	left_hand.laser_enabled = true
	right_hand.laser_enabled = true


func close_switcher() -> void:
	if not _switcher_open:
		return
	_switcher_open = false
	_switcher.hide_panel()
	if game and game.has_method("resume_panel"):
		game.resume_panel()
	left_hand.laser_enabled = _switcher_lasers[0]
	right_hand.laser_enabled = _switcher_lasers[1]


func _on_switcher_pressed(id: String) -> void:
	match id:
		"close":
			close_switcher()
		"menu":
			show_menu()
		"quit":
			quit_app()
		_:
			if id.begins_with("game_"):
				var gid := id.substr(5)
				if gid == _current_id:
					close_switcher()
				elif GAMES.has(gid):
					start_game(gid)
				else:
					var title := gid
					for g in GameMenu.GAMES:
						if g["id"] == gid:
							title = g["title"]
					open_switcher("%s arrive bientôt !" % title)


# ---------------------------------------------------------------- entrées

func _process(_delta: float) -> void:
	if _switcher_open:
		_switcher.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])
	if game == null and menu.visible:
		menu.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])


func _on_button_pressed(button: String, hand: Hand) -> void:
	# Bouton Menu de la manette gauche : panneau « Changer de jeu », ou quitter depuis le menu.
	if button == "menu_button":
		if _switcher_open:
			close_switcher()
		elif game:
			open_switcher()
		else:
			quit_app()
		return
	if _switcher_open:
		if button == "trigger_click":
			var pick := hand.pointed_object()
			if pick:
				hand.buzz(0.3, 0.05)
				_switcher.click(pick)
		return
	if game:
		game.on_button_pressed(hand, button)
		return
	if button == "trigger_click":
		var target := hand.pointed_object()
		if target:
			hand.buzz(0.3, 0.05)
			menu.click(target)
	elif button == "ax_button":
		_place_current()


func _on_button_released(button: String, hand: Hand) -> void:
	if game:
		game.on_button_released(hand, button)


func quit_app() -> void:
	if xr_interface and xr_interface.is_initialized():
		xr_interface.uninitialize()
	get_tree().quit()
