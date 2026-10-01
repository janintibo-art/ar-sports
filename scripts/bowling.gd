class_name BowlingGame
extends Node3D
## Bowling en réalité augmentée : une piste virtuelle posée sur le sol réel.
## Le noeud est placé aux pieds du joueur ; la piste part vers -Z (devant lui).

signal exit_requested

const LANE_W := 1.05
const FOUL_Z := -0.5
const HEADPIN_Z := -4.4
const PIN_SPACING_X := 0.3048
const PIN_SPACING_Z := 0.2635
const PIN_HEIGHT := 0.38
const PIN_RADIUS := 0.0605
const BALL_RADIUS := 0.109
const BALL_REST := Vector3(0.35, 0.9, -0.3)
const THROW_BOOST := 1.4
const MIN_THROW_SPEED := 0.9
const ROLL_TIMEOUT := 7.0
const SETTLE_TIME := 2.5

enum State { READY, HELD, ROLLING, SETTLING, GAME_OVER }

var state := State.READY
var frames: Array = []          # un tableau de lancers par frame
var _standing: Array[int] = []  # indices (0..9) des quilles encore debout
var _pins: Array[RigidBody3D] = []
var _pin_spots: Array[Vector3] = []
var _ball: RigidBody3D
var _holder: Hand = null
var _timer := 0.0
var _slow_time := 0.0
var _board: Label3D
var _message: Label3D
var _message_time := 0.0
var _selftest := false
var _selftest_rolls := 0


func _ready() -> void:
	_compute_pin_spots()
	_build_lane()
	_build_ball()
	_board = _make_label(0.11)
	_board.position = Vector3(0, 1.25, HEADPIN_Z - 0.6)
	add_child(_board)
	_message = _make_label(0.07)
	_message.position = Vector3(0, 1.45, -1.6)
	add_child(_message)
	new_game()


# ---------------------------------------------------------------- partie

func new_game() -> void:
	frames = [[]]
	_standing = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	_spawn_pins()
	_ball_to_rest()
	state = State.READY
	_update_board()
	show_message("Gâchette ou poignée : prendre la boule")


## Replace la piste devant le joueur (pieds au sol, face au regard).
func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if state == State.READY or state == State.GAME_OVER:
		_spawn_pins()
		_ball_to_rest()


# ---------------------------------------------------------------- entrées

func on_button_pressed(hand: Hand, button: String) -> void:
	match button:
		"trigger_click", "grip_click":
			if state == State.READY:
				_grab(hand)
		"ax_button":
			if state == State.GAME_OVER:
				new_game()
		"by_button":
			exit_requested.emit()


func on_button_released(hand: Hand, button: String) -> void:
	if state == State.HELD and hand == _holder and (button == "trigger_click" or button == "grip_click"):
		_release(hand)


func _grab(hand: Hand) -> void:
	_holder = hand
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	_ball.freeze = true
	state = State.HELD
	show_message("")


func _release(hand: Hand) -> void:
	var velocity := hand.throw_velocity() * THROW_BOOST
	_holder = null
	if velocity.length() < MIN_THROW_SPEED:
		_ball_to_rest()
		state = State.READY
		show_message("Lance un peu plus fort !")
		return
	_launch(_ball.global_position, velocity)
	hand.buzz(0.7, 0.1)


func _launch(from: Vector3, velocity: Vector3) -> void:
	var min_y := global_position.y + BALL_RADIUS + 0.01
	if from.y < min_y:
		from.y = min_y
	_ball.global_position = from
	_ball.freeze = false
	_ball.linear_velocity = velocity
	_ball.angular_velocity = Vector3.ZERO
	_timer = 0.0
	_slow_time = 0.0
	state = State.ROLLING


# ---------------------------------------------------------------- boucle

func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""

	match state:
		State.READY:
			if _selftest:
				_selftest_throw()
		State.HELD:
			if _holder:
				_ball.global_position = _holder.global_position - _holder.global_basis.y * 0.04
		State.ROLLING:
			_timer += delta
			var local := to_local(_ball.global_position)
			if _ball.linear_velocity.length() < 0.08:
				_slow_time += delta
			else:
				_slow_time = 0.0
			var finished := _timer > ROLL_TIMEOUT \
				or local.z < HEADPIN_Z - 1.0 \
				or local.y < -1.0 or absf(local.x) > 3.0 or local.z > 2.0 \
				or (_timer > 1.0 and _slow_time > 0.5)
			if finished:
				state = State.SETTLING
				_timer = 0.0
		State.SETTLING:
			_timer += delta
			if _timer > SETTLE_TIME:
				_end_roll()


func _end_roll() -> void:
	var still_up: Array[int] = []
	for i in _pins.size():
		if not _is_down(_pins[i], _standing[i]):
			still_up.append(_standing[i])
	var knocked := _standing.size() - still_up.size()
	var cleared := still_up.is_empty()

	var frame_index := frames.size() - 1
	var cur: Array = frames[frame_index]
	cur.append(knocked)

	var full_reset := false
	var frame_done := false
	var game_over := false

	if frame_index < 9:
		if cur.size() == 1 and cleared:
			full_reset = true
			frame_done = true
			show_message("STRIKE !", 2.5)
		elif cur.size() == 2:
			full_reset = true
			frame_done = true
			show_message("SPARE !" if cleared else _count_text(knocked), 2.0)
		else:
			show_message(_count_text(knocked), 2.0)
	else:
		match cur.size():
			1:
				full_reset = cleared
				show_message("STRIKE !" if cleared else _count_text(knocked), 2.0)
			2:
				if cur[0] == 10:
					full_reset = cleared
					show_message("STRIKE !" if cleared else _count_text(knocked), 2.0)
				elif cur[0] + cur[1] == 10:
					full_reset = true
					show_message("SPARE ! Dernière boule", 2.0)
				else:
					game_over = true
			_:
				game_over = true

	if frame_done:
		frames.append([])
	if full_reset:
		_standing = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	else:
		_standing = still_up
	_spawn_pins()
	_ball_to_rest()
	_update_board()

	if game_over:
		state = State.GAME_OVER
		var total := total_score()
		show_message("Partie terminée : %d points\nA : rejouer   B : menu" % total, 0.0)
		if _selftest:
			_selftest_finish()
	else:
		state = State.READY


func _count_text(knocked: int) -> String:
	if knocked == 0:
		return "Raté !"
	if knocked == 1:
		return "1 quille"
	return "%d quilles" % knocked


func _is_down(pin: RigidBody3D, spot_index: int) -> bool:
	if not is_instance_valid(pin):
		return true
	var up := pin.global_basis.y.normalized()
	if up.dot(global_basis.y) < 0.85:
		return true
	var local := to_local(pin.global_position)
	var spot := _pin_spots[spot_index]
	if local.y < -0.3:
		return true
	return Vector2(local.x - spot.x, local.z - spot.z).length() > 0.1


# ---------------------------------------------------------------- score

func flat_rolls() -> Array:
	var rolls: Array = []
	for f in frames:
		rolls.append_array(f)
	return rolls


func total_score() -> int:
	var scores := BowlingGame.frame_scores(flat_rolls())
	return 0 if scores.is_empty() else int(scores[scores.size() - 1])


## Scores cumulés des frames dont la valeur est déjà connue.
static func frame_scores(rolls: Array) -> Array:
	var out: Array = []
	var i := 0
	var total := 0
	for _f in 10:
		if i >= rolls.size():
			break
		if rolls[i] == 10:
			if i + 2 >= rolls.size():
				break
			total += 10 + rolls[i + 1] + rolls[i + 2]
			i += 1
		else:
			if i + 1 >= rolls.size():
				break
			if rolls[i] + rolls[i + 1] == 10:
				if i + 2 >= rolls.size():
					break
				total += 10 + rolls[i + 2]
			else:
				total += rolls[i] + rolls[i + 1]
			i += 2
		out.append(total)
	return out


## Notation d'une frame (X, /, -), y compris la 10e.
static func frame_marks(frame: Array, is_tenth: bool) -> String:
	var marks := ""
	var rack_first := true
	var pins_left := 10
	for r in frame.size():
		var v: int = frame[r]
		var mark := ""
		if rack_first and v == 10:
			mark = "X"
		elif not rack_first and v == pins_left:
			mark = "/"
		elif v == 0:
			mark = "-"
		else:
			mark = str(v)
		marks += mark
		pins_left -= v
		if pins_left <= 0 or not rack_first:
			pins_left = 10
			rack_first = true
		else:
			rack_first = false
		if not is_tenth and (mark == "X" or r == 1):
			break
	return marks


func _update_board() -> void:
	var cells: Array[String] = []
	for i in 10:
		var f: Array = frames[i] if i < frames.size() else []
		var m := BowlingGame.frame_marks(f, i == 9)
		cells.append(m if m != "" else "·")
	var frame_no: int = mini(frames.size(), 10)
	_board.text = "Frame %d/10      Score %d\n%s" % [frame_no, total_score(), " | ".join(cells)]


func show_message(text: String, seconds: float = 3.0) -> void:
	_message.text = text
	_message_time = seconds


# ---------------------------------------------------------------- construction

func _compute_pin_spots() -> void:
	_pin_spots.clear()
	for row in 4:
		for k in row + 1:
			var x := (k - row / 2.0) * PIN_SPACING_X
			var z := HEADPIN_Z - row * PIN_SPACING_Z
			_pin_spots.append(Vector3(x, 0.0, z))


func _build_lane() -> void:
	var deck_end := HEADPIN_Z - 3 * PIN_SPACING_Z - 0.35
	var length := FOUL_Z - deck_end
	var center_z := (FOUL_Z + deck_end) / 2.0

	# Plancher de piste (visuel uniquement : le vrai sol est géré par Main).
	var lane := MeshInstance3D.new()
	var lane_mesh := BoxMesh.new()
	lane_mesh.size = Vector3(LANE_W, 0.004, length)
	lane.mesh = lane_mesh
	lane.position = Vector3(0, 0.002, center_z)
	lane.material_override = _material(Color(0.86, 0.68, 0.45, 0.55))
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lane)

	# Ligne de faute.
	var foul := MeshInstance3D.new()
	var foul_mesh := BoxMesh.new()
	foul_mesh.size = Vector3(LANE_W, 0.005, 0.03)
	foul.mesh = foul_mesh
	foul.position = Vector3(0, 0.004, FOUL_Z)
	foul.material_override = _material(Color(0.9, 0.15, 0.15))
	add_child(foul)

	# Flèches de visée.
	for k in 5:
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.04, 0.08, 0.004)
		arrow.mesh = prism
		arrow.rotation_degrees = Vector3(-90, 0, 0)
		arrow.position = Vector3((k - 2) * 0.12, 0.005, FOUL_Z - 1.4 - absf(k - 2) * 0.1)
		arrow.material_override = _material(Color(0.25, 0.15, 0.1))
		add_child(arrow)

	# Bumpers (rebords) et fond de piste.
	for side in [-1.0, 1.0]:
		_add_static_box(Vector3(0.08, 0.14, length + 0.6), Vector3(side * (LANE_W / 2.0 + 0.04), 0.07, center_z - 0.3), Color(0.3, 0.55, 0.95, 0.45))
	_add_static_box(Vector3(LANE_W + 0.24, 0.7, 0.1), Vector3(0, 0.35, deck_end - 0.6), Color(0.1, 0.1, 0.12, 0.85))

	# Petit support de boule à droite du joueur.
	var stand := MeshInstance3D.new()
	var col := CylinderMesh.new()
	col.top_radius = 0.06
	col.bottom_radius = 0.1
	col.height = BALL_REST.y - BALL_RADIUS
	stand.mesh = col
	stand.position = Vector3(BALL_REST.x, col.height / 2.0, BALL_REST.z)
	stand.material_override = _material(Color(0.2, 0.2, 0.25, 0.8))
	add_child(stand)


func _build_ball() -> void:
	_ball = RigidBody3D.new()
	_ball.name = "Boule"
	_ball.mass = 6.0
	_ball.continuous_cd = true
	_ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_ball.can_sleep = false
	var phys := PhysicsMaterial.new()
	phys.friction = 0.25
	phys.bounce = 0.05
	_ball.physics_material_override = phys

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	shape.shape = sphere
	_ball.add_child(shape)

	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_RADIUS
	sm.height = BALL_RADIUS * 2.0
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.25, 0.85)
	mat.metallic = 0.2
	mat.roughness = 0.25
	mesh.material_override = mat
	_ball.add_child(mesh)

	# Trois trous pour les doigts, juste pour le style.
	for offset in [Vector3(-0.025, 0.02, 0), Vector3(0.025, 0.02, 0), Vector3(0, -0.03, 0)]:
		var hole := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.012
		hm.height = 0.024
		hole.mesh = hm
		hole.position = (offset + Vector3(0, 0, BALL_RADIUS)).normalized() * (BALL_RADIUS - 0.006)
		hole.material_override = _material(Color(0.02, 0.02, 0.05))
		_ball.add_child(hole)

	add_child(_ball)


func _ball_to_rest() -> void:
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.position = BALL_REST
	_ball.rotation = Vector3.ZERO


func _spawn_pins() -> void:
	for pin in _pins:
		if is_instance_valid(pin):
			pin.queue_free()
	_pins.clear()
	for index in _standing:
		var pin := _make_pin()
		pin.position = _pin_spots[index] + Vector3(0, PIN_HEIGHT / 2.0 + 0.002, 0)
		add_child(pin)
		_pins.append(pin)


func _make_pin() -> RigidBody3D:
	var pin := RigidBody3D.new()
	pin.mass = 1.5
	pin.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	pin.center_of_mass = Vector3(0, -0.06, 0)
	var phys := PhysicsMaterial.new()
	phys.friction = 0.25
	phys.bounce = 0.35
	pin.physics_material_override = phys

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PIN_RADIUS
	cyl.height = PIN_HEIGHT
	shape.shape = cyl
	pin.add_child(shape)

	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.032
	cm.bottom_radius = 0.045
	cm.height = PIN_HEIGHT - 0.06
	body.mesh = cm
	body.position = Vector3(0, -0.03, 0)
	body.material_override = _solid(Color(0.97, 0.97, 0.95))
	pin.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.034
	hm.height = 0.068
	head.mesh = hm
	head.position = Vector3(0, PIN_HEIGHT / 2.0 - 0.034, 0)
	head.material_override = _solid(Color(0.97, 0.97, 0.95))
	pin.add_child(head)

	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.034
	bm.bottom_radius = 0.035
	bm.height = 0.025
	band.mesh = bm
	band.position = Vector3(0, 0.09, 0)
	band.material_override = _solid(Color(0.85, 0.1, 0.1))
	pin.add_child(band)
	return pin


func _add_static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _material(color)
	body.add_child(mesh)
	add_child(body)


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	return mat


static func _make_label(height: float) -> Label3D:
	var label := Label3D.new()
	label.font_size = 96
	label.pixel_size = height / 96.0
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return label


# ---------------------------------------------------------------- auto-test

func enable_selftest() -> void:
	_selftest = true


func _selftest_throw() -> void:
	_selftest_rolls += 1
	if _selftest_rolls > 25:
		_selftest_finish()
		return
	var aim_x := randf_range(-0.12, 0.12)
	var from := to_global(Vector3(0.0, BALL_RADIUS + 0.02, FOUL_Z - 0.1))
	var target := to_global(Vector3(aim_x, BALL_RADIUS, HEADPIN_Z))
	var velocity := (target - from).normalized() * randf_range(4.0, 7.0)
	_launch(from, velocity)


func _selftest_finish() -> void:
	_selftest = false
	var marks: Array[String] = []
	for i in frames.size():
		marks.append(BowlingGame.frame_marks(frames[i], i == 9))
	print("SELFTEST frames=", frames)
	print("SELFTEST marques=", " | ".join(marks))
	print("SELFTEST score=", total_score(), " etat=", State.keys()[state])
	get_tree().quit(0 if state == State.GAME_OVER else 2)
