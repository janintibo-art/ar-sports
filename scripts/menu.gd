class_name GameMenu
extends Node3D
## Menu d'accueil : logo animé, quatre cartes de jeux avec pictogramme, bouton Quitter.
## On vise avec le laser et on appuie sur la gâchette. Au tout premier affichage,
## une intro fait apparaître le logo puis les cartes une à une.

signal game_chosen(game_id: String)

const GAMES := [
	{"id": "bowling", "title": "Bowling", "sub": "1 à 4 joueurs", "color": Color(0.85, 0.25, 0.25), "ready": true},
	{"id": "flechettes", "title": "Fléchettes", "sub": "301 · 501 · horloge", "color": Color(0.25, 0.4, 0.85), "ready": true},
	{"id": "petanque", "title": "Pétanque", "sub": "contre l'ordinateur", "color": Color(0.75, 0.6, 0.2), "ready": true},
	{"id": "pingpong", "title": "Ping-pong", "sub": "contre l'ordinateur", "color": Color(0.2, 0.6, 0.35), "ready": true},
	{"id": "molkky", "title": "Mölkky", "sub": "50 points · 2 à 4 joueurs", "color": Color(0.8, 0.5, 0.2), "ready": true},
	{"id": "palet", "title": "Palet", "sub": "3 variantes", "color": Color(0.3, 0.7, 0.85), "ready": true},
	{"id": "billard", "title": "Billard", "sub": "américain · 8 · 9", "color": Color(0.1, 0.5, 0.45), "ready": true},
	{"id": "babyfoot", "title": "Baby-foot", "sub": "contre l'ordinateur", "color": Color(0.85, 0.35, 0.15), "ready": true},
	{"id": "tir", "title": "Tir", "sub": "tir à l'arc · bientôt d'autres", "color": Color(0.65, 0.2, 0.3), "ready": true},
]

const QUIT := {"id": "quit", "title": "Quitter", "sub": "", "color": Color(0.35, 0.35, 0.42), "ready": true}

const CARD_SIZE := Vector3(0.29, 0.22, 0.02)
const QUIT_SIZE := Vector3(0.3, 0.09, 0.02)
const LOGO_Y := 0.53
const COLS := 3
const CARD_DX := 0.305
const CARD_Y0 := 0.15
const CARD_DY := 0.235
const QUIT_Y := -0.52

const INTRO_HOLD := 1.9
const INTRO_MOVE := 0.8
const INTRO_CARD0 := 2.1
const INTRO_CARD_STEP := 0.14
const INTRO_END := 3.2

var _panels: Array[StaticBody3D] = []
var _hovered: StaticBody3D = null
var _info: Label3D
var _logo: Logo
var _active := false
var _intro_t := -1.0          # -1 : en attente ; INTRO_END et plus : terminée
var _icons: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	_logo = Logo.new()
	add_child(_logo)

	_info = _make_label("Vise un jeu avec le laser et appuie sur la gâchette", 0.032)
	_info.position = Vector3(0, -0.62, 0)
	add_child(_info)

	for i in GAMES.size():
		var panel := _make_card(GAMES[i], CARD_SIZE)
		panel.position = Vector3((i % COLS - (COLS - 1) / 2.0) * CARD_DX, CARD_Y0 - CARD_DY * (i / COLS), 0)
		add_child(panel)
		_panels.append(panel)
	var quit_panel := _make_card(QUIT, QUIT_SIZE)
	quit_panel.position = Vector3(0, QUIT_Y, 0)
	add_child(quit_panel)
	_panels.append(quit_panel)
	_apply_intro()


# ---------------------------------------------------------------- intro

## Lance l'intro : le logo apparaît au centre, puis monte et laisse place aux cartes.
func play_intro() -> void:
	_intro_t = 0.0
	_logo.celebrate(2.2)
	Sound.play("next_player", -3.0)
	_apply_intro()


func skip_intro() -> void:
	_intro_t = INTRO_END + 1.0
	_apply_intro()


func intro_running() -> bool:
	return _intro_t >= 0.0 and _intro_t < INTRO_END


## Image fixe de l'intro à l'instant t (captures d'écran).
func show_intro_at(t: float) -> void:
	_intro_t = t
	_apply_intro()


static func _back_out(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var p := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * p * p * p + c1 * p * p


static func _smooth(x: float) -> float:
	var s := clampf(x, 0.0, 1.0)
	return s * s * (3.0 - 2.0 * s)


func _apply_intro() -> void:
	if _logo == null:
		return
	var t := _intro_t
	var done := t >= INTRO_END
	var logo_scale := 1.0
	var logo_y := LOGO_Y
	var logo_rot := 0.0
	var card_progress := 1.0
	if t < 0.0:
		logo_scale = 1.4
		logo_y = 0.0
		card_progress = -1.0
	elif not done:
		if t < 0.8:
			var k := _back_out(t / 0.8)
			logo_scale = lerpf(0.2, 1.4, k)
			logo_rot = lerpf(-1.2, 0.0, _smooth(t / 0.8))
			logo_y = 0.0
		elif t < INTRO_HOLD:
			logo_scale = 1.4
			logo_y = 0.0
		else:
			var m := _smooth((t - INTRO_HOLD) / INTRO_MOVE)
			logo_scale = lerpf(1.4, 1.0, m)
			logo_y = lerpf(0.0, LOGO_Y, m)
		card_progress = t
	_logo.scale = Vector3.ONE * logo_scale
	_logo.position = Vector3(0, logo_y, 0)
	_logo.rotation = Vector3(0, logo_rot, 0)
	for i in _panels.size():
		var s := 1.0
		if card_progress < 0.0:
			s = 0.0
		elif not done:
			s = _back_out((card_progress - INTRO_CARD0 - INTRO_CARD_STEP * i) / 0.4)
			if card_progress < INTRO_CARD0 + INTRO_CARD_STEP * i:
				s = 0.0
		var hover := 1.06 if _panels[i] == _hovered else 1.0
		_panels[i].scale = Vector3.ONE * maxf(s * hover, 0.001)
		_panels[i].visible = s > 0.001
	_info.visible = done
	_apply_collisions()


func _apply_collisions() -> void:
	var on := _active and (_intro_t < 0.0 or _intro_t >= INTRO_END)
	if _intro_t < 0.0:
		on = false
	for p in _panels:
		p.collision_layer = 2 if on else 0


## Active ou coupe la visée des cartes (coupée quand un jeu est lancé).
func set_active(on: bool) -> void:
	_active = on
	_apply_collisions()


func _process(delta: float) -> void:
	_t += delta
	if _intro_t >= 0.0 and _intro_t < INTRO_END:
		_intro_t += delta
		_apply_intro()
	for i in _icons.size():
		_icons[i].rotation = Vector3(0.0, sin(_t * 1.2 + i * 1.7) * 0.35, 0.0)


## Place le menu à environ un mètre devant le regard.
func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var pos := head.origin + forward * 1.0
	pos.y = max(head.origin.y - 0.1, 0.8)
	global_position = pos
	# Le panneau regarde le joueur : son axe +Z pointe vers lui.
	global_basis = Basis.looking_at(forward, Vector3.UP)


func update_hover(objects: Array) -> void:
	var target: StaticBody3D = null
	for obj in objects:
		if obj is StaticBody3D and _panels.has(obj):
			target = obj
			break
	if target == _hovered:
		return
	if _hovered:
		_set_highlight(_hovered, false)
	_hovered = target
	if _hovered:
		_set_highlight(_hovered, true)


## Appelé quand une gâchette est pressée en visant `obj`.
## Renvoie true si un jeu a été lancé.
func click(obj: Object) -> bool:
	if not (obj is StaticBody3D and _panels.has(obj)):
		return false
	var game: Dictionary = obj.get_meta("game")
	if game["ready"]:
		Sound.play("ui_click", -4.0)
		game_chosen.emit(game["id"])
		return true
	_info.text = "%s arrive bientôt !" % game["title"]
	return false


func _make_card(game: Dictionary, size: Vector3) -> StaticBody3D:
	var compact := size == QUIT_SIZE
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta("game", game)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.03)
	shape.shape = box
	body.add_child(shape)

	var base: Color = game["color"]
	if not game["ready"]:
		base = base.darkened(0.5)
	var frame := BowlingArt.box(Vector3(size.x + 0.014, size.y + 0.014, 0.012), BowlingArt.unshaded(Color(0.9, 0.9, 0.95) if game["ready"] else Color(0.45, 0.45, 0.5)), Vector3(0, 0, -0.008))
	frame.name = "Cadre"
	body.add_child(frame)
	var face := BowlingArt.gradient_panel(Vector2(size.x, size.y), base.lightened(0.18), base.darkened(0.5))
	face.name = "Fond"
	face.position = Vector3(0, 0, 0.0)
	body.add_child(face)
	body.set_meta("base_color", base)

	if compact:
		var l := _make_label(game["title"], 0.045)
		l.position = Vector3(0, 0, 0.004)
		body.add_child(l)
		return body

	# Pictogramme en haut, titre et sous-titre dessous
	var icon := GameIcons.build(game["id"])
	icon.position = Vector3(0, 0.035, 0.05)
	icon.scale = Vector3.ONE * 0.95
	body.add_child(icon)
	if game["ready"]:
		_icons.append(icon)
	var title := BowlingArt.label(game["title"], 0.036, Color.WHITE, 12)
	title.font = BowlingArt.bold_font()
	title.position = Vector3(0, -0.058, 0.006)
	body.add_child(title)
	var sub := BowlingArt.label(game["sub"], 0.019, Color(1, 0.95, 0.75) if game["ready"] else Color(1, 1, 1, 0.65), 8)
	sub.position = Vector3(0, -0.092, 0.006)
	body.add_child(sub)
	if not game["ready"]:
		var ribbon := BowlingArt.box(Vector3(0.13, 0.032, 0.004), BowlingArt.unshaded(Color(0.85, 0.2, 0.2)), Vector3(size.x / 2.0 - 0.07, size.y / 2.0 - 0.025, 0.004))
		body.add_child(ribbon)
		var rl := BowlingArt.label("BIENTÔT", 0.02, Color.WHITE, 6)
		rl.position = Vector3(size.x / 2.0 - 0.07, size.y / 2.0 - 0.025, 0.008)
		body.add_child(rl)
	return body


func _set_highlight(panel: StaticBody3D, on: bool) -> void:
	var frame := panel.get_node("Cadre") as MeshInstance3D
	var mat := frame.material_override as StandardMaterial3D
	var game: Dictionary = panel.get_meta("game")
	if on:
		mat.albedo_color = Color(1.0, 0.85, 0.3)
	else:
		mat.albedo_color = Color(0.9, 0.9, 0.95) if game["ready"] else Color(0.45, 0.45, 0.5)
	panel.scale = Vector3.ONE * (1.06 if on else 1.0)


static func _make_label(text: String, size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = size / 96.0
	label.font_size = 96
	label.outline_size = 18
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.double_sided = false
	label.no_depth_test = false
	return label
