class_name NeonSign
extends Node3D
## Enseigne lumineuse au-dessus des quilles : « BOWLING » en néon rose,
## quilles et boule en néon, cadre d'ampoules qui défilent.
## Elle réagit au jeu : arc-en-ciel sur un strike, clignote sur un spare,
## néon qui grésille quand la boule finit dans la rigole.

const W := 1.75
const H := 0.66
const PINK := Color(1.0, 0.15, 0.6)
const CYAN := Color(0.1, 0.85, 1.0)
const GOLD := Color(1.0, 0.75, 0.2)

var _title: Label3D
var _sub: Label3D
var _title_halo: MeshInstance3D
var _tube: MeshInstance3D
var _tube_halo: MeshInstance3D
var _icons: Array[Node3D] = []
var _marquee: Marquee
var _t := 0.0
var _mode := ""
var _mode_time := 0.0
var _flicker := 0.0


func _ready() -> void:
	# Caisson : dégradé violet nuit, cadre chromé
	var back := BowlingArt.gradient_panel(Vector2(W, H), Color(0.16, 0.04, 0.28), Color(0.02, 0.02, 0.08))
	add_child(back)
	add_child(BowlingArt.box(Vector3(W, H, 0.06), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.035)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [H / 2.0, -H / 2.0]:
		add_child(BowlingArt.box(Vector3(W + 0.06, 0.03, 0.08), chrome, Vector3(0, y, -0.01)))
	for x in [W / 2.0, -W / 2.0]:
		add_child(BowlingArt.box(Vector3(0.03, H + 0.06, 0.08), chrome, Vector3(x, 0, -0.01)))

	# Halos lumineux (derrière les néons)
	_title_halo = BowlingArt.halo(Vector2(1.5, 0.5), PINK * Color(1, 1, 1, 0.55))
	_title_halo.position = Vector3(0, 0.03, 0.005)
	add_child(_title_halo)
	_tube_halo = BowlingArt.halo(Vector2(1.2, 0.16), CYAN * Color(1, 1, 1, 0.5))
	_tube_halo.position = Vector3(0, -0.15, 0.006)
	add_child(_tube_halo)

	# Lettrage néon
	_title = BowlingArt.neon_label("BOWLING", 0.22, PINK)
	_title.position = Vector3(0, 0.04, 0.02)
	add_child(_title)
	_sub = BowlingArt.neon_label("·  AR SPORTS  ·", 0.06, GOLD)
	_sub.position = Vector3(0, 0.22, 0.02)
	add_child(_sub)
	var tube_mat := BowlingArt.unshaded(Color(0.75, 0.97, 1.0))
	_tube = BowlingArt.capsule(0.012, 1.0, tube_mat, Vector3(0, -0.15, 0.02))
	_tube.rotation_degrees = Vector3(0, 0, 90)
	add_child(_tube)

	# Icônes : une quille de chaque côté, une boule à droite
	for side in [-1.0, 1.0]:
		var icon := Node3D.new()
		icon.position = Vector3(side * 0.72, -0.02, 0.03)
		add_child(icon)
		var h := BowlingArt.halo(Vector2(0.26, 0.42), CYAN * Color(1, 1, 1, 0.45))
		h.position = Vector3(0, 0, -0.01)
		icon.add_child(h)
		var pin := MeshInstance3D.new()
		pin.mesh = BowlingArt.pin_mesh()
		var pm := StandardMaterial3D.new()
		pm.vertex_color_use_as_albedo = true
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pin.material_override = pm
		pin.scale = Vector3.ONE * 0.85
		pin.rotation_degrees = Vector3(0, 0, -12.0 * side)
		icon.add_child(pin)
		_icons.append(icon)
	var ball := BowlingArt.sphere(0.07, BowlingArt.unshaded(Color(0.25, 0.45, 1.0)), Vector3(0.58, -0.13, 0.05), 16)
	add_child(ball)
	var shine := BowlingArt.sphere(0.018, BowlingArt.unshaded(Color(0.85, 0.92, 1.0)), Vector3(0.555, -0.105, 0.11), 8)
	add_child(shine)

	# Ampoules tout autour
	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(W - 0.06, H - 0.06, 0.07, 0.03), 0.016)
	add_child(_marquee)


## kind : strike, spare, gutter, win
func celebrate(kind: String) -> void:
	match kind:
		"strike", "win":
			_marquee.boost("rainbow", 3.5)
			_set_mode("rainbow", 3.5)
		"spare":
			_marquee.boost("flash", 1.8)
			_set_mode("pulse", 1.8)
		"gutter":
			_marquee.boost("calm", 2.0)
			_set_mode("broken", 2.0)


func _set_mode(m: String, seconds: float) -> void:
	_mode = m
	_mode_time = seconds


func _process(delta: float) -> void:
	_t += delta
	if _mode_time > 0.0:
		_mode_time -= delta
		if _mode_time <= 0.0:
			_mode = ""

	var glow := PINK
	var lit := 1.0
	match _mode:
		"rainbow":
			glow = Color.from_hsv(fmod(_t * 0.9, 1.0), 0.9, 1.0)
			lit = 1.0 + 0.15 * sin(_t * 18.0)
		"pulse":
			lit = 0.75 + 0.35 * absf(sin(_t * 9.0))
		"broken":
			# Le néon grésille et s'éteint par à-coups
			lit = 0.15 if fmod(_t * 7.3, 1.0) < 0.45 or randf() < 0.2 else 1.0
		_:
			# Petit grésillement aléatoire de temps en temps, comme un vrai néon
			if _flicker > 0.0:
				_flicker -= delta
				lit = 0.35 if randf() < 0.5 else 1.0
			elif randf() < delta * 0.08:
				_flicker = 0.25
			lit *= 0.92 + 0.08 * sin(_t * 2.2)

	_title.outline_modulate = glow * Color(lit, lit, lit, 1.0)
	_title.modulate = Color(1, 1, 1).lerp(glow, 0.2) * Color(lit, lit, lit, 1.0)
	var hm := _title_halo.material_override as StandardMaterial3D
	hm.albedo_color = glow * Color(1, 1, 1, 0.5 * lit)
	var th := _tube_halo.material_override as StandardMaterial3D
	th.albedo_color = CYAN * Color(1, 1, 1, 0.35 + 0.15 * sin(_t * 3.0))
	for i in _icons.size():
		_icons[i].rotation.z = sin(_t * 1.2 + i * PI) * 0.06
