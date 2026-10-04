class_name BabyfootGame
extends Node3D
## Baby-foot en réalité augmentée : une table devant le joueur vue par le long côté. On attrape
## une barre par sa poignée (gâchette ou grip) : l'approcher/l'éloigner la fait glisser, balayer la
## main vers l'avant (le long de la table) fait tourner les joueurs et frappe la balle.
## Vos autres barres suivent la balle toutes seules ; l'ordinateur défend l'autre côté.
## Le noeud est aux pieds du joueur ; la table est à -Z, but du joueur à gauche (-x), attaque vers +x.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const L := 1.2                # longueur du terrain (x)
const W := 0.68               # largeur (y, vers le joueur = +)
const GOAL_W := 0.22          # largeur des buts
const BR := 0.017             # rayon de la balle
const FR := 0.018             # rayon d'un pied
const BODY_R := 0.015
const LEG := 0.075
const TABLE_Y := 0.85
const TZ := -1.05
const SUBSTEPS := 6
const DECEL := 0.22
const E_WALL := 0.72
const SPEED_MAX := 8.0
const SPIN_GAIN := 30.0       # vitesse de la main -> vitesse de rotation
const OMEGA_MAX := 45.0
const THETA_MAX := 1.25
const SAVE_PATH := "user://babyfoot.cfg"
const PLAYER := 1
const AI := -1
const CLR_PLAYER := Color(0.3, 0.55, 1.0)
const CLR_AI := Color(0.95, 0.3, 0.25)
const TRAIN_TIME := 60.0
var _train_time := TRAIN_TIME

const LEVELS := {
	"facile": {"title": "Facile", "speed": 0.55, "k": 4.0, "kick_p": 0.35, "assist": 0.9},
	"normal": {"title": "Normal", "speed": 1.0, "k": 8.0, "kick_p": 0.7, "assist": 0.6},
	"expert": {"title": "Expert", "speed": 1.8, "k": 15.0, "kick_p": 1.0, "assist": 0.35},
}

enum State { SETUP, SERVE, PLAY, GOAL, GAME_OVER }

var settings := {"mode": "ordi", "level": "normal", "goals": 5, "music": true}
var state := State.SETUP
var scores := [0, 0]
var _rods: Array[BfRod] = []
var _ball_pos := Vector2.ZERO
var _ball_vel := Vector2.ZERO
var _ball_node: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _timer := 0.0
var _clock := 0.0
var _still := 0.0
var _serve_dir := 1
var _game_time := 0.0
var _last_touch := 0
var _hands: Array = []
var _hand_prev: Dictionary = {}
var _hand_vx: Dictionary = {}
var _table: Node3D
var _rods_root: Node3D
var _scoreboard: PingScoreboard
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _message: Label3D
var _message_time := 0.0
var _hint: Label3D
var _fan: Spectator
var _save := ConfigFile.new()
var _kicks := 0
var _touches := 0
var _test_rod: BfRod = null
var _test_vx := 0.0

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
	_rods_root = Node3D.new()
	add_child(_rods_root)
	_build_table()
	_build_rods()
	_build_decor()
	_ball_node = BowlingArt.sphere(BR, BowlingArt.mat(Color(0.97, 0.97, 0.9), 0.3), Vector3.ZERO, 14)
	add_child(_ball_node)
	_ball_shadow = BowlingArt.make_blob(BR * 3.0)
	add_child(_ball_shadow)

	_scoreboard = PingScoreboard.new()
	add_child(_scoreboard)
	_fan = Spectator.new({
		"name": "Lulu", "skin": Color(0.9, 0.7, 0.58), "shirt": Color(0.9, 0.75, 0.15),
		"pants": Color(0.2, 0.25, 0.4), "hair": Color(0.45, 0.25, 0.1), "beard": false,
		"hat": false, "hat_color": Color(0.1, 0.1, 0.12),
	})
	add_child(_fan)
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
	_panel.accent = Color(0.95, 0.8, 0.2)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)

	_scoreboard.position = Vector3(1.9, 1.5, TZ - 0.4)
	_scoreboard.scale = Vector3.ONE * 1.1
	var face := Vector3(0, 0, 1.0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_fan.position = Vector3(-1.9, 0, TZ - 0.9)
	_fan.rotation.y = deg_to_rad(70.0)
	_message.position = Vector3(0, 1.75, TZ - 0.8)
	_hint.position = Vector3(0, 1.3, -0.35)
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	_reset_ball()
	_update_scoreboard()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


func _w(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, TABLE_Y + h, TZ + p.y)


func _build_table() -> void:
	var wood := BowlingArt.surface_material("wood", Color(0.56, 0.34, 0.17), Vector2(3, 1))
	var dark := BowlingArt.mat(Color(0.25, 0.14, 0.07), 0.6)
	var pitch := BowlingArt.surface_material("grass", Color(0.10, 0.45, 0.24), Vector2(4, 3))
	_table.add_child(BowlingArt.box(Vector3(L + 0.04, 0.03, W + 0.04), pitch, Vector3(0, TABLE_Y - 0.015, TZ)))
	# Lignes du terrain
	var white := BowlingArt.unshaded(Color(1, 1, 1, 0.9))
	_table.add_child(BowlingArt.box(Vector3(0.006, 0.002, W), white, _w(Vector2(0, 0), 0.001)))
	_table.add_child(BowlingArt.cylinder(0.09, 0.09, 0.0015, white, _w(Vector2(0, 0), 0.0012), 28))
	_table.add_child(BowlingArt.cylinder(0.084, 0.084, 0.002, pitch, _w(Vector2(0, 0), 0.0016), 28))
	for sx in [-1.0, 1.0]:
		_table.add_child(BowlingArt.box(Vector3(0.006, 0.002, 0.34), white, _w(Vector2(sx * (L / 2.0 - 0.17), 0), 0.001)))
		_table.add_child(BowlingArt.box(Vector3(0.17, 0.002, 0.006), white, _w(Vector2(sx * (L / 2.0 - 0.085), 0.17), 0.001)))
		_table.add_child(BowlingArt.box(Vector3(0.17, 0.002, 0.006), white, _w(Vector2(sx * (L / 2.0 - 0.085), -0.17), 0.001)))
	# Bords (parois) avec ouverture pour les buts
	var wall_h := 0.07
	for sy in [-1.0, 1.0]:
		_table.add_child(BowlingArt.box(Vector3(L + 0.2, wall_h, 0.08), wood, Vector3(0, TABLE_Y + wall_h / 2.0 - 0.01, TZ + sy * (W / 2.0 + 0.04))))
	var seg := (W - GOAL_W) / 2.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_table.add_child(BowlingArt.box(Vector3(0.08, wall_h, seg), wood, Vector3(sx * (L / 2.0 + 0.04), TABLE_Y + wall_h / 2.0 - 0.01, TZ + sy * (GOAL_W / 2.0 + seg / 2.0))))
		# fond des buts
		_table.add_child(BowlingArt.box(Vector3(0.14, 0.12, GOAL_W + 0.02), BowlingArt.mat(Color(0.03, 0.03, 0.04), 0.9), Vector3(sx * (L / 2.0 + 0.1), TABLE_Y - 0.05, TZ)))
	# Caisse et pieds
	_table.add_child(BowlingArt.box(Vector3(L + 0.3, 0.16, W + 0.3), dark, Vector3(0, TABLE_Y - 0.1, TZ)))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_table.add_child(BowlingArt.box(Vector3(0.08, TABLE_Y - 0.18, 0.08), dark, Vector3(sx * (L / 2.0 + 0.0), (TABLE_Y - 0.18) / 2.0, TZ + sy * (W / 2.0 + 0.0))))


func _build_rods() -> void:
	var order := [1, 1, -1, 1, -1, 1, -1, -1]          # équipe de chaque barre, du but du joueur au but adverse
	var kinds := [1, 2, 3, 5, 5, 3, 2, 1]               # nombre de joueurs
	var gaps := [0.0, 0.24, 0.20, 0.12, 0.12, 0.20, 0.24, 0.0]
	for i in 8:
		var r := BfRod.new()
		r.idx = i
		r.team = order[i]
		r.dir = r.team
		r.x = -L / 2.0 + 0.075 + 0.15 * i
		var n: int = kinds[i]
		for m in n:
			r.men.append((m - (n - 1) / 2.0) * float(gaps[i]))
		var maxm := 0.0
		for m in r.men:
			maxm = maxf(maxm, absf(m))
		r.lim = minf(W / 2.0 - 0.025 - maxm, 0.2 if n == 1 else 0.5)
		_make_rod_nodes(r)
		_rods.append(r)


func _make_rod_nodes(r: BfRod) -> void:
	var col := CLR_PLAYER if r.team == PLAYER else CLR_AI
	r.node = Node3D.new()
	r.node.position = Vector3(r.x, TABLE_Y + 0.085, TZ)
	_rods_root.add_child(r.node)
	var steel := BowlingArt.mat(Color(0.75, 0.77, 0.8), 0.25, 0.9)
	var bar := BowlingArt.cylinder(0.006, 0.006, 1.0, steel, Vector3.ZERO, 10)
	bar.rotation_degrees = Vector3(90, 0, 0)
	r.node.add_child(bar)
	for sy in [-1.0, 1.0]:
		var h := BowlingArt.cylinder(0.017, 0.017, 0.13, BowlingArt.mat(Color(0.08, 0.08, 0.1), 0.6) if sy > 0 else BowlingArt.mat(col.darkened(0.2), 0.5), Vector3(0, 0, sy * 0.47), 14)
		h.rotation_degrees = Vector3(90, 0, 0)
		r.node.add_child(h)
		var ring := BowlingArt.cylinder(0.02, 0.02, 0.012, BowlingArt.mat(col, 0.4), Vector3(0, 0, sy * 0.405), 14)
		ring.rotation_degrees = Vector3(90, 0, 0)
		r.node.add_child(ring)
	r.pivot = Node3D.new()
	r.node.add_child(r.pivot)
	var body_mat := BowlingArt.mat(col, 0.45, 0.1)
	var skin := BowlingArt.mat(Color(0.95, 0.85, 0.7), 0.6)
	for m in r.men:
		var man := Node3D.new()
		man.position = Vector3(0, 0, m)
		r.pivot.add_child(man)
		man.add_child(BowlingArt.box(Vector3(0.03, LEG, 0.026), body_mat, Vector3(0, -LEG / 2.0, 0)))
		man.add_child(BowlingArt.box(Vector3(0.036, 0.018, 0.03), BowlingArt.mat(col.darkened(0.45), 0.5), Vector3(0, -LEG + 0.006, 0)))
		man.add_child(BowlingArt.sphere(0.017, skin, Vector3(0, 0.012, 0), 10))


func _build_decor() -> void:
	_table.add_child(Decor.sport_corner("pub", Vector3(-1.55, 0, TZ - 1.25)))
	_table.add_child(Decor.rug(Vector2(4.2, 3.0), Color(0.12, 0.25, 0.4), Vector3(0, 0.003, TZ)))
	var wall := BowlingArt.box(Vector3(4.8, 2.3, 0.1), BowlingArt.mat(Color(0.2, 0.18, 0.28), 0.9), Vector3(0, 1.15, TZ - 1.6))
	_table.add_child(wall)
	var sign_node := Decor.neon_sign("BABY-FOOT", Color(1.0, 0.8, 0.2), 1.6, 0.45)
	sign_node.position = Vector3(0, 1.7, TZ - 1.53)
	_table.add_child(sign_node)
	for sx in [-1.0, 1.0]:
		var pl := Decor.plant(1.0)
		pl.position = Vector3(sx * 2.0, 0, TZ - 1.3)
		_table.add_child(pl)
	var shade := BowlingArt.mat(Color(0.5, 0.1, 0.1), 0.4, 0.3)
	_table.add_child(BowlingArt.box(Vector3(1.4, 0.1, 0.4), shade, Vector3(0, 1.95, TZ)))
	_table.add_child(BowlingArt.box(Vector3(1.3, 0.02, 0.3), BowlingArt.unshaded(Color(1.0, 0.95, 0.75)), Vector3(0, 1.89, TZ)))
	for sx in [-0.6, 0.6]:
		_table.add_child(BowlingArt.cylinder(0.006, 0.006, 1.2, BowlingArt.mat(Color(0.1, 0.1, 0.1), 0.5), Vector3(sx, 2.55, TZ), 8))


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

func is_training() -> bool:
	return settings["mode"] == "training"


func show_setup() -> void:
	state = State.SETUP
	_release_rods()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Baby-foot", "Victoires : %d   ·   meilleur défi : %d buts" % [_stat("wins"), _stat("best_goals")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.28, "selected": settings["mode"] == "ordi"},
		{"id": "mode_training", "text": "Défi 60 s", "width": 0.24, "selected": settings["mode"] == "training"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Buts", [
		{"id": "goals_5", "text": "5", "width": 0.14, "selected": settings["goals"] == 5},
		{"id": "goals_10", "text": "10", "width": 0.14, "selected": settings["goals"] == 10},
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
	_release_rods()
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
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
	elif id.begins_with("goals_"):
		settings["goals"] = int(id.substr(6))
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
	show_setup()


# ================================================================ partie

func start_match() -> void:
	scores = [0, 0]
	_clock = 0.0
	_game_time = 0.0
	_reset_rods()
	_serve_dir = 1
	_begin_serve()


func _reset_rods() -> void:
	_release_rods()
	for r in _rods:
		r.off = 0.0
		r.off_prev = 0.0
		r.theta = 0.0
		r.theta_prev = 0.0
		r.omega = 0.0
		r.kick_t = 0.0
		r.cd = 0.0
		r.track_y = 0.0


func _reset_ball() -> void:
	_ball_pos = Vector2.ZERO
	_ball_vel = Vector2.ZERO
	_ball_node.position = _w(_ball_pos, BR)
	_ball_shadow.position = _w(_ball_pos, 0.002)


func _begin_serve() -> void:
	_reset_ball()
	state = State.SERVE
	_timer = 1.4 if not _selftest else 0.2
	_still = 0.0
	_update_scoreboard()
	_hint.text = "Attrape une barre (gâchette ou grip)\nglisse-la, balaie pour frapper" if not _st_bot else ""


func _is_human_rod(r: BfRod) -> bool:
	return r.team == PLAYER and not _st_bot


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
	_track_hands(delta)
	match state:
		State.SERVE:
			_update_rods(delta)
			_timer -= delta
			if _timer <= 0.0:
				_ball_vel = Vector2(_serve_dir * 0.7, randf_range(-0.35, 0.35))
				state = State.PLAY
				_hint.text = ""
		State.PLAY:
			_game_time += delta
			_update_rods(delta)
			_play_ball(delta)
			if is_training():
				_clock += delta
				if _clock >= _train_time:
					_end_training()
		State.GOAL:
			_update_rods(delta)
			_timer -= delta
			if _timer <= 0.0:
				_begin_serve()
		_:
			pass
	_update_visuals()


# ---------------------------------------------------------------- les barres

func _track_hands(delta: float) -> void:
	for h in _hands:
		if not is_instance_valid(h):
			continue
		var p := _hand_pos(h)
		if _hand_prev.has(h) and delta > 0.0:
			var v := (p.x - float(_hand_prev[h])) / delta
			_hand_vx[h] = lerpf(float(_hand_vx.get(h, 0.0)), v, 0.5)
		_hand_prev[h] = p.x


func _hand_pos(h: Hand) -> Vector3:
	return (global_transform.affine_inverse() * h.global_transform).origin


func _update_rods(delta: float) -> void:
	var lvl: Dictionary = LEVELS[settings["level"]]
	for r in _rods:
		r.off_prev = r.off
		r.theta_prev = r.theta
		r.cd -= delta
		if r == _test_rod:
			_apply_sweep(r, _test_vx)
		elif r.held_by is Hand and is_instance_valid(r.held_by) and not _st_bot:
			var hp := _hand_pos(r.held_by as Hand)
			apply_hand(r, hp.z, float(_hand_vx.get(r.held_by, 0.0)), delta)
		elif r.team == PLAYER and not _st_bot:
			_assist_rod(r, delta, lvl)
		elif r.team == AI and is_training():
			_freeze_rod(r, delta)
		else:
			_ai_rod(r, delta, lvl)
		r.theta = clampf(r.theta + r.omega * delta, -THETA_MAX, THETA_MAX)
		r.off = clampf(r.off, -r.lim, r.lim)


## Mouvement d'une barre tenue : le décalage suit la main, la vitesse de la main fait tourner.
func apply_hand(r: BfRod, hand_z: float, vx: float, delta: float) -> void:
	var target := clampf(r.off0 + (hand_z - r.hand_z0), -r.lim, r.lim)
	r.off = move_toward(r.off, target, 5.0 * delta)
	r.omega = clampf(vx * r.dir * SPIN_GAIN * VisualStyle.rod_gain - 7.0 * r.theta, -OMEGA_MAX, OMEGA_MAX)


func _freeze_rod(r: BfRod, delta: float) -> void:
	r.off = move_toward(r.off, 0.0, 1.0 * delta)
	r.omega = -8.0 * r.theta


func _best_offset(r: BfRod, y: float) -> float:
	var best := r.off
	var bd := 1e9
	for m in r.men:
		var o := clampf(y - m, -r.lim, r.lim)
		var d := absf(o - r.off)
		if d < bd:
			bd = d
			best = o
	return best


## Vos barres libres suivent la balle (coéquipiers), plus ou moins bien selon le niveau.
func _assist_rod(r: BfRod, delta: float, lvl: Dictionary) -> void:
	var a: float = lvl["assist"]
	r.track_y += (_ball_pos.y - r.track_y) * minf(1.0, delta * 5.0)
	r.off = move_toward(r.off, _best_offset(r, r.track_y), 1.0 * a * delta)
	r.omega = -8.0 * r.theta


func _ai_rod(r: BfRod, delta: float, lvl: Dictionary) -> void:
	r.track_y += (_ball_pos.y - r.track_y) * minf(1.0, delta * float(lvl["k"]))
	r.off = move_toward(r.off, _best_offset(r, r.track_y), float(lvl["speed"]) * delta)
	if r.kick_t > 0.0:
		r.kick_t -= delta
		r.omega = r.dir * 38.0
		return
	r.omega = -9.0 * r.theta
	if r.cd > 0.0 or state != State.PLAY:
		return
	var dx := (_ball_pos.x - r.x) * r.dir
	if dx < -0.005 or dx > 0.095:
		return
	var aligned := false
	for i in r.men.size():
		if absf(_ball_pos.y - (r.men[i] + r.off)) < 0.032:
			aligned = true
	if not aligned:
		return
	if randf() < float(lvl["kick_p"]):
		r.kick_t = 0.11
		r.cd = 0.45
		_kicks += 1


# ---------------------------------------------------------------- la balle

func _play_ball(delta: float) -> void:
	var n := SUBSTEPS
	var dt := delta / n
	for s in n:
		var f := float(s + 1) / n
		_step_ball(dt, f, delta)
		if state != State.PLAY:
			return
	# bloquée ?
	if _ball_vel.length() < 0.05:
		_still += delta
		if _still > 2.5:
			_announce("Balle remise en jeu", Color(1, 0.8, 0.2), 1.2)
			_serve_dir = 1 if randf() < 0.5 else -1
			_begin_serve()
	else:
		_still = 0.0


func _step_ball(dt: float, f: float, frame: float) -> void:
	var sp := _ball_vel.length()
	if sp > 0.0:
		sp = maxf(0.0, sp - DECEL * dt)
		_ball_vel = _ball_vel.normalized() * minf(sp, SPEED_MAX)
	_ball_pos += _ball_vel * dt
	# joueurs
	for r in _rods:
		for i in r.men.size():
			var th := lerpf(r.theta_prev, r.theta, f)
			var of := lerpf(r.off_prev, r.off, f)
			var fp := Vector2(r.x + r.dir * LEG * sin(th), r.men[i] + of)
			var fprev := Vector2(r.x + r.dir * LEG * sin(r.theta_prev), r.men[i] + r.off_prev)
			var fnow := Vector2(r.x + r.dir * LEG * sin(r.theta), r.men[i] + r.off)
			var vf := (fnow - fprev) / frame
			_collide(fp, FR, vf, 0.55, r.team)
			var pp := Vector2(r.x, r.men[i] + of)
			var vp := Vector2(0.0, (r.off - r.off_prev) / frame)
			_collide(pp, BODY_R, vp, 0.35, r.team)
	# bords et buts
	var ly := W / 2.0 - BR
	if _ball_pos.y > ly:
		_ball_pos.y = ly
		_ball_vel.y = -_ball_vel.y * E_WALL
	elif _ball_pos.y < -ly:
		_ball_pos.y = -ly
		_ball_vel.y = -_ball_vel.y * E_WALL
	var in_mouth := absf(_ball_pos.y) < GOAL_W / 2.0
	if _ball_pos.x > L / 2.0:
		if in_mouth:
			_goal(PLAYER)
			return
	elif _ball_pos.x < -L / 2.0:
		if in_mouth:
			_goal(AI)
			return
	var lx := L / 2.0 - BR
	if _ball_pos.x > lx and not in_mouth:
		_ball_pos.x = lx
		_ball_vel.x = -_ball_vel.x * E_WALL
	elif _ball_pos.x < -lx and not in_mouth:
		_ball_pos.x = -lx
		_ball_vel.x = -_ball_vel.x * E_WALL


func _collide(c: Vector2, rc: float, vc: Vector2, e: float, team: int) -> void:
	var d := _ball_pos - c
	var dist := d.length()
	var rr := BR + rc
	if dist >= rr or dist < 0.00001:
		return
	var n := d / dist
	_ball_pos = c + n * rr
	var vr := _ball_vel - vc
	var vn := vr.dot(n)
	if vn >= 0.0:
		return
	_ball_vel += n * (-(1.0 + e) * vn)
	if _ball_vel.length() > SPEED_MAX:
		_ball_vel = _ball_vel.normalized() * SPEED_MAX
	_last_touch = team
	_touches += 1
	if -vn > 0.4:
		Sound.play_at("pet_clack", to_global(_w(c, 0.05)), -10.0 + minf(-vn, 6.0) * 1.2, 0.08)
		if team == PLAYER and -vn > 1.5:
			for h in _hands:
				if is_instance_valid(h):
					h.buzz(0.15, 0.03)


func _goal(team: int) -> void:
	scores[0 if team == PLAYER else 1] += 1
	state = State.GOAL
	_timer = 2.0 if not _selftest else 0.2
	_ball_vel = Vector2.ZERO
	var who := ("But ! " if team == PLAYER else "But adverse ")
	_announce(who + "%d – %d" % [scores[0], scores[1]], CLR_PLAYER if team == PLAYER else CLR_AI, 1.9)
	_scoreboard.celebrate("point")
	Sound.play_at("pet_land", to_global(_w(_ball_pos)), 2.0, 0.05)
	if team == PLAYER:
		_fan.react("carreau")
	else:
		_fan.react("oups")
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.5, 0.15)
	_serve_dir = -team
	_update_scoreboard()
	if not is_training() and (scores[0] >= settings["goals"] or scores[1] >= settings["goals"]):
		_end_game()


func _end_game() -> void:
	state = State.GAME_OVER
	var win: bool = scores[0] > scores[1]
	var summary := "%s %d – %d" % ["Vous gagnez" if win else "L'ordinateur gagne", maxi(scores[0], scores[1]), mini(scores[0], scores[1])]
	if win:
		_bump_stat("wins")
		_scoreboard.celebrate("win")
		_fan.say("win", true)
	else:
		_scoreboard.celebrate("lose")
	_release_rods()
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _end_training() -> void:
	state = State.GAME_OVER
	var g: int = scores[0]
	if g > _stat("best_goals"):
		_save.set_value("records", "best_goals", g)
		_save.save(SAVE_PATH)
	_announce("Temps ! %d but%s" % [g, "s" if g > 1 else ""], Color(0.4, 1, 0.5), 3.0)
	_scoreboard.celebrate("win")
	_release_rods()
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over("%d but%s en 60 secondes" % [g, "s" if g > 1 else ""])


func _announce(text: String, color: Color, seconds: float) -> void:
	_message.text = text
	_message.outline_modulate = color
	_message.modulate = Color(1, 1, 1).lerp(color, 0.2)
	_message.visible = true
	_message_time = seconds
	_message.scale = Vector3.ONE * 1.5
	var tw_ := create_tween()
	tw_.tween_property(_message, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_scoreboard() -> void:
	if is_training():
		_scoreboard.set_data("BABY-FOOT · DÉFI 60 S", ["BUTS", "RECORD"], [scores[0], maxi(_stat("best_goals"), scores[0])], 0, "Marque un maximum de buts")
		return
	var lvl := String(LEVELS[settings["level"]]["title"]).to_upper()
	_scoreboard.set_data("BABY-FOOT · " + lvl, ["VOUS", "ORDI"], scores, 0, "Premier à %d buts" % int(settings["goals"]))


func _update_visuals() -> void:
	for r in _rods:
		r.node.position.z = TZ + r.off
		r.pivot.rotation.z = r.dir * r.theta
	var bp := _w(_ball_pos, BR)
	var move := _ball_vel * get_physics_process_delta_time()
	if move.length() > 0.0:
		var axis := Vector3(move.y, 0, -move.x)
		_ball_node.rotate(axis.normalized(), move.length() / BR)
	_ball_node.position = bp
	_ball_shadow.position = _w(_ball_pos, 0.002)


# ================================================================ entrées

func _rod_for_hand(p: Vector3) -> BfRod:
	var best: BfRod = null
	var bd := 0.11
	for r in _rods:
		if r.team != PLAYER or r.held_by != null:
			continue
		var handle_z := TZ + r.off + 0.42
		if absf(p.x - r.x) > bd:
			continue
		if absf(p.z - handle_z) > 0.32 or absf(p.y - (TABLE_Y + 0.1)) > 0.45:
			continue
		best = r
		bd = absf(p.x - r.x)
	return best


func _try_grab(hand: Hand, button: String) -> void:
	if state == State.SETUP or state == State.GAME_OVER:
		return
	var p := _hand_pos(hand)
	var r := _rod_for_hand(p)
	if r == null:
		return
	r.held_by = hand
	r.hand_z0 = p.z
	r.off0 = r.off
	hand.set_meta("bf_button", button)
	hand.buzz(0.4, 0.05)
	_hint.text = ""


func _release_rods() -> void:
	for r in _rods:
		r.held_by = null


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
	if hand.has_meta("bf_button") and hand.get_meta("bf_button") == button:
		for r in _rods:
			if r.held_by == hand:
				r.held_by = null
		hand.remove_meta("bf_button")


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["ordi", "training"]:
		settings["mode"] = "ordi"
	if settings["goals"] not in [5, 10]:
		settings["goals"] = 5


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	_save.save(SAVE_PATH)


func _stat(key: String) -> int:
	return int(_save.get_value("records", key, 0))


func _bump_stat(key: String) -> void:
	_save.set_value("records", key, _stat(key) + 1)
	_save.save(SAVE_PATH)


# ================================================================ auto-test

func _st_check(name: String, ok: bool, detail: String = "") -> void:
	_st_log.append("%s : %s %s" % [name, "ok" if ok else "ECHEC", detail])
	if not ok:
		_st_failures.append(name)


func enable_selftest() -> void:
	_selftest = true
	_close_panel()
	_selftest_run()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["goals"] = 5
	_st_bot = false

	# A. La table
	var men := [0, 0]
	for r in _rods:
		men[0 if r.team == PLAYER else 1] += r.men.size()
	_st_check("8 barres, 11 joueurs par équipe", _rods.size() == 8 and men[0] == 11 and men[1] == 11, str(men))

	# B. But : la balle franchit la ligne dans la cage adverse
	_st_bot = true
	start_match()
	await _wait_frames(40)
	state = State.PLAY
	_ball_pos = Vector2(L / 2.0 - 0.03, 0.0)
	_ball_vel = Vector2(3.0, 0.0)
	var s0: int = scores[0]
	await _wait_frames(20)
	_st_check("but marqué", scores[0] == s0 + 1 and state != State.PLAY, str(scores))

	# B2. Hors de la cage : la balle rebondit
	start_match()
	await _wait_frames(40)
	state = State.PLAY
	_ball_pos = Vector2(L / 2.0 - 0.04, 0.27)
	_ball_vel = Vector2(3.0, 0.0)
	var sc2: Array = scores.duplicate()
	await _wait_frames(6)
	_st_check("pas de but sur le côté", scores == sc2 and _ball_vel.x < 0.0, str(_ball_vel))

	# B3. La balle reste sur le terrain
	var bad := 0
	for i in 8:
		_ball_pos = Vector2(randf_range(-0.4, 0.4), randf_range(-0.25, 0.25))
		_ball_vel = Vector2.from_angle(randf() * TAU) * 6.0
		state = State.PLAY
		for k in 120:
			await get_tree().physics_frame
			if state != State.PLAY:
				break
			if absf(_ball_pos.y) > W / 2.0 or absf(_ball_pos.x) > L / 2.0 + 0.05:
				bad += 1
				break
		state = State.PLAY
	_st_check("balle sur le terrain", bad == 0, "(%d sorties)" % bad)

	# C. Frappe : un joueur qui balaie envoie la balle vers l'avant
	_st_bot = false
	start_match()
	await _wait_frames(30)
	state = State.PLAY
	var rod: BfRod = _rods[5]                         # attaquants du joueur
	rod.off = 0.0
	rod.off_prev = 0.0
	rod.theta = -0.9
	rod.theta_prev = -0.9
	_ball_pos = Vector2(rod.x + 0.03, rod.men[1])
	_ball_vel = Vector2.ZERO
	# on imite une main qui balaie vers +x
	var hit_v := 0.0
	_test_rod = rod
	_test_vx = 2.0
	for i in 40:
		await get_tree().physics_frame
		hit_v = maxf(hit_v, _ball_vel.x)
	_test_rod = null
	_st_check("frappe vers l'avant", hit_v > 1.5, "(vitesse %.1f m/s)" % hit_v)

	# D. Prise d'une barre
	var hp := Vector3(_rods[3].x + 0.02, TABLE_Y + 0.1, TZ + _rods[3].off + 0.4)
	_st_check("barre attrapée près de la poignée", _rod_for_hand(hp) == _rods[3], "")
	hp.x += 0.5
	_st_check("loin d'une barre : rien", _rod_for_hand(hp) == null or _rod_for_hand(hp) != _rods[3], "")
	var tr: BfRod = _rods[1]
	tr.off = 0.0
	tr.off0 = 0.0
	tr.hand_z0 = 0.0
	for i in 30:
		apply_hand(tr, 0.2, 0.0, 1.0 / 90.0)
	_st_check("la barre suit la main", absf(tr.off - 0.2) < 0.02, "(%.3f)" % tr.off)
	for i in 10:
		apply_hand(tr, 0.2, 1.5, 1.0 / 90.0)
	_st_check("la main fait tourner", tr.omega > 5.0, "(%.1f)" % tr.omega)

	# E. Parties complètes : ordinateur contre ordinateur, chaque niveau
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		settings["mode"] = "ordi"
		settings["goals"] = 5 if lv == "normal" else 2
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 900:
			await get_tree().physics_frame
			guard += 1
			if guard == 90 * 600 and state != State.GAME_OVER:
				break
		_st_check("partie %s terminée" % lv, state == State.GAME_OVER, "%s en %.0f s (%d frappes)" % [str(scores), guard / 90.0, _kicks])

	# F. Défi chrono
	settings["mode"] = "training"
	settings["level"] = "normal"
	_train_time = 15.0
	_st_bot = true
	start_match()
	var g2 := 0
	while state != State.GAME_OVER and g2 < 90 * 120:
		await get_tree().physics_frame
		g2 += 1
	_st_check("défi chrono terminé", state == State.GAME_OVER, "(%d buts)" % scores[0])
	_st_bot = false

	for line in _st_log:
		print("SELFTEST babyfoot ", line)
	print("SELFTEST babyfoot=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())


## Test : simule une main qui balaie à `vx` m/s (sans main réelle).
func _apply_sweep(r: BfRod, vx: float) -> void:
	r.omega = clampf(vx * r.dir * SPIN_GAIN - 7.0 * r.theta, -OMEGA_MAX, OMEGA_MAX)
