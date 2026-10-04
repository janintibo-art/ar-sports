extends Node
## Habillage visuel v30 de la queue de billard.
## N'intervient ni dans la détection de frappe, ni dans la physique.

const META_KEY := "cue_art_v30"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BillardGame:
		_polish_game.call_deferred(node)


func _polish_game(game: BillardGame) -> void:
	if not is_instance_valid(game):
		return
	var cue = game.get("_cue")
	if not is_instance_valid(cue):
		return
	if cue.has_meta(META_KEY):
		return

	for child in cue.get_children():
		child.free()

	var detailed := VisualStyle.detailed
	var wood := BowlingArt.surface_material("wood", Color(0.82, 0.61, 0.32), Vector2(5, 1))
	var dark_wood := BowlingArt.surface_material("wood", Color(0.22, 0.105, 0.055), Vector2(3, 1))
	var ferrule := BowlingArt.mat(Color(0.92, 0.89, 0.78), 0.58)
	var leather := BowlingArt.mat(Color(0.095, 0.055, 0.038), 0.82)
	var blue := BowlingArt.mat(Color(0.16, 0.38, 0.72), 0.72)
	var metal := BowlingArt.mat(Color(0.72, 0.68, 0.56), 0.32, 0.35)
	var seg := 18 if detailed else 12

	_add_cylinder(cue, 0.0066, 0.0066, 0.025, blue, -0.5875, seg)
	_add_cylinder(cue, 0.0068, 0.0074, 0.045, ferrule, -0.5525, seg)
	_add_cylinder(cue, 0.0074, 0.0122, 0.620, wood, -0.220, seg)
	_add_cylinder(cue, 0.0128, 0.0128, 0.012, metal, 0.096, seg)
	_add_cylinder(cue, 0.0140, 0.0145, 0.205, leather, 0.2045, seg)
	_add_cylinder(cue, 0.0145, 0.0145, 0.093, dark_wood, 0.3535, seg)

	if detailed:
		for z in [0.125, 0.165, 0.245, 0.285, 0.308]:
			_add_cylinder(cue, 0.01415, 0.01415, 0.004, metal, z, 12)

	cue.set_meta(META_KEY, true)
	cue.set_meta("cue_tip_distance", game.CUE_TIP)
	cue.set_meta("cue_back_distance", game.CUE_BACK)
	cue.set_meta("cue_total_length", game.CUE_TIP + game.CUE_BACK)


func _add_cylinder(parent: Node3D, r1: float, r2: float, length: float, material: Material, z: float, segments: int) -> void:
	var part := BowlingArt.cylinder(r1, r2, length, material, Vector3(0, 0, z), segments)
	part.rotation_degrees = Vector3(90, 0, 0)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
