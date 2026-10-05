class_name BasketGame
extends Node3D
## Basket en réalité augmentée : un panier de mini-basket (anneau à 2 m), un ballon à lancer.
## Trois zones de tir : près (1 point), moyen (2 points), loin (3 points) ou mixte.
## Séries de 10 tirs contre l'ordinateur, à plusieurs ou seul ; en entraînement, mode chrono 60 s.
## Vraie physique (Jolt) : ballon, anneau (seize petites sphères) et panneau sont des corps solides.
## Le panier est vu comme marqué quand le ballon traverse le plan de l'anneau en descendant.
## Le noeud est placé aux pieds du joueur ; le panier est devant lui, vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const BALL_R := 0.07
const RIM_Y := 2.0
const RIM_R := 0.18                 # rayon intérieur de l'anneau
const RIM_TUBE := 0.012
const BOARD_SIZE := Vector2(1.1, 0.75)
const STAND := Vector3(0.36, 0.95, -0.2)
const GRAB_RADIUS := 0.38
const THROW_GAIN_H := 1.3
const THROW_GAIN_V := 1.15
const SHOTS := 10
const CHRONO_SECONDS := 60.0
const SAVE_PATH := "user://basket.cfg"
const L_WORLD := 1
const L_BALL := 2
const ROW_COLORS := [Color(0.2, 0.5, 1.0), Color(1.0, 0.35, 0.3), Color(0.3, 0.85, 0.4), Color(0.9, 0.5, 1.0)]
const AI_HAND := Vector3(-0.7, 1.45, -0.3)

const LEVELS := {
	"facile": {"title": "Facile", "assist": 0.85, "speed": 0.07, "angle": 0.06},
	"normal": {"title": "Normal", "assist": 0.55, "speed": 0.035, "angle": 0.03},
	"expert": {"title": "Expert", "assist": 0.2, "speed": 0.018, "angle": 0.015},
}

const ZONES := {
	"pres": {"title": "Près · 1 pt", "d": 2.0, "pts": 1},
	"moyen": {"title": "Moyen · 2 pts", "d": 3.0, "pts": 2},
	"loin": {"title": "Loin · 3 pts", "d": 4.2, "pts": 3},
}
const MIXED := ["moyen", "pres", "loin", "moyen", "loin", "pres", "moyen", "loin", "pres", "moyen"]

enum State { SETUP, TURN_WAIT, AI_WAIT, FLIGHT, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "players": 2, "level": "normal", "zone": "mixte", "format": "serie", "music": true}
var state := State.SETUP
var players: Array = []         # [{name, score, thrown, ai, streak}]
var current := 0
var hoop_z := -3.0
var _ball: RigidBody3D
var _held := false
var _held_hand: Hand = null
var _held_button := ""
var _flight := 0.0
var _timer := 0.0
var _think := 1.0
var _scored := false
var _above := false
var _contacts := 0              # touches de l'anneau ou du panneau pendant le tir
var _floor_hit := false
var _shot_zone := "moyen"
var _shots_total := 0
var _series_total := 0
var _chrono_left := 0.0
var _chrono_over := false
var _last_text := ""
var _hist: Array = []
var _hands: Array = []
var _field: Node3D
var _hoop: Node3D
var _board: MolkkyBoard
var _leo: Spectator
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _message: Label3D
var _message_time := 0.0
var _hint: Label3D
var _zone_label: Label3D
var _save := ConfigFile.new()

var _selftest := false
var _st_bot := false
var _st_log: Array = []
var _st_failures: Array = []
var _pending_scores: Array = []
var _last_points := 0


# ================================================================ mise en place

func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_load_save()
	_field = Node3D.new()
	add_child(_field)
	_build_ground()
	_build_stand()
	_build_ball()
	_hoop = Node3D.new()
	_hoop.name = "Panier"
	add_child(_hoop)
	_build_hoop()
	_board = MolkkyBoard.new()
	add_child(_board)
	_leo = Spectator.new({
		"name": "Léo", "skin": Color(0.62, 0.45, 0.34), "shirt": Color(0.9, 0.5, 0.1),
		"pants": Color(0.15, 0.15, 0.2), "hair": Color(0.08, 0.06, 0.05), "beard": false,
		"hat": false, "hat_color": Color(0.3, 0.3, 0.3),
	})
	add_child(_leo)
	_message = BowlingArt.neon_label("", 0.13, Color(1.0, 0.6, 0.2))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.no_depth_test = true
	_message.visible = false
	add_child(_message)
	_hint = BowlingArt.label("", 0.04, Color(1, 0.95, 0.7))
	_hint.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hint.no_depth_test = true
	add_child(_hint)
	_zone_label = BowlingArt.label("", 0.12, Color(1, 1, 1), 6)
	_zone_label.rotation_degrees = Vector3(-90, 0, 0)
	_zone_label.position = Vector3(0, 0.008, 0.0)
	add_child(_zone_label)
	_panel = UiPanel.new()
	_panel.accent = Color(0.95, 0.5, 0.15)
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


func _static_body(size: Vector3, pos: Vector3, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	body.add_child(cs)
	body.position = pos
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = bounce
	body.physics_material_override = pm
	return body


func _build_ground() -> void:
	var g := _static_body(Vector3(14.0, 0.2, 16.0), Vector3(0, -0.1, -5.0), 0.55)
	g.name = "Sol"
	g.set_meta("kind", "floor")
	add_child(g)


func _build_stand() -> void:
	var metal := BowlingArt.mat(Color(0.25, 0.27, 0.32), 0.35, 0.8)
	var rubber := BowlingArt.mat(Color(0.12, 0.12, 0.14), 0.8)
	add_child(BowlingArt.cylinder(0.18, 0.2, 0.025, metal, Vector3(STAND.x, 0.0125, STAND.z), 24))
	add_child(BowlingArt.cylinder(0.022, 0.03, STAND.y - 0.03, metal, Vector3(STAND.x, (STAND.y - 0.03) / 2.0, STAND.z), 16))
	add_child(BowlingArt.cylinder(0.075, 0.05, 0.05, rubber, Vector3(STAND.x, STAND.y - 0.025, STAND.z), 20))


func _ball_visual() -> Node3D:
	var n := Node3D.new()
	n.add_child(BowlingArt.sphere(BALL_R, BowlingArt.mat(Color(0.93, 0.45, 0.1), 0.75), Vector3.ZERO, 20))
	var seam := BowlingArt.mat(Color(0.08, 0.05, 0.03), 0.8)
	for k in 3:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BALL_R - 0.0015
		tm.outer_radius = BALL_R + 0.0025
		tm.rings = 20
		tm.ring_segments = 6
		t.mesh = tm
		t.material_override = seam
		t.rotation = Vector3(0, 0, 0) if k == 0 else (Vector3(PI / 2.0, 0, 0) if k == 1 else Vector3(0, 0, PI / 2.0))
		n.add_child(t)
	return n


func _build_ball() -> void:
	_ball = RigidBody3D.new()
	_ball.name = "Ballon"
	_ball.collision_layer = L_BALL
	_ball.collision_mask = L_WORLD
	_ball.mass = 0.35
	_ball.continuous_cd = true
	_ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_ball.linear_damp = 0.0
	_ball.angular_damp = 0.4
	_ball.contact_monitor = true
	_ball.max_contacts_reported = 6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.55
	_ball.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	cs.shape = sh
	_ball.add_child(cs)
	_ball.add_child(_ball_visual())
	_ball.freeze = true
	_ball.visible = false
	_ball.body_entered.connect(_on_ball_contact)
	add_child(_ball)


func _build_hoop() -> void:
	var white := BowlingArt.mat(Color(0.92, 0.94, 1.0, 0.35), 0.2)
	var red := BowlingArt.unshaded(Color(0.9, 0.15, 0.12))
	var orange := BowlingArt.mat(Color(1.0, 0.4, 0.05), 0.35, 0.4)
	var metal := BowlingArt.mat(Color(0.25, 0.27, 0.32), 0.35, 0.8)
	var back_z := -(RIM_R + RIM_TUBE + 0.04)
	var by := RIM_Y + 0.27
	# Panneau (visuel + collision)
	_hoop.add_child(BowlingArt.box(Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.03), white, Vector3(0, by, back_z)))
	for sx in [-1.0, 1.0]:
		_hoop.add_child(BowlingArt.box(Vector3(0.025, BOARD_SIZE.y, 0.04), metal, Vector3(sx * (BOARD_SIZE.x / 2.0), by, back_z)))
	for sy in [-1.0, 1.0]:
		_hoop.add_child(BowlingArt.box(Vector3(BOARD_SIZE.x, 0.025, 0.04), metal, Vector3(0, by + sy * (BOARD_SIZE.y / 2.0), back_z)))
	# Carré rouge derrière l'anneau
	var sq := Vector2(0.5, 0.36)
	var sq_y := RIM_Y + 0.17
	for sx in [-1.0, 1.0]:
		_hoop.add_child(BowlingArt.box(Vector3(0.012, sq.y, 0.004), red, Vector3(sx * sq.x / 2.0, sq_y, back_z + 0.018)))
	for sy in [-1.0, 1.0]:
		_hoop.add_child(BowlingArt.box(Vector3(sq.x, 0.012, 0.004), red, Vector3(0, sq_y + sy * sq.y / 2.0, back_z + 0.018)))
	var board_body := _static_body(Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.05), Vector3(0, by, back_z), 0.5)
	board_body.set_meta("kind", "board")
	_hoop.add_child(board_body)
	# Anneau : tore orange et seize sphères de collision
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RIM_R
	tm.outer_radius = RIM_R + RIM_TUBE * 2.0
	tm.rings = 32
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = orange
	rim.position = Vector3(0, RIM_Y, 0)
	_hoop.add_child(rim)
	var rim_body := StaticBody3D.new()
	rim_body.collision_layer = L_WORLD
	rim_body.collision_mask = 0
	rim_body.set_meta("kind", "rim")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.35
	rim_body.physics_material_override = pm
	var ring_r := RIM_R + RIM_TUBE
	for k in 16:
		var a := TAU * k / 16.0
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = RIM_TUBE * 1.15
		cs.shape = sp
		cs.position = Vector3(cos(a) * ring_r, 0.0, sin(a) * ring_r)
		rim_body.add_child(cs)
	rim_body.position = Vector3(0, RIM_Y, 0)
	_hoop.add_child(rim_body)
	# Console qui relie l'anneau au panneau
	_hoop.add_child(BowlingArt.box(Vector3(0.06, 0.02, 0.08), orange, Vector3(0, RIM_Y, -(RIM_R + RIM_TUBE * 2.0 + 0.0))))
	# Filet : seize brins et deux anneaux
	var net_mat := BowlingArt.mat(Color(1, 1, 1, 0.8), 0.9)
	var h := 0.36
	var r1 := RIM_R + RIM_TUBE
	var r2 := 0.085
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		var top := Vector3(cos(a) * r1, RIM_Y - 0.01, sin(a) * r1)
		var bot := Vector3(cos(a + 0.35) * r2, RIM_Y - h, sin(a + 0.35) * r2)
		var seg := BowlingArt.box(Vector3(0.004, 0.004, top.distance_to(bot)), net_mat, (top + bot) / 2.0)
		seg.look_at_from_position((top + bot) / 2.0, bot, Vector3.UP)
		_hoop.add_child(seg)
	for f in [0.35, 0.7]:
		var rr := lerpf(r1, r2, f)
		var ring := MeshInstance3D.new()
		var rt := TorusMesh.new()
		rt.inner_radius = rr - 0.003
		rt.outer_radius = rr + 0.003
		rt.rings = 24
		rt.ring_segments = 4
		ring.mesh = rt
		ring.material_override = net_mat
		ring.position = Vector3(0, RIM_Y - 0.01 - h * f, 0)
		_hoop.add_child(ring)
	# Poteau derrière le panneau, pied lesté
	var pole_z := back_z - 0.45
	_hoop.add_child(BowlingArt.cylinder(0.04, 0.05, RIM_Y + 0.7, metal, Vector3(0, (RIM_Y + 0.7) / 2.0, pole_z), 12))
	_hoop.add_child(BowlingArt.box(Vector3(0.05, 0.05, 0.45), metal, Vector3(0, by, back_z - 0.22)))
	_hoop.add_child(BowlingArt.box(Vector3(0.9, 0.12, 0.7), BowlingArt.mat(Color(0.12, 0.12, 0.15), 0.8), Vector3(0, 0.06, pole_z)))


func _apply_layout() -> void:
	for ch in _field.get_children():
		ch.queue_free()
	var floor_m := BowlingArt.surface_material("wood", Color(0.62, 0.42, 0.2), Vector2(7, 9))
	_field.add_child(BowlingArt.floor_quad(6.0, 9.0, floor_m, Vector3(0, 0.001, -3.5)))
	_field.add_child(BowlingArt.box(Vector3(1.6, 0.004, 0.05), BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, 0.003, -0.25)))
	var zb := -7.2
	var wall := BowlingArt.mat(Color(0.2, 0.28, 0.45), 0.95)
	_field.add_child(BowlingArt.box(Vector3(6.0, 3.0, 0.12), wall, Vector3(0, 1.5, zb)))
	var sign_node := Decor.neon_sign("BASKET", Color(1.0, 0.55, 0.15), 1.5, 0.45)
	sign_node.position = Vector3(-1.9, 2.5, zb + 0.08)
	_field.add_child(sign_node)
	_field.add_child(Decor.rug(Vector2(3.0, 5.0), Color(0.55, 0.1, 0.08), Vector3(0, 0.003, -3.6)))
	for sx in [-1.0, 1.0]:
		var bench := Decor.bench()
		bench.position = Vector3(sx * 2.5, 0, -2.6)
		bench.rotation.y = -sx * PI / 2.0
		_field.add_child(bench)
		var l := Decor.lamp(2.4)
		l.position = Vector3(sx * 2.7, 0, -5.4)
		_field.add_child(l)
	var bunting := Decor.bunting(4.0, 11)
	bunting.position = Vector3(0, 2.9, zb + 0.15)
	_field.add_child(bunting)
	_board.position = Vector3(-2.0, 1.45, -1.8)
	var face := Vector3(0.0, 0, 1.0) - _board.position
	_board.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_board.scale = Vector3.ONE * 1.1
	_leo.position = Vector3(-1.0, 0, 0.15)
	_leo.rotation.y = deg_to_rad(25.0)
	_leo.visible = settings["mode"] == "ordi"
	_hint.position = STAND + Vector3(0, 0.28, 0)
	_set_zone(_zone_for(0))
	_board.set_data("BASKET", [], 0, 0, "")


func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


# ================================================================ zones

func _zone_for(shot_index: int) -> String:
	var z := String(settings["zone"])
	if z == "mixte":
		return MIXED[shot_index % MIXED.size()]
	return z


func zone_points(zone: String) -> int:
	return int(ZONES[zone]["pts"])


func _set_zone(zone: String) -> void:
	_shot_zone = zone
	hoop_z = -float(ZONES[zone]["d"])
	_hoop.position = Vector3(0, 0, hoop_z)
	_message.position = Vector3(0, 1.7, hoop_z)
	_zone_label.text = "%d pt%s" % [zone_points(zone), "s" if zone_points(zone) > 1 else ""]
	_zone_label.modulate = [Color(0.6, 1, 0.6), Color(1, 0.9, 0.4), Color(1, 0.55, 0.3)][["pres", "moyen", "loin"].find(zone)]


# ================================================================ menus

func is_training() -> bool:
	return settings["mode"] == "training"


func is_chrono() -> bool:
	return is_training() and settings["format"] == "chrono"


func show_setup() -> void:
	state = State.SETUP
	_drop_ball()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Basket", "Victoires : %d   ·   meilleure série : %d pts   ·   chrono : %d pts" % [_stat("wins"), _stat("best_series"), _stat("best_chrono")])
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
	if is_training():
		_panel.add_row("Format", [
			{"id": "format_serie", "text": "10 tirs", "width": 0.2, "selected": settings["format"] == "serie"},
			{"id": "format_chrono", "text": "Chrono 60 s", "width": 0.26, "selected": settings["format"] == "chrono"},
		])
	_panel.add_row("Zone", [
		{"id": "zone_pres", "text": "Près 1", "width": 0.16, "selected": settings["zone"] == "pres"},
		{"id": "zone_moyen", "text": "Moyen 2", "width": 0.18, "selected": settings["zone"] == "moyen"},
		{"id": "zone_loin", "text": "Loin 3", "width": 0.16, "selected": settings["zone"] == "loin"},
		{"id": "zone_mixte", "text": "Mixte", "width": 0.16, "selected": settings["zone"] == "mixte"},
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
	_drop_ball()
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
	elif id.begins_with("format_"):
		settings["format"] = id.substr(7)
	elif id.begins_with("zone_"):
		settings["zone"] = id.substr(5)
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

func shots_per_player() -> int:
	return SHOTS


func start_match() -> void:
	_apply_layout()
	players.clear()
	match String(settings["mode"]):
		"ordi":
			players.append({"name": "VOUS", "score": 0, "thrown": 0, "ai": false, "streak": 0})
			players.append({"name": "LÉO", "score": 0, "thrown": 0, "ai": true, "streak": 0})
		"deux":
			for i in int(settings["players"]):
				players.append({"name": "J%d" % (i + 1), "score": 0, "thrown": 0, "ai": false, "streak": 0})
		_:
			players.append({"name": "VOUS", "score": 0, "thrown": 0, "ai": false, "streak": 0})
	current = 0
	_series_total = 0
	_shots_total = 0
	_last_text = ""
	_chrono_over = false
	_chrono_left = CHRONO_SECONDS if is_chrono() else 0.0
	_hist.clear()
	_begin_turn()


func _begin_turn() -> void:
	var p: Dictionary = players[current]
	var idx := _shots_total if is_chrono() else int(p["thrown"])
	_set_zone(_zone_for(idx))
	_update_board()
	if _st_bot or bool(p["ai"]):
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""
		_ball.visible = false
		if not _st_bot and players.size() > 1:
			_announce("Au tour de %s" % String(p["name"]).capitalize(), Color(1.0, 0.6, 0.2), 1.2)
	else:
		state = State.TURN_WAIT
		_put_ball_on_stand()
		_hint.text = "Attrape le ballon (gâchette ou grip)\net lance-le en cloche vers le panier"
		if players.size() > 1:
			_announce("%s, à toi !" % String(p["name"]).capitalize(), Color(1.0, 0.6, 0.2), 1.4)


func _put_ball_on_stand() -> void:
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.transform = Transform3D(Basis.IDENTITY, STAND + Vector3(0, BALL_R * 0.75, 0))
	_ball.visible = true
	_held = false
	_held_hand = null


func _drop_ball() -> void:
	_held = false
	_held_hand = null
	_held_button = ""
	_ball.visible = false
	_ball.freeze = true
	_hint.text = ""


func _launch(from: Vector3, vel: Vector3) -> void:
	_ball.freeze = true
	_ball.transform = Transform3D(Basis.IDENTITY, from)
	_ball.visible = true
	_ball.freeze = false
	_ball.sleeping = false
	_ball.linear_velocity = vel
	_ball.angular_velocity = Vector3(-4.0, 0.0, 0.0)
	_held = false
	_held_hand = null
	_held_button = ""
	_flight = 0.0
	_scored = false
	_above = false
	_contacts = 0
	_floor_hit = false
	state = State.FLIGHT
	_hint.text = ""
	Sound.play_at("whoosh", to_global(from), -10.0, 0.1)


# ---------------------------------------------------------------- lancer humain

func _hand_item_pos(h: Hand) -> Vector3:
	var gt := global_transform.affine_inverse() * h.global_transform
	return (gt * Transform3D(Basis(), Vector3(0, -0.02, -0.08))).origin


func _try_grab(hand: Hand, button: String) -> void:
	if state != State.TURN_WAIT or _held:
		return
	if _hand_item_pos(hand).distance_to(_ball.position) > GRAB_RADIUS:
		return
	_held = true
	_held_hand = hand
	_held_button = button
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	Sound.play_at("grab", to_global(_ball.position), -6.0, 0.05)
	_hint.text = ""


func _release_held(hand: Hand) -> void:
	if not _held or _held_hand != hand:
		return
	var p := _hand_item_pos(hand)
	var v := global_basis.inverse() * hand.throw_velocity()
	_held = false
	_held_hand = null
	_held_button = ""
	_throw(p, v)


## Lance le ballon tenu : `p` position, `vel` vitesse de la main.
func _throw(p: Vector3, vel: Vector3) -> void:
	if vel.length() < 1.5:
		_put_ball_on_stand()
		_hint.text = "Lance plus fort !"
		return
	vel = Vector3(vel.x * THROW_GAIN_H, vel.y * THROW_GAIN_V, vel.z * THROW_GAIN_H)
	vel = vel.limit_length(11.0)
	vel = _assist(p, vel)
	_launch(p, vel)


## Instant où le ballon, en descendant, traverse la hauteur de l'anneau (-1 s'il n'y arrive pas).
func cross_time(p: Vector3, v: Vector3) -> float:
	var disc := v.y * v.y + 2.0 * 9.81 * (p.y - RIM_Y)
	if disc < 0.0:
		return -1.0
	return (v.y + sqrt(disc)) / 9.81


## Aide : si le ballon monte assez haut pour atteindre l'anneau, sa course est ramenée vers
## le centre du panier (beaucoup en Facile, peu en Expert). Un tir trop plat n'est pas aidé.
func _assist(p: Vector3, v: Vector3) -> Vector3:
	var a: float = LEVELS.get(settings["level"], LEVELS["normal"])["assist"]
	var t := cross_time(p, v)
	if t < 0.15:
		return v
	var land := Vector2(p.x + v.x * t, p.z + v.z * t)
	var err := Vector2(0.0, hoop_z) - land
	return Vector3(v.x + err.x / t * a, v.y, v.z + err.y / t * a)


# ================================================================ physique et déroulement

func _on_ball_contact(body: Node) -> void:
	if state != State.FLIGHT:
		return
	var kind := String(body.get_meta("kind", ""))
	var pos := to_global(_ball.position)
	match kind:
		"rim":
			_contacts += 1
			Sound.play_at("pet_clack", pos, -6.0, 0.15)
		"board":
			_contacts += 1
			Sound.play_at("pp_table", pos, -4.0, 0.1)
		"floor":
			_floor_hit = true
			Sound.play_at("ball_thud", pos, -6.0, 0.1)


func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.visible = false
	if _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)
		return
	if is_chrono() and not _chrono_over and state in [State.TURN_WAIT, State.AI_WAIT, State.FLIGHT, State.PAUSE]:
		_chrono_left -= delta
		if _chrono_left <= 0.0:
			_chrono_left = 0.0
			_chrono_over = true
		_update_board_timer()
	match state:
		State.TURN_WAIT:
			if _chrono_over:
				_end_match()
			elif _held and _held_hand != null and is_instance_valid(_held_hand):
				_ball.position = _hand_item_pos(_held_hand)
		State.AI_WAIT:
			if _chrono_over:
				_end_match()
				return
			_timer -= delta
			if _timer <= 0.0:
				_ai_throw()
		State.FLIGHT:
			_flight += delta
			_watch_ball(delta)
			var p := _ball.position
			var out := absf(p.x) > 6.0 or p.z < -9.0 or p.z > 3.0
			if _floor_hit or _flight > 7.0 or out:
				_evaluate()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()


func _watch_ball(_delta: float) -> void:
	var p := _ball.position
	if p.y >= RIM_Y + 0.02:
		_above = true
	if _scored:
		# Dans le filet : le ballon est freiné et glisse vers le bas
		if p.y < RIM_Y and p.y > RIM_Y - 0.4 and Vector2(p.x, p.z - hoop_z).length() < RIM_R:
			var v := _ball.linear_velocity
			_ball.linear_velocity = Vector3(v.x * 0.9, v.y * 0.97, v.z * 0.9)
		return
	var d := Vector2(p.x, p.z - hoop_z).length()
	if _above and p.y < RIM_Y and p.y > RIM_Y - 0.12 and _ball.linear_velocity.y < 0.0 and d < RIM_R - 0.02:
		_scored = true
		var pos := to_global(Vector3(0, RIM_Y - 0.1, hoop_z))
		if _contacts == 0:
			Sound.play_at("pp_net", pos, -2.0, 0.0)
			Sound.play_at("cheer_small", pos, -6.0, 0.0)
		else:
			Sound.play_at("pp_net", pos, -6.0, 0.1)


func _evaluate() -> void:
	if state != State.FLIGHT:
		return
	var pts := 0
	var text := "Raté"
	if _scored:
		pts = zone_points(_shot_zone)
		text = ("Swish +%d" if _contacts == 0 else "Panier +%d") % pts
	_last_points = pts
	_register(pts, text)


func _register(pts: int, text: String) -> void:
	var p: Dictionary = players[current]
	p["score"] = int(p["score"]) + pts
	p["thrown"] = int(p["thrown"]) + 1
	_hist.append(pts)
	_shots_total += 1
	_last_text = text
	_series_total += pts
	if pts > 0:
		p["streak"] = int(p["streak"]) + 1
		if int(p["streak"]) >= 3:
			_announce("En feu ! %s" % text, Color(1.0, 0.45, 0.1), 1.8)
			_board.celebrate("point")
		else:
			_announce(text, Color(1.0, 0.8, 0.2), 1.5)
			_board.celebrate("point")
		if _contacts == 0 and not _st_bot and bool(p["ai"]):
			_leo.react("win")
	else:
		p["streak"] = 0
		_announce("Raté…", Color(0.8, 0.8, 0.85), 1.2)
	_update_board()
	state = State.PAUSE
	_timer = 0.2 if _st_bot else 0.9
	_ball.freeze = true
	_ball.visible = false


func _after_pause() -> void:
	if is_chrono():
		if _chrono_over:
			_end_match()
		else:
			_begin_turn()
		return
	var per := shots_per_player()
	var done := true
	for p in players:
		if int(p["thrown"]) < per:
			done = false
	if done:
		_end_match()
		return
	var n := players.size()
	var i := current
	for k in n:
		i = (i + 1) % n
		if int(players[i]["thrown"]) < per:
			break
	current = i
	_begin_turn()


func _end_match() -> void:
	if state == State.GAME_OVER:
		return
	if is_training():
		_best_stat("best_chrono" if is_chrono() else "best_series", _series_total)
		_pending_scores.append(_series_total)
		_game_over(0)
		return
	var best := 0
	for i in players.size():
		if int(players[i]["score"]) > int(players[best]["score"]):
			best = i
	_game_over(best)


func _game_over(winner: int) -> void:
	state = State.GAME_OVER
	_ball.visible = false
	var summary := ""
	if is_training():
		if is_chrono():
			summary = "%d points en 60 secondes (%d tirs)" % [_series_total, _shots_total]
		else:
			summary = "%d points en %d tirs" % [_series_total, SHOTS]
		_board.celebrate("win")
	else:
		var top := int(players[winner]["score"])
		var tie := false
		for i in players.size():
			if i != winner and int(players[i]["score"]) == top:
				tie = true
		if tie:
			summary = "Égalité à %d points !" % top
		else:
			summary = "%s gagne avec %d points !" % [String(players[winner]["name"]).capitalize(), top]
			_board.celebrate("win")
			if winner == 0 and settings["mode"] == "ordi":
				_bump_stat("wins")
			elif settings["mode"] == "ordi":
				_leo.react("win")
	_announce("%s" % summary, Color(1, 0.8, 0.2), 3.0)
	_update_board()
	if _selftest:
		return
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _update_board() -> void:
	var title := "BASKET"
	var foot := ""
	if is_training():
		title = "BASKET · CHRONO" if is_chrono() else "BASKET · ENTRAÎNEMENT"
		if is_chrono():
			foot = "Temps : %d s · tirs : %d · %s" % [int(ceil(_chrono_left)), _shots_total, _last_text if _last_text != "" else "—"]
		else:
			var p0: Dictionary = players[0] if not players.is_empty() else {"thrown": 0}
			foot = "Tir %d sur %d · %s · dernier : %s" % [mini(int(p0["thrown"]) + 1, SHOTS), SHOTS, String(ZONES[_shot_zone]["title"]), _last_text if _last_text != "" else "—"]
	elif not players.is_empty():
		var p: Dictionary = players[current]
		title = "BASKET · 10 TIRS"
		foot = "%s : tir %d sur %d · %s" % [String(p["name"]).capitalize(), mini(int(p["thrown"]) + 1, SHOTS), SHOTS, String(ZONES[_shot_zone]["title"])]
	var rows: Array = []
	for p in players:
		rows.append({"name": p["name"], "score": p["score"], "misses": 0, "out": false})
	_board.set_data(title, rows, current, 0, foot)


func _update_board_timer() -> void:
	if int(ceil(_chrono_left)) != int(ceil(_chrono_left + 0.02)) or _chrono_left <= 0.0:
		_update_board()


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


## Vitesse de lancer qui amène le ballon au centre de l'anneau depuis `from` (apex à `rise` m au-dessus).
func ideal_velocity(from: Vector3, rise: float = 1.1) -> Vector3:
	var vy := sqrt(2.0 * 9.81 * (RIM_Y + rise - from.y))
	var t := (vy + sqrt(vy * vy + 2.0 * 9.81 * (from.y - RIM_Y))) / 9.81
	return Vector3((0.0 - from.x) / t, vy, (hoop_z - from.z) / t)


func _ai_throw() -> void:
	var lvl: Dictionary = LEVELS[settings["level"]]
	_ai_shoot(float(lvl["speed"]), float(lvl["angle"]))


## Tir de l'adversaire avec erreurs relatives de vitesse et d'angle (en radians).
func _ai_shoot(speed_sigma: float, angle_sigma: float) -> void:
	var v := ideal_velocity(AI_HAND, 0.9 + randf() * 0.4)
	v *= 1.0 + _gauss() * speed_sigma
	var yaw := _gauss() * angle_sigma
	v = Vector3(v.x * cos(yaw) - v.z * sin(yaw), v.y, v.x * sin(yaw) + v.z * cos(yaw))
	_launch(AI_HAND, v)


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
	if settings["format"] not in ["serie", "chrono"]:
		settings["format"] = "serie"
	if settings["zone"] not in ["pres", "moyen", "loin", "mixte"]:
		settings["zone"] = "mixte"
	if int(settings["players"]) not in [2, 3, 4]:
		settings["players"] = 2


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	if _save.save(SAVE_PATH) != OK:
		push_warning("Basket : réglages non sauvegardés")


func _stat(key: String) -> int:
	return int(_save.get_value("records", key, 0))


func _bump_stat(key: String) -> void:
	_save.set_value("records", key, _stat(key) + 1)
	if _save.save(SAVE_PATH) != OK:
		push_warning("Basket : record non sauvegardé")


func _best_stat(key: String, value: int) -> void:
	if value > _stat(key):
		_save.set_value("records", key, value)
		if _save.save(SAVE_PATH) != OK:
			push_warning("Basket : record non sauvegardé")


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
	settings["zone"] = "moyen"
	settings["format"] = "serie"
	_apply_layout()
	await _wait_frames(3)

	# A. Géométrie : anneau à 2 m, zones 1/2/3 points, panneau derrière l'anneau
	_st_check("zones 1 / 2 / 3 points", zone_points("pres") == 1 and zone_points("moyen") == 2 and zone_points("loin") == 3 and MIXED.size() == 10, "")
	var kinds := {}
	for n in _hoop.get_children():
		if n is StaticBody3D:
			kinds[String(n.get_meta("kind", ""))] = true
	_st_check("anneau et panneau solides", kinds.has("rim") and kinds.has("board") and _hoop.get_child_count() > 30, str(kinds.keys()))

	# B. Un lancer parfait entre dans le panier dans chaque zone (sans toucher l'anneau)
	players = [{"name": "A", "score": 0, "thrown": 0, "ai": false, "streak": 0}]
	current = 0
	var wrong: Array = []
	for z in ["pres", "moyen", "loin"]:
		settings["zone"] = z
		_set_zone(z)
		players[0]["thrown"] = 0
		var v := ideal_velocity(AI_HAND, 1.1)
		_launch(AI_HAND, v)
		await _wait_state(State.PAUSE, 90 * 10)
		if _last_points != zone_points(z):
			wrong.append("%s=%d" % [z, _last_points])
		_flight = 0.0
		state = State.SETUP
	_st_check("tir parfait marqué", wrong.is_empty(), str(wrong))

	# C. Un tir trop court ou trop long ne marque pas et ne bloque pas
	settings["zone"] = "moyen"
	_set_zone("moyen")
	var bad := 0
	for k in [0.6, 1.5]:
		players[0]["thrown"] = 0
		_launch(AI_HAND, ideal_velocity(AI_HAND, 1.1) * k)
		await _wait_state(State.PAUSE, 90 * 10)
		if _last_points != 0 or state != State.PAUSE:
			bad += 1
		_flight = 0.0
		state = State.SETUP
	_st_check("tirs manqués : 0 point", bad == 0, "")

	# D. Parties complètes : adversaire, joueurs virtuels
	for mode in ["ordi", "deux"]:
		settings["mode"] = mode
		settings["players"] = 3
		settings["zone"] = "mixte"
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 400:
			await get_tree().physics_frame
			guard += 1
		var scores: Array = []
		for p in players:
			scores.append(int(p["score"]))
		_st_check("partie %s terminée" % mode, state == State.GAME_OVER and _hist.size() == SHOTS * players.size(), "%s en %.0f s ; %s" % [str(scores), guard / 90.0, str(_hist)])

	# E. Entraînement : série de 10 tirs, puis chrono de 60 s
	settings["mode"] = "training"
	settings["format"] = "serie"
	_pending_scores.clear()
	start_match()
	var g2 := 0
	while _pending_scores.is_empty() and g2 < 90 * 300:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement : série", not _pending_scores.is_empty() and _hist.size() == SHOTS, "(%s pts en %.0f s)" % [str(_pending_scores), g2 / 90.0])
	settings["format"] = "chrono"
	_pending_scores.clear()
	start_match()
	g2 = 0
	while _pending_scores.is_empty() and g2 < 90 * 200:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement : chrono", not _pending_scores.is_empty() and _shots_total >= 10 and g2 > 90 * 55, "(%s pts, %d tirs en %.0f s)" % [str(_pending_scores), _shots_total, g2 / 90.0])
	_st_bot = false

	# F. Adresse de l'adversaire : l'expert marque plus que le niveau facile
	var rates := {}
	settings["mode"] = "deux"
	settings["zone"] = "moyen"
	for lvl in ["facile", "expert"]:
		settings["level"] = lvl
		players = [{"name": "A", "score": 0, "thrown": 0, "ai": false, "streak": 0}]
		current = 0
		_set_zone("moyen")
		var made := 0
		for k in 20:
			players[0]["thrown"] = 0
			_ai_shoot(float(LEVELS[lvl]["speed"]) * 1.6, float(LEVELS[lvl]["angle"]) * 1.6)
			await _wait_state(State.PAUSE, 90 * 10)
			if _last_points > 0:
				made += 1
			_flight = 0.0
			state = State.SETUP
		rates[lvl] = made
	_st_check("adresse de l'adversaire", int(rates["expert"]) > int(rates["facile"]) and int(rates["expert"]) >= 5, str(rates))

	# G. Lancer humain simulé : l'aide ramène un tir correct vers le panier
	settings["mode"] = "deux"
	settings["players"] = 2
	settings["level"] = "facile"
	settings["zone"] = "moyen"
	start_match()
	await _wait_frames(2)
	_st_check("tour du joueur", state == State.TURN_WAIT and _ball.visible, str(state))
	var hp := Vector3(0.3, 1.3, 0.0)
	var hv := ideal_velocity(hp, 1.1) + Vector3(0.4, 0.0, 0.2)
	_held = true
	_throw(hp, Vector3(hv.x / THROW_GAIN_H, hv.y / THROW_GAIN_V, hv.z / THROW_GAIN_H))
	await _wait_state(State.PAUSE, 90 * 10)
	_st_check("lancer humain aidé", state == State.PAUSE and _last_points == 2, "(%d pts)" % _last_points)

	_drop_ball()
	for line in _st_log:
		print("SELFTEST basket ", line)
	print("SELFTEST basket=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
