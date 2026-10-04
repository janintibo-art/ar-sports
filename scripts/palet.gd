class_name PaletGame
extends Node3D
## Palet en réalité augmentée : une planche de bois posée devant le joueur, des palets
## que l'on lance en cloche pour qu'ils se posent SUR la planche (sinon ils sont morts).
## Trois variantes : Breton (rapprocher du maître), Planche à trous, Cible à anneaux.
## Physique maison (réutilise PetBall) : stable et prévisible.
## Le noeud est placé aux pieds du joueur ; la planche est à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const R_B := 0.06             # palet
const R_J := 0.03             # maître (petit palet)
const M_B := 0.5
const M_J := 0.15
const SUBSTEPS := 2
const Z_BACK := 0.6
const SAVE_PATH := "user://palet.cfg"
const PLAYER := 1
const AI := -1
const STAND := Vector3(0.38, 0.99, -0.2)
const GRAB_RADIUS := 0.38
const THROW_GAIN_H := 2.1
const THROW_GAIN_V := 1.45
const BW := 1.6               # largeur de la planche
const BL := 1.2               # profondeur de la planche
const TOP := 0.03             # hauteur de la planche
const GY := 0.042             # hauteur du centre d'un palet posé
const LAND_KEEP_P := 0.35     # la planche freine à l'atterrissage
const ROLL_DECEL_P := 5.0
const HOLE_R := 0.10
const HOLE_CAPTURE := 0.075
const HOLES := [
	[0.0, 0.38, 20], [-0.5, 0.15, 10], [0.5, 0.15, 10], [-0.25, -0.2, 5], [0.25, -0.2, 5],
]
const RINGS := [[0.55, 1], [0.38, 2], [0.22, 3], [0.10, 5]]
const CLR_PLAYER := Color(0.45, 0.65, 1.0)
const CLR_AI := Color(0.95, 0.45, 0.3)
const VARIANTS := {
	"breton": {"title": "Breton", "palets": 4, "points": [6, 12], "default": 6},
	"trous": {"title": "Planche à trous", "palets": 5, "points": [21, 31], "default": 21},
	"cible": {"title": "Cible", "palets": 5, "points": [21, 31], "default": 21},
}

const LEVELS := {
	"facile": {"title": "Facile", "assist": 1.0, "point_s": 0.50, "p_shoot": 0.08, "shoot_s": 0.30, "aim_s": 0.14},
	"normal": {"title": "Normal", "assist": 0.7, "point_s": 0.26, "p_shoot": 0.30, "shoot_s": 0.14, "aim_s": 0.09},
	"expert": {"title": "Expert", "assist": 0.3, "point_s": 0.12, "p_shoot": 0.55, "shoot_s": 0.06, "aim_s": 0.05},
}

enum State { SETUP, JACK_WAIT, TURN_WAIT, AI_WAIT, FLIGHT, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "level": "normal", "variant": "breton", "points": 6, "dist": 5.0, "music": true}
var state := State.SETUP
var scores := [0, 0]          # [équipe 1 (vous), équipe 2 (adversaire)]
var left := [4, 4]            # palets restants
var starter := PLAYER
var to_play := PLAYER
var _last_thrower := PLAYER
var _phase := "jack"          # "jack" : on lance le cochonnet ; "play" : on joue les boules
var _jack_fails := 0
var _balls: Array[PetBall] = []
var _jack: PetBall = null

# Terrain
var tw := 3.0
var tlen := 7.0
var bz := -5.0                 # z du centre de la planche
var _round_gain := [0, 0]
var _throw_gain := 0
var _throw_dead := false

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
var _yann: Spectator
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

	_lead_ring = BowlingArt.cylinder(0.085, 0.085, 0.002, BowlingArt.unshaded(Color(1, 1, 1, 0.7)), Vector3.ZERO, 28)
	(_lead_ring.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lead_ring.visible = false
	add_child(_lead_ring)
	_jack_ring = BowlingArt.cylinder(0.055, 0.055, 0.002, BowlingArt.unshaded(Color(1, 0.9, 0.3, 0.55)), Vector3.ZERO, 28)
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
	_yann = Spectator.new({
		"name": "Yann", "skin": Color(0.9, 0.72, 0.6), "shirt": Color(0.2, 0.3, 0.6),
		"pants": Color(0.75, 0.7, 0.55), "hair": Color(0.8, 0.8, 0.8), "beard": false,
		"hat": true, "hat_color": Color(0.1, 0.1, 0.12),
	})
	add_child(_yann)

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
	_panel.accent = Color(0.3, 0.75, 0.9)
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


## Dimensions du terrain et position des éléments.
func _apply_layout() -> void:
	bz = -float(settings["dist"])
	tw = 3.4
	tlen = -bz + BL / 2.0 + 1.6
	_build_terrain()
	_scoreboard.position = Vector3(1.9, 1.45, -3.2)
	_scoreboard.scale = Vector3.ONE * 1.15
	var face := Vector3(0, 0, 1.5) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_yann.position = Vector3(-1.0, 0, 0.1)
	_yann.rotation.y = deg_to_rad(25.0)
	_message.position = Vector3(0, 1.8, -2.5)
	_hint.position = STAND + Vector3(0, 0.28, 0)


func is_breton() -> bool:
	return settings["variant"] == "breton"


func _board_rect() -> Rect2:
	return Rect2(Vector2(-BW / 2.0, bz - BL / 2.0), Vector2(BW, BL))


## Zone où un palet doit s'arrêter pour avoir atterri sur la planche (il glisse encore un peu).
func _rest_zone() -> Rect2:
	return Rect2(Vector2(-BW / 2.0 + 0.12, bz - BL / 2.0 + 0.10), Vector2(BW - 0.24, BL - 0.62))


func _hole_pos(i: int) -> Vector2:
	return Vector2(float(HOLES[i][0]), bz - float(HOLES[i][1]))


static func ring_points(d: float) -> int:
	var pts := 0
	for r in RINGS:
		if d <= float(r[0]):
			pts = int(r[1])
	return pts


func _ring_sum(team: int) -> int:
	var total := 0
	for b in _alive_boules(team):
		total += ring_points(Vector2(b.pos.x, b.pos.z - bz).length())
	return total


func _gravel_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in s:
		for y in s:
			var v := 0.60 + rng.randf_range(-0.07, 0.07)
			if rng.randf() < 0.05:
				v -= 0.18
			elif rng.randf() < 0.03:
				v += 0.12
			img.set_pixel(x, y, Color(v * 1.0, v * 0.9, v * 0.74))
	return ImageTexture.create_from_image(img)


func _build_terrain() -> void:
	for c in _terrain.get_children():
		c.queue_free()
	var zc := (Z_BACK - tlen) / 2.0
	var len := tlen + Z_BACK
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _gravel_texture()
	gm.uv1_scale = Vector3(tw * 2.5, len * 2.5, 1.0)
	gm.roughness = 0.95
	_terrain.add_child(BowlingArt.floor_quad(tw, len, gm, Vector3(0, 0.001, zc)))
	var wood := BowlingArt.mat(Color(0.42, 0.27, 0.14), 0.7)
	for sx in [-1.0, 1.0]:
		_terrain.add_child(BowlingArt.box(Vector3(0.05, 0.09, len + 0.05), wood, Vector3(sx * (tw / 2.0 + 0.025), 0.045, zc)))
	_terrain.add_child(BowlingArt.box(Vector3(tw + 0.1, 0.09, 0.05), wood, Vector3(0, 0.045, -tlen - 0.025)))
	_terrain.add_child(BowlingArt.box(Vector3(tw + 0.1, 0.09, 0.05), wood, Vector3(0, 0.045, Z_BACK + 0.025)))
	_terrain.add_child(BowlingArt.cylinder(0.27, 0.27, 0.003, BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, 0.004, 0), 40))
	_terrain.add_child(BowlingArt.cylinder(0.24, 0.24, 0.004, gm, Vector3(0, 0.0045, 0), 40))
	_build_board()
	_build_decor()
	var lab := BowlingArt.label("%s m" % str(settings["dist"]).replace(".", ","), 0.16, Color(1, 1, 1), 6)
	lab.rotation_degrees = Vector3(-90, 0, 0)
	lab.position = Vector3(-(tw / 2.0 - 0.45), 0.006, bz + BL / 2.0 + 0.3)
	_terrain.add_child(lab)


## La planche : bois (Breton, Cible) ou peinte avec des trous.
func _build_board() -> void:
	var v: String = settings["variant"]
	var n := 8
	var pw := BW / n
	for i in n:
		var base := Color(0.62, 0.43, 0.24) if v != "trous" else Color(0.14, 0.28, 0.42)
		var shade := 1.0 + 0.07 * (((i * 5) % 7) - 3) / 3.0
		_terrain.add_child(BowlingArt.box(Vector3(pw - 0.004, TOP, BL), BowlingArt.mat(base * Color(shade, shade, shade), 0.75), Vector3(-BW / 2.0 + pw * (i + 0.5), TOP / 2.0, bz)))
	var frame := BowlingArt.mat(Color(0.3, 0.19, 0.1), 0.7)
	for sx in [-1.0, 1.0]:
		_terrain.add_child(BowlingArt.box(Vector3(0.05, TOP + 0.03, BL + 0.1), frame, Vector3(sx * (BW / 2.0 + 0.025), (TOP + 0.03) / 2.0, bz)))
	for sz in [-1.0, 1.0]:
		_terrain.add_child(BowlingArt.box(Vector3(BW + 0.1, TOP + 0.03, 0.05), frame, Vector3(0, (TOP + 0.03) / 2.0, bz + sz * (BL / 2.0 + 0.025))))
	var y := TOP + 0.001
	if v == "breton":
		var white := BowlingArt.unshaded(Color(1, 1, 1))
		var z := _rest_zone()
		for sx in [z.position.x, z.end.x]:
			_terrain.add_child(BowlingArt.box(Vector3(0.012, 0.002, z.size.y), white, Vector3(sx, y, z.position.y + z.size.y / 2.0)))
		for sz in [z.position.y, z.end.y]:
			_terrain.add_child(BowlingArt.box(Vector3(z.size.x, 0.002, 0.012), white, Vector3(0, y, sz)))
	elif v == "cible":
		var k := 0
		for r in RINGS:
			var cols := [Color(0.92, 0.92, 0.85), Color(0.25, 0.5, 0.9), Color(0.9, 0.25, 0.25), Color(1.0, 0.85, 0.2)]
			var rad: float = r[0]
			_terrain.add_child(BowlingArt.cylinder(rad, rad, 0.0012, BowlingArt.unshaded(cols[k]), Vector3(0, y + 0.0008 * k, bz), 40))
			var lab := BowlingArt.label(str(int(r[1])), 0.07, Color(0.1, 0.1, 0.1), 2)
			lab.rotation_degrees = Vector3(-90, 0, 0)
			lab.position = Vector3(0.0, y + 0.004, bz + rad - 0.045) if k < 3 else Vector3(0.0, y + 0.004, bz)
			if k < 3:
				_terrain.add_child(lab)
			else:
				lab.pixel_size *= 0.8
				_terrain.add_child(lab)
			k += 1
	else:
		for i in HOLES.size():
			var hp := _hole_pos(i)
			_terrain.add_child(BowlingArt.cylinder(HOLE_R + 0.014, HOLE_R + 0.014, 0.0015, BowlingArt.unshaded(Color(0.95, 0.85, 0.5)), Vector3(hp.x, y, hp.y), 32))
			_terrain.add_child(BowlingArt.cylinder(HOLE_R, HOLE_R, 0.0015, BowlingArt.unshaded(Color(0.02, 0.02, 0.03)), Vector3(hp.x, y + 0.001, hp.y), 32))
			var lab := BowlingArt.label(str(int(HOLES[i][2])), 0.1, Color(1, 0.9, 0.4), 4)
			lab.rotation_degrees = Vector3(-90, 0, 0)
			lab.position = Vector3(hp.x, y + 0.004, hp.y + HOLE_R + 0.07)
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
	return "Joueur 2" if _is_two() else "Yann"


func _best_key() -> String:
	return "best_training_" + String(settings["variant"])


func show_setup() -> void:
	state = State.SETUP
	_clear_balls()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Palet", "Victoires : %d   ·   meilleur entraînement : %d pts" % [_stat("wins"), _stat(_best_key())])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.26, "selected": settings["mode"] == "ordi"},
		{"id": "mode_deux", "text": "2 joueurs", "width": 0.22, "selected": settings["mode"] == "deux"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
	])
	var vrow: Array = []
	for k in VARIANTS:
		vrow.append({"id": "variant_" + k, "text": VARIANTS[k]["title"], "width": 0.34 if k == "trous" else 0.22, "selected": settings["variant"] == k})
	_panel.add_row("Variante", vrow)
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	var prow: Array = []
	for p in VARIANTS[settings["variant"]]["points"]:
		prow.append({"id": "points_%d" % int(p), "text": str(int(p)), "width": 0.14, "selected": settings["points"] == int(p)})
	_panel.add_row("Points", prow)
	_panel.add_row("Distance", [
		{"id": "dist_3.5", "text": "3,5 m", "width": 0.2, "selected": is_equal_approx(float(settings["dist"]), 3.5)},
		{"id": "dist_5.0", "text": "5 m", "width": 0.2, "selected": is_equal_approx(float(settings["dist"]), 5.0)},
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
	elif id.begins_with("variant_"):
		settings["variant"] = id.substr(8)
		settings["points"] = int(VARIANTS[settings["variant"]]["default"])
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
	b.land_keep = LAND_KEEP_P
	b.roll_decel = ROLL_DECEL_P
	b.ground_y = GY
	b.spin = false
	b.r = R_J if team == 0 else R_B
	b.mass = M_J if team == 0 else M_B
	var col := Color(1.0, 0.85, 0.2)
	if team != 0:
		col = CLR_PLAYER if team == PLAYER else CLR_AI
	b.node = BowlingArt.cylinder(b.r, b.r, 0.024, BowlingArt.mat(col, 0.3, 0.7), Vector3.ZERO, 28)
	b.node.add_child(BowlingArt.cylinder(b.r * 0.62, b.r * 0.62, 0.026, BowlingArt.mat(col.lightened(0.35), 0.25, 0.8), Vector3.ZERO, 24))
	_balls_root.add_child(b.node)
	b.shadow = BowlingArt.make_blob(b.r * 3.5)
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
	if not is_breton():
		return -_last_thrower
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
	var n: int = VARIANTS[settings["variant"]]["palets"]
	left = [n, n]
	_round_gain = [0, 0]
	_jack_fails = 0
	to_play = starter
	if is_breton():
		_phase = "jack"
		_last_thrower = starter
		_update_scoreboard()
		_begin_jack_turn()
	else:
		_phase = "play"
		_last_thrower = -starter
		_update_scoreboard()
		_begin_turn()


func _begin_jack_turn() -> void:
	if is_training() or not _is_human(starter):
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""
		_announce("Le maître !" if starter == PLAYER else "%s lance le maître" % _team_name(starter), Color(1, 0.8, 0.2), 1.6)
	else:
		state = State.JACK_WAIT
		_spawn_held(0)
		_hint.text = "Attrape le maître (gâchette)\net lance-le sur la planche"
		_announce("%s : le maître !" % _team_name(starter), Color(1, 0.8, 0.2), 1.8)


func _begin_turn() -> void:
	_update_scoreboard()
	if _is_human(to_play):
		state = State.TURN_WAIT
		_spawn_held(to_play)
		_hint.text = "Attrape le palet (gâchette ou grip)\nlance-le en cloche sur la planche"
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
	_throw_gain = 0
	_throw_dead = false
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


func _flight_time(p: Vector3, v: Vector3, _r: float) -> float:
	var disc := v.y * v.y + 2.0 * PetBall.G * (p.y - GY)
	if disc < 0.0:
		return 0.0
	return (v.y + sqrt(disc)) / PetBall.G


## Aide au lancer : un palet qui s'arrêterait hors de la zone utile de la planche y est ramené.
## Un tir correct n'est jamais modifié.
func _assist(p: Vector3, v: Vector3, as_jack: bool) -> Vector3:
	var a: float = LEVELS[settings["level"]]["assist"]
	if a < 0.5:
		return v
	var r := R_J if as_jack else R_B
	var m := M_J if as_jack else M_B
	var rest := _sim_rest(p, v, r, m)
	var zone := _rest_zone()
	if as_jack:
		zone = zone.grow_individual(-0.1, -0.05, -0.1, -0.05)
	var rp := Vector2(rest.x, rest.z)
	if zone.has_point(rp):
		return v
	var goal := Vector2(clampf(rp.x, zone.position.x, zone.end.x), clampf(rp.y, zone.position.y, zone.end.y))
	return _solve_point(p, Vector3(goal.x, GY, goal.y), r, m)


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
	# Hors de la planche (seulement une fois posé) et trous
	var rect := _board_rect()
	var holes: bool = settings["variant"] == "trous"
	for b in _balls:
		if b == _held or b.dead or not b.touched:
			continue
		var p2 := Vector2(b.pos.x, b.pos.z)
		if not rect.has_point(p2):
			b.dead = true
			b.moving = false
			b.vel = Vector3.ZERO
			b.pos.y = 0.012
			_throw_dead = true
			continue
		if holes and b.team != 0:
			for i in HOLES.size():
				if p2.distance_to(_hole_pos(i)) < HOLE_CAPTURE:
					_capture(b, i)
					break


func _capture(b: PetBall, i: int) -> void:
	var value := int(HOLES[i][2])
	b.dead = true
	b.moving = false
	b.vel = Vector3.ZERO
	b.node.visible = false
	b.shadow.visible = false
	var idx := 0 if b.team == PLAYER else 1
	scores[idx] += value
	_round_gain[idx] += value
	if b.team == _last_thrower:
		_throw_gain += value
	var hp := _hole_pos(i)
	_float_text("+%d" % value, Vector3(hp.x, TOP + 0.1, hp.y), CLR_PLAYER if b.team == PLAYER else CLR_AI)
	Sound.play_at("pet_land", to_global(Vector3(hp.x, TOP, hp.y)), 0.0, 0.05)
	if value >= 10:
		_scoreboard.celebrate("point")
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.3, 0.08)


func _float_text(text: String, pos: Vector3, color: Color) -> void:
	var l := BowlingArt.neon_label(text, 0.14, color)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	_fx_root.add_child(l)
	var tw_ := create_tween()
	tw_.set_parallel(true)
	tw_.tween_property(l, "position:y", pos.y + 0.45, 1.1)
	tw_.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw_.chain().tween_callback(l.queue_free)


func _update_visuals(delta: float) -> void:
	for b in _balls:
		if b == _held and _held_hand == null:
			continue
		b.node.position = b.pos
		if b.spin and b.moving and b.pos.y <= b.r + 0.01:
			var axis := Vector3(b.vel.z, 0, -b.vel.x)
			if axis.length() > 0.01:
				b.node.rotate(axis.normalized(), Vector2(b.vel.x, b.vel.z).length() * delta / b.r)
		if b.shadow:
			var h := maxf(0.0, b.pos.y - GY)
			var on_b := _board_rect().has_point(Vector2(b.pos.x, b.pos.z))
			b.shadow.position = Vector3(b.pos.x, TOP + 0.002 if on_b else 0.003, b.pos.z)
			b.shadow.scale = Vector3.ONE * clampf(1.0 - h * 0.25, 0.4, 1.0)
	_update_markers()


func _update_markers() -> void:
	# Anneau autour du cochonnet et marque de la boule qui « tient le point »
	if is_breton() and _jack != null and not _jack.dead and _phase == "play":
		_jack_ring.visible = true
		_jack_ring.position = Vector3(_jack.pos.x, TOP + 0.004, _jack.pos.z)
	else:
		_jack_ring.visible = false
	if _lead_ball != null and not _lead_ball.dead and _phase == "play" and state != State.FLIGHT:
		_lead_ring.visible = true
		_lead_ring.position = Vector3(_lead_ball.pos.x, TOP + 0.005, _lead_ball.pos.z)
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
	if is_breton() and (_jack == null or _jack.dead):
		_void_end("Maître sorti ! On recommence")
		return
	var gained := _throw_gain
	var went_out := _throw_dead
	_throw_gain = 0
	_throw_dead = false
	_remove_dead_from_play()
	_lead_ball = null
	if is_breton():
		var bt := _best_ball(PLAYER)
		var ba := _best_ball(AI)
		if bt != null or ba != null:
			var dp := _best(PLAYER)
			var da := _best(AI)
			_lead_ball = bt if dp < da else ba
			var lead_team: int = _lead_ball.team
			_lead_label.text = "%d cm" % int(round(_dist_to_jack(_lead_ball) * 100.0))
			_lead_label.modulate = CLR_PLAYER if lead_team == PLAYER else CLR_AI
	_react_after_throw(gained, went_out)
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


func _react_after_throw(gained: int, went_out: bool) -> void:
	var team := _last_thrower
	if gained > 0:
		_announce("+%d !" % gained, CLR_PLAYER if team == PLAYER else CLR_AI, 1.8)
		if team == PLAYER and not _is_two() and not is_training():
			_yann.say("good")
		elif team == AI and not _is_two() and not is_training():
			_yann.react("pointe")
		return
	if went_out:
		_announce("Hors planche !", Color(1, 0.5, 0.3), 1.6)
		if team == AI and not _is_two() and not is_training():
			_yann.react("oups")
		return
	if is_training() or _lead_ball == null or not is_breton():
		return
	var lead: int = _lead_ball.team
	var d_cm := int(round(_dist_to_jack(_lead_ball) * 100.0))
	var who := _team_name(lead)
	_announce("%s tient le point · %d cm" % [who, d_cm], CLR_PLAYER if lead == PLAYER else CLR_AI, 2.2)
	if lead == PLAYER and team == PLAYER and d_cm < 15 and not _is_two():
		_yann.react("pointe")
	elif lead == AI and team == PLAYER and not _is_two():
		_yann.say("good")


func _after_jack() -> void:
	var ok := _jack != null and not _jack.dead
	if ok:
		ok = _board_rect().grow(-0.08).has_point(Vector2(_jack.pos.x, _jack.pos.z))
	if not ok:
		_jack_fails += 1
		if _jack != null:
			_balls.erase(_jack)
			_free_ball(_jack)
			_jack = null
		if _is_human(starter) and not is_training() and _jack_fails < 2:
			_announce("Maître non valable !", Color(1, 0.4, 0.3), 1.8)
			_begin_jack_turn_retry()
			return
		# Trop d'échecs : on le pose nous-mêmes au milieu de la planche
		_jack = _new_ball(0)
		_jack.pos = Vector3(randf_range(-0.3, 0.3), GY, bz - 0.1)
		_jack.moving = false
		_jack.touched = true
		_announce("Maître posé par l'arbitre", Color(1, 0.8, 0.2), 1.6)
	_phase = "play"
	_last_thrower = -starter
	to_play = starter
	_lead_ball = null
	_begin_turn()


func _begin_jack_turn_retry() -> void:
	state = State.JACK_WAIT
	_spawn_held(0)
	_hint.text = "Attrape le maître (gâchette)\net lance-le sur la planche"


func _void_end(msg: String) -> void:
	_announce(msg, Color(1, 0.5, 0.3), 2.4)
	_pause_next = "restart_end"
	state = State.PAUSE
	_timer = 2.4 if not _selftest else 0.3


func _finish_end() -> void:
	var v := String(settings["variant"])
	if is_training():
		var total := 0
		match v:
			"breton":
				for d in _distances(PLAYER):
					var dd: float = d
					if dd < 0.10:
						total += 3
					elif dd < 0.25:
						total += 2
					elif dd < 0.60:
						total += 1
			"trous":
				total = _round_gain[0]
			_:
				total = _ring_sum(PLAYER)
		_train_end += 1
		_train_total += total
		_train_best_session = maxi(_train_best_session, total)
		_best_stat(_best_key(), total)
		_announce("Manche : %d pts" % total, Color(1, 0.8, 0.2), 2.6)
		_scoreboard.celebrate("point")
		_pause_next = "next_end"
		state = State.PAUSE
		_timer = 3.0 if not _selftest else 0.3
		_update_scoreboard()
		return
	if v == "breton":
		var res := end_points(_distances(PLAYER), _distances(AI))
		var win_team: int = res[0]
		var pts: int = res[1]
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
					_yann.react("oups")
				else:
					_yann.react("carreau" if pts >= 3 else "pointe")
	else:
		if v == "cible":
			for t in [PLAYER, AI]:
				var idx := 0 if t == PLAYER else 1
				var g := _ring_sum(t)
				scores[idx] += g
				_round_gain[idx] = g
		_announce("Manche : %d – %d" % [_round_gain[0], _round_gain[1]], Color(1, 0.8, 0.2), 2.6)
		_scoreboard.celebrate("point")
		starter = -starter
	_update_scoreboard()
	_pause_next = "next_end"
	state = State.PAUSE
	_timer = 3.2 if not _selftest else 0.3


## Fin de partie : objectif atteint (et pas d'égalité pour les variantes à points cumulés).
func _target_reached() -> bool:
	var t: int = settings["points"]
	if scores[0] < t and scores[1] < t:
		return false
	if is_breton():
		return true
	return scores[0] != scores[1]


func _after_pause() -> void:
	match _pause_next:
		"restart_end":
			_start_end()
		"next_end":
			if not is_training() and _target_reached():
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
			_yann.say("win", true)
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
	var vt := String(VARIANTS[settings["variant"]]["title"]).to_upper()
	if is_training():
		_scoreboard.set_data("PALET · " + vt + " · ENTRAÎNEMENT", ["TOTAL", "RECORD"], [_train_total, maxi(_stat(_best_key()), _train_best_session)], 0, "Manche %d · palets restants : %d" % [_train_end + 1, left[0]])
		return
	var mode := "2 JOUEURS" if _is_two() else lvl
	var names := ["VOUS", "YANN"] if not _is_two() else ["J1", "J2"]
	var foot := "Palets : %d – %d   ·   premier à %d" % [left[0], left[1], int(settings["points"])]
	if settings["variant"] == "cible":
		foot = "Sur la cible : %d – %d   ·   premier à %d" % [_ring_sum(PLAYER), _ring_sum(AI), int(settings["points"])]
	var srv := to_play if state != State.SETUP else 0
	_scoreboard.set_data("PALET · %s · %s" % [vt, mode], names, scores, srv, foot)


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
	var vy := (GY - p.y + 0.5 * PetBall.G * t * t) / t
	return Vector3((land.x - p.x) / t, vy, (land.y - p.z) / t)


## Où s'arrête une boule lancée de `p` avec la vitesse `v` (sans obstacle).
func _sim_rest(p: Vector3, v: Vector3, r: float, mass: float) -> Vector3:
	var b := PetBall.new()
	b.r = r
	b.mass = mass
	b.land_keep = LAND_KEEP_P
	b.roll_decel = ROLL_DECEL_P
	b.ground_y = GY
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
	var zone := _rest_zone()
	if _phase == "jack":
		var zj := zone.grow_individual(-0.15, -0.05, -0.15, -0.05)
		var tx := randf_range(zj.position.x, zj.end.x)
		var tz := randf_range(zj.position.y, zj.end.y)
		_launch(team, o, _solve_point(o, Vector3(tx, GY, tz), R_J, M_J), true)
		return
	var v: String = settings["variant"]
	if v == "trous":
		var pick := randf()
		var hi := 0 if pick < 0.4 else (1 + randi() % 2 if pick < 0.75 else 3 + randi() % 2)
		var hp := _hole_pos(hi)
		var ax := hp.x + _gauss() * float(lvl["aim_s"]) * 0.6
		var az := hp.y - 0.04 + _gauss() * float(lvl["aim_s"]) * 0.6
		_launch(team, o, _solve_point(o, Vector3(ax, GY, az), R_B, M_B), false)
		return
	if v == "cible":
		var cx := _gauss() * float(lvl["aim_s"]) * 0.7
		var cz := bz + _gauss() * float(lvl["aim_s"]) * 0.7
		var cvec := _solve_point(o, Vector3(clampf(cx, -BW / 2.0 + 0.1, BW / 2.0 - 0.1), GY, clampf(cz, zone.position.y, zone.end.y)), R_B, M_B)
		_launch(team, o, cvec, false)
		return
	var shoot := false
	var opp := -team
	var opp_ball := _best_ball(opp)
	if not is_training() and opp_ball != null and _best(opp) < _best(team):
		var near := _dist_to_jack(opp_ball) < 0.6
		if near and randf() < float(lvl["p_shoot"]):
			shoot = true
	if shoot:
		var tgt := Vector2(opp_ball.pos.x, opp_ball.pos.z)
		var dist := Vector2(tgt.x - o.x, tgt.y - o.z).length()
		var dir := (tgt - Vector2(o.x, o.z)).normalized()
		var land := tgt - dir * 0.12
		var sg: float = lvl["shoot_s"]
		land += Vector2(_gauss(), _gauss()) * sg * 0.5
		var tt := clampf(dist / 12.0, 0.4, 0.8)
		_launch(team, o, _lob(o, land, tt, R_B), false)
		return
	var sp: float = lvl["point_s"]
	var jp := _jack.pos
	var rx := jp.x + randf_range(-0.03, 0.03) + _gauss() * sp * 0.4
	var rz := jp.z + 0.10 + _gauss() * sp * 0.4
	rx = clampf(rx, zone.position.x, zone.end.x)
	rz = clampf(rz, zone.position.y, zone.end.y)
	_launch(team, o, _solve_point(o, Vector3(rx, GY, rz), R_B, M_B), false)


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
	if not VARIANTS.has(settings["variant"]):
		settings["variant"] = "breton"
	if int(settings["points"]) not in VARIANTS[settings["variant"]]["points"]:
		settings["points"] = int(VARIANTS[settings["variant"]]["default"])
	if not (is_equal_approx(float(settings["dist"]), 3.5) or is_equal_approx(float(settings["dist"]), 5.0)):
		settings["dist"] = 5.0


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
	settings["variant"] = "breton"
	settings["points"] = 6
	settings["dist"] = 5.0
	_apply_layout()

	# A. Le solveur : le palet s'arrête où on le demande (dans la zone utile)
	var o := _ai_origin()
	var zone := _rest_zone()
	var bad := 0
	var worst := 0.0
	for i in 40:
		var rest := Vector3(randf_range(zone.position.x, zone.end.x), GY, randf_range(zone.position.y, zone.end.y))
		var v := _solve_point(o, rest, R_B, M_B)
		var rp := _sim_rest(o, v, R_B, M_B)
		var err := Vector2(rp.x - rest.x, rp.z - rest.z).length()
		worst = maxf(worst, err)
		if err > 0.06:
			bad += 1
	_st_check("visée calculée", bad == 0, "(pire écart %.3f m, %d ratés sur 40)" % [worst, bad])

	# A2. Le palet atterrit bien sur la planche quand il vise la zone
	var off := 0
	for i in 40:
		var rest2 := Vector3(randf_range(zone.position.x, zone.end.x), GY, randf_range(zone.position.y, zone.end.y))
		var v2 := _solve_point(o, rest2, R_B, M_B)
		var t2 := _flight_time(o, v2, R_B)
		var land := Vector2(o.x + v2.x * t2, o.z + v2.z * t2)
		if not _board_rect().has_point(land):
			off += 1
	_st_check("atterrissage sur la planche", off == 0, "(%d hors planche sur 40)" % off)

	# B. Choc : un palet lancé sur un palet posé le déplace
	settings["variant"] = "cible"
	_clear_balls()
	var target := _new_ball(AI)
	target.pos = Vector3(0.2, GY, bz - 0.1)
	target.moving = false
	target.touched = true
	_phase = "play"
	var tgt2 := Vector2(target.pos.x, target.pos.z)
	var dir2 := (tgt2 - Vector2(o.x, o.z)).normalized()
	var shot := _new_ball(PLAYER)
	shot.pos = o
	shot.vel = _lob(o, tgt2 - dir2 * 0.12, 0.6, R_B)
	state = State.FLIGHT
	_fly_time = 0.0
	var before := target.pos
	_clacks = 0
	await _wait_rest(90 * 8)
	var moved := Vector2(target.pos.x - before.x, target.pos.z - before.z).length()
	_st_check("tir : choc", _clacks >= 1 and moved > 0.1, "(déplacé de %.2f m, %d chocs)" % [moved, _clacks])
	_st_check("tout s'arrête", state != State.FLIGHT, "")

	# B2. Un palet qui quitte la planche est mort
	_clear_balls()
	var out_b := _new_ball(PLAYER)
	out_b.pos = Vector3(BW / 2.0 - 0.1, GY, bz)
	out_b.vel = Vector3(2.5, 0, 0)
	out_b.touched = true
	state = State.FLIGHT
	await _wait_rest(90 * 6)
	_st_check("palet sorti = mort", out_b.dead, "")

	# B3. Trou : un palet qui passe sur le trou du 20 le fait tomber et marque
	settings["variant"] = "trous"
	_apply_layout()
	scores = [0, 0]
	_round_gain = [0, 0]
	_clear_balls()
	var hp := _hole_pos(0)
	var hb := _new_ball(PLAYER)
	hb.pos = Vector3(hp.x - 0.3, GY, hp.y)
	hb.vel = Vector3(1.6, 0, 0)
	hb.touched = true
	_last_thrower = PLAYER
	state = State.FLIGHT
	await _wait_rest(90 * 6)
	_st_check("trou : 20 points", hb.dead and scores[0] == 20, "(%s)" % str(scores))

	# C. Règles
	_st_check("anneaux", ring_points(0.05) == 5 and ring_points(0.15) == 3 and ring_points(0.3) == 2 and ring_points(0.5) == 1 and ring_points(0.8) == 0, "")
	settings["variant"] = "breton"
	_clear_balls()
	_phase = "play"
	_jack = _new_ball(0)
	_jack.pos = Vector3(0, GY, bz)
	_jack.moving = false
	var bp1 := _new_ball(PLAYER)
	bp1.pos = Vector3(0.1, GY, bz)
	bp1.moving = false
	var ba1 := _new_ball(AI)
	ba1.pos = Vector3(-0.3, GY, bz)
	ba1.moving = false
	left = [2, 2]
	_last_thrower = AI
	_st_check("la plus éloignée joue", _team_to_play() == AI, "")
	ba1.pos.x = -0.1
	_st_check("égalité : l'autre équipe joue", _team_to_play() == PLAYER, "")
	left = [0, 2]
	_st_check("plus de palets : l'autre joue", _team_to_play() == AI, "")
	left = [0, 0]
	_st_check("manche finie", _team_to_play() == 0, "")
	var r1 := end_points([0.2, 0.5], [0.3, 0.9])
	var r2 := end_points([0.5], [0.1, 0.12, 0.6])
	_st_check("points de la manche", r1 == [PLAYER, 1] and r2 == [AI, 2], str([r1, r2]))
	settings["variant"] = "cible"
	left = [2, 2]
	_last_thrower = PLAYER
	_st_check("cible : on alterne", _team_to_play() == AI, "")

	# D. Aide au lancer : un tir qui finirait hors de la planche y est ramené
	settings["variant"] = "breton"
	settings["level"] = "facile"
	_clear_balls()
	var bad2 := 0
	for i in 40:
		var from := Vector3(randf_range(-0.2, 0.5), randf_range(0.9, 1.4), randf_range(-0.2, 0.2))
		var v3 := Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 5.0), randf_range(-9.0, -4.0))
		var a := _assist(from, v3, false)
		var rp2 := _sim_rest(from, a, R_B, M_B)
		var t3 := _flight_time(from, a, R_B)
		var ok3 := _board_rect().has_point(Vector2(rp2.x, rp2.z)) and _board_rect().has_point(Vector2(from.x + a.x * t3, from.z + a.z * t3))
		if not ok3:
			bad2 += 1
	_st_check("aide au lancer", bad2 == 0, "(%d hors planche après aide)" % bad2)
	settings["level"] = "normal"

	# E. Parties complètes, les trois variantes : l'ordinateur contre un joueur virtuel
	for vv in ["breton", "trous", "cible"]:
		settings["variant"] = vv
		settings["points"] = int(VARIANTS[vv]["default"])
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 900:
			await get_tree().physics_frame
			guard += 1
		var okg := state == State.GAME_OVER and maxi(scores[0], scores[1]) >= int(settings["points"])
		_st_check("partie %s terminée" % vv, okg, "%s en %.0f s" % [str(scores), guard / 90.0])

	# F. Entraînement : une manche se termine
	settings["mode"] = "training"
	for vv in ["breton", "trous", "cible"]:
		settings["variant"] = vv
		_st_bot = true
		start_match()
		var g2 := 0
		while _train_end < 1 and g2 < 90 * 120:
			await get_tree().physics_frame
			g2 += 1
		_st_check("entraînement %s : manche" % vv, _train_end >= 1, "(%d pts en %.0f s)" % [_train_total, g2 / 90.0])
	_st_bot = false

	# G. Lancer humain simulé : maître puis palet, avec l'aide
	settings["mode"] = "ordi"
	settings["variant"] = "breton"
	settings["level"] = "facile"
	start_match()
	await _wait_frames(2)
	_st_check("maître à lancer", state == State.JACK_WAIT and _held != null and _held.team == 0, str(state))
	_throw(Vector3(0.3, 1.2, 0.0), Vector3(0.1, 3.5, -4.5))
	await _wait_rest(90 * 10)
	var jack_ok := _phase == "play" or _jack_fails > 0
	_st_check("maître lancé", jack_ok and _jack != null, "(distance %.1f m)" % (-_jack.pos.z if _jack else -1.0))
	var guard3 := 0
	while state != State.TURN_WAIT and guard3 < 600:
		await get_tree().physics_frame
		guard3 += 1
	_st_check("tour du joueur", state == State.TURN_WAIT and _held != null and _held.team == PLAYER, str(state))
	if state == State.TURN_WAIT:
		_throw(Vector3(0.3, 1.2, 0.0), Vector3(0.0, 3.8, -5.0))
		await _wait_rest(90 * 10)
		_st_check("palet du joueur posé", left[0] == 3, str(left))

	_clear_balls()
	for line in _st_log:
		print("SELFTEST palet ", line)
	print("SELFTEST palet=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())


## Cour de ferme bretonne : arbres, bancs, lampadaires, muret et enseigne au fond.
func _build_decor() -> void:
	var side := tw / 2.0
	var zs := [-2.5, -4.5, -6.5, -8.5]
	for i in zs.size():
		var z: float = zs[i]
		if z < -tlen + 0.5:
			continue
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(2.6 + 0.3 * ((i + int(sx)) % 3), 11 + i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (side + 1.8 + 0.3 * (i % 2)), 0, z)
			_terrain.add_child(t)
	for sx in [-1.0, 1.0]:
		var b := Decor.bush(0.4)
		b.position = Vector3(sx * (side + 0.35), 0, bz)
		_terrain.add_child(b)
	var bench := Decor.bench()
	bench.position = Vector3(-(side + 0.75), 0, -2.2)
	bench.rotation.y = -PI / 2.0
	_terrain.add_child(bench)
	var bench2 := Decor.bench()
	bench2.position = Vector3(side + 0.75, 0, -3.4)
	bench2.rotation.y = PI / 2.0
	_terrain.add_child(bench2)
	for sx in [-1.0, 1.0]:
		var l := Decor.lamp(2.6)
		l.position = Vector3(sx * (side + 0.35), 0, -tlen - 0.05)
		_terrain.add_child(l)
	var wall := BowlingArt.box(Vector3(tw + 3.4, 0.9, 0.25), BowlingArt.mat(Color(0.7, 0.68, 0.62), 0.95), Vector3(0, 0.45, -tlen - 0.35))
	_terrain.add_child(wall)
	_terrain.add_child(BowlingArt.box(Vector3(tw + 3.5, 0.06, 0.3), BowlingArt.mat(Color(0.45, 0.42, 0.37), 0.9), Vector3(0, 0.93, -tlen - 0.35)))
	var sign_node := Decor.neon_sign("PALET", Color(0.3, 0.75, 0.95), 1.4, 0.5)
	sign_node.position = Vector3(0, 1.75, -tlen - 0.4)
	_terrain.add_child(sign_node)
