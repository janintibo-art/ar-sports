extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _run() -> void:
	for i in range(16):
		var a := BillBall.texture_of(i)
		var b := BillBall.texture_of(i)
		assert(a == b)
		var img := a.get_image()
		assert(img.get_width() == 128)
		assert(img.get_height() == 128)
		assert(img.has_mipmaps())

	assert(BillBall.group_of(0) == "")
	assert(BillBall.group_of(1) == "solid")
	assert(BillBall.group_of(7) == "solid")
	assert(BillBall.group_of(8) == "eight")
	assert(BillBall.group_of(9) == "stripe")
	assert(BillBall.group_of(15) == "stripe")

	var solid := BillBall.texture_of(1).get_image()
	var stripe := BillBall.texture_of(9).get_image()
	var solid_edge := solid.get_pixel(64, 10)
	var stripe_edge := stripe.get_pixel(64, 10)
	var stripe_mid := stripe.get_pixel(64, 64)
	var white := Color(0.965, 0.96, 0.92)
	var yellow := BillBall.color_of(9)

	# Sur une rayée, le bord doit être plus proche du blanc et le centre plus
	# proche de la couleur de la bille. On compare la couleur complète plutôt
	# qu'un seul canal (le rouge du jaune peut être supérieur à celui du blanc).
	assert(_color_distance(stripe_edge, white) < _color_distance(stripe_edge, yellow))
	assert(_color_distance(stripe_mid, yellow) < _color_distance(stripe_mid, white))
	assert(solid_edge.b < 0.5)

	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game("billard")
	await process_frame
	var game = main.game
	assert(game.R == 0.0285)
	assert(game._balls.size() in [10, 16])
	for ball in game._balls:
		assert(ball.node.mesh.radius == game.R)
		assert(ball.node.material_override.albedo_texture == BillBall.texture_of(ball.id))

	main.queue_free()
	await process_frame
	print("SELFTEST billard_art_v29=OK")
	quit()
