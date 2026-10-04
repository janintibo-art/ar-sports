class_name Marquee
extends MultiMeshInstance3D
## Rangée d'ampoules façon fête foraine (une seule passe de rendu pour toutes).
## Modes : « chase » (chenillard doré), « rainbow » (arc-en-ciel rapide),
## « flash » (tout clignote), « calm » (lueur douce).

var mode := "chase"
var speed := 1.0
var base_color := Color(1.0, 0.78, 0.3)
var _t := 0.0
var _boost_time := 0.0
var _boost_mode := ""
var _count := 0


## points : positions locales des ampoules ; radius : taille d'une ampoule.
func setup(points: Array, radius: float = 0.018) -> void:
	_count = points.size()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	sphere.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = _count
	for i in _count:
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
		mm.set_instance_color(i, base_color)
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Ampoules réparties le long d'un rectangle (cadre d'enseigne ou de tableau).
static func rectangle_points(w: float, h: float, spacing: float, z: float = 0.0) -> Array:
	var pts: Array = []
	var nx := maxi(2, int(w / spacing))
	var ny := maxi(2, int(h / spacing))
	for i in nx:
		pts.append(Vector3(-w / 2.0 + w * i / nx, h / 2.0, z))
	for i in ny:
		pts.append(Vector3(w / 2.0, h / 2.0 - h * i / ny, z))
	for i in nx:
		pts.append(Vector3(w / 2.0 - w * i / nx, -h / 2.0, z))
	for i in ny:
		pts.append(Vector3(-w / 2.0, -h / 2.0 + h * i / ny, z))
	return pts


## Change de mode pendant quelques secondes (strike, spare…), puis revient.
func boost(new_mode: String, seconds: float) -> void:
	_boost_mode = new_mode
	_boost_time = seconds


func _process(delta: float) -> void:
	if multimesh == null:
		return
	_t += delta * speed
	var m := mode
	if _boost_time > 0.0:
		_boost_time -= delta
		m = _boost_mode
	var mm := multimesh
	for i in _count:
		var c: Color
		match m:
			"rainbow":
				c = Color.from_hsv(fmod(float(i) / 14.0 - _t * 1.6, 1.0), 0.85, 1.0)
			"flash":
				c = Color(1, 1, 1) if int(_t * 10.0) % 2 == 0 else base_color.darkened(0.7)
			"calm":
				c = base_color.darkened(0.25 + 0.2 * sin(_t * 1.5 + i * 0.4))
			_:
				var on := (i + int(_t * 9.0)) % 4 == 0
				c = Color(1.0, 0.97, 0.85) if on else base_color.darkened(0.55)
		mm.set_instance_color(i, c)
