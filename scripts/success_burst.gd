class_name SuccessBurst
extends Node3D
## Confettis groupés en un MultiMesh, sans lumière ni collision.
## Un seul effet actif par tableau, pause héritée du jeu, destruction automatique.
var _mesh: MultiMeshInstance3D
var _velocities: Array[Vector3] = []
var _positions: Array[Vector3] = []
var _age := 0.0
var _duration := 1.5
var _count := 0
var _base := Color(1, 0.8, 0.2)
var _wide := 0.7

static func play(parent: Node3D, major: bool, color: Color = Color(1, 0.8, 0.2)) -> SuccessBurst:
	var previous := parent.get_node_or_null("SuccessBurst")
	if previous:
		parent.remove_child(previous)
		previous.queue_free()
	var effect := SuccessBurst.new()
	effect.name = "SuccessBurst"
	effect._count = (40 if major else 16) if VisualStyle.detailed else (12 if major else 6)
	effect._duration = 1.7 if major else 0.8
	effect._base = color
	effect.position.z = 0.055
	parent.add_child(effect)
	return effect

func _ready() -> void:
	_mesh = MultiMeshInstance3D.new()
	var shard := BoxMesh.new()
	shard.size = Vector3(0.018, 0.035, 0.004)
	var material := BowlingArt.unshaded(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	shard.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = shard
	mm.instance_count = _count
	_mesh.multimesh = mm
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var rng := RandomNumberGenerator.new()
	rng.seed = 200
	for i in _count:
		var side := -1.0 if i % 2 == 0 else 1.0
		_positions.append(Vector3(side * _wide, -0.24, 0))
		_velocities.append(Vector3(side * rng.randf_range(0.05, 0.35), rng.randf_range(0.45, 0.95), rng.randf_range(0.01, 0.12)))
		mm.set_instance_color(i, _base if i % 3 == 0 else Color.from_hsv(float(i % 7) / 7.0, 0.65, 1.0))
		mm.set_instance_transform(i, Transform3D(Basis(), _positions[i]))

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	# Trajectoire analytique, indépendante de la fréquence d'affichage.
	var shrink := clampf((_duration - _age) / 0.25, 0, 1)
	for i in _count:
		var pos := _positions[i] + _velocities[i] * _age + Vector3(0, -0.5 * _age * _age, 0)
		var spin := Basis.from_euler(Vector3(_age * 3 + i, _age * 4, _age * 2 + i * 0.4)).scaled(Vector3.ONE * shrink)
		_mesh.multimesh.set_instance_transform(i, Transform3D(spin, pos))
