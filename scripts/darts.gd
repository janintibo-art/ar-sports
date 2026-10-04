class_name DartsGame
extends Node3D
## Fléchettes en réalité augmentée : une cible réglementaire (agrandie selon le
## niveau) devant le joueur, trois fléchettes dans un porte-fléchettes. On en prend
## une avec la gâchette ou la poignée, on lance, on relâche. 1 à 4 joueurs à tour
## de rôle (3 fléchettes chacun), modes 301, 501, tour de l'horloge et libre.
## Le noeud est placé aux pieds du joueur ; la cible est devant lui, vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const GRAVITY := 6.5
const THROW_BOOST := 1.5
const MIN_THROW_SPEED := 1.2
const BOARD_H := 1.5
const HOLDER_POS := Vector3(0.42, 0.9, -0.22)
const GRAB_RADIUS := 0.22
const TURN_PAUSE := 2.4
const FLIGHT_TIMEOUT := 5.0
const SAVE_PATH := "user://darts.cfg"

const PLAYER_COLORS := [
	Color(0.15, 0.45, 1.0), Color(0.95, 0.22, 0.25), Color(0.15, 0.75, 0.38), Color(1.0, 0.62, 0.1),
]
const LEVELS := {
	"facile": {"title": "Facile", "scale": 2.0, "assist": 0.7, "dist": 1.6},
	"normal": {"title": "Normal", "scale": 1.5, "assist": 0.35, "dist": 2.0},
	"pro": {"title": "Pro", "scale": 1.0, "assist": 0.0, "dist": 2.37},
}
const MODES := {
	"301": {"title": "301", "start": 301},
	"501": {"title": "501", "start": 501},
	"horloge": {"title": "Horloge", "start": 0},
	"libre": {"title": "Libre", "start": 0},
}

enum State { SETUP, READY, HELD, TURN_END, GAME_OVER }

var settings := {"players": 1, "mode": "501", "level": "normal", "double_out": false, "music": true}
var state := State.SETUP
var players: Array = []
var current := 0
var round_number := 1

var _hands: Array = []
var _board: Dartboard
var _scoreboard: DartScoreboard
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _hud: Label3D
var _message: Label3D
var _message_time := 0.0
var _decor: Node3D
var _darts: Array[Dart] = []
var _flying: Array[Dart] = []
var _held: Dart = null
var _holder_hand: Hand = null
var _grab_button := ""
var _turn_hits: Array = []
var _turn_total := 0
var _turn_over := false
var _timer := 0.0
var _flight_age := {}
var _save := ConfigFile.new()

var _selftest := false
var _st_failures: Array = []
var _st_log: Array = []
var _assist_override := -1.0


# ================================================================ mise en place

func set_hands(left: Hand, right: Hand) -> void:
	_hands = [left, right]


func _ready() -> void:
	_load_save()
	_build_decor()
	_board = Dartboard.new()
	add_child(_board)
	_scoreboard = DartScoreboard.new()
	add_child(_scoreboard)
	_hud = BowlingArt.label("", 0.05)
	_hud.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hud.position = HOLDER_POS + Vector3(0, 0.5, 0)
	add_child(_hud)
	_message = BowlingArt.neon_label("", 0.13, Color(1, 0.8, 0.2))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.no_depth_test = true
	_message.visible = false
	add_child(_message)
	_panel = UiPanel.new()
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)
	_apply_level()
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


func _build_decor() -> void:
	_decor = Node3D.new()
	add_child(_decor)
	# Ligne de lancer lumineuse au sol
	_decor.add_child(BowlingArt.box(Vector3(0.9, 0.004, 0.035), BowlingArt.unshaded(Color(1.0, 0.8, 0.2)), Vector3(0, 0.002, 0)))
	# Porte-fléchettes : pied, plateau, bloc de mousse
	var wood := BowlingArt.mat(Color(0.3, 0.17, 0.09), 0.4)
	var metal := BowlingArt.mat(Color(0.15, 0.15, 0.17), 0.3, 0.7)
	var hp := HOLDER_POS
	_decor.add_child(BowlingArt.cylinder(0.03, 0.03, hp.y, metal, Vector3(hp.x, hp.y / 2.0, hp.z)))
	_decor.add_child(BowlingArt.cylinder(0.14, 0.15, 0.025, metal, Vector3(hp.x, 0.0125, hp.z), 28))
	_decor.add_child(BowlingArt.cylinder(0.17, 0.17, 0.025, wood, Vector3(hp.x, hp.y, hp.z), 28))
	_decor.add_child(BowlingArt.box(Vector3(0.28, 0.05, 0.07), BowlingArt.mat(Color(0.07, 0.07, 0.08), 0.9), Vector3(hp.x, hp.y + 0.037, hp.z)))
	var blob := BowlingArt.make_blob(0.7)
	blob.top_level = false
	blob.position = Vector3(hp.x, 0.003, hp.z)
	_decor.add_child(blob)


## Replace la zone de jeu devant le joueur (pieds au sol, face au regard).
func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	for d in _darts:
		if d.state == Dart.State.HOLDER:
			d.transform = d.slot
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


## Taille et distance de la cible selon le niveau, tableau placé à gauche.
func _apply_level() -> void:
	var lv: Dictionary = LEVELS[settings["level"]]
	var dist: float = lv["dist"]
	var sc: float = lv["scale"]
	_board.face_scale = sc
	_board.position = Vector3(0, BOARD_H, -dist)
	var radius := Dartboard.R_SURROUND * sc
	var px := -(radius + DartScoreboard.W / 2.0 + 0.2)
	_scoreboard.position = Vector3(px, BOARD_H, -dist + 0.1)
	var to := Vector3(0, 0, 0) - _scoreboard.position
	_scoreboard.rotation = Vector3(0, atan2(to.x, to.z), 0)
	_message.position = Vector3(0, BOARD_H + radius + 0.14, -dist + 0.3)


# ================================================================ panneaux

func show_setup() -> void:
	state = State.SETUP
	_return_held()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("Fléchettes", "Record  501 : %s   ·   301 : %s" % [_record_text("501"), _record_text("301")])
	var row: Array = []
	for n in 4:
		row.append({"id": "players_%d" % (n + 1), "text": str(n + 1), "width": 0.1, "selected": settings["players"] == n + 1})
	_panel.add_row("Joueurs", row)
	row = []
	for m in ["301", "501", "horloge", "libre"]:
		row.append({"id": "mode_" + m, "text": MODES[m]["title"], "width": 0.17, "selected": settings["mode"] == m})
	_panel.add_row("Mode", row)
	row = []
	for l in ["facile", "normal", "pro"]:
		row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.22, "selected": settings["level"] == l})
	_panel.add_row("Niveau", row)
	for opt in [["double_out", "Sortie double"], ["music", "Musique"]]:
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
	_return_held()
	_panel_page = "pause"
	_panel.clear()
	_panel.set_title("Pause")
	_panel.add_row("", [{"id": "resume", "text": "Reprendre", "width": 0.34, "color": Color(0.15, 0.6, 0.25)}])
	_panel.add_row("", [{"id": "restart", "text": "Recommencer", "width": 0.34}])
	_panel.add_row("", [{"id": "settings", "text": "Réglages", "width": 0.34}])
	_panel.add_row("", [{"id": "switch", "text": "Changer de jeu", "width": 0.34, "color": Color(0.2, 0.4, 0.75)}])
	_panel.add_row("", [{"id": "menu", "text": "Menu principal", "width": 0.34, "color": Color(0.35, 0.35, 0.4)}])
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


func _set_lasers(on: bool) -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = on


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("players_"):
		settings["players"] = int(id.substr(8))
	elif id.begins_with("mode_"):
		settings["mode"] = id.substr(5)
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
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
	Sound.music_enabled = settings["music"]
	_apply_level()
	_save_settings()
	show_setup()


# ================================================================ partie

func start_match() -> void:
	_clear_all_darts()
	_apply_level()
	var mode: String = settings["mode"]
	players = []
	var n: int = settings["players"]
	for i in n:
		players.append({
			"name": "Joueur %d" % (i + 1), "color": PLAYER_COLORS[i],
			"remaining": int(MODES[mode]["start"]), "turn_start": int(MODES[mode]["start"]),
			"target": 1, "last": [], "thrown": 0, "points": 0, "best_turn": 0,
		})
	current = 0
	round_number = 1
	var title := "FLÉCHETTES · " + String(MODES[mode]["title"]).to_upper()
	var record := "" if mode in ["horloge", "libre"] else "RECORD  %s" % _record_text(mode)
	_scoreboard.build(n, title, record)
	_begin_turn(false)


func _begin_turn(announce: bool) -> void:
	var pl: Dictionary = players[current]
	pl["turn_start"] = pl["remaining"]
	_turn_hits = []
	_turn_total = 0
	_turn_over = false
	_spawn_darts(pl["color"])
	state = State.READY
	_refresh()
	if announce and players.size() > 1:
		_announce("À %s !" % String(pl["name"]).to_upper(), pl["color"], 1.8)
		Sound.play("next_player", -4.0)
	elif not announce:
		var m: String = settings["mode"]
		match m:
			"horloge":
				_announce("1 → 20 puis BULL", Color(0.3, 0.85, 1.0), 3.0)
			"libre":
				_announce("LIBRE", Color(0.3, 0.85, 1.0), 2.0)
			_:
				_announce(m + " !", Color(1, 0.8, 0.2), 2.0)


func _spawn_darts(color: Color) -> void:
	_darts.clear()
	for i in 3:
		var d := Dart.new()
		d.flight_color = color
		d.slot = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), HOLDER_POS + Vector3((i - 1) * 0.085, 0.12, 0))
		add_child(d)
		d.transform = d.slot
		_darts.append(d)


func _clear_all_darts() -> void:
	for d in _darts:
		if is_instance_valid(d):
			d.queue_free()
	_darts.clear()
	_flying.clear()
	_flight_age.clear()
	_held = null
	_holder_hand = null


## Les fléchettes de la volée disparaissent en rétrécissant.
func _retire_darts() -> void:
	for d in _darts:
		if not is_instance_valid(d):
			continue
		var tw := create_tween()
		tw.tween_property(d, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(d.queue_free)
	_darts.clear()


func _end_turn() -> void:
	_turn_over = true
	state = State.TURN_END
	_timer = TURN_PAUSE
	_refresh()


func _next_turn() -> void:
	_retire_darts()
	current = (current + 1) % players.size()
	if current == 0:
		round_number += 1
	_begin_turn(true)


func _refresh() -> void:
	if players.is_empty():
		return
	var pl: Dictionary = players[current]
	var left := 3 - _turn_hits.size()
	_hud.text = "%s\n%d fléchette%s" % [pl["name"], left, "s" if left > 1 else ""] if state == State.READY else ""
	var hint := ""
	match String(settings["mode"]):
		"301", "501":
			var rem: int = pl["remaining"]
			if state == State.READY:
				var co := DartRules.checkout(rem, left, settings["double_out"])
				if not co.is_empty():
					hint = "Finish : " + "  ·  ".join(co)
		"horloge":
			hint = "Touche le %d" % int(pl["target"]) if int(pl["target"]) <= 20 else "Touche le BULL !"
		"libre":
			hint = "Total volée : %d" % _turn_total
	_scoreboard.refresh(players, current, settings["mode"], hint)


func _announce(text: String, color: Color, seconds: float) -> void:
	_message.text = text
	_message.outline_modulate = color
	_message.modulate = Color(1, 1, 1).lerp(color, 0.2)
	_message.visible = true
	_message_time = seconds
	_message.scale = Vector3.ONE * 1.5
	var tw := create_tween()
	tw.tween_property(_message, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	if (button == "trigger_click" or button == "grip_click") and state == State.READY and _held == null and _flying.is_empty():
		var d := _nearest_dart(hand)
		if d:
			_grab(hand, d, button)


func on_button_released(hand: Hand, button: String) -> void:
	if state == State.HELD and hand == _holder_hand and button == _grab_button:
		_release(hand)


func _nearest_dart(hand: Hand) -> Dart:
	var best: Dart = null
	var best_d := GRAB_RADIUS
	for d in _darts:
		if d.state != Dart.State.HOLDER:
			continue
		var dist := d.distance_to(hand.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _grab(hand: Hand, d: Dart, button: String) -> void:
	_held = d
	_holder_hand = hand
	_grab_button = button
	d.state = Dart.State.HELD
	hand.clear_history()
	hand.buzz(0.4, 0.05)
	state = State.HELD
	Sound.play_at("grab", d.global_position, -4.0)
	_message_time = 0.0
	_message.visible = false


func _return_held() -> void:
	if _held and is_instance_valid(_held):
		_held.state = Dart.State.HOLDER
		_held.transform = _held.slot
	_held = null
	_holder_hand = null
	if state == State.HELD:
		state = State.READY


func _release(hand: Hand) -> void:
	var velocity := hand.throw_velocity() * THROW_BOOST
	var d := _held
	if velocity.length() < MIN_THROW_SPEED:
		_return_held()
		_announce("Lance plus fort !", Color(0.9, 0.9, 0.9), 1.6)
		return
	_held = null
	_holder_hand = null
	hand.buzz(0.6, 0.08)
	_throw(d, velocity)


## Lance la fléchette `d` avec la vitesse `velocity` (après l'aide à la visée).
func _throw(d: Dart, velocity: Vector3) -> void:
	velocity = _apply_assist(d.global_position, velocity)
	d.velocity = velocity
	d.state = Dart.State.FLYING
	_flying.append(d)
	_flight_age[d] = 0.0
	state = State.READY
	Sound.play_at("whoosh", d.global_position, -10.0, 0.15)
	_refresh()


## Rapproche la trajectoire du centre de la cible, sans changer le temps de vol.
func _apply_assist(from: Vector3, v: Vector3) -> Vector3:
	var assist: float = LEVELS[settings["level"]]["assist"]
	if _assist_override >= 0.0:
		assist = _assist_override
	if assist <= 0.0:
		return v
	var forward := -global_basis.z
	var vf := v.dot(forward)
	var to_board := _board.global_position - from
	var dist_f := to_board.dot(forward)
	if vf < 1.5 or dist_f < 0.3:
		return v
	var t := dist_f / vf
	var ideal := (to_board + Vector3(0, 0.5 * GRAVITY * t * t, 0)) / t
	return v.lerp(ideal, assist)


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

	if _held and _holder_hand:
		_held.global_transform = _holder_hand.global_transform * Transform3D(Basis(), Vector3(0, 0, -0.03))

	for d in _flying.duplicate():
		if is_instance_valid(d):
			_step_dart(d, delta)

	if state == State.TURN_END:
		_timer -= delta
		if _timer <= 0.0:
			_next_turn()


func _basis_along(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(dir.normalized(), up)


func _step_dart(d: Dart, dt: float) -> void:
	_flight_age[d] = float(_flight_age.get(d, 0.0)) + dt
	var prev_tip := d.tip_global()
	d.velocity.y -= GRAVITY * dt
	d.global_position += d.velocity * dt
	if d.velocity.length() > 0.2:
		d.global_basis = _basis_along(d.velocity)
	var tip := d.tip_global()
	var a := _board.to_local(prev_tip)
	var b := _board.to_local(tip)
	if a.z > 0.0 and b.z <= 0.0:
		_hit_plane(d, a.lerp(b, a.z / (a.z - b.z)))
		return
	if tip.y <= global_position.y + 0.005 or float(_flight_age[d]) > FLIGHT_TIMEOUT:
		_fall_to_floor(d)


## La pointe traverse le plan de la cible au point `hit` (repère de la cible).
func _hit_plane(d: Dart, hit: Vector3) -> void:
	var xy := Vector2(hit.x, hit.y) / _board.face_scale
	var r := xy.length()
	var normal := _board.global_basis.z
	if r > Dartboard.R_SURROUND:
		# Dans le mur : la fléchette rebondit mollement et tombe
		var v := d_velocity_after_wall(d.velocity, normal)
		d.velocity = v
		d.global_position = _board.to_global(hit) + normal * 0.03 - d.global_basis * d.tip_local
		Sound.play_at("dart_thud", _board.to_global(hit), -8.0, 0.2)
		return
	var info: Dictionary
	if r > Dartboard.R_FACE:
		info = {"value": 0, "mult": 0, "number": 0, "label": "RATÉ", "bull": false}
	else:
		info = Dartboard.score_at(xy)
	var dir := d.velocity.normalized()
	var into := -normal
	var angle := acos(clampf(dir.dot(into), -1.0, 1.0))
	if angle > 0.7:
		dir = into.slerp(dir, 0.7 / angle)
	var tip := _board.to_global(hit) + into * 0.012
	d.stick(tip, _basis_along(dir), clampf(d.velocity.length() / 8.0, 0.4, 1.4))
	_flying.erase(d)
	_flight_age.erase(d)
	Sound.play_at("dart_thud", tip, -2.0, 0.08)
	if bool(info["bull"]) and int(info["mult"]) == 2:
		Sound.play_at("bull_ding", tip, -4.0, 0.0)
	_buzz_throwing_hands()
	_dart_done(d, info, tip + normal * 0.06)


func d_velocity_after_wall(v: Vector3, normal: Vector3) -> Vector3:
	var vn := v.dot(normal)
	var tangential := v - normal * vn
	return tangential * 0.25 + normal * absf(vn) * 0.15


func _fall_to_floor(d: Dart) -> void:
	d.state = Dart.State.FALLEN
	_flying.erase(d)
	_flight_age.erase(d)
	var flat := Vector3(d.velocity.x, 0.0, d.velocity.z)
	if flat.length() < 0.05:
		flat = -global_basis.z
	d.global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	d.global_position.y = global_position.y + 0.012
	Sound.play_at("dart_thud", d.global_position, -10.0, 0.25)
	_dart_done(d, {"value": 0, "mult": 0, "number": 0, "label": "RATÉ", "bull": false}, d.global_position + Vector3(0, 0.15, 0))


func _buzz_throwing_hands() -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.buzz(0.25, 0.05)


# ================================================================ score

func _dart_done(d: Dart, info: Dictionary, popup_at: Vector3) -> void:
	if players.is_empty() or _turn_over:
		return
	var pl: Dictionary = players[current]
	var label: String = info["label"]
	var value: int = info["value"]
	_turn_hits.append(label)
	pl["last"] = _turn_hits.duplicate()
	pl["thrown"] = int(pl["thrown"]) + 1
	pl["points"] = int(pl["points"]) + value
	_hit_popup(label, popup_at, info)

	var ended := false
	match String(settings["mode"]):
		"301", "501":
			var new_rem := int(pl["remaining"]) - value
			var dbl: bool = settings["double_out"]
			var finish_ok := (not dbl) or int(info["mult"]) == 2
			if new_rem < 0 or (dbl and new_rem == 1) or (new_rem == 0 and not finish_ok):
				_bust(pl)
				return
			pl["remaining"] = new_rem
			_turn_total += value
			if new_rem == 0:
				_win(pl)
				return
		"horloge":
			var target := int(pl["target"])
			var number := int(info["number"])
			if number == target or (target == 21 and number == 25):
				pl["target"] = target + 1
				Sound.play("clink", -6.0)
				if target + 1 > 21:
					_win(pl)
					return
				_announce("%s ✓" % ("BULL" if target == 21 else str(target)), Color(0.3, 1.0, 0.5), 1.2)
			_turn_total += value
		_:
			_turn_total += value

	_react(info)
	if _turn_hits.size() >= 3:
		ended = true
	if ended:
		_finish_volley()
	else:
		_refresh()


## Annonces et ambiance selon le tir.
func _react(info: Dictionary) -> void:
	var label: String = info["label"]
	if label == "BULL":
		_announce("BULLSEYE !", Color(1, 0.3, 0.3), 2.0)
		Sound.play("cheer_small", -4.0)
		_scoreboard.celebrate("good")
	elif label == "T20":
		_announce("TRIPLE 20 !", Color(1, 0.8, 0.2), 1.8)
		Sound.play("cheer_small", -8.0)
		_scoreboard.celebrate("good")
	elif label == "25":
		_announce("25", Color(0.4, 0.9, 0.5), 1.0)


func _finish_volley() -> void:
	var pl: Dictionary = players[current]
	pl["best_turn"] = maxi(int(pl["best_turn"]), _turn_total)
	var mode: String = settings["mode"]
	if mode in ["301", "501", "libre"]:
		if _turn_total == 180:
			_announce("180 !!!", Color(1, 0.8, 0.2), 3.0)
			Sound.play("cheer_big", -2.0)
			_scoreboard.celebrate("big")
		elif _turn_total >= 100:
			_announce("%d !" % _turn_total, Color(1, 0.55, 0.2), 2.0)
			Sound.play("cheer_small", -4.0)
		else:
			_announce("Volée : %d" % _turn_total, Color(0.85, 0.9, 1.0), 2.0)
	_end_turn()


func _bust(pl: Dictionary) -> void:
	pl["remaining"] = pl["turn_start"]
	_turn_total = 0
	_announce("BUST !", Color(1, 0.25, 0.25), 2.4)
	Sound.play("gutter", -2.0)
	_scoreboard.celebrate("bust")
	# Les fléchettes pas encore lancées sont retirées tout de suite
	for d in _darts:
		if d.state == Dart.State.HOLDER:
			d.visible = false
	_end_turn()


func _win(pl: Dictionary) -> void:
	_turn_over = true
	state = State.GAME_OVER
	var mode: String = settings["mode"]
	var darts := int(pl["thrown"])
	var summary := "%s gagne en %d fléchettes !" % [pl["name"], darts]
	if mode in ["301", "501"]:
		var best := _record(mode)
		if best == 0 or darts < best:
			_set_record(mode, darts)
			summary += "\nNOUVEAU RECORD !"
	_announce("%s GAGNE !" % String(pl["name"]).to_upper(), pl["color"], 6.0)
	Sound.play("cheer_big")
	_scoreboard.celebrate("win")
	_refresh()
	if not _selftest:
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			if state == State.GAME_OVER and is_inside_tree():
				show_game_over(summary))


func _hit_popup(text: String, at: Vector3, info: Dictionary) -> void:
	var col := Color(1, 1, 1)
	if int(info["mult"]) == 3 or bool(info["bull"]):
		col = Color(1, 0.45, 0.35)
	elif int(info["mult"]) == 2:
		col = Color(0.5, 1, 0.6)
	elif int(info["value"]) == 0:
		col = Color(0.7, 0.72, 0.8)
	var l := BowlingArt.label(text, 0.08, col, 14)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.25, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if not MODES.has(settings["mode"]):
		settings["mode"] = "501"


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	_save.save(SAVE_PATH)


func _record(mode: String) -> int:
	return int(_save.get_value("records", mode, 0))


func _record_text(mode: String) -> String:
	var r := _record(mode)
	return "—" if r == 0 else "%d fl." % r


func _set_record(mode: String, darts: int) -> void:
	_save.set_value("records", mode, darts)
	_save.save(SAVE_PATH)


# ================================================================ auto-test

## Prédit où la pointe coupera le plan de la cible (même intégration que le vol).
func _predict_hit(from: Vector3, v: Vector3) -> Vector3:
	var p := from
	var vel := v
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var nose := Dart.TIP_Y * Dart.SCALE
	var prev := p + vel.normalized() * nose
	for i in 600:
		vel.y -= GRAVITY * dt
		p += vel * dt
		var tip := p + vel.normalized() * nose
		var a := _board.to_local(prev)
		var b := _board.to_local(tip)
		if a.z > 0.0 and b.z <= 0.0:
			return a.lerp(b, a.z / (a.z - b.z))
		prev = tip
	return Vector3(99, 99, 0)


func _st_velocity_for(from: Vector3, xy_real: Vector2) -> Vector3:
	var target_local := Vector3(xy_real.x * _board.face_scale, xy_real.y * _board.face_scale, 0.0)
	var target := _board.to_global(target_local)
	var t := 0.32
	var v := (target - from + Vector3(0, 0.5 * GRAVITY * t * t, 0)) / t
	for i in 6:
		var hit := _predict_hit(from, v)
		var err := _board.to_global(Vector3(hit.x, hit.y, 0.0)) - target
		v -= err / t
	return v


func _st_wait_ready() -> void:
	var guard := 0
	while (state != State.READY or not _flying.is_empty()) and state != State.GAME_OVER and guard < 2000:
		await get_tree().physics_frame
		guard += 1


## Lance une fléchette visée au centre du secteur (number, mult) ; renvoie le libellé obtenu.
func _st_throw(number: int, mult: int) -> String:
	await _st_wait_ready()
	if state == State.GAME_OVER:
		return ""
	var d: Dart = null
	for x in _darts:
		if x.state == Dart.State.HOLDER:
			d = x
			break
	if d == null:
		return ""
	var before := _turn_hits.size()
	var from := to_global(Vector3(0.2, 1.4, -0.1))
	d.state = Dart.State.HELD
	d.global_position = from
	var xy := Dartboard.segment_center(number, mult)
	_throw(d, _st_velocity_for(from, xy))
	var guard := 0
	while not _flying.is_empty() and guard < 1000:
		await get_tree().physics_frame
		guard += 1
	if _turn_hits.size() > before:
		return String(_turn_hits[_turn_hits.size() - 1])
	return String(players[current]["last"].back()) if not players[current]["last"].is_empty() else ""


func _st_check(name: String, ok: bool, detail: String = "") -> void:
	_st_log.append("%s : %s %s" % [name, "ok" if ok else "ECHEC", detail])
	if not ok:
		_st_failures.append(name)


func enable_selftest() -> void:
	_selftest = true
	_close_panel()
	_selftest_run()


func _selftest_run() -> void:
	# A. Tous les secteurs donnent le bon score
	var bad := 0
	for n in Dartboard.NUMBERS:
		for m in [1, 2, 3]:
			var info := Dartboard.score_at(Dartboard.segment_center(n, m))
			if int(info["value"]) != n * m:
				bad += 1
	var bull := Dartboard.score_at(Vector2.ZERO)
	var outer := Dartboard.score_at(Vector2(0, 0.011))
	var miss := Dartboard.score_at(Vector2(0.2, 0.0))
	_st_check("secteurs", bad == 0, "(%d faux)" % bad)
	_st_check("bull / 25 / raté", int(bull["value"]) == 50 and int(outer["value"]) == 25 and int(miss["value"]) == 0)

	# B. Conseils de sortie
	_st_check("sortie 170", DartRules.checkout(170, 3, true) == ["T20", "T20", "BULL"], str(DartRules.checkout(170, 3, true)))
	_st_check("sortie 40", DartRules.checkout(40, 3, true) == ["D20"])
	_st_check("sortie 159 impossible", DartRules.checkout(159, 3, true).is_empty())
	_st_check("sortie 50 sans double", DartRules.checkout(50, 1, false) == ["BULL"])
	_st_check("sortie 2", DartRules.checkout(2, 1, true) == ["D1"])

	# C. 501 avec sortie double, niveau facile (grande cible), sans aide à la visée
	_assist_override = 0.0
	settings.merge({"players": 1, "mode": "501", "level": "facile", "double_out": true}, true)
	start_match()
	await _st_throw(20, 3)
	await _st_throw(20, 3)
	await _st_throw(20, 3)
	await _st_wait_ready()
	_st_check("501 : 3 triples 20", int(players[0]["remaining"]) == 321, "reste %d" % int(players[0]["remaining"]))
	_st_check("volée suivante", state == State.READY or state == State.TURN_END)
	# Bust : 40 restant, 20 puis 20 (le 2e n'est pas un double)
	while state == State.TURN_END:
		await get_tree().physics_frame
	await _st_wait_ready()
	players[0]["remaining"] = 40
	players[0]["turn_start"] = 40
	var l1 := await _st_throw(20, 1)
	var l2 := await _st_throw(20, 1)
	_st_check("bust sortie non double", int(players[0]["remaining"]) == 40 and l1 == "20" and l2 == "20", "reste %d (%s %s)" % [int(players[0]["remaining"]), l1, l2])
	while state == State.TURN_END:
		await get_tree().physics_frame
	await _st_wait_ready()
	players[0]["remaining"] = 40
	players[0]["turn_start"] = 40
	var l3 := await _st_throw(20, 2)
	_st_check("victoire par double", state == State.GAME_OVER and int(players[0]["remaining"]) == 0, "%s état %d" % [l3, state])

	# D. Horloge à deux joueurs
	settings.merge({"players": 2, "mode": "horloge", "level": "facile"}, true)
	start_match()
	await _st_throw(1, 2)
	await _st_throw(5, 1)
	await _st_throw(2, 3)
	_st_check("horloge : cible suivante", int(players[0]["target"]) == 3, "cible %d" % int(players[0]["target"]))
	var guard := 0
	while current == 0 and guard < 1000:
		await get_tree().physics_frame
		guard += 1
	_st_check("changement de joueur", current == 1, "joueur %d" % current)
	await _st_throw(1, 1)
	_st_check("horloge : joueur 2", int(players[1]["target"]) == 2)

	# E. Libre, bull et tir raté
	settings.merge({"players": 1, "mode": "libre", "level": "facile"}, true)
	start_match()
	var lb := await _st_throw(25, 2)
	var lr := await _st_throw(19, 1)
	_st_check("libre : bull", lb == "BULL", lb)
	_st_check("libre : 19", lr == "19", lr)
	await _st_wait_ready()
	if _darts.size() > 0:
		var far: Dart = null
		for x in _darts:
			if x.state == Dart.State.HOLDER:
				far = x
				break
		if far:
			far.state = Dart.State.HELD
			var from := to_global(Vector3(0.2, 1.4, -0.1))
			far.global_position = from
			_throw(far, (-global_basis.z * 6.0) + global_basis.x * 6.0 + Vector3(0, 1.5, 0))
			guard = 0
			while not _flying.is_empty() and guard < 1000:
				await get_tree().physics_frame
				guard += 1
			_st_check("tir hors cible", String(players[0]["last"].back()) == "RATÉ", str(players[0]["last"]))

	# F. Aide à la visée : une fléchette mal visée tombe plus près du centre
	_assist_override = -1.0
	settings.merge({"players": 1, "mode": "501", "level": "normal", "double_out": false}, true)
	start_match()
	await _st_wait_ready()
	var from2 := to_global(Vector3(0.2, 1.4, -0.1))
	var ideal := _st_velocity_for(from2, Vector2.ZERO)
	var off := ideal + global_basis.x * 0.7
	var raw := _predict_hit(from2, off)
	var assisted := _predict_hit(from2, _apply_assist(from2, off))
	_st_check("aide à la visée", Vector2(assisted.x, assisted.y).length() < Vector2(raw.x, raw.y).length() * 0.8, "%.3f -> %.3f" % [Vector2(raw.x, raw.y).length(), Vector2(assisted.x, assisted.y).length()])

	for line in _st_log:
		print("SELFTEST darts ", line)
	print("SELFTEST darts=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
