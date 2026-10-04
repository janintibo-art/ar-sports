extends Node
## v51 : regroupe les maillages fixes du baby-foot (figurines, barres, table) pour réduire les
## appels de dessin (de ~600 à ~150). Attend que les habillages v37 à v45 soient en place.
## Purement visuel : la physique et les barres (pivot) ne changent pas.

const META_KEY := "babyfoot_merge_v51"
const WAIT_FRAMES := 12


func _ready() -> void:
	if "--selftest" in OS.get_cmdline_user_args():
		return
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	if script == null:
		return
	if script.resource_path == "res://scripts/babyfoot.gd":
		_later.call_deferred(node.get_instance_id())


func _later(id: int) -> void:
	for i in WAIT_FRAMES:
		await get_tree().process_frame
	var game = instance_from_id(id)
	if game == null or not is_instance_valid(game):
		return
	merge(game)


func merge(game: Node) -> int:
	if game.has_meta(META_KEY):
		return 0
	var removed := 0
	var rods = game.get("_rods")
	if rods != null:
		for r in rods:
			if is_instance_valid(r.pivot):
				removed += MeshMerge.merge_static(r.pivot, null, "FusionJoueurs")
			if is_instance_valid(r.node):
				removed += MeshMerge.merge_static(r.node, r.pivot, "FusionBarre")
	var table = game.get("_table")
	if is_instance_valid(table):
		removed += MeshMerge.merge_static(table, null, "FusionTable")
	game.set_meta(META_KEY, true)
	game.set_meta("babyfoot_merge_v51_removed", removed)
	return removed
