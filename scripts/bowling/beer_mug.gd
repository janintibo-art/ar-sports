class_name BeerMug
extends Node3D
## Chope de bière : on la prend avec la poignée de la manette, on la porte à la
## bouche en l'inclinant et elle se vide (glouglou). Reposée vide, elle se remplit.

signal emptied(mug: BeerMug)

enum State { ON_TABLE, HELD, RETURNING }

const HEIGHT := 0.14
const RADIUS := 0.042
const LIQ_H := 0.112
const DRINK_SECONDS := 5.0

var state := State.ON_TABLE
var level := 1.0
var decorative := false         # chope tenue par un personnage : pas de logique
var local_slot := Transform3D() # place sur la table (le parent de la chope est la table)
var hand: Node3D = null

var _liquid: MeshInstance3D
var _foam: MeshInstance3D
var _blob: MeshInstance3D
var _glug: AudioStreamPlayer3D
var _return_t := 0.0
var _return_from := Transform3D()
var _refill_timer := -1.0
var _was_drinking := false


func _ready() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.6
	var beer := BowlingArt.mat(Color(0.95, 0.62, 0.12, 0.92), 0.2)
	beer.emission_enabled = true
	beer.emission = Color(0.6, 0.3, 0.02)
	beer.emission_energy_multiplier = 0.35
	var foam_mat := BowlingArt.mat(Color(0.98, 0.96, 0.9), 0.9)

	_liquid = BowlingArt.cylinder(RADIUS - 0.006, RADIUS - 0.006, LIQ_H, beer, Vector3(0, 0.012 + LIQ_H / 2.0, 0), 16)
	add_child(_liquid)
	_foam = BowlingArt.cylinder(RADIUS - 0.004, RADIUS - 0.005, 0.022, foam_mat, Vector3.ZERO, 16)
	add_child(_foam)
	var bottom := BowlingArt.cylinder(RADIUS, RADIUS, 0.012, glass, Vector3(0, 0.006, 0), 16)
	add_child(bottom)
	var wall := BowlingArt.cylinder(RADIUS, RADIUS * 0.94, HEIGHT, glass, Vector3(0, HEIGHT / 2.0, 0), 20)
	wall.sorting_offset = 0.1
	add_child(wall)
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.026
	torus.outer_radius = 0.036
	torus.rings = 12
	torus.ring_segments = 8
	handle.mesh = torus
	handle.material_override = glass
	handle.rotation_degrees = Vector3(90, 0, 0)
	handle.scale = Vector3(1.0, 1.0, 1.25)
	handle.position = Vector3(RADIUS + 0.012, HEIGHT * 0.52, 0)
	add_child(handle)

	if not decorative:
		_blob = BowlingArt.make_blob(0.13)
		add_child(_blob)
		_glug = Sound.make_loop_player("glug_loop", self, -2.0)
	_update_liquid()


func grab(by_hand: Node3D) -> void:
	hand = by_hand
	state = State.HELD
	_refill_timer = -1.0
	Sound.play_at("grab", global_position, -6.0)


func release() -> void:
	hand = null
	state = State.RETURNING
	_return_t = 0.0
	_return_from = global_transform
	_stop_glug()


func distance_to_hand(h: Node3D) -> float:
	return (global_position + global_basis.y * HEIGHT * 0.5).distance_to(h.global_position)


func _process(delta: float) -> void:
	if decorative:
		return
	match state:
		State.HELD:
			if hand:
				var side := -1.0 if String(hand.name).ends_with("Droite") else 1.0
				var offset := Transform3D(Basis.from_euler(Vector3(0, PI if side < 0 else 0.0, 0)), Vector3(0, -0.085, 0.035))
				global_transform = hand.global_transform * offset
				_check_drinking(delta)
		State.RETURNING:
			_return_t = minf(1.0, _return_t + delta / 0.45)
			var k := _return_t * _return_t * (3.0 - 2.0 * _return_t)
			var slot := _slot_global()
			var tr := _return_from.interpolate_with(slot, k)
			tr.origin.y += sin(PI * _return_t) * 0.08
			global_transform = tr
			if _return_t >= 1.0:
				state = State.ON_TABLE
				transform = local_slot
				Sound.play_at("clink", global_position, -14.0)
				if level <= 0.01:
					_refill_timer = 2.0
		State.ON_TABLE:
			transform = local_slot
			if _refill_timer >= 0.0:
				_refill_timer -= delta
				if _refill_timer < 0.0:
					Sound.play_at("pour", global_position, -4.0)
					var tw := create_tween()
					tw.tween_method(_set_level, 0.0, 1.0, 1.5)
	if _blob:
		_blob.visible = state == State.ON_TABLE
		_blob.global_position = global_position + Vector3(0, 0.002, 0)


func _check_drinking(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var up := global_basis.y.normalized()
	var top := global_position + up * HEIGHT
	var mouth := cam.global_position - cam.global_basis.y * 0.08 - cam.global_basis.z * 0.03
	var tilt := rad_to_deg(up.angle_to(Vector3.UP))
	var drinking := level > 0.0 and top.distance_to(mouth) < 0.2 and tilt > 18.0
	if drinking:
		level = maxf(0.0, level - delta / DRINK_SECONDS)
		_update_liquid()
		if not _glug.playing:
			_glug.play()
		if level <= 0.0:
			_stop_glug()
			emptied.emit(self)
	elif _was_drinking:
		_stop_glug()
	_was_drinking = drinking


func _slot_global() -> Transform3D:
	var p := get_parent() as Node3D
	return p.global_transform * local_slot if p else local_slot


func _set_level(v: float) -> void:
	level = v
	_update_liquid()


func _stop_glug() -> void:
	if _glug and _glug.playing:
		_glug.stop()


func _update_liquid() -> void:
	if _liquid == null:
		return
	var h := maxf(level, 0.001) * LIQ_H
	_liquid.visible = level > 0.005
	_liquid.scale = Vector3(1, maxf(level, 0.001), 1)
	_liquid.position.y = 0.012 + h / 2.0
	_foam.visible = level > 0.03
	_foam.position.y = 0.012 + h + 0.008
