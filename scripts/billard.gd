class_name BillardGame
extends Node3D
## Billard en réalité augmentée : un grand tapis vert devant le joueur, une queue que l'on
## attrape et avec laquelle on frappe la blanche. Deux variantes : 8 boules (pleines contre
## rayées) et 9 boules (toujours la plus petite en premier). Physique maison (billes à plat,
## bandes, poches) : stable et prévisible. Le noeud est aux pieds du joueur ; le tapis est à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const R := 0.0285             # rayon d'une bille
const PX := 0.95              # demi-longueur du tapis (entre les bandes)
const PZ := 0.475             # demi-largeur
const TABLE_Y := 0.80         # hauteur du tapis
const TZ := -1.25             # position du centre du tapis (z)
const SUBSTEPS := 8
const DECEL := 0.32           # ralentissement du roulement (m/s²)
const E_CUSHION := 0.74
const E_BALL := 0.95
const CORNER_CAP := 0.075
const SIDE_CAP := 0.062
const CUE_TIP := 0.6          # distance main - pointe de la queue
const CUE_BACK := 0.4
const GRAB_RADIUS := 0.5
const HEAD_X := -0.475
const FOOT_X := 0.475
const MAX_SHOTS := 70         # au-delà, l'arbitre tranche (pour que les parties finissent)
const SAVE_PATH := "user://billard.cfg"
const PLAYER := 1
const AI := -1
const CLR_PLAYER := Color(0.45, 0.65, 1.0)
const CLR_AI := Color(0.95, 0.5, 0.3)
const RACK_POS := Vector3(0.85, 0.98, -0.35)

const LEVELS := {
	"facile": {"title": "Facile", "sigma": 0.050, "guide": true},
	"normal": {"title": "Normal", "sigma": 0.024, "guide": true},
	"expert": {"title": "Expert", "sigma": 0.009, "guide": false},
}

enum State { SETUP, AIM, PLACE, ROLL, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "variant": "8", "level": "normal", "music": true}
var state := State.SETUP
var scores := [0, 0]            # billes empochées par chaque joueur
var groups := ["", ""]          # "solid" / "stripe" par joueur (8 boules)
var to_play := PLAYER
var starter := PLAYER
var _balls: Array[BillBall] = []
var _cue_ball: BillBall = null
var _is_break := true
var _in_hand := false
var _head_only := false
var _first_hit := -1
var _shot_potted: Array[int] = []
var _cue_potted := false
var _shots := 0
var _train_shots := 0
var _timer := 0.0
var _think := 1.4
var _pause_next := ""
var _clacks := 0
var _sigma_override := -1.0

var _hands: Array = []
var _table: Node3D
var _balls_root: Node3D
var _cue: Node3D
var _cue_hand: Hand = null
var _cue_button := ""
var _prev_tip := Vector3.ZERO
var _have_prev := false
var _held_ball := false
var _ball_hand: Hand = null
var _ball_button := ""
var _guide_line: MeshInstance3D
var _guide_ghost: MeshInstance3D
var _guide_dir: MeshInstance3D
var _bob: Spectator
var _scoreboard: PingScoreboard
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


# ================================================================ mise en place

func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_load_save()
	_table = Node3D.new()
	add_child(_table)
	_balls_root = Node3D.new()
	add_child(_balls_root)
	_build_table()
	_build_decor()
	_build_cue()
	_build_guide()

	_scoreboard = PingScoreboard.new()
	add_child(_scoreboard)
	_bob = Spectator.new({
		"name": "Bob", "skin": Color(0.85, 0.65, 0.55), "shirt": Color(0.55, 0.12, 0.15),
		"pants": Color(0.12, 0.12, 0.18), "hair": Color(0.15, 0.1, 0.08), "beard": true,
		"hat": false, "hat_color": Color(0.1, 0.1, 0.12),
	})
	add_child(_bob)
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
	_panel.floor_clearance = TABLE_Y + 0.35
	_panel.accent = Color(0.2, 0.85, 0.55)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)

	_scoreboard.position = Vector3(1.9, 1.45, -2.4)
	_scoreboard.scale = Vector3.ONE * 1.15
	var face := Vector3(0, 0, 1.0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_bob.position = Vector3(-2.0, 0, -2.0)
	_bob.rotation.y = deg_to_rad(60.0)
	_message.position = Vector3(0, 1.75, -2.3)
	_hint.position = Vector3(0, 1.25, -0.55)
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	_rack_balls()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


func _w(p: Vector2) -> Vector3:
	return Vector3(p.x, TABLE_Y + R, TZ + p.y)


func _pockets() -> Array:
	return [
		[Vector2(-PX, -PZ), CORNER_CAP], [Vector2(PX, -PZ), CORNER_CAP],
		[Vector2(-PX, PZ), CORNER_CAP], [Vector2(PX, PZ), CORNER_CAP],
		[Vector2(0, -PZ), SIDE_CAP], [Vector2(0, PZ), SIDE_CAP],
	]


func _build_table() -> void:
	var wood := BowlingArt.surface_material("wood", Color(0.38, 0.22, 0.11), Vector2(3, 1))
	var felt := BowlingArt.surface_material("fabric", Color(0.045, 0.43, 0.29), Vector2(6, 3))
	var cushion := BowlingArt.mat(Color(0.04, 0.33, 0.17), 0.9)
	var cx := 0.0
	# Tapis
	_table.add_child(BowlingArt.box(Vector3(PX * 2 + 0.1, 0.04, PZ * 2 + 0.1), felt, Vector3(cx, TABLE_Y - 0.02, TZ)))
	# Bandes (coussins) et cadre en bois
	var rail_w := 0.14
	for sz in [-1.0, 1.0]:
		_table.add_child(BowlingArt.box(Vector3(PX * 2 + 0.3, 0.07, rail_w), wood, Vector3(0, TABLE_Y + 0.0, TZ + sz * (PZ + 0.05 + rail_w / 2.0))))
		_table.add_child(BowlingArt.box(Vector3(PX * 2 - 0.2, 0.035, 0.05), cushion, Vector3(0, TABLE_Y + 0.0175, TZ + sz * (PZ + 0.025))))
	for sx in [-1.0, 1.0]:
		_table.add_child(BowlingArt.box(Vector3(rail_w, 0.07, PZ * 2 + 0.1), wood, Vector3(sx * (PX + 0.05 + rail_w / 2.0), TABLE_Y + 0.0, TZ)))
		_table.add_child(BowlingArt.box(Vector3(0.05, 0.035, PZ * 2 - 0.2), cushion, Vector3(sx * (PX + 0.025), TABLE_Y + 0.0175, TZ)))
	# Poches
	for p in _pockets():
		var pp: Vector2 = p[0]
		var cap: float = p[1]
		_table.add_child(BowlingArt.cylinder(cap * 0.85, cap * 0.85, 0.012, BowlingArt.unshaded(Color(0.01, 0.01, 0.01)), Vector3(pp.x * 1.01, TABLE_Y + 0.003, TZ + pp.y * 1.01), 20))
	# Losanges (repères) sur le bois
	var dia := BowlingArt.mat(Color(0.9, 0.85, 0.6), 0.4)
	for i in 3:
		for sz in [-1.0, 1.0]:
			_table.add_child(BowlingArt.box(Vector3(0.025, 0.004, 0.025), dia, Vector3(-PX * 0.5 + i * PX * 0.5, TABLE_Y + 0.036, TZ + sz * (PZ + 0.05 + rail_w / 2.0))))
	# Points de départ
	var spot := BowlingArt.unshaded(Color(1, 1, 1, 0.5))
	for sx in [HEAD_X, FOOT_X]:
		_table.add_child(BowlingArt.cylinder(0.008, 0.008, 0.001, spot, Vector3(sx, TABLE_Y + 0.001, TZ), 12))
	# Pieds et jupe
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_table.add_child(BowlingArt.box(Vector3(0.14, TABLE_Y - 0.05, 0.14), wood, Vector3(sx * (PX - 0.1), (TABLE_Y - 0.05) / 2.0, TZ + sz * (PZ - 0.1))))
	_table.add_child(BowlingArt.box(Vector3(PX * 2 + 0.3, 0.1, PZ * 2 + 0.3), wood.duplicate(), Vector3(0, TABLE_Y - 0.09, TZ)))


func _build_decor() -> void:
	_table.add_child(Decor.sport_corner("pub", Vector3(-1.45, 0, TZ - 1.28)))
	# Tapis de sol, lampe suspendue, enseigne au mur du fond, plantes
	_table.add_child(Decor.rug(Vector2(4.2, 3.2), Color(0.35, 0.08, 0.1), Vector3(0, 0.003, TZ)))
	var shade := BowlingArt.mat(Color(0.05, 0.35, 0.2), 0.4, 0.3)
	_table.add_child(BowlingArt.box(Vector3(1.5, 0.12, 0.38), shade, Vector3(0, 1.9, TZ)))
	_table.add_child(BowlingArt.box(Vector3(1.4, 0.02, 0.3), BowlingArt.unshaded(Color(1.0, 0.95, 0.75)), Vector3(0, 1.835, TZ)))
	for sx in [-0.6, 0.6]:
		_table.add_child(BowlingArt.cylinder(0.006, 0.006, 1.2, BowlingArt.mat(Color(0.1, 0.1, 0.1), 0.5), Vector3(sx, 2.5, TZ), 8))
	var wall := BowlingArt.box(Vector3(4.6, 2.2, 0.1), BowlingArt.mat(Color(0.18, 0.1, 0.12), 0.9), Vector3(0, 1.1, TZ - 1.6))
	_table.add_child(wall)
	var sign_node := Decor.neon_sign("BILLARD", Color(0.2, 0.95, 0.6), 1.5, 0.45)
	sign_node.position = Vector3(0, 1.6, TZ - 1.53)
	_table.add_child(sign_node)
	for sx in [-1.0, 1.0]:
		var pl := Decor.plant(1.0)
		pl.position = Vector3(sx * 2.0, 0, TZ - 1.3)
		_table.add_child(pl)
	# Support de queue (le long du mur de droite)
	var rack := BowlingArt.box(Vector3(0.05, 0.03, 0.05), BowlingArt.mat(Color(0.3, 0.2, 0.1), 0.6), RACK_POS + Vector3(0, -0.12, 0))
	_table.add_child(rack)


func _build_cue() -> void:
	_cue = Node3D.new()
	add_child(_cue)
	var body := BowlingArt.cylinder(0.014, 0.0065, CUE_TIP + CUE_BACK - 0.03, BowlingArt.mat(Color(0.85, 0.65, 0.35), 0.4), Vector3(0, 0, -(CUE_TIP - CUE_BACK - 0.03) / 2.0), 12)
	body.rotation_degrees = Vector3(90, 0, 0)
	_cue.add_child(body)
	var tip := BowlingArt.cylinder(0.0066, 0.0066, 0.03, BowlingArt.mat(Color(0.25, 0.5, 0.85), 0.6), Vector3(0, 0, -(CUE_TIP - 0.015)), 10)
	tip.rotation_degrees = Vector3(90, 0, 0)
	_cue.add_child(tip)
	var butt := BowlingArt.cylinder(0.0145, 0.0145, 0.18, BowlingArt.mat(Color(0.15, 0.08, 0.05), 0.5), Vector3(0, 0, CUE_BACK - 0.09), 12)
	butt.rotation_degrees = Vector3(90, 0, 0)
	_cue.add_child(butt)
	_park_cue()


func _park_cue() -> void:
	_cue.transform = Transform3D(Basis.looking_at(Vector3(-0.15, -0.35, -1.0).normalized(), Vector3.UP), RACK_POS)


func _build_guide() -> void:
	_guide_line = BowlingArt.box(Vector3(0.004, 0.002, 1.0), BowlingArt.unshaded(Color(1, 1, 1, 0.8)), Vector3.ZERO)
	_guide_line.visible = false
	add_child(_guide_line)
	var gm := BowlingArt.unshaded(Color(1, 1, 1, 0.35))
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_guide_ghost = BowlingArt.sphere(R, gm, Vector3.ZERO, 12)
	_guide_ghost.visible = false
	add_child(_guide_ghost)
	_guide_dir = BowlingArt.box(Vector3(0.004, 0.002, 1.0), BowlingArt.unshaded(Color(1.0, 0.85, 0.2, 0.8)), Vector3.ZERO)
	_guide_dir.visible = false
	add_child(_guide_dir)


func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


# ================================================================ panneaux

func _is_two() -> bool:
	return settings["mode"] == "deux"


func is_training() -> bool:
	return settings["mode"] == "training"


func is_nine() -> bool:
	return settings["variant"] == "9"


func _team_name(team: int) -> String:
	if team == PLAYER:
		return "Joueur 1" if _is_two() else "Vous"
	return "Joueur 2" if _is_two() else "Bob"


func _idx(team: int) -> int:
	return 0 if team == PLAYER else 1


func show_setup() -> void:
	state = State.SETUP
	_drop_all()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Billard", "Victoires : %d   ·   record entraînement : %s" % [_stat("wins"), "—" if _stat("best_shots") == 0 else "%d coups" % _stat("best_shots")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.26, "selected": settings["mode"] == "ordi"},
		{"id": "mode_deux", "text": "2 joueurs", "width": 0.22, "selected": settings["mode"] == "deux"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
	])
	_panel.add_row("Variante", [
		{"id": "variant_8", "text": "8 boules", "width": 0.24, "selected": settings["variant"] == "8"},
		{"id": "variant_9", "text": "9 boules", "width": 0.24, "selected": settings["variant"] == "9"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
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
	_release_all()
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
	elif id.begins_with("variant_"):
		settings["variant"] = id.substr(8)
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
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
	_save_settings()
	_rack_balls()
	show_setup()


# ================================================================ billes

func _drop_all() -> void:
	_release_all()
	for b in _balls:
		if b.node and is_instance_valid(b.node):
			b.node.queue_free()
		if b.shadow and is_instance_valid(b.shadow):
			b.shadow.queue_free()
	_balls.clear()
	_cue_ball = null


func _new_ball(i: int) -> BillBall:
	var b := BillBall.new()
	b.id = i
	var m := StandardMaterial3D.new()
	m.albedo_texture = BillBall.texture_of(i)
	m.roughness = 0.18
	m.metallic = 0.1
	b.node = BowlingArt.sphere(R, m, Vector3.ZERO, 20)
	if i > 0:
		for sx in [-1.0, 1.0]:
			var l := BowlingArt.label(str(i), R * 0.9, Color(0.05, 0.05, 0.05), 0)
			l.position = Vector3(sx * (R + 0.0008), 0, 0)
			l.rotation_degrees = Vector3(0, 90.0 * sx, 0)
			b.node.add_child(l)
	_balls_root.add_child(b.node)
	b.shadow = BowlingArt.make_blob(R * 3.2)
	_balls_root.add_child(b.shadow)
	_balls.append(b)
	return b


## Place les billes : triangle (8 boules) ou losange (9 boules), blanche sur la mouche.
func _rack_balls() -> void:
	_drop_all()
	_cue_ball = _new_ball(0)
	_cue_ball.pos = Vector2(HEAD_X, 0.0)
	var ids: Array[int] = []
	var rows: Array = []
	if is_nine():
		ids = [1, 2, 3, 4, 9, 5, 6, 7, 8]
		rows = [1, 2, 3, 2, 1]
	else:
		ids = [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 6, 13, 7, 14, 15]
		rows = [1, 2, 3, 4, 5]
	var k := 0
	var dx := sqrt(3.0) * R * 1.002
	for r in rows.size():
		var cnt: int = rows[r]
		for c in cnt:
			var b := _new_ball(ids[k])
			b.pos = Vector2(FOOT_X + r * dx, (c - (cnt - 1) / 2.0) * 2.0 * R * 1.002)
			k += 1
	_sync_visuals()
	_is_break = true


func _object_balls() -> Array[BillBall]:
	var out: Array[BillBall] = []
	for b in _balls:
		if b.id != 0 and not b.potted:
			out.append(b)
	return out


func _ball(i: int) -> BillBall:
	for b in _balls:
		if b.id == i:
			return b
	return null


func _remaining(group: String) -> int:
	var n := 0
	for b in _balls:
		if not b.potted and BillBall.group_of(b.id) == group:
			n += 1
	return n


func _lowest() -> int:
	var low := 99
	for b in _balls:
		if b.id != 0 and not b.potted:
			low = mini(low, b.id)
	return low


# ================================================================ partie

func start_match() -> void:
	scores = [0, 0]
	groups = ["", ""]
	starter = PLAYER
	_shots = 0
	_train_shots = 0
	_rack_balls()
	to_play = starter
	_is_break = true
	_in_hand = false
	_head_only = false
	_update_scoreboard()
	_begin_turn()


func _begin_turn() -> void:
	_update_scoreboard()
	_first_hit = -1
	_shot_potted.clear()
	_cue_potted = false
	_have_prev = false
	if _in_hand:
		if _is_human(to_play):
			state = State.PLACE
			var was_potted := _cue_ball.potted
			_hint.text = "Faute : place la blanche\n(gâchette sur la blanche, puis relâche)"
			_cue_ball.potted = false
			_cue_ball.vel = Vector2.ZERO
			_cue_ball.pos = _nearest_valid(_cue_ball.pos if not was_potted else Vector2(HEAD_X, 0.0), _head_only)
			_sync_visuals()
		else:
			_cue_ball.potted = false
			_cue_ball.vel = Vector2.ZERO
			_cue_ball.pos = _ai_place()
			_in_hand = false
			_sync_visuals()
			state = State.PAUSE
			_pause_next = "ai_shot"
			_timer = _think
		return
	if _is_human(to_play):
		state = State.AIM
		_hint.text = "Attrape la queue (gâchette ou grip)\net frappe la blanche"
	else:
		state = State.PAUSE
		_pause_next = "ai_shot"
		_timer = _think
		_hint.text = ""


func _is_human(team: int) -> bool:
	if _st_bot:
		return false
	if team == PLAYER:
		return true
	return _is_two()


func _legal_first(team: int, first: int) -> bool:
	if first <= 0:
		return false
	if is_nine():
		return first == _lowest_before
	var g: String = groups[_idx(team)]
	if g == "":
		return first != 8
	if _remaining_before(g) == 0:
		return first == 8
	return BillBall.group_of(first) == g


var _lowest_before := 1


func _remaining_before(group: String) -> int:
	var n := _remaining(group)
	for id in _shot_potted:
		if BillBall.group_of(id) == group:
			n += 1
	return n


## Résolution d'un coup. Renvoie : {foul, win (équipe ou 0), next, respot : [ids], msg}.
func resolve_shot(team: int) -> Dictionary:
	var res := {"foul": false, "win": 0, "next": team, "respot": [], "msg": ""}
	var idx := _idx(team)
	var foul := _cue_potted or _first_hit <= 0 or not _legal_first(team, _first_hit)
	res["foul"] = foul
	if is_nine():
		var low := _lowest_before
		if 9 in _shot_potted:
			if foul:
				res["respot"] = [9]
				res["msg"] = "Faute : le 9 est remis"
			else:
				res["win"] = team
				res["msg"] = "Le 9 !"
		var any := false
		for id in _shot_potted:
			if id != 9 or not foul:
				any = true
		if low >= 0 and not foul and any:
			res["next"] = team
		else:
			res["next"] = -team
		return res
	# 8 boules
	var g: String = groups[idx]
	if 8 in _shot_potted:
		if _is_break:
			res["respot"] = [8]
			res["msg"] = "La noire est remise"
		else:
			var cleared := g != "" and _remaining_before(g) == 0
			if cleared and not foul:
				res["win"] = team
				res["msg"] = "La noire !"
			else:
				res["win"] = -team
				res["msg"] = "La noire trop tôt !" if not cleared else "Faute sur la noire !"
			return res
	if g == "" and not foul:
		for id in _shot_potted:
			var gg := BillBall.group_of(id)
			if gg == "solid" or gg == "stripe":
				groups[idx] = gg
				groups[1 - idx] = "stripe" if gg == "solid" else "solid"
				g = gg
				break
	var own := false
	for id in _shot_potted:
		if g != "" and BillBall.group_of(id) == g:
			own = true
	res["next"] = team if (not foul and own) else -team
	return res


# ================================================================ coups

func _strike(dir: Vector2, speed: float) -> void:
	if state != State.AIM and state != State.PAUSE:
		return
	_lowest_before = _lowest()
	_cue_ball.vel = dir.normalized() * clampf(speed, 0.3, 8.0)
	_first_hit = -1
	_shot_potted.clear()
	_cue_potted = false
	_clacks = 0
	_shots += 1
	if is_training():
		_train_shots += 1
	state = State.ROLL
	_hint.text = ""
	_hide_guide()
	Sound.play_at("pet_clack", to_global(_w(_cue_ball.pos)), -2.0 + minf(speed, 7.0) * 0.8, 0.05)
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.5, 0.08)


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
	match state:
		State.AIM:
			_update_cue(delta)
		State.PLACE:
			_update_cue(delta)
			_update_place()
		State.ROLL:
			_update_cue(delta)
			var h := delta / SUBSTEPS
			for i in SUBSTEPS:
				_step(h)
			_sync_visuals(delta)
			if not _any_moving():
				_after_shot()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()
	if state != State.ROLL:
		_sync_visuals(delta)


func _any_moving() -> bool:
	for b in _balls:
		if b.is_moving():
			return true
	return false


func _step(dt: float) -> void:
	for b in _balls:
		if b.potted or b.vel == Vector2.ZERO:
			continue
		b.pos += b.vel * dt
		var sp := b.vel.length()
		sp -= DECEL * dt
		if sp <= 0.015:
			b.vel = Vector2.ZERO
		else:
			b.vel = b.vel / b.vel.length() * sp
		# poches
		var pocketed := false
		for p in _pockets():
			if b.pos.distance_to(p[0]) < float(p[1]):
				_pot(b)
				pocketed = true
				break
		if pocketed:
			continue
		# bandes
		var lx := PX - R
		var lz := PZ - R
		var hit := false
		if b.pos.x > lx:
			b.pos.x = lx
			b.vel.x = -b.vel.x * E_CUSHION
			b.vel.y *= 0.98
			hit = true
		elif b.pos.x < -lx:
			b.pos.x = -lx
			b.vel.x = -b.vel.x * E_CUSHION
			b.vel.y *= 0.98
			hit = true
		if b.pos.y > lz:
			b.pos.y = lz
			b.vel.y = -b.vel.y * E_CUSHION
			b.vel.x *= 0.98
			hit = true
		elif b.pos.y < -lz:
			b.pos.y = -lz
			b.vel.y = -b.vel.y * E_CUSHION
			b.vel.x *= 0.98
			hit = true
		if hit and sp > 0.5:
			Sound.play_at("pin_hit_1", to_global(_w(b.pos)), -14.0 + minf(sp, 5.0), 0.1)
	# chocs
	var n := _balls.size()
	for i in n:
		var a := _balls[i]
		if a.potted:
			continue
		for j in range(i + 1, n):
			var c := _balls[j]
			if c.potted:
				continue
			var d := c.pos - a.pos
			var dist := d.length()
			if dist >= 2.0 * R or dist < 0.00001:
				continue
			var nn := d / dist
			var over := 2.0 * R - dist
			a.pos -= nn * over * 0.5
			c.pos += nn * over * 0.5
			var vn := (c.vel - a.vel).dot(nn)
			if vn >= 0.0:
				continue
			var jimp := -(1.0 + E_BALL) * vn / 2.0
			a.vel -= nn * jimp
			c.vel += nn * jimp
			if (a.id == 0 or c.id == 0) and _first_hit == -1:
				_first_hit = c.id if a.id == 0 else a.id
			_clacks += 1
			if -vn > 0.25:
				Sound.play_at("pet_clack", to_global(_w((a.pos + c.pos) / 2.0)), -10.0 + minf(-vn, 6.0) * 1.1, 0.05)


func _pot(b: BillBall) -> void:
	b.potted = true
	b.vel = Vector2.ZERO
	b.node.visible = false
	b.shadow.visible = false
	Sound.play_at("pet_land", to_global(_w(b.pos)), -2.0, 0.05)
	if b.id == 0:
		_cue_potted = true
	else:
		_shot_potted.append(b.id)
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.25, 0.06)



func _sync_visuals(delta: float = 0.0) -> void:
	for b in _balls:
		if b.potted:
			continue
		var wp := _w(b.pos)
		if delta > 0.0 and b.vel.length() > 0.01:
			var axis := Vector3(b.vel.y, 0, -b.vel.x)
			if axis.length() > 0.001:
				b.node.rotate(axis.normalized(), b.vel.length() * delta / R)
		b.node.position = wp
		b.shadow.position = Vector3(wp.x, TABLE_Y + 0.002, wp.z)
		b.node.visible = true
		b.shadow.visible = true


# ---------------------------------------------------------------- après le coup

func _after_shot() -> void:
	for b in _balls:
		b.vel = Vector2.ZERO
	if is_training():
		_after_shot_training()
		return
	var team := to_play
	var res := resolve_shot(team)
	var foul: bool = res["foul"]
	for id in _shot_potted:
		if (not foul or id != 9) and (is_nine() or BillBall.group_of(id) == groups[_idx(team)]):
			scores[_idx(team)] += 1
	for id in res["respot"]:
		_respot(int(id))
	var msg: String = res["msg"]
	var win: int = res["win"]
	_is_break = false
	if win != 0:
		_update_scoreboard()
		_announce(msg, CLR_PLAYER if win == PLAYER else CLR_AI, 2.4)
		_end_game(win)
		return
	if _shots >= MAX_SHOTS:
		_adjudicate()
		return
	if foul:
		var why := "Blanche empochée !" if _cue_potted else ("Rien touché !" if _first_hit <= 0 else "Mauvaise bille !")
		_announce("Faute : %s" % why, Color(1, 0.4, 0.3), 2.2)
		_in_hand = true
		_head_only = false
		if _cue_potted:
			_cue_ball.potted = true
		if not _is_two() and team == AI:
			_bob.react("oups")
	else:
		if msg != "":
			_announce(msg, Color(1, 0.8, 0.2), 2.0)
		elif not _shot_potted.is_empty():
			var own: bool = res["next"] == team
			_announce("Bien joué !" if own else "Pas la bonne !", Color(0.4, 1, 0.5) if own else Color(1, 0.8, 0.2), 1.6)
	if res["next"] == team and not foul and not _shot_potted.is_empty() and not _is_two() and team == AI:
		_bob.say("good")
	to_play = res["next"]
	_update_scoreboard()
	state = State.PAUSE
	_pause_next = "turn"
	_timer = 1.4 if not _selftest else 0.1


func _after_shot_training() -> void:
	if _cue_potted:
		_cue_ball.potted = false
		_cue_ball.pos = _nearest_valid(Vector2(HEAD_X, 0.0), true)
		_announce("Blanche remise", Color(1, 0.6, 0.3), 1.4)
	if _object_balls().is_empty() or _train_shots >= MAX_SHOTS * 2:
		_announce("Table nettoyée en %d coups !" % _train_shots, Color(0.4, 1, 0.5), 3.0)
		if _object_balls().is_empty():
			_best_low("best_shots", _train_shots)
		_scoreboard.celebrate("win")
		state = State.GAME_OVER
		if not _selftest:
			await get_tree().create_timer(1.5).timeout
			if state == State.GAME_OVER and not _panel.visible:
				show_game_over("Table nettoyée en %d coups" % _train_shots)
		return
	if not _shot_potted.is_empty():
		_announce("Empochée !", Color(0.4, 1, 0.5), 1.0)
	_update_scoreboard()
	state = State.PAUSE
	_pause_next = "turn"
	_timer = 0.8 if not _selftest else 0.1


func _respot(id: int) -> void:
	var b := _ball(id)
	if b == null:
		return
	b.potted = false
	b.vel = Vector2.ZERO
	b.pos = _nearest_valid(Vector2(FOOT_X, 0.0), false)
	_shot_potted.erase(id)
	b.node.visible = true


func _adjudicate() -> void:
	var win := PLAYER if scores[0] >= scores[1] else AI
	_announce("Temps écoulé : l'arbitre tranche", Color(1, 0.8, 0.2), 2.4)
	_end_game(win)


func _end_game(win: int) -> void:
	state = State.GAME_OVER
	var summary := "%s gagne %d – %d" % [_team_name(win), scores[_idx(win)], scores[1 - _idx(win)]]
	if not _is_two():
		if win == PLAYER:
			_bump_stat("wins")
			_scoreboard.celebrate("win")
			_bob.say("win", true)
		else:
			_scoreboard.celebrate("lose")
	else:
		_scoreboard.celebrate("win")
	if _selftest:
		return
	await get_tree().create_timer(1.6).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _after_pause() -> void:
	match _pause_next:
		"turn":
			_begin_turn()
		"ai_shot":
			_ai_shoot()


func _announce(text: String, color: Color, seconds: float) -> void:
	_message.text = text
	_message.outline_modulate = color
	_message.modulate = Color(1, 1, 1).lerp(color, 0.2)
	_message.visible = true
	_message_time = seconds
	_message.scale = Vector3.ONE * 1.5
	var tw_ := create_tween()
	tw_.tween_property(_message, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _group_text(i: int) -> String:
	var g: String = groups[i]
	return "pleines" if g == "solid" else ("rayées" if g == "stripe" else "?")


func _update_scoreboard() -> void:
	var vt := "9 BOULES" if is_nine() else "8 BOULES"
	if is_training():
		_scoreboard.set_data("BILLARD · ENTRAÎNEMENT", ["COUPS", "RESTE"], [_train_shots, _object_balls().size()], 0, "Empoche toutes les billes")
		return
	var lvl := String(LEVELS[settings["level"]]["title"]).to_upper()
	var mode := "2 JOUEURS" if _is_two() else lvl
	var names := ["VOUS", "BOB"] if not _is_two() else ["J1", "J2"]
	var foot := ""
	if is_nine():
		foot = "Plus petite bille d'abord · 9 gagne"
	else:
		foot = "%s : %s   ·   %s : %s" % [names[0], _group_text(0), names[1], _group_text(1)]
	var srv := to_play if state != State.SETUP else 0
	_scoreboard.set_data("BILLARD %s · %s" % [vt, mode], names, scores, srv, foot)


# ================================================================ placement de la blanche

func _valid_place(p: Vector2, head_only: bool) -> bool:
	if absf(p.x) > PX - R - 0.01 or absf(p.y) > PZ - R - 0.01:
		return false
	if head_only and p.x > HEAD_X:
		return false
	for b in _balls:
		if b == _cue_ball or b.potted:
			continue
		if b.pos.distance_to(p) < 2.0 * R + 0.004:
			return false
	return true


func _nearest_valid(want: Vector2, head_only: bool) -> Vector2:
	if head_only:
		want.x = minf(want.x, HEAD_X)
	if _valid_place(want, head_only):
		return want
	for ring in range(1, 40):
		var rad := ring * 0.02
		for k in 16:
			var a := TAU * k / 16.0
			var p := want + Vector2(cos(a), sin(a)) * rad
			if _valid_place(p, head_only):
				return p
	return Vector2(HEAD_X, 0.0)


func _update_place() -> void:
	if _held_ball and _ball_hand != null and is_instance_valid(_ball_hand):
		var hp := _hand_pos(_ball_hand)
		var p := Vector2(hp.x, hp.z - TZ)
		p.x = clampf(p.x, -PX + R, PX - R)
		p.y = clampf(p.y, -PZ + R, PZ - R)
		if _head_only:
			p.x = minf(p.x, HEAD_X)
		_cue_ball.pos = p
		_sync_visuals()


func _release_ball() -> void:
	if not _held_ball:
		return
	_held_ball = false
	_ball_hand = null
	_cue_ball.pos = _nearest_valid(_cue_ball.pos, _head_only)
	_sync_visuals()
	_in_hand = false
	_head_only = false
	state = State.AIM
	_hint.text = "Attrape la queue (gâchette ou grip)\net frappe la blanche"


# ================================================================ la queue

func _hand_pos(h: Hand) -> Vector3:
	var gt := global_transform.affine_inverse() * h.global_transform
	return gt.origin


func _hand_basis(h: Hand) -> Basis:
	return (global_transform.affine_inverse() * h.global_transform).basis


func _try_grab(hand: Hand, button: String) -> void:
	if state == State.PLACE:
		if _held_ball:
			return
		var hp := _hand_pos(hand)
		if hp.distance_to(_w(_cue_ball.pos)) < 0.3:
			_held_ball = true
			_ball_hand = hand
			_ball_button = button
			hand.buzz(0.4, 0.05)
		return
	if state != State.AIM and state != State.ROLL:
		return
	if _cue_hand != null:
		return
	var hp2 := _hand_pos(hand)
	if hp2.distance_to(_cue.position) > GRAB_RADIUS and hp2.distance_to(RACK_POS) > GRAB_RADIUS:
		return
	_cue_hand = hand
	_cue_button = button
	_have_prev = false
	hand.buzz(0.4, 0.06)
	_hint.text = ""


func _release_cue(hand: Hand) -> void:
	if _cue_hand != hand:
		return
	_cue_hand = null
	_cue_button = ""
	_have_prev = false
	_hide_guide()
	_park_cue()


func _release_all() -> void:
	_cue_hand = null
	_cue_button = ""
	_held_ball = false
	_ball_hand = null
	_have_prev = false
	if _cue:
		_park_cue()
	if _guide_line:
		_hide_guide()


func _hide_guide() -> void:
	_guide_line.visible = false
	_guide_ghost.visible = false
	_guide_dir.visible = false


func _update_cue(delta: float) -> void:
	if _cue_hand == null or not is_instance_valid(_cue_hand):
		return
	var gt := global_transform.affine_inverse() * _cue_hand.global_transform
	_cue.transform = gt
	var fwd := -gt.basis.z
	var tip := gt.origin + fwd * CUE_TIP
	var tip_vel := Vector3.ZERO
	if _have_prev and delta > 0.0:
		tip_vel = (tip - _prev_tip) / delta
	_prev_tip = tip
	_have_prev = true
	if state != State.AIM:
		_hide_guide()
		return
	_update_guide(fwd)
	_check_strike(tip, tip_vel, fwd)


## La pointe touche la blanche à bonne vitesse : le coup part dans l'axe de la queue.
func _check_strike(tip: Vector3, tip_vel: Vector3, fwd: Vector3) -> bool:
	if state != State.AIM or _cue_ball == null or _cue_ball.potted:
		return false
	var hd := Vector2(fwd.x, fwd.z)
	if hd.length() < 0.35:
		return false
	hd = hd.normalized()
	if tip.distance_to(_w(_cue_ball.pos)) > R + 0.022:
		return false
	var along := tip_vel.dot(Vector3(hd.x, 0.0, hd.y))
	if along < 0.45:
		return false
	_strike(hd, clampf(along * 1.5 * VisualStyle.cue_gain, 0.8, 7.5))
	return true


func _trace(from: Vector2, dir: Vector2) -> Dictionary:
	var best := 6.0
	var hit_id := -1
	for b in _balls:
		if b == _cue_ball or b.potted:
			continue
		var oc := from - b.pos
		var bb := oc.dot(dir)
		var cc := oc.dot(oc) - 4.0 * R * R
		var disc := bb * bb - cc
		if disc < 0.0:
			continue
		var t := -bb - sqrt(disc)
		if t > 0.0 and t < best:
			best = t
			hit_id = b.id
	# bandes
	var lx := PX - R
	var lz := PZ - R
	if dir.x > 0.0001:
		best = minf(best, (lx - from.x) / dir.x)
	elif dir.x < -0.0001:
		best = minf(best, (-lx - from.x) / dir.x)
	if dir.y > 0.0001:
		best = minf(best, (lz - from.y) / dir.y)
	elif dir.y < -0.0001:
		best = minf(best, (-lz - from.y) / dir.y)
	return {"t": maxf(best, 0.0), "id": hit_id, "ghost": from + dir * maxf(best, 0.0)}


func _update_guide(fwd: Vector3) -> void:
	if not bool(LEVELS[settings["level"]]["guide"]) and not _is_two():
		_hide_guide()
		return
	var hd := Vector2(fwd.x, fwd.z)
	if hd.length() < 0.35 or _cue_ball.potted:
		_hide_guide()
		return
	hd = hd.normalized()
	var tr := _trace(_cue_ball.pos, hd)
	var t: float = tr["t"]
	var a := _w(_cue_ball.pos)
	var b := _w(_cue_ball.pos + hd * t)
	_set_line(_guide_line, a, b)
	if int(tr["id"]) > 0:
		var gp: Vector2 = tr["ghost"]
		_guide_ghost.visible = true
		_guide_ghost.position = _w(gp)
		var ob := _ball(int(tr["id"]))
		var od := (ob.pos - gp).normalized()
		_set_line(_guide_dir, _w(ob.pos), _w(ob.pos + od * 0.3))
	else:
		_guide_ghost.visible = false
		_guide_dir.visible = false


func _set_line(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.01:
		m.visible = false
		return
	m.visible = true
	m.position = (a + b) / 2.0
	m.basis = Basis.looking_at((b - a).normalized(), Vector3.UP).scaled(Vector3(1, 1, len))


# ================================================================ adversaire

func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _legal_targets(team: int) -> Array[BillBall]:
	var out: Array[BillBall] = []
	_lowest_before = _lowest()
	_shot_potted.clear()
	for b in _balls:
		if b.id == 0 or b.potted:
			continue
		var ok := false
		if is_nine():
			ok = b.id == _lowest_before
		elif is_training():
			ok = true
		else:
			ok = _legal_first(team, b.id)
		if ok:
			out.append(b)
	if out.is_empty():
		out = _object_balls()
	return out


func _blocked(a: Vector2, b: Vector2, ignore: Array) -> bool:
	var seg := b - a
	var l2 := seg.length_squared()
	if l2 < 0.000001:
		return false
	for o in _balls:
		if o.potted or ignore.has(o):
			continue
		var t := clampf((o.pos - a).dot(seg) / l2, 0.0, 1.0)
		var cp := a + seg * t
		if cp.distance_to(o.pos) < 2.0 * R * 0.98:
			return true
	return false


## Meilleur coup depuis la position `cue` : {dir, dist, score}. Trace aussi un coup « au contact » si rien de direct.
func _ai_plan(cue: Vector2, team: int) -> Dictionary:
	var best := {"dir": Vector2.RIGHT, "dist": 1.0, "score": INF, "direct": false}
	var targets := _legal_targets(team)
	for t in targets:
		for p in _pockets():
			var pp: Vector2 = p[0]
			# la poche visée est un peu rentrée dans le coin
			pp = pp * 0.97
			var tp := pp - t.pos
			var tl := tp.length()
			if tl < 0.05:
				continue
			var tn := tp / tl
			var ghost := t.pos - tn * 2.0 * R
			var v1 := ghost - cue
			var d1 := v1.length()
			if d1 < 0.02:
				continue
			var cosa := (v1 / d1).dot(tn)
			if cosa < 0.34:
				continue
			if _blocked(cue, ghost, [_cue_ball, t]) or _blocked(t.pos, pp, [_cue_ball, t]):
				continue
			var score := d1 + tl * 1.2 + (1.0 - cosa) * 1.6
			if score < float(best["score"]):
				best = {"dir": v1 / d1, "dist": d1 + tl, "score": score, "direct": true}
	if not bool(best["direct"]) and not targets.is_empty():
		var nearest: BillBall = targets[0]
		for t in targets:
			if t.pos.distance_to(cue) < nearest.pos.distance_to(cue):
				nearest = t
		var v := nearest.pos - cue
		best = {"dir": v.normalized(), "dist": v.length(), "score": 99.0 + v.length(), "direct": false}
	return best


func _ai_place() -> Vector2:
	var bestp := _nearest_valid(Vector2(HEAD_X, 0.0), _head_only)
	var bests := INF
	for i in 14:
		var p := Vector2(randf_range(-PX + 0.1, PX - 0.1), randf_range(-PZ + 0.08, PZ - 0.08))
		if _head_only:
			p.x = randf_range(-PX + 0.1, HEAD_X)
		if not _valid_place(p, _head_only):
			continue
		var sc := float(_ai_plan(p, to_play)["score"])
		if sc < bests:
			bests = sc
			bestp = p
	return bestp


func _ai_shoot() -> void:
	if _cue_ball.potted:
		_cue_ball.potted = false
	var lvl: Dictionary = LEVELS[settings["level"]]
	var sg: float = lvl["sigma"] if _sigma_override < 0.0 else _sigma_override
	var plan := _ai_plan(_cue_ball.pos, to_play)
	var dir: Vector2 = plan["dir"]
	dir = dir.rotated(_gauss() * sg * 0.5)
	var dist: float = plan["dist"]
	var speed := clampf(1.7 + 1.5 * dist, 1.9, 6.8)
	if _is_break:
		dir = (Vector2(FOOT_X, 0.0) - _cue_ball.pos).normalized().rotated(_gauss() * 0.01)
		speed = 7.0
	state = State.AIM
	_strike(dir, speed)


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
	if _held_ball and button == _ball_button and hand == _ball_hand:
		_release_ball()
		return
	if button == _cue_button and hand == _cue_hand:
		_release_cue(hand)


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
	if settings["variant"] not in ["8", "9"]:
		settings["variant"] = "8"


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	_save.save(SAVE_PATH)


func _stat(key: String) -> int:
	return int(_save.get_value("records", key, 0))


func _bump_stat(key: String) -> void:
	_save.set_value("records", key, _stat(key) + 1)
	_save.save(SAVE_PATH)


func _best_low(key: String, value: int) -> void:
	var cur := _stat(key)
	if cur == 0 or value < cur:
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


func _wait_roll(max_frames: int) -> void:
	var i := 0
	while state == State.ROLL and i < max_frames:
		await get_tree().physics_frame
		i += 1


func _in_bounds() -> bool:
	for b in _balls:
		if b.potted:
			continue
		if absf(b.pos.x) > PX or absf(b.pos.y) > PZ:
			return false
	return true


func _no_overlap() -> bool:
	for i in _balls.size():
		for j in range(i + 1, _balls.size()):
			if not _balls[i].potted and not _balls[j].potted and _balls[i].pos.distance_to(_balls[j].pos) < 2.0 * R - 0.0005:
				return false
	return true


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["variant"] = "8"
	settings["level"] = "normal"
	_st_bot = false

	# A. Mises en place
	_rack_balls()
	_st_check("triangle de 15 billes", _balls.size() == 16 and _no_overlap() and _in_bounds() and _ball(8) != null and _ball(8).pos.x > FOOT_X, str(_balls.size()))
	settings["variant"] = "9"
	_rack_balls()
	_st_check("losange de 9 billes", _balls.size() == 10 and _no_overlap() and _ball(9).pos.x > FOOT_X and is_equal_approx(_ball(1).pos.x, FOOT_X), str(_balls.size()))

	# B. Casse : la blanche percute le triangle
	settings["variant"] = "8"
	_rack_balls()
	state = State.AIM
	_strike(Vector2.RIGHT, 6.5)
	await _wait_roll(90 * 40)
	var moved := 0
	for b in _balls:
		if b.id != 0 and not b.potted and b.pos.distance_to(Vector2(FOOT_X, 0.0)) > 0.3:
			moved += 1
	_st_check("casse", _clacks > 5 and moved >= 5 and _in_bounds() and not _any_moving(), "(%d chocs, %d billes dispersées)" % [_clacks, moved])

	# B2. Poche : une bille qui file vers le coin tombe
	_rack_balls()
	var pb := _ball(1)
	pb.pos = Vector2(PX - 0.2, PZ - 0.2)
	pb.vel = Vector2(1.0, 1.0).normalized() * 1.2
	state = State.ROLL
	await _wait_roll(90 * 10)
	_st_check("poche d'angle", pb.potted, "")
	_rack_balls()
	var sb := _ball(2)
	sb.pos = Vector2(0.02, PZ - 0.3)
	sb.vel = Vector2(0, 1.0)
	state = State.ROLL
	await _wait_roll(90 * 10)
	_st_check("poche du milieu", sb.potted, "")

	# C. Règles
	settings["variant"] = "8"
	_rack_balls()
	groups = ["", ""]
	_is_break = false
	_first_hit = 3
	_shot_potted = [3]
	_cue_potted = false
	var r1 := resolve_shot(PLAYER)
	_st_check("8 boules : 1re bille empochée = groupe", not r1["foul"] and r1["next"] == PLAYER and groups[0] == "solid" and groups[1] == "stripe", str(groups))
	_first_hit = 8
	_shot_potted = []
	groups = ["", ""]
	var r2 := resolve_shot(PLAYER)
	_st_check("noire en premier = faute", r2["foul"] and r2["next"] == AI, "")
	groups = ["solid", "stripe"]
	_first_hit = 10
	var r3 := resolve_shot(PLAYER)
	_st_check("mauvais groupe = faute", r3["foul"], "")
	_first_hit = 2
	_shot_potted = [10]
	var r4 := resolve_shot(PLAYER)
	_st_check("bille adverse : on passe la main", not r4["foul"] and r4["next"] == AI, "")
	_first_hit = 8
	_shot_potted = [8]
	var r5 := resolve_shot(PLAYER)
	_st_check("noire trop tôt = défaite", r5["win"] == AI, str(r5["win"]))
	for i in range(1, 8):
		_ball(i).potted = true
	_first_hit = 8
	_shot_potted = [8]
	var r6 := resolve_shot(PLAYER)
	_st_check("noire en dernier = victoire", r6["win"] == PLAYER, str(r6["win"]))
	_cue_potted = true
	var r7 := resolve_shot(PLAYER)
	_st_check("noire + blanche = défaite", r7["win"] == AI, "")
	_cue_potted = false
	settings["variant"] = "9"
	_rack_balls()
	_lowest_before = 1
	_is_break = false
	_first_hit = 1
	_shot_potted = [1]
	var n1 := resolve_shot(PLAYER)
	_st_check("9 boules : on rejoue", not n1["foul"] and n1["next"] == PLAYER, "")
	_first_hit = 2
	_shot_potted = []
	var n2 := resolve_shot(PLAYER)
	_st_check("9 boules : mauvaise bille", n2["foul"] and n2["next"] == AI, "")
	_first_hit = 1
	_shot_potted = [9]
	var n3 := resolve_shot(PLAYER)
	_st_check("9 boules : le 9 gagne", n3["win"] == PLAYER, "")

	# D. Placement de la blanche
	_rack_balls()
	var want := _ball(1).pos
	var pv := _nearest_valid(want, false)
	_st_check("placement de la blanche", _valid_place(pv, false) and pv.distance_to(want) > R, "")
	var head := _nearest_valid(Vector2(0.5, 0.0), true)
	_st_check("placement derrière la ligne", head.x <= HEAD_X, "")

	# E. Frappe à la queue
	_rack_balls()
	state = State.AIM
	var wp := _w(_cue_ball.pos)
	var fired := _check_strike(wp + Vector3(-0.03, 0, 0), Vector3(1.6, 0, 0), Vector3(1, 0, 0))
	_st_check("frappe détectée", fired and state == State.ROLL and _cue_ball.vel.x > 1.0, "")
	_rack_balls()
	state = State.AIM
	var slow := _check_strike(wp + Vector3(-0.03, 0, 0), Vector3(0.1, 0, 0), Vector3(1, 0, 0))
	_st_check("frappe trop douce ignorée", not slow and state == State.AIM, "")

	# F. L'ordinateur empoche des billes directes
	settings["mode"] = "training"
	_sigma_override = 0.0
	var pots := 0
	for k in 5:
		_rack_balls()
		for b in _balls:
			if b.id > 1:
				b.potted = true
				b.node.visible = false
		_cue_ball.pos = Vector2(-0.5 + randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		_ball(1).pos = Vector2(randf_range(0.1, 0.5), randf_range(-0.25, 0.25))
		_train_shots = 0
		_is_break = false
		state = State.AIM
		_st_bot = true
		_ai_shoot()
		await _wait_roll(90 * 25)
		if _ball(1).potted:
			pots += 1
	_st_check("l'ordi empoche", pots >= 3, "(%d sur 5)" % pots)
	_sigma_override = -1.0

	# G. Parties complètes
	for vv in ["8", "9"]:
		settings["mode"] = "ordi"
		settings["variant"] = vv
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 1500:
			await get_tree().physics_frame
			guard += 1
		_st_check("partie %s boules terminée" % vv, state == State.GAME_OVER, "%s, %d coups, %.0f s" % [str(scores), _shots, guard / 90.0])

	# H. Entraînement
	settings["mode"] = "training"
	settings["variant"] = "8"
	_st_bot = true
	start_match()
	var g2 := 0
	while state != State.GAME_OVER and g2 < 90 * 1500:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement terminé", state == State.GAME_OVER, "(%d coups)" % _train_shots)
	_st_bot = false

	_drop_all()
	for line in _st_log:
		print("SELFTEST billard ", line)
	print("SELFTEST billard=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
