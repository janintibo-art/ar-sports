extends Node3D
## Point d'entrée : démarre OpenXR, active le passthrough (réalité augmentée),
## crée les mains, le sol invisible et le menu, puis lance les jeux.

const GAMES := {
	"bowling": preload("res://scripts/bowling.gd"),
	"flechettes": preload("res://scripts/darts.gd"),
	"pingpong": preload("res://scripts/pingpong.gd"),
	"petanque": preload("res://scripts/petanque.gd"),
	"molkky": preload("res://scripts/molkky.gd"),
	"palet": preload("res://scripts/palet.gd"),
	"billard": preload("res://scripts/billard.gd"),
	"babyfoot": preload("res://scripts/babyfoot.gd"),
	"tir": preload("res://scripts/tir.gd"),
	"grenouille": preload("res://scripts/grenouille.gd"),
	"basket": preload("res://scripts/basket.gd"),
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
var _comfort: UiPanel
var _comfort_open := false
var _comfort_tab := "menus"
var _guide_page := 0
var _comfort_message := "Taille et distance des menus"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest = args.has("--selftest") or args.has("--selftest-darts") or args.has("--selftest-pingpong") or args.has("--selftest-petanque") or args.has("--selftest-molkky") or args.has("--selftest-palet") or args.has("--selftest-billard") or args.has("--selftest-babyfoot") or args.has("--selftest-tir") or args.has("--selftest-grenouille") or args.has("--selftest-basket")
	if not _selftest:
		VisualStyle.load_preferences()
	Sound.apply_preferences()
	_build_world()
	_start_xr()
	menu = GameMenu.new()
	menu.game_chosen.connect(start_game)
	add_child(menu)
	_switcher = UiPanel.new()
	_switcher.pressed.connect(_on_switcher_pressed)
	add_child(_switcher)
	_switcher.visible = false
	_comfort = UiPanel.new()
	_comfort.accent = Color(0.4, 0.7, 1.0)
	_comfort.pressed.connect(_on_comfort_pressed)
	add_child(_comfort)
	_comfort.hide_panel()
	if _selftest:
		print("SELFTEST démarrage")
		_run_selftests("darts" if args.has("--selftest-darts") else ("pingpong" if args.has("--selftest-pingpong") else ("petanque" if args.has("--selftest-petanque") else ("molkky" if args.has("--selftest-molkky") else ("palet" if args.has("--selftest-palet") else ("billard" if args.has("--selftest-billard") else ("babyfoot" if args.has("--selftest-babyfoot") else ("tir" if args.has("--selftest-tir") else ("grenouille" if args.has("--selftest-grenouille") else ("basket" if args.has("--selftest-basket") else ""))))))))))
	else:
		show_menu()


## Termine un auto-test après avoir laissé Godot vider les suppressions différées.
## Cela évite que `quit()` interrompe la libération du dernier jeu encore affiché.
func _finish_selftest(code: int) -> void:
	close_comfort()
	close_switcher()
	if game:
		if game.get_parent() == self:
			remove_child(game)
		game.queue_free()
		game = null
	_current_id = ""

	# `queue_free()` est traité en fin de frame. Deux frames garantissent aussi
	# la destruction des enfants et de leurs ressources graphiques.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)


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
			await _finish_selftest(1)
			return
	if only in ["", "pingpong"]:
		start_game("pingpong")
		game.enable_selftest()
		var pp_ok: bool = await game.selftest_finished
		if not pp_ok:
			await _finish_selftest(1)
			return
	if only in ["", "petanque"]:
		start_game("petanque")
		game.enable_selftest()
		var pet_ok: bool = await game.selftest_finished
		if not pet_ok:
			await _finish_selftest(1)
			return
	if only in ["", "molkky"]:
		start_game("molkky")
		game.enable_selftest()
		var mol_ok: bool = await game.selftest_finished
		if not mol_ok:
			await _finish_selftest(1)
			return
	if only in ["", "palet"]:
		start_game("palet")
		game.enable_selftest()
		var pal_ok: bool = await game.selftest_finished
		if not pal_ok:
			await _finish_selftest(1)
			return
	if only in ["", "billard"]:
		start_game("billard")
		game.enable_selftest()
		var bil_ok: bool = await game.selftest_finished
		if not bil_ok:
			await _finish_selftest(1)
			return
	if only in ["", "babyfoot"]:
		start_game("babyfoot")
		game.enable_selftest()
		var bf_ok: bool = await game.selftest_finished
		if not bf_ok:
			await _finish_selftest(1)
			return
	if only in ["", "tir"]:
		start_game("tir")
		game.enable_selftest()
		var tir_ok: bool = await game.selftest_finished
		if not tir_ok:
			await _finish_selftest(1)
			return
	if only in ["", "grenouille"]:
		start_game("grenouille")
		game.enable_selftest()
		var gre_ok: bool = await game.selftest_finished
		if not gre_ok:
			await _finish_selftest(1)
			return
	if only in ["", "basket"]:
		start_game("basket")
		game.enable_selftest()
		var bas_ok: bool = await game.selftest_finished
		if not bas_ok:
			await _finish_selftest(1)
			return
	if only != "":
		await _finish_selftest(0)
		return
	var nav_ok := await _selftest_nav()
	print("SELFTEST nav=", "OK" if nav_ok else "ECHEC")
	await _finish_selftest(0 if nav_ok else 1)


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
	await get_tree().process_frame
	ok = ok and game is PetanqueGame and _current_id == "petanque" and not _switcher_open
	open_switcher()
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
	var rates: Array = xr_interface.get_available_display_refresh_rates()
	if rates.has(90.0):
		xr_interface.display_refresh_rate = 90.0
	var rate: float = xr_interface.display_refresh_rate
	if rate > 0.0:
		Engine.physics_ticks_per_second = int(roundf(rate))
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
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


func show_menu() -> void:
	close_comfort()
	close_switcher()
	if game:
		remove_child(game)
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


func _start_intro_if_needed() -> void:
	if _intro_done:
		return
	_intro_done = true
	menu.play_intro()


func start_game(game_id: String) -> void:
	if game_id == "comfort":
		open_comfort()
		return
	close_comfort()
	if game_id == "quit":
		quit_app()
		return
	if not GAMES.has(game_id):
		return
	close_switcher()
	_intro_done = true
	_current_id = game_id
	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.set_active(false)
	menu.update_hover([])
	left_hand.laser_enabled = false
	right_hand.laser_enabled = false
	if game:
		remove_child(game)
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
	if _comfort_open:
		_comfort.place_in_front_of(head, 1.15)
		return
	if _switcher_open:
		_switcher.place_in_front_of(head, 0.7)
	if game:
		game.place_in_front_of(head)
	else:
		menu.place_in_front_of(head)


func open_switcher(message: String = "") -> void:
	if game == null:
		return
	if not _switcher_open:
		_switcher_lasers = [left_hand.laser_enabled, right_hand.laser_enabled]
		if game.has_method("suspend_panel"):
			game.suspend_panel()
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.visible = false
	_switcher.clear()
	_switcher.set_title("Changer de jeu", message if message != "" else "Le jeu en cours sera quitté")
	var rows: Array = [[], [], []]
	for i in GameMenu.GAMES.size():
		var g: Dictionary = GameMenu.GAMES[i]
		var ready: bool = g["ready"]
		var item := {
			"id": "game_" + String(g["id"]),
			"text": String(g["title"]),
			"width": 0.2,
			"selected": g["id"] == _current_id,
			"color": (g["color"] as Color).darkened(0.25) if ready else Color(0.22, 0.23, 0.28),
		}
		rows[i / 4].append(item)
	_switcher.add_row("", rows[0])
	_switcher.add_row("", rows[1])
	_switcher.add_row("", rows[2])
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
	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true
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


func _process(_delta: float) -> void:
	if _comfort_open:
		_comfort.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])
		return
	if _switcher_open:
		_switcher.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])
	if game == null and menu.visible:
		menu.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])


func _on_button_pressed(button: String, hand: Hand) -> void:
	if _comfort_open:
		if button == "menu_button" or button == "by_button":
			close_comfort()
		elif button == "ax_button":
			_place_current()
		elif button == "trigger_click":
			_comfort.click(hand.pointed_object())
		return
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
	if game and not _switcher_open:
		game.on_button_released(hand, button)


func quit_app() -> void:
	if xr_interface and xr_interface.is_initialized():
		xr_interface.uninitialize()
	get_tree().quit()


func open_comfort() -> void:
	if game != null:
		return
	_comfort_open = true
	menu.set_active(false)
	menu.update_hover([])
	menu.visible = false
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	_build_comfort()


func _build_comfort() -> void:
	_comfort.clear()
	_comfort.set_title("Confort", _comfort_message)
	_comfort.add_row("", [
		{"id": "tab_menus", "text": "Menus", "width": 0.17, "selected": _comfort_tab == "menus"},
		{"id": "tab_gestures", "text": "Gestes", "width": 0.17, "selected": _comfort_tab == "gestures"},
		{"id": "tab_audio", "text": "Audio", "width": 0.17, "selected": _comfort_tab == "audio"},
		{"id": "tab_guide", "text": "Guide", "width": 0.17, "selected": _comfort_tab == "guide"},
	])
	if _comfort_tab == "menus":
		var sizes: Array = []
		for value in [1.0, 1.15, 1.3]:
			sizes.append({"id": "size_" + str(value), "text": "%d %%" % roundi(value * 100), "width": 0.19, "selected": is_equal_approx(VisualStyle.ui_scale, value)})
		_comfort.add_row("Taille", sizes)
		var distances: Array = []
		for item in [[0.85, "Proche"], [1.0, "Normal"], [1.25, "Éloigné"]]:
			distances.append({"id": "distance_" + str(item[0]), "text": item[1], "width": 0.19, "selected": is_equal_approx(VisualStyle.distance_factor, item[0])})
		_comfort.add_row("Distance", distances)
	elif _comfort_tab == "gestures":
		_add_gesture_row("Lancers", "throw", VisualStyle.throw_gain, [0.8, 1.0, 1.2], ["Doux", "Normal", "Fort"])
		_add_gesture_row("Billard", "cue", VisualStyle.cue_gain, [0.75, 1.0, 1.25], ["Doux", "Normal", "Fort"])
		_add_gesture_row("Barres", "rod", VisualStyle.rod_gain, [0.75, 1.0, 1.25], ["Calme", "Normal", "Vif"])
	elif _comfort_tab == "audio":
		_add_gesture_row("Général", "master", VisualStyle.master_volume, [0.0, 0.5, 1.0], ["Muet", "50 %", "100 %"])
		_add_gesture_row("Musique", "music", VisualStyle.music_volume, [0.0, 0.5, 1.0], ["Muet", "50 %", "100 %"])
		_add_gesture_row("Effets", "effects", VisualStyle.effects_volume, [0.0, 0.5, 1.0], ["Muet", "50 %", "100 %"])
		_comfort.add_row("", [{"id": "audio_test", "text": "Tester un son", "width": 0.28}])
	else:
		var page: Dictionary = QuickGuide.PAGES[_guide_page]
		_comfort.set_title("Guide · " + String(page["title"]), "%d / %d" % [_guide_page + 1, QuickGuide.PAGES.size()])
		_comfort.add_text(page["text"])
		_comfort.add_row("", [
			{"id": "guide_previous", "text": "Précédent", "width": 0.25},
			{"id": "guide_next", "text": "Suivant", "width": 0.25},
		])
	if _comfort_tab == "guide":
		_comfort.add_row("", [{"id": "close", "text": "Retour au menu", "width": 0.30, "color": Color(0.1, 0.4, 0.35)}])
	else:
		_comfort.add_row("", [{"id": "reset", "text": "Réinitialiser", "width": 0.27}, {"id": "close", "text": "Retour au menu", "width": 0.30, "color": Color(0.1, 0.4, 0.35)}])
	_comfort.build()
	_comfort.show_panel()
	_comfort.place_in_front_of(camera.global_transform, 1.15)


func _add_gesture_row(caption: String, prefix: String, current: float, values: Array, labels: Array) -> void:
	var items: Array = []
	for i in values.size():
		items.append({"id": prefix + "_" + str(values[i]), "text": labels[i], "width": 0.19, "selected": is_equal_approx(current, float(values[i]))})
	_comfort.add_row(caption, items)


func _on_comfort_pressed(id: String) -> void:
	if id == "close":
		close_comfort()
		return
	if id in ["tab_menus", "tab_gestures", "tab_audio", "tab_guide"]:
		_comfort_tab = id.trim_prefix("tab_")
		_comfort_message = {"menus": "Taille et distance des menus", "gestures": "Lancers · queue de billard · baby-foot", "audio": "Effets : bruitages et ambiance"}.get(_comfort_tab, "Commandes des jeux")
		_build_comfort()
		return
	if _comfort_tab == "guide":
		if id == "guide_previous":
			_guide_page = posmod(_guide_page - 1, QuickGuide.PAGES.size())
		elif id == "guide_next":
			_guide_page = (_guide_page + 1) % QuickGuide.PAGES.size()
		else:
			return
		_build_comfort()
		return
	if _comfort_tab == "audio" and id == "audio_test":
		Sound.play("bull_ding", -8.0)
		return
	var result: Error = OK
	if _comfort_tab == "gestures":
		var throwing := VisualStyle.throw_gain
		var cue := VisualStyle.cue_gain
		var rod := VisualStyle.rod_gain
		if id.begins_with("throw_"):
			throwing = id.substr(6).to_float()
		elif id.begins_with("cue_"):
			cue = id.substr(4).to_float()
		elif id.begins_with("rod_"):
			rod = id.substr(4).to_float()
		elif id == "reset":
			throwing = 1.0
			cue = 1.0
			rod = 1.0
		else:
			return
		result = VisualStyle.set_gestures(throwing, cue, rod)
	elif _comfort_tab == "audio":
		var master := VisualStyle.master_volume
		var music := VisualStyle.music_volume
		var effects := VisualStyle.effects_volume
		if id.begins_with("master_"):
			master = id.substr(7).to_float()
		elif id.begins_with("music_"):
			music = id.substr(6).to_float()
		elif id.begins_with("effects_"):
			effects = id.substr(8).to_float()
		elif id == "reset":
			master = 1.0
			music = 1.0
			effects = 1.0
		else:
			return
		result = VisualStyle.set_audio(master, music, effects)
		Sound.apply_preferences()
	else:
		var size := VisualStyle.ui_scale
		var distance := VisualStyle.distance_factor
		if id.begins_with("size_"):
			size = id.substr(5).to_float()
		elif id.begins_with("distance_"):
			distance = id.substr(9).to_float()
		elif id == "reset":
			size = 1.0
			distance = 1.0
		else:
			return
		result = VisualStyle.set_comfort(size, distance)
	_comfort_message = "Réglage appliqué et mémorisé" if result == OK else "Appliqué, sauvegarde impossible"
	_build_comfort()


func close_comfort() -> void:
	if not _comfort_open:
		return
	_comfort_open = false
	_comfort.hide_panel()
	menu.visible = true
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	menu.set_active(true)
	menu.skip_intro()
	menu.place_in_front_of(camera.global_transform)
