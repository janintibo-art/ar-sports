class_name MolkkyGame
extends Node3D
## Mölkky en réalité augmentée : douze quilles de bois numérotées, un bâton à lancer
## par en-dessous. Une quille tombée = son numéro, plusieurs = leur nombre. Premier à
## 50 exactement ; en dépassant on retombe à 25 ; trois ratés de suite = éliminé.
## Vraie physique (Jolt) : quilles et bâton sont des corps rigides. Après chaque lancer
## on relève les quilles là où elles sont tombées, comme sur un vrai terrain.
## Le noeud est placé aux pieds du joueur ; les quilles sont devant lui, vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const PIN_R := 0.03
const PIN_H := 0.15
const STICK_R := 0.03
const STICK_L := 0.21
const GROUND_TOP := 0.002
const STAND := Vector3(0.36, 0.95, -0.2)
const GRAB_RADIUS := 0.38
const THROW_GAIN_H := 1.5
const THROW_GAIN_V := 1.2
const SAVE_PATH := "user://molkky.cfg"
const L_WORLD := 1
const L_PINS := 4
const L_STICK := 8

const LEVELS := {
	"facile": {"title": "Facile", "assist": 1.0, "sigma": 0.15},
	"normal": {"title": "Normal", "assist": 0.6, "sigma": 0.085},
	"expert": {"title": "Expert", "assist": 0.2, "sigma": 0.045},
}

# Disposition réglementaire (de la rangée la plus proche à la plus lointaine)
const LAYOUT := [[1, 2], [3, 10, 4], [5, 11, 12, 6], [7, 9, 8]]

enum State { SETUP, TURN_WAIT, AI_WAIT, FLIGHT, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "players": 2, "level": "normal", "target": 50, "dist": 3.5, "music": true}
var state := State.SETUP
var players: Array = []         # [{name, score, misses, out, ai}]
var current := 0
var cz := -3.5                  # profondeur du centre du groupe de quilles
var _pins: Array[RigidBody3D] = []
var _stick: RigidBody3D
var _held := false
var _held_hand: Hand = null
var _held_button := ""
var _settle := 0.0
var _flight := 0.0
var _timer := 0.0
var _think := 1.0
var _throws := 0                # série d'entraînement
var _series_total := 0
var _last_text := ""
var _pin_moved := {}
var _snd_cool := 0.0
var _rot_hist: Array = []
var _hands: Array = []
var _field: Node3D
var _board: MolkkyBoard
var _marcel: Spectator
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _message: Label3D
var _message_time := 0.0
var _hint: Label3D
var _save := ConfigFile.new()

var _selftest := false
var _st_bot := false
var _st_log: Array = []
var _st_failures: Array = []
var _pending_scores: Array = []
var _last_fallen := 0
var _hist: Array = []


# ================================================================ mise en place

func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_load_save()
	_field = Node3D.new()
	add_child(_field)
	_build_ground()
	_build_stand()
	_build_pins()
	_build_stick()
	_board = MolkkyBoard.new()
	add_child(_board)
	_marcel = Spectator.new({
		"name": "Marcel", "skin": Color(0.9, 0.72, 0.6), "shirt": Color(0.25, 0.5, 0.35),
		"pants": Color(0.75, 0.7, 0.55), "hair": Color(0.8, 0.8, 0.8), "beard": false,
		"hat": true, "hat_color": Color(0.85, 0.7, 0.3),
	})
	add_child(_marcel)
	_message = BowlingArt.neon_label("", 0.13, Color(1, 0.8, 0.2))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.no_depth_test = true
	_message.visible = false
	add_child(_message)
	_hint = BowlingArt.label("", 0.04, Color(1, 0.95, 0.7))
	_hint.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hint.no_depth_test = true
	add_child(_hint)
	_panel = UiPanel.new()
	_panel.accent = Color(0.95, 0.6, 0.2)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)
	_apply_layout()
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


func _build_ground() -> void:
	# Dalle de collision : le dessus est à GROUND_TOP, juste au-dessus du sol du monde
	var body := StaticBody3D.new()
	body.name = "Pelouse"
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.2, 14.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, GROUND_TOP - 0.1, -4.0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.05
	body.physics_material_override = pm
	add_child(body)


func _build_stand() -> void:
	var metal := BowlingArt.mat(Color(0.25, 0.27, 0.32), 0.35, 0.8)
	var wood := BowlingArt.mat(Color(0.55, 0.38, 0.18), 0.6)
	add_child(BowlingArt.cylinder(0.18, 0.2, 0.025, metal, Vector3(STAND.x, 0.0125, STAND.z), 24))
	add_child(BowlingArt.cylinder(0.022, 0.03, STAND.y - 0.03, metal, Vector3(STAND.x, (STAND.y - 0.03) / 2.0, STAND.z), 16))
	add_child(BowlingArt.box(Vector3(0.3, 0.025, 0.1), wood, Vector3(STAND.x, STAND.y - 0.02, STAND.z)))


func _pin_mesh(num: int) -> Node3D:
	var n := Node3D.new()
	var wood := BowlingArt.surface_material("wood", Color(0.88, 0.68, 0.38))
	n.add_child(BowlingArt.cylinder(PIN_R, PIN_R, PIN_H, wood, Vector3.ZERO, 14))
	# Dessus biseauté et numéro sur la face avant
	var cap := BowlingArt.cylinder(PIN_R * 0.98, PIN_R * 0.98, 0.006, BowlingArt.mat(Color(0.98, 0.85, 0.55), 0.5), Vector3(0, PIN_H / 2.0 + 0.001, 0), 14)
	cap.rotation_degrees = Vector3(28, 0, 0)
	n.add_child(cap)
	var l := BowlingArt.label(str(num), 0.036, Color(0.3, 0.12, 0.0), 0)
	l.position = Vector3(0, 0.012, PIN_R + 0.001)
	n.add_child(l)
	var ring := BowlingArt.cylinder(PIN_R * 1.01, PIN_R * 1.01, 0.012, BowlingArt.mat(Color(0.75, 0.2, 0.15), 0.6), Vector3(0, -0.045, 0), 14)
	n.add_child(ring)
	return n


func _build_pins() -> void:
	for num in range(1, 13):
		var b := RigidBody3D.new()
		b.name = "Quille%d" % num
		b.mass = 0.2
		b.collision_layer = L_PINS
		b.collision_mask = L_WORLD | L_PINS | L_STICK
		var pm := PhysicsMaterial.new()
		pm.friction = 0.6
		pm.bounce = 0.1
		b.physics_material_override = pm
		b.linear_damp = 0.6
		b.angular_damp = 2.5
		b.can_sleep = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = PIN_R
		cyl.height = PIN_H
		shape.shape = cyl
		b.add_child(shape)
		b.add_child(_pin_mesh(num))
		b.set_meta("num", num)
		add_child(b)
		b.freeze = true
		_pins.append(b)


func _build_stick() -> void:
	_stick = RigidBody3D.new()
	_stick.name = "Molkky"
	_stick.mass = 0.65
	_stick.collision_layer = L_STICK
	_stick.collision_mask = L_WORLD | L_PINS
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	_stick.physics_material_override = pm
	_stick.continuous_cd = true
	_stick.linear_damp = 0.0
	_stick.angular_damp = 0.0
	_stick.can_sleep = true
	_stick.contact_monitor = true
	_stick.max_contacts_reported = 6
	_stick.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = STICK_R
	cyl.height = STICK_L
	shape.shape = cyl
	_stick.add_child(shape)
	var wood := BowlingArt.mat(Color(0.95, 0.76, 0.42), 0.5)
	_stick.add_child(BowlingArt.cylinder(STICK_R, STICK_R, STICK_L, wood, Vector3.ZERO, 16))
	_stick.add_child(BowlingArt.cylinder(STICK_R * 1.02, STICK_R * 1.02, 0.02, BowlingArt.mat(Color(0.75, 0.2, 0.15), 0.6), Vector3(0, 0.04, 0), 16))
	_stick.body_entered.connect(_on_stick_hit)
	add_child(_stick)
	_stick.freeze = true
	_stick.visible = false


func _apply_layout() -> void:
	cz = -float(settings["dist"])
	for c in _field.get_children():
		c.queue_free()
	var len := float(settings["dist"]) + 4.5
	var gm := BowlingArt.surface_material("grass", Color(0.30, 0.48, 0.22), Vector2(7, len * 2.0))
	_field.add_child(BowlingArt.floor_quad(3.2, len, gm, Vector3(0, GROUND_TOP + 0.001, 1.0 - len / 2.0)))
	# Ligne de lancer et repère du groupe de quilles
	_field.add_child(BowlingArt.box(Vector3(1.8, 0.004, 0.05), BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, GROUND_TOP + 0.003, 0)))
	_field.add_child(BowlingArt.cylinder(0.3, 0.3, 0.003, BowlingArt.unshaded(Color(1, 1, 1, 0.25)), Vector3(0, GROUND_TOP + 0.002, cz), 32))
	var dl := BowlingArt.label("%s m" % str(settings["dist"]), 0.14, Color(1, 1, 1), 6)
	dl.rotation_degrees = Vector3(-90, 0, 0)
	dl.position = Vector3(-0.95, GROUND_TOP + 0.006, cz / 2.0)
	_field.add_child(dl)
	_build_decor(len)
	_board.position = Vector3(-1.9, 1.35, -1.5)
	var face := Vector3(0.0, 0, 1.0) - _board.position
	_board.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_board.scale = Vector3.ONE * 1.1
	_marcel.position = Vector3(-1.0, 0, 0.15)
	_marcel.rotation.y = deg_to_rad(25.0)
	_marcel.visible = settings["mode"] == "ordi"
	_message.position = Vector3(0, 1.7, cz)
	_hint.position = STAND + Vector3(0, 0.28, 0)
	_stand_pins_home()


func _build_decor(len: float) -> void:
	var zf := 1.0 - len
	for i in 4:
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(2.6 + 0.3 * ((i + int(sx)) % 3), 30 + i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (2.5 + 0.3 * (i % 2)), 0, -1.0 - i * 1.7)
			_field.add_child(t)
	for sx in [-1.0, 1.0]:
		var b := Decor.bush(0.4)
		b.position = Vector3(sx * 1.75, 0, cz - 0.3)
		_field.add_child(b)
	var bench := Decor.bench()
	bench.position = Vector3(1.8, 0, -1.6)
	bench.rotation.y = PI / 2.0
	_field.add_child(bench)
	# Palissade en bois au fond
	var wood := BowlingArt.mat(Color(0.5, 0.35, 0.2), 0.8)
	for k in 15:
		_field.add_child(BowlingArt.box(Vector3(0.1, 1.0 + 0.1 * (k % 2), 0.03), wood, Vector3(-1.6 + k * 0.23, 0.5, zf)))
	_field.add_child(BowlingArt.box(Vector3(3.5, 0.06, 0.04), wood, Vector3(0, 0.75, zf + 0.02)))
	var sign_node := Decor.neon_sign("MÖLKKY", Color(1.0, 0.6, 0.2), 1.5, 0.45)
	sign_node.position = Vector3(0, 1.55, zf - 0.05)
	_field.add_child(sign_node)
	for sx in [-1.0, 1.0]:
		var l := Decor.lamp(2.4)
		l.position = Vector3(sx * 1.7, 0, zf + 0.1)
		_field.add_child(l)


func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


# ================================================================ quilles

func _pin_home(num: int) -> Vector3:
	for r in LAYOUT.size():
		var row: Array = LAYOUT[r]
		var i := row.find(num)
		if i >= 0:
			var x := (i - (row.size() - 1) / 2.0) * 0.066
			var z := cz + 0.087 - r * 0.058
			return Vector3(x, GROUND_TOP + PIN_H / 2.0 + 0.001, z)
	return Vector3.ZERO


func _set_pin(b: RigidBody3D, pos: Vector3) -> void:
	b.freeze = true
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.transform = Transform3D(Basis(), pos)


func _stand_pins_home() -> void:
	for b in _pins:
		_set_pin(b, _pin_home(int(b.get_meta("num"))))
	_stick.visible = false


func _is_standing(b: RigidBody3D) -> bool:
	return b.global_transform.basis.y.dot(Vector3.UP) > 0.9 and b.position.y > GROUND_TOP + PIN_H * 0.4


func _fallen() -> Array:
	var out: Array = []
	for b in _pins:
		if not _is_standing(b):
			out.append(int(b.get_meta("num")))
	return out


## Relève chaque quille là où elle est tombée (sans chevauchement, dans les limites du terrain).
func _reset_pins_after() -> void:
	var pos: Array = []
	for b in _pins:
		var p := b.position
		p.x = clampf(p.x, -1.3, 1.3)
		p.z = clampf(p.z, cz - 1.8, cz + 1.2)
		pos.append(Vector2(p.x, p.z))
	for it in 40:
		var moved := false
		for i in pos.size():
			for j in range(i + 1, pos.size()):
				var d: Vector2 = pos[i] - pos[j]
				var l := d.length()
				if l < 0.068:
					var n := d / l if l > 0.0001 else Vector2(1, 0)
					var push := (0.068 - l) / 2.0 + 0.001
					pos[i] += n * push
					pos[j] -= n * push
					moved = true
		if not moved:
			break
	for i in _pins.size():
		var q: Vector2 = pos[i]
		_set_pin(_pins[i], Vector3(q.x, GROUND_TOP + PIN_H / 2.0 + 0.001, q.y))


func _on_stick_hit(body: Node) -> void:
	if _snd_cool > 0.0:
		return
	var sp := _stick.linear_velocity.length()
	if sp < 0.6:
		return
	_snd_cool = 0.06
	if body is RigidBody3D:
		Sound.play_at("pin_hit_%d" % (1 + randi() % 3), to_global(_stick.position), -6.0 + minf(sp, 6.0), 0.1)
	else:
		Sound.play_at("ball_thud", to_global(_stick.position), -12.0 + minf(sp, 6.0), 0.1)


# ================================================================ panneaux

func _is_two() -> bool:
	return settings["mode"] == "deux"


func is_training() -> bool:
	return settings["mode"] == "training"


func show_setup() -> void:
	state = State.SETUP
	_drop_stick()
	_stand_pins_home()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Mölkky", "Victoires : %d   ·   meilleure série : %d pts" % [_stat("wins"), _stat("best_series")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.26, "selected": settings["mode"] == "ordi"},
		{"id": "mode_deux", "text": "2 à 4 joueurs", "width": 0.26, "selected": settings["mode"] == "deux"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
	])
	if settings["mode"] == "deux":
		var prow: Array = []
		for n in [2, 3, 4]:
			prow.append({"id": "players_%d" % n, "text": str(n), "width": 0.12, "selected": settings["players"] == n})
		_panel.add_row("Joueurs", prow)
	if settings["mode"] == "ordi":
		var row: Array = []
		for l in ["facile", "normal", "expert"]:
			row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
		_panel.add_row("Niveau", row)
	_panel.add_row("Objectif", [
		{"id": "target_50", "text": "50 points", "width": 0.22, "selected": settings["target"] == 50},
		{"id": "target_25", "text": "Express 25", "width": 0.22, "selected": settings["target"] == 25},
	])
	_panel.add_row("Distance", [
		{"id": "dist_3.0", "text": "3 m", "width": 0.14, "selected": is_equal_approx(float(settings["dist"]), 3.0)},
		{"id": "dist_3.5", "text": "3,5 m", "width": 0.14, "selected": is_equal_approx(float(settings["dist"]), 3.5)},
		{"id": "dist_4.0", "text": "4 m", "width": 0.14, "selected": is_equal_approx(float(settings["dist"]), 4.0)},
	])
	_panel.add_row("", [
		{"id": "menu", "text": "Menu", "width": 0.2, "color": Color(0.35, 0.35, 0.4)},
		{"id": "play", "text": "JOUER", "width": 0.34, "color": Color(0.15, 0.6, 0.25)},
	])
	_open_panel()


func show_pause() -> void:
	_panel_page = "pause"
	_panel.clear()
	_panel.set_title("Pause")
	_panel.add_row("", [{"id": "resume", "text": "Reprendre", "width": 0.34, "color": Color(0.15, 0.6, 0.25)}])
	_panel.add_row("", [{"id": "restart", "text": "Recommencer", "width": 0.34}])
	_panel.add_row("", [{"id": "settings", "text": "Réglages", "width": 0.34}])
	_panel.add_row("", [{"id": "music_toggle", "text": "Musique : %s" % ("oui" if settings["music"] else "non"), "width": 0.34}])
	_panel.add_row("", [{"id": "switch", "text": "Changer de jeu", "width": 0.34, "color": Color(0.2, 0.4, 0.75)}])
	_panel.add_row("", [{"id": "menu", "text": "Menu principal", "width": 0.34, "color": Color(0.35, 0.35, 0.4)}])
	_open_panel()


func show_game_over(summary: String) -> void:
	_panel_page = "over"
	_panel.clear()
	_panel.set_title("Partie terminée", summary)
	_panel.add_row("", [
		{"id": "settings", "text": "Réglages", "width": 0.22},
		{"id": "restart", "text": "Revanche", "width": 0.26, "color": Color(0.15, 0.6, 0.25)},
		{"id": "menu", "text": "Menu", "width": 0.18, "color": Color(0.35, 0.35, 0.4)},
	])
	_open_panel()


func _open_panel() -> void:
	_drop_stick()
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)


func suspend_panel() -> void:
	_panel_was_visible = _panel.visible
	if _panel_was_visible:
		_panel.hide_panel()


func resume_panel() -> void:
	if _panel_was_visible:
		_panel.show_panel()
	_panel_was_visible = false


func _close_panel() -> void:
	_panel.hide_panel()
	_panel_page = ""
	_set_lasers(false)


func _set_lasers(on: bool) -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = on


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("mode_"):
		settings["mode"] = id.substr(5)
	elif id.begins_with("players_"):
		settings["players"] = int(id.substr(8))
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
	elif id.begins_with("target_"):
		settings["target"] = int(id.substr(7))
	elif id.begins_with("dist_"):
		settings["dist"] = float(id.substr(5))
	match id:
		"play", "restart":
			_close_panel()
			start_match()
			return
		"resume":
			_close_panel()
			return
		"settings":
			show_setup()
			return
		"menu":
			exit_requested.emit()
			return
		"switch":
			switch_requested.emit()
			return
		"music_toggle":
			settings["music"] = not settings["music"]
			Sound.music_enabled = settings["music"]
			_save_settings()
			show_pause()
			return
	_apply_layout()
	_save_settings()
	show_setup()


# ================================================================ partie

func start_match() -> void:
	_apply_layout()
	players.clear()
	match String(settings["mode"]):
		"ordi":
			players.append({"name": "VOUS", "score": 0, "misses": 0, "out": false, "ai": false})
			players.append({"name": "MARCEL", "score": 0, "misses": 0, "out": false, "ai": true})
		"deux":
			for i in int(settings["players"]):
				players.append({"name": "J%d" % (i + 1), "score": 0, "misses": 0, "out": false, "ai": false})
		_:
			players.append({"name": "VOUS", "score": 0, "misses": 0, "out": false, "ai": false})
	current = 0
	_throws = 0
	_series_total = 0
	_last_text = ""
	_begin_turn()


func _begin_turn() -> void:
	_update_board()
	var p: Dictionary = players[current]
	if _st_bot or bool(p["ai"]):
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""
		if not _st_bot and players.size() > 1:
			_announce("Au tour de %s" % String(p["name"]).capitalize(), Color(1, 0.8, 0.2), 1.2)
	else:
		state = State.TURN_WAIT
		_put_stick_on_stand()
		_hint.text = "Attrape le bâton (gâchette ou grip)\net lance-le par en-dessous"
		if players.size() > 1:
			_announce("%s, à toi !" % String(p["name"]).capitalize(), Color(1, 0.8, 0.2), 1.4)


func _put_stick_on_stand() -> void:
	_stick.freeze = true
	_stick.linear_velocity = Vector3.ZERO
	_stick.angular_velocity = Vector3.ZERO
	_stick.transform = Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), STAND + Vector3(0, STICK_R + 0.0, 0))
	_stick.visible = true
	_held = false
	_held_hand = null


func _drop_stick() -> void:
	_held = false
	_held_hand = null
	_held_button = ""
	_stick.visible = false
	_stick.freeze = true
	_hint.text = ""


func _launch(from: Vector3, vel: Vector3, omega: Vector3, orient: Basis) -> void:
	_stick.freeze = true
	_stick.transform = Transform3D(orient, from)
	_stick.visible = true
	for b in _pins:
		b.freeze = false
		b.sleeping = false
	_stick.freeze = false
	_stick.linear_velocity = vel
	_stick.angular_velocity = omega
	_pin_moved.clear()
	_held = false
	_held_hand = null
	_held_button = ""
	_settle = 0.0
	_flight = 0.0
	state = State.FLIGHT
	_hint.text = ""
	Sound.play_at("whoosh", to_global(from), -10.0, 0.1)


# ---------------------------------------------------------------- lancer humain

func _hand_item_tf(h: Hand) -> Transform3D:
	var gt := global_transform.affine_inverse() * h.global_transform
	return gt * Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(0, -0.03, -0.08))


func _try_grab(hand: Hand, button: String) -> void:
	if state != State.TURN_WAIT or _held:
		return
	var tf := _hand_item_tf(hand)
	if tf.origin.distance_to(_stick.position) > GRAB_RADIUS:
		return
	_held = true
	_held_hand = hand
	_held_button = button
	_rot_hist.clear()
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	Sound.play_at("grab", to_global(_stick.position), -6.0, 0.05)
	_hint.text = ""


func _track_hand_rotation(delta: float) -> void:
	if _held_hand == null or not is_instance_valid(_held_hand):
		return
	var b := (global_transform.affine_inverse() * _held_hand.global_transform).basis
	_rot_hist.append({"t": Time.get_ticks_msec() / 1000.0, "b": b})
	while _rot_hist.size() > 2 and float(_rot_hist.back()["t"]) - float(_rot_hist[0]["t"]) > 0.12:
		_rot_hist.pop_front()


func _hand_omega() -> Vector3:
	if _rot_hist.size() < 2:
		return Vector3.ZERO
	var a: Basis = _rot_hist[0]["b"]
	var b: Basis = _rot_hist.back()["b"]
	var dt := float(_rot_hist.back()["t"]) - float(_rot_hist[0]["t"])
	if dt < 0.01:
		return Vector3.ZERO
	var q := (Quaternion(b) * Quaternion(a).inverse()).normalized()
	var ang := q.get_angle()
	if ang > PI:
		ang -= TAU
	var axis := q.get_axis()
	if not axis.is_finite():
		return Vector3.ZERO
	return (axis * ang / dt).limit_length(14.0)


func _release_held(hand: Hand) -> void:
	if not _held or _held_hand != hand:
		return
	var tf := _hand_item_tf(hand)
	var v := global_basis.inverse() * hand.throw_velocity()
	var w := _hand_omega()
	_held = false
	_held_hand = null
	_held_button = ""
	_throw(tf, v, w)


## Lance le bâton tenu : `tf` position/orientation, `vel` vitesse de la main, `omega` rotation.
func _throw(tf: Transform3D, vel: Vector3, omega: Vector3) -> void:
	var hv := Vector2(vel.x, vel.z).length()
	if hv < 0.8 and vel.y < 0.8:
		_put_stick_on_stand()
		_hint.text = "Lance plus fort !"
		return
	vel = Vector3(vel.x * THROW_GAIN_H, vel.y * THROW_GAIN_V, vel.z * THROW_GAIN_H)
	vel = vel.limit_length(9.0)
	vel = _assist(tf.origin, vel)
	_launch(tf.origin, vel, omega, tf.basis)


func _flight_time(p: Vector3, v: Vector3, y_end: float) -> float:
	var disc := v.y * v.y + 2.0 * 9.81 * (p.y - y_end)
	if disc < 0.0:
		return 0.0
	return (v.y + sqrt(disc)) / 9.81


## Aide : un lancer qui retomberait loin des quilles est ramené vers elles ;
## en Facile, un petit coup de pouce guide aussi les lancers corrects.
func _assist(p: Vector3, v: Vector3) -> Vector3:
	var a: float = LEVELS[settings["level"]]["assist"]
	var t := _flight_time(p, v, 0.05)
	if t < 0.1:
		return v
	var land := Vector2(p.x + v.x * t, p.z + v.z * t)
	var lo := Vector2(-0.8, cz - 0.7)
	var hi := Vector2(0.8, cz + 0.9)
	var clamped := Vector2(clampf(land.x, lo.x, hi.x), clampf(land.y, lo.y, hi.y))
	var target := land.lerp(clamped, minf(1.0, a + 0.2))
	var guide := a * 0.25
	target = target.lerp(Vector2(0.0, cz + 0.25), guide)
	return Vector3((target.x - p.x) / t, v.y, (target.y - p.z) / t)


# ================================================================ physique et déroulement

func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.visible = false
	_snd_cool = maxf(0.0, _snd_cool - delta)
	if _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)
		return
	match state:
		State.TURN_WAIT:
			_track_hand_rotation(delta)
			if _held and _held_hand != null and is_instance_valid(_held_hand):
				_stick.transform = _hand_item_tf(_held_hand)
		State.AI_WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_ai_throw()
		State.FLIGHT:
			_flight += delta
			# En l'air le bâton ne freine pas ; au sol il s'arrête vite (herbe)
			var on_ground := _stick.position.y < 0.06
			_stick.linear_damp = 0.5 if on_ground else 0.0
			_stick.angular_damp = 2.0 if on_ground else 0.0
			_watch_pins()
			if _flight > 0.5:
				if _is_moving():
					_settle = 0.0
				else:
					_settle += delta
			if _settle > 0.7 or _flight > 8.0:
				_evaluate()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()


func _is_moving() -> bool:
	if _stick.linear_velocity.length() > 0.1 or _stick.angular_velocity.length() > 0.6:
		return true
	for b in _pins:
		if b.linear_velocity.length() > 0.1 or b.angular_velocity.length() > 0.6:
			return true
	return false


func _watch_pins() -> void:
	for b in _pins:
		var n := int(b.get_meta("num"))
		if not _pin_moved.has(n) and b.linear_velocity.length() > 0.5 and not _is_standing(b):
			_pin_moved[n] = true
			if _snd_cool <= 0.0:
				Sound.play_at("pin_hit_%d" % (1 + randi() % 3), to_global(b.position), -8.0, 0.12)


## Applique la règle du score : renvoie [nouveau score, dépassement ?].
static func apply_score(score: int, gained: int, target: int) -> Array:
	var ns := score + gained
	if ns > target:
		return [target / 2, true]
	return [ns, false]


func _evaluate() -> void:
	var fallen := _fallen()
	_last_fallen = fallen.size()
	_hist.append(fallen.size())
	var gained := 0
	if fallen.size() == 1:
		gained = int(fallen[0])
	else:
		gained = fallen.size()
	for b in _pins:
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
	_stick.freeze = true
	_stick.visible = false
	_reset_pins_after()
	_register(gained, fallen)


func _register(gained: int, fallen: Array) -> void:
	var p: Dictionary = players[current]
	var target: int = settings["target"]
	var won := false
	var text := ""
	if is_training():
		_throws += 1
		_series_total += gained
		_last_text = "%d" % gained
		text = "%d point%s" % [gained, "s" if gained > 1 else ""] if gained > 0 else "Raté !"
		p["score"] = _series_total
		if gained == 0:
			p["misses"] = mini(int(p["misses"]) + 1, 3)
		else:
			p["misses"] = 0
		if _throws >= 10:
			_best_stat("best_series", _series_total)
			text = "Série finie : %d pts" % _series_total
			_pending_scores.append(_series_total)
			_throws = 0
			_series_total = 0
			p["score"] = 0
			p["misses"] = 0
		_announce(text, Color(1, 0.8, 0.2), 2.0)
	elif gained == 0:
		p["misses"] = int(p["misses"]) + 1
		text = "Raté !"
		if int(p["misses"]) >= 3:
			p["out"] = true
			text = "Raté… %s est éliminé !" % String(p["name"]).capitalize()
		_announce(text, Color(1, 0.4, 0.3), 2.2)
		_board.celebrate("bust")
	else:
		p["misses"] = 0
		var res := apply_score(int(p["score"]), gained, target)
		p["score"] = res[0]
		if res[1]:
			text = "%d… trop ! Retour à %d" % [gained, target / 2]
			_board.celebrate("bust")
			_announce(text, Color(1, 0.5, 0.2), 2.4)
		else:
			text = "%d point%s !" % [gained, "s" if gained > 1 else ""]
			_board.celebrate("point")
			_announce("%s : %d" % [String(p["name"]).capitalize(), gained] if players.size() > 1 else text, Color(0.4, 1, 0.5), 2.0)
			if res[0] == target:
				won = true
		_last_text = "%d" % gained
	if _marcel.visible and not is_training():
		if gained >= 8 and bool(p["ai"]):
			_marcel.react("carreau")
		elif gained == 0 and bool(p["ai"]):
			_marcel.react("oups")
		elif gained >= 8:
			_marcel.say("good")
	_update_board()
	if won:
		_game_over(current)
		return
	var alive := 0
	var last_alive := -1
	for i in players.size():
		if not bool(players[i]["out"]):
			alive += 1
			last_alive = i
	if players.size() > 1 and alive <= 1:
		_game_over(last_alive)
		return
	state = State.PAUSE
	_timer = 1.6 if not _selftest else 0.1


func _after_pause() -> void:
	var n := players.size()
	var i := current
	for k in n:
		i = (i + 1) % n
		if not bool(players[i]["out"]):
			break
	current = i
	_begin_turn()


func _game_over(winner: int) -> void:
	state = State.GAME_OVER
	var w: Dictionary = players[winner]
	var summary := "%s gagne avec %d points !" % [String(w["name"]).capitalize(), int(w["score"])]
	_board.celebrate("win")
	if winner == 0 and settings["mode"] == "ordi":
		_bump_stat("wins")
		_marcel.say("oups", true)
	elif settings["mode"] == "ordi":
		_marcel.react("win")
	_announce("%s !" % summary, Color(1, 0.8, 0.2), 3.0)
	_update_board()
	if _selftest:
		return
	await get_tree().create_timer(1.6).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _update_board() -> void:
	var target: int = settings["target"]
	var title := "MÖLKKY · %d" % target
	var foot := ""
	if is_training():
		title = "MÖLKKY · ENTRAÎNEMENT"
		foot = "Lancer %d sur 10 · dernier : %s" % [mini(_throws + 1, 10), _last_text if _last_text != "" else "—"]
	elif not players.is_empty():
		var p: Dictionary = players[current]
		var need := target - int(p["score"])
		foot = "%s : encore %d point%s" % [String(p["name"]).capitalize(), need, "s" if need > 1 else ""]
	_board.set_data(title, players, current, target, foot)


func _announce(text: String, color: Color, seconds: float) -> void:
	_message.text = text
	_message.outline_modulate = color
	_message.modulate = Color(1, 1, 1).lerp(color, 0.2)
	_message.visible = true
	_message_time = seconds
	_message.scale = Vector3.ONE * 1.5
	var tw_ := create_tween()
	tw_.tween_property(_message, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================ adversaire

func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _ai_throw() -> void:
	var lvl: Dictionary = LEVELS[settings["level"]]
	var p: Dictionary = players[current]
	var need: int = int(settings["target"]) - int(p["score"])
	# Cible : la quille qui donne exactement les points manquants (si possible), sinon la plus haute
	var best: RigidBody3D = null
	var best_num := -1
	for b in _pins:
		if not _is_standing(b):
			continue
		var n := int(b.get_meta("num"))
		if need <= 12 and n == need:
			best = b
			break
		if need > 12 and n > best_num:
			best = b
			best_num = n
	if best == null:
		best = _pins[0]
		for b in _pins:
			if _is_standing(b):
				best = b
				break
	var sg: float = lvl["sigma"]
	var tx := best.position.x + _gauss() * sg * 0.6
	var tz := best.position.z + _gauss() * sg * 0.6
	var from := Vector3(-0.8, 0.6, 0.1)
	var d2 := Vector2(tx - from.x, tz - from.z)
	var dir := d2.normalized()
	var land := Vector2(tx, tz) - dir * 0.3
	var t := 0.5 + 0.08 * d2.length()
	var vy := (0.04 - from.y + 0.5 * 9.81 * t * t) / t
	var vel := Vector3((land.x - from.x) / t, vy, (land.y - from.z) / t)
	var side := Vector3.UP.cross(Vector3(dir.x, 0.0, dir.y)).normalized()
	var basis_ := Basis(Quaternion(Vector3.UP, side))
	var omega := side * (6.0 + randf() * 4.0) * (1.0 if randf() < 0.5 else -1.0)
	_launch(from, vel, omega, basis_)


# ================================================================ entrées

func on_button_pressed(hand: Hand, button: String) -> void:
	if _panel.visible:
		if button == "trigger_click":
			var target := hand.pointed_object()
			if target:
				hand.buzz(0.3, 0.04)
				_panel.click(target)
		elif button == "by_button" and _panel_page == "pause":
			_close_panel()
		return
	if button == "by_button":
		show_pause()
		return
	if button == "trigger_click" or button == "grip_click":
		_try_grab(hand, button)


func on_button_released(hand: Hand, button: String) -> void:
	if button == _held_button and hand == _held_hand:
		_release_held(hand)


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["ordi", "deux", "training"]:
		settings["mode"] = "ordi"
	if int(settings["target"]) not in [25, 50]:
		settings["target"] = 50
	if int(settings["players"]) not in [2, 3, 4]:
		settings["players"] = 2
	if not (float(settings["dist"]) in [3.0, 3.5, 4.0]):
		settings["dist"] = 3.5


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	_save.save(SAVE_PATH)


func _stat(key: String) -> int:
	return int(_save.get_value("records", key, 0))


func _bump_stat(key: String) -> void:
	_save.set_value("records", key, _stat(key) + 1)
	_save.save(SAVE_PATH)


func _best_stat(key: String, value: int) -> void:
	if value > _stat(key):
		_save.set_value("records", key, value)
		_save.save(SAVE_PATH)


# ================================================================ auto-test

func _st_check(name: String, ok: bool, detail: String = "") -> void:
	_st_log.append("%s : %s %s" % [name, "ok" if ok else "ECHEC", detail])
	if not ok:
		_st_failures.append(name)


func enable_selftest() -> void:
	_selftest = true
	_think = 0.1
	_close_panel()
	_selftest_run()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_state(target: State, max_frames: int) -> void:
	var i := 0
	while state != target and i < max_frames:
		await get_tree().physics_frame
		i += 1


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["target"] = 50
	settings["dist"] = 3.5
	_apply_layout()
	await _wait_frames(3)

	# A. Les douze quilles sont debout, numérotées de 1 à 12, bien rangées
	var nums := {}
	for b in _pins:
		nums[int(b.get_meta("num"))] = true
	var all_up := _fallen().is_empty()
	_st_check("12 quilles debout", _pins.size() == 12 and nums.size() == 12 and all_up, "(%d tombées)" % _fallen().size())

	# B. Règles de score
	var r1 := apply_score(40, 8, 50)
	var r2 := apply_score(45, 9, 50)
	var r3 := apply_score(49, 1, 50)
	var r4 := apply_score(20, 12, 25)
	_st_check("règle des 50", r1 == [48, false] and r2 == [25, true] and r3 == [50, false] and r4 == [12, true], str([r1, r2, r3, r4]))

	# C. Physique : un lancer en plein dans le groupe fait tomber des quilles, et tout se stabilise
	var fell := 0
	var timeouts := 0
	players = [{"name": "A", "score": 0, "misses": 0, "out": false, "ai": false}]
	current = 0
	for i in 5:
		_stand_pins_home()
		var from := Vector3(0.0, 0.5, 0.0)
		var t := 0.8
		var land := Vector2(0.0, cz + 0.3)
		var vy := (0.04 - from.y + 0.5 * 9.81 * t * t) / t
		var vel := Vector3((land.x - from.x) / t, vy, (land.y - from.z) / t)
		_launch(from, vel, Vector3(8.0, 0, 0), Basis(Vector3(0, 0, 1), PI / 2.0))
		await _wait_state(State.PAUSE, 90 * 12)
		if state == State.FLIGHT:
			timeouts += 1
		fell += _last_fallen
		_flight = 0.0
		state = State.SETUP
	_st_check("lancer dans le groupe", fell >= 2 and timeouts == 0, "(%d quilles au total, %d blocages)" % [fell, timeouts])

	# D. Relever les quilles : debout, sans chevauchement
	var b0 := _pins[0]
	b0.freeze = false
	b0.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.03, cz))
	_pins[1].global_transform = Transform3D(Basis(), Vector3(0.01, 0.077, cz))
	_reset_pins_after()
	var overlap := false
	for i in _pins.size():
		for j in range(i + 1, _pins.size()):
			if _pins[i].position.distance_to(_pins[j].position) < 0.06:
				overlap = true
	_st_check("quilles relevées", _fallen().is_empty() and not overlap, "")

	# E. Éliminations : trois ratés de suite
	players = [
		{"name": "A", "score": 0, "misses": 2, "out": false, "ai": false},
		{"name": "B", "score": 0, "misses": 0, "out": false, "ai": false},
	]
	current = 0
	_register(0, [])
	_st_check("trois ratés = éliminé", bool(players[0]["out"]) and state == State.GAME_OVER, "")

	# F. Parties complètes (adversaire et joueurs virtuels)
	for mode in ["ordi", "deux"]:
		settings["mode"] = mode
		settings["players"] = 3
		settings["target"] = 25
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 900:
			await get_tree().physics_frame
			guard += 1
		var scores: Array = []
		for p in players:
			scores.append(int(p["score"]))
		_st_check("partie %s terminée" % mode, state == State.GAME_OVER, "%s en %.0f s ; quilles par lancer %s" % [str(scores), guard / 90.0, str(_hist)])
		_hist.clear()

	# G. Entraînement : une série de 10 lancers
	settings["mode"] = "training"
	_pending_scores.clear()
	_st_bot = true
	start_match()
	var g2 := 0
	while _pending_scores.is_empty() and g2 < 90 * 400:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement : série", not _pending_scores.is_empty(), "(%s pts en %.0f s)" % [str(_pending_scores), g2 / 90.0])
	_st_bot = false

	# H. Lancer humain simulé : un geste doux atteint les quilles
	settings["mode"] = "deux"
	settings["players"] = 2
	settings["level"] = "facile"
	settings["target"] = 50
	start_match()
	await _wait_frames(2)
	_st_check("tour du joueur", state == State.TURN_WAIT and _stick.visible, str(state))
	_held = true
	_throw(Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(0.3, 0.7, 0.0)), Vector3(0.0, 1.5, -2.6), Vector3(5, 0, 0))
	await _wait_state(State.PAUSE, 90 * 12)
	_st_check("lancer humain jugé", state == State.PAUSE or state == State.TURN_WAIT or state == State.GAME_OVER, str(state))

	_drop_stick()
	for line in _st_log:
		print("SELFTEST molkky ", line)
	print("SELFTEST molkky=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
