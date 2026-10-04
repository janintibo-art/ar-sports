extends Node
## Finition visuelle v49 du terrain de pétanque.
## Le module ne modifie aucune limite, collision ou règle. Il vérifie simplement
## que son décor existe sur le terrain actif et le recrée si `_build_terrain()`
## reconstruit la scène lors d'un changement Normal/Court.

var _game_id: int = 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null:
		return
	if script.resource_path == "res://scripts/petanque.gd":
		_game_id = node.get_instance_id()


func _process(_delta: float) -> void:
	if _game_id == 0:
		return
	var game = instance_from_id(_game_id)
	if not is_instance_valid(game):
		_game_id = 0
		return

	var terrain = game.get("_terrain")
	if not is_instance_valid(terrain):
		return

	var existing = terrain.get_node_or_null("TerrainArtV49")
	if is_instance_valid(existing) and not existing.is_queued_for_deletion():
		return

	_add_art(game, terrain)


func _add_art(game, terrain: Node3D) -> void:
	var tw: float = float(game.get("tw"))
	var tlen: float = float(game.get("tlen"))
	var jack_min: float = float(game.get("jack_min"))
	var jack_max: float = float(game.get("jack_max"))

	var art := Node3D.new()
	art.name = "TerrainArtV49"
	terrain.add_child(art)

	var wood_dark = BowlingArt.mat(Color(0.26, 0.16, 0.085), 0.78)
	var brass = BowlingArt.mat(Color(0.68, 0.49, 0.18), 0.32, 0.54)
	var white = BowlingArt.unshaded(Color(1.0, 0.97, 0.90, 0.88))
	var pale = BowlingArt.unshaded(Color(0.96, 0.82, 0.48, 0.50))
	var gravel_dark = BowlingArt.mat(Color(0.44, 0.38, 0.28), 0.94)

	# Renforts sombres sous les quatre bordures existantes.
	var zc: float = (0.6 - tlen) / 2.0
	var length: float = tlen + 0.6
	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		art.add_child(BowlingArt.box(
			Vector3(0.018, 0.035, length + 0.04),
			wood_dark,
			Vector3(sx * (tw / 2.0 + 0.054), 0.020, zc)
		))
	art.add_child(BowlingArt.box(
		Vector3(tw + 0.14, 0.035, 0.018),
		wood_dark,
		Vector3(0, 0.020, -tlen - 0.054)
	))
	art.add_child(BowlingArt.box(
		Vector3(tw + 0.14, 0.035, 0.018),
		wood_dark,
		Vector3(0, 0.020, 0.654)
	))

	# Petits renforts métalliques aux quatre coins.
	for sx_value in [-1.0, 1.0]:
		var sx: float = float(sx_value)
		for back_z in [-tlen - 0.052, 0.652]:
			var cap = BowlingArt.cylinder(
				0.030, 0.030, 0.012, brass,
				Vector3(sx * (tw / 2.0 + 0.053), 0.072, float(back_z)),
				12
			)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			art.add_child(cap)

	# Ligne de départ discrète derrière le cercle de lancer.
	art.add_child(BowlingArt.box(
		Vector3(tw * 0.72, 0.002, 0.018),
		white,
		Vector3(0, 0.006, 0.32)
	))

	# Repères centraux aux distances mini/maxi du cochonnet.
	for d_value in [jack_min, jack_max]:
		var d: float = float(d_value)
		var marker = BowlingArt.cylinder(
			0.022, 0.022, 0.002,
			pale, Vector3(0, 0.006, -d), 14
		)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.add_child(marker)

	# Quelques petites plaques "usées" sur le gravier, volontairement plates.
	var spots := [
		Vector3(-0.42, 0.0035, -2.1),
		Vector3(0.55, 0.0035, -3.7),
		Vector3(-0.30, 0.0035, -5.4),
		Vector3(0.38, 0.0035, -7.2),
	]
	for p in spots:
		if absf(p.z) < tlen - 0.4 and absf(p.x) < tw / 2.0 - 0.2:
			var spot = BowlingArt.cylinder(
				0.085, 0.070, 0.0015,
				gravel_dark, p, 12
			)
			spot.scale.z = 0.62
			spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			art.add_child(spot)

	art.set_meta("petanque_terrain_v49", true)
	art.set_meta("petanque_terrain_v49_tw", tw)
	art.set_meta("petanque_terrain_v49_tlen", tlen)
