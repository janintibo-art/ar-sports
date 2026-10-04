extends Node
## Finition visuelle v48 du support de boules de pétanque.
## Purement décoratif : aucun collider ni paramètre de gameplay n'est modifié.

const META_KEY := "petanque_stand_v48"
const STAND_X := 0.38
const STAND_Y := 0.99
const STAND_Z := -0.20


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var game := node.get_parent()
	if game == null:
		return

	var script = game.get_script()
	if script == null or script.resource_path != "res://scripts/petanque.gd":
		return

	# `_stand` est affecté avant son add_child() dans PetanqueGame._build_stand().
	# On peut donc reconnaître le bon Node3D immédiatement, sans call_deferred().
	var stand = game.get("_stand")
	if not is_instance_valid(stand) or node != stand:
		return
	if stand.has_meta(META_KEY):
		return

	_decorate_stand(stand)


func _decorate_stand(stand: Node3D) -> void:
	var steel = BowlingArt.mat(Color(0.63, 0.66, 0.70), 0.20, 0.88)
	var dark_steel = BowlingArt.mat(Color(0.18, 0.20, 0.23), 0.30, 0.82)
	var brass = BowlingArt.mat(Color(0.72, 0.53, 0.22), 0.28, 0.62)
	var wood = BowlingArt.mat(Color(0.48, 0.28, 0.12), 0.70, 0.04)

	var art := Node3D.new()
	art.name = "StandArtV48"
	stand.add_child(art)

	# Double socle pour donner plus de présence au pied.
	art.add_child(BowlingArt.cylinder(
		0.205, 0.205, 0.012, dark_steel,
		Vector3(STAND_X, 0.006, STAND_Z), 24
	))
	art.add_child(BowlingArt.cylinder(
		0.165, 0.180, 0.010, steel,
		Vector3(STAND_X, 0.017, STAND_Z), 24
	))

	# Bagues décoratives sur la colonne.
	for y_value in [0.24, 0.52, 0.80]:
		var y: float = float(y_value)
		var ring = BowlingArt.cylinder(
			0.031, 0.031, 0.012, brass,
			Vector3(STAND_X, y, STAND_Z), 16
		)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(ring)

	# Plateau supérieur en bois et cerclage métallique.
	art.add_child(BowlingArt.cylinder(
		0.105, 0.090, 0.026, wood,
		Vector3(STAND_X, STAND_Y - 0.005, STAND_Z), 24
	))
	art.add_child(BowlingArt.cylinder(
		0.110, 0.110, 0.008, brass,
		Vector3(STAND_X, STAND_Y + 0.010, STAND_Z), 24
	))

	# Trois petits plots de maintien autour du plateau.
	for angle_deg in [0.0, 120.0, 240.0]:
		var a: float = deg_to_rad(float(angle_deg))
		var px: float = STAND_X + cos(a) * 0.070
		var pz: float = STAND_Z + sin(a) * 0.070
		var peg = BowlingArt.cylinder(
			0.010, 0.010, 0.030, dark_steel,
			Vector3(px, STAND_Y + 0.030, pz), 10
		)
		peg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(peg)

	# Petite plaque frontale discrète.
	art.add_child(BowlingArt.box(
		Vector3(0.085, 0.040, 0.008),
		brass,
		Vector3(STAND_X, 0.66, STAND_Z + 0.028)
	))

	stand.set_meta(META_KEY, true)
	stand.set_meta("petanque_stand_v48_children", art.get_child_count())
