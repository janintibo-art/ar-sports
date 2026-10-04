extends Node
## Finition visuelle v45 du terrain de baby-foot.
## Tous les éléments sont purement décoratifs et sans collider.

const META_KEY := "babyfoot_field_v45"


func _ready() -> void:
	if "--selftest" in OS.get_cmdline_user_args():
		return
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null:
		return
	if script.resource_path == "res://scripts/babyfoot.gd":
		_apply_later.call_deferred(node)


func _apply_later(game: Node) -> void:
	await get_tree().process_frame
	_apply(game)


func _apply(game: Node) -> void:
	if not is_instance_valid(game):
		return
	if game.has_meta(META_KEY):
		return

	var table = game.get("_table")
	if not is_instance_valid(table):
		return

	var l: float = float(game.get("L"))
	var w: float = float(game.get("W"))
	var goal_w: float = float(game.get("GOAL_W"))
	var table_y: float = float(game.get("TABLE_Y"))
	var tz: float = float(game.get("TZ"))

	var white = BowlingArt.unshaded(Color(1.0, 1.0, 0.96, 0.95))
	var pale = BowlingArt.unshaded(Color(0.84, 0.92, 0.84, 0.72))
	var blue = BowlingArt.unshaded(Color(0.20, 0.48, 1.0, 0.78))
	var red = BowlingArt.unshaded(Color(1.0, 0.27, 0.22, 0.78))

	var art := Node3D.new()
	art.name = "FieldArtV45"
	table.add_child(art)

	var y: float = table_y + 0.003

	# Contour complet du terrain, placé juste au-dessus du tapis.
	art.add_child(BowlingArt.box(
		Vector3(l, 0.0015, 0.005),
		white,
		Vector3(0, y, tz - w / 2.0 + 0.003)
	))
	art.add_child(BowlingArt.box(
		Vector3(l, 0.0015, 0.005),
		white,
		Vector3(0, y, tz + w / 2.0 - 0.003)
	))
	art.add_child(BowlingArt.box(
		Vector3(0.005, 0.0015, w),
		white,
		Vector3(-l / 2.0 + 0.003, y, tz)
	))
	art.add_child(BowlingArt.box(
		Vector3(0.005, 0.0015, w),
		white,
		Vector3(l / 2.0 - 0.003, y, tz)
	))

	# Point central.
	var center = BowlingArt.cylinder(
		0.012, 0.012, 0.0018, white,
		Vector3(0, y + 0.0004, tz), 16
	)
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(center)

	# Repères discrets dans les quatre coins.
	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		for sz_value in [-1.0, 1.0]:
			var sz: float = float(sz_value)
			art.add_child(BowlingArt.box(
				Vector3(0.045, 0.0014, 0.005),
				pale,
				Vector3(sx * (l / 2.0 - 0.025), y + 0.0002, tz + sz * (w / 2.0 - 0.018))
			))
			art.add_child(BowlingArt.box(
				Vector3(0.005, 0.0014, 0.045),
				pale,
				Vector3(sx * (l / 2.0 - 0.018), y + 0.0002, tz + sz * (w / 2.0 - 0.025))
			))

	# Accent coloré à l'entrée de chaque but, hors collision.
	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		var goal_mat = blue if sx < 0.0 else red
		art.add_child(BowlingArt.box(
			Vector3(0.018, 0.0016, goal_w * 0.82),
			goal_mat,
			Vector3(sx * (l / 2.0 - 0.010), y + 0.0006, tz)
		))

	game.set_meta(META_KEY, true)
	game.set_meta("babyfoot_field_v45_children", art.get_child_count())
	game.set_meta("babyfoot_field_v45_l", l)
	game.set_meta("babyfoot_field_v45_w", w)
