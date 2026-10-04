class_name PingPongGame
extends Node3D
## Ping-pong en réalité augmentée : table réglementaire devant le joueur, une raquette
## dans la main, un adversaire robot (mode Match) ou une machine à balles (Entraînement).
## Physique maison : la balle vole avec une gravité simple, rebondit sur la table et
## sur les raquettes (test de traversée, donc jamais de balle qui passe au travers).
## Le noeud est placé aux pieds du joueur ; la table est devant lui, vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const G := 9.81
const BALL_R := 0.028
const TABLE_Y := PingTable.TOP_Y
const NET_H := PingTable.NET_H
const E_TABLE := 0.9
const E_PADDLE := 0.55
const MAX_SPEED := 12.0
const Z_NEAR := -0.35
const SUBSTEPS := 2
const SAVE_PATH := "user://pingpong.cfg"
const PLAYER := 1
const AI := -1

const LEVELS := {
	"facile": {"title": "Facile", "assist": 1.0, "ai_speed": 1.5, "reaction": 0.30, "sigma": 0.22, "p_err": 0.22, "vmin": 2.6, "vmax": 3.5, "reach": 0.10},
	"normal": {"title": "Normal", "assist": 0.7, "ai_speed": 2.6, "reaction": 0.18, "sigma": 0.12, "p_err": 0.09, "vmin": 3.4, "vmax": 4.6, "reach": 0.12},
	"expert": {"title": "Expert", "assist": 0.35, "ai_speed": 4.0, "reaction": 0.09, "sigma": 0.05, "p_err": 0.03, "vmin": 4.6, "vmax": 6.2, "reach": 0.14},
}

enum State { SETUP, SERVE_WAIT, WAIT_LAUNCH, RALLY, POINT_PAUSE, GAME_OVER }


class PadState:
	var pos := Vector3.ZERO
	var prev := Vector3.ZERO
	var vel := Vector3.ZERO
	var normal := Vector3(0, 0, -1)
	var radius := 0.11
	var cooldown := 0.0


var settings := {"mode": "match", "level": "normal", "points": 11, "hand": "right", "table": "normal", "music": true}
var state := State.SETUP
var scores := [0, 0]            # [vous, ordinateur]
var first_server := PLAYER
var server := PLAYER

# Géométrie de la table (repère du jeu)
var tl := 2.74
var tw := 1.525
var z_far := Z_NEAR - 2.74
var z_net := Z_NEAR - 1.37
var z_ai := Z_NEAR - 2.74 - 0.15

# Balle et échange
var ball_pos := Vector3.ZERO
var ball_vel := Vector3.ZERO
var ball_live := false
var _last_hitter := 0
var _serving := true
var _own_bounces := 0
var _opp_bounces := 0
var _rally_hits := 0
var _rally_over := false
var _timer := 0.0
var _rally_time := 0.0

# Entraînement
var _streak := 0
var _best_streak_session := 0
var _returns := 0

var _hands: Array = []
var _hand: Hand = null
var _pad := PadState.new()
var _ai_pad := PadState.new()
var _ai_target := Vector3.ZERO
var _ai_react := 0.0
var _ai_err := Vector2.ZERO
var _ai_plan_t := 0.0
var _ai_kick := 0.0

var _table: PingTable
var _decor: Node3D
var _ball: MeshInstance3D
var _shadow: MeshInstance3D
var _player_paddle: PingPaddle
var _ai_paddle: PingPaddle
var _robot: Node3D
var _robot_arm: MeshInstance3D
var _robot_anchor := Vector3.ZERO
var _referee: Spectator
var _scoreboard: PingScoreboard
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _message: Label3D
var _message_time := 0.0
var _hint: Label3D
var _fx_root: Node3D
var _save := ConfigFile.new()

var _selftest := false
var _st_bot := false
var _st_log: Array = []
var _st_failures: Array = []


# ================================================================ mise en place

func set_hands(left: Hand, right: Hand) -> void:
	_hands = [left, right]


func _ready() -> void:
	_load_save()
	_table = PingTable.new()
	add_child(_table)
	_scoreboard = PingScoreboard.new()
	add_child(_scoreboard)
	_fx_root = Node3D.new()
	add_child(_fx_root)

	_ball = BowlingArt.sphere(BALL_R, PingArt.ball_material(), Vector3.ZERO, 20 if VisualStyle.detailed else 14)
	add_child(_ball)
	_shadow = BowlingArt.make_blob(0.09)
	add_child(_shadow)

	_player_paddle = PingPaddle.new()
	add_child(_player_paddle)
	_ai_paddle = PingPaddle.new()
	_ai_paddle.front_color = Color(0.2, 0.5, 1.0)
	_ai_paddle.glow = true
	add_child(_ai_paddle)
	_robot = Node3D.new()
	add_child(_robot)

	_referee = Spectator.new({
		"name": "Gégé", "skin": Color(0.95, 0.78, 0.65), "shirt": Color(0.85, 0.32, 0.15),
		"pants": Color(0.2, 0.22, 0.3), "hair": Color(0.45, 0.4, 0.38), "beard": true,
		"hat": true, "hat_color": Color(0.15, 0.3, 0.75),
	})
	add_child(_referee)

	_message = BowlingArt.neon_label("", 0.13, Color(1, 0.8, 0.2))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.no_depth_test = true
	_message.visible = false
	add_child(_message)
	_hint = BowlingArt.label("", 0.045, Color(1, 0.95, 0.7))
	_hint.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hint.no_depth_test = true
	add_child(_hint)
	_panel = UiPanel.new()
	_panel.accent = Color(0.2, 0.8, 0.45)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)

	_apply_layout()
	_ball.visible = false
	_shadow.visible = false
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


## Dimensions de la table (normale ou compacte) et position des éléments.
func _apply_layout() -> void:
	var sc := 1.0 if settings["table"] == "normal" else 0.75
	tl = 2.74 * sc
	tw = 1.525 * sc
	z_far = Z_NEAR - tl
	z_net = Z_NEAR - tl / 2.0
	z_ai = z_far - 0.15
	if _table.is_inside_tree() and (not is_equal_approx(_table.length, tl)):
		pass
	_table.length = tl
	_table.width = tw
	if _table.get_child_count() > 0:
		for c in _table.get_children():
			c.queue_free()
		_table._ready()
	_table.position = Vector3(0, 0, z_net)
	_scoreboard.position = Vector3(0, 1.7, z_far - 1.0)
	_scoreboard.scale = Vector3.ONE * 1.5
	_build_decor()
	_robot_anchor = Vector3(tw / 2.0 + 0.55, 1.05, z_far - 0.4)
	_build_robot()
	_referee.position = Vector3(-(tw / 2.0 + 0.9), 0, z_far + 0.4)
	var to := Vector3(0, 0, z_net) - _referee.position
	_referee.rotation.y = atan2(to.x, to.z)
	_message.position = Vector3(0, 1.75, z_net)
	_hand = _hands[1 if settings["hand"] == "right" else 0] if _hands.size() == 2 else null
	_ai_pad.pos = Vector3(0, TABLE_Y + 0.3, z_ai)
	_ai_pad.prev = _ai_pad.pos
	_ai_target = _ai_pad.pos
	_pad.pos = Vector3(0.3, 1.0, 0.0)
	_pad.prev = _pad.pos


## Salle de jeu : tapis sous la table, enseigne néon, plantes, lampadaires.
func _build_decor() -> void:
	if _decor == null:
		_decor = Node3D.new()
		add_child(_decor)
	for c in _decor.get_children():
		c.queue_free()
	_decor.add_child(Decor.sport_corner("garden", Vector3(tw / 2.0 + 1.0, 0, z_net)))
	_decor.add_child(Decor.rug(Vector2(tw + 2.4, tl + 2.6), Color(0.1, 0.16, 0.3), Vector3(0, 0.002, z_net)))
	_decor.add_child(Decor.rug(Vector2(tw + 2.6, tl + 2.8), Color(0.22, 0.27, 0.4), Vector3(0, 0.0015, z_net)))
	var sign_node := Decor.neon_sign("PING-PONG", Color(0.2, 0.8, 0.45), 1.7, 0.48)
	sign_node.position = Vector3(-(tw / 2.0 + 1.9), 1.6, z_net)
	sign_node.rotation.y = PI / 2.0
	_decor.add_child(sign_node)
	for sx in [-1.0, 1.0]:
		var pl := Decor.plant(1.0)
		pl.position = Vector3(sx * (tw / 2.0 + 1.0), 0, z_far - 0.5)
		_decor.add_child(pl)
		var lp := Decor.lamp(2.2, Color(0.6, 0.85, 1.0))
		lp.position = Vector3(sx * (tw / 2.0 + 1.4), 0, Z_NEAR + 0.3)
		_decor.add_child(lp)


func _build_robot() -> void:
	for c in _robot.get_children():
		c.queue_free()
	var metal := BowlingArt.mat(Color(0.22, 0.24, 0.3), 0.3, 0.8)
	var accent := BowlingArt.glow(Color(0.2, 0.6, 1.0), 1.2)
	_robot.add_child(BowlingArt.cylinder(0.2, 0.22, 0.05, metal, Vector3(_robot_anchor.x, 0.025, _robot_anchor.z), 24))
	_robot.add_child(BowlingArt.cylinder(0.05, 0.06, _robot_anchor.y, metal, Vector3(_robot_anchor.x, _robot_anchor.y / 2.0, _robot_anchor.z), 16))
	_robot.add_child(BowlingArt.sphere(0.09, accent, _robot_anchor, 16))
	var head := BowlingArt.sphere(0.12, metal, _robot_anchor + Vector3(0, 0.22, 0), 18)
	_robot.add_child(head)
	for sx in [-0.045, 0.045]:
		_robot.add_child(BowlingArt.sphere(0.025, accent, _robot_anchor + Vector3(sx, 0.23, 0.1), 8))
	_robot_arm = BowlingArt.capsule(0.03, 1.0, metal, Vector3.ZERO)
	_robot.add_child(_robot_arm)


func _update_robot_arm() -> void:
	# La capsule relie l'épaule du robot à la raquette adverse
	var a := _robot_anchor
	var b := _ai_pad.pos + Vector3(0, -PingPaddle.RADIUS - 0.05, 0.0)
	var d := b - a
	var len := maxf(d.length(), 0.05)
	_robot_arm.position = (a + b) / 2.0
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT
	_robot_arm.global_basis = Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, PI / 2.0)
	_robot_arm.scale = Vector3(1, len, 1)


## Replace la zone de jeu devant le joueur.
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

func show_setup() -> void:
	state = State.SETUP
	_ball_hide()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Ping-pong", "Victoires : %d   ·   meilleur échange : %d   ·   meilleure série : %d" % [_stat("wins"), _stat("best_rally"), _stat("best_streak")])
	_panel.add_row("Mode", [
		{"id": "mode_match", "text": "Contre l'ordi", "width": 0.28, "selected": settings["mode"] == "match"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.28, "selected": settings["mode"] == "training"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Points", [
		{"id": "points_7", "text": "7", "width": 0.14, "selected": settings["points"] == 7},
		{"id": "points_11", "text": "11", "width": 0.14, "selected": settings["points"] == 11},
	])
	_panel.add_row("Raquette", [
		{"id": "hand_right", "text": "Main droite", "width": 0.26, "selected": settings["hand"] == "right"},
		{"id": "hand_left", "text": "Main gauche", "width": 0.26, "selected": settings["hand"] == "left"},
	])
	_panel.add_row("Table", [
		{"id": "table_normal", "text": "Normale", "width": 0.22, "selected": settings["table"] == "normal"},
		{"id": "table_compact", "text": "Compacte", "width": 0.22, "selected": settings["table"] == "compact"},
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
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)
	_set_paddle_visible(false)


## Masque le panneau du jeu pendant que « Changer de jeu » est ouvert.
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
	_set_paddle_visible(true)


func _set_paddle_visible(on: bool) -> void:
	_player_paddle.visible = on


func _set_lasers(on: bool) -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = on


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("mode_"):
		settings["mode"] = id.substr(5)
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
	elif id.begins_with("points_"):
		settings["points"] = int(id.substr(7))
	elif id.begins_with("hand_"):
		settings["hand"] = id.substr(5)
	elif id.begins_with("table_"):
		settings["table"] = id.substr(6)
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
	scores = [0, 0]
	first_server = PLAYER
	_streak = 0
	_returns = 0
	_best_streak_session = 0
	server = PLAYER
	_reset_ai_pad()
	_update_scoreboard()
	_start_serve()


func is_training() -> bool:
	return settings["mode"] == "training"


func _compute_server() -> int:
	var total: int = scores[0] + scores[1]
	var target: int = settings["points"]
	if scores[0] >= target - 1 and scores[1] >= target - 1:
		return first_server if total % 2 == 0 else -first_server
	return first_server if (total / 2) % 2 == 0 else -first_server


func _start_serve() -> void:
	_rally_over = false
	_last_hitter = 0
	_serving = true
	_own_bounces = 0
	_opp_bounces = 0
	_rally_hits = 0
	_rally_time = 0.0
	ball_live = false
	_reset_ai_pad()
	if is_training():
		server = AI
		state = State.WAIT_LAUNCH
		_timer = 1.2
		_ball_hide()
		_hint.text = ""
		_update_scoreboard()
		return
	server = _compute_server()
	_update_scoreboard()
	if server == PLAYER:
		state = State.SERVE_WAIT
		ball_pos = Vector3(0.0, 1.0, Z_NEAR - 0.25)
		ball_vel = Vector3.ZERO
		_ball_show()
		_hint.position = ball_pos + Vector3(0, 0.22, 0)
		_hint.text = "Gâchette : lancer la balle\npuis frappe-la !"
	else:
		state = State.WAIT_LAUNCH
		_timer = 1.4
		_ball_hide()
		_hint.text = ""


func _reset_ai_pad() -> void:
	_ai_target = Vector3(0, TABLE_Y + 0.3, z_ai)
	_ai_react = 0.0


func _toss() -> void:
	ball_vel = Vector3(0, 2.4, 0)
	ball_live = true
	_last_hitter = 0
	_serving = true
	state = State.RALLY
	_hint.text = ""
	Sound.play_at("grab", ball_pos, -8.0, 0.1)


## L'ordinateur (ou la machine à balles) envoie une balle vers le joueur.
func _launch_from_ai() -> void:
	var lvl: Dictionary = LEVELS[settings["level"]]
	var start := Vector3(randf_range(-0.25, 0.25), TABLE_Y + 0.3, z_far - 0.1)
	if is_training():
		start.x = randf_range(-0.4, 0.4)
	var tx := randf_range(-tw / 2.0 + 0.2, tw / 2.0 - 0.2)
	var tz := randf_range(z_net + tl * 0.25, Z_NEAR - 0.15)
	var vh := randf_range(float(lvl["vmin"]) * 0.85, float(lvl["vmax"]) * 0.85)
	if is_training():
		vh = randf_range(2.8, 4.2)
	ball_pos = start
	ball_vel = _solve_shot(start, Vector3(tx, TABLE_Y + BALL_R, tz), vh, true)
	ball_live = true
	_last_hitter = AI
	_serving = true
	_own_bounces = 0
	_opp_bounces = 0
	_ai_pad.pos = start + Vector3(0, 0.05, -0.1)
	_ai_pad.prev = _ai_pad.pos
	_ai_kick = 0.15
	_ball_show()
	state = State.RALLY
	Sound.play_at("pp_paddle", ball_pos, -2.0, 0.05)


func _ball_show() -> void:
	_ball.visible = true
	_shadow.visible = true
	_ball.global_position = to_global(ball_pos)


func _ball_hide() -> void:
	_ball.visible = false
	_shadow.visible = false


# ================================================================ physique de la balle

## Avance la balle d'un pas. Renvoie les évènements : "table" (±1 côté), "net", "floor".
func _advance(s: Dictionary, dt: float) -> Dictionary:
	var ev := {}
	var pos: Vector3 = s["pos"]
	var vel: Vector3 = s["vel"]
	var prev := pos
	vel.y -= G * dt
	pos += vel * dt
	if (prev.z - z_net) * (pos.z - z_net) < 0.0 and pos.y - BALL_R < TABLE_Y + NET_H and pos.y > TABLE_Y - 0.1 and absf(pos.x) < tw / 2.0 + 0.1:
		ev["net"] = true
		vel.z = -vel.z * 0.2
		vel.x *= 0.5
		pos.z = prev.z
	elif vel.y < 0.0 and prev.y - BALL_R >= TABLE_Y and pos.y - BALL_R < TABLE_Y and absf(pos.x) <= tw / 2.0 and pos.z <= Z_NEAR and pos.z >= z_far:
		pos.y = TABLE_Y + BALL_R
		vel.y = -vel.y * E_TABLE
		vel.x *= 0.98
		vel.z *= 0.98
		ev["table"] = PLAYER if pos.z > z_net else AI
	if pos.y < BALL_R and vel.y < 0.0:
		pos.y = BALL_R
		vel.y = -vel.y * 0.5
		vel.x *= 0.8
		vel.z *= 0.8
		ev["floor"] = true
	s["pos"] = pos
	s["vel"] = vel
	return ev


## Vitesse de départ pour qu'une balle lancée de `p` retombe en `t` (sur la table, hauteur de la balle),
## en passant au-dessus du filet. `vh` : vitesse horizontale souhaitée (réduite si le filet gêne).
func _solve_shot(p: Vector3, t: Vector3, vh: float, check_net: bool) -> Vector3:
	var flat := Vector2(t.x - p.x, t.z - p.z)
	var dist := maxf(flat.length(), 0.05)
	var best := Vector3.ZERO
	var speed := vh
	for i in 10:
		var tt := dist / speed
		var v := Vector3(flat.x / tt, (t.y - p.y + 0.5 * G * tt * tt) / tt, flat.y / tt)
		best = v
		if not check_net or absf(v.z) < 0.01:
			break
		var tn := (z_net - p.z) / v.z
		if tn <= 0.0 or tn >= tt:
			break
		var y_net := p.y + v.y * tn - 0.5 * G * tn * tn
		if y_net > TABLE_Y + NET_H + BALL_R + 0.04:
			break
		speed *= 0.85
	return best


## Simule la trajectoire : liste des rebonds sur la table, filet touché, sol touché.
func _simulate(p: Vector3, v: Vector3, steps: int = 400) -> Dictionary:
	var s := {"pos": p, "vel": v}
	var out := {"bounces": [], "net": false, "floor": false, "pos": p}
	var dt := 1.0 / 90.0
	for i in steps:
		var ev := _advance(s, dt)
		if ev.has("table"):
			out["bounces"].append({"side": ev["table"], "pos": s["pos"]})
		if ev.has("net"):
			out["net"] = true
			break
		if ev.has("floor"):
			out["floor"] = true
			break
	out["pos"] = s["pos"]
	return out


# ================================================================ boucle

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
		return   # jeu en pause tant qu'un panneau est ouvert

	_update_player_pad(delta)
	_update_ai(delta)
	_pad.cooldown = maxf(0.0, _pad.cooldown - delta)
	_ai_pad.cooldown = maxf(0.0, _ai_pad.cooldown - delta)

	match state:
		State.WAIT_LAUNCH:
			_timer -= delta
			if _timer <= 0.0:
				_launch_from_ai()
		State.RALLY:
			_rally_time += delta
			_step_rally(delta)
			if _rally_time > 20.0 and not _rally_over:
				_point(-_last_hitter if _last_hitter != 0 else AI, "")
		State.POINT_PAUSE:
			_timer -= delta
			if ball_live:
				_free_fall(delta)
			if _timer <= 0.0:
				_after_pause()
		State.SERVE_WAIT:
			_ball.global_position = to_global(ball_pos)
			_pulse_ball()
	_update_visuals()


func _pulse_ball() -> void:
	_ball.scale = Vector3.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008))


## Mise à jour de la raquette du joueur à partir de la manette (ou du robot de test).
func _update_player_pad(delta: float) -> void:
	_pad.prev = _pad.pos
	if _st_bot:
		_st_bot_step(delta)
		return
	if _hand == null or not is_instance_valid(_hand):
		return
	var xf := to_local(_hand.global_position)
	var gt := global_transform.affine_inverse() * _hand.global_transform
	var center := gt * Vector3(0, 0.1, -0.04)
	_pad.pos = center
	_pad.normal = (gt.basis * Vector3(0, 0, -1)).normalized()
	var raw := (_pad.pos - _pad.prev) / maxf(delta, 0.0001)
	_pad.vel = _pad.vel.lerp(raw, 0.6)
	_pad.radius = PingPaddle.RADIUS + 0.025
	if xf.length() > 100.0:
		_pad.vel = Vector3.ZERO


func _update_visuals() -> void:
	if _hand and not _st_bot:
		var gt := global_transform.affine_inverse() * _hand.global_transform
		_player_paddle.transform = gt * Transform3D(Basis(), Vector3(0, 0.1, -0.04))
	else:
		_player_paddle.position = _pad.pos
		_player_paddle.basis = Basis.looking_at(-_pad.normal, Vector3.UP)
	# Raquette adverse : face vers le joueur, petit coup vers l'avant lors d'une frappe
	_ai_paddle.visible = not is_training()
	_robot.visible = not is_training()
	_ai_paddle.position = _ai_pad.pos + Vector3(0, 0, _ai_kick * 0.5)
	_ai_paddle.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.12 * clampf(_ai_pad.vel.y, -1.0, 1.0))
	_ai_kick = maxf(0.0, _ai_kick - get_physics_process_delta_time())
	if not is_training():
		_update_robot_arm()
	if _ball.visible:
		_ball.global_position = to_global(ball_pos)
		var h := maxf(ball_pos.y - TABLE_Y, 0.0)
		var over_table := absf(ball_pos.x) <= tw / 2.0 and ball_pos.z <= Z_NEAR and ball_pos.z >= z_far
		_shadow.visible = over_table and ball_live or state == State.SERVE_WAIT
		_shadow.global_position = to_global(Vector3(ball_pos.x, TABLE_Y + 0.003, ball_pos.z))
		_shadow.scale = Vector3.ONE * (1.0 + h * 0.6)


# ================================================================ échange

func _step_rally(delta: float) -> void:
	var dt := delta / SUBSTEPS
	var s := {"pos": ball_pos, "vel": ball_vel}
	for i in SUBSTEPS:
		var p0 := _pad.prev.lerp(_pad.pos, float(i) / SUBSTEPS)
		var p1 := _pad.prev.lerp(_pad.pos, float(i + 1) / SUBSTEPS)
		var a0 := _ai_pad.prev.lerp(_ai_pad.pos, float(i) / SUBSTEPS)
		var a1 := _ai_pad.prev.lerp(_ai_pad.pos, float(i + 1) / SUBSTEPS)
		var b0: Vector3 = s["pos"]
		var ev := _advance(s, dt)
		var b1: Vector3 = s["pos"]
		if _rally_over:
			continue
		if ev.has("net"):
			ball_pos = s["pos"]
			ball_vel = s["vel"]
			Sound.play_at("pp_net", to_global(ball_pos), -2.0)
			if _last_hitter != 0:
				_point(-_last_hitter, "Dans le filet !")
			else:
				_serve_fail("Filet !")
			return
		if ev.has("table"):
			ball_pos = s["pos"]
			Sound.play_at("pp_table", to_global(ball_pos), -3.0, 0.08)
			_bounce_fx(ball_pos)
			_on_table_bounce(int(ev["table"]))
			if _rally_over:
				ball_vel = s["vel"]
				return
		if ev.has("floor"):
			ball_pos = s["pos"]
			ball_vel = s["vel"]
			_on_floor()
			return
		# Raquette du joueur
		if _pad.cooldown <= 0.0 and _paddle_contact(_pad, p0, p1, b0, b1):
			s["vel"] = _player_hit(s["pos"], s["vel"])
		elif not is_training() and _ai_pad.cooldown <= 0.0 and _last_hitter == PLAYER and _opp_bounces >= 1 and _paddle_contact(_ai_pad, a0, a1, b0, b1, Vector3(0, 0, 1)):
			s["vel"] = _ai_return(s["pos"])
	ball_pos = s["pos"]
	ball_vel = s["vel"]
	if ball_vel.length() > MAX_SPEED:
		ball_vel = ball_vel.normalized() * MAX_SPEED


## Test de contact balle / raquette (traversée du plan de la raquette dans le disque).
func _paddle_contact(P: PadState, p0: Vector3, p1: Vector3, b0: Vector3, b1: Vector3, normal_override: Vector3 = Vector3.ZERO) -> bool:
	var n := P.normal if normal_override == Vector3.ZERO else normal_override
	var d0 := (b0 - p0).dot(n)
	var d1 := (b1 - p1).dot(n)
	var crossed := d0 * d1 <= 0.0
	if not crossed and absf(d1) > BALL_R:
		return false
	var t := 1.0
	if crossed and absf(d0 - d1) > 0.00001:
		t = clampf(d0 / (d0 - d1), 0.0, 1.0)
	var bc := b0.lerp(b1, t)
	var pc := p0.lerp(p1, t)
	var rel := bc - pc
	var in_plane := rel - n * rel.dot(n)
	return in_plane.length() <= P.radius + BALL_R


func _player_hit(pos: Vector3, vel: Vector3) -> Vector3:
	var P := _pad
	var side := signf((pos - P.pos).dot(P.normal))
	if side == 0.0:
		side = 1.0
	var n := P.normal * side
	var v_rel := vel - P.vel
	var vn := v_rel.dot(n)
	if vn >= 0.0:
		return vel
	v_rel -= (1.0 + E_PADDLE) * vn * n
	var normal_part := n * v_rel.dot(n)
	v_rel = normal_part + (v_rel - normal_part) * 0.92
	var out := P.vel + v_rel
	out = _assist(pos, out)
	if out.length() > MAX_SPEED:
		out = out.normalized() * MAX_SPEED
	P.cooldown = 0.12
	_after_player_hit(pos, out)
	return out


## Aide : un tir qui partait mal (filet, dehors, dans son camp) est rapproché d'une
## trajectoire qui retombe sur la moitié adverse. Un bon tir n'est jamais modifié.
func _assist(pos: Vector3, out: Vector3) -> Vector3:
	var assist: float = LEVELS[settings["level"]]["assist"]
	if assist <= 0.0 or out.z > -0.6:
		return out
	var raw := _simulate(pos, out, 240)
	var rb: Array = raw["bounces"]
	if not raw["net"] and not rb.is_empty() and int(rb[0]["side"]) == AI:
		return out
	# Plus on frappe fort, plus la balle est visée profond
	var strength := clampf((Vector2(out.x, out.z).length() - 2.0) / 4.0, 0.0, 1.0)
	var z_t := z_net - tl * lerpf(0.12, 0.4, strength)
	var dz := pos.z - z_t
	if dz < 0.3:
		return out
	var x_t := clampf(pos.x + out.x * (dz / -out.z), -tw / 2.0 + 0.15, tw / 2.0 - 0.15)
	var vh := lerpf(2.8, 5.2, strength)
	var ideal := _solve_shot(pos, Vector3(x_t, TABLE_Y + BALL_R, z_t), vh, true)
	return out.lerp(ideal, assist)


func _after_player_hit(pos: Vector3, out: Vector3) -> void:
	if _rally_over:
		return
	_last_hitter = PLAYER
	_own_bounces = 0
	_opp_bounces = 0
	_rally_hits += 1
	Sound.play_at("pp_paddle", to_global(pos), -1.0, 0.06)
	if _hand and is_instance_valid(_hand):
		_hand.buzz(clampf(out.length() / 10.0, 0.25, 0.9), 0.07)
	_ai_plan_t = 0.0
	_ai_react = float(LEVELS[settings["level"]]["reaction"])
	var sg: float = LEVELS[settings["level"]]["sigma"]
	_ai_err = Vector2(randfn(0.0, sg), randfn(0.0, sg * 0.7))


func _on_table_bounce(side: int) -> void:
	if _rally_over:
		return
	if _last_hitter == 0:
		# La balle lancée pour servir tombe sur la table : un rebond est toléré
		_own_bounces += 1
		if _own_bounces >= 2:
			_serve_fail("Service raté !")
		return
	if side == _last_hitter:
		if _serving and _own_bounces == 0:
			_own_bounces = 1
			return
		_point(-_last_hitter, "Dans son camp !" if _last_hitter == AI else "Dans ton camp !")
		return
	_opp_bounces += 1
	_serving = false
	if _opp_bounces >= 2:
		_point(_last_hitter, "")


func _on_floor() -> void:
	if _rally_over:
		return
	if _last_hitter == 0:
		_serve_fail("Service raté !")
	elif _opp_bounces >= 1:
		_point(_last_hitter, "")
	else:
		_point(-_last_hitter, "Dehors !")


## Service manqué (balle lancée mais pas frappée, filet…) : on recommence sans point.
func _serve_fail(msg: String) -> void:
	if _rally_over:
		return
	_announce(msg, Color(0.9, 0.9, 0.9), 1.5)
	ball_live = false
	_start_serve_after(1.0)


func _start_serve_after(seconds: float) -> void:
	state = State.POINT_PAUSE
	_timer = seconds
	_rally_over = true
	_pending_point = false


var _pending_point := false


func _point(winner: int, reason: String) -> void:
	if _rally_over:
		return
	_rally_over = true
	_pending_point = true
	state = State.POINT_PAUSE
	_timer = 2.0
	if is_training():
		_training_result(winner == PLAYER and _last_hitter == PLAYER)
		return
	var idx := 0 if winner == PLAYER else 1
	scores[idx] += 1
	var long_rally := _rally_hits >= 8
	_best_stat("best_rally", _rally_hits)
	if winner == PLAYER:
		_announce("POINT !" if reason == "" else reason + "\nPoint pour vous", Color(0.3, 1.0, 0.5), 2.0)
		Sound.play("cheer_small", -4.0)
		_scoreboard.celebrate("point")
		_referee.react("good")
	else:
		_announce("Point ordi" if reason == "" else reason + "\nPoint ordi", Color(1.0, 0.4, 0.35), 2.0)
		Sound.play("gutter", -6.0)
		_scoreboard.celebrate("lose")
		_referee.react("low")
	if long_rally:
		Sound.play("cheer_big", -6.0)
	_update_scoreboard()
	var target: int = settings["points"]
	if (scores[0] >= target or scores[1] >= target) and absi(scores[0] - scores[1]) >= 2:
		_game_over()


func _training_result(success: bool) -> void:
	if success:
		_streak += 1
		_returns += 1
		_best_streak_session = maxi(_best_streak_session, _streak)
		_best_stat("best_streak", _streak)
		_announce("%d de suite !" % _streak if _streak > 1 else "Bien !", Color(0.3, 1.0, 0.5), 1.4)
		Sound.play("clink", -4.0)
		if _streak % 5 == 0:
			Sound.play("cheer_small", -4.0)
			_referee.react("good")
	else:
		if _streak >= 3:
			_referee.react("low")
		_streak = 0
		_announce("Raté", Color(0.9, 0.9, 0.9), 1.0)
	_update_scoreboard()


func _after_pause() -> void:
	ball_live = false
	if state == State.GAME_OVER:
		return
	_start_serve()


func _free_fall(delta: float) -> void:
	# La balle finit sa course (visuel seulement)
	var s := {"pos": ball_pos, "vel": ball_vel}
	var ev := _advance(s, delta)
	ball_pos = s["pos"]
	ball_vel = s["vel"]
	if ev.has("table"):
		Sound.play_at("pp_table", to_global(ball_pos), -8.0, 0.1)
	if ball_pos.y <= BALL_R + 0.01 and ball_vel.length() < 0.4:
		ball_live = false


func _game_over() -> void:
	state = State.GAME_OVER
	var won: bool = scores[0] > scores[1]
	var summary := "Vous %s : %d - %d" % ["gagnez" if won else "perdez", scores[0], scores[1]]
	if won:
		_bump_stat("wins")
		_announce("VICTOIRE !", Color(1, 0.8, 0.2), 6.0)
		Sound.play("cheer_big")
		_scoreboard.celebrate("win")
		_referee.react("win")
	else:
		_announce("DÉFAITE…", Color(1, 0.4, 0.35), 5.0)
		_referee.react("low")
	_update_scoreboard()
	if not _selftest:
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			if state == State.GAME_OVER and is_inside_tree():
				show_game_over(summary))


# ================================================================ adversaire

func _update_ai(delta: float) -> void:
	if is_training():
		return
	var lvl: Dictionary = LEVELS[settings["level"]]
	_ai_pad.prev = _ai_pad.pos
	_ai_pad.normal = Vector3(0, 0, 1)
	_ai_pad.radius = float(lvl["reach"])
	var idle := Vector3(0, TABLE_Y + 0.3, z_ai)
	if state == State.RALLY and ball_live and _last_hitter == PLAYER and ball_vel.z < 0.0:
		_ai_react -= delta
		_ai_plan_t -= delta
		if _ai_plan_t <= 0.0:
			_ai_plan_t = 0.08
			var pred := _ai_predict()
			if pred.size() > 0:
				var p: Vector3 = pred["pos"]
				_ai_target = Vector3(clampf(p.x + _ai_err.x, -tw / 2.0 - 0.3, tw / 2.0 + 0.3), clampf(p.y + _ai_err.y, TABLE_Y + 0.05, TABLE_Y + 0.65), z_ai)
			else:
				_ai_target = idle
		if _ai_react <= 0.0:
			_ai_pad.pos = _ai_pad.pos.move_toward(_ai_target, float(lvl["ai_speed"]) * delta)
			_ai_pad.pos.z = z_ai
	elif state != State.RALLY or not ball_live:
		_ai_pad.pos = _ai_pad.pos.move_toward(idle, float(lvl["ai_speed"]) * 0.5 * delta)
	_ai_pad.vel = (_ai_pad.pos - _ai_pad.prev) / maxf(delta, 0.0001)


## Où la balle franchira le plan de l'adversaire, après un rebond de son côté.
func _ai_predict() -> Dictionary:
	var s := {"pos": ball_pos, "vel": ball_vel}
	var bounced := _opp_bounces >= 1
	var dt := 1.0 / 90.0
	for i in 400:
		var ev := _advance(s, dt)
		if ev.has("table"):
			if int(ev["table"]) == AI:
				bounced = true
			else:
				return {}
		if ev.has("net") or ev.has("floor"):
			return {}
		var p: Vector3 = s["pos"]
		if p.z <= z_ai:
			if bounced:
				return {"pos": p, "t": i * dt}
			return {}
	return {}


## L'ordinateur renvoie la balle (avec une chance de se tromper selon le niveau).
func _ai_return(pos: Vector3) -> Vector3:
	var lvl: Dictionary = LEVELS[settings["level"]]
	var mistake := randf() < float(lvl["p_err"])
	var tx := randf_range(-tw / 2.0 + 0.15, tw / 2.0 - 0.15)
	if settings["level"] == "expert" and randf() < 0.6:
		tx = signf(tx) * randf_range(tw / 2.0 - 0.3, tw / 2.0 - 0.12)
	var tz := randf_range(z_net + tl * 0.2, Z_NEAR - 0.15)
	if mistake:
		if randf() < 0.5:
			tz = Z_NEAR + randf_range(0.25, 0.7)
		else:
			tx = signf(tx) * (tw / 2.0 + randf_range(0.2, 0.5))
	var vh := randf_range(float(lvl["vmin"]), float(lvl["vmax"]))
	var v := _solve_shot(pos, Vector3(tx, TABLE_Y + BALL_R, tz), vh, not mistake)
	_ai_pad.cooldown = 0.2
	_last_hitter = AI
	_own_bounces = 0
	_opp_bounces = 0
	_serving = false
	_rally_hits += 1
	_ai_kick = 0.2
	Sound.play_at("pp_paddle", to_global(pos), -1.0, 0.06)
	return v


# ================================================================ effets, annonces, score

func _bounce_fx(at: Vector3) -> void:
	var ring := BowlingArt.cylinder(0.02, 0.02, 0.002, BowlingArt.unshaded(Color(1, 1, 1, 0.8)), Vector3(at.x, TABLE_Y + 0.004, at.z), 20)
	var m := ring.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fx_root.add_child(ring)
	var tw_ := create_tween()
	tw_.set_parallel(true)
	tw_.tween_property(ring, "scale", Vector3(4.0, 1.0, 4.0), 0.4)
	tw_.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw_.chain().tween_callback(ring.queue_free)


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
	var mode := "ENTRAÎNEMENT" if is_training() else "MATCH · " + String(LEVELS[settings["level"]]["title"]).to_upper()
	if is_training():
		_scoreboard.set_data("PING-PONG · " + mode, ["SÉRIE", "RECORD"], [_streak, maxi(_stat("best_streak"), _best_streak_session)], 0, "Renvois réussis : %d" % _returns)
	else:
		var foot := "Premier à %d" % int(settings["points"])
		_scoreboard.set_data("PING-PONG · " + mode, ["VOUS", "ORDI"], scores, server, foot)


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
	if state == State.SERVE_WAIT and (button == "trigger_click" or button == "grip_click"):
		_toss()


func on_button_released(_hand_released: Hand, _button: String) -> void:
	pass


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["match", "training"]:
		settings["mode"] = "match"
	if settings["points"] not in [7, 11]:
		settings["points"] = 11


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

## Joueur virtuel : se place sous la balle qui arrive et frappe vers l'avant.
func _st_bot_step(delta: float) -> void:
	var idle := Vector3(0.0, TABLE_Y + 0.35, Z_NEAR + 0.35)
	var target := idle
	var vel := Vector3.ZERO
	# Service : le joueur virtuel frappe la balle lancée quand elle redescend
	if ball_live and _last_hitter == 0 and ball_vel.y < 0.0 and ball_pos.y < 1.12 and state == State.RALLY:
		var tgt := Vector3(randf_range(-tw / 3.0, tw / 3.0), TABLE_Y + BALL_R, z_net - tl * 0.25)
		ball_vel = _solve_shot(ball_pos, tgt, 3.4, true)
		_after_player_hit(ball_pos, ball_vel)
		return
	if ball_live and ball_vel.z > 0.0 and ball_pos.z > z_net and _last_hitter != PLAYER and randf() > 0.0:
		var s := {"pos": ball_pos, "vel": ball_vel}
		for i in 300:
			_advance(s, 1.0 / 90.0)
			var p: Vector3 = s["pos"]
			if p.z >= Z_NEAR + 0.2:
				target = Vector3(p.x, maxf(p.y, TABLE_Y + 0.12), p.z + 0.02)
				break
		vel = Vector3(0, 1.2, -3.5)
	_pad.normal = Vector3(0, 0.3, -1).normalized()
	_pad.pos = _pad.pos.move_toward(target, 9.0 * delta)
	_pad.vel = vel
	_pad.radius = PingPaddle.RADIUS + 0.025


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


func _wait_state(target: State, max_frames: int) -> bool:
	var i := 0
	while state != target and i < max_frames:
		await get_tree().physics_frame
		i += 1
	return state == target


func _selftest_run() -> void:
	# A. Le tir calculé retombe bien sur la moitié visée et passe le filet
	var bad := 0
	for i in 60:
		var from := Vector3(randf_range(-0.3, 0.3), TABLE_Y + 0.3, z_far - 0.1)
		var tgt := Vector3(randf_range(-tw / 2.0 + 0.2, tw / 2.0 - 0.2), TABLE_Y + BALL_R, randf_range(z_net + tl * 0.25, Z_NEAR - 0.15))
		var v := _solve_shot(from, tgt, randf_range(2.8, 5.0), true)
		var r := _simulate(from, v)
		var bounces: Array = r["bounces"]
		if r["net"] or bounces.is_empty() or int(bounces[0]["side"]) != PLAYER:
			bad += 1
	_st_check("tirs calculés", bad == 0, "(%d ratés sur 60)" % bad)

	# B. Règles : deux rebonds du même côté sans frappe = point pour celui qui a frappé
	settings["mode"] = "match"
	settings["level"] = "facile"
	settings["points"] = 7
	start_match()
	state = State.RALLY
	ball_live = true
	_rally_over = false
	_last_hitter = PLAYER
	_serving = false
	_opp_bounces = 0
	_on_table_bounce(AI)
	_on_table_bounce(AI)
	_st_check("2 rebonds = point", scores[0] == 1 and scores[1] == 0, str(scores))
	await _wait_state(State.SERVE_WAIT, 600)
	state = State.RALLY
	ball_live = true
	_rally_over = false
	_last_hitter = AI
	_serving = false
	_opp_bounces = 0
	_on_table_bounce(AI)
	_st_check("rebond dans son camp", scores[0] == 2, str(scores))
	await _wait_frames(200)

	# C. Match complet : l'ordinateur contre le joueur virtuel, premier à 3
	settings["points"] = 7
	_st_bot = true
	start_match()
	var rallies := 0
	var guard := 0
	var served := false
	while state != State.GAME_OVER and guard < 90 * 400:
		if state == State.SERVE_WAIT:
			await _wait_frames(20)
			_toss()
			served = true
		await get_tree().physics_frame
		guard += 1
	_st_check("match terminé", state == State.GAME_OVER, "%s en %.0f s (service joueur %s)" % [str(scores), guard / 90.0, served])
	_st_check("score final valide", maxi(scores[0], scores[1]) >= 7 and absi(scores[0] - scores[1]) >= 2, str(scores))

	# C2. Les autres niveaux se terminent aussi
	for lv in ["normal", "expert"]:
		settings["level"] = lv
		start_match()
		guard = 0
		while state != State.GAME_OVER and guard < 90 * 500:
			if state == State.SERVE_WAIT:
				await _wait_frames(20)
				_toss()
			await get_tree().physics_frame
			guard += 1
		_st_check("match %s terminé" % lv, state == State.GAME_OVER, "%s en %.0f s" % [str(scores), guard / 90.0])

	# C3. Table compacte : la géométrie suit et les tirs calculés restent valides
	settings["table"] = "compact"
	_apply_layout()
	await _wait_frames(2)
	var bad2 := 0
	for i in 30:
		var from2 := Vector3(randf_range(-0.2, 0.2), TABLE_Y + 0.3, z_far - 0.1)
		var tgt2 := Vector3(randf_range(-tw / 2.0 + 0.2, tw / 2.0 - 0.2), TABLE_Y + BALL_R, randf_range(z_net + tl * 0.25, Z_NEAR - 0.15))
		var r2 := _simulate(from2, _solve_shot(from2, tgt2, 3.5, true))
		var b2: Array = r2["bounces"]
		if r2["net"] or b2.is_empty() or int(b2[0]["side"]) != PLAYER:
			bad2 += 1
	_st_check("table compacte", absf(tl - 2.055) < 0.01 and bad2 == 0, "(L=%.2f, %d ratés)" % [tl, bad2])
	settings["table"] = "normal"
	_apply_layout()

	# D. Entraînement : la machine envoie, le joueur virtuel renvoie
	settings["mode"] = "training"
	settings["level"] = "facile"
	start_match()
	guard = 0
	while _returns < 2 and guard < 90 * 90:
		await get_tree().physics_frame
		guard += 1
	_st_check("entraînement : renvois", _returns >= 2, "%d renvois en %.0f s" % [_returns, guard / 90.0])
	_st_bot = false

	for line in _st_log:
		print("SELFTEST pingpong ", line)
	print("SELFTEST pingpong=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
