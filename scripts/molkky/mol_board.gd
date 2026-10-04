class_name MolkkyBoard
extends Node3D
## Tableau d'affichage du Mölkky : jusqu'à 4 joueurs (nom, score, essais ratés),
## le joueur courant est mis en avant, ligne d'info en bas.

const W := 1.3
const H := 0.78
const GOLD := Color(1.0, 0.8, 0.2)
const ROW_COLORS := [Color(0.2, 0.5, 1.0), Color(1.0, 0.35, 0.3), Color(0.3, 0.85, 0.4), Color(0.9, 0.5, 1.0)]

var _title: Label3D
var _rows: Array = []        # {bg, name, score, dots[], arrow}
var _foot: Label3D
var _marquee: Marquee
var _target := 50


func _ready() -> void:
	add_child(BowlingArt.box(Vector3(W + 0.06, H + 0.06, 0.05), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.03)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [H / 2.0 + 0.03, -H / 2.0 - 0.03]:
		add_child(BowlingArt.box(Vector3(W + 0.1, 0.03, 0.07), chrome, Vector3(0, y, -0.005)))
	for x in [W / 2.0 + 0.045, -W / 2.0 - 0.045]:
		add_child(BowlingArt.box(Vector3(0.03, H + 0.09, 0.07), chrome, Vector3(x, 0, -0.005)))
	add_child(BowlingArt.gradient_panel(Vector2(W, H), Color(0.14, 0.09, 0.05), Color(0.04, 0.03, 0.03)))
	var band := BowlingArt.gradient_panel(Vector2(W, 0.13), Color(0.9, 0.55, 0.15), Color(0.5, 0.25, 0.08))
	band.position = Vector3(0, H / 2.0 - 0.075, 0.002)
	add_child(band)
	_title = BowlingArt.label("MÖLKKY", 0.075, Color.WHITE, 10)
	_title.font = BowlingArt.bold_font()
	_title.position = Vector3(0, H / 2.0 - 0.075, 0.01)
	add_child(_title)
	for i in 4:
		var y := H / 2.0 - 0.2 - i * 0.13
		var col: Color = ROW_COLORS[i]
		var bg := BowlingArt.gradient_panel(Vector2(W - 0.08, 0.11), col.darkened(0.55), col.darkened(0.8))
		bg.position = Vector3(0, y, 0.002)
		add_child(bg)
		var arrow := BowlingArt.sphere(0.025, BowlingArt.unshaded(Color(1, 0.9, 0.3)), Vector3(-W / 2.0 + 0.07, y, 0.012), 10)
		add_child(arrow)
		var nm := BowlingArt.label("", 0.065, col.lightened(0.45), 8)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nm.position = Vector3(-W / 2.0 + 0.13, y, 0.012)
		add_child(nm)
		var sc := BowlingArt.neon_label("0", 0.1, GOLD)
		sc.outline_size = 16
		sc.position = Vector3(0.3, y, 0.014)
		add_child(sc)
		var dots: Array = []
		for k in 3:
			var d := BowlingArt.sphere(0.02, BowlingArt.unshaded(Color(0.35, 0.1, 0.1)), Vector3(0.48 + k * 0.055, y, 0.012), 10)
			add_child(d)
			dots.append(d)
		_rows.append({"bg": bg, "name": nm, "score": sc, "dots": dots, "arrow": arrow})
	_foot = BowlingArt.label("", 0.05, Color(1, 0.92, 0.5), 8)
	_foot.position = Vector3(0, -H / 2.0 + 0.045, 0.01)
	add_child(_foot)
	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(W + 0.12, H + 0.12, 0.075, 0.03), 0.014)
	add_child(_marquee)


func celebrate(kind: String) -> void:
	if kind in ["win", "point"]:
		SuccessBurst.play(self, kind in ["win", "big", "strike"])
	match kind:
		"win":
			_marquee.boost("rainbow", 3.5)
		"point":
			_marquee.boost("flash", 1.0)
		"bust":
			_marquee.boost("calm", 1.8)


## players : [{name, score, misses, out}], current : index du joueur qui joue.
func set_data(title: String, players: Array, current: int, target: int, footer: String) -> void:
	_title.text = title
	_target = target
	for i in 4:
		var row: Dictionary = _rows[i]
		var on := i < players.size()
		for k in ["bg", "name", "score", "arrow"]:
			(row[k] as Node3D).visible = on
		for d in row["dots"]:
			(d as Node3D).visible = on
		if not on:
			continue
		var p: Dictionary = players[i]
		(row["name"] as Label3D).text = String(p["name"])
		(row["score"] as Label3D).text = ("%d" % int(p["score"])) if not bool(p.get("out", false)) else "—"
		(row["arrow"] as Node3D).visible = i == current
		var misses: int = int(p["misses"])
		for k in 3:
			var m := ((row["dots"] as Array)[k] as MeshInstance3D).material_override as StandardMaterial3D
			m.albedo_color = Color(1, 0.2, 0.2) if k < misses else Color(0.35, 0.1, 0.1)
		(row["name"] as Label3D).modulate = Color(0.5, 0.5, 0.5) if bool(p.get("out", false)) else Color.WHITE
	_foot.text = footer
