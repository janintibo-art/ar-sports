extends SceneTree
## v54 : lampe du baby-foot au-dessus du menu, adversaire baby-foot qui anticipe,
## aide à la visée de l'arc, bouche de la grenouille sur le trou des 500 points.

func _init() -> void:
	_run.call_deferred()


func _top_y(n: Node) -> float:
	var top := -1e9
	if n is MeshInstance3D and n.visible and n.mesh != null:
		var bb: AABB = n.global_transform * n.get_aabb()
		top = bb.end.y
	for c in n.get_children():
		top = maxf(top, _top_y(c))
	return top


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ok := true
	# Baby-foot
	main.start_game("babyfoot")
	for i in 5:
		await process_frame
	var bf = main.game
	var lamp_low := 99.0
	for c in bf._table.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh and absf((c.mesh as BoxMesh).size.x - 1.4) < 0.001 and absf((c.mesh as BoxMesh).size.y - 0.1) < 0.001:
			lamp_low = minf(lamp_low, c.global_position.y)
	var panel_top: float = _top_y(bf._panel)
	if lamp_low < panel_top + 0.2:
		print("ECHEC : lampe trop basse ", lamp_low, " menu ", panel_top)
		ok = false
	var lvl: Dictionary = bf.LEVELS["normal"]
	if float(lvl["speed"]) < 1.4 or float(lvl["anticip"]) < 0.5:
		print("ECHEC : adversaire pas assez réactif")
		ok = false
	var rod = null
	for r in bf._rods:
		if r.team == -1 and r.x > 0.2:
			rod = r
			break
	if rod == null:
		print("ECHEC : barre adverse introuvable")
		ok = false
	else:
		bf._ball_pos = Vector2(0.0, 0.0)
		bf._ball_vel = Vector2(1.0, 0.0)
		var y0: float = bf._predict_y(rod)
		bf._ball_vel = Vector2(1.0, 0.3)
		var y1: float = bf._predict_y(rod)
		bf._ball_vel = Vector2(1.0, 1.2)
		var y2: float = bf._predict_y(rod)
		var half: float = bf.W * 0.5
		if absf(y0) > 0.001 or absf(y1) < 0.01 or absf(y2) > half:
			print("ECHEC : prédiction ", y0, " ", y1, " ", y2)
			ok = false
	# Arc
	var tir = load("res://scripts/tir/arc.gd").new()
	if tir.has_method("assisted_dir"):
		tir.settings["level"] = "normal"
		tir.settings["dist"] = 20
		var from := Vector3(0, 1.4, 0)
		var ideal: Vector3 = tir.aim_dir(from, Vector3(0, tir.TARGET_Y, -20.0), 40.0, tir._wind)
		var off := ideal.rotated(Vector3.UP, 0.02)
		var fixed: Vector3 = tir.assisted_dir(from, off, 40.0)
		if fixed.angle_to(ideal) >= off.angle_to(ideal) * 0.7:
			print("ECHEC : l'aide ne rapproche pas du centre")
			ok = false
		var far := ideal.rotated(Vector3.UP, 0.5)
		if tir.assisted_dir(from, far, 40.0).angle_to(far) > 0.0001:
			print("ECHEC : l'aide agit trop loin de la cible")
			ok = false
	else:
		print("ECHEC : assisted_dir absent")
		ok = false
	tir.free()
	# Grenouille
	main.start_game("grenouille")
	for i in 5:
		await process_frame
	var gr = main.game
	var hz: float = gr.hole_pos(0).z - gr.cz - (-0.25 * gr.K)
	if gr._frog.get_child_count() < 12 or hz < 0.05:
		print("ECHEC : grenouille mal construite ", gr._frog.get_child_count(), " ", hz)
		ok = false
	main.queue_free()
	await process_frame
	if ok:
		print("SELFTEST v54=OK")
	quit()
