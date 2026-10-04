extends Node
## Habillage visuel du baby-foot.
## Cette couche ajoute seulement des détails graphiques à la table, aux barres,
## aux figurines et à la balle. La physique reste dans babyfoot.gd.

const META_KEY := "babyfoot_art_v37"
const PLAYER_META_KEY := "babyfoot_players_v41"


func _ready() -> void:
	# Le gros auto-test fonctionnel valide déjà le gameplay. Les graphismes
	# possèdent leurs tests dédiés séparés.
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

	_polish_players(game, rods, blue, red)
	_polish_ball(game)

	game.set_meta(META_KEY, true)
	game.set_meta("babyfoot_art_v37_rods", rods.size())
	game.set_meta("babyfoot_art_v37_table_children", deco.get_child_count())


func _polish_players(game: Node, rods, blue, red) -> void:
	var white = BowlingArt.mat(Color(0.94, 0.94, 0.90), 0.58)
	var skin = BowlingArt.mat(Color(0.93, 0.76, 0.60), 0.62)
	var shoe = BowlingArt.mat(Color(0.035, 0.04, 0.05), 0.70)
	var hair = BowlingArt.mat(Color(0.12, 0.075, 0.045), 0.72)
	var player_count: int = 0

	for r in rods:
		if not is_instance_valid(r.pivot):
			continue
		var team_color = blue if int(r.team) == 1 else red
		var shorts_color = BowlingArt.mat(
			Color(0.035, 0.08, 0.20) if int(r.team) == 1 else Color(0.22, 0.035, 0.035),
			0.58
		)

		for man in r.pivot.get_children():
			if not is_instance_valid(man):
				continue
			var player_art := Node3D.new()
			player_art.name = "PlayerArtV41"
			man.add_child(player_art)

			# Maillot : bande claire sur le torse existant.
			player_art.add_child(BowlingArt.box(
				Vector3(0.031, 0.018, 0.028),
				white,
				Vector3(0, -0.028, 0)
			))
			# Short sous le maillot.
			player_art.add_child(BowlingArt.box(
				Vector3(0.032, 0.018, 0.029),
				shorts_color,
				Vector3(0, -0.050, 0)
			))
			# Deux bras courts, légèrement écartés.
			for side_value in [-1.0, 1.0]:
				var side: float = float(side_value)
				var arm = BowlingArt.box(
					Vector3(0.010, 0.034, 0.010),
					skin,
					Vector3(side * 0.020, -0.026, 0)
				)
				arm.rotation_degrees = Vector3(0, 0, side * 16.0)
				player_art.add_child(arm)

			# Petite chevelure/casque au-dessus de la tête d'origine.
			player_art.add_child(BowlingArt.sphere(
				0.014,
				hair,
				Vector3(0, 0.021, 0),
				8
			))
			# Chaussure sombre sur le pied de frappe, sans collider.
			player_art.add_child(BowlingArt.box(
				Vector3(0.040, 0.012, 0.032),
				shoe,
				Vector3(0, -0.092, 0)
			))
			# Petit écusson d'équipe sur le maillot.
			player_art.add_child(BowlingArt.box(
				Vector3(0.008, 0.008, 0.030),
				team_color,
				Vector3(0, -0.020, -0.001)
			))
			player_count += 1

	game.set_meta(PLAYER_META_KEY, true)
	game.set_meta("babyfoot_players_v41_count", player_count)


func _polish_ball(game: Node) -> void:
	var ball = game.get("_ball_node")
	if not is_instance_valid(ball):
		return

	var ball_art := Node3D.new()
	ball_art.name = "BallArtV41"
	ball.add_child(ball_art)

	var patch = BowlingArt.mat(Color(0.07, 0.075, 0.08), 0.52)
	var positions := [
		Vector3(0.014, 0, 0),
		Vector3(-0.014, 0, 0),
		Vector3(0, 0.014, 0),
		Vector3(0, -0.014, 0),
		Vector3(0, 0, 0.014),
		Vector3(0, 0, -0.014),
	]
	for p in positions:
		var dot = BowlingArt.sphere(0.004, patch, p, 8)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball_art.add_child(dot)

	game.set_meta("babyfoot_ball_v41", true)
	game.set_meta("babyfoot_ball_v41_patches", ball_art.get_child_count())
