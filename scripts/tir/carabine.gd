class_name CarabineGame
extends Node3D
## Carabine à plomb en réalité augmentée. La carabine suit la main de tir ; si l'autre main est
## placée devant (comme pour soutenir le fût), on vise le long de la ligne main -> main, ce qui est
## bien plus stable. Gâchette = un plomb. Trois jeux : concours contre Robin sur cible papier,
## entraînement, et stand de foire (boîtes de conserve, canards, cible bonus).
## Le noeud est aux pieds du joueur ; les cibles sont à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const GRAVITY := 9.81
const PELLET_SPEED := 150.0
const TARGET_Y := 1.3
const SAVE_PATH := "user://carabine.cfg"
const PLAYER := 1
const AI := -1
const CLR_PLAYER := Color(0.4, 0.7, 1.0)
const CLR_AI := Color(0.95, 0.5, 0.3)
const PER_SERIES := 5
const SHOT_GAP := 0.3
const GALLERY_D := 8.0
const GALLERY_TIME := 60.0
const MUZZLE := 0.7

const LEVELS := {
	"facile": {"title": "Facile", "dot": true, "sigma": 0.40, "speed": 0.7, "size": 1.2},
	"normal": {"title": "Normal", "dot": false, "sigma": 0.28, "speed": 1.0, "size": 1.0},
	"expert": {"title": "Expert", "dot": false, "sigma": 0.18, "speed": 1.4, "size": 0.8},
}

enum State { SETUP, READY, FLIGHT, PAUSE, AI_TURN, PLAY, GAME_OVER }


class Pellet extends RefCounted:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var team := 1
	var node: MeshInstance3D
	var alive := true
	var points := 0
	var life := 0.0


class GItem extends RefCounted:
	var kind := "can"
	var node: Node3D
	var x := 0.0
	var y := 1.0
	var vx := 0.0
	var r := 0.1
	var pts := 5
	var alive := true
	var timer := 0.0
	var span := 2.4


var settings := {"mode": "ordi", "level": "normal", "dist": 10, "series": 3, "hand": 1, "music": true}
var state := State.SETUP
var scores := [0, 0]
var _series := 0
var _left := PER_SERIES
var _series_pts := 0
var _best_series := 0
var _total_shots := 0
var _time := 0.0
var _timer := 0.0
var _cd := 0.0
var _pause_next := ""
var _face_r := 0.3
var _gallery_time := GALLERY_TIME
var _gtime := 0.0
var _last_sec := -1
var _pellets: Array[Pellet] = []
var _marks: Array[Node3D] = []
var _gitems: Array[GItem] = []
var _last_points := 0

var _hands: Array = []
var _scene: Node3D
var _target: Node3D
var _fx_root: Node3D
var _gun: Node3D
var _dot: MeshInstance3D
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
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_gun()
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
	_panel.accent = Color(0.3, 0.65, 0.95)
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


func is_gallery() -> bool:
	return settings["mode"] == "gallery"


func is_training() -> bool:
	return settings["mode"] == "training"


func is_contest() -> bool:
	return settings["mode"] == "ordi"


func _level() -> Dictionary:
	return LEVELS[settings["level"]]


func _plane_z() -> float:
	return -GALLERY_D if is_gallery() else -float(settings["dist"])


func _apply_layout() -> void:
	_face_r = 0.25 + 0.012 * float(settings["dist"])
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
	rng.seed = 17
	for x in s:
		for y in s:
			var v := 0.5 + rng.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, Color(0.2 * v * 1.6, 0.48 * v * 1.4, 0.15 * v * 1.5))
	return ImageTexture.create_from_image(img)


func _build_range() -> void:
	for c in _scene.get_children():
		c.queue_free()
	_gitems.clear()
	_marks.clear()
	var d := -_plane_z()
	var len := d + 6.0
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_texture()
	gm.uv1_scale = Vector3(5, len * 0.6, 1.0)
	gm.roughness = 0.95
	_scene.add_child(BowlingArt.floor_quad(10.0, len, gm, Vector3(0, 0.001, -len / 2.0 + 2.0)))
	var white := BowlingArt.unshaded(Color(1, 1, 1, 0.9))
	_scene.add_child(BowlingArt.box(Vector3(2.45, 0.004, 0.06), white, Vector3(0, 0.004, 0.2)))
	for sx in [-1.2, 1.2]:
		_scene.add_child(BowlingArt.box(Vector3(0.05, 0.004, d + 1.0), white, Vector3(sx, 0.004, -(d + 1.0) / 2.0 + 0.5)))
	for i in 6:
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(3.2 + 0.4 * ((i + int(sx)) % 3), 41 + i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (3.6 + 0.5 * (i % 2)), 0, -1.0 - i * (d + 2.0) / 5.0)
			_scene.add_child(t)
	for sx in [-1.0, 1.0]:
		var lamp := Decor.lamp(2.4)
		lamp.position = Vector3(sx * 2.2, 0, -0.3)
		_scene.add_child(lamp)
	# butte de tir derrière la cible
	_scene.add_child(BowlingArt.box(Vector3(9.0, 2.6, 0.5), BowlingArt.mat(Color(0.35, 0.28, 0.18), 0.95), Vector3(0, 1.3, -d - 2.6)))
	if is_gallery():
		_build_gallery()
		_target = null
	else:
		_target = Node3D.new()
		_target.position = Vector3(0, TARGET_Y, -d)
		_scene.add_child(_target)
		_build_target_face()
		var sign_node := Decor.neon_sign("CARABINE À PLOMB", Color(0.4, 0.75, 1.0), 1.8, 0.5)
		sign_node.position = Vector3(0, 2.7, -d - 2.3)
		sign_node.scale = Vector3.ONE * (1.0 + d / 25.0)
		_scene.add_child(sign_node)


func _build_target_face() -> void:
	var board := _face_r + 0.14
	_target.add_child(BowlingArt.box(Vector3(board * 2.0, board * 2.0, 0.02), BowlingArt.mat(Color(0.9, 0.86, 0.74), 0.9), Vector3(0, 0, -0.03)))
	_target.add_child(BowlingArt.box(Vector3(0.06, TARGET_Y, 0.06), BowlingArt.mat(Color(0.4, 0.26, 0.14), 0.7), Vector3(0, -TARGET_Y / 2.0 - board * 0.5, -0.06)))
	for k in range(10, 0, -1):
		var black := k >= 4
		var col := Color(0.06, 0.06, 0.07) if black else Color(0.95, 0.93, 0.88)
		if k % 2 == 1:
			col = col.lightened(0.14) if black else col.darkened(0.1)
		var rr := _face_r * k / 10.0
		var disc := BowlingArt.cylinder(rr, rr, 0.004, BowlingArt.mat(col, 0.8), Vector3.ZERO, 36)
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position.z = -0.012 + 0.0012 * (10 - k)
		_target.add_child(disc)


func _build_gallery() -> void:
	var gz := -GALLERY_D
	var red := BowlingArt.mat(Color(0.75, 0.15, 0.15), 0.7)
	var cream := BowlingArt.mat(Color(0.95, 0.9, 0.8), 0.7)
	var dark := BowlingArt.mat(Color(0.18, 0.12, 0.1), 0.9)
	_scene.add_child(BowlingArt.box(Vector3(7.0, 3.0, 0.1), dark, Vector3(0, 1.5, gz - 0.7)))
	for i in 14:
		var stripe := BowlingArt.box(Vector3(0.5, 0.5, 0.05), red if i % 2 == 0 else cream, Vector3(-3.25 + i * 0.5, 2.95, gz - 0.3))
		stripe.rotation_degrees.x = -25.0
		_scene.add_child(stripe)
	for sx in [-3.4, 3.4]:
		_scene.add_child(BowlingArt.box(Vector3(0.15, 3.0, 0.15), BowlingArt.mat(Color(0.5, 0.3, 0.15), 0.6), Vector3(sx, 1.5, gz - 0.3)))
	_scene.add_child(BowlingArt.box(Vector3(6.6, 0.06, 0.4), BowlingArt.mat(Color(0.55, 0.35, 0.18), 0.6), Vector3(0, 0.9, gz - 0.2)))
	_scene.add_child(BowlingArt.box(Vector3(6.6, 0.9, 0.4), red, Vector3(0, 0.45, gz - 0.2)))
	var rail := BowlingArt.cylinder(0.012, 0.012, 6.6, BowlingArt.mat(Color(0.6, 0.6, 0.65), 0.4, 0.7), Vector3(0, 1.38, gz - 0.12), 8)
	rail.rotation_degrees = Vector3(0, 0, 90)
	_scene.add_child(rail)
	var sign_node := Decor.neon_sign("STAND DE TIR", Color(1.0, 0.75, 0.2), 1.8, 0.5)
	sign_node.position = Vector3(0, 3.35, gz - 0.2)
	sign_node.scale = Vector3.ONE * 1.4
	_scene.add_child(sign_node)
	var lv := _level()
	var size: float = lv["size"]
	var speed: float = lv["speed"]
	for i in 6:
		var it := GItem.new()
		it.kind = "can"
		it.x = -1.5 + i * 0.6
		it.y = 1.0
		it.r = 0.1 * size
		it.pts = 5
		it.node = _make_can(i)
		_add_item(it)
	for i in 5:
		var it := GItem.new()
		it.kind = "duck"
		it.x = -2.0 + i * 1.0
		it.y = 1.55
		it.vx = (1.0 if i % 2 == 0 else -1.0) * 1.1 * speed
		it.r = 0.14 * size
		it.pts = 10
		it.node = _make_duck()
		_add_item(it)
	var star := GItem.new()
	star.kind = "star"
	star.y = 2.05
	star.r = 0.12 * size
	star.pts = 25
	star.alive = false
	star.timer = 3.0
	star.span = 3.0
	star.vx = 2.6 * speed
	star.node = _make_star()
	_add_item(star)


func _add_item(it: GItem) -> void:
	it.node.position = Vector3(it.x, it.y, -GALLERY_D)
	_scene.add_child(it.node)
	_gitems.append(it)
	if it.kind == "star" and not it.alive:
		it.node.visible = false


func _make_can(i: int) -> Node3D:
	var n := Node3D.new()
	var cols := [Color(0.85, 0.2, 0.2), Color(0.9, 0.9, 0.9), Color(0.2, 0.5, 0.85)]
	n.add_child(BowlingArt.cylinder(0.05, 0.05, 0.13, BowlingArt.mat(cols[i % 3], 0.4, 0.5), Vector3(0, 0.065 - 0.065, 0), 14))
	n.add_child(BowlingArt.cylinder(0.052, 0.052, 0.02, BowlingArt.mat(Color(0.7, 0.7, 0.72), 0.3, 0.8), Vector3(0, 0.065, 0), 14))
	return n


func _make_duck() -> Node3D:
	var n := Node3D.new()
	var body := BowlingArt.sphere(0.1, BowlingArt.mat(Color(1.0, 0.85, 0.15), 0.6), Vector3.ZERO, 12)
	body.scale = Vector3(1.2, 0.8, 0.8)
	n.add_child(body)
	n.add_child(BowlingArt.sphere(0.055, BowlingArt.mat(Color(1.0, 0.85, 0.15), 0.6), Vector3(0.09, 0.09, 0), 10))
	n.add_child(BowlingArt.box(Vector3(0.05, 0.02, 0.04), BowlingArt.mat(Color(1.0, 0.5, 0.1), 0.6), Vector3(0.15, 0.085, 0)))
	n.add_child(BowlingArt.sphere(0.01, BowlingArt.unshaded(Color(0, 0, 0)), Vector3(0.11, 0.11, 0.045), 6))
	n.add_child(BowlingArt.sphere(0.01, BowlingArt.unshaded(Color(0, 0, 0)), Vector3(0.11, 0.11, -0.045), 6))
	return n


func _make_star() -> Node3D:
	var n := Node3D.new()
	var disc := BowlingArt.cylinder(0.12, 0.12, 0.02, BowlingArt.glow(Color(1.0, 0.8, 0.1), 1.5), Vector3.ZERO, 16)
	disc.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(disc)
	var lab := BowlingArt.neon_label("25", 0.12, Color(1, 0.6, 0.1))
	lab.position = Vector3(0, 0, 0.02)
	n.add_child(lab)
	return n


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
	_clear_pellets()
	_clear_marks()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Carabine à plomb", "Victoires : %d   ·   record série : %d   ·   stand : %d" % [_stat("wins"), _stat("best_series"), _stat("best_gallery")])
	_panel.add_row("Jeu", [
		{"id": "mode_ordi", "text": "Concours", "width": 0.22, "selected": settings["mode"] == "ordi"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
		{"id": "mode_gallery", "text": "Stand de foire", "width": 0.28, "selected": settings["mode"] == "gallery"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	if not is_gallery():
		_panel.add_row("Distance", [
			{"id": "dist_10", "text": "10 m", "width": 0.18, "selected": settings["dist"] == 10},
			{"id": "dist_25", "text": "25 m", "width": 0.18, "selected": settings["dist"] == 25},
		])
		_panel.add_row("Séries", [
			{"id": "series_3", "text": "3", "width": 0.14, "selected": settings["series"] == 3},
			{"id": "series_5", "text": "5", "width": 0.14, "selected": settings["series"] == 5},
		])
	_panel.add_row("Carabine en main", [
		{"id": "hand_0", "text": "Gauche", "width": 0.2, "selected": settings["hand"] == 0},
		{"id": "hand_1", "text": "Droite", "width": 0.2, "selected": settings["hand"] == 1},
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
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)
	_gun.visible = false
	_dot.visible = false


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
	elif id.begins_with("series_"):
		settings["series"] = int(id.substr(7))
	elif id.begins_with("hand_"):
		settings["hand"] = int(id.substr(5))
	match id:
		"play", "restart":
			_close_panel()
			_apply_layout()
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


# ================================================================ la carabine

func _build_gun() -> void:
	_gun = Node3D.new()
	add_child(_gun)
	var metal := BowlingArt.mat(Color(0.15, 0.16, 0.18), 0.35, 0.7)
	var wood := BowlingArt.mat(Color(0.45, 0.27, 0.12), 0.5)
	_gun.add_child(BowlingArt.box(Vector3(0.04, 0.075, 0.38), wood, Vector3(0, -0.02, 0.24)))
	_gun.add_child(BowlingArt.box(Vector3(0.04, 0.055, 0.42), wood, Vector3(0, -0.03, -0.3)))
	_gun.add_child(BowlingArt.box(Vector3(0.036, 0.05, 0.4), metal, Vector3(0, 0.0, -0.05)))
	var barrel := BowlingArt.cylinder(0.011, 0.011, 0.5, metal, Vector3(0, 0.008, -0.45), 10)
	barrel.rotation_degrees = Vector3(90, 0, 0)
	_gun.add_child(barrel)
	_gun.add_child(BowlingArt.box(Vector3(0.012, 0.03, 0.012), metal, Vector3(0, 0.04, -0.66)))
	_gun.add_child(BowlingArt.box(Vector3(0.03, 0.02, 0.012), metal, Vector3(0, 0.04, 0.0)))
	_gun.add_child(BowlingArt.box(Vector3(0.012, 0.05, 0.012), metal, Vector3(0, -0.06, 0.0)))
	_gun.visible = false
	_dot = BowlingArt.sphere(0.014, BowlingArt.unshaded(Color(1, 0.1, 0.1)), Vector3.ZERO, 8)
	_dot.visible = false
	add_child(_dot)


func _main_hand() -> Hand:
	if _hands.size() < 2:
		return null
	return _hands[int(settings["hand"])]


func _off_hand() -> Hand:
	if _hands.size() < 2:
		return null
	return _hands[1 - int(settings["hand"])]


func _hpos(h: Hand) -> Vector3:
	return (global_transform.affine_inverse() * h.global_transform).origin


func _hbasis(h: Hand) -> Basis:
	return (global_transform.affine_inverse() * h.global_transform).basis


## Position de la main de tir et direction du canon (en repère du jeu).
func _aim() -> Dictionary:
	var mh := _main_hand()
	if mh == null or not is_instance_valid(mh):
		return {"pos": Vector3(0.2, 1.4, -0.1), "dir": Vector3(0, 0, -1), "two": false, "up": Vector3.UP}
	var mp := _hpos(mh)
	var mb := _hbasis(mh)
	var dir := -mb.z
	var two := false
	var oh := _off_hand()
	if oh != null and is_instance_valid(oh):
		var d := _hpos(oh) - mp
		var l := d.length()
		if l > 0.2 and l < 0.8 and d.normalized().dot(dir) > 0.6:
			dir = d / l
			two = true
	return {"pos": mp, "dir": dir, "two": two, "up": mb.y}


## Angle de relèvement du canon pour que le plomb touche la cible à `dist` (tir tendu).
static func zero_pitch(dist: float) -> float:
	var f := clampf(GRAVITY * dist / (PELLET_SPEED * PELLET_SPEED), 0.0, 0.99)
	return 0.5 * asin(f)


func _fire_dir(dir: Vector3) -> Vector3:
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.01:
		return dir
	return dir.rotated(right.normalized(), zero_pitch(-_plane_z()))


func _update_gun() -> void:
	var show := state != State.SETUP and state != State.GAME_OVER and not _panel.visible
	_gun.visible = show
	if not show:
		_dot.visible = false
		return
	var a := _aim()
	var dir: Vector3 = a["dir"]
	var up: Vector3 = a["up"]
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.UP
	_gun.transform = Transform3D(Basis.looking_at(dir, up), a["pos"])
	_dot.visible = false
	if bool(_level()["dot"]) and (state == State.READY or state == State.PLAY):
		var from: Vector3 = a["pos"] + dir * MUZZLE
		var hit = predict_hit(from, _fire_dir(dir) * PELLET_SPEED)
		if hit != null:
			_dot.position = (hit as Vector3) + Vector3(0, 0, 0.01)
			_dot.visible = true


# ================================================================ plombs

func predict_hit(start: Vector3, vel: Vector3) -> Variant:
	var plane := _plane_z()
	var p := start
	var v := vel
	var dt := 0.002
	for i in 3000:
		var pv := p
		v.y -= GRAVITY * dt
		p += v * dt
		if pv.z > plane and p.z <= plane:
			var t := (pv.z - plane) / (pv.z - p.z)
			return pv.lerp(p, t)
		if p.y < 0.0:
			return null
	return null


func _new_pellet(team: int) -> Pellet:
	var p := Pellet.new()
	p.team = team
	var n := BowlingArt.box(Vector3(0.006, 0.006, 0.5), BowlingArt.unshaded(Color(1.0, 0.92, 0.6, 0.9)), Vector3.ZERO)
	add_child(n)
	p.node = n
	_pellets.append(p)
	return p


func _clear_pellets() -> void:
	for p in _pellets:
		if p.node and is_instance_valid(p.node):
			p.node.queue_free()
	_pellets.clear()


func _clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()


## Tire un plomb depuis `mp` dans la direction `dir` du canon. Renvoie false si on ne peut pas.
func _shoot(mp: Vector3, dir: Vector3) -> bool:
	if _cd > 0.0:
		return false
	if state != State.READY and state != State.PLAY:
		return false
	var p := _new_pellet(PLAYER)
	var d := dir.normalized()
	p.pos = mp + d * MUZZLE
	p.vel = _fire_dir(d) * PELLET_SPEED
	_cd = SHOT_GAP
	_total_shots += 1
	if not is_gallery():
		_left -= 1
		state = State.FLIGHT
	_hint.text = ""
	Sound.play_at("air_shot", to_global(p.pos), -2.0, 0.06)
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.7, 0.08)
	return true


func _step_pellet(p: Pellet, dt: float) -> void:
	var pv := p.pos
	p.vel.y -= GRAVITY * dt
	p.pos += p.vel * dt
	p.life += dt
	var plane := _plane_z()
	if pv.z > plane and p.pos.z <= plane:
		var t := (pv.z - plane) / (pv.z - p.pos.z)
		_plane_hit(p, pv.lerp(p.pos, t))
		return
	if p.pos.y <= 0.0 or p.pos.z < plane - 8.0 or p.life > 4.0:
		_kill_pellet(p, false)
		return
	var dir := p.vel.normalized()
	p.node.visible = true
	p.node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), p.pos - dir * 0.25)


func _kill_pellet(p: Pellet, _hit: bool) -> void:
	p.alive = false
	_last_points = p.points
	if p.node and is_instance_valid(p.node):
		p.node.visible = false


func _plane_hit(p: Pellet, hit: Vector3) -> void:
	if is_gallery():
		_gallery_hit(p, hit)
	else:
		_paper_hit(p, hit)
	_kill_pellet(p, true)


## Points d'un impact : 10 zones de largeur égale, 0 hors de la cible.
static func ring_points(r: float, face_r: float) -> int:
	if r >= face_r:
		return 0
	return 10 - int(floor(10.0 * r / face_r))


func _paper_hit(p: Pellet, hit: Vector3) -> void:
	var rel := Vector2(hit.x, hit.y - TARGET_Y)
	var r := rel.length()
	p.points = ring_points(r, _face_r)
	var board := _face_r + 0.14
	if absf(rel.x) <= board and absf(rel.y) <= board:
		_add_mark(rel, p.team)
		Sound.play_at("dart_thud", to_global(hit), -4.0, 0.08)
		if p.points >= 10:
			Sound.play_at("bull_ding", to_global(hit), -10.0, 0.0)
	else:
		Sound.play_at("pet_land", to_global(hit), -8.0, 0.08)
	_float_score(p.points, Vector3(hit.x, hit.y + 0.15, hit.z + 0.1))


func _add_mark(rel: Vector2, team: int) -> void:
	var col := CLR_PLAYER if team == PLAYER else CLR_AI
	var rr := 0.012 * (_face_r / 0.3)
	var m := BowlingArt.cylinder(rr, rr, 0.002, BowlingArt.unshaded(col), Vector3(rel.x, rel.y, 0.006), 10)
	m.rotation_degrees = Vector3(90, 0, 0)
	_target.add_child(m)
	_marks.append(m)
	if _marks.size() > 80:
		var old: Node3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _gallery_hit(p: Pellet, hit: Vector3) -> void:
	var best: GItem = null
	var best_d := 99.0
	for it in _gitems:
		if not it.alive:
			continue
		var dd := Vector2(hit.x - it.x, hit.y - it.y).length()
		if dd <= it.r and dd < best_d:
			best = it
			best_d = dd
	if best == null:
		Sound.play_at("pet_land", to_global(hit), -10.0, 0.08)
		return
	p.points = best.pts
	scores[0] += best.pts
	_knock(best)
	Sound.play_at("can_ping", to_global(hit), 0.0, 0.1)
	_float_score(best.pts, Vector3(best.x, best.y + 0.2, hit.z + 0.1))
	if best.pts >= 25 and not _st_bot:
		_robin.react("carreau")
	_update_scoreboard()


func _knock(it: GItem) -> void:
	it.alive = false
	it.timer = 2.5 if it.kind == "can" else (2.0 if it.kind == "duck" else 5.0)
	var n := it.node
	var tw_ := create_tween()
	tw_.set_parallel(true)
	tw_.tween_property(n, "rotation:z", 1.6, 0.25)
	tw_.tween_property(n, "position:y", it.y - 0.5, 0.35)
	tw_.chain().tween_callback(n.hide)


func _float_score(pts: int, pos: Vector3) -> void:
	var col := Color(1.0, 0.85, 0.2) if pts >= 9 else (Color(0.5, 1, 0.5) if pts > 0 else Color(1, 0.5, 0.4))
	var l := BowlingArt.neon_label(str(pts) if pts > 0 else "×", 0.2, col)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	_fx_root.add_child(l)
	var tw_ := create_tween()
	tw_.set_parallel(true)
	tw_.tween_property(l, "position:y", pos.y + 0.4, 1.4)
	tw_.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tw_.chain().tween_callback(l.queue_free)


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
		return
	_time += delta
	_cd = maxf(0.0, _cd - delta)
	if not _st_bot:
		_update_gun()
	for p in _pellets:
		if p.alive:
			var h := delta / 2.0
			for i in 2:
				_step_pellet(p, h)
				if not p.alive:
					break
	for i in range(_pellets.size() - 1, -1, -1):
		var p := _pellets[i]
		if not p.alive:
			if state == State.FLIGHT and p.team == PLAYER:
				_after_pellet(p)
			if p.node and is_instance_valid(p.node):
				p.node.queue_free()
			_pellets.remove_at(i)
	match state:
		State.READY:
			if _st_bot:
				_bot_shoot()
		State.PLAY:
			_update_gallery(delta)
			if _st_bot:
				_bot_gallery()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()
		State.AI_TURN:
			_timer -= delta
			if _timer <= 0.0:
				_ai_series()


func _after_pellet(p: Pellet) -> void:
	_series_pts += p.points
	if is_contest():
		scores[0] += p.points
	_announce(("%d !" % p.points) if p.points > 0 else "Raté", Color(1.0, 0.85, 0.2) if p.points >= 9 else (Color(0.5, 1, 0.5) if p.points > 0 else Color(1, 0.5, 0.4)), 1.2)
	if not _st_bot:
		if p.points >= 9:
			_robin.react("carreau")
		elif p.points == 0:
			_robin.react("oups")
	_update_scoreboard()
	state = State.PAUSE
	_timer = 0.7 if not _selftest else 0.05
	_pause_next = "next_shot"


func _after_pause() -> void:
	match _pause_next:
		"next_shot":
			_next_shot()
		"retrieve":
			_retrieve_and_continue()


func _next_shot() -> void:
	if _left > 0:
		_begin_ready()
		return
	if is_training():
		_best_series = maxi(_best_series, _series_pts)
		if _series_pts > _stat("best_series"):
			_save.set_value("records", "best_series", _series_pts)
			_save.save(SAVE_PATH)
		_announce("Série : %d" % _series_pts, Color(1, 0.8, 0.2), 2.0)
		_update_scoreboard()
		state = State.PAUSE
		_pause_next = "retrieve"
		_timer = 2.2 if not _selftest else 0.05
		return
	state = State.AI_TURN
	_timer = 1.2 if not _selftest else 0.05
	_announce("Robin tire…", CLR_AI, 1.2)


func _retrieve_and_continue() -> void:
	_clear_marks()
	_series_pts = 0
	_left = PER_SERIES
	if is_contest():
		_series += 1
		if _series >= int(settings["series"]):
			_end_contest()
			return
	_begin_ready()


func _begin_ready() -> void:
	state = State.READY
	if not _st_bot:
		_hint.text = "Gâchette de la main de tir = un plomb.\nMets l'autre main devant pour viser plus stable"
	_update_scoreboard()


func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _ai_series() -> void:
	var sg: float = float(_level()["sigma"]) * _face_r
	var total := 0
	for i in PER_SERIES:
		var off := Vector2(_gauss(), _gauss()) * sg
		total += ring_points(off.length(), _face_r)
		if absf(off.x) <= _face_r + 0.14 and absf(off.y) <= _face_r + 0.14:
			_add_mark(off, AI)
		Sound.play_at("dart_thud", to_global(Vector3(off.x, TARGET_Y + off.y, _plane_z())), -6.0, 0.1)
	scores[1] += total
	_announce("Robin : %d" % total, CLR_AI, 2.0)
	_update_scoreboard()
	if not _st_bot:
		_robin.react("pointe" if total >= 36 else "oups")
	state = State.PAUSE
	_pause_next = "retrieve"
	_timer = 2.4 if not _selftest else 0.05


# ---------------------------------------------------------------- stand de foire

func _update_gallery(delta: float) -> void:
	_gtime -= delta
	var sec := int(ceil(maxf(_gtime, 0.0)))
	if sec != _last_sec:
		_last_sec = sec
		_update_scoreboard()
	for it in _gitems:
		match it.kind:
			"can":
				if not it.alive:
					it.timer -= delta
					if it.timer <= 0.0:
						_respawn(it)
			"duck":
				if it.alive:
					it.x += it.vx * delta
					if absf(it.x) > it.span:
						it.x = clampf(it.x, -it.span, it.span)
						it.vx = -it.vx
					it.node.position = Vector3(it.x, it.y, -GALLERY_D)
					it.node.rotation.y = 0.0 if it.vx > 0.0 else PI
				else:
					it.timer -= delta
					if it.timer <= 0.0:
						_respawn(it)
			"star":
				if it.alive:
					it.x += it.vx * delta
					it.node.position = Vector3(it.x, it.y, -GALLERY_D)
					if absf(it.x) > it.span + 0.3:
						it.alive = false
						it.timer = 4.0
						it.node.visible = false
				else:
					it.timer -= delta
					if it.timer <= 0.0:
						it.alive = true
						var dirn := 1.0 if randf() < 0.5 else -1.0
						it.vx = absf(it.vx) * dirn
						it.x = -dirn * (it.span + 0.2)
						it.node.rotation = Vector3.ZERO
						it.node.position = Vector3(it.x, it.y, -GALLERY_D)
						it.node.visible = true
	if _gtime <= 0.0:
		_end_gallery()


func _respawn(it: GItem) -> void:
	it.alive = true
	it.node.rotation = Vector3.ZERO
	it.node.position = Vector3(it.x, it.y, -GALLERY_D)
	it.node.visible = true
	if it.kind == "duck":
		it.vx = -it.vx if randf() < 0.3 else it.vx


func _end_gallery() -> void:
	state = State.GAME_OVER
	var pts: int = scores[0]
	var rec := pts > _stat("best_gallery")
	if rec:
		_save.set_value("records", "best_gallery", pts)
		_save.save(SAVE_PATH)
	var summary := "%d points%s" % [pts, "  ·  nouveau record !" if rec else ""]
	_announce(summary, Color(1, 0.8, 0.2), 3.0)
	_scoreboard.celebrate("win")
	_update_scoreboard()
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


# ---------------------------------------------------------------- déroulement

func start_match() -> void:
	_clear_pellets()
	_clear_marks()
	scores = [0, 0]
	_series = 0
	_left = PER_SERIES
	_series_pts = 0
	_best_series = 0
	_total_shots = 0
	_time = 0.0
	_cd = 0.0
	_last_sec = -1
	if is_gallery():
		_gtime = _gallery_time
		for it in _gitems:
			if it.kind == "star":
				it.alive = false
				it.timer = 3.0
				it.node.visible = false
			else:
				_respawn(it)
		state = State.PLAY
		_hint.text = "Gâchette = un plomb. Boîtes 5, canards 10, étoile 25 !"
		_update_scoreboard()
		return
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
	var lvl := String(_level()["title"]).to_upper()
	if is_gallery():
		_scoreboard.set_data("CARABINE · STAND DE FOIRE", ["POINTS", "RECORD"], [scores[0], maxi(_stat("best_gallery"), scores[0])], 0, "Temps restant : %d s" % int(ceil(maxf(_gtime, 0.0))))
	elif is_training():
		_scoreboard.set_data("CARABINE · ENTRAÎNEMENT", ["SÉRIE", "RECORD"], [_series_pts, maxi(_stat("best_series"), _best_series)], 0, "Plombs restants dans la série : %d  ·  %d m" % [_left, int(settings["dist"])])
	else:
		_scoreboard.set_data("CARABINE · %s" % lvl, ["VOUS", "ROBIN"], scores, PLAYER if state != State.AI_TURN else AI, "Série %d / %d  ·  plombs : %d  ·  %d m" % [mini(_series + 1, int(settings["series"])), int(settings["series"]), _left, int(settings["dist"])])


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
	if button == "trigger_click" and hand == _main_hand():
		var a := _aim()
		_shoot(a["pos"], a["dir"])


func on_button_released(_hand: Hand, _button: String) -> void:
	pass


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["ordi", "training", "gallery"]:
		settings["mode"] = "ordi"
	if int(settings["dist"]) not in [10, 25]:
		settings["dist"] = 10
	if int(settings["series"]) not in [3, 5]:
		settings["series"] = 3
	if int(settings["hand"]) not in [0, 1]:
		settings["hand"] = 1


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


## Le joueur virtuel : vise le centre avec une petite erreur.
func _bot_shoot() -> void:
	var from := Vector3(0.2, 1.4, -0.1)
	var sg := 0.13 * _face_r
	var target := Vector3(_gauss() * sg, TARGET_Y + _gauss() * sg, _plane_z())
	_shoot(from, (target - from).normalized())


func _bot_gallery() -> void:
	if _cd > 0.0:
		return
	var alive: Array[GItem] = []
	for it in _gitems:
		if it.alive:
			alive.append(it)
	if alive.is_empty():
		return
	var it: GItem = alive[randi() % alive.size()]
	var from := Vector3(0.2, 1.4, -0.1)
	var tf := (GALLERY_D) / PELLET_SPEED
	var target := Vector3(it.x + it.vx * tf + _gauss() * 0.015, it.y + _gauss() * 0.015, _plane_z())
	_shoot(from, (target - from).normalized())


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["dist"] = 10
	settings["series"] = 3
	_apply_layout()
	_st_bot = false
	state = State.SETUP

	# A. Barème : 10 zones de largeur égale
	var fr := _face_r
	_st_check("barème", ring_points(0.0, fr) == 10 and ring_points(fr * 0.05, fr) == 10 and ring_points(fr * 0.15, fr) == 9 and ring_points(fr * 0.55, fr) == 5 and ring_points(fr * 0.95, fr) == 1 and ring_points(fr * 1.1, fr) == 0, "")

	# B. La visée relevée compense la chute : plomb droit sur le centre = 9 ou 10, à 10 et 25 m
	var from := Vector3(0.2, 1.4, -0.1)
	for d in [10, 25]:
		settings["dist"] = d
		_apply_layout()
		var pts := 0
		var rec := 0
		for k in 3:
			state = State.READY
			_left = 5
			_cd = 0.0
			var tgt := Vector3(0, TARGET_Y, _plane_z())
			var dirc := (tgt - from).normalized()
			_shoot(from, dirc)
			await _wait_frames(60)
			var pl := _last_points
			rec += 1 if pl >= 9 else 0
			pts += pl
		_st_check("tir au centre à %d m" % d, rec == 3, "(%d pts sur 3 plombs)" % pts)
	settings["dist"] = 10
	_apply_layout()

	# C. Cadence : pas de second plomb tant que le premier vole
	state = State.READY
	_left = 5
	_cd = 0.0
	var first := _shoot(from, (Vector3(0, TARGET_Y, -10.0) - from).normalized())
	var second := _shoot(from, (Vector3(0, TARGET_Y, -10.0) - from).normalized())
	_st_check("cadence de tir", first and not second and _left == 4, "")
	await _wait_frames(60)

	# D. Plomb loin au-dessus : 0 point ; plomb à mi-rayon : 4 à 6 points
	state = State.READY
	_cd = 0.0
	_shoot(from, (Vector3(0, TARGET_Y + 2.0, -10.0) - from).normalized())
	await _wait_frames(60)
	_st_check("plomb hors cible", _last_points == 0, "(%d pts)" % _last_points)
	state = State.READY
	_cd = 0.0
	_shoot(from, (Vector3(_face_r * 0.55, TARGET_Y, -10.0) - from).normalized())
	await _wait_frames(60)
	_st_check("plomb à mi-rayon", _last_points >= 4 and _last_points <= 6, "(%d pts)" % _last_points)
	_clear_pellets()
	_clear_marks()

	# E. Stand de foire : toucher une boîte, un canard en mouvement
	settings["mode"] = "gallery"
	_apply_layout()
	_gallery_time = 60.0
	_st_bot = false
	start_match()
	var can: GItem = null
	var duck: GItem = null
	for it in _gitems:
		if it.kind == "can" and can == null:
			can = it
		if it.kind == "duck" and duck == null:
			duck = it
	_cd = 0.0
	_shoot(from, (Vector3(can.x, can.y, -GALLERY_D) - from).normalized())
	await _wait_frames(40)
	_st_check("boîte touchée", not can.alive and scores[0] == 5, "(%d pts)" % scores[0])
	_cd = 0.0
	var tfl := GALLERY_D / PELLET_SPEED
	_shoot(from, (Vector3(duck.x + duck.vx * (tfl + 0.02), duck.y, -GALLERY_D) - from).normalized())
	await _wait_frames(40)
	_st_check("canard touché", not duck.alive and scores[0] == 15, "(%d pts)" % scores[0])
	_cd = 0.0
	_shoot(from, (Vector3(0, 3.0, -GALLERY_D) - from).normalized())
	await _wait_frames(40)
	_st_check("tir à côté dans le stand", scores[0] == 15, "")
	_clear_pellets()

	# F. Parties complètes avec le joueur virtuel
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		settings["mode"] = "ordi"
		settings["series"] = 3
		_apply_layout()
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 400:
			await get_tree().physics_frame
			guard += 1
		_st_check("concours %s terminé" % lv, state == State.GAME_OVER and scores[0] > 0 and scores[1] > 0, "%s en %.0f s" % [str(scores), guard / 90.0])
	settings["level"] = "normal"
	settings["mode"] = "gallery"
	_apply_layout()
	_gallery_time = 8.0
	_st_bot = true
	start_match()
	var g2 := 0
	while state != State.GAME_OVER and g2 < 90 * 60:
		await get_tree().physics_frame
		g2 += 1
	_st_check("stand terminé", state == State.GAME_OVER and scores[0] >= 20, "(%d pts en %.0f s)" % [scores[0], g2 / 90.0])
	settings["mode"] = "training"
	_apply_layout()
	_st_bot = true
	start_match()
	var g3 := 0
	while _left > 0 or state != State.PAUSE or _pause_next != "retrieve":
		await get_tree().physics_frame
		g3 += 1
		if g3 > 90 * 60:
			break
	_st_check("entraînement : une série", _series_pts > 0 and g3 <= 90 * 60, "(%d pts)" % _series_pts)

	_st_bot = false
	_clear_pellets()
	for l in _st_log:
		print("SELFTEST carabine ", l)
	var ok := _st_failures.is_empty()
	print("SELFTEST carabine=", "OK" if ok else "ECHEC")
	selftest_finished.emit(ok)
