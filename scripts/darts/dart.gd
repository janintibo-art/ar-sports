class_name Dart
extends Node3D
## Une fléchette : pointe vers -Z, modèle bâti en code (pointe, fût, tige, ailette).
## Pas de moteur physique : le jeu la fait voler (gravité simple) et la plante.

enum State { HOLDER, HELD, FLYING, STUCK, FALLEN }

const SCALE := 1.5
const TIP_Y := 0.078

var state := State.HOLDER
var velocity := Vector3.ZERO
var slot := Transform3D()          # place dans le porte-fléchettes (repère du jeu)
var tip_local := Vector3(0, 0, -TIP_Y * SCALE)
var flight_color := Color(0.9, 0.2, 0.2):
	set(value):
		flight_color = value
		_apply_color()

var _model: Node3D
var _flights: Array[MeshInstance3D] = []
var _shaft: MeshInstance3D
var _wobble := 0.0
var _wobble_time := 0.0
var _stick_tip := Vector3.ZERO
var _stick_basis := Basis()
var _wobble_axis := Vector3.RIGHT


func _ready() -> void:
	_model = Node3D.new()
	_model.rotation_degrees = Vector3(-90, 0, 0)   # l'axe +Y du modèle devient -Z
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_model.add_child(DartArt.body(VisualStyle.detailed))
	_shaft = BowlingArt.cylinder(0.0026, 0.0026, 0.036, BowlingArt.mat(flight_color, 0.5), Vector3(0, -0.016, 0), 8)
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_shaft)
	for k in 2:
		var f := MeshInstance3D.new()
		f.mesh = DartArt.wing_mesh()
		f.material_override = BowlingArt.mat(flight_color, 0.6)
		f.rotation_degrees = Vector3(0, 90.0 * k, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_model.add_child(f)
		_flights.append(f)
	_apply_color()


func _apply_color() -> void:
	if _shaft == null:
		return
	(_shaft.material_override as StandardMaterial3D).albedo_color = flight_color
	for f in _flights:
		(f.material_override as StandardMaterial3D).albedo_color = flight_color


func tip_global() -> Vector3:
	return global_transform * tip_local


## Pose la fléchette pour que sa pointe soit en `tip` avec l'orientation `b`.
func place_tip(tip: Vector3, b: Basis) -> void:
	global_basis = b
	global_position = tip - b * tip_local


## Plante la fléchette (pointe en `tip`), avec une petite vibration.
func stick(tip: Vector3, b: Basis, strength: float = 1.0) -> void:
	state = State.STUCK
	_stick_tip = tip
	_stick_basis = b
	_wobble_time = 0.0
	_wobble = 0.1 * strength
	_wobble_axis = (b * Vector3.RIGHT).rotated(b * Vector3.FORWARD, randf() * TAU)
	place_tip(tip, b)


func _process(delta: float) -> void:
	if state == State.STUCK and _wobble > 0.001:
		_wobble_time += delta
		var amp := _wobble * exp(-_wobble_time * 7.0) * sin(_wobble_time * 55.0)
		if _wobble_time > 0.9:
			_wobble = 0.0
			amp = 0.0
		place_tip(_stick_tip, Basis(_wobble_axis, amp) * _stick_basis)


func distance_to(point: Vector3) -> float:
	return (global_position - point).length()
