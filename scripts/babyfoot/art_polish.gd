extends Node
## Habillage visuel v37 du baby-foot.
## Cette couche ajoute seulement des détails graphiques à la table et aux barres.
## La physique, les dimensions du terrain et les mouvements restent dans babyfoot.gd.

const META_KEY := "babyfoot_art_v37"


func _ready() -> void:
	# Le gros auto-test fonctionnel valide déjà le gameplay du baby-foot et
	# termine très vite plusieurs scènes successives. La couche graphique v37
	# possède son propre test dédié (`check_v37_babyfoot_art.gd`) juste après.
	# On évite donc d'instancier ces décorations pendant `--selftest`.
	if "--selftest" in OS.get_cmdline_user_args():
		return
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null:
		return
	if script.resource_path == "res://scripts/babyfoot.gd":
		_polish.call_deferred(node)


func _polish(game: Node) -> void:
	if not is_instance_valid(game):
		return
	if game.has_meta(META_KEY):
		return

	var table = game.get("_table")
	var rods = game.get("_rods")
	if not is_instance_valid(table) or rods == null:
		return

	var l: float = float(game.get("L"))
	var w: float = float(game.get("W"))
	var goal_w: float = float(game.get("GOAL_W"))
	var table_y: float = float(game.get("TABLE_Y"))
	var tz: float = float(game.get("TZ"))

	var chrome = BowlingArt.mat(Color(0.70, 0.72, 0.76), 0.24, 0.82)
	var brass = BowlingArt.mat(Color(0.72, 0.55, 0.23), 0.34, 0.55)
	var black = BowlingArt.mat(Color(0.055, 0.06, 0.07), 0.78)
	var red = BowlingArt.mat(Color(0.66, 0.10, 0.08), 0.48)
	var blue = BowlingArt.mat(Color(0.08, 0.24, 0.66), 0.48)
	var net = BowlingArt.mat(Color(0.80, 0.80, 0.76), 0.88)

	var deco := Node3D.new()
	deco.name = "BabyfootArtV37"
	table.add_child(deco)

	for sy_value in [-1.0, 1.0]:
		var sy: float = float(sy_value)
		deco.add_child(BowlingArt.box(
			Vector3(l + 0.31, 0.020, 0.025),
			chrome,
			Vector3(0, table_y - 0.028, tz + sy * (w / 2.0 + 0.135))
		))

	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		for sy_value in [-1.0, 1.0]:
			var sy: float = float(sy_value)
			deco.add_child(BowlingArt.box(
				Vector3(0.045, 0.13, 0.045),
				brass,
				Vector3(sx * (l / 2.0 + 0.125), table_y - 0.09, tz + sy * (w / 2.0 + 0.125))
			))

	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		var gx: float = sx * (l / 2.0 + 0.145)
		deco.add_child(BowlingArt.box(
			Vector3(0.025, 0.12, goal_w + 0.06),
			black,
			Vector3(gx, table_y + 0.015, tz)
		))

		for iy_value in [-1, 0, 1]:
			var iy: int = int(iy_value)
			var z: float = tz + float(iy) * goal_w * 0.32
			deco.add_child(BowlingArt.box(
				Vector3(0.003, 0.10, 0.003),
				net,
				Vector3(gx + sx * 0.014, table_y + 0.015, z)
			))

		for ih_value in [-1, 0, 1]:
			var ih: int = int(ih_value)
			var y: float = table_y + 0.015 + float(ih) * 0.035
			deco.add_child(BowlingArt.box(
				Vector3(0.003, 0.003, goal_w + 0.025),
				net,
				Vector3(gx + sx * 0.014, y, tz)
			))

	for r in rods:
		var rod_node = r.node
		if not is_instance_valid(rod_node):
			continue

		var art_node := Node3D.new()
		art_node.name = "RodArtV37"
		rod_node.add_child(art_node)

		var team_mat = blue if int(r.team) == 1 else red

		for sy_value in [-1.0, 1.0]:
			var sy: float = float(sy_value)
			var end_z: float = sy * 0.545

			var cap = BowlingArt.cylinder(
				0.021, 0.021, 0.018, chrome,
				Vector3(0, 0, end_z), 14
			)
			cap.rotation_degrees = Vector3(90, 0, 0)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			art_node.add_child(cap)

			var grip = BowlingArt.cylinder(
				0.020, 0.018, 0.075, team_mat,
				Vector3(0, 0, sy * 0.505), 14
			)
			grip.rotation_degrees = Vector3(90, 0, 0)
			grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			art_node.add_child(grip)

		var ring = BowlingArt.cylinder(
			0.010, 0.010, 0.014, brass,
			Vector3.ZERO, 12
		)
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art_node.add_child(ring)

	game.set_meta(META_KEY, true)
	game.set_meta("babyfoot_art_v37_rods", rods.size())
	game.set_meta("babyfoot_art_v37_table_children", deco.get_child_count())
