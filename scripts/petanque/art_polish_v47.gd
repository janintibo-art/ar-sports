extends Node
## Finition visuelle v47 des boules de pétanque et du cochonnet.
## Les éléments ajoutés sont uniquement des MeshInstance3D : aucun collider,
## rayon physique, masse ou comportement n'est modifié.

const R_B := 0.0375
const R_J := 0.015


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if not (node is MeshInstance3D):
		return
	if node.has_meta("petanque_art_v47"):
		return

	var parent := node.get_parent()
	if parent == null:
		return
	var game := parent.get_parent()
	if game == null:
		return

	var script = game.get_script()
	if script == null or script.resource_path != "res://scripts/petanque.gd":
		return

	var balls_root = game.get("_balls_root")
	if not is_instance_valid(balls_root) or parent != balls_root:
		return

	var mesh = node.mesh
	if mesh == null or not (mesh is SphereMesh):
		return

	var radius: float = float(mesh.radius)
	if is_equal_approx(radius, R_J):
		_decorate_jack(node)
	elif is_equal_approx(radius, R_B):
		_decorate_boule(node)


func _decorate_boule(node: MeshInstance3D) -> void:
	var base_color := Color(0.65, 0.68, 0.72)
	var original = node.material_override
	if original is StandardMaterial3D:
		base_color = (original as StandardMaterial3D).albedo_color

	# Acier légèrement désaturé : l'équipe reste identifiable, mais la boule
	# paraît davantage métallique que simplement peinte.
	var steel_tint: Color = base_color.lerp(Color(0.72, 0.74, 0.76), 0.48)
	node.material_override = BowlingArt.mat(steel_tint, 0.17, 0.94)

	var art := Node3D.new()
	art.name = "PetanqueArtV47"
	node.add_child(art)

	var groove_color: Color = steel_tint.darkened(0.46)
	var groove = BowlingArt.mat(groove_color, 0.30, 0.72)

	# Fine strie centrale supplémentaire : complète les deux stries historiques
	# déjà créées par le jeu sans modifier la silhouette physique.
	var ring := BowlingArt.cylinder(
		R_B * 1.006, R_B * 1.006, 0.0018,
		groove, Vector3.ZERO, 20
	)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(ring)

	# Deux petits poinçons métalliques opposés, comme un marquage de fabricant.
	var stamp_mat = BowlingArt.mat(steel_tint.lightened(0.20), 0.13, 0.98)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var stamp = BowlingArt.sphere(
			0.0032, stamp_mat,
			Vector3(side * R_B * 0.94, 0, 0), 7
		)
		stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(stamp)

	node.set_meta("petanque_art_v47", true)
	node.set_meta("petanque_art_v47_kind", "boule")
	node.set_meta("petanque_art_v47_radius", R_B)


func _decorate_jack(node: MeshInstance3D) -> void:
	# Cochonnet plus proche d'un petit objet en bois verni.
	node.material_override = BowlingArt.mat(Color(0.88, 0.59, 0.16), 0.62, 0.04)

	var art := Node3D.new()
	art.name = "PetanqueArtV47"
	node.add_child(art)

	var dark = BowlingArt.mat(Color(0.31, 0.17, 0.055), 0.72, 0.02)

	# Deux petits nœuds de bois opposés.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var knot = BowlingArt.sphere(
			0.0022, dark,
			Vector3(0, side * R_J * 0.92, 0), 6
		)
		knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(knot)

	# Une fine bande sombre aide à lire sa rotation à distance.
	var band := BowlingArt.cylinder(
		R_J * 1.006, R_J * 1.006, 0.0012,
		dark, Vector3.ZERO, 14
	)
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(band)

	node.set_meta("petanque_art_v47", true)
	node.set_meta("petanque_art_v47_kind", "cochonnet")
	node.set_meta("petanque_art_v47_radius", R_J)
