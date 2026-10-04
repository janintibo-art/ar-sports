class_name PetanqueGame
extends Node3D
## Pétanque en réalité augmentée : un terrain de gravier devant le joueur, un cochonnet,
## trois boules d'acier par équipe. On attrape une boule sur le support, on la lance en
## la relâchant. Règles classiques : l'équipe la plus loin du cochonnet rejoue, on marque
## un point par boule plus proche que la meilleure boule adverse.
## Physique maison (gravité, rebond amorti, roulement, chocs) : stable et prévisible.
## Le noeud est placé aux pieds du joueur ; le terrain s'étend vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const R_B := 0.0375
const R_J := 0.015
const M_B := 0.7
const M_J := 0.01
const SUBSTEPS := 2
const Z_BACK := 0.6
const SAVE_PATH := "user://petanque.cfg"
const PLAYER := 1
const AI := -1
const STAND := Vector3(0.38, 0.99, -0.2)
const GRAB_RADIUS := 0.38
const BOULES_PER_TEAM := 3
const THROW_GAIN_H := 2.1     # un geste doux porte loin : la vitesse de la main est amplifiée
const THROW_GAIN_V := 1.45
const CLR_PLAYER := Color(0.55, 0.68, 0.95)
const CLR_AI := Color(0.95, 0.5, 0.25)

const LEVELS := {
	"facile": {"title": "Facile", "assist": 1.0, "point_s": 0.55, "p_shoot": 0.08, "shoot_s": 0.30},
	"normal": {"title": "Normal", "assist": 0.7, "point_s": 0.28, "p_shoot": 0.30, "shoot_s": 0.14},
	"expert": {"title": "Expert", "assist": 0.3, "point_s": 0.14, "p_shoot": 0.55, "shoot_s": 0.06},
}

enum State { SETUP, JACK_WAIT, TURN_WAIT, AI_WAIT, FLIGHT, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "level": "normal", "points": 7, "terrain": "normal", "music": true}
var state := State.SETUP
var scores := [0, 0]          # [équipe 1 (vous), équipe 2 (adversaire)]
var left := [3, 3]            # boules restantes
var starter := PLAYER
var to_play := PLAYER
var _last_thrower := PLAYER
var _phase := "jack"          # "jack" : on lance le cochonnet ; "play" : on joue les boules
var _jack_fails := 0
var _balls: Array[PetBall] = []
var _jack: PetBall = null

# Terrain
var tw := 3.0
var tlen := 12.0
var jack_min := 6.0
var jack_max := 10.0

# Boule tenue en main
var _held: PetBall = null
var _held_hand: Hand = null
var _held_button := ""
var _timer := 0.0
var _fly_time := 0.0
var _think := 1.2
var _pause_next := ""
var _lead_ball: PetBall = null
var _train_end := 0
var _train_total := 0
var _train_best_session := 0

var _hands: Array = []
var _terrain: Node3D
var _balls_root: Node3D
var _fx_root: Node3D
var _stand: Node3D
var _lead_ring: MeshInstance3D
var _lead_label: Label3D
var _jack_ring: MeshInstance3D
var _marcel: Spectator
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
var _clacks := 0


# ================================================================ mise en place

func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_load_save()
	_terrain = Node3D.new()
	add_child(_terrain)
	_balls_root = Node3D.new()
	add_child(_balls_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_stand()

	_lead_ring = BowlingArt.cylinder(0.065, 0.065, 0.002, BowlingArt.unshaded(Color(1, 1, 1, 0.7)), Vector3.ZERO, 28)
	(_lead_ring.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lead_ring.visible = false
	add_child(_lead_ring)
	_jack_ring = BowlingArt.cylinder(0.085, 0.085, 0.002, BowlingArt.unshaded(Color(1, 0.9, 0.3, 0.55)), Vector3.ZERO, 28)
	(_jack_ring.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_jack_ring.visible = false
	add_child(_jack_ring)
	_lead_label = BowlingArt.label("", 0.06, Color(1, 1, 1), 10)
	_lead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lead_label.no_depth_test = true
	_lead_label.visible = false
	add_child(_lead_label)

	_scoreboard = PingScoreboard.new()
	add_child(_scoreboard)
	_marcel = Spectator.new({
		"name": "Marcel", "skin": Color(0.9, 0.72, 0.6), "shirt": Color(0.25, 0.5, 0.35),
		"pants": Color(0.75, 0.7, 0.55), "hair": Color(0.8, 0.8, 0.8), "beard": false,
		"hat": true, "hat_color": Color(0.1, 0.1, 0.12),
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
	_panel.accent = Color(1.0, 0.75, 0.2)
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


## Dimensions du terrain (normal ou court) et position des éléments.
func _apply_layout() -> void:
	if settings["terrain"] == "normal":
		tw = 3.0
		tlen = 12.0
		jack_min = 6.0
		jack_max = 10.0
	else:
		tw = 2.6
		tlen = 9.0
		jack_min = 4.0
		jack_max = 7.0
	_build_terrain()
	_scoreboard.position = Vector3(1.9, 1.45, -3.2)
	_scoreboard.scale = Vector3.ONE * 1.15
	var face := Vector3(0, 0, 1.5) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_marcel.position = Vector3(-1.0, 0, 0.1)
	_marcel.rotation.y = deg_to_rad(25.0)
	_message.position = Vector3(0, 1.8, -2.5)
	_hint.position = STAND + Vector3(0, 0.28, 0)


func _build_terrain() -> void:
	for c in _terrain.get_children():
		c.queue_free()
	var zc := (Z_BACK - tlen) / 2.0
	var len := tlen + Z_BACK
	var gm := BowlingArt.surface_material("gravel", Color(0.68, 0.60, 0.46), Vector2(tw * 2.5, len * 2.5))
	_terrain.add_child(BowlingArt.floor_quad(tw, len, gm, Vector3(0, 0.001, zc)))
	# Zone où le cochonnet doit s'arrêter (légèrement plus claire)
	var band_mat := BowlingArt.unshaded(Color(1, 1, 1, 0.10))
	band_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_terrain.add_child(BowlingArt.floor_quad(tw - 0.1, jack_max - jack_min, band_mat, Vector3(0, 0.003, -(jack_min + jack_max) / 2.0)))
	# Planches de bordure
	var wood := BowlingArt.mat(Color(0.42, 0.27, 0.14), 0.7)
	for sx in [-1.0, 1.0]:
		_terrain.add_child(BowlingArt.box(Vector3(0.05, 0.09, len + 0.05), wood, Vector3(sx * (tw / 2.0 + 0.025), 0.045, zc)))
	_terrain.add_child(BowlingArt.box(Vector3(tw + 0.1, 0.09, 0.05), wood, Vector3(0, 0.045, -tlen - 0.025)))
	_terrain.add_child(BowlingArt.box(Vector3(tw + 0.1, 0.09, 0.05), wood, Vector3(0, 0.045, Z_BACK + 0.025)))
	# Cercle de lancer
	_terrain.add_child(BowlingArt.cylinder(0.27, 0.27, 0.003, BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, 0.004, 0), 40))
	_terrain.add_child(BowlingArt.cylinder(0.24, 0.24, 0.004, gm, Vector3(0, 0.0045, 0), 40))
	_build_decor()
	# Repères de distance posés au sol
	for d in [jack_min, jack_max]:
		for sx in [-1.0, 1.0]:
			var tick := BowlingArt.box(Vector3(0.2, 0.004, 0.04), BowlingArt.unshaded(Color(1, 1, 1)), Vector3(sx * (tw / 2.0 - 0.12), 0.005, -d))
			_terrain.add_child(tick)
		var lab := BowlingArt.label("%d m" % int(d), 0.16, Color(1, 1, 1), 6)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(-(tw / 2.0 - 0.45), 0.006, -d)
		_terrain.add_child(lab)


func _build_stand() -> void:
	_stand = Node3D.new()
	add_child(_stand)
	var metal := BowlingArt.mat(Color(0.25, 0.27, 0.32), 0.35, 0.8)
	var x := STAND.x
	var z := STAND.z
	_stand.add_child(BowlingArt.cylinder(0.18, 0.2, 0.025, metal, Vector3(x, 0.0125, z), 24))
	_stand.add_child(BowlingArt.cylinder(0.022, 0.03, STAND.y - 0.03, metal, Vector3(x, (STAND.y - 0.03) / 2.0, z), 16))
	_stand.add_child(BowlingArt.cylinder(0.065, 0.03, 0.035, BowlingArt.mat(Color(0.7, 0.55, 0.2), 0.3, 0.7), Vector3(x, STAND.y - 0.015, z), 20))


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

func _is_two() -> bool:
	return settings["mode"] == "deux"


func is_training() -> bool:
	return settings["mode"] == "training"


func _team_name(team: int) -> String:
	if team == PLAYER:
		return "Joueur 1" if _is_two() else "Vous"
	return "Joueur 2" if _is_two() else "Marcel"


func show_setup() -> void:
	state = State.SETUP
	_clear_balls()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Pétanque", "Victoires : %d   ·   meilleur entraînement : %d pts" % [_stat("wins"), _stat("best_training")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.26, "selected": settings["mode"] == "ordi"},
		{"id": "mode_deux", "text": "2 joueurs", "width": 0.22, "selected": settings["mode"] == "deux"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Points", [
		{"id": "points_7", "text": "7", "width": 0.14, "selected": settings["points"] == 7},
		{"id": "points_13", "text": "13", "width": 0.14, "selected": settings["points"] == 13},
	])
	_panel.add_row("Terrain", [
		{"id": "terrain_normal", "text": "Normal", "width": 0.22, "selected": settings["terrain"] == "normal"},
		{"id": "terrain_court", "text": "Court", "width": 0.22, "selected": settings["terrain"] == "court"},
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
	_drop_held()
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)


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
	elif id.begins_with("terrain_"):
		settings["terrain"] = id.substr(8)
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


# ================================================================ boules

func _clear_balls() -> void:
	_drop_held()
	for b in _balls:
		_free_ball(b)
	_balls.clear()
	_jack = null
	_lead_ball = null
	_lead_ring.visible = false
	_lead_label.visible = false
	_jack_ring.visible = false


func _free_ball(b: PetBall) -> void:
	if b.node and is_instance_valid(b.node):
		b.node.queue_free()
	if b.shadow and is_instance_valid(b.shadow):
		b.shadow.queue_free()


func _new_ball(team: int) -> PetBall:
	var b := PetBall.new()
	b.team = team
	if team == 0:
		b.r = R_J
		b.mass = M_J
		b.node = BowlingArt.sphere(R_J, BowlingArt.mat(Color(1.0, 0.82, 0.15), 0.25, 0.1), Vector3.ZERO, 10)
	else:
		b.r = R_B
		b.mass = M_B
		var col := CLR_PLAYER if team == PLAYER else CLR_AI
		var m := BowlingArt.mat(col, 0.22, 0.85)
		b.node = BowlingArt.sphere(R_B, m, Vector3.ZERO, 16)
		# Stries gravées : deux petits anneaux sombres
		for sy in [-0.45, 0.45]:
			var ring := BowlingArt.cylinder(R_B * sqrt(1.0 - sy * sy) * 1.005, R_B * sqrt(1.0 - sy * sy) * 1.005, 0.003, BowlingArt.mat(col.darkened(0.5), 0.4, 0.6), Vector3(0, R_B * sy, 0), 16)
			b.node.add_child(ring)
	_balls_root.add_child(b.node)
	b.shadow = BowlingArt.make_blob(b.r * 4.0)
	_balls_root.add_child(b.shadow)
	_balls.append(b)
	return b


func _alive_boules(team: int) -> Array[PetBall]:
	var out: Array[PetBall] = []
	for b in _balls:
		if b.team == team and not b.dead:
			out.append(b)
	return out


## Distance entre le cochonnet et la boule (bord à bord), en mètres.
func _dist_to_jack(b: PetBall) -> float:
	if _jack == null:
		return INF
	return maxf(0.0, Vector2(b.pos.x - _jack.pos.x, b.pos.z - _jack.pos.z).length() - b.r - _jack.r)


func _best_ball(team: int) -> PetBall:
	var best: PetBall = null
	var bd := INF
	for b in _alive_boules(team):
		var d := _dist_to_jack(b)
		if d < bd:
			bd = d
			best = b
	return best


func _best(team: int) -> float:
	var b := _best_ball(team)
	return INF if b == null else _dist_to_jack(b)


## Quelle équipe doit jouer ? 0 si la manche est finie. La plus éloignée rejoue ;
## à égalité, c'est l'équipe qui n'a pas joué en dernier.
func _team_to_play() -> int:
	if is_training():
		return PLAYER if left[0] > 0 else 0
	if left[0] == 0 and left[1] == 0:
		return 0
	if left[0] == 0:
		return AI
	if left[1] == 0:
		return PLAYER
	var d1 := _best(PLAYER)
	var d2 := _best(AI)
	if is_equal_approx(d1, d2):
		return -_last_thrower
	return PLAYER if d1 > d2 else AI


## Points de la manche : (équipe gagnante, points). Pure fonction de distances (pour le test).
static func end_points(d_player: Array, d_ai: Array) -> Array:
	var bp := INF
	var ba := INF
	for d in d_player:
		bp = minf(bp, float(d))
	for d in d_ai:
		ba = minf(ba, float(d))
	if is_inf(bp) and is_inf(ba):
		return [0, 0]
	if is_equal_approx(bp, ba):
		return [0, 0]
	var winner := PLAYER if bp < ba else AI
	var mine: Array = d_player if winner == PLAYER else d_ai
	var other_best := ba if winner == PLAYER else bp
	var pts := 0
	for d in mine:
		if float(d) < other_best:
			pts += 1
	return [winner, pts]


func _distances(team: int) -> Array:
	var out: Array = []
	for b in _alive_boules(team):
		out.append(_dist_to_jack(b))
	return out


# ================================================================ partie

func start_match() -> void:
	_apply_layout()
	scores = [0, 0]
	starter = PLAYER
	_train_end = 0
	_train_total = 0
	_train_best_session = 0
	_start_end()


func _start_end() -> void:
	_clear_balls()
	left = [BOULES_PER_TEAM, BOULES_PER_TEAM]
	_phase = "jack"
	_jack_fails = 0
	_last_thrower = starter
	to_play = starter
	_update_scoreboard()
	_begin_jack_turn()


func _begin_jack_turn() -> void:
	if is_training() or not _is_human(starter):
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""
		_announce("Cochonnet !" if starter == PLAYER else "%s lance le cochonnet" % _team_name(starter), Color(1, 0.8, 0.2), 1.6)
	else:
		state = State.JACK_WAIT
		_spawn_held(0)
		_hint.text = "Attrape le cochonnet (gâchette)\net lance-le entre les repères"
		_announce("%s : le cochonnet !" % _team_name(starter), Color(1, 0.8, 0.2), 1.8)


func _begin_turn() -> void:
	_update_scoreboard()
	if _is_human(to_play):
		state = State.TURN_WAIT
		_spawn_held(to_play)
		_hint.text = "Attrape la boule (gâchette ou grip)\net lance-la en la relâchant"
	else:
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""


func _is_human(team: int) -> bool:
	if _st_bot:
		return false
	if team == PLAYER:
		return true
	return _is_two()


func _spawn_held(kind_team: int) -> void:
	_drop_held()
	_held = _new_ball(kind_team)
	_held.moving = false
	_held.pos = Vector3(STAND.x, STAND.y + _held.r, STAND.z)
	_held.node.position = _held.pos
	_held.shadow.visible = false
	_hint.visible = true


## Retire la boule en main (panneau ouvert, partie quittée) sans la compter.
func _drop_held() -> void:
	if _held != null:
		_balls.erase(_held)
		_free_ball(_held)
		_held = null
		_held_hand = null
		_held_button = ""
	_hint.text = ""


func _launch(team: int, from: Vector3, vel: Vector3, as_jack: bool) -> PetBall:
	var b: PetBall
	if _held != null and not _st_bot and not _held.moving:
		b = _held
		_held = null
		_held_hand = null
		_held_button = ""
	else:
		b = _new_ball(0 if as_jack else team)
	b.pos = from
	b.vel = vel
	b.moving = true
	b.shadow.visible = true
	if as_jack:
		_jack = b
	else:
		left[0 if team == PLAYER else 1] -= 1
	_last_thrower = team
	_hint.text = ""
	state = State.FLIGHT
	_fly_time = 0.0
	Sound.play_at("whoosh", to_global(from), -10.0, 0.1)
	_update_scoreboard()
	return b


# ---------------------------------------------------------------- lancer humain

func _hand_item_pos(h: Hand) -> Vector3:
	var gt := global_transform.affine_inverse() * h.global_transform
	return gt * Vector3(0, -0.02, -0.05)


func _try_grab(hand: Hand, button: String) -> void:
	if _held == null or _held.moving or _held_hand != null:
		return
	if _hand_item_pos(hand).distance_to(_held.pos) > GRAB_RADIUS:
		return
	_held_hand = hand
	_held_button = button
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	Sound.play_at("grab", to_global(_held.pos), -6.0, 0.05)
	_hint.text = ""


func _release_held(hand: Hand) -> void:
	if _held == null or _held_hand != hand:
		return
	var from := _hand_item_pos(hand)
	var v := global_basis.inverse() * hand.throw_velocity()
	_held_hand = null
	_held_button = ""
	_throw(from, v)


## Lance l'objet en main depuis `from` avec la vitesse `vel` (repère du jeu).
func _throw(from: Vector3, vel: Vector3) -> void:
	var as_jack := _held.team == 0
	var hv := Vector2(vel.x, vel.z).length()
	if hv < 0.9 and vel.y < 1.0:
		# Simplement lâchée : elle retourne sur le support
		_held.pos = Vector3(STAND.x, STAND.y + _held.r, STAND.z)
		_held.node.position = _held.pos
		_hint.text = "Lance plus fort !"
		return
	vel = Vector3(vel.x * THROW_GAIN_H, vel.y * THROW_GAIN_V, vel.z * THROW_GAIN_H)
	vel = vel.limit_length(18.0)
	vel = _assist(from, vel, as_jack)
	var team := to_play
	_launch(team, from, vel, as_jack)


func _flight_time(p: Vector3, v: Vector3, r: float) -> float:
	var disc := v.y * v.y + 2.0 * PetBall.G * (p.y - r)
	if disc < 0.0:
		return 0.0
	return (v.y + sqrt(disc)) / PetBall.G


## Aide au lancer : un tir qui retomberait hors du terrain est ramené à l'intérieur.
## Un tir correct n'est jamais modifié.
func _assist(p: Vector3, v: Vector3, as_jack: bool) -> Vector3:
	var a: float = LEVELS[settings["level"]]["assist"]
	var r := R_J if as_jack else R_B
	if as_jack:
		# Le cochonnet doit s'arrêter entre les repères : on simule où il finirait
		var rest := _sim_rest(p, v, R_J, M_J)
		var d := -rest.z
		var xm_j := tw / 2.0 - 0.4
		if d >= jack_min + 0.2 and d <= jack_max - 0.2 and absf(rest.x) <= xm_j:
			return v
		if a < 0.5:
			return v
		var goal := Vector3(clampf(rest.x, -xm_j, xm_j), R_J, -clampf(d, jack_min + 0.5, jack_max - 0.5))
		return _solve_point(p, goal, R_J, M_J)
	var t := _flight_time(p, v, r)
	if t < 0.08:
		return v
	var land := Vector2(p.x + v.x * t, p.z + v.z * t)
	var xm := tw / 2.0 - 0.15
	var zmin: float = -(tlen - 0.4)
	var zmax: float = -1.0
	var clamped := Vector2(clampf(land.x, -xm, xm), clampf(land.y, zmin, zmax))
	var out := v
	if not clamped.is_equal_approx(land):
		var target := land.lerp(clamped, a)
		out = Vector3((target.x - p.x) / t, v.y, (target.y - p.z) / t)
	# La boule roule encore après l'atterrissage : si elle finirait hors du terrain, on la retient
	if a >= 0.5:
		var rest := _sim_rest(p, out, R_B, M_B)
		var rx := tw / 2.0 - 0.2
		if absf(rest.x) > rx or rest.z < -tlen + 0.3 or rest.z > -0.6:
			var goal := Vector3(clampf(rest.x, -rx, rx), R_B, clampf(rest.z, -tlen + 0.5, -1.0))
			out = _solve_point(p, goal, R_B, M_B)
	return out


# ================================================================ physique

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
		State.JACK_WAIT, State.TURN_WAIT:
			_update_held()
		State.AI_WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_ai_act()
		State.FLIGHT:
			_fly_time += delta
			var h := delta / SUBSTEPS
			for i in SUBSTEPS:
				_step(h)
			if _all_rest() or _fly_time > 14.0:
				for b in _balls:
					b.moving = false
					b.vel = Vector3.ZERO
				_after_settle()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()
	_update_visuals(delta)


func _update_held() -> void:
	if _held == null:
		return
	if _held_hand != null and is_instance_valid(_held_hand):
		_held.pos = _hand_item_pos(_held_hand)
		_held.node.position = _held.pos
	elif _held_hand == null:
		_held.node.position = _held.pos
		var wob := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008)
		_held.node.scale = Vector3.ONE * wob


func _all_rest() -> bool:
	for b in _balls:
		if b.moving:
			return false
	return true


func _step(dt: float) -> void:
	for b in _balls:
		if b == _held:
			continue
		if b.moving:
			b.move(dt)
			if b.land_speed > 0.0:
				if b.land_speed > 1.5:
					Sound.play_at("pet_land", to_global(b.pos), -4.0 + minf(b.land_speed, 8.0) * 0.4, 0.1)
				b.land_speed = 0.0
	# Chocs
	var n := _balls.size()
	for i in n:
		var a := _balls[i]
		if a == _held or a.dead:
			continue
		for j in range(i + 1, n):
			var c := _balls[j]
			if c == _held or c.dead:
				continue
			if not (a.moving or c.moving):
				continue
			var hit := PetBall.collide(a, c)
			if hit > 0.0:
				_clacks += 1
				Sound.play_at("pet_clack", to_global((a.pos + c.pos) / 2.0), -8.0 + minf(hit, 8.0) * 0.9, 0.05)
				if hit > 3.0:
					for h in _hands:
						if is_instance_valid(h):
							h.buzz(0.2, 0.04)
	# Sorties de terrain (seulement une fois posée au sol)
	for b in _balls:
		if b == _held or b.dead or not b.touched:
			continue
		if absf(b.pos.x) > tw / 2.0 or b.pos.z < -tlen or b.pos.z > Z_BACK:
			b.dead = true


func _update_visuals(delta: float) -> void:
	for b in _balls:
		if b == _held and _held_hand == null:
			continue
		b.node.position = b.pos
		if b.moving and b.pos.y <= b.r + 0.01:
			var axis := Vector3(b.vel.z, 0, -b.vel.x)
			if axis.length() > 0.01:
				b.node.rotate(axis.normalized(), Vector2(b.vel.x, b.vel.z).length() * delta / b.r)
		if b.shadow:
			var h := maxf(0.0, b.pos.y - b.r)
			b.shadow.position = Vector3(b.pos.x, 0.003, b.pos.z)
			b.shadow.scale = Vector3.ONE * clampf(1.0 - h * 0.25, 0.4, 1.0)
		if b.dead and not b.moving and b.node.visible:
			b.node.visible = false
			if b.shadow:
				b.shadow.visible = false
	_update_markers()


func _update_markers() -> void:
	# Anneau autour du cochonnet et marque de la boule qui « tient le point »
	if _jack != null and not _jack.dead and _phase == "play":
		_jack_ring.visible = true
		_jack_ring.position = Vector3(_jack.pos.x, 0.005, _jack.pos.z)
	else:
		_jack_ring.visible = false
	if _lead_ball != null and not _lead_ball.dead and _phase == "play" and state != State.FLIGHT:
		_lead_ring.visible = true
		_lead_ring.position = Vector3(_lead_ball.pos.x, 0.006, _lead_ball.pos.z)
		(_lead_ring.material_override as StandardMaterial3D).albedo_color = (CLR_PLAYER if _lead_ball.team == PLAYER else CLR_AI) * Color(1, 1, 1, 0.8)
		_lead_label.visible = true
		_lead_label.position = _lead_ball.pos + Vector3(0, 0.16, 0)
	else:
		_lead_ring.visible = false
		_lead_label.visible = false


# ================================================================ déroulement

func _after_settle() -> void:
	if _phase == "jack":
		_after_jack()
		return
	if _jack == null or _jack.dead:
		_void_end("Cochonnet sorti ! On recommence")
		return
	_remove_dead_from_play()
	_lead_ball = null
	var bt := _best_ball(PLAYER)
	var ba := _best_ball(AI)
	if bt != null or ba != null:
		var dp := _best(PLAYER)
		var da := _best(AI)
		_lead_ball = bt if dp < da else ba
		var lead_team: int = _lead_ball.team
		_lead_label.text = "%d cm" % int(round(_dist_to_jack(_lead_ball) * 100.0))
		_lead_label.modulate = CLR_PLAYER if lead_team == PLAYER else CLR_AI
	_react_after_throw()
	var nxt := _team_to_play()
	if nxt == 0:
		_finish_end()
		return
	to_play = nxt
	_begin_turn()


func _remove_dead_from_play() -> void:
	var keep: Array[PetBall] = []
	for b in _balls:
		if b.dead and b.team != 0:
			_free_ball(b)
		else:
			keep.append(b)
	_balls = keep


func _react_after_throw() -> void:
	var team := _last_thrower
	if is_training() or _lead_ball == null:
		return
	var lead: int = _lead_ball.team
	var d_cm := int(round(_dist_to_jack(_lead_ball) * 100.0))
	var who := _team_name(lead)
	_announce("%s tient le point · %d cm" % [who, d_cm], CLR_PLAYER if lead == PLAYER else CLR_AI, 2.2)
	if lead == PLAYER and team == PLAYER and d_cm < 15 and not _is_two():
		_marcel.react("pointe")
	elif lead == AI and team == PLAYER and not _is_two():
		_marcel.say("good")


func _after_jack() -> void:
	var ok := _jack != null and not _jack.dead
	var d := 0.0
	if ok:
		d = -_jack.pos.z
		ok = d >= jack_min and d <= jack_max and absf(_jack.pos.x) < tw / 2.0 - 0.2
	if not ok:
		_jack_fails += 1
		if _jack != null:
			_balls.erase(_jack)
			_free_ball(_jack)
			_jack = null
		if _is_human(starter) and not is_training() and _jack_fails < 2:
			_announce("Cochonnet non valable !", Color(1, 0.4, 0.3), 1.8)
			_begin_jack_turn_retry()
			return
		# Trop d'échecs : on le pose nous-mêmes à bonne distance
		_jack = _new_ball(0)
		_jack.pos = Vector3(randf_range(-0.4, 0.4), R_J, -(jack_min + jack_max) / 2.0)
		_jack.moving = false
		_jack.touched = true
		_announce("Cochonnet posé par l'arbitre", Color(1, 0.8, 0.2), 1.6)
	_phase = "play"
	_last_thrower = -starter
	to_play = starter
	_lead_ball = null
	_begin_turn()


func _begin_jack_turn_retry() -> void:
	state = State.JACK_WAIT
	_spawn_held(0)
	_hint.text = "Attrape le cochonnet (gâchette)\net lance-le entre les repères"


func _void_end(msg: String) -> void:
	_announce(msg, Color(1, 0.5, 0.3), 2.4)
	_pause_next = "restart_end"
	state = State.PAUSE
	_timer = 2.4 if not _selftest else 0.3


func _finish_end() -> void:
	var win_team := 0
	var pts := 0
	if is_training():
		var total := 0
		for d in _distances(PLAYER):
			var dd: float = d
			if dd < 0.15:
				total += 3
			elif dd < 0.40:
				total += 2
			elif dd < 1.0:
				total += 1
		_train_end += 1
		_train_total += total
		_train_best_session = maxi(_train_best_session, total)
		_best_stat("best_training", total)
		_announce("Manche : %d pts" % total, Color(1, 0.8, 0.2), 2.6)
		_scoreboard.celebrate("point")
		_pause_next = "next_end"
		state = State.PAUSE
		_timer = 3.0 if not _selftest else 0.3
		_update_scoreboard()
		return
	var res := end_points(_distances(PLAYER), _distances(AI))
	win_team = res[0]
	pts = res[1]
	if win_team == 0:
		_announce("Égalité, personne ne marque", Color(1, 0.8, 0.2), 2.6)
		starter = -starter
	else:
		scores[0 if win_team == PLAYER else 1] += pts
		var who := _team_name(win_team)
		_announce("%s : %d point%s !" % [who, pts, "s" if pts > 1 else ""], CLR_PLAYER if win_team == PLAYER else CLR_AI, 2.8)
		_scoreboard.celebrate("point")
		starter = win_team
		if not _is_two():
			if win_team == PLAYER:
				_marcel.react("oups")
			else:
				_marcel.react("carreau" if pts >= 3 else "pointe")
	_update_scoreboard()
	_pause_next = "next_end"
	state = State.PAUSE
	_timer = 3.2 if not _selftest else 0.3


func _after_pause() -> void:
	match _pause_next:
		"restart_end":
			_start_end()
		"next_end":
			if not is_training() and (scores[0] >= settings["points"] or scores[1] >= settings["points"]):
				_game_over()
			else:
				_start_end()


func _game_over() -> void:
	state = State.GAME_OVER
	var you_win: bool = scores[0] > scores[1]
	var winner := PLAYER if you_win else AI
	var summary := "%s gagne %d – %d" % [_team_name(winner), maxi(scores[0], scores[1]), mini(scores[0], scores[1])]
	if not _is_two():
		if you_win:
			_bump_stat("wins")
			_scoreboard.celebrate("win")
			_marcel.say("win", true)
		else:
			_scoreboard.celebrate("lose")
	else:
		_scoreboard.celebrate("win")
	if _selftest:
		return
	await get_tree().create_timer(1.2).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


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
	var lvl := String(LEVELS[settings["level"]]["title"]).to_upper()
	if is_training():
		_scoreboard.set_data("PÉTANQUE · ENTRAÎNEMENT", ["TOTAL", "RECORD"], [_train_total, maxi(_stat("best_training"), _train_best_session)], 0, "Manche %d · boules restantes : %d" % [_train_end + 1, left[0]])
		return
	var mode := "2 JOUEURS" if _is_two() else lvl
	var names := ["VOUS", "MARCEL"] if not _is_two() else ["J1", "J2"]
	var foot := "Boules : %d – %d   ·   premier à %d" % [left[0], left[1], int(settings["points"])]
	var srv := to_play if state != State.SETUP else 0
	_scoreboard.set_data("PÉTANQUE · " + mode, names, scores, srv, foot)


# ================================================================ adversaire

func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _ai_origin() -> Vector3:
	return Vector3(-0.8, 1.05, -0.15)


## Vitesse initiale d'une cloche qui retombe en `land` (au sol) au bout de `t` secondes.
func _lob(p: Vector3, land: Vector2, t: float, r: float) -> Vector3:
	var vy := (r - p.y + 0.5 * PetBall.G * t * t) / t
	return Vector3((land.x - p.x) / t, vy, (land.y - p.z) / t)


## Où s'arrête une boule lancée de `p` avec la vitesse `v` (sans obstacle).
func _sim_rest(p: Vector3, v: Vector3, r: float, mass: float) -> Vector3:
	var b := PetBall.new()
	b.r = r
	b.mass = mass
	b.pos = p
	b.vel = v
	for i in 1500:
		b.move(1.0 / 180.0)
		if not b.moving:
			break
	return b.pos


## Cloche qui s'arrête (après roulement) au point `rest`.
func _solve_point(p: Vector3, rest: Vector3, r: float, mass: float) -> Vector3:
	var dir := Vector2(rest.x - p.x, rest.z - p.z)
	var dist := dir.length()
	if dist < 0.5:
		return Vector3(0, 3.0, 0)
	dir /= dist
	var lo := 0.4
	var hi := dist
	var best := hi
	for i in 18:
		var s := (lo + hi) / 2.0
		var land := Vector2(p.x, p.z) + dir * s
		var v := _lob(p, land, 0.5 + 0.075 * s, r)
		var rp := _sim_rest(p, v, r, mass)
		var rd := Vector2(rp.x - p.x, rp.z - p.z).length()
		if rd > dist:
			hi = s
		else:
			lo = s
		best = s
	var land2 := Vector2(p.x, p.z) + dir * best
	return _lob(p, land2, 0.5 + 0.075 * best, r)


func _ai_act() -> void:
	var team := to_play
	var lvl: Dictionary = LEVELS[settings["level"]]
	var o := _ai_origin()
	if _phase == "jack":
		var d := randf_range(jack_min + 1.0, jack_max - 1.0)
		var tx := randf_range(-tw / 2.0 + 0.7, tw / 2.0 - 0.7)
		var v := _solve_point(o, Vector3(tx, R_J, -d), R_J, M_J)
		_launch(team, o, v, true)
		return
	var shoot := false
	var opp := -team
	var opp_ball := _best_ball(opp)
	if not is_training() and opp_ball != null and _best(opp) < _best(team):
		var near := _dist_to_jack(opp_ball) < 1.5
		if near and randf() < float(lvl["p_shoot"]):
			shoot = true
	if shoot:
		var tgt := Vector2(opp_ball.pos.x, opp_ball.pos.z)
		var dist := Vector2(tgt.x - o.x, tgt.y - o.z).length()
		var dir := (tgt - Vector2(o.x, o.z)).normalized()
		var land := tgt - dir * 0.12
		var sg: float = lvl["shoot_s"]
		land += Vector2(_gauss(), _gauss()) * sg * 0.5
		var tt := clampf(dist / 12.0, 0.32, 0.7)
		_launch(team, o, _lob(o, land, tt, R_B), false)
		return
	var sp: float = lvl["point_s"]
	var jp := _jack.pos
	var rest := Vector3(jp.x + randf_range(-0.05, 0.05), R_B, jp.z + 0.09)
	rest.x += _gauss() * sp * 0.5
	rest.z += _gauss() * sp * 0.5
	rest.x = clampf(rest.x, -tw / 2.0 + 0.1, tw / 2.0 - 0.1)
	rest.z = clampf(rest.z, -tlen + 0.1, -1.0)
	_launch(team, o, _solve_point(o, rest, R_B, M_B), false)


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
		if state == State.JACK_WAIT or state == State.TURN_WAIT:
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
	if settings["points"] not in [7, 13]:
		settings["points"] = 7
	if settings["terrain"] not in ["normal", "court"]:
		settings["terrain"] = "normal"


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


func _wait_rest(max_frames: int) -> void:
	var i := 0
	while state == State.FLIGHT and i < max_frames:
		await get_tree().physics_frame
		i += 1


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["points"] = 7
	settings["terrain"] = "normal"
	_apply_layout()

	# A. Le solveur de pointage : la boule s'arrête où on le demande
	var o := _ai_origin()
	var bad := 0
	var worst := 0.0
	for i in 40:
		var rest := Vector3(randf_range(-1.2, 1.2), R_B, randf_range(-9.0, -4.5))
		var v := _solve_point(o, rest, R_B, M_B)
		var rp := _sim_rest(o, v, R_B, M_B)
		var err := Vector2(rp.x - rest.x, rp.z - rest.z).length()
		worst = maxf(worst, err)
		if err > 0.06:
			bad += 1
	_st_check("pointage calculé", bad == 0, "(pire écart %.3f m, %d ratés sur 40)" % [worst, bad])

	# A2. Distance de roulement réaliste pour une cloche de 6 m
	var vroll := _solve_point(o, Vector3(0, R_B, -6.0), R_B, M_B)
	var tl := _flight_time(o, vroll, R_B)
	var land_z := o.z + vroll.z * tl
	var roll := absf(-6.0 - land_z)
	_st_check("roulement après cloche", roll > 0.3 and roll < 3.5, "(%.2f m)" % roll)

	# B. Choc : une boule lancée sur une boule posée la déplace, le cochonnet part plus vite
	_clear_balls()
	var target := _new_ball(AI)
	target.pos = Vector3(0.2, R_B, -7.0)
	target.moving = false
	target.touched = true
	_jack = _new_ball(0)
	_jack.pos = Vector3(-0.6, R_J, -7.4)
	_jack.moving = false
	_jack.touched = true
	_phase = "play"
	var shot_from := o
	var tgt2 := Vector2(target.pos.x, target.pos.z)
	var dir2 := (tgt2 - Vector2(o.x, o.z)).normalized()
	var shot := _new_ball(PLAYER)
	shot.pos = shot_from
	shot.vel = _lob(shot_from, tgt2 - dir2 * 0.12, 0.5, R_B)
	state = State.FLIGHT
	_fly_time = 0.0
	var before := target.pos
	_clacks = 0
	await _wait_rest(90 * 8)
	var moved := Vector2(target.pos.x - before.x, target.pos.z - before.z).length()
	_st_check("tir : choc", _clacks >= 1 and moved > 0.15, "(déplacée de %.2f m, %d chocs)" % [moved, _clacks])
	_st_check("tout s'arrête", state != State.FLIGHT, "")

	# B2. Boule qui sort : morte
	_clear_balls()
	var out_b := _new_ball(PLAYER)
	out_b.pos = Vector3(tw / 2.0 - 0.1, R_B, -5.0)
	out_b.vel = Vector3(2.5, 0, 0)
	out_b.touched = true
	_jack = _new_ball(0)
	_jack.pos = Vector3(0, R_J, -8.0)
	_jack.moving = false
	_jack.touched = true
	_phase = "play"
	state = State.FLIGHT
	await _wait_rest(90 * 6)
	_st_check("boule sortie = morte", out_b.dead, "")

	# C. Règles : qui joue, et combien de points
	_clear_balls()
	_phase = "play"
	_jack = _new_ball(0)
	_jack.pos = Vector3(0, R_J, -8.0)
	_jack.moving = false
	var bp1 := _new_ball(PLAYER)
	bp1.pos = Vector3(0.1, R_B, -8.0)
	bp1.moving = false
	var ba1 := _new_ball(AI)
	ba1.pos = Vector3(-0.3, R_B, -8.0)
	ba1.moving = false
	left = [2, 2]
	_last_thrower = AI
	_st_check("la plus éloignée joue", _team_to_play() == AI, "")
	ba1.pos.x = -0.1
	_st_check("égalité : l'autre équipe joue", _team_to_play() == PLAYER, "")
	left = [0, 2]
	_st_check("plus de boules : l'autre joue", _team_to_play() == AI, "")
	left = [0, 0]
	_st_check("manche finie", _team_to_play() == 0, "")
	var r1 := end_points([0.2, 0.5], [0.3, 0.9])
	var r2 := end_points([0.5], [0.1, 0.12, 0.6])
	var r3 := end_points([0.3], [0.3])
	var r4 := end_points([], [0.4])
	_st_check("points de la manche", r1 == [PLAYER, 1] and r2 == [AI, 2] and r3 == [0, 0] and r4 == [AI, 1], str([r1, r2, r3, r4]))

	# D. Aide au lancer : un tir hors terrain est ramené dans le terrain
	_clear_balls()
	var bad2 := 0
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		for i in 40:
			var from := Vector3(randf_range(-0.2, 0.5), randf_range(0.9, 1.4), randf_range(-0.2, 0.2))
			var v2 := Vector3(randf_range(-6.0, 6.0), randf_range(1.5, 6.0), randf_range(-14.0, -2.0))
			var a := _assist(from, v2, false)
			var t2 := _flight_time(from, a, R_B)
			var lx := from.x + a.x * t2
			var lz := from.z + a.z * t2
			var strength: float = LEVELS[lv]["assist"]
			if strength >= 0.99 and (absf(lx) > tw / 2.0 or lz < -tlen or lz > 0.0):
				bad2 += 1
	_st_check("aide au lancer", bad2 == 0, "(%d hors terrain après aide)" % bad2)
	settings["level"] = "normal"

	# E. Parties complètes : l'ordinateur contre un joueur virtuel, à chaque niveau
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		settings["points"] = 7
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 900:
			await get_tree().physics_frame
			guard += 1
		var ok := state == State.GAME_OVER and maxi(scores[0], scores[1]) >= 7
		_st_check("partie %s terminée" % lv, ok, "%s en %.0f s" % [str(scores), guard / 90.0])

	# F. Entraînement : une manche se termine
	settings["mode"] = "training"
	_st_bot = true
	start_match()
	var g2 := 0
	while _train_end < 1 and g2 < 90 * 120:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement : manche", _train_end >= 1, "(%d pts en %.0f s)" % [_train_total, g2 / 90.0])
	_st_bot = false

	# G. Lancer humain simulé : cochonnet puis boule, avec l'aide
	settings["mode"] = "ordi"
	settings["level"] = "facile"
	start_match()
	await _wait_frames(2)
	_st_check("cochonnet à lancer", state == State.JACK_WAIT and _held != null and _held.team == 0, str(state))
	_throw(Vector3(0.3, 1.2, 0.0), Vector3(0.1, 3.5, -5.5))
	await _wait_rest(90 * 10)
	var jack_ok := _phase == "play" or _jack_fails > 0
	_st_check("cochonnet lancé", jack_ok and _jack != null, "(distance %.1f m)" % (-_jack.pos.z if _jack else -1.0))
	var guard3 := 0
	while state != State.TURN_WAIT and guard3 < 600:
		await get_tree().physics_frame
		guard3 += 1
	_st_check("tour du joueur", state == State.TURN_WAIT and _held != null and _held.team == PLAYER, str(state))
	if state == State.TURN_WAIT:
		_throw(Vector3(0.3, 1.2, 0.0), Vector3(0.0, 4.0, -6.5))
		await _wait_rest(90 * 10)
		_st_check("boule du joueur posée", left[0] == 2 and _alive_boules(PLAYER).size() == 1, str(left))

	_clear_balls()
	for line in _st_log:
		print("SELFTEST petanque ", line)
	print("SELFTEST petanque=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())


## Place de village : platanes, bancs, lampadaires, muret et enseigne au fond.
func _build_decor() -> void:
	var side := tw / 2.0
	var zs := [-3.5, -6.0, -8.5, -11.0]
	for i in zs.size():
		var z: float = zs[i]
		if z < -tlen + 0.5:
			continue
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(2.6 + 0.3 * ((i + int(sx)) % 3), i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (side + 2.0 + 0.3 * (i % 2)), 0, z)
			_terrain.add_child(t)
	for sx in [-1.0, 1.0]:
		var b := Decor.bush(0.4)
		b.position = Vector3(sx * (side + 0.35), 0, -tlen * 0.5)
		_terrain.add_child(b)
	var bench := Decor.bench()
	bench.position = Vector3(-(side + 0.75), 0, -3.2)
	bench.rotation.y = -PI / 2.0
	_terrain.add_child(bench)
	var bench2 := Decor.bench()
	bench2.position = Vector3(side + 0.75, 0, -5.2)
	bench2.rotation.y = PI / 2.0
	_terrain.add_child(bench2)
	for sx in [-1.0, 1.0]:
		var l := Decor.lamp(2.6)
		l.position = Vector3(sx * (side + 0.35), 0, -tlen - 0.05)
		_terrain.add_child(l)
	var wall := BowlingArt.box(Vector3(tw + 3.4, 0.9, 0.25), BowlingArt.mat(Color(0.62, 0.58, 0.5), 0.95), Vector3(0, 0.45, -tlen - 0.35))
	_terrain.add_child(wall)
	_terrain.add_child(BowlingArt.box(Vector3(tw + 3.5, 0.06, 0.3), BowlingArt.mat(Color(0.45, 0.42, 0.37), 0.9), Vector3(0, 0.93, -tlen - 0.35)))
	var sign_node := Decor.neon_sign("PÉTANQUE", Color(1.0, 0.75, 0.2), 1.8, 0.5)
	sign_node.position = Vector3(0, 1.75, -tlen - 0.4)
	_terrain.add_child(sign_node)
