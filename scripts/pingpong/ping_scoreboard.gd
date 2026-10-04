class_name PingScoreboard
extends Node3D
## Tableau d'affichage du ping-pong : deux gros scores (vous / ordinateur),
## voyant de service, ligne d'info en bas, cadre à ampoules.

const W := 1.3
const H := 0.62
const BLUE := Color(0.2, 0.5, 1.0)
const RED := Color(1.0, 0.3, 0.3)
const GOLD := Color(1.0, 0.8, 0.2)

var _title: Label3D
var _names: Array[Label3D] = []
var _scores: Array[Label3D] = []
var _serve: Array[MeshInstance3D] = []
var _foot: Label3D
var _marquee: Marquee
var _t := 0.0
var _server := 0


func _ready() -> void:
	add_child(BowlingArt.box(Vector3(W + 0.06, H + 0.06, 0.05), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.03)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [H / 2.0 + 0.03, -H / 2.0 - 0.03]:
		add_child(BowlingArt.box(Vector3(W + 0.1, 0.03, 0.07), chrome, Vector3(0, y, -0.005)))
	for x in [W / 2.0 + 0.045, -W / 2.0 - 0.045]:
		add_child(BowlingArt.box(Vector3(0.03, H + 0.09, 0.07), chrome, Vector3(x, 0, -0.005)))
	add_child(BowlingArt.gradient_panel(Vector2(W, H), Color(0.08, 0.1, 0.25), Color(0.02, 0.02, 0.08)))

	var band := BowlingArt.gradient_panel(Vector2(W, 0.13), Color(0.9, 0.2, 0.6), Color(0.35, 0.1, 0.6))
	band.position = Vector3(0, H / 2.0 - 0.075, 0.002)
	add_child(band)
	_title = BowlingArt.label("PING-PONG", 0.07, Color.WHITE, 10)
	_title.font = BowlingArt.bold_font()
	_title.position = Vector3(0, H / 2.0 - 0.075, 0.01)
	add_child(_title)

	for i in 2:
		var x := -0.33 if i == 0 else 0.33
		var col := BLUE if i == 0 else RED
		var chip := BowlingArt.gradient_panel(Vector2(0.56, 0.38), col.darkened(0.55), col.darkened(0.8))
		chip.position = Vector3(x, -0.02, 0.002)
		add_child(chip)
		var n := BowlingArt.label("", 0.07, col.lightened(0.4), 8)
		n.position = Vector3(x, 0.11, 0.01)
		add_child(n)
		_names.append(n)
		var sc := BowlingArt.neon_label("0", 0.24, GOLD)
		sc.outline_size = 22
		sc.position = Vector3(x, -0.06, 0.012)
		add_child(sc)
		_scores.append(sc)
		var dot := BowlingArt.sphere(0.022, BowlingArt.unshaded(Color(1, 0.9, 0.3)), Vector3(x - 0.22, 0.11, 0.012), 10)
		add_child(dot)
		_serve.append(dot)
	_foot = BowlingArt.label("", 0.05, Color(1, 0.92, 0.5), 8)
	_foot.position = Vector3(0, -H / 2.0 + 0.045, 0.01)
	add_child(_foot)

	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(W + 0.12, H + 0.12, 0.075, 0.03), 0.014)
	add_child(_marquee)


func celebrate(kind: String) -> void:
	match kind:
		"win":
			_marquee.boost("rainbow", 3.5)
		"point":
			_marquee.boost("flash", 1.2)
		"lose":
			_marquee.boost("calm", 1.8)


## server : 1 = vous, -1 = ordinateur, 0 = aucun.
func set_data(title: String, names: Array, scores: Array, server: int, footer: String) -> void:
	_title.text = title
	_server = server
	for i in 2:
		_names[i].text = String(names[i])
		_scores[i].text = str(scores[i])
	_foot.text = footer


func _process(delta: float) -> void:
	_t += delta
	for i in 2:
		var mine := (i == 0 and _server == 1) or (i == 1 and _server == -1)
		_serve[i].visible = mine and fmod(_t, 0.8) < 0.55
