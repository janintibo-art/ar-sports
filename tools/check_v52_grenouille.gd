extends SceneTree
## v52 : le jeu de la grenouille est branché partout (menu à 10 cartes sans chevauchement,
## sélecteur de jeux, aide, guide rapide, icône) et le plateau correspond aux règles.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ok := true
	var ids: Array = []
	for g in main.menu.GAMES:
		ids.append(g["id"])
	if not ("grenouille" in ids) or not main.GAMES.has("grenouille"):
		print("ECHEC : jeu absent du menu ou de main")
		ok = false
	if not main.menu.HELP.has("grenouille"):
		print("ECHEC : aide du menu absente")
		ok = false
	var guide_ok := false
	for p in load("res://scripts/quick_guide.gd").PAGES:
		if p["title"] == "Grenouille":
			guide_ok = true
	if not guide_ok:
		print("ECHEC : page du guide absente")
		ok = false
	if load("res://scripts/game_icons.gd").build("grenouille").get_child_count() < 5:
		print("ECHEC : icône absente")
		ok = false
	# Les cartes ne se chevauchent pas et restent au-dessus de la rangée Décor/Confort/Quitter
	main.menu.skip_intro()
	var rects: Array = []
	var quit_top := 9.0
	for panel in main.menu._panels:
		var game: Dictionary = panel.get_meta("game")
		var size := Vector2(0.25, 0.22) if game["id"] in ids else Vector2(0.27, 0.09)
		var pos := Vector2(panel.position.x, panel.position.y)
		var r := Rect2(pos - size / 2.0, size)
		if game["id"] in ids:
			rects.append(r)
		else:
			quit_top = minf(quit_top, r.end.y)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				print("ECHEC : cartes qui se chevauchent ", i, " ", j)
				ok = false
		if (rects[i] as Rect2).position.y < quit_top - 0.001:
			print("ECHEC : carte trop basse ", i)
			ok = false
	# Le sélecteur de jeux présente les dix jeux
	main.start_game("bowling")
	await process_frame
	main.open_switcher()
	var found := 0
	for b in main._switcher._buttons:
		if String(b.get_meta("ui_id", "")).begins_with("game_"):
			found += 1
	if found != ids.size():
		print("ECHEC : sélecteur ", found, " jeux sur ", ids.size())
		ok = false
	main.close_switcher()
	# Le jeu démarre, avec 8 trous et le 500 dans la bouche
	main.start_game("grenouille")
	await process_frame
	var game = main.game
	if game.get_script().resource_path != "res://scripts/grenouille.gd" or game.HOLES.size() != 8 or game.hole_points(0) != 500:
		print("ECHEC : jeu mal construit")
		ok = false
	main.queue_free()
	await process_frame
	if ok:
		print("SELFTEST grenouille_v52=OK")
	quit()
