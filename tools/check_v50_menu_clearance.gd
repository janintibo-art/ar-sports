extends SceneTree
## Les menus des jeux à table (ping-pong, baby-foot, billard) ne doivent pas entrer dans la table,
## quelle que soit la hauteur de tête (debout, assis) et la taille de menu choisie.

func _init() -> void:
	_run.call_deferred()


func _meshes(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and n.mesh and n.is_visible_in_tree():
		acc.append(n.global_transform * n.mesh.get_aabb())
	for c in n.get_children():
		_meshes(c, acc)


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var bad := 0
	var cases := 0
	for gid in ["pingpong", "babyfoot", "billard"]:
		main.start_game(gid)
		await process_frame
		var game = main.game
		if "--sans-correctif" in OS.get_cmdline_user_args():
			game.get("_panel").set("floor_clearance", 0.0)
		for head_y in [1.7, 1.5, 1.3, 1.1]:
			for sc in [1.0, 1.3]:
				VisualStyle.ui_scale = sc
				main.camera.global_position = Vector3(0, head_y, 0)
				main.camera.global_rotation = Vector3.ZERO
				game.place_in_front_of(Transform3D(Basis(), Vector3(0, head_y, 0)))
				for page in ["setup", "pause", "over"]:
					match page:
						"setup":
							game.show_setup()
						"pause":
							game.show_pause()
						_:
							game.show_game_over("Vous 11 - 7 Ordi")
					await process_frame
					var panel: Node3D = game.get("_panel")
					var h: float = panel.get("_height")
					var half: float = h * 0.5 * sc
					var box := AABB(Vector3(-0.45, panel.global_position.y - half, panel.global_position.z - 0.03), Vector3(0.9, half * 2.0, 0.06))
					var table: Node = game.get("_table")
					var acc: Array = []
					_meshes(table, acc)
					var hit := false
					for a in acc:
						# seuls les éléments de la table elle-même (pas le décor haut ni les suspensions)
						if a.position.y < 1.3 and a.intersects(box):
							hit = true
							break
					cases += 1
					if hit:
						bad += 1
						print("MENU DANS LA TABLE : ", gid, " tête ", head_y, " échelle ", sc, " page ", page, " bas ", box.position.y)
		main.start_game("tir")
		await process_frame
	VisualStyle.ui_scale = 1.0
	print("cas testés : ", cases, ", conflits : ", bad)
	main.queue_free()
	await process_frame
	if bad == 0:
		print("SELFTEST menu_clearance_v50=OK")
	quit()
