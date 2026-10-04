class_name BallTrapGame
extends Node3D
## Ball-trap en réalité augmentée. Fusil à l'épaule (main de tir + autre main devant pour
## stabiliser), on crie « Pull ! » et un plateau d'argile part : on tire en anticipant sa course
## (deux cartouches par plateau : touché au 1er coup = 2 points, au 2e = 1 point).
## Trois parcours : fosse, skeet, parcours de chasse. On joue contre Robin.
## Le noeud est aux pieds du joueur ; le terrain est à -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const GRAVITY := 9.81
const SHOT_SPEED := 350.0
const SHOT_RANGE := 70.0
const CLAY_R := 0.13
const SHOT_GAP := 0.35
const MUZZLE := 0.8
const SAVE_PATH := "user://balltrap.cfg"
const PLAYER := 1
const AI := -1
const CLR_AI := Color(0.95, 0.5, 0.3)

const PARCOURS := {
	"fosse": {"title": "Fosse"},
	"skeet": {"title": "Skeet"},
	"sporting": {"title": "Parcours de chasse"},
}

const LEVELS := {
	"facile": {"title": "Facile", "spread": 0.045, "speed": 0.85, "p1": 0.45},
	"normal": {"title": "Normal", "spread": 0.03, "speed": 1.0, "p1": 0.62},
	"expert": {"title": "Expert", "spread": 0.02, "speed": 1.15, "p1": 0.78},
}

enum State { SETUP, WAIT, FLY, PAUSE, GAME_OVER }


class Shot extends RefCounted:
	var pos := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var dist := 0.0
	var n := 1
	var alive := true


var settings := {"mode": "fosse", "level": "normal", "count": 10, "hand": 1, "music": true}
var state := State.SETUP
var scores := [0, 0]
var _n := 0                       # plateaux déjà tirés
var _shots_left := 2
var _timer := 0.0
var _cd := 0.0
var _pause_next := ""
var _clay_pos := Vector3.ZERO
var _clay_vel := Vector3.ZERO
var _clay_age := 0.0
var _clay_alive := false
var _clay_node: Node3D
var _clay_hit_shot := 0
var _shots: Array[Shot] = []
var _hits := 0
var _last_pts := 0
var _hold := false                # test : fige la partie après un plateau

var _hands: Array = []
var _scene: Node3D
var _fx_root: Node3D
var _gun: Node3D
var _flash: MeshInstance3D
var _flash_t := 0.0
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
	_clay_node = _make_clay()
	_clay_node.visible = false
	add_child(_clay_node)
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
	_panel.accent = Color(0.95, 0.6, 0.15)
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


func _level() -> Dictionary:
	return LEVELS[settings["level"]]


func _apply_layout() -> void:
	_build_field()
	_scoreboard.position = Vector3(2.2, 1.5, -1.6)
	_scoreboard.scale = Vector3.ONE * 1.1
	var face := Vector3(0, 0, 1.0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_robin.position = Vector3(-1.6, 0, -0.6)
	_robin.rotation.y = deg_to_rad(40.0)
	_message.position = Vector3(0, 2.0, -3.0)
	_hint.position = Vector3(0, 1.3, -0.5)


func _grass_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for x in s:
		for y in s:
			var v := 0.5 + rng.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, Color(0.22 * v * 1.6, 0.46 * v * 1.4, 0.14 * v * 1.5))
	return ImageTexture.create_from_image(img)


func _build_field() -> void:
	for c in _scene.get_children():
		c.queue_free()
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_texture()
	gm.uv1_scale = Vector3(8, 12, 1.0)
	gm.roughness = 0.95
	_scene.add_child(BowlingArt.floor_quad(26.0, 32.0, gm, Vector3(0, 0.001, -12.0)))
	var concrete := BowlingArt.mat(Color(0.55, 0.55, 0.52), 0.9)
	_scene.add_child(BowlingArt.cylinder(0.9, 0.9, 0.04, concrete, Vector3(0, 0.02, 0), 24))
	# lisière d'arbres au fond et sur les côtés
	for i in 10:
		for sx in [-1.0, 1.0]:
			var t := Decor.tree(3.4 + 0.5 * ((i + int(sx)) % 3), 61 + i * 2 + (1 if sx > 0 else 0))
			t.position = Vector3(sx * (13.0 + 0.8 * (i % 3)), 0, 2.0 - i * 3.2)
			_scene.add_child(t)
	for i in 9:
		var t2 := Decor.tree(3.6 + 0.5 * (i % 3), 91 + i)
		t2.position = Vector3(-12.0 + i * 3.0, 0, -30.0 - 1.0 * (i % 2))
		_scene.add_child(t2)
	var dark := BowlingArt.mat(Color(0.3, 0.3, 0.33), 0.8)
	var amber := BowlingArt.mat(Color(0.85, 0.55, 0.15), 0.6)
	match settings["mode"]:
		"fosse":
			_scene.add_child(BowlingArt.box(Vector3(2.2, 0.35, 1.4), dark, Vector3(0, 0.12, -8.0)))
			_scene.add_child(BowlingArt.box(Vector3(0.6, 0.12, 0.6), amber, Vector3(0, 0.34, -8.0)))
		"skeet":
			_scene.add_child(BowlingArt.box(Vector3(1.6, 3.0, 1.6), dark, Vector3(-9.6, 1.5, -7.0)))
			_scene.add_child(BowlingArt.box(Vector3(0.8, 0.2, 0.7), amber, Vector3(-9.0, 3.05, -7.0)))
			_scene.add_child(BowlingArt.box(Vector3(1.6, 1.2, 1.6), dark, Vector3(9.6, 0.6, -7.0)))
			_scene.add_child(BowlingArt.box(Vector3(0.8, 0.2, 0.7), amber, Vector3(9.0, 1.25, -7.0)))
		_:
			for p in [Vector3(0, 0.2, -12), Vector3(-9.0, 0.2, -8.0), Vector3(5.0, 0.2, -16.0), Vector3(-5.0, 0.2, -16.0)]:
				_scene.add_child(BowlingArt.box(Vector3(1.2, 0.45, 1.2), dark, p))
				_scene.add_child(BowlingArt.box(Vector3(0.5, 0.1, 0.5), amber, p + Vector3(0, 0.27, 0)))
	var sign_node := Decor.neon_sign("BALL-TRAP", Color(1.0, 0.65, 0.2), 1.8, 0.5)
	sign_node.position = Vector3(0, 3.2, -22.0)
	sign_node.scale = Vector3.ONE * 2.5
	_scene.add_child(sign_node)


func _make_clay() -> Node3D:
	var n := Node3D.new()
	var disc := BowlingArt.cylinder(0.11, 0.09, 0.035, BowlingArt.glow(Color(1.0, 0.45, 0.08), 0.9), Vector3.ZERO, 16)
	n.add_child(disc)
	n.add_child(BowlingArt.cylinder(0.06, 0.07, 0.03, BowlingArt.glow(Color(1.0, 0.7, 0.2), 0.9), Vector3(0, 0.02, 0), 12))
	n.scale = Vector3.ONE * 1.6
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
	_clear_clay()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Ball-trap", "Victoires : %d   ·   records : fosse %d · skeet %d · chasse %d" % [_stat("wins"), _stat("best_fosse"), _stat("best_skeet"), _stat("best_sporting")])
	_panel.add_row("Parcours", [
		{"id": "mode_fosse", "text": "Fosse", "width": 0.18, "selected": settings["mode"] == "fosse"},
		{"id": "mode_skeet", "text": "Skeet", "width": 0.18, "selected": settings["mode"] == "skeet"},
		{"id": "mode_sporting", "text": "Chasse", "width": 0.2, "selected": settings["mode"] == "sporting"},
	])
	var row: Array = []
	for l in ["facile", "normal", "expert"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	_panel.add_row("Plateaux", [
		{"id": "count_10", "text": "10", "width": 0.14, "selected": settings["count"] == 10},
		{"id": "count_25", "text": "25", "width": 0.14, "selected": settings["count"] == 25},
	])
	_panel.add_row("Fusil en main", [
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
	elif id.begins_with("count_"):
		settings["count"] = int(id.substr(6))
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


# ================================================================ le fusil

func _build_gun() -> void:
	_gun = Node3D.new()
	add_child(_gun)
	_gun.add_child(GunArt.build(true, VisualStyle.detailed))
	_gun.visible = false
	_flash = BowlingArt.sphere(0.08, BowlingArt.unshaded(Color(1.0, 0.85, 0.4, 0.9)), Vector3(0, 0.012, -MUZZLE), 8)
	_flash.visible = false
	_gun.add_child(_flash)


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


func _aim() -> Dictionary:
	var mh := _main_hand()
	if mh == null or not is_instance_valid(mh):
		return {"pos": Vector3(0.2, 1.4, -0.1), "dir": Vector3(0, 0, -1), "up": Vector3.UP}
	var mp := _hpos(mh)
	var mb := _hbasis(mh)
	var dir := -mb.z
	var oh := _off_hand()
	if oh != null and is_instance_valid(oh):
		var d := _hpos(oh) - mp
		var l := d.length()
		if l > 0.2 and l < 0.8 and d.normalized().dot(dir) > 0.6:
			dir = d / l
	return {"pos": mp, "dir": dir, "up": mb.y}


func _update_gun() -> void:
	var show := state != State.SETUP and state != State.GAME_OVER and not _panel.visible
	_gun.visible = show
	if not show:
		return
	var a := _aim()
	var dir: Vector3 = a["dir"]
	var up: Vector3 = a["up"]
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.UP
	_gun.transform = Transform3D(Basis.looking_at(dir, up), a["pos"])


# ================================================================ plateau et cartouches

func _launch_params() -> Dictionary:
	var sp: float = _level()["speed"]
	var from := Vector3.ZERO
	var vel := Vector3.ZERO
	var kind: String = settings["mode"]
	if kind == "sporting":
		kind = ["away", "cross", "incoming"][randi() % 3]
	match kind:
		"fosse", "away":
			var az := deg_to_rad(randf_range(-35.0, 35.0))
			var el := deg_to_rad(randf_range(18.0, 32.0))
			var speed := randf_range(15.0, 18.0) * sp
			from = Vector3(0, 0.45, -8.0) if kind == "fosse" else Vector3(0, 0.5, -12.0)
			vel = Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)) * speed
		"skeet", "cross":
			var side := 1.0 if randf() < 0.5 else -1.0
			var high := side < 0.0
			from = Vector3(-side * 9.0, 3.2 if high else 1.3, -7.0)
			if kind == "cross":
				from = Vector3(-side * 9.0, 0.6, -9.0)
			var target := Vector3(side * 0.5, 3.8 + randf_range(-0.4, 0.4), -8.5)
			vel = (target - from).normalized() * 17.0 * sp
		_:
			var side2 := 1.0 if randf() < 0.5 else -1.0
			from = Vector3(side2 * 5.0, 0.5, -16.0)
			var target2 := Vector3(-side2 * 1.5, 4.5, -2.5)
			vel = (target2 - from).normalized() * 19.0 * sp
	return {"from": from, "vel": vel}


func _launch() -> void:
	var lp := _launch_params()
	_clay_pos = lp["from"]
	_clay_vel = lp["vel"]
	_spawn_clay()


func _spawn_clay() -> void:
	_clay_age = 0.0
	_clay_alive = true
	_clay_hit_shot = 0
	_clay_node.position = _clay_pos
	_clay_node.visible = true
	state = State.FLY
	_shots_left = 2
	_cd = 0.0
	_announce("Pull !", Color(1, 0.8, 0.2), 0.8)
	_hint.text = ""
	Sound.play_at("whoosh", to_global(_clay_pos), -4.0, 0.1)


func _clear_clay() -> void:
	_clay_alive = false
	if _clay_node:
		_clay_node.visible = false
	_shots.clear()


## Tire une cartouche. Renvoie false si on ne peut pas.
func _shoot(mp: Vector3, dir: Vector3) -> bool:
	if state != State.FLY or _shots_left <= 0 or _cd > 0.0 or not _clay_alive:
		return false
	var s := Shot.new()
	var d := dir.normalized()
	s.pos = mp + d * MUZZLE
	s.dir = d
	s.n = 3 - _shots_left
	_shots.append(s)
	_shots_left -= 1
	_cd = SHOT_GAP
	_flash_t = 0.06
	_flash.visible = true
	Sound.play_at("shotgun", to_global(s.pos), 0.0, 0.05)
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(1.0, 0.15)
	_update_scoreboard()
	return true


func _step_shot(s: Shot, dt: float) -> void:
	var spread: float = _level()["spread"]
	var sub := 4
	var h := dt / sub
	for i in sub:
		var pv := s.pos
		var step := s.dir * SHOT_SPEED * h
		s.pos += step
		s.dist += step.length()
		if _clay_alive:
			var seg := s.pos - pv
			var t := clampf((_clay_pos - pv).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
			var closest := pv + seg * t
			var reach := CLAY_R + spread * s.dist
			if closest.distance_to(_clay_pos) <= reach:
				_clay_hit(s)
				s.alive = false
				return
		if s.dist > SHOT_RANGE:
			s.alive = false
			return


func _clay_hit(s: Shot) -> void:
	_clay_alive = false
	_clay_hit_shot = s.n
	_clay_node.visible = false
	_burst(_clay_pos)
	Sound.play_at("clay_break", to_global(_clay_pos), 0.0, 0.08)


func _burst(pos: Vector3) -> void:
	for i in 9:
		var f := BowlingArt.box(Vector3(0.04, 0.012, 0.04), BowlingArt.glow(Color(1.0, 0.5, 0.1), 0.9), pos)
		f.rotation = Vector3(randf() * 3.0, randf() * 3.0, randf() * 3.0)
		_fx_root.add_child(f)
		var v := Vector3(randf_range(-1, 1), randf_range(0.2, 1.5), randf_range(-1, 1)) * 1.4
		var tw_ := create_tween()
		tw_.set_parallel(true)
		tw_.tween_property(f, "position", pos + v * 0.9 + Vector3(0, -0.8, 0), 0.9)
		tw_.tween_property(f, "scale", Vector3.ZERO, 0.9).set_delay(0.3)
		tw_.chain().tween_callback(f.queue_free)
	var puff := BowlingArt.sphere(0.25, BowlingArt.unshaded(Color(0.9, 0.9, 0.85, 0.5)), pos, 8)
	_fx_root.add_child(puff)
	var tp := create_tween()
	tp.set_parallel(true)
	tp.tween_property(puff, "scale", Vector3.ONE * 2.2, 0.5)
	tp.tween_property(puff, "transparency", 1.0, 0.5)
	tp.chain().tween_callback(puff.queue_free)


# ================================================================ boucle

func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.visible = false
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	if _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)
		return
	_cd = maxf(0.0, _cd - delta)
	if not _st_bot:
		_update_gun()
	if _clay_alive:
		_clay_age += delta
		_clay_vel.y -= GRAVITY * delta
		_clay_vel *= 1.0 - 0.1 * delta
		_clay_pos += _clay_vel * delta
		_clay_node.position = _clay_pos
		_clay_node.rotation.y += 12.0 * delta
	for i in range(_shots.size() - 1, -1, -1):
		var s := _shots[i]
		if s.alive:
			_step_shot(s, delta)
		if not s.alive:
			_shots.remove_at(i)
	match state:
		State.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_launch()
		State.FLY:
			if _st_bot:
				_bot_shoot()
			if not _clay_alive and _clay_hit_shot > 0:
				_end_clay(true)
			elif _clay_alive and (_clay_pos.y <= 0.05 or _clay_age > 7.0):
				_clay_alive = false
				_clay_node.visible = false
				_end_clay(false)
			elif _clay_alive and _shots_left <= 0 and _shots.is_empty() and _cd <= 0.0:
				# plus de cartouche : on laisse finir la course du plateau
				pass
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0 and not _hold:
				_next_clay()


func _end_clay(hit: bool) -> void:
	var pts := 0
	if hit:
		pts = 2 if _clay_hit_shot == 1 else 1
		_hits += 1
	_last_pts = pts
	scores[0] += pts
	if hit:
		_announce("Touché ! +%d" % pts, Color(1.0, 0.85, 0.2) if pts == 2 else Color(0.5, 1, 0.5), 1.0)
		if not _st_bot and pts == 2:
			_robin.react("carreau")
	else:
		_announce("Raté", Color(1, 0.5, 0.4), 1.0)
		if not _st_bot:
			_robin.react("oups")
	# Robin tire le même plateau
	var p1: float = _level()["p1"]
	var rp := 0
	if randf() < p1:
		rp = 2
	elif randf() < 0.5:
		rp = 1
	scores[1] += rp
	_n += 1
	_update_scoreboard()
	state = State.PAUSE
	_timer = 1.4 if not _selftest else 0.05


func _next_clay() -> void:
	if _n >= int(settings["count"]):
		_end_match()
		return
	_begin_wait()


func _begin_wait() -> void:
	state = State.WAIT
	_timer = randf_range(1.2, 2.4) if not _selftest else 0.1
	if not _st_bot:
		_hint.text = "Fusil à l'épaule, vise devant le plateau.\nGâchette = une cartouche (2 par plateau)"
	_update_scoreboard()


func start_match() -> void:
	_clear_clay()
	scores = [0, 0]
	_n = 0
	_hits = 0
	_last_pts = 0
	_begin_wait()


func _end_match() -> void:
	state = State.GAME_OVER
	var key := "best_" + String(settings["mode"])
	var rec: bool = scores[0] > _stat(key)
	if rec:
		_save.set_value("records", key, scores[0])
		_save.save(SAVE_PATH)
	var win: bool = scores[0] > scores[1]
	var summary := "Vous %d – %d Robin  (%d / %d touchés)" % [scores[0], scores[1], _hits, int(settings["count"])]
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
	if not is_inside_tree():
		return
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary + ("  ·  nouveau record !" if rec else ""))


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
	var title := String(PARCOURS[settings["mode"]]["title"]).to_upper()
	_scoreboard.set_data("BALL-TRAP · %s" % title, ["VOUS", "ROBIN"], scores, PLAYER, "Plateau %d / %d  ·  cartouches : %d  ·  %s" % [mini(_n + 1, int(settings["count"])), int(settings["count"]), _shots_left if state == State.FLY else 2, String(_level()["title"])])


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
	if not PARCOURS.has(settings["mode"]):
		settings["mode"] = "fosse"
	if int(settings["count"]) not in [10, 25]:
		settings["count"] = 10
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


func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


## Point où viser pour toucher le plateau depuis `from` (anticipation de sa course).
func lead_point(from: Vector3) -> Vector3:
	var tt := 0.0
	var p := _clay_pos
	for i in 4:
		p = _clay_pos + _clay_vel * tt + Vector3(0, -0.5 * GRAVITY * tt * tt, 0)
		tt = (p - from).length() / SHOT_SPEED
	return p


func _bot_shoot() -> void:
	if _cd > 0.0 or _shots_left <= 0 or not _clay_alive or _clay_age < 0.25:
		return
	var from := Vector3(0.2, 1.4, -0.1)
	var tgt := lead_point(from) + Vector3(_gauss(), _gauss(), _gauss()) * 0.05
	_shoot(from, (tgt - from).normalized())


func _fresh_clay(pos: Vector3, vel: Vector3) -> void:
	_clear_clay()
	_clay_pos = pos
	_clay_vel = vel
	_spawn_clay()


func _selftest_run() -> void:
	settings["mode"] = "fosse"
	settings["level"] = "normal"
	settings["count"] = 10
	_apply_layout()
	_st_bot = false
	scores = [0, 0]
	_n = 0
	var from := Vector3(0.2, 1.4, -0.1)
	_hold = true

	# A. Plateau immobile : tir droit dessus = touché au 1er coup (2 points)
	_fresh_clay(Vector3(1.0, 3.0, -15.0), Vector3.ZERO)
	_clay_vel = Vector3(0, GRAVITY * 0.0, 0)
	var tgt := _clay_pos
	_shoot(from, (tgt - from).normalized())
	await _wait_frames(30)
	_st_check("plateau touché au 1er coup", _clay_hit_shot == 1 and not _clay_alive, "")
	state = State.PAUSE
	_clear_clay()

	# B. Plateau en mouvement : viser devant touche, viser sur la position actuelle rate
	var lp := _launch_params_fixed()
	_fresh_clay(lp["from"], lp["vel"])
	await _wait_frames(20)
	var lead := lead_point(from)
	_shoot(from, (lead - from).normalized())
	await _wait_frames(20)
	_st_check("tir avec anticipation", _clay_hit_shot == 1, "")
	state = State.PAUSE
	_clear_clay()
	_fresh_clay(lp["from"], lp["vel"])
	await _wait_frames(20)
	var behind := _clay_pos - _clay_vel.normalized() * 6.0
	_shoot(from, (behind - from).normalized())
	await _wait_frames(15)
	_st_check("tir derrière le plateau raté", _clay_hit_shot == 0 and _shots_left == 1, "")

	# C. Deuxième cartouche : touche après un premier coup raté = 1 point
	await _wait_frames(15)
	_cd = 0.0
	var before: int = scores[0]
	var lead2 := lead_point(from)
	_shoot(from, (lead2 - from).normalized())
	await _wait_frames(30)
	_st_check("2e cartouche", _clay_hit_shot == 2, "(coup %d)" % _clay_hit_shot)
	_st_check("points du 2e coup", scores[0] == before + 1 and state == State.PAUSE, "(%d)" % (scores[0] - before))
	_clear_clay()

	# D. Pas de tir sans plateau, ni de 3e cartouche
	state = State.WAIT
	_st_check("pas de tir sans plateau", not _shoot(from, Vector3(0, 0, -1)), "")
	_fresh_clay(Vector3(0, 3.0, -30.0), Vector3(0, 0, -1.0))
	_cd = 0.0
	_shoot(from, Vector3(1, 0, 0))
	_cd = 0.0
	_shoot(from, Vector3(-1, 0, 0))
	_cd = 0.0
	_st_check("pas de 3e cartouche", not _shoot(from, Vector3(0, 0, -1)) and _shots_left == 0, "")
	_clear_clay()
	state = State.WAIT

	_hold = false

	# E. Parties complètes avec le joueur virtuel, sur chaque parcours et niveau
	for combo in [["fosse", "facile"], ["skeet", "normal"], ["sporting", "expert"]]:
		settings["mode"] = combo[0]
		settings["level"] = combo[1]
		settings["count"] = 10
		_apply_layout()
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 400:
			await get_tree().physics_frame
			guard += 1
		_st_check("parcours %s (%s) terminé" % [combo[0], combo[1]], state == State.GAME_OVER and _hits >= 6 and _n == 10, "%s, %d touchés en %.0f s" % [str(scores), _hits, guard / 90.0])

	_st_bot = false
	_clear_clay()
	for l in _st_log:
		print("SELFTEST balltrap ", l)
	var ok := _st_failures.is_empty()
	print("SELFTEST balltrap=", "OK" if ok else "ECHEC")
	selftest_finished.emit(ok)


## Lancer fixe pour le test (traversée gauche -> droite).
func _launch_params_fixed() -> Dictionary:
	var from := Vector3(-9.0, 2.0, -7.0)
	var target := Vector3(0.5, 3.8, -8.5)
	return {"from": from, "vel": (target - from).normalized() * 17.0}
