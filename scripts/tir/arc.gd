class_name ArcGame
extends Node3D
## Tir à l'arc en réalité augmentée. L'arc est dans une main, de l'autre on tient la corde :
## gâchette (ou grip) = on encoche et on tend, on relâche = la flèche part dans l'axe
## main de corde -> main d'arc. Cible à 10, 20 ou 30 m, concours contre l'ordinateur,
## entraînement libre ou cible mobile. Le noeud est aux pieds du joueur ; la cible est à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const GRAVITY := 9.81
const SUBSTEPS := 3
const ARROW_LEN := 0.7
const DRAW_MIN := 0.25
const DRAW_MAX := 0.7
const SPEED_MIN := 24.0
const SPEED_MAX := 62.0
const TARGET_Y := 1.3
const BOSS_EXTRA := 0.14
const SAVE_PATH := "user://arc.cfg"
const PLAYER := 1
const AI := -1
const CLR_PLAYER := Color(0.4, 0.6, 1.0)
const CLR_AI := Color(0.95, 0.4, 0.3)
const MOVE_AMP := 1.6
const MOVE_PERIOD := 5.0
const PER_END := 3
const MOBILE_ARROWS := 10

const LEVELS := {
	"facile": {"title": "Facile", "wind": 0.0, "preview": true, "sigma": 0.17},
	"normal": {"title": "Normal", "wind": 2.0, "preview": false, "sigma": 0.11},
	"expert": {"title": "Expert", "wind": 5.0, "preview": false, "sigma": 0.065},
}

enum State { SETUP, READY, DRAW, FLIGHT, PAUSE, AI_TURN, GAME_OVER }

var settings := {"mode": "ordi", "level": "normal", "dist": 20, "ends": 5, "bow_hand": 0, "music": true}
var state := State.SETUP
var scores := [0, 0]
var _end := 0                  # volée en cours (0..ends-1)
var _left := PER_END           # flèches restantes (joueur)
var _end_pts := 0
var _total_arrows := 0
var _best_end := 0
var _wind := 0.0
var _time := 0.0
var _timer := 0.0
var _pause_next := ""
var _arrows: Array[ArcArrow] = []
var _flying: ArcArrow = null
var _face_r := 0.4
var _tx := 0.0                 # abscisse actuelle de la cible
var _drawer: Hand = null
var _draw_button := ""
var _draw_len := 0.0
var _nocked: ArcArrow = null
var _wind_off := 0.0

var _hands: Array = []
var _scene: Node3D
var _target: Node3D
var _arrow_root: Node3D
var _fx_root: Node3D
var _bow: Node3D
var _bow_string: Array[MeshInstance3D] = []
var _preview: Array[MeshInstance3D] = []
var _flag: Node3D
var _wind_label: Label3D
var _robin: Spectator
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
	_scene = Node3D.new()
	add_child(_scene)
	_arrow_root = Node3D.new()
	add_child(_arrow_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_bow()
	_scoreboard = PingScoreboard.new()
	add_child(_scoreboard)
	_robin = Spectator.new({
		"name": "Robin", "skin": Color(0.9, 0.72, 0.6), "shirt": Color(0.15, 0.45, 0.2),
		"pants": Color(0.35, 0.25, 0.15), "hair": Color(0.5, 0.3, 0.12), "beard": false,
		"hat": true, "hat_color": Color(0.1, 0.35, 0.15),
	})
	add_child(_robin)
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
	_panel.accent = Color(0.95, 0.35, 0.3)
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


func _apply_layout() -> void:
	var d := float(settings["dist"])
	_face_r = 0.2 + 0.01 * d
	_build_range()
	_scoreboard.position = Vector3(1.6, 1.5, -2.2)
	_scoreboard.scale = Vector3.ONE * 1.1
	var face := Vector3(0, 0, 1.0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_robin.position = Vector3(-1.6, 0, -0.6)
	_robin.rotation.y = deg_to_rad(40.0)
	_message.position = Vector3(0, 1.9, -2.5)
	_hint.position = Vector3(0, 1.3, -0.5)


func _grass_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in s:
		for y in s:
			var v := 0.5 + rng.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, Color(0.18 * v * 1.6, 0.5 * v * 1.4, 0.14 * v * 1.5))
	return ImageTexture.create_from_image(img)


func _build_range() -> void:
	for c in _scene.get_children():
		c.queue_free()
	var d := float(settings["dist"])
	var len := d + 6.0
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_texture()
	gm.uv1_scale = Vector3(5, len * 0.6, 1.0)
	gm.roughness = 0.95
	_scene.add_child(BowlingArt.floor_quad(10.0, len, gm, Vector3(0, 0.001, -len / 2.0 + 2.0)))
	# couloir de tir et repères de distance
	var white := BowlingArt.unshaded(Color(1, 1, 1, 0.9))
	for sx in [-1.2, 1.2]:
		_scene.add_child(BowlingArt.box(Vector3(0.05, 0.004, d + 1.0), white, Vector3(sx, 0.004, -(d + 1.0) / 2.0 + 0.5)))
	_scene.add_child(BowlingArt.box(Vector3(2.45, 0.004, 0.06), white, Vector3(0, 0.004, 0.2)))
	for m in [10, 20, 30]:
		if m > d:
			continue
		var lab := BowlingArt.label("%d m" % m, 0.4, Color(1, 1, 1), 8)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(1.8, 0.006, -float(m))
		_scene.add_child(lab)
		_scene.add_child(BowlingArt.box(Vector3(0.5, 0.004, 0.05), white, Vector3(1.8, 0.005, -float(m) + 0.25)))
	# cible
	_target = Node3D.new()
	_target.position = Vector3(0, TARGET_Y, -d)
	_scene.add_child(_target)
	_build_target_face()
	# décor : arbres, haies, banderole
	for i in 6:
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(3.2 + 0.4 * ((i + int(sx)) % 3), 21 + i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (3.4 + 0.5 * (i % 2)), 0, -1.0 - i * (d + 2.0) / 5.0)
			_scene.add_child(t)
	for sx in [-1.0, 1.0]:
		var lamp := Decor.lamp(2.4)
		lamp.position = Vector3(sx * 2.2, 0, -0.3)
		_scene.add_child(lamp)
	var back := BowlingArt.box(Vector3(9.0, 2.0, 0.3), BowlingArt.mat(Color(0.2, 0.35, 0.18), 0.95), Vector3(0, 1.0, -d - 2.5))
	_scene.add_child(back)
	var sign_node := Decor.neon_sign("TIR À L'ARC", Color(1.0, 0.45, 0.3), 1.8, 0.5)
	sign_node.position = Vector3(0, 2.5, -d - 2.3)
	sign_node.scale = Vector3.ONE * (1.0 + d / 20.0)
	_scene.add_child(sign_node)
	# manche à air
	_flag = Node3D.new()
	_flag.position = Vector3(-1.5, 0, -d * 0.5)
	_scene.add_child(_flag)
	_flag.add_child(BowlingArt.cylinder(0.025, 0.03, 2.4, BowlingArt.mat(Color(0.8, 0.8, 0.8), 0.5), Vector3(0, 1.2, 0), 10))
	var sock := BowlingArt.box(Vector3(0.6, 0.12, 0.02), BowlingArt.mat(Color(1.0, 0.45, 0.15), 0.6), Vector3(0.3, 2.3, 0))
	sock.name = "sock"
	_flag.add_child(sock)
	_wind_label = BowlingArt.label("", 0.14, Color(1, 1, 0.8), 6)
	_wind_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_wind_label.position = Vector3(-1.5, 2.8, -d * 0.5)
	_scene.add_child(_wind_label)
	_update_wind_visual()


func _build_target_face() -> void:
	for c in _target.get_children():
		if c is Node3D and not c.has_meta("arrow"):
			c.queue_free()
	# paille et pied
	var straw := BowlingArt.cylinder(_face_r + BOSS_EXTRA, _face_r + BOSS_EXTRA, 0.16, BowlingArt.mat(Color(0.75, 0.6, 0.25), 0.95), Vector3(0, 0, -0.1), 28)
	straw.rotation_degrees = Vector3(90, 0, 0)
	_target.add_child(straw)
	var wood := BowlingArt.mat(Color(0.4, 0.26, 0.14), 0.7)
	for sx in [-1.0, 1.0]:
		_target.add_child(BowlingArt.box(Vector3(0.06, TARGET_Y, 0.06), wood, Vector3(sx * (_face_r * 0.55), -TARGET_Y / 2.0, -0.2)))
	# anneaux : 10 zones de largeur égale, 5 couleurs
	var cols := [Color(0.95, 0.95, 0.92), Color(0.08, 0.08, 0.1), Color(0.15, 0.4, 0.85), Color(0.9, 0.15, 0.15), Color(1.0, 0.82, 0.1)]
	for k in range(10, 0, -1):
		var ci := (k - 1) / 2
		var col: Color = cols[ci]
		if k % 2 == 1:
			col = col.darkened(0.12)
		var disc := BowlingArt.cylinder(_face_r * k / 10.0, _face_r * k / 10.0, 0.004, BowlingArt.mat(col, 0.7), Vector3(0, 0, -0.015 + 0.0016 * (10 - k) * -1.0), 36)
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position.z = -0.012 + 0.0012 * (10 - k)
		_target.add_child(disc)


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


func is_mobile() -> bool:
	return settings["mode"] == "mobile"


func is_contest() -> bool:
	return settings["mode"] == "ordi"


func show_setup() -> void:
	state = State.SETUP
	_cancel_draw()
	_clear_arrows()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Tir à l'arc", "Victoires : %d   ·   record volée : %d   ·   cible mobile : %d" % [_stat("wins"), _stat("best_end"), _stat("best_mobile")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Concours", "width": 0.22, "selected": settings["mode"] == "ordi"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
		{"id": "mode_mobile", "text": "Cible mobile", "width": 0.26, "selected": settings["mode"] == "mobile"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Distance", [
		{"id": "dist_10", "text": "10 m", "width": 0.18, "selected": settings["dist"] == 10},
		{"id": "dist_20", "text": "20 m", "width": 0.18, "selected": settings["dist"] == 20},
		{"id": "dist_30", "text": "30 m", "width": 0.18, "selected": settings["dist"] == 30},
	])
	_panel.add_row("Volées", [
		{"id": "ends_3", "text": "3", "width": 0.14, "selected": settings["ends"] == 3},
		{"id": "ends_5", "text": "5", "width": 0.14, "selected": settings["ends"] == 5},
	])
	_panel.add_row("Arc en main", [
		{"id": "hand_0", "text": "Gauche", "width": 0.2, "selected": settings["bow_hand"] == 0},
		{"id": "hand_1", "text": "Droite", "width": 0.2, "selected": settings["bow_hand"] == 1},
	])
	_panel.add_row("", [
		{"id": "menu", "text": "Retour", "width": 0.2, "color": Color(0.35, 0.35, 0.4)},
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
	_panel.add_row("", [{"id": "menu", "text": "Retour au tir", "width": 0.34, "color": Color(0.35, 0.35, 0.4)}])
	_open_panel()


func show_game_over(summary: String) -> void:
	_panel_page = "over"
	_panel.clear()
	_panel.set_title("Terminé", summary)
	_panel.add_row("", [
		{"id": "settings", "text": "Réglages", "width": 0.22},
		{"id": "restart", "text": "Rejouer", "width": 0.26, "color": Color(0.15, 0.6, 0.25)},
		{"id": "menu", "text": "Retour", "width": 0.18, "color": Color(0.35, 0.35, 0.4)},
	])
	_open_panel()


func _open_panel() -> void:
	_cancel_draw()
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)
	_bow.visible = false


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
	elif id.begins_with("dist_"):
		settings["dist"] = int(id.substr(5))
	elif id.begins_with("ends_"):
		settings["ends"] = int(id.substr(5))
	elif id.begins_with("hand_"):
		settings["bow_hand"] = int(id.substr(5))
	match id:
		"play", "restart":
			_close_panel()
			start_match()
			return
		"resume":
			_close_panel()
			_bow.visible = true
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


# ================================================================ l'arc

func _build_bow() -> void:
	_bow = Node3D.new()
	add_child(_bow)
	var wood := BowlingArt.mat(Color(0.5, 0.3, 0.12), 0.45)
	var pts: Array[Vector3] = []
	for i in 13:
		var t := (i - 6) / 6.0
		pts.append(Vector3(0, t * 0.62, 0.14 * t * t - 0.0))
	for i in 12:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := BowlingArt.box(Vector3(0.016, 0.016, a.distance_to(b)), wood, (a + b) / 2.0)
		seg.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT).scaled(Vector3(1, 1, 1))
		_bow.add_child(seg)
		seg.position = (a + b) / 2.0
	_bow.add_child(BowlingArt.box(Vector3(0.026, 0.12, 0.03), BowlingArt.mat(Color(0.1, 0.07, 0.05), 0.6), Vector3(0, 0, 0)))
	for i in 2:
		var s := BowlingArt.box(Vector3(0.003, 0.003, 1.0), BowlingArt.unshaded(Color(0.95, 0.95, 0.85)), Vector3.ZERO)
		_bow.add_child(s)
		_bow_string.append(s)
	for i in 24:
		var dot := BowlingArt.sphere(0.012, BowlingArt.unshaded(Color(1, 1, 0.6, 0.8)), Vector3.ZERO, 6)
		dot.visible = false
		add_child(dot)
		_preview.append(dot)
	_bow.visible = false


func _hand_of(role: String) -> Hand:
	# role "bow" : main de l'arc ; "draw" : main de la corde
	if _hands.size() < 2:
		return null
	var bi: int = settings["bow_hand"]
	return _hands[bi] if role == "bow" else _hands[1 - bi]


func _hpos(h: Hand) -> Vector3:
	return (global_transform.affine_inverse() * h.global_transform).origin


func _hbasis(h: Hand) -> Basis:
	return (global_transform.affine_inverse() * h.global_transform).basis


func _set_seg(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.002:
		m.visible = false
		return
	m.visible = true
	m.position = (a + b) / 2.0
	m.basis = Basis.looking_at((b - a).normalized(), Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT).scaled(Vector3(1, 1, len))


## Met l'arc et la corde à jour selon les mains.
func _update_bow() -> void:
	var bh := _hand_of("bow")
	if bh == null or not is_instance_valid(bh):
		return
	_bow.visible = state != State.SETUP and state != State.GAME_OVER and not _panel.visible
	var bpos := _hpos(bh)
	var bb := _hbasis(bh)
	var dir := -bb.z
	var tip_top := Vector3(0, 0.62, 0.14)
	var tip_bot := Vector3(0, -0.62, 0.14)
	var nock_local := Vector3(0, 0, 0.14)
	if state == State.DRAW and _drawer != null and is_instance_valid(_drawer):
		var d := bpos - _hpos(_drawer)
		_draw_len = d.length()
		if _draw_len > 0.05:
			dir = d / _draw_len
		nock_local = Vector3(0, 0, clampf(_draw_len, 0.0, DRAW_MAX))
	var up := bb.y
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.UP
	_bow.transform = Transform3D(Basis.looking_at(dir, up), bpos)
	_set_seg(_bow_string[0], tip_top, nock_local)
	_set_seg(_bow_string[1], nock_local, tip_bot)
	if _nocked != null:
		var tail_local := nock_local
		var tip_local := nock_local + Vector3(0, 0, -ARROW_LEN)
		_nocked.node.transform = Transform3D(_bow.transform.basis, _bow.transform * tip_local)
		_nocked.pos = _bow.transform * tip_local
		_nocked.node.visible = true
		if tail_local.z < 0.0:
			_nocked.node.visible = false
	_update_preview(dir)


func _update_preview(dir: Vector3) -> void:
	for p in _preview:
		p.visible = false
	if state != State.DRAW or not bool(LEVELS[settings["level"]]["preview"]) or _draw_len < DRAW_MIN:
		return
	var bpos := _bow.position
	var start := bpos + dir * 0.2
	var path := simulate_path(start, dir * _speed_for(_draw_len), 0.0, 24, 0.035)
	for i in path.size():
		_preview[i].position = path[i]
		_preview[i].visible = true


# ================================================================ flèches

func _speed_for(draw: float) -> float:
	var f := clampf((draw - DRAW_MIN) / (DRAW_MAX - DRAW_MIN), 0.0, 1.0)
	return lerpf(SPEED_MIN, SPEED_MAX, f)


func _new_arrow(team: int) -> ArcArrow:
	var a := ArcArrow.new()
	a.team = team
	var n := Node3D.new()
	var col := CLR_PLAYER if team == PLAYER else CLR_AI
	var shaft := BowlingArt.cylinder(0.004, 0.004, ARROW_LEN, BowlingArt.mat(Color(0.85, 0.7, 0.4), 0.5), Vector3(0, 0, ARROW_LEN / 2.0), 6)
	shaft.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(shaft)
	var tip := BowlingArt.cylinder(0.0, 0.007, 0.05, BowlingArt.mat(Color(0.7, 0.7, 0.75), 0.3, 0.8), Vector3(0, 0, -0.02), 6)
	tip.rotation_degrees = Vector3(-90, 0, 0)
	n.add_child(tip)
	for k in 3:
		var f := BowlingArt.box(Vector3(0.002, 0.03, 0.09), BowlingArt.mat(col, 0.6), Vector3(0, 0, ARROW_LEN - 0.07))
		f.rotation_degrees = Vector3(0, 0, k * 60.0)
		n.add_child(f)
	_arrow_root.add_child(n)
	a.node = n
	_arrows.append(a)
	return a


func _clear_arrows() -> void:
	for a in _arrows:
		if a.node and is_instance_valid(a.node):
			a.node.queue_free()
	_arrows.clear()
	_flying = null
	_nocked = null


func _wind_vec() -> Vector3:
	return Vector3(_wind, 0, 0)


## Trajectoire simulée : liste de points (pour l'aperçu), pas de temps fixe.
func simulate_path(start: Vector3, vel: Vector3, wind: float, count: int, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var p := start
	var v := vel
	var dt := 0.005
	var acc := 0.0
	var n := 0
	var total := 0
	while n < count and total < 2000:
		v += Vector3(wind, -GRAVITY, 0) * dt
		v *= 1.0 - 0.02 * dt
		p += v * dt
		acc += dt
		total += 1
		if acc >= step:
			acc = 0.0
			out.append(p)
			n += 1
		if p.y < 0.0 or p.z < -float(settings["dist"]) - 3.0:
			break
	return out


## Où la flèche coupe le plan de la cible (sans cible mobile) : renvoie Vector3 ou null.
func predict_hit(start: Vector3, vel: Vector3, wind: float) -> Variant:
	var plane := -float(settings["dist"])
	var p := start
	var v := vel
	var dt := 0.004
	for i in 2500:
		var pv := p
		v += Vector3(wind, -GRAVITY, 0) * dt
		v *= 1.0 - 0.02 * dt
		p += v * dt
		if pv.z > plane and p.z <= plane:
			var t := (pv.z - plane) / (pv.z - p.z)
			return pv.lerp(p, t)
		if p.y < 0.0:
			return null
	return null


## Direction qui touche `target` malgré la chute et le vent.
func aim_dir(from: Vector3, target: Vector3, speed: float, wind: float) -> Vector3:
	var aim := target
	for i in 6:
		var dir := (aim - from).normalized()
		var hit = predict_hit(from, dir * speed, wind)
		if hit == null:
			aim += Vector3(0, 0.5, 0)
			continue
		aim += target - (hit as Vector3)
	return (aim - from).normalized()


func _fire(from: Vector3, dir: Vector3, speed: float, team: int) -> ArcArrow:
	var a: ArcArrow = _nocked if (_nocked != null and team == PLAYER) else _new_arrow(team)
	_nocked = null
	a.pos = from
	a.vel = dir.normalized() * speed
	a.flying = true
	a.stuck = false
	a.life = 0.0
	a.node.visible = true
	_flying = a
	state = State.FLIGHT
	if team == PLAYER:
		_left -= 1
		_total_arrows += 1
	_hint.text = ""
	Sound.play_at("whoosh", to_global(from), -2.0, 0.08)
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.6, 0.1)
	return a


func target_x_at(t: float) -> float:
	if not is_mobile():
		return 0.0
	return MOVE_AMP * sin(TAU * t / MOVE_PERIOD)


## Points d'un impact : 10 zones de largeur égale, 0 hors de la cible.
static func ring_points(r: float, face_r: float) -> int:
	if r >= face_r:
		return 0
	return 10 - int(floor(10.0 * r / face_r))


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
	_time += delta
	_tx = target_x_at(_time)
	_target.position.x = _tx
	_update_flag(delta)
	if state == State.READY or state == State.DRAW or state == State.FLIGHT:
		if not _st_bot:
			_update_bow()
	match state:
		State.READY:
			if _st_bot:
				_bot_shoot()
		State.FLIGHT:
			if _flying != null:
				var h := delta / SUBSTEPS
				for i in SUBSTEPS:
					_step_arrow(_flying, h)
					if not _flying.flying:
						break
				if _flying != null and not _flying.flying:
					_after_arrow()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()
		State.AI_TURN:
			_timer -= delta
			if _timer <= 0.0:
				_ai_volley()


func _step_arrow(a: ArcArrow, dt: float) -> void:
	var pv := a.pos
	a.vel += (Vector3(_wind, -GRAVITY, 0)) * dt
	a.vel *= 1.0 - 0.02 * dt
	a.pos += a.vel * dt
	a.life += dt
	var plane := -float(settings["dist"])
	if pv.z > plane and a.pos.z <= plane:
		var t := (pv.z - plane) / (pv.z - a.pos.z)
		var hit := pv.lerp(a.pos, t)
		var rel := Vector2(hit.x - _tx, hit.y - TARGET_Y)
		var r := rel.length()
		if r <= _face_r + BOSS_EXTRA:
			a.points = ring_points(r, _face_r)
			_stick(a, hit, true)
			return
	if a.pos.y <= 0.0:
		a.pos.y = 0.0
		a.points = 0
		_stick(a, a.pos, false)
		return
	if a.pos.z < plane - 6.0:
		a.points = 0
		a.flying = false
		a.stuck = true
		a.node.visible = false
		return
	a.node.transform = Transform3D(Basis.looking_at(a.vel.normalized(), Vector3.UP), a.pos)


func _stick(a: ArcArrow, at: Vector3, in_target: bool) -> void:
	a.flying = false
	a.stuck = true
	var dir := a.vel.normalized()
	var depth := 0.12 if in_target else 0.06
	var tip := at + dir * depth
	a.in_target = in_target
	if in_target:
		a.node.reparent(_target, false)
		a.node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), tip - _target.position)
	else:
		a.node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), tip)
	var rel_pos := at
	if in_target:
		_float_score(a.points, Vector3(at.x, at.y + 0.18, at.z + 0.1), a.team)
	Sound.play_at("pet_land", to_global(rel_pos), 0.0 if in_target else -8.0, 0.08)


func _float_score(pts: int, pos: Vector3, team: int) -> void:
	var col := Color(1.0, 0.85, 0.2) if pts >= 9 else (Color(0.5, 1, 0.5) if pts > 0 else Color(1, 0.5, 0.4))
	var l := BowlingArt.neon_label(str(pts) if pts > 0 else "×", 0.22, col)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	_fx_root.add_child(l)
	var tw_ := create_tween()
	tw_.set_parallel(true)
	tw_.tween_property(l, "position:y", pos.y + 0.4, 1.4)
	tw_.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tw_.chain().tween_callback(l.queue_free)


func _after_arrow() -> void:
	var a := _flying
	_flying = null
	if a.team == PLAYER:
		_end_pts += a.points
		if is_contest():
			scores[0] += a.points
		elif is_mobile():
			scores[0] += a.points
		_announce(("%d !" % a.points) if a.points > 0 else "Raté", Color(1.0, 0.85, 0.2) if a.points >= 9 else (Color(0.5, 1, 0.5) if a.points > 0 else Color(1, 0.5, 0.4)), 1.4)
		if a.points >= 9 and not _st_bot:
			_robin.react("carreau")
		elif a.points == 0 and not _st_bot:
			_robin.react("oups")
	_update_scoreboard()
	state = State.PAUSE
	_timer = 0.9 if not _selftest else 0.05
	_pause_next = "next_arrow"


func _after_pause() -> void:
	match _pause_next:
		"next_arrow":
			_next_arrow()
		"end_done":
			_finish_end()
		"retrieve":
			_retrieve_and_continue()


func _next_arrow() -> void:
	if is_mobile():
		if _total_arrows >= MOBILE_ARROWS:
			_end_mobile()
			return
		_begin_ready()
		return
	if _left > 0:
		_begin_ready()
		return
	# volée terminée
	if is_training():
		_best_end = maxi(_best_end, _end_pts)
		if _end_pts > _stat("best_end"):
			_save.set_value("records", "best_end", _end_pts)
			_save.save(SAVE_PATH)
		_announce("Volée : %d" % _end_pts, Color(1, 0.8, 0.2), 2.0)
		_update_scoreboard()
		state = State.PAUSE
		_pause_next = "retrieve"
		_timer = 2.2 if not _selftest else 0.05
		return
	# concours : l'adversaire tire
	state = State.AI_TURN
	_timer = 1.2 if not _selftest else 0.05
	_announce("Robin tire…", CLR_AI, 1.2)


func _retrieve_and_continue() -> void:
	_clear_arrows()
	_end_pts = 0
	_left = PER_END
	if is_contest():
		_end += 1
		if _end >= int(settings["ends"]):
			_end_contest()
			return
		_new_wind()
	_begin_ready()


func _finish_end() -> void:
	pass


func _begin_ready() -> void:
	state = State.READY
	if not _st_bot:
		_hint.text = "Gâchette/grip de la main libre : tends la corde,\nvise, relâche pour tirer"
	_update_scoreboard()


# ---------------------------------------------------------------- adversaire

func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _ai_volley() -> void:
	var sg: float = float(LEVELS[settings["level"]]["sigma"]) * (_face_r / 0.4)
	var total := 0
	var d := float(settings["dist"])
	for i in PER_END:
		var off := Vector2(_gauss(), _gauss()) * sg
		var hit := Vector3(_tx + off.x, TARGET_Y + off.y, -d)
		var r := off.length()
		var a := _new_arrow(AI)
		a.vel = Vector3(0, 0, -50.0)
		var pts := ring_points(r, _face_r)
		a.points = pts
		total += pts
		a.flying = false
		a.stuck = true
		a.in_target = r <= _face_r + BOSS_EXTRA
		var dir := Vector3(off.x * 0.01, -0.012, -1.0).normalized()
		if a.in_target:
			a.node.reparent(_target, false)
			a.node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(off.x, off.y, 0.0) + dir * 0.12)
		else:
			a.node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(hit.x, 0.05, hit.z))
		Sound.play_at("pet_land", to_global(hit), -4.0, 0.1)
	scores[1] += total
	_announce("Robin : %d" % total, CLR_AI, 2.0)
	_update_scoreboard()
	if not _st_bot:
		_robin.react("pointe" if total >= 24 else "oups")
	state = State.PAUSE
	_pause_next = "retrieve"
	_timer = 2.4 if not _selftest else 0.05


func _new_wind() -> void:
	var w: float = LEVELS[settings["level"]]["wind"]
	_wind = randf_range(-w, w)
	_update_wind_visual()


func _update_wind_visual() -> void:
	if _wind_label == null:
		return
	if absf(_wind) < 0.05:
		_wind_label.text = ""
	else:
		_wind_label.text = "Vent %s %d" % ["→" if _wind > 0 else "←", int(round(absf(_wind) * 10.0))]


func _update_flag(delta: float) -> void:
	if _flag == null or not is_instance_valid(_flag):
		return
	var sock := _flag.get_node_or_null("sock") as Node3D
	if sock:
		var target_rot := clampf(-_wind * 0.18, -1.2, 1.2)
		sock.rotation.z = lerpf(sock.rotation.z, target_rot + 0.05 * sin(_time * 5.0), minf(1.0, delta * 3.0))
		sock.position.x = 0.3 * (1.0 if _wind >= 0 else -1.0)


# ---------------------------------------------------------------- déroulement

func start_match() -> void:
	_clear_arrows()
	_cancel_draw()
	scores = [0, 0]
	_end = 0
	_left = PER_END
	_end_pts = 0
	_total_arrows = 0
	_best_end = 0
	_time = 0.0
	_new_wind()
	if not is_contest():
		_wind = 0.0 if is_training() else _wind
		_update_wind_visual()
	_begin_ready()


func _end_contest() -> void:
	state = State.GAME_OVER
	var win: bool = scores[0] > scores[1]
	var summary := "Vous %d – %d Robin" % [scores[0], scores[1]]
	if scores[0] == scores[1]:
		summary = "Égalité %d – %d" % [scores[0], scores[1]]
	elif win:
		_bump_stat("wins")
		_scoreboard.celebrate("win")
		_robin.say("win", true)
	else:
		_scoreboard.celebrate("lose")
	_announce(summary, Color(1, 0.8, 0.2), 3.0)
	_update_scoreboard()
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _end_mobile() -> void:
	state = State.GAME_OVER
	var pts: int = scores[0]
	if pts > _stat("best_mobile"):
		_save.set_value("records", "best_mobile", pts)
		_save.save(SAVE_PATH)
	_announce("%d points sur %d flèches" % [pts, MOBILE_ARROWS], Color(1, 0.8, 0.2), 3.0)
	_scoreboard.celebrate("win")
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over("%d points sur %d flèches" % [pts, MOBILE_ARROWS])


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
		_scoreboard.set_data("TIR À L'ARC · ENTRAÎNEMENT", ["VOLÉE", "RECORD"], [_end_pts, maxi(_stat("best_end"), _best_end)], 0, "Flèches restantes dans la volée : %d" % _left)
	elif is_mobile():
		_scoreboard.set_data("TIR À L'ARC · CIBLE MOBILE", ["POINTS", "RECORD"], [scores[0], maxi(_stat("best_mobile"), scores[0])], 0, "Flèche %d / %d" % [mini(_total_arrows + 1, MOBILE_ARROWS), MOBILE_ARROWS])
	else:
		_scoreboard.set_data("TIR À L'ARC · %s" % lvl, ["VOUS", "ROBIN"], scores, PLAYER if state != State.AI_TURN else AI, "Volée %d / %d  ·  flèches : %d  ·  %d m" % [mini(_end + 1, int(settings["ends"])), int(settings["ends"]), _left, int(settings["dist"])])


# ================================================================ entrées

func _try_draw(hand: Hand, button: String) -> void:
	if state != State.READY or _drawer != null:
		return
	if hand != _hand_of("draw"):
		return
	_drawer = hand
	_draw_button = button
	_draw_len = 0.0
	_nocked = _new_arrow(PLAYER)
	_nocked.node.visible = false
	state = State.DRAW
	_hint.text = ""
	hand.buzz(0.3, 0.05)


func _release_draw(hand: Hand) -> void:
	if state != State.DRAW or hand != _drawer:
		return
	var bh := _hand_of("bow")
	var bp := _hpos(bh)
	var dp := _hpos(_drawer)
	_loose(bp, dp)


## Relâche la corde : mains de l'arc et de la corde en positions du jeu.
func _loose(bow_pos: Vector3, draw_pos: Vector3) -> bool:
	var d := bow_pos - draw_pos
	var length := d.length()
	_drawer = null
	_draw_button = ""
	if length < DRAW_MIN:
		# Tir à vide : on remet la flèche
		if _nocked != null:
			_arrows.erase(_nocked)
			_nocked.node.queue_free()
			_nocked = null
		state = State.READY
		_hint.text = "Tends plus la corde !"
		return false
	var dir := d / length
	_fire(bow_pos + dir * 0.15, dir, _speed_for(length), PLAYER)
	return true


func _cancel_draw() -> void:
	_drawer = null
	_draw_button = ""
	if _nocked != null:
		_arrows.erase(_nocked)
		if _nocked.node and is_instance_valid(_nocked.node):
			_nocked.node.queue_free()
		_nocked = null
	if state == State.DRAW:
		state = State.READY


func on_button_pressed(hand: Hand, button: String) -> void:
	if _panel.visible:
		if button == "trigger_click":
			var target := hand.pointed_object()
			if target:
				hand.buzz(0.3, 0.04)
				_panel.click(target)
		elif button == "by_button" and _panel_page == "pause":
			_close_panel()
			_bow.visible = true
		return
	if button == "by_button":
		show_pause()
		return
	if button == "trigger_click" or button == "grip_click":
		_try_draw(hand, button)


func on_button_released(hand: Hand, button: String) -> void:
	if button == _draw_button and hand == _drawer:
		_release_draw(hand)


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["ordi", "training", "mobile"]:
		settings["mode"] = "ordi"
	if int(settings["dist"]) not in [10, 20, 30]:
		settings["dist"] = 20
	if int(settings["ends"]) not in [3, 5]:
		settings["ends"] = 5
	if int(settings["bow_hand"]) not in [0, 1]:
		settings["bow_hand"] = 0


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


## Le joueur virtuel : vise le centre (avec une erreur) et tire.
func _bot_shoot() -> void:
	var from := Vector3(0.3, 1.45, -0.1)
	var d := float(settings["dist"])
	var speed := SPEED_MAX
	var sg := 0.08 * (_face_r / 0.4)
	var tf := 0.35
	var target := Vector3(target_x_at(_time + tf) + _gauss() * sg, TARGET_Y + _gauss() * sg, -d)
	if is_mobile():
		for i in 2:
			var dir0 := aim_dir(from, target, speed, _wind)
			var hit = predict_hit(from, dir0 * speed, _wind)
			if hit != null:
				tf = (from.z - (hit as Vector3).z) / maxf(0.1, -dir0.z * speed)
			target.x = target_x_at(_time + tf) + _gauss() * sg
	var dir := aim_dir(from, target, speed, _wind)
	_fire(from, dir, speed, PLAYER)


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["dist"] = 20
	settings["ends"] = 3
	_apply_layout()
	_st_bot = false
	state = State.SETUP

	# A. Barème : 10 zones de largeur égale
	var fr := _face_r
	_st_check("barème", ring_points(0.0, fr) == 10 and ring_points(fr * 0.05, fr) == 10 and ring_points(fr * 0.15, fr) == 9 and ring_points(fr * 0.55, fr) == 5 and ring_points(fr * 0.95, fr) == 1 and ring_points(fr * 1.1, fr) == 0, "")

	# B. Visée : la direction calculée touche le centre malgré la chute
	var from := Vector3(0.3, 1.45, -0.1)
	var bad := 0
	var worst := 0.0
	for i in 20:
		var tgt := Vector3(randf_range(-0.3, 0.3), TARGET_Y + randf_range(-0.3, 0.3), -20.0)
		var w := randf_range(-4.0, 4.0)
		var sp := randf_range(40.0, 62.0)
		var dir := aim_dir(from, tgt, sp, w)
		var hit = predict_hit(from, dir * sp, w)
		if hit == null:
			bad += 1
			continue
		var err := (hit as Vector3).distance_to(tgt)
		worst = maxf(worst, err)
		if err > 0.03:
			bad += 1
	_st_check("visée balistique", bad == 0, "(pire écart %.3f m, %d ratés)" % [worst, bad])

	# C. La chute et le vent déplacent bien la flèche
	var straight := (Vector3(0, TARGET_Y, -20.0) - from).normalized()
	var h0 = predict_hit(from, straight * 50.0, 0.0)
	var h1 = predict_hit(from, straight * 50.0, 5.0)
	_st_check("chute de la flèche", h0 != null and (h0 as Vector3).y < TARGET_Y - 0.1, "(%.2f m sous le centre)" % (TARGET_Y - (h0 as Vector3).y if h0 != null else -1.0))
	_st_check("effet du vent", h0 != null and h1 != null and (h1 as Vector3).x - (h0 as Vector3).x > 0.1, "")

	# D. Tir réel : flèche visée au centre = 9 ou 10 ; flèche à côté = 0
	_wind = 0.0
	_left = 3
	_total_arrows = 0
	scores = [0, 0]
	_time = 0.0
	state = State.READY
	var dirc := aim_dir(from, Vector3(0, TARGET_Y, -20.0), SPEED_MAX, 0.0)
	var a1 := _fire(from, dirc, SPEED_MAX, PLAYER)
	await _wait_frames(90)
	_st_check("flèche au centre", a1.stuck and a1.in_target and a1.points >= 9, "(%d pts)" % a1.points)
	state = State.READY
	var dirm := aim_dir(from, Vector3(0, TARGET_Y + 2.0, -20.0), SPEED_MAX, 0.0)
	var a2 := _fire(from, dirm, SPEED_MAX, PLAYER)
	await _wait_frames(120)
	_st_check("flèche à côté", a2.stuck and a2.points == 0, "(%d pts)" % a2.points)
	state = State.READY
	var offp := _face_r * 0.55
	var dirp := aim_dir(from, Vector3(offp, TARGET_Y, -20.0), SPEED_MAX, 0.0)
	var a3 := _fire(from, dirp, SPEED_MAX, PLAYER)
	await _wait_frames(90)
	_st_check("flèche à mi-rayon", a3.in_target and a3.points >= 4 and a3.points <= 6, "(%d pts)" % a3.points)

	# E. Tension de corde : tir à vide ignoré, vrai tir parti dans l'axe
	_clear_arrows()
	_left = 3
	state = State.READY
	_nocked = _new_arrow(PLAYER)
	state = State.DRAW
	var dry := _loose(Vector3(0.3, 1.4, -0.3), Vector3(0.3, 1.4, -0.3 + DRAW_MIN * 0.5))
	_st_check("tir à vide ignoré", not dry and state == State.READY and _left == 3, "")
	_nocked = _new_arrow(PLAYER)
	state = State.DRAW
	var bow_p := Vector3(0.3, 1.4, -0.3)
	var draw_p := bow_p + Vector3(0.0, 0.0, 0.6)
	var fired := _loose(bow_p, draw_p)
	_st_check("tir réel", fired and state == State.FLIGHT and _flying != null and _flying.vel.z < -30.0 and _left == 2, "")
	await _wait_frames(120)
	_clear_arrows()

	# F. Parties complètes : concours (chaque niveau), entraînement, cible mobile
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		settings["mode"] = "ordi"
		settings["ends"] = 3
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 400:
			await get_tree().physics_frame
			guard += 1
		_st_check("concours %s terminé" % lv, state == State.GAME_OVER and scores[0] > 0 and scores[1] > 0, "%s en %.0f s" % [str(scores), guard / 90.0])
	settings["level"] = "normal"
	settings["mode"] = "mobile"
	_st_bot = true
	start_match()
	var g2 := 0
	while state != State.GAME_OVER and g2 < 90 * 400:
		await get_tree().physics_frame
		g2 += 1
	_st_check("cible mobile terminée", state == State.GAME_OVER and _total_arrows == MOBILE_ARROWS and scores[0] > 0, "(%d pts en %.0f s)" % [scores[0], g2 / 90.0])
	settings["mode"] = "training"
	_st_bot = true
	start_match()
	var g3 := 0
	while _best_end == 0 and g3 < 90 * 200:
		await get_tree().physics_frame
		g3 += 1
	_st_check("entraînement : une volée", _best_end > 0, "(%d pts)" % _best_end)
	_st_bot = false
	state = State.SETUP
	_clear_arrows()

	for line in _st_log:
		print("SELFTEST arc ", line)
	print("SELFTEST arc=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
