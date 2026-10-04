extends SceneTree
## Vérifie que les deux profils créent tous les jeux et que le léger réduit les nœuds.
func _init() -> void:
	_run.call_deferred()

func _count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count(child)
	return count

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var original := VisualStyle.detailed
	var counts: Dictionary = {}
	for detailed in [true, false]:
		VisualStyle.set_detailed(detailed, false)
		for id in ["bowling", "flechettes", "pingpong", "petanque", "molkky", "palet", "billard", "babyfoot"]:
			main.start_game(id)
			await process_frame
			await process_frame
			var count := _count(main.game)
			if detailed:
				counts[id] = count
			else:
				assert(count < int(counts[id]), "Le mode léger doit réduire les objets : " + id)
				print("STYLE ", id, " : ", counts[id], " -> ", count)
		main.start_game("tir")
		for id in ["arc", "carabine", "balltrap", "couteau"]:
			main.game.start_discipline(id)
			await process_frame
			await process_frame
			assert(main.game._child != null)
			var count := _count(main.game._child)
			if detailed:
				counts[id] = count
			else:
				assert(count < int(counts[id]), "Profil de tir non réduit : " + id)
				print("STYLE ", id, " : ", counts[id], " -> ", count)
			main.game.show_choice()
	var spectator = load("res://scripts/bowling/spectator.gd").new({"name": "Test"})
	main.add_child(spectator)
	spectator.react("strike")
	for i in 6:
		await process_frame
	assert(spectator._mouth.scale.y > 1.0, "Expression de joie absente")
	assert(spectator._eyes.size() == 2)
	spectator.queue_free()
	VisualStyle.set_detailed(original, false)
	main.queue_free()
	await process_frame
	print("SELFTEST style_v19=OK")
	quit(0)
