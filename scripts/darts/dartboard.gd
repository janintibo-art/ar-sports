class_name Dartboard
extends Node3D
## Cible réglementaire (dimensions réelles en mètres) construite en code, avec
## boîtier de bois, fils métalliques et numéros. Le plan de la cible est z = 0,
## face vers +Z (vers le joueur). `face_scale` agrandit tout pour jouer plus facile.

const NUMBERS := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const R_BULL := 0.00635
const R_OUTER_BULL := 0.0159
const R_TRIPLE_IN := 0.099
const R_TRIPLE_OUT := 0.107
const R_DOUBLE_IN := 0.162
const R_DOUBLE_OUT := 0.170
const R_FACE := 0.225
const R_SURROUND := 0.34

const BLACK := Color(0.06, 0.06, 0.07)
const CREAM := Color(0.94, 0.88, 0.7)
const RED := Color(0.82, 0.1, 0.1)
const GREEN := Color(0.05, 0.5, 0.22)
const WIRE := Color(0.78, 0.8, 0.84)

var face_scale := 1.0:
	set(value):
		face_scale = value
		if _content:
			_content.scale = Vector3.ONE * value

var _content: Node3D


func _ready() -> void:
	_content = Node3D.new()
	_content.scale = Vector3.ONE * face_scale
	add_child(_content)

	# Boîtier de bois derrière la cible
	var wood := BowlingArt.mat(Color(0.22, 0.12, 0.07), 0.5)
	var cab := BowlingArt.cylinder(R_SURROUND, R_SURROUND, 0.07, wood, Vector3(0, 0, -0.04), 40)
	cab.rotation_degrees = Vector3(90, 0, 0)
	_content.add_child(cab)
	var rim := BowlingArt.cylinder(R_SURROUND + 0.006, R_SURROUND + 0.006, 0.012, BowlingArt.mat(Color(0.6, 0.45, 0.2), 0.3, 0.6), Vector3(0, 0, -0.0125), 40)
	rim.rotation_degrees = Vector3(90, 0, 0)
	_content.add_child(rim)

	var mi := MeshInstance3D.new()
	mi.mesh = _build_face()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_content.add_child(mi)

	# Numéros
	var font := BowlingArt.bold_font()
	for i in 20:
		var a := deg_to_rad(i * 18.0)
		var l := BowlingArt.label(str(NUMBERS[i]), 0.036, Color(0.97, 0.97, 0.95), 8)
		l.font = font
		l.position = Vector3(sin(a) * 0.1975, cos(a) * 0.1975, 0.0015)
		l.double_sided = false
		_content.add_child(l)


# ---------------------------------------------------------------- géométrie

func _build_face() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring(st, 0.0, R_SURROUND, 0.0, 360.0, Color(0.1, 0.1, 0.11), -0.003, 24)
	_ring(st, R_DOUBLE_OUT, R_FACE, 0.0, 360.0, BLACK, 0.0, 120)
	for i in 20:
		var a0 := i * 18.0 - 9.0
		var a1 := a0 + 18.0
		var dark_seg := i % 2 == 0
		var base := BLACK if dark_seg else CREAM
		var mult := RED if dark_seg else GREEN
		_ring(st, R_OUTER_BULL, R_TRIPLE_IN, a0, a1, base, 0.0)
		_ring(st, R_TRIPLE_IN, R_TRIPLE_OUT, a0, a1, mult, 0.0)
		_ring(st, R_TRIPLE_OUT, R_DOUBLE_IN, a0, a1, base, 0.0)
		_ring(st, R_DOUBLE_IN, R_DOUBLE_OUT, a0, a1, mult, 0.0)
	_ring(st, R_BULL, R_OUTER_BULL, 0.0, 360.0, GREEN, 0.0, 48)
	_ring(st, 0.0, R_BULL, 0.0, 360.0, RED, 0.0, 32)
	# Fils métalliques
	var w := 0.0016
	for r in [R_BULL, R_OUTER_BULL, R_TRIPLE_IN, R_TRIPLE_OUT, R_DOUBLE_IN, R_DOUBLE_OUT]:
		_ring(st, r - w / 2.0, r + w / 2.0, 0.0, 360.0, WIRE, 0.0006, 120)
	for i in 20:
		var a := deg_to_rad(i * 18.0 - 9.0)
		var dir := Vector2(sin(a), cos(a))
		var side := Vector2(dir.y, -dir.x) * (w / 2.0)
		var p0 := dir * R_OUTER_BULL
		var p1 := dir * R_DOUBLE_OUT
		_quad(st, p0 - side, p0 + side, p1 + side, p1 - side, WIRE, 0.0006)
	return st.commit()


## Secteur d'anneau entre r0 et r1, de l'angle a0 à a1 (degrés, sens horaire depuis le haut).
static func _ring(st: SurfaceTool, r0: float, r1: float, a0: float, a1: float, color: Color, z: float, steps: int = 6) -> void:
	for s in steps:
		var t0 := deg_to_rad(lerpf(a0, a1, float(s) / steps))
		var t1 := deg_to_rad(lerpf(a0, a1, float(s + 1) / steps))
		var p00 := Vector2(sin(t0), cos(t0)) * r0
		var p10 := Vector2(sin(t0), cos(t0)) * r1
		var p11 := Vector2(sin(t1), cos(t1)) * r1
		var p01 := Vector2(sin(t1), cos(t1)) * r0
		_quad(st, p00, p01, p11, p10, color, z)


static func _quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, z: float) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(color)
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(p.x, p.y, z))


# ---------------------------------------------------------------- points

## Score d'un impact. `xy` : position sur la cible en mètres réels (x vers la droite, y vers le haut).
static func score_at(xy: Vector2) -> Dictionary:
	var r := xy.length()
	if r <= R_BULL:
		return {"value": 50, "mult": 2, "number": 25, "label": "BULL", "bull": true}
	if r <= R_OUTER_BULL:
		return {"value": 25, "mult": 1, "number": 25, "label": "25", "bull": true}
	if r > R_DOUBLE_OUT:
		return {"value": 0, "mult": 0, "number": 0, "label": "RATÉ", "bull": false}
	var deg := rad_to_deg(atan2(xy.x, xy.y))
	var idx := int(floorf(fposmod(deg + 9.0, 360.0) / 18.0)) % 20
	var number: int = NUMBERS[idx]
	var mult := 1
	if r > R_TRIPLE_IN and r <= R_TRIPLE_OUT:
		mult = 3
	elif r > R_DOUBLE_IN:
		mult = 2
	var prefix := "" if mult == 1 else ("D" if mult == 2 else "T")
	return {"value": number * mult, "mult": mult, "number": number, "label": "%s%d" % [prefix, number], "bull": false}


## Centre d'un secteur (mètres réels) : sert à viser dans l'auto-test.
static func segment_center(number: int, mult: int) -> Vector2:
	if number == 25:
		return Vector2.ZERO if mult == 2 else Vector2(0, (R_BULL + R_OUTER_BULL) / 2.0)
	var idx: int = NUMBERS.find(number)
	var a := deg_to_rad(idx * 18.0)
	var r := 0.07
	if mult == 3:
		r = (R_TRIPLE_IN + R_TRIPLE_OUT) / 2.0
	elif mult == 2:
		r = (R_DOUBLE_IN + R_DOUBLE_OUT) / 2.0
	return Vector2(sin(a), cos(a)) * r
