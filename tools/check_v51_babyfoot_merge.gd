extends SceneTree
## v51 : le baby-foot fusionne ses maillages statiques (moins d'appels de rendu).
## Vérifie : moins de maillages, mêmes triangles, même encombrement, tiges qui tournent/glissent toujours.

func _init() -> void:
	_run.call_deferred()


func _stats(n: Node, acc: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh and n.is_visible_in_tree():
		acc["mesh"] += 1
		acc["tri"] += n.mesh.get_faces().size() / 3
		acc["box"] = acc["box"].merge(n.global_transform * n.mesh.get_aabb())
	for c in n.get_children():
		_stats(c, acc)


func _snapshot(g: Node) -> Dictionary:
	var acc := {"mesh": 0, "tri": 0, "box": AABB(Vector3.ZERO, Vector3.ZERO)}
	_stats(g, acc)
	return acc


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("babyfoot")
	for i in 11:
		await process_frame
	var g = main.game
	var before := _snapshot(g)
	for i in 30:
		await process_frame
	var after := _snapshot(g)
	print("avant ", before, " après ", after)
	var ok := true
	if not g.has_meta("babyfoot_merge_v51"):
		print("ECHEC : méta de fusion absente")
		ok = false
	if after["mesh"] >= before["mesh"] / 2:
		print("ECHEC : pas assez de maillages supprimés")
		ok = false
	if absi(after["tri"] - before["tri"]) > 0:
		print("ECHEC : triangles différents")
		ok = false
	var b0: AABB = before["box"]
	var b1: AABB = after["box"]
	if b0.position.distance_to(b1.position) > 0.01 or b0.size.distance_to(b1.size) > 0.01:
		print("ECHEC : encombrement modifié")
		ok = false
	# les tiges portent toujours leur maillage fusionné et le font tourner avec le pivot
	var rods: Array = g.get("_rods")
	var tested := 0
	for r in rods:
		var fusion: Node = r.pivot.get_node_or_null("FusionJoueurs")
		if fusion == null:
			continue
		tested += 1
		var a0: AABB = (fusion as MeshInstance3D).global_transform * (fusion as MeshInstance3D).mesh.get_aabb()
		r.pivot.rotation.x = 0.8
		var a1: AABB = (fusion as MeshInstance3D).global_transform * (fusion as MeshInstance3D).mesh.get_aabb()
		r.pivot.rotation.x = 0.0
		if a0.size.distance_to(a1.size) < 0.001 and a0.position.distance_to(a1.position) < 0.001:
			print("ECHEC : la rotation ne déplace pas le maillage fusionné")
			ok = false
			break
	if tested < 4:
		print("ECHEC : trop peu de tiges fusionnées : ", tested)
		ok = false
	main.queue_free()
	await process_frame
	if ok:
		print("SELFTEST babyfoot_merge_v51=OK")
	quit()
