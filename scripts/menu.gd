class_name GameMenu
extends Node3D
## Menu flottant : quatre panneaux, on vise avec le laser et on appuie sur la gâchette.

signal game_chosen(game_id: String)

const GAMES := [
	{"id": "bowling", "title": "Bowling", "color": Color(0.85, 0.25, 0.25), "ready": true},
	{"id": "petanque", "title": "Pétanque", "color": Color(0.75, 0.6, 0.2), "ready": false},
	{"id": "pingpong", "title": "Ping-pong", "color": Color(0.2, 0.6, 0.35), "ready": false},
	{"id": "flechettes", "title": "Fléchettes", "color": Color(0.25, 0.4, 0.85), "ready": false},
]

const QUIT := {"id": "quit", "title": "Quitter", "color": Color(0.35, 0.35, 0.4), "ready": true}

const PANEL_SIZE := Vector3(0.36, 0.24, 0.02)
const QUIT_SIZE := Vector3(0.3, 0.1, 0.02)
const SPACING := 0.42

var _panels: Array[StaticBody3D] = []
var _hovered: StaticBody3D = null
var _info: Label3D


func _ready() -> void:
	var title := _make_label("AR Sports", 0.09)
	title.position = Vector3(0, 0.36, 0)
	add_child(title)

	_info = _make_label("Vise un jeu et appuie sur la gâchette\nBouton Menu (manette gauche) : quitter", 0.035)
	_info.position = Vector3(0, -0.5, 0)
	add_child(_info)

	for i in GAMES.size():
		var game: Dictionary = GAMES[i]
		var col := i % 2
		var row := i / 2
		var panel := _make_panel(game)
		panel.position = Vector3((col - 0.5) * SPACING, (0.5 - row) * 0.3 + 0.02, 0)
		add_child(panel)
		_panels.append(panel)

	var quit_panel := _make_panel(QUIT, QUIT_SIZE)
	quit_panel.position = Vector3(0, -0.38, 0)
	add_child(quit_panel)
	_panels.append(quit_panel)


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
		game_chosen.emit(game["id"])
		return true
	_info.text = "%s arrive bientôt !" % game["title"]
	return false


func _make_panel(game: Dictionary, size: Vector3 = PANEL_SIZE) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("game", game)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Fond"
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	var base_color: Color = game["color"]
	if not game["ready"]:
		base_color = base_color.darkened(0.55)
	mat.albedo_color = base_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	body.add_child(mesh)
	body.set_meta("base_color", base_color)

	var label := _make_label(game["title"], 0.055 if size == PANEL_SIZE else 0.045)
	label.position = Vector3(0, 0.02 if size == PANEL_SIZE else 0.0, size.z / 2.0 + 0.002)
	body.add_child(label)

	if not game["ready"]:
		var soon := _make_label("bientôt", 0.03)
		soon.modulate = Color(1, 1, 1, 0.7)
		soon.position = Vector3(0, -0.06, size.z / 2.0 + 0.002)
		body.add_child(soon)
	return body


func _set_highlight(panel: StaticBody3D, on: bool) -> void:
	var mesh := panel.get_node("Fond") as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	var base: Color = panel.get_meta("base_color")
	mat.albedo_color = base.lightened(0.35) if on else base
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
