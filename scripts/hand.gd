class_name Hand
extends XRController3D
## Une main (manette) : position suivie, rayon laser pour viser les menus,
## mémoire des positions récentes pour calculer la vitesse d'un lancer.

const LASER_LENGTH := 3.0
const HISTORY_SECONDS := 0.12

var laser_enabled := true:
	set(value):
		laser_enabled = value
		if is_inside_tree():
			_laser.visible = value
			_ray.enabled = value
			_dot.visible = false

var _laser: MeshInstance3D
var _dot: MeshInstance3D
var _ray: RayCast3D
var _history: Array[Dictionary] = []
var _clock := 0.0


func _init(hand_tracker: StringName) -> void:
	tracker = hand_tracker
	pose = &"aim"
	name = "MainGauche" if hand_tracker == &"left_hand" else "MainDroite"


func _ready() -> void:
	# Petite poignée visible à la place de la manette.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.022
	capsule.height = 0.11
	body.mesh = capsule
	body.rotation_degrees = Vector3(90, 0, 0)
	body.position = Vector3(0, -0.01, 0.05)
	body.material_override = _flat_material(Color(0.85, 0.85, 0.9))
	add_child(body)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -LASER_LENGTH)
	_ray.collision_mask = 2
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	add_child(_ray)

	_laser = MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.003, 0.003, LASER_LENGTH)
	_laser.mesh = beam
	_laser.position = Vector3(0, 0, -LASER_LENGTH / 2.0)
	_laser.material_override = _flat_material(Color(0.3, 0.8, 1.0, 0.6))
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser)

	_dot = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	_dot.mesh = sphere
	_dot.material_override = _flat_material(Color(1, 1, 1))
	_dot.visible = false
	_dot.top_level = true
	add_child(_dot)

	laser_enabled = laser_enabled


func _physics_process(delta: float) -> void:
	_clock += delta
	var now := _clock
	_history.append({"t": now, "p": global_position})
	while _history.size() > 2 and now - float(_history[0]["t"]) > HISTORY_SECONDS:
		_history.pop_front()

	if laser_enabled:
		_ray.force_raycast_update()
		if _ray.is_colliding():
			_dot.visible = true
			_dot.global_position = _ray.get_collision_point()
		else:
			_dot.visible = false


## Objet d'interface visé par le laser (ou null).
func pointed_object() -> Object:
	if laser_enabled and _ray.is_colliding():
		return _ray.get_collider()
	return null


## Vitesse moyenne de la main sur les dernières ~0,1 s.
func throw_velocity() -> Vector3:
	if _history.size() < 2:
		return Vector3.ZERO
	var first: Dictionary = _history[0]
	var last: Dictionary = _history[_history.size() - 1]
	var dt := float(last["t"]) - float(first["t"])
	if dt <= 0.0001:
		return Vector3.ZERO
	return (Vector3(last["p"]) - Vector3(first["p"])) / dt * VisualStyle.throw_gain


func clear_history() -> void:
	_history.clear()


func buzz(amplitude: float = 0.5, duration: float = 0.08) -> void:
	trigger_haptic_pulse(&"haptic", 0.0, amplitude, duration, 0.0)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
