extends Node
## Habillage visuel v36 de la table de billard.
## Ajoute uniquement des détails décoratifs au Node3D `_table`.
## Aucune dimension utile, poche logique, collision ou règle n'est modifiée.

const META_KEY := "table_art_v36"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null:
		return
	if script.resource_path == "res://scripts/billard.gd":
		_polish.call_deferred(node)


func _polish(game: Node) -> void:
	if not is_instance_valid(game):
		return
	var table = game.get("_table")
	if not is_instance_valid(table):
		return
	if table.has_meta(META_KEY):
		return

	var px := float(game.get("PX"))
	var pz := float(game.get("PZ"))
	var table_y := float(game.get("TABLE_Y"))
	var tz := float(game.get("TZ"))
	var detailed := VisualStyle.detailed

	var metal := BowlingArt.mat(Color(0.62, 0.52, 0.34), 0.32, 0.48)
	var dark := BowlingArt.mat(Color(0.08, 0.055, 0.035), 0.74)
	var inlay := BowlingArt.mat(Color(0.92, 0.82, 0.56), 0.42, 0.12)
	var leather := BowlingArt.mat(Color(0.055, 0.12, 0.075), 0.86)

	var deco := Node3D.new()
	deco.name = "TableArtV36"
	table.add_child(deco)

	# Liseré sombre sous le cadre : il donne davantage d'épaisseur visuelle,
	# mais reste sous le plan de jeu et hors des zones physiques.
	deco.add_child(BowlingArt.box(
		Vector3(px * 2.0 + 0.34, 0.025, pz * 2.0 + 0.34),
		dark,
		Vector3(0, table_y - 0.145, tz)
	))

	# Quatre renforts de coins métalliques, positionnés à l'extérieur du tapis.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := BowlingArt.cylinder(
				0.040, 0.040, 0.018, metal,
				Vector3(sx * (px + 0.105), table_y + 0.045, tz + sz * (pz + 0.105)),
				14
			)
			deco.add_child(corner)

	# Incrustations centrales sur chaque grand rail.
	for sx in [-0.66, -0.22, 0.22, 0.66]:
		for sz in [-1.0, 1.0]:
			deco.add_child(BowlingArt.box(
				Vector3(0.038, 0.006, 0.018),
				inlay,
				Vector3(sx * px, table_y + 0.044, tz + sz * (pz + 0.12))
			))

	# Petites garnitures en cuir autour des six ouvertures visuelles des poches.
	# Elles n'interviennent pas dans la détection de poche.
	var pocket_points = [
		Vector2(-px, -pz), Vector2(px, -pz),
		Vector2(-px, pz), Vector2(px, pz),
		Vector2(0, -pz), Vector2(0, pz)
	]
	for pp in pocket_points:
		var collar := BowlingArt.cylinder(
			0.050, 0.050, 0.010, leather,
			Vector3(pp.x * 1.01, table_y + 0.007, tz + pp.y * 1.01),
			18
		)
		collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		deco.add_child(collar)

	# En qualité détaillée : petits boulons décoratifs sur le cadre.
	if detailed:
		for sx in [-0.82, 0.82]:
			for sz in [-1.0, 1.0]:
				var bolt := BowlingArt.cylinder(
					0.007, 0.007, 0.005, metal,
					Vector3(sx * px, table_y + 0.047, tz + sz * (pz + 0.12)),
					10
				)
				bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				deco.add_child(bolt)

	table.set_meta(META_KEY, true)
	table.set_meta("table_art_v36_children", deco.get_child_count())
	table.set_meta("table_art_v36_px", px)
	table.set_meta("table_art_v36_pz", pz)
