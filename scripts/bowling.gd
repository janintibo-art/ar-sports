class_name BowlingGame
extends Node3D
## Bowling en réalité augmentée : piste en bois posée sur le sol réel, de 1 à 4
## joueurs à tour de rôle, trois modes, tableau des scores, bruitages, musique,
## décor (table, bières, deux spectateurs).
## Le noeud est placé aux pieds du joueur ; la piste part vers -Z (devant lui).

signal exit_requested
signal switch_requested
signal selftest_finished

const LANE_W := 1.05
const GUTTER_W := 0.13
const FOUL_Z := -0.5
const HEADPIN_Z := -4.4
const PIN_SPACING_X := 0.3048
const PIN_SPACING_Z := 0.2635
const PIN_HEIGHT := 0.38
const PIN_RADIUS := 0.0605
const BALL_RADIUS := 0.109
const DECK_END := HEADPIN_Z - 3.0 * PIN_SPACING_Z - 0.35
const BALL_REST := Vector3(0.42, 0.93, -0.22)
const THROW_BOOST := 1.4
const MIN_THROW_SPEED := 0.9
const ROLL_TIMEOUT := 7.0
const SETTLE_TIME := 2.2

const LAYER_WORLD := 1
const LAYER_PINS := 4
const LAYER_BALL := 8

const PLAYER_COLORS := [
	Color(0.15, 0.38, 0.95), Color(0.92, 0.2, 0.22), Color(0.15, 0.72, 0.35), Color(0.96, 0.6, 0.1),
]
const MODES := {
	"classique": {"title": "Classique", "frames": 10},
	"rapide": {"title": "Rapide", "frames": 5},
	"entrainement": {"title": "Entraînement", "frames": 0},
}
const SAVE_PATH := "user://bowling.cfg"

enum State { SETUP, RESETTING, READY, HELD, ROLLING, SETTLING, GAME_OVER }

var settings := {"players": 1, "mode": "classique", "bumpers": true, "decor": true, "music": true}
var state := State.SETUP
var players: Array = []
var current := 0
var frame_index := 0

var _hands: Array = []
var _pins: Array[RigidBody3D] = []
var _pin_blobs: Array[MeshInstance3D] = []
var _pin_spots: Array[Vector3] = []
var _standing: Array[int] = []
var _ball: RigidBody3D
var _ball_mesh: MeshInstance3D
var _ball_blob: MeshInstance3D
var _roll_sound: AudioStreamPlayer3D
var _holder: Hand = null
var _thrower: Hand = null
var _timer := 0.0
var _slow_time := 0.0
var _ball_hit_pins := false
var _in_gutter := false
var _landed := false
var _rack_first := true
var _hit_cooldown := {}

var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _scoreboard: Scoreboard
var _sign: NeonSign
var _hud: Label3D
var _message: Label3D
var _message_time := 0.0
var _bumpers: Array[StaticBody3D] = []
var _decor: Node3D
var _spectators: Array[Spectator] = []
var _mugs: Array[BeerMug] = []
var _held_mugs := {}            # Hand -> BeerMug
var _cheers_cooldown := 0.0
var _save := ConfigFile.new()

var _selftest := false
var _selftest_plan: Array = []
var _selftest_throws := 0
var _selftest_log: Array = []
var _selftest_events := {}


# ================================================================ mise en place

func set_hands(left: Hand, right: Hand) -> void:
	_hands = [left, right]


func _ready() -> void:
	_load_save()
	_compute_pin_spots()
	_build_lane()
	_build_ball()
	_build_decor()
	_scoreboard = Scoreboard.new()
	_scoreboard.position = Vector3(0, 1.95, DECK_END - 0.25)
	_scoreboard.rotation_degrees = Vector3(-8, 0, 0)
	add_child(_scoreboard)
	_hud = BowlingArt.label("", 0.055)
	_hud.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hud.position = BALL_REST + Vector3(0, 0.36, 0)
	add_child(_hud)
	_message = BowlingArt.label("", 0.085, Color(1, 0.95, 0.7))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.position = Vector3(0, 1.2, -1.3)
	_message.no_depth_test = true
	add_child(_message)
	_panel = UiPanel.new()
	_panel.accent = Color(1.0, 0.25, 0.65)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)

	Sound.music_enabled = settings["music"]
	Sound.start_music()
	_apply_settings()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


## Replace la piste devant le joueur (pieds au sol, face au regard).
func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if state in [State.READY, State.SETUP, State.GAME_OVER]:
		_respot_pins_instant()
		_ball_to_rest()
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


# ================================================================ panneaux

func show_setup() -> void:
	state = State.SETUP
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Bowling", "Record classique : %d   ·   rapide : %d" % [_record("classique"), _record("rapide")])
	var row: Array = []
	for n in 4:
		row.append({"id": "players_%d" % (n + 1), "text": str(n + 1), "width": 0.1, "selected": settings["players"] == n + 1})
	_panel.add_row("Joueurs", row)
	row = []
	for m in ["classique", "rapide", "entrainement"]:
		row.append({"id": "mode_" + m, "text": MODES[m]["title"], "width": 0.24, "selected": settings["mode"] == m})
	_panel.add_row("Mode", row)
	for opt in [["bumpers", "Bumpers"], ["decor", "Décor"], ["music", "Musique"]]:
		_panel.add_row(opt[1], [
			{"id": opt[0] + "_on", "text": "Oui", "width": 0.13, "selected": settings[opt[0]]},
			{"id": opt[0] + "_off", "text": "Non", "width": 0.13, "selected": not settings[opt[0]]},
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
	_panel.add_row("", [{"id": "resume", "text": "Reprendre", "width": 0.32, "color": Color(0.15, 0.6, 0.25)}])
	_panel.add_row("", [{"id": "restart", "text": "Recommencer", "width": 0.32}])
	_panel.add_row("", [{"id": "settings", "text": "Réglages", "width": 0.32}])
	_panel.add_row("", [{"id": "switch", "text": "Changer de jeu", "width": 0.32, "color": Color(0.2, 0.4, 0.75)}])
	_panel.add_row("", [{"id": "menu", "text": "Menu principal", "width": 0.32, "color": Color(0.35, 0.35, 0.4)}])
	_open_panel()


func show_game_over(summary: String) -> void:
	_panel_page = "over"
	_panel.clear()
	_panel.set_title("Partie terminée", summary)
	_panel.add_row("", [
		{"id": "settings", "text": "Réglages", "width": 0.22},
		{"id": "restart", "text": "Rejouer", "width": 0.26, "color": Color(0.15, 0.6, 0.25)},
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


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("players_"):
		settings["players"] = int(id.substr(8))
	elif id.begins_with("mode_"):
		settings["mode"] = id.substr(5)
	elif id.ends_with("_on") or id.ends_with("_off"):
		var key := id.substr(0, id.rfind("_"))
		settings[key] = id.ends_with("_on")
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
	_apply_settings()
	_save_settings()
	show_setup()


func _apply_settings() -> void:
	for b in _bumpers:
		b.visible = settings["bumpers"]
		b.collision_layer = LAYER_WORLD if settings["bumpers"] else 0
	_decor.visible = settings["decor"]
	_decor.process_mode = Node.PROCESS_MODE_INHERIT if settings["decor"] else Node.PROCESS_MODE_DISABLED
	Sound.music_enabled = settings["music"]


func _set_lasers(on: bool) -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = on


# ================================================================ partie

func is_training() -> bool:
	return settings["mode"] == "entrainement"


func n_frames() -> int:
	return int(MODES[settings["mode"]]["frames"])


func start_match() -> void:
	players.clear()
	for i in settings["players"]:
		players.append({
			"name": "Joueur %d" % (i + 1),
			"color": PLAYER_COLORS[i],
			"frames": [[]],
			"stats": {"throws": 0, "strikes": 0, "pins": 0, "last": 0},
		})
	current = 0
	frame_index = 0
	_apply_settings()
	for p in players:
		p["streak"] = 0
	var mode: String = settings["mode"]
	var title := "AR BOWLING · " + String(MODES[mode]["title"]).to_upper()
	var record := "" if is_training() else "RECORD  %d" % _record(mode)
	_scoreboard.build(players.size(), n_frames(), is_training(), title, record)
	# Le tableau monte avec le nombre de joueurs pour rester au-dessus de l'enseigne
	_scoreboard.position.y = 1.47 + Scoreboard.HEAD_H / 2.0 + Scoreboard.ROW_H * players.size() + 0.05
	_begin_turn(false)


func _begin_turn(announce: bool) -> void:
	_standing = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	_rack_first = true
	var pl: Dictionary = players[current]
	_ball_mesh.material_override = BowlingArt.ball_material(pl["color"])
	_ball_to_rest()
	_reset_pins_animated()
	_refresh_board()
	if announce and players.size() > 1:
		Sound.play("next_player", -6.0)
		show_message("À %s !" % pl["name"], 2.0)
	elif not announce:
		show_message("Gâchette : prendre la boule\nB : pause", 4.0)


func _refresh_board() -> void:
	_scoreboard.refresh(players, current, frame_index)
	var pl: Dictionary = players[current]
	if is_training():
		_hud.text = "%s\nEntraînement" % pl["name"]
	else:
		_hud.text = "%s\nFrame %d/%d · %d pts" % [pl["name"], mini(frame_index + 1, n_frames()), n_frames(), player_total(current)]
	_hud.modulate = (pl["color"] as Color).lightened(0.35)


func player_total(i: int) -> int:
	var rolls: Array = []
	for f in players[i]["frames"]:
		rolls.append_array(f)
	var scores := BowlingGame.frame_scores(rolls, n_frames())
	return 0 if scores.is_empty() else int(scores[scores.size() - 1])


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
	match button:
		"by_button":
			show_pause()
			return
		"grip_click":
			var mug := _nearest_mug(hand)
			if mug:
				_held_mugs[hand] = mug
				mug.grab(hand)
				hand.buzz(0.25, 0.04)
				return
	if (button == "trigger_click" or button == "grip_click") and state == State.READY and not _held_mugs.has(hand):
		_grab(hand)


func on_button_released(hand: Hand, button: String) -> void:
	if button == "grip_click" and _held_mugs.has(hand):
		(_held_mugs[hand] as BeerMug).release()
		_held_mugs.erase(hand)
		return
	if state == State.HELD and hand == _holder and (button == "trigger_click" or button == "grip_click"):
		_release(hand)


func _nearest_mug(hand: Hand) -> BeerMug:
	if not settings["decor"]:
		return null
	var best: BeerMug = null
	var best_d := 0.17
	for m in _mugs:
		if m.state == BeerMug.State.HELD:
			continue
		var d := m.distance_to_hand(hand)
		if d < best_d:
			best_d = d
			best = m
	return best


func _grab(hand: Hand) -> void:
	_holder = hand
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	_ball.freeze = true
	state = State.HELD
	Sound.play_at("grab", _ball.global_position, -4.0)
	show_message("", 0.0)


func _release(hand: Hand) -> void:
	var velocity := hand.throw_velocity() * THROW_BOOST
	_holder = null
	if velocity.length() < MIN_THROW_SPEED:
		_ball_to_rest()
		state = State.READY
		show_message("Lance un peu plus fort !", 2.0)
		return
	_thrower = hand
	Sound.play_at("whoosh", _ball.global_position, -6.0)
	_launch(_ball.global_position, velocity)
	hand.buzz(0.7, 0.1)


func _launch(from: Vector3, velocity: Vector3) -> void:
	var min_y := global_position.y + BALL_RADIUS + 0.01
	if from.y < min_y:
		from.y = min_y
	_ball.global_position = from
	_ball.collision_mask = LAYER_WORLD | LAYER_PINS
	_ball.freeze = false
	_ball.linear_velocity = velocity
	_ball.angular_velocity = Vector3.ZERO
	_timer = 0.0
	_slow_time = 0.0
	_ball_hit_pins = false
	_in_gutter = false
	_landed = false
	state = State.ROLLING


# ================================================================ boucle

func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""
	if _cheers_cooldown > 0.0:
		_cheers_cooldown -= delta
	if _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)

	match state:
		State.READY:
			if _selftest and not _panel.visible:
				_selftest_throw()
		State.HELD:
			if _holder:
				_ball.global_position = _holder.global_position - _holder.global_basis.y * 0.045
		State.ROLLING:
			_update_rolling(delta)
		State.SETTLING:
			_timer += delta
			if _timer > SETTLE_TIME:
				_end_roll()

	_update_roll_sound()
	_update_blobs()
	_check_cheers()


func _update_rolling(delta: float) -> void:
	_timer += delta
	var local := to_local(_ball.global_position)
	if not _landed and local.y < BALL_RADIUS + 0.02:
		_landed = true
		var down := -_ball.linear_velocity.y
		Sound.play_at("ball_thud", _ball.global_position, linear_to_db(clampf(0.25 + down / 3.0, 0.1, 1.0)))
	# Rigole : sans bumpers, une boule qui sort de la piste ne touche plus les quilles.
	if not settings["bumpers"] and not _in_gutter and local.z < FOUL_Z and absf(local.x) > LANE_W / 2.0 + 0.01:
		_in_gutter = true
		_ball.collision_mask = LAYER_WORLD
		var v := _ball.linear_velocity
		var along := -global_basis.z * maxf(2.0, v.dot(-global_basis.z))
		_ball.linear_velocity = along
	if _ball.linear_velocity.length() < 0.08:
		_slow_time += delta
	else:
		_slow_time = 0.0
	var finished := _timer > ROLL_TIMEOUT \
		or local.z < DECK_END - 0.3 \
		or local.y < -1.0 or absf(local.x) > 3.0 or local.z > 2.0 \
		or (_timer > 1.0 and _slow_time > 0.5)
	if finished:
		state = State.SETTLING
		_timer = 0.0


func _update_roll_sound() -> void:
	if state == State.ROLLING and _landed:
		var local := to_local(_ball.global_position)
		var speed := _ball.linear_velocity.length()
		if local.y < BALL_RADIUS + 0.03 and speed > 0.3:
			if not _roll_sound.playing:
				_roll_sound.play()
			_roll_sound.volume_db = linear_to_db(clampf(speed / 5.0, 0.05, 1.0))
			_roll_sound.pitch_scale = clampf(0.75 + speed * 0.07, 0.75, 1.3)
			return
	if _roll_sound.playing:
		_roll_sound.stop()


func _update_blobs() -> void:
	var floor_y := global_position.y + 0.006
	var bp := _ball.global_position
	var h := bp.y - floor_y
	_ball_blob.visible = h < 1.2
	_ball_blob.global_position = Vector3(bp.x, floor_y, bp.z)
	_ball_blob.scale = Vector3.ONE * clampf(1.0 - h * 0.5, 0.4, 1.0)
	for i in _pins.size():
		if is_instance_valid(_pins[i]):
			var p := _pins[i].global_position
			_pin_blobs[i].global_position = Vector3(p.x, floor_y + 0.001, p.z)


func _check_cheers() -> void:
	if _cheers_cooldown > 0.0 or _held_mugs.is_empty():
		return
	for hand in _held_mugs:
		var mine: BeerMug = _held_mugs[hand]
		for s in _spectators:
			if s.mug and mine.global_position.distance_to(s.mug.global_position) < 0.16:
				Sound.play_at("clink", mine.global_position, -2.0)
				(hand as Hand).buzz(0.5, 0.05)
				s.say("cheers", true)
				_cheers_cooldown = 3.0
				return


# ================================================================ fin de lancer

func _end_roll() -> void:
	var still_up: Array[int] = []
	for i in _pins.size():
		if not _is_down(_pins[i], _standing[i]):
			still_up.append(_standing[i])
	var knocked := _standing.size() - still_up.size()
	var cleared := still_up.is_empty()
	var event := _classify(knocked, cleared)

	if is_training():
		_end_roll_training(knocked, event)
	else:
		_end_roll_match(knocked, cleared, still_up, event)


func _classify(knocked: int, cleared: bool) -> String:
	if cleared and _rack_first:
		return "strike"
	if cleared:
		return "spare"
	if knocked == 0 and _in_gutter:
		return "gutter"
	if knocked <= 3:
		return "low"
	if knocked >= 7:
		return "good"
	return ""


func _celebrate(event: String, knocked: int) -> void:
	if _selftest:
		_selftest_events[event] = int(_selftest_events.get(event, 0)) + 1
	var pl: Dictionary = players[current]
	if event == "strike":
		pl["streak"] = int(pl.get("streak", 0)) + 1
	elif _rack_first:
		pl["streak"] = 0
	match event:
		"strike":
			var n := int(pl["streak"])
			var txt := "STRIKE !"
			if n == 2:
				txt = "DOUBLE !"
			elif n == 3:
				txt = "TURKEY !"
			elif n > 3:
				txt = "%d STRIKES !" % n
			_scoreboard.announce(txt, Color(1, 0.8, 0.1), 3.0, true)
			show_message("", 0.0)
			Sound.play("cheer_big", -3.0)
			if _thrower:
				_thrower.buzz(1.0, 0.3)
		"spare":
			_scoreboard.announce("SPARE !", Color(0.2, 0.85, 1.0), 2.2)
			show_message("", 0.0)
			Sound.play("cheer_small", -4.0)
		"gutter":
			_scoreboard.announce("RIGOLE…", Color(0.55, 0.55, 0.6), 2.0)
			show_message("", 0.0)
			Sound.play("gutter", -5.0)
		_:
			if knocked == 9:
				_scoreboard.announce("9 !", Color(1.0, 0.5, 0.2), 1.6)
			show_message(_count_text(knocked), 2.0)
	if event in ["strike", "spare", "gutter"]:
		_sign.celebrate(event)
	if event != "" and settings["decor"]:
		for s in _spectators:
			s.react(event)


func _end_roll_training(knocked: int, event: String) -> void:
	var st: Dictionary = players[current]["stats"]
	st["throws"] += 1
	st["pins"] += knocked
	st["last"] = knocked
	if knocked == 10:
		st["strikes"] += 1
	_celebrate(event, knocked)
	if _selftest:
		_selftest_throws += 1
	var next := (current + 1) % players.size()
	var changed := next != current
	current = next
	_begin_turn(changed)
	if _selftest and _selftest_throws >= 6:
		var stats: Array[String] = []
		for p in players:
			stats.append("%s %s" % [p["name"], p["stats"]])
		_selftest_log.append("entrainement %dj : %s" % [players.size(), " | ".join(stats)])
		_selftest_next()


func _end_roll_match(knocked: int, cleared: bool, still_up: Array[int], event: String) -> void:
	var nf := n_frames()
	var frames: Array = players[current]["frames"]
	var cur: Array = frames[frame_index]
	cur.append(knocked)
	var last := frame_index == nf - 1
	var frame_done := false
	var full_reset := false

	if not last:
		if cur.size() == 1 and cleared:
			frame_done = true
		elif cur.size() == 2:
			frame_done = true
	else:
		match cur.size():
			1:
				full_reset = cleared
			2:
				if cur[0] == 10:
					full_reset = cleared
				elif cur[0] + cur[1] == 10:
					full_reset = true
				else:
					frame_done = true
			_:
				frame_done = true

	_celebrate(event, knocked)

	if not frame_done:
		if full_reset:
			_standing = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
			_rack_first = true
		else:
			_standing = still_up
			_rack_first = false
		_ball_to_rest()
		_reset_pins_animated()
		_refresh_board()
		return

	if not last:
		frames.append([])
	current += 1
	if current >= players.size():
		current = 0
		frame_index += 1
	if frame_index >= nf:
		_game_over()
	else:
		_begin_turn(true)


func _game_over() -> void:
	state = State.GAME_OVER
	current = players.size() - 1
	_refresh_board()
	var best := -1
	var winner := 0
	for i in players.size():
		var t := player_total(i)
		if t > best:
			best = t
			winner = i
	var summary := ""
	if players.size() == 1:
		summary = "Score : %d points" % best
	else:
		summary = "%s gagne avec %d points !" % [players[winner]["name"], best]
	var mode: String = settings["mode"]
	if best > _record(mode):
		_save.set_value("records", mode, best)
		_save.save(SAVE_PATH)
		summary += "\nNouveau record !"
	Sound.play("cheer_big", -2.0)
	show_message("", 0.0)
	_scoreboard.announce("BRAVO !" if players.size() == 1 else "%s GAGNE !" % String(players[winner]["name"]).to_upper(), players[winner]["color"], 6.0, true)
	_sign.celebrate("win")
	if settings["decor"]:
		for s in _spectators:
			s.react("win")
	_ball_to_rest()
	if _selftest:
		_selftest_log.append("%s %dj : %s | %s" % [mode, players.size(), _frames_text(), summary.replace("\n", " ")])
		_selftest_next()
		return
	show_game_over(summary)


func _frames_text() -> String:
	var parts: Array[String] = []
	for p in players:
		var marks: Array[String] = []
		var frames: Array = p["frames"]
		for i in frames.size():
			marks.append(BowlingGame.frame_marks(frames[i], i == n_frames() - 1))
		parts.append(" ".join(marks))
	return " || ".join(parts)


func _count_text(knocked: int) -> String:
	if knocked == 0:
		return "Raté !"
	if knocked == 1:
		return "1 quille"
	return "%d quilles" % knocked


func _is_down(pin: RigidBody3D, spot_index: int) -> bool:
	if not is_instance_valid(pin):
		return true
	var up := pin.global_basis.y.normalized()
	if up.dot(global_basis.y) < 0.85:
		return true
	var local := to_local(pin.global_position)
	var spot := _pin_spots[spot_index]
	if local.y < -0.3:
		return true
	return Vector2(local.x - spot.x, local.z - spot.z).length() > 0.1


# ================================================================ score

## Scores cumulés des frames dont la valeur est déjà connue (la dernière frame
## suit la règle de la 10e : bonus jusqu'à 3 boules).
static func frame_scores(rolls: Array, frame_count: int = 10) -> Array:
	var out: Array = []
	var i := 0
	var total := 0
	for _f in frame_count:
		if i >= rolls.size():
			break
		if rolls[i] == 10:
			if i + 2 >= rolls.size():
				break
			total += 10 + rolls[i + 1] + rolls[i + 2]
			i += 1
		else:
			if i + 1 >= rolls.size():
				break
			if rolls[i] + rolls[i + 1] == 10:
				if i + 2 >= rolls.size():
					break
				total += 10 + rolls[i + 2]
			else:
				total += rolls[i] + rolls[i + 1]
			i += 2
		out.append(total)
	return out


## Notation d'une frame (X, /, -), y compris la dernière.
static func frame_marks(frame: Array, is_last: bool) -> String:
	var marks := ""
	var rack_first := true
	var pins_left := 10
	for r in frame.size():
		var v: int = frame[r]
		var mark := ""
		if rack_first and v == 10:
			mark = "X"
		elif not rack_first and v == pins_left:
			mark = "/"
		elif v == 0:
			mark = "-"
		else:
			mark = str(v)
		marks += mark
		pins_left -= v
		if pins_left <= 0 or not rack_first:
			pins_left = 10
			rack_first = true
		else:
			rack_first = false
		if not is_last and (mark == "X" or r == 1):
			break
	return marks


func show_message(text: String, seconds: float = 3.0) -> void:
	_message.text = text
	_message_time = seconds


# ================================================================ quilles

func _compute_pin_spots() -> void:
	_pin_spots.clear()
	for row in 4:
		for k in row + 1:
			var x := (k - row / 2.0) * PIN_SPACING_X
			var z := HEADPIN_Z - row * PIN_SPACING_Z
			_pin_spots.append(Vector3(x, 0.0, z))


func _clear_pins() -> void:
	for pin in _pins:
		if is_instance_valid(pin):
			pin.queue_free()
	for b in _pin_blobs:
		b.queue_free()
	_pins.clear()
	_pin_blobs.clear()


func _spawn_pins(lift: float) -> void:
	_clear_pins()
	for index in _standing:
		var pin := _make_pin()
		pin.position = _pin_spots[index] + Vector3(0, PIN_HEIGHT / 2.0 + 0.002 + lift, 0)
		pin.freeze = true
		add_child(pin)
		_pins.append(pin)
		var blob := BowlingArt.make_blob(0.16)
		add_child(blob)
		_pin_blobs.append(blob)


## La machine redescend les quilles debout ; on ne peut lancer qu'après.
func _reset_pins_animated() -> void:
	state = State.RESETTING
	_spawn_pins(0.55)
	Sound.play_at("pinsetter", to_global(Vector3(0, 0.6, HEADPIN_Z - 0.4)), -6.0)
	var tw := create_tween().set_parallel(true)
	for pin in _pins:
		tw.tween_property(pin, "position:y", PIN_HEIGHT / 2.0 + 0.002, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_on_pins_set)


func _on_pins_set() -> void:
	for pin in _pins:
		pin.freeze = false
	if state == State.RESETTING:
		state = State.READY


func _respot_pins_instant() -> void:
	if _standing.is_empty():
		_standing = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	_spawn_pins(0.0)
	for pin in _pins:
		pin.freeze = state == State.SETUP


func _make_pin() -> RigidBody3D:
	var pin := RigidBody3D.new()
	pin.mass = 1.5
	pin.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	pin.collision_layer = LAYER_PINS
	pin.collision_mask = LAYER_WORLD | LAYER_PINS | LAYER_BALL
	pin.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	pin.center_of_mass = Vector3(0, -0.06, 0)
	pin.contact_monitor = true
	pin.max_contacts_reported = 2
	var phys := PhysicsMaterial.new()
	phys.friction = 0.25
	phys.bounce = 0.35
	pin.physics_material_override = phys

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PIN_RADIUS
	cyl.height = PIN_HEIGHT
	shape.shape = cyl
	pin.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BowlingArt.pin_mesh()
	pin.add_child(mesh)
	pin.body_entered.connect(_on_pin_contact.bind(pin))
	return pin


func _on_pin_contact(_other: Node, pin: RigidBody3D) -> void:
	if state != State.ROLLING and state != State.SETTLING:
		return
	var now := Time.get_ticks_msec()
	var id := pin.get_instance_id()
	if now - int(_hit_cooldown.get(id, 0)) < 90:
		return
	var speed := pin.linear_velocity.length() + pin.angular_velocity.length() * 0.1
	if speed < 0.35:
		return
	_hit_cooldown[id] = now
	var vol := linear_to_db(clampf(speed / 3.0, 0.08, 1.0))
	Sound.play_at("pin_hit_%d" % (randi() % 3 + 1), pin.global_position, vol, 0.1)


func _on_ball_contact(other: Node) -> void:
	if state != State.ROLLING or _ball_hit_pins:
		return
	if other is RigidBody3D and _pins.has(other):
		_ball_hit_pins = true
		var speed := _ball.linear_velocity.length()
		if speed > 2.0 and _standing.size() >= 6:
			Sound.play_at("strike_crash", _ball.global_position, linear_to_db(clampf(speed / 6.0, 0.3, 1.0)))
		if _thrower:
			_thrower.buzz(0.6, 0.12)


# ================================================================ construction

func _build_lane() -> void:
	var lane_len := FOUL_Z - DECK_END
	var center_z := (FOUL_Z + DECK_END) / 2.0
	var approach_len := 1.1

	# Piste et zone d'élan en lattes de bois vernies
	add_child(BowlingArt.floor_quad(LANE_W, lane_len, BowlingArt.wood_material(lane_len), Vector3(0, 0.004, center_z)))
	var approach := BowlingArt.wood_material(approach_len)
	approach.albedo_color = Color(0.92, 0.88, 0.82)
	add_child(BowlingArt.floor_quad(LANE_W + 2.0 * GUTTER_W + 0.06, approach_len, approach, Vector3(0, 0.004, FOUL_Z + approach_len / 2.0)))

	# Ligne de faute, points et flèches de visée
	add_child(BowlingArt.box(Vector3(LANE_W + 2.0 * GUTTER_W + 0.06, 0.003, 0.025), BowlingArt.unshaded(Color(0.1, 0.1, 0.12)), Vector3(0, 0.006, FOUL_Z)))
	var dark := BowlingArt.mat(Color(0.2, 0.1, 0.06), 0.3)
	for k in 7:
		var x := (k - 3) * 0.13
		add_child(BowlingArt.cylinder(0.01, 0.01, 0.002, dark, Vector3(x, 0.006, FOUL_Z - 0.3), 10))
	for k in 7:
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.035, 0.09, 0.002)
		arrow.mesh = prism
		arrow.material_override = dark
		arrow.rotation_degrees = Vector3(-90, 0, 0)
		arrow.position = Vector3((k - 3) * 0.13, 0.006, FOUL_Z - 1.35 - absf(k - 3) * 0.08)
		add_child(arrow)
	# Position des quilles dessinées sur le plateau
	for s in _pin_spots:
		add_child(BowlingArt.cylinder(0.03, 0.03, 0.002, BowlingArt.mat(Color(0.75, 0.55, 0.35), 0.3), Vector3(s.x, 0.006, s.z), 12))

	# Rigoles (métal) et rebords
	var gutter_mat := BowlingArt.mat(Color(0.32, 0.34, 0.38), 0.35, 0.6)
	var cap_mat := BowlingArt.mat(Color(0.12, 0.12, 0.14), 0.5)
	for side in [-1.0, 1.0]:
		var gx: float = side * (LANE_W / 2.0 + GUTTER_W / 2.0)
		add_child(BowlingArt.floor_quad(GUTTER_W, lane_len, gutter_mat, Vector3(gx, 0.002, center_z)))
		var wall_x: float = side * (LANE_W / 2.0 + GUTTER_W + 0.015)
		_add_static_box(Vector3(0.03, 0.07, lane_len), Vector3(wall_x, 0.035, center_z), cap_mat)
		# Murs latéraux (kickbacks) autour du plateau de quilles
		var kb_len := HEADPIN_Z + 0.5 - DECK_END
		_add_static_box(Vector3(0.05, 0.55, kb_len), Vector3(side * (LANE_W / 2.0 + GUTTER_W + 0.04), 0.275, DECK_END + kb_len / 2.0), BowlingArt.mat(Color(0.35, 0.12, 0.08), 0.4))
		# Bumpers (rails gonflables), activables
		var bumper := _add_static_box(Vector3(0.07, 0.12, lane_len - 0.2), Vector3(side * (LANE_W / 2.0 + 0.035), 0.06, center_z + 0.1), BowlingArt.mat(Color(0.2, 0.55, 1.0, 0.85), 0.3))
		_bumpers.append(bumper)

	# Fosse et fond de piste
	_add_static_box(Vector3(LANE_W + 2.0 * GUTTER_W + 0.2, 0.8, 0.12), Vector3(0, 0.4, DECK_END - 0.55), BowlingArt.mat(Color(0.05, 0.05, 0.06), 0.9))
	add_child(BowlingArt.floor_quad(LANE_W + 2.0 * GUTTER_W, 0.5, BowlingArt.unshaded(Color(0.02, 0.02, 0.02)), Vector3(0, 0.003, DECK_END - 0.25)))
	# Enseigne néon au-dessus des quilles
	_sign = NeonSign.new()
	_sign.position = Vector3(0, 1.02, DECK_END - 0.05)
	add_child(_sign)

	# Éclairage chaud sur les quilles
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.75)
	light.light_energy = 1.1
	light.light_specular = 0.25
	light.omni_range = 2.4
	light.position = Vector3(0, 1.1, HEADPIN_Z - 0.35)
	add_child(light)

	# Porte-boule à droite du joueur
	var stand_mat := BowlingArt.mat(Color(0.15, 0.15, 0.2), 0.35, 0.4)
	add_child(BowlingArt.cylinder(0.12, 0.16, 0.04, stand_mat, Vector3(BALL_REST.x, 0.02, BALL_REST.z)))
	var col_h := BALL_REST.y - BALL_RADIUS - 0.02
	add_child(BowlingArt.cylinder(0.035, 0.05, col_h, stand_mat, Vector3(BALL_REST.x, col_h / 2.0, BALL_REST.z)))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.085
	ring.mesh = torus
	ring.material_override = BowlingArt.mat(Color(0.8, 0.8, 0.85), 0.2, 0.8)
	ring.position = Vector3(BALL_REST.x, col_h + 0.01, BALL_REST.z)
	add_child(ring)


func _build_ball() -> void:
	_ball = RigidBody3D.new()
	_ball.name = "Boule"
	_ball.mass = 6.0
	_ball.continuous_cd = true
	_ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_ball.can_sleep = false
	_ball.collision_layer = LAYER_BALL
	_ball.collision_mask = LAYER_WORLD | LAYER_PINS
	_ball.contact_monitor = true
	_ball.max_contacts_reported = 4
	_ball.body_entered.connect(_on_ball_contact)
	var phys := PhysicsMaterial.new()
	phys.friction = 0.25
	phys.bounce = 0.05
	_ball.physics_material_override = phys

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	shape.shape = sphere
	_ball.add_child(shape)

	_ball_mesh = BowlingArt.sphere(BALL_RADIUS, BowlingArt.ball_material(PLAYER_COLORS[0]), Vector3.ZERO, 28)
	_ball.add_child(_ball_mesh)
	var hole_mat := BowlingArt.mat(Color(0.02, 0.02, 0.04), 0.8)
	for offset in [Vector3(-0.025, 0.02, 0), Vector3(0.025, 0.02, 0), Vector3(0, -0.03, 0)]:
		var hole := BowlingArt.sphere(0.012, hole_mat, Vector3.ZERO, 8)
		hole.position = (offset + Vector3(0, 0, BALL_RADIUS)).normalized() * (BALL_RADIUS - 0.006)
		_ball.add_child(hole)
	add_child(_ball)
	_ball_blob = BowlingArt.make_blob(0.3)
	add_child(_ball_blob)
	_roll_sound = Sound.make_loop_player("roll_loop", _ball, 0.0)


func _build_decor() -> void:
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)

	# Mange-debout avec trois bières et un bol de chips
	var table := Node3D.new()
	table.position = Vector3(-1.2, 0, 0.05)
	_decor.add_child(table)
	var wood := BowlingArt.mat(Color(0.32, 0.18, 0.1), 0.35)
	var metal := BowlingArt.mat(Color(0.15, 0.15, 0.17), 0.3, 0.7)
	table.add_child(BowlingArt.cylinder(0.36, 0.36, 0.04, wood, Vector3(0, 1.05, 0), 32))
	table.add_child(BowlingArt.cylinder(0.035, 0.035, 1.03, metal, Vector3(0, 0.515, 0)))
	table.add_child(BowlingArt.cylinder(0.24, 0.26, 0.025, metal, Vector3(0, 0.0125, 0), 28))
	var blob := BowlingArt.make_blob(0.8)
	blob.top_level = false
	blob.position = Vector3(0, 0.003, 0)
	table.add_child(blob)
	var bowl := BowlingArt.sphere(0.08, BowlingArt.mat(Color(0.9, 0.9, 0.92), 0.3), Vector3(0.12, 1.07, 0.15), 14)
	bowl.scale = Vector3(1, 0.45, 1)
	table.add_child(bowl)
	var chip_mat := BowlingArt.mat(Color(0.95, 0.78, 0.3), 0.6)
	for k in 9:
		var a := TAU * k / 9.0
		var chip := BowlingArt.sphere(0.022, chip_mat, Vector3(0.12 + cos(a) * 0.035, 1.1 + (k % 3) * 0.006, 0.15 + sin(a) * 0.035), 6)
		chip.scale = Vector3(1, 0.25, 0.8)
		chip.rotation = Vector3(randf() * 0.6, a, randf() * 0.6)
		table.add_child(chip)
	for spot in [Vector3(-0.14, 1.07, -0.06), Vector3(0.08, 1.07, -0.14), Vector3(-0.08, 1.07, 0.16)]:
		var mug := BeerMug.new()
		mug.local_slot = Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0)), spot)
		mug.transform = mug.local_slot
		table.add_child(mug)
		mug.emptied.connect(_on_mug_emptied)
		_mugs.append(mug)

	# Deux spectateurs
	var gege := Spectator.new({
		"name": "Gégé", "skin": Color(0.95, 0.78, 0.65), "shirt": Color(0.85, 0.32, 0.15),
		"pants": Color(0.2, 0.22, 0.3), "hair": Color(0.45, 0.4, 0.38), "beard": true,
		"hat": true, "hat_color": Color(0.15, 0.3, 0.75),
	})
	gege.position = Vector3(-1.75, 0, -0.5)
	_decor.add_child(gege)
	var gege_mug := BeerMug.new()
	gege_mug.decorative = true
	gege.hold_mug(gege_mug)
	_spectators.append(gege)

	var sonia := Spectator.new({
		"name": "Sonia", "skin": Color(0.72, 0.52, 0.38), "shirt": Color(0.1, 0.65, 0.65),
		"pants": Color(0.12, 0.12, 0.18), "hair": Color(0.3, 0.1, 0.06), "ponytail": true,
	})
	sonia.position = Vector3(1.5, 0, -1.0)
	_decor.add_child(sonia)
	_spectators.append(sonia)

	for s in _spectators:
		var to := Vector3(0, 0, -0.6) - s.position
		s.rotation.y = atan2(to.x, to.z)


func _on_mug_emptied(_mug: BeerMug) -> void:
	for s in _spectators:
		if randf() < 0.6:
			s.say("empty", true)
	if randf() < 0.7:
		var cam := get_viewport().get_camera_3d()
		var pos := cam.global_position if cam else global_position
		get_tree().create_timer(0.7).timeout.connect(func() -> void: Sound.play_at("burp", pos, -2.0))


func _ball_to_rest() -> void:
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.position = BALL_REST
	_ball.rotation = Vector3.ZERO


func _add_static_box(size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(BowlingArt.box(size, material))
	add_child(body)
	return body


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = _save.get_value("settings", k, settings[k])
	if not MODES.has(settings["mode"]):
		settings["mode"] = "classique"


func _save_settings() -> void:
	for k in settings.keys():
		_save.set_value("settings", k, settings[k])
	_save.save(SAVE_PATH)


func _record(mode: String) -> int:
	return int(_save.get_value("records", mode, 0))


# ================================================================ auto-test

func enable_selftest() -> void:
	_selftest = true
	_close_panel()
	_selftest_plan = [
		{"players": 2, "mode": "classique", "bumpers": true},
		{"players": 1, "mode": "rapide", "bumpers": false},
		{"players": 3, "mode": "entrainement", "bumpers": true},
	]
	_selftest_next()


func _selftest_next() -> void:
	if _selftest_plan.is_empty():
		_selftest_drink()
		return
	var plan: Dictionary = _selftest_plan.pop_front()
	for k in plan:
		settings[k] = plan[k]
	_selftest_throws = 0
	start_match()


func _selftest_throw() -> void:
	var wide: bool = not settings["bumpers"] and randf() < 0.3
	var aim_x := randf_range(0.45, 0.6) * (1.0 if randf() < 0.5 else -1.0) if wide else randf_range(-0.1, 0.1)
	var from := to_global(Vector3(aim_x * 0.3, BALL_RADIUS + 0.02, FOUL_Z - 0.1))
	var target := to_global(Vector3(aim_x, BALL_RADIUS, HEADPIN_Z))
	var velocity := (target - from).normalized() * randf_range(5.0, 7.5)
	_launch(from, velocity)


## Teste la bière : la main droite prend une chope, la porte à la bouche, boit.
func _selftest_drink() -> void:
	state = State.SETUP
	var hand: Hand = _hands[1]
	var mug := _mugs[0]
	hand.global_position = mug.global_position + Vector3(0, 0.07, 0)
	var picked := _nearest_mug(hand)
	_selftest_log.append("chope proche de la main : %s" % (picked != null))
	if picked == null:
		_selftest_finish()
		return
	on_button_pressed(hand, "grip_click")
	var cam := get_viewport().get_camera_3d()
	hand.global_position = cam.global_position - cam.global_basis.y * 0.02 - cam.global_basis.z * 0.12
	hand.global_basis = Basis.from_euler(Vector3(deg_to_rad(60), 0, 0))
	await get_tree().create_timer(BeerMug.DRINK_SECONDS + 1.0).timeout
	_selftest_log.append("niveau de bière après avoir bu : %.2f" % mug.level)
	on_button_released(hand, "grip_click")
	await get_tree().create_timer(5.0).timeout
	_selftest_log.append("niveau après remplissage : %.2f (état %s)" % [mug.level, BeerMug.State.keys()[mug.state]])
	_selftest_finish()


func _selftest_finish() -> void:
	for line in _selftest_log:
		print("SELFTEST ", line)
	print("SELFTEST évènements ", _selftest_events)
	print("SELFTEST score=OK")
	selftest_finished.emit()
