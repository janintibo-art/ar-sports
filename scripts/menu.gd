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
	{"id": "tir", "title": "Tir", "sub": "4 disciplines", "color": Color(0.65, 0.2, 0.3), "ready": true},
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
const INTRO_END := 4.2

var _panels: Array[StaticBody3D] = []
var _hovered: StaticBody3D = null
var _help_title: Label3D
var _help_bg: MeshInstance3D
var _info: Label3D
var _logo: Logo
var _active := false
var _intro_t := -1.0          # -1 : en attente ; INTRO_END et plus : terminée
var _icons: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	_logo = Logo.new()
	add_child(_logo)

	_help_bg = BowlingArt.rounded_panel(Vector2(0.92, 0.16), Color(0.06, 0.09, 0.15), Color(0.015, 0.025, 0.05))
	_help_bg.position = Vector3(0, -0.695, -0.01)
	add_child(_help_bg)
	_help_title = BowlingArt.label("Choisis un jeu", 0.029, Color(0.75, 0.9, 1), 6)
	_help_title.position = Vector3(0, -0.648, 0.004)
	add_child(_help_title)
	_info = _make_label("Vise une carte avec le laser\net appuie sur la gâchette", 0.026)
	_info.position = Vector3(0, -0.716, 0.004)
	add_child(_info)

	for i in GAMES.size():
		var panel := _make_card(GAMES[i], CARD_SIZE)
		panel.position = Vector3((i % COLS - (COLS - 1) / 2.0) * CARD_DX, CARD_Y0 - CARD_DY * (i / COLS), 0)
		add_child(panel)
		_panels.append(panel)
	var quality := {"id": "quality", "title": _quality_title(), "sub": "", "color": Color(0.17, 0.42, 0.48), "ready": true}
	var quality_panel := _make_card(quality, Vector3(0.29, 0.09, 0.02))
	quality_panel.position = Vector3(-0.305, QUIT_Y, 0)
	add_child(quality_panel)
	_panels.append(quality_panel)
	var comfort := {"id": "comfort", "title": "Confort", "sub": "", "color": Color(0.3, 0.3, 0.55), "ready": true}
	var comfort_panel := _make_card(comfort, Vector3(0.27, 0.09, 0.02))
	comfort_panel.position = Vector3(0, QUIT_Y, 0)
	add_child(comfort_panel)
	_panels.append(comfort_panel)
	var quit_panel := _make_card(QUIT, Vector3(0.27, 0.09, 0.02))
	quit_panel.position = Vector3(0.29, QUIT_Y, 0)
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
	_help_title.visible = done
	_help_bg.visible = done
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
	var pos := head.origin + forward * (1.15 * VisualStyle.distance_factor)
	pos.y = max(head.origin.y - 0.04, 0.8)
	global_position = pos
	# Le panneau regarde le joueur : son axe +Z pointe vers lui.
	global_basis = Basis.looking_at(forward, Vector3.UP)
	scale = Vector3.ONE * VisualStyle.ui_scale


func update_hover(objects: Array) -> void:
	var target: StaticBody3D = null
	for obj in (objects if _active and not intro_running() else []):
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
	_update_help()


## Appelé quand une gâchette est pressée en visant `obj`.
## Renvoie true si un jeu a été lancé.
func click(obj: Object) -> bool:
	if not _active or intro_running() or _intro_t < 0.0 or not (obj is StaticBody3D and _panels.has(obj)):
		return false
	var game: Dictionary = obj.get_meta("game")
	if game["id"] == "quality":
		var result := VisualStyle.set_detailed(not VisualStyle.detailed)
		var label := obj.get_node("CompactLabel") as Label3D
		label.text = _quality_title()
		_help_title.text = _quality_title()
		_info.text = "Appliqué au prochain jeu" if result == OK else "Réglage appliqué, sauvegarde impossible"
		BowlingArt.fit_label(_info, 0.84)
		Sound.play("ui_click", -4.0)
		return false
	if game["ready"]:
		Sound.play("ui_click", -4.0)
		game_chosen.emit(game["id"])
		return true
	_info.text = "%s arrive bientôt !" % game["title"]
	return false


func _make_card(game: Dictionary, size: Vector3) -> StaticBody3D:
	var compact := size.y <= 0.1
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
	var frame := BowlingArt.rounded_panel(Vector2(size.x + 0.014, size.y + 0.014), base.lightened(0.35), base.darkened(0.25), 0.022)
	frame.position.z = -0.008
	frame.name = "Cadre"
	body.add_child(frame)
	var face := BowlingArt.rounded_panel(Vector2(size.x, size.y), Color(0.075, 0.10, 0.17).lerp(base, 0.18), Color(0.018, 0.025, 0.055))
	face.name = "Fond"
	face.position = Vector3(0, 0, 0.0)
	body.add_child(face)
	body.set_meta("base_color", base)

	if compact:
		var l := _make_label(game["title"], 0.038)
		l.name = "CompactLabel"
		BowlingArt.fit_label(l, size.x - 0.025)
		l.position = Vector3(0, 0, 0.004)
		body.add_child(l)
		return body

	# Pictogramme en haut, titre et sous-titre dessous
	var icon := GameIcons.build(game["id"])
	icon.position = Vector3(0, 0.050, 0.05)
	icon.scale = Vector3.ONE * 0.72
	body.add_child(icon)
	if game["ready"]:
		_icons.append(icon)
	var title := BowlingArt.label(game["title"], 0.036, Color.WHITE, 12)
	title.font = BowlingArt.bold_font()
	title.position = Vector3(0, -0.058, 0.006)
	BowlingArt.fit_label(title, size.x - 0.025)
	body.add_child(title)
	var sub := BowlingArt.label(game["sub"], 0.019, Color(1, 0.95, 0.75) if game["ready"] else Color(1, 1, 1, 0.65), 8)
	sub.position = Vector3(0, -0.092, 0.006)
	BowlingArt.fit_label(sub, size.x - 0.022)
	body.add_child(sub)
	var strip := BowlingArt.rounded_panel(Vector2(size.x - 0.035, 0.004), base.lightened(0.3), base, 0.002)
	strip.position = Vector3(0, size.y * 0.5 - 0.014, 0.004)
	body.add_child(strip)
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
		mat.albedo_color = Color.WHITE
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


static func _quality_title() -> String:
	return "Décor : détaillé" if VisualStyle.detailed else "Décor : léger"


const HELP := {
	"bowling": "Prends la boule avec gâchette ou poignée.\nFais ton geste, puis relâche pour lancer.",
	"flechettes": "Prends une fléchette avec gâchette ou poignée.\nVise la cible et relâche pour lancer.",
	"petanque": "Prends une boule sur le support.\nLance doucement, puis relâche la prise.",
	"pingpong": "Gâchette : lance la balle en l'air.\nFrappe-la ensuite avec ta raquette.",
	"molkky": "Prends le bâton, puis relâche pour lancer.\nVise les quilles pour atteindre 50 points.",
	"palet": "Prends un palet, puis relâche pour lancer.\nFais-le atterrir sur la planche.",
	"billard": "Prends la queue sur son support.\nFrappe la boule blanche avec la pointe.",
	"babyfoot": "Prends une poignée près de la barre.\nDéplace la main pour glisser et faire tourner.",
	"tir": "Arc · carabine · ball-trap · couteau.\nChoisis ta discipline sur l'écran suivant.",
	"quality": "Détaillé : accessoires et végétation enrichis.\nLéger : moins d'objets, au prochain jeu.",
	"comfort": "Réglages des menus, gestes et volumes.\nGuide des commandes de chaque jeu.",
	"quit": "Ferme AR Sports et retourne au Quest.",
}

func _update_help() -> void:
	_info.pixel_size = 0.026 / 96.0
	if _hovered:
		var game: Dictionary = _hovered.get_meta("game")
		_help_title.text = _quality_title() if game["id"] == "quality" else String(game["title"])
		_info.text = HELP.get(game["id"], "Vise puis appuie sur la gâchette")
	else:
		_help_title.text = "Choisis un jeu"
		_info.text = "Vise une carte avec le laser\net appuie sur la gâchette"
	BowlingArt.fit_label(_info, 0.84)
