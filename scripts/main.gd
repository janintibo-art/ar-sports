extends Node3D
## Point d'entrée : démarre OpenXR, active le passthrough (réalité augmentée),
## crée les mains, le sol invisible et le menu, puis lance les jeux.

const GAMES := {
	"bowling": preload("res://scripts/bowling.gd"),
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


func _ready() -> void:
	_selftest = OS.get_cmdline_user_args().has("--selftest")
	_build_world()
	_start_xr()
	menu = GameMenu.new()
	menu.game_chosen.connect(start_game)
	add_child(menu)
	if _selftest:
		print("SELFTEST démarrage")
		start_game("bowling")
		game.enable_selftest()
	else:
		show_menu()


func _build_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.25, 0.27, 0.3)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.6
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
	if game:
		game.queue_free()
		game = null
	menu.visible = true
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	_set_menu_collisions(true)
	left_hand.laser_enabled = true
	right_hand.laser_enabled = true
	_place_current()


func start_game(game_id: String) -> void:
	if not GAMES.has(game_id):
		return
	menu.visible = false
	_set_menu_collisions(false)
	menu.update_hover([])
	left_hand.laser_enabled = false
	right_hand.laser_enabled = false
	if game:
		game.queue_free()
	game = GAMES[game_id].new()
	game.exit_requested.connect(show_menu)
	add_child(game)
	_place_current()


func _place_current() -> void:
	var head := camera.global_transform
	if game:
		game.place_in_front_of(head)
	else:
		menu.place_in_front_of(head)


func _set_menu_collisions(on: bool) -> void:
	for child in menu.get_children():
		if child is StaticBody3D:
			child.collision_layer = 2 if on else 0


# ---------------------------------------------------------------- entrées

func _process(_delta: float) -> void:
	if game == null and menu.visible:
		menu.update_hover([right_hand.pointed_object(), left_hand.pointed_object()])


func _on_button_pressed(button: String, hand: Hand) -> void:
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
