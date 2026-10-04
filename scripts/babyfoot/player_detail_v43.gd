extends Node
## Détails visuels v43 des figurines de baby-foot.
## Purement décoratif : aucun collider ni paramètre de gameplay n'est modifié.

const META_KEY := "babyfoot_player_detail_v43"


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
	# L'habillage v41 est lui aussi différé : attendre deux frames garantit
	# que PlayerArtV41 existe avant d'ajouter les détails v43.
	await get_tree().process_frame
	await get_tree().process_frame
	_apply(game)


func _apply(game: Node) -> void:
	if not is_instance_valid(game):
		return
	if game.has_meta(META_KEY):
		return

	var rods = game.get("_rods")
	if rods == null:
		return

	var dark = BowlingArt.mat(Color(0.035, 0.04, 0.05), 0.72)
	var light = BowlingArt.mat(Color(0.96, 0.96, 0.92), 0.60)
	var player_count: int = 0

	for r in rods:
		if not is_instance_valid(r.pivot):
			continue
		var facing: float = float(r.dir)

		for man in r.pivot.get_children():
			if not is_instance_valid(man):
				continue
			if man.get_node_or_null("PlayerArtV41") == null:
				continue

			var details := Node3D.new()
			details.name = "PlayerDetailV43"
			man.add_child(details)

			# Ceinture fine entre maillot et short.
			details.add_child(BowlingArt.box(
				Vector3(0.033, 0.005, 0.031),
				dark,
				Vector3(0, -0.041, 0)
			))

			# Semelle sous la chaussure déjà présente en v41.
			details.add_child(BowlingArt.box(
				Vector3(0.041, 0.004, 0.033),
				dark,
				Vector3(0, -0.098, 0)
			))

			# Deux yeux minimalistes placés du côté où regarde la figurine.
			for side_value in [-1.0, 1.0]:
				var side: float = float(side_value)
				var eye = BowlingArt.sphere(
					0.0026,
					dark,
					Vector3(facing * 0.0155, 0.010, side * 0.006),
					6
				)
				eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				details.add_child(eye)

			# Petite bande claire à l'arrière du maillot pour mieux lire l'équipe.
			details.add_child(BowlingArt.box(
				Vector3(0.004, 0.020, 0.024),
				light,
				Vector3(-facing * 0.016, -0.025, 0)
			))

			player_count += 1

	game.set_meta(META_KEY, true)
	game.set_meta("babyfoot_player_detail_v43_count", player_count)
