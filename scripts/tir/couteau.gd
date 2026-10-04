class_name CouteauGame
extends Node3D
## Lancer de couteau en réalité augmentée. Les couteaux sont posés sur une table devant toi :
## gâchette ou grip près d'un couteau = tu le prends, tu lances d'un geste, tu relâches.
## Le couteau tourne sur lui-même (un tour complet jusqu'à la cible) : il se plante s'il arrive
## la pointe devant, sinon il rebondit. Cible en rondin à 3, 4,5 ou 6 m ; concours contre Robin,
## entraînement ou rondin mobile. Le noeud est aux pieds du joueur ; la cible est à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const GRAVITY := 9.81
const TARGET_Y := 1.45
const HOLDER_POS := Vector3(0.0, 0.95, -0.5)
const GRAB_RADIUS := 0.22
const THROW_BOOST := 1.3
const MIN_THROW_SPEED := 2.5
const TOL_DEG := 45.0
const PER_ROUND := 3
const MOBILE_TOTAL := 9
const MOVE_AMP := 1.2
const MOVE_PERIOD := 4.5
const SAVE_PATH := "user://couteau.cfg"
const PLAYER := 1
const AI := -1
const CLR_AI := Color(0.95, 0.5, 0.3)
const LOG_EXTRA := 0.12

const LEVELS := {
	"facile": {"title": "Facile", "assist": 0.75, "noise": 12.0, "sigma": 0.45},
	"normal": {"title": "Normal", "assist": 0.45, "noise": 22.0, "sigma": 0.32},
	"expert": {"title": "Expert", "assist": 0.15, "noise": 34.0, "sigma": 0.20},
}

enum State { SETUP, READY, HELD, FLIGHT, PAUSE, AI_TURN, GAME_OVER }


class Knife extends RefCounted:
	var node: Node3D
	var slot := Transform3D.IDENTITY
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var team := 1
	var in_holder := true
	var flying := false
	var done := false
	var bounced := false
	var in_target := false
	var points := 0
	var omega := 0.0
	var theta0 := 0.0
	var age := 0.0
	var dir0 := Vector3(0, 0, -1)


var settings := {"mode": "ordi", "level": "normal", "dist": 4.5, "rounds": 3, "music": true}
var state := State.SETUP
var scores := [0, 0]
var _round := 0
var _left := PER_ROUND
var _round_pts := 0
var _best_round := 0
var _total := 0
var _time := 0.0
var _timer := 0.0
var _pause_next := ""
var _face_r := 0.4
var _tx := 0.0
var _knives: Array[Knife] = []
var _held: Knife = null
var _holder_hand: Hand = null
var _grab_button := ""
var _flying: Knife = null
var _test_err := 999.0             # test : erreur d'angle imposée (degrés)

var _hands: Array = []
var _scene: Node3D
var _target: Node3D
var _fx_root: Node3D
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
	_panel.accent = Color(0.8, 0.55, 0.25)
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


func is_training() -> bool:
	return settings["mode"] == "training"


func is_mobile() -> bool:
	return settings["mode"] == "mobile"


func is_contest() -> bool:
	return settings["mode"] == "ordi"


func _level() -> Dictionary:
	return LEVELS[settings["level"]]


func _dist() -> float:
	return float(settings["dist"])


func _apply_layout() -> void:
	_face_r = 0.3 + 0.02 * _dist()
	_build_range()
	_scoreboard.position = Vector3(1.7, 1.5, -2.0)
	_scoreboard.scale = Vector3.ONE * 1.1
	var face := Vector3(0, 0, 1.0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_robin.position = Vector3(-1.7, 0, -0.8)
	_robin.rotation.y = deg_to_rad(40.0)
	_message.position = Vector3(0, 2.0, -2.2)
	_hint.position = Vector3(0, 1.2, -0.7)


func _wood_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for x in s:
		for y in s:
			var v := 0.5 + 0.12 * sin(y * 0.35 + 3.0 * sin(x * 0.05)) + rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, Color(0.5 * v * 1.4, 0.32 * v * 1.4, 0.16 * v * 1.4))
	return ImageTexture.create_from_image(img)


func _build_range() -> void:
	for c in _scene.get_children():
		c.queue_free()
	_clear_knives()
	var d := _dist()
	_scene.add_child(Decor.sport_corner("fair", Vector3(0, 2.3, -d - 0.5)))
	var len := d + 5.0
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _wood_texture()
	fm.uv1_scale = Vector3(4, len * 0.5, 1.0)
	fm.roughness = 0.8
	_scene.add_child(BowlingArt.floor_quad(7.0, len, fm, Vector3(0, 0.001, -len / 2.0 + 2.0)))
	var wall := BowlingArt.mat(Color(0.32, 0.22, 0.16), 0.9)
	_scene.add_child(BowlingArt.box(Vector3(7.0, 3.2, 0.2), wall, Vector3(0, 1.6, -d - 1.2)))
	_scene.add_child(BowlingArt.box(Vector3(0.2, 3.2, len + 1.0), wall, Vector3(-3.5, 1.6, -len / 2.0 + 1.8)))
	_scene.add_child(BowlingArt.box(Vector3(0.2, 3.2, len + 1.0), wall, Vector3(3.5, 1.6, -len / 2.0 + 1.8)))
	_scene.add_child(BowlingArt.box(Vector3(7.0, 0.2, len + 1.0), BowlingArt.mat(Color(0.25, 0.17, 0.12), 0.9), Vector3(0, 3.3, -len / 2.0 + 1.8)))
	var white := BowlingArt.unshaded(Color(1, 0.95, 0.8, 0.9))
	_scene.add_child(BowlingArt.box(Vector3(2.0, 0.004, 0.05), white, Vector3(0, 0.004, 0.05)))
	for sx in [-1.0, 1.0]:
		var lamp := Decor.lamp(2.4)
		lamp.position = Vector3(sx * 3.0, 0, -d * 0.5)
		_scene.add_child(lamp)
	# table des couteaux
	var table := Node3D.new()
	table.position = HOLDER_POS
	_scene.add_child(table)
	table.add_child(BowlingArt.box(Vector3(0.6, 0.04, 0.3), BowlingArt.surface_material("wood", Color(0.5, 0.32, 0.16)), Vector3(0, -0.04, 0)))
	table.add_child(BowlingArt.box(Vector3(0.58, 0.003, 0.28), BowlingArt.surface_material("fabric", Color(0.6, 0.12, 0.12)), Vector3(0, -0.018, 0)))
	for sx in [-0.26, 0.26]:
		for sz in [-0.12, 0.12]:
			table.add_child(BowlingArt.box(Vector3(0.04, HOLDER_POS.y, 0.04), BowlingArt.mat(Color(0.4, 0.26, 0.14), 0.7), Vector3(sx, -HOLDER_POS.y / 2.0 - 0.02, sz)))
	# cible : rondin
	_target = Node3D.new()
	_target.position = Vector3(0, TARGET_Y, -d)
	_scene.add_child(_target)
	_build_target_face()
	var sign_node := Decor.neon_sign("LANCER DE COUTEAU", Color(1.0, 0.7, 0.3), 1.8, 0.5)
	sign_node.position = Vector3(0, 2.75, -d - 1.05)
	sign_node.scale = Vector3.ONE * (1.0 + d / 8.0)
	_scene.add_child(sign_node)
	_build_knives()


func _build_target_face() -> void:
	var log_r := _face_r + LOG_EXTRA
	var logm := BowlingArt.mat(Color(0.55, 0.36, 0.18), 0.85)
	var body := BowlingArt.cylinder(log_r, log_r, 0.3, logm, Vector3(0, 0, -0.15), 36)
	body.rotation_degrees = Vector3(90, 0, 0)
	_target.add_child(body)
	_target.add_child(BowlingArt.box(Vector3(0.1, TARGET_Y, 0.1), BowlingArt.mat(Color(0.4, 0.26, 0.14), 0.7), Vector3(0, -TARGET_Y / 2.0 - log_r * 0.5, -0.2)))
	var cols := [Color(0.93, 0.9, 0.8), Color(0.15, 0.12, 0.1), Color(0.2, 0.45, 0.8), Color(0.85, 0.15, 0.15), Color(1.0, 0.8, 0.15)]
	for k in range(10, 0, -1):
		var col: Color = cols[(k - 1) / 2]
		if k % 2 == 1:
			col = col.darkened(0.12)
		var rr := _face_r * k / 10.0
		var disc := BowlingArt.cylinder(rr, rr, 0.004, BowlingArt.mat(col, 0.8), Vector3.ZERO, 36)
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position.z = 0.002 + 0.0012 * (10 - k)
		_target.add_child(disc)


func _make_knife_node() -> Node3D:
	return RangedArt.knife(VisualStyle.detailed)


func _build_knives() -> void:
	for i in PER_ROUND:
		_new_holder_knife(i)


func _new_holder_knife(i: int) -> Knife:
	var k := Knife.new()
	k.node = _make_knife_node()
	k.slot = Transform3D(Basis.IDENTITY, HOLDER_POS + Vector3(-0.17 + 0.17 * i, 0.012, 0.0))
	k.node.transform = k.slot
	add_child(k.node)
	k.pos = k.slot.origin
	k.team = PLAYER
	_knives.append(k)
	return k


func _clear_knives() -> void:
	for k in _knives:
		if k.node and is_instance_valid(k.node):
			k.node.queue_free()
	_knives.clear()
	_held = null
	_flying = null
	_holder_hand = null


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
	_return_held()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Lancer de couteau", "Victoires : %d   ·   record manche : %d   ·   rondin mobile : %d" % [_stat("wins"), _stat("best_round"), _stat("best_mobile")])
	_panel.add_row("Jeu", [
		{"id": "mode_ordi", "text": "Concours", "width": 0.22, "selected": settings["mode"] == "ordi"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
		{"id": "mode_mobile", "text": "Rondin mobile", "width": 0.28, "selected": settings["mode"] == "mobile"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Distance", [
		{"id": "dist_3", "text": "3 m", "width": 0.16, "selected": is_equal_approx(_dist(), 3.0)},
		{"id": "dist_4.5", "text": "4,5 m", "width": 0.18, "selected": is_equal_approx(_dist(), 4.5)},
		{"id": "dist_6", "text": "6 m", "width": 0.16, "selected": is_equal_approx(_dist(), 6.0)},
	])
	_panel.add_row("Manches", [
		{"id": "rounds_3", "text": "3", "width": 0.14, "selected": settings["rounds"] == 3},
		{"id": "rounds_5", "text": "5", "width": 0.14, "selected": settings["rounds"] == 5},
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
	_return_held()
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
	elif id.begins_with("dist_"):
		settings["dist"] = float(id.substr(5))
	elif id.begins_with("rounds_"):
		settings["rounds"] = int(id.substr(7))
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


# ================================================================ lancer

func _lpos(h: Hand) -> Vector3:
	return (global_transform.affine_inverse() * h.global_transform).origin


func target_x_at(t: float) -> float:
	if not is_mobile():
		return 0.0
	return MOVE_AMP * sin(TAU * t / MOVE_PERIOD)


## Points d'un impact : 10 zones de largeur égale, 0 hors des cercles.
static func ring_points(r: float, face_r: float) -> int:
	if r >= face_r:
		return 0
	return 10 - int(floor(10.0 * r / face_r))


## Vitesse (repère du jeu) qui amène le couteau en `target` avec une vitesse avant `vf`.
func ideal_velocity(from: Vector3, target: Vector3, vf: float) -> Vector3:
	var t := (from.z - target.z) / vf
	return Vector3((target.x - from.x) / t, (target.y - from.y) / t + 0.5 * GRAVITY * t, -vf)


## Rapproche le lancer du centre de la cible sans changer le temps de vol.
func _apply_assist(from: Vector3, v: Vector3) -> Vector3:
	var assist: float = _level()["assist"]
	var vf := -v.z
	if vf < 1.5 or assist <= 0.0:
		return v
	var t := (from.z + _dist()) / vf
	var tx := target_x_at(_time + t)
	var ideal := ideal_velocity(from, Vector3(tx, TARGET_Y, -_dist()), vf)
	return v.lerp(ideal, assist)


## Lance le couteau `k` depuis `from` (repère du jeu) à la vitesse `v`. Renvoie false si trop faible.
func _throw_knife(k: Knife, from: Vector3, v: Vector3) -> bool:
	if v.length() < MIN_THROW_SPEED or -v.z < 1.5:
		return false
	v = _apply_assist(from, v)
	k.pos = from
	k.vel = v
	k.in_holder = false
	k.flying = true
	k.done = false
	k.age = 0.0
	k.dir0 = v.normalized()
	var t := maxf(0.05, (from.z + _dist()) / maxf(-v.z, 0.5))
	k.omega = TAU / t
	var noise: float = _level()["noise"]
	var err := _gauss() * noise * 0.5
	if _test_err < 900.0:
		err = _test_err
	k.theta0 = deg_to_rad(err)
	_flying = k
	_left -= 1
	_total += 1
	state = State.FLIGHT
	_hint.text = ""
	Sound.play_at("whoosh", to_global(from), -6.0, 0.15)
	return true


func _knife_basis(k: Knife) -> Basis:
	var d := k.vel.normalized()
	var ax := d.cross(Vector3.UP)
	if ax.length() < 0.05:
		ax = Vector3.RIGHT
	ax = ax.normalized()
	var theta := k.theta0 + k.omega * k.age
	var blade := k.dir0.rotated(ax, theta)
	if k.bounced or k.done:
		blade = d
	return Basis.looking_at(blade, Vector3.UP if absf(blade.y) < 0.98 else Vector3.RIGHT)


func _step_knife(k: Knife, dt: float) -> void:
	var pv := k.pos
	k.vel.y -= GRAVITY * dt
	k.pos += k.vel * dt
	k.age += dt
	var plane := -_dist()
	if not k.bounced and pv.z > plane and k.pos.z <= plane:
		var f := (pv.z - plane) / (pv.z - k.pos.z)
		var hit := pv.lerp(k.pos, f)
		var rel := Vector2(hit.x - _tx, hit.y - TARGET_Y)
		var r := rel.length()
		if r <= _face_r + LOG_EXTRA:
			var theta := k.theta0 + k.omega * k.age
			var err := absf(wrapf(rad_to_deg(theta), -180.0, 180.0))
			if err <= TOL_DEG:
				k.points = ring_points(r, _face_r)
				_stick(k, hit)
				return
			# plat ou manche : rebond
			k.bounced = true
			k.points = 0
			k.pos = hit + Vector3(0, 0, 0.05)
			k.vel = Vector3(k.vel.x * 0.1 + randf_range(-0.6, 0.6), 1.2, 2.0)
			Sound.play_at("pet_clack", to_global(hit), -2.0, 0.1)
			_announce("Pas planté !", Color(1, 0.5, 0.4), 1.4)
			k.node.transform = Transform3D(_knife_basis(k), k.pos)
			return
	if k.pos.y <= 0.03:
		k.pos.y = 0.03
		k.flying = false
		k.done = true
		k.node.transform = Transform3D(Basis.looking_at(Vector3(k.vel.x, 0.0, k.vel.z) if Vector2(k.vel.x, k.vel.z).length() > 0.1 else Vector3(0, 0, -1), Vector3.UP), k.pos)
		Sound.play_at("pet_clack", to_global(k.pos), -8.0, 0.1)
		return
	if k.pos.z < plane - 1.5 or k.age > 5.0:
		k.flying = false
		k.done = true
		k.node.visible = false
		return
	k.node.transform = Transform3D(_knife_basis(k), k.pos)


func _stick(k: Knife, at: Vector3) -> void:
	k.flying = false
	k.done = true
	k.in_target = true
	var d := k.vel.normalized()
	var tip := at + d * 0.06
	k.node.reparent(_target, false)
	k.node.transform = Transform3D(Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT), tip - _target.position)
	Sound.play_at("dart_thud", to_global(at), 2.0, 0.08)
	if k.points >= 10:
		Sound.play_at("bull_ding", to_global(at), -6.0, 0.0)
	_float_score(k.points, Vector3(at.x, at.y + 0.2, at.z + 0.1))
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.4, 0.06)


func _float_score(pts: int, pos: Vector3) -> void:
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
	_tx = target_x_at(_time)
	_target.position.x = _tx
	if state == State.HELD and _held != null and is_instance_valid(_holder_hand):
		var hb := global_transform.affine_inverse() * _holder_hand.global_transform
		_held.node.transform = Transform3D(hb.basis, hb.origin)
		_held.pos = hb.origin
	match state:
		State.READY:
			if _st_bot:
				_bot_throw()
		State.FLIGHT:
			if _flying != null:
				var h := delta / 2.0
				for i in 2:
					_step_knife(_flying, h)
					if not _flying.flying:
						break
				if _flying != null and not _flying.flying:
					_after_knife()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()
		State.AI_TURN:
			_timer -= delta
			if _timer <= 0.0:
				_ai_round()


func _after_knife() -> void:
	var k := _flying
	_flying = null
	_round_pts += k.points
	if is_contest() or is_mobile():
		scores[0] += k.points
	if k.in_target:
		_announce(("%d !" % k.points) if k.points > 0 else "Dans le bois", Color(1.0, 0.85, 0.2) if k.points >= 9 else (Color(0.5, 1, 0.5) if k.points > 0 else Color(1, 0.5, 0.4)), 1.2)
		if not _st_bot:
			if k.points >= 9:
				_robin.react("carreau")
			elif k.points == 0:
				_robin.react("oups")
	elif not k.bounced:
		_announce("Raté", Color(1, 0.5, 0.4), 1.2)
		if not _st_bot:
			_robin.react("oups")
	_update_scoreboard()
	state = State.PAUSE
	_timer = 0.8 if not _selftest else 0.05
	_pause_next = "next_knife"


func _after_pause() -> void:
	match _pause_next:
		"next_knife":
			_next_knife()
		"retrieve":
			_retrieve_and_continue()


func _next_knife() -> void:
	if is_mobile() and _total >= MOBILE_TOTAL:
		_end_mobile()
		return
	if _left > 0:
		_begin_ready()
		return
	if is_training():
		_best_round = maxi(_best_round, _round_pts)
		if _round_pts > _stat("best_round"):
			_save.set_value("records", "best_round", _round_pts)
			_save.save(SAVE_PATH)
		_announce("Manche : %d" % _round_pts, Color(1, 0.8, 0.2), 2.0)
		_update_scoreboard()
		state = State.PAUSE
		_pause_next = "retrieve"
		_timer = 2.2 if not _selftest else 0.05
		return
	if is_mobile():
		state = State.PAUSE
		_pause_next = "retrieve"
		_timer = 1.4 if not _selftest else 0.05
		return
	state = State.AI_TURN
	_timer = 1.2 if not _selftest else 0.05
	_announce("Robin lance…", CLR_AI, 1.2)


func _retrieve_and_continue() -> void:
	_clear_knives()
	_build_knives()
	_round_pts = 0
	_left = PER_ROUND
	if is_contest():
		_round += 1
		if _round >= int(settings["rounds"]):
			_end_contest()
			return
	_begin_ready()


func _begin_ready() -> void:
	state = State.READY
	if not _st_bot:
		_hint.text = "Prends un couteau sur la table (gâchette ou grip),\nlance-le d'un geste vers le rondin et relâche"
	_update_scoreboard()


func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


func _ai_round() -> void:
	var sg: float = float(_level()["sigma"]) * _face_r
	var noise: float = _level()["noise"]
	var total := 0
	for i in PER_ROUND:
		var off := Vector2(_gauss(), _gauss()) * sg
		var err := absf(_gauss() * noise * 0.5)
		var pts := 0
		var stuck := err <= TOL_DEG and off.length() <= _face_r + LOG_EXTRA
		if stuck:
			pts = ring_points(off.length(), _face_r)
			var k := Knife.new()
			k.node = _make_knife_node()
			_target.add_child(k.node)
			k.node.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(off.x, off.y, 0.06))
			_knives.append(k)
			Sound.play_at("dart_thud", to_global(Vector3(off.x, TARGET_Y + off.y, -_dist())), -2.0, 0.1)
		total += pts
	scores[1] += total
	_announce("Robin : %d" % total, CLR_AI, 2.0)
	_update_scoreboard()
	if not _st_bot:
		_robin.react("pointe" if total >= 18 else "oups")
	state = State.PAUSE
	_pause_next = "retrieve"
	_timer = 2.4 if not _selftest else 0.05


# ---------------------------------------------------------------- déroulement

func start_match() -> void:
	_clear_knives()
	_build_knives()
	scores = [0, 0]
	_round = 0
	_left = PER_ROUND
	_round_pts = 0
	_best_round = 0
	_total = 0
	_time = 0.0
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
	_announce("%d points sur %d couteaux" % [pts, MOBILE_TOTAL], Color(1, 0.8, 0.2), 3.0)
	_scoreboard.celebrate("win")
	if _selftest:
		return
	await get_tree().create_timer(2.0).timeout
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over("%d points sur %d couteaux" % [pts, MOBILE_TOTAL])


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
	if is_training():
		_scoreboard.set_data("COUTEAU · ENTRAÎNEMENT", ["MANCHE", "RECORD"], [_round_pts, maxi(_stat("best_round"), _best_round)], 0, "Couteaux restants : %d  ·  %s m" % [_left, str(_dist())])
	elif is_mobile():
		_scoreboard.set_data("COUTEAU · RONDIN MOBILE", ["POINTS", "RECORD"], [scores[0], maxi(_stat("best_mobile"), scores[0])], 0, "Couteau %d / %d" % [mini(_total + 1, MOBILE_TOTAL), MOBILE_TOTAL])
	else:
		_scoreboard.set_data("COUTEAU · %s" % lvl, ["VOUS", "ROBIN"], scores, PLAYER if state != State.AI_TURN else AI, "Manche %d / %d  ·  couteaux : %d  ·  %s m" % [mini(_round + 1, int(settings["rounds"])), int(settings["rounds"]), _left, str(_dist())])


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
	if (button == "trigger_click" or button == "grip_click") and state == State.READY and _held == null:
		var k := _nearest_knife(_lpos(hand))
		if k != null:
			_grab(hand, k, button)


func on_button_released(hand: Hand, button: String) -> void:
	if state == State.HELD and hand == _holder_hand and button == _grab_button:
		_release(hand)


func _nearest_knife(at: Vector3) -> Knife:
	var best: Knife = null
	var best_d := GRAB_RADIUS
	for k in _knives:
		if not k.in_holder or k.done:
			continue
		var dd := k.slot.origin.distance_to(at)
		if dd < best_d:
			best_d = dd
			best = k
	return best


func _grab(hand: Hand, k: Knife, button: String) -> void:
	_held = k
	_holder_hand = hand
	_grab_button = button
	hand.clear_history()
	hand.buzz(0.4, 0.05)
	state = State.HELD
	Sound.play_at("grab", to_global(k.pos), -4.0)
	_message_time = 0.0
	_message.visible = false
	_hint.text = ""


func _return_held() -> void:
	if _held != null and is_instance_valid(_held.node):
		_held.node.transform = _held.slot
		_held.pos = _held.slot.origin
	_held = null
	_holder_hand = null
	if state == State.HELD:
		state = State.READY


func _release(hand: Hand) -> void:
	var vw := hand.throw_velocity() * THROW_BOOST
	var v := global_basis.inverse() * vw
	var k := _held
	var from := _lpos(hand)
	if v.length() < MIN_THROW_SPEED or -v.z < 1.5:
		_return_held()
		_announce("Lance plus fort, vers la cible !", Color(0.9, 0.9, 0.9), 1.6)
		return
	_held = null
	_holder_hand = null
	hand.buzz(0.6, 0.08)
	_throw_knife(k, from, v)


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
	var d := float(settings["dist"])
	if not (is_equal_approx(d, 3.0) or is_equal_approx(d, 4.5) or is_equal_approx(d, 6.0)):
		settings["dist"] = 4.5
	if int(settings["rounds"]) not in [3, 5]:
		settings["rounds"] = 3


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


func _next_ready_knife() -> Knife:
	for k in _knives:
		if k.in_holder and not k.done:
			return k
	return null


## Le joueur virtuel : vise le centre avec une petite erreur, vitesse avant 10 m/s.
func _bot_throw() -> void:
	var k := _next_ready_knife()
	if k == null:
		return
	var from := Vector3(0.2, 1.2, -0.4)
	var sg := 0.12 * _face_r
	var vf := 10.0
	var t := (from.z + _dist()) / vf
	var tgt := Vector3(target_x_at(_time + t) + _gauss() * sg, TARGET_Y + _gauss() * sg, -_dist())
	_throw_knife(k, from, ideal_velocity(from, tgt, vf))


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["dist"] = 4.5
	settings["rounds"] = 3
	_apply_layout()
	_st_bot = false
	_time = 0.0

	# A. Barème : 10 zones de largeur égale
	var fr := _face_r
	_st_check("barème", ring_points(0.0, fr) == 10 and ring_points(fr * 0.05, fr) == 10 and ring_points(fr * 0.15, fr) == 9 and ring_points(fr * 0.55, fr) == 5 and ring_points(fr * 0.95, fr) == 1 and ring_points(fr * 1.1, fr) == 0, "")

	# B. Lancer droit sur le centre, bien orienté : planté, 9 ou 10 points (3 m et 6 m)
	var from := Vector3(0.2, 1.2, -0.4)
	for d in [3.0, 6.0]:
		settings["dist"] = d
		_apply_layout()
		state = State.READY
		_left = PER_ROUND
		_test_err = 0.0
		var k := _next_ready_knife()
		var tgt := Vector3(0, TARGET_Y, -d)
		var ok := _throw_knife(k, from, ideal_velocity(from, tgt, 10.0) - Vector3(0, 0, 0))
		await _wait_frames(70)
		_st_check("couteau planté à %s m" % str(d), ok and k.in_target and k.points >= 9, "(%d pts)" % k.points)
		state = State.PAUSE
		_pause_next = "none"
	settings["dist"] = 4.5
	_apply_layout()

	# C. Mauvaise orientation : le couteau rebondit, 0 point, pas planté
	state = State.READY
	_left = PER_ROUND
	_test_err = 90.0
	var k2 := _next_ready_knife()
	_throw_knife(k2, from, ideal_velocity(from, Vector3(0, TARGET_Y, -4.5), 10.0))
	await _wait_frames(90)
	_st_check("couteau mal orienté rebondit", k2.bounced and not k2.in_target and k2.points == 0, "")
	state = State.PAUSE
	_pause_next = "none"

	# D. Lancer trop faible refusé, la gravité fait tomber un lancer court
	state = State.READY
	_test_err = 0.0
	var k3 := _next_ready_knife()
	_st_check("lancer trop faible refusé", not _throw_knife(k3, from, Vector3(0, 0.5, -1.0)), "")
	var k4 := _next_ready_knife()
	_throw_knife(k4, from, Vector3(0, 0.5, -3.0))
	await _wait_frames(120)
	_st_check("lancer court tombe", k4.done and not k4.in_target and k4.points == 0, "")
	state = State.PAUSE
	_pause_next = "none"

	# E. L'aide rapproche un lancer imprécis du centre
	var off_v := ideal_velocity(from, Vector3(0.4, TARGET_Y + 0.3, -4.5), 10.0)
	var assisted := _apply_assist(from, off_v)
	var t_fl := (from.z + 4.5) / 10.0
	var hit_raw := Vector2(from.x + off_v.x * t_fl, from.y + off_v.y * t_fl - 0.5 * GRAVITY * t_fl * t_fl)
	var hit_as := Vector2(from.x + assisted.x * t_fl, from.y + assisted.y * t_fl - 0.5 * GRAVITY * t_fl * t_fl)
	var cen := Vector2(0, TARGET_Y)
	_st_check("aide à la visée", hit_as.distance_to(cen) < hit_raw.distance_to(cen) - 0.1, "(%.2f -> %.2f m)" % [hit_raw.distance_to(cen), hit_as.distance_to(cen)])
	_clear_knives()
	_test_err = 999.0

	# F. Parties complètes avec le joueur virtuel
	for lv in ["facile", "normal", "expert"]:
		settings["level"] = lv
		settings["mode"] = "ordi"
		settings["rounds"] = 3
		_apply_layout()
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 400:
			await get_tree().physics_frame
			guard += 1
		_st_check("concours %s terminé" % lv, state == State.GAME_OVER and scores[0] > 0 and scores[1] > 0, "%s en %.0f s" % [str(scores), guard / 90.0])
	settings["level"] = "normal"
	settings["mode"] = "mobile"
	_apply_layout()
	_st_bot = true
	start_match()
	var g2 := 0
	while state != State.GAME_OVER and g2 < 90 * 400:
		await get_tree().physics_frame
		g2 += 1
	_st_check("rondin mobile terminé", state == State.GAME_OVER and scores[0] > 0, "(%d pts en %.0f s)" % [scores[0], g2 / 90.0])
	settings["mode"] = "training"
	_apply_layout()
	_st_bot = true
	start_match()
	var g3 := 0
	while not (_left == 0 and state == State.PAUSE and _pause_next == "retrieve"):
		await get_tree().physics_frame
		g3 += 1
		if g3 > 90 * 60:
			break
	_st_check("entraînement : une manche", _round_pts > 0 and g3 <= 90 * 60, "(%d pts)" % _round_pts)

	_st_bot = false
	_clear_knives()
	for l in _st_log:
		print("SELFTEST couteau ", l)
	var okk := _st_failures.is_empty()
	print("SELFTEST couteau=", "OK" if okk else "ECHEC")
	selftest_finished.emit(okk)
