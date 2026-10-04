class_name Logo
extends Node3D
## Logo « AR SPORTS » : enseigne néon violette cadre chromé et ampoules, quatre
## médaillons (bowling, fléchettes, pétanque, ping-pong) et titre qui change de teinte.

const W := 0.92
const H := 0.44
const PINK := Color(1.0, 0.15, 0.6)
const CYAN := Color(0.1, 0.85, 1.0)
const GOLD := Color(1.0, 0.78, 0.25)
const BADGES := [
	["bowling", Color(0.9, 0.25, 0.25)], ["flechettes", Color(0.3, 0.5, 1.0)],
	["petanque", Color(0.9, 0.7, 0.2)], ["pingpong", Color(0.2, 0.75, 0.4)],
]

var _title: Label3D
var _halo: MeshInstance3D
var _icons: Array[Node3D] = []
var _marquee: Marquee
var _t := 0.0


func _ready() -> void:
	add_child(BowlingArt.gradient_panel(Vector2(W, H), Color(0.22, 0.05, 0.38), Color(0.03, 0.02, 0.1)))
	add_child(BowlingArt.box(Vector3(W, H, 0.05), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.03)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [H / 2.0, -H / 2.0]:
		add_child(BowlingArt.box(Vector3(W + 0.04, 0.022, 0.06), chrome, Vector3(0, y, -0.005)))
	for x in [W / 2.0, -W / 2.0]:
		add_child(BowlingArt.box(Vector3(0.022, H + 0.04, 0.06), chrome, Vector3(x, 0, -0.005)))

	_halo = BowlingArt.halo(Vector2(0.8, 0.26), PINK * Color(1, 1, 1, 0.5))
	_halo.position = Vector3(0, -0.06, 0.004)
	add_child(_halo)

	# Quatre médaillons
	for i in BADGES.size():
		var x := (i - 1.5) * 0.15
		var ring := BowlingArt.cylinder(0.058, 0.058, 0.008, BowlingArt.unshaded(BADGES[i][1]), Vector3(x, 0.11, 0.006), 28)
		ring.rotation_degrees = Vector3(90, 0, 0)
		add_child(ring)
		var disc := BowlingArt.cylinder(0.05, 0.05, 0.01, BowlingArt.unshaded(Color(0.06, 0.06, 0.14)), Vector3(x, 0.11, 0.008), 28)
		disc.rotation_degrees = Vector3(90, 0, 0)
		add_child(disc)
		var icon := GameIcons.build(BADGES[i][0])
		icon.position = Vector3(x, 0.11, 0.035)
		icon.scale = Vector3.ONE * 0.6
		add_child(icon)
		_icons.append(icon)

	_title = BowlingArt.neon_label("AR SPORTS", 0.135, PINK)
	_title.position = Vector3(0, -0.06, 0.02)
	add_child(_title)
	var tube := BowlingArt.capsule(0.007, 0.62, BowlingArt.unshaded(Color(0.75, 0.97, 1.0)), Vector3(0, -0.14, 0.02))
	tube.rotation_degrees = Vector3(0, 0, 90)
	add_child(tube)
	var sub := BowlingArt.neon_label("RÉALITÉ AUGMENTÉE", 0.03, GOLD)
	sub.outline_size = 20
	sub.position = Vector3(0, -0.172, 0.02)
	add_child(sub)

	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(W - 0.04, H - 0.04, 0.065, 0.03), 0.014)
	add_child(_marquee)


func celebrate(seconds: float = 2.0) -> void:
	_marquee.boost("rainbow", seconds)


func _process(delta: float) -> void:
	_t += delta
	var glow := PINK.lerp(CYAN, 0.5 + 0.5 * sin(_t * 0.7))
	_title.outline_modulate = glow
	_title.modulate = Color(1, 1, 1).lerp(glow, 0.2)
	(_halo.material_override as StandardMaterial3D).albedo_color = glow * Color(1, 1, 1, 0.45)
	for i in _icons.size():
		_icons[i].rotation = Vector3(0.0, sin(_t * 1.1 + i * 1.3) * 0.45, 0.0)
