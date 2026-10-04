class_name DartScoreboard
extends Node3D
## Tableau des scores des fléchettes : une ligne par joueur (nom, points restants
## en gros, trois dernières fléchettes), ligne du joueur actif qui pulse, conseil
## de sortie en bas, cadre chromé à ampoules.

const W := 1.2
const TITLE_H := 0.17
const ROW_H := 0.2
const FOOT_H := 0.1
const NAME_W := 0.4
const GOLD := Color(1.0, 0.8, 0.2)
const CYAN := Color(0.2, 0.85, 1.0)

var height := 0.0
var _rows: Array = []
var _title: Label3D
var _record: Label3D
var _hint: Label3D
var _content: Node3D
var _marquee: Marquee
var _t := 0.0
var _current := -1


func build(count: int, title: String, record_text: String) -> void:
	if _content:
		_content.queue_free()
	if _marquee:
		_marquee.queue_free()
	_content = Node3D.new()
	add_child(_content)
	_rows.clear()
	height = TITLE_H + ROW_H * count + FOOT_H
	var top := height / 2.0

	_content.add_child(BowlingArt.box(Vector3(W + 0.06, height + 0.06, 0.05), BowlingArt.mat(Color(0.03, 0.03, 0.05)), Vector3(0, 0, -0.03)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [top + 0.03, -top - 0.03]:
		_content.add_child(BowlingArt.box(Vector3(W + 0.1, 0.03, 0.07), chrome, Vector3(0, y, -0.005)))
	for x in [W / 2.0 + 0.045, -W / 2.0 - 0.045]:
		_content.add_child(BowlingArt.box(Vector3(0.03, height + 0.09, 0.07), chrome, Vector3(x, 0, -0.005)))

	# Bandeau titre rose -> violet
	var band := BowlingArt.gradient_panel(Vector2(W, TITLE_H - 0.02), Color(0.9, 0.2, 0.6), Color(0.35, 0.1, 0.6))
	band.position = Vector3(0, top - TITLE_H / 2.0, 0.001)
	_content.add_child(band)
	_title = BowlingArt.label(title, 0.07, Color.WHITE, 10)
	_title.font = BowlingArt.bold_font()
	_title.position = Vector3(-0.2, top - TITLE_H / 2.0, 0.01)
	_content.add_child(_title)
	_record = BowlingArt.label(record_text, 0.045, Color(1, 0.92, 0.5), 8)
	_record.position = Vector3(0.42, top - TITLE_H / 2.0, 0.01)
	_content.add_child(_record)

	for i in count:
		var y := top - TITLE_H - ROW_H * (i + 0.5)
		var row := Node3D.new()
		row.position = Vector3(0, y, 0)
		_content.add_child(row)
		var bg := BowlingArt.gradient_panel(Vector2(W, ROW_H - 0.016), Color(0.1, 0.12, 0.28), Color(0.03, 0.04, 0.12))
		bg.position = Vector3(0, 0, 0.001)
		row.add_child(bg)
		var halo := BowlingArt.halo(Vector2(W * 1.05, ROW_H * 1.5), Color(1, 1, 1, 0.0))
		halo.position = Vector3(0, 0, 0.003)
		row.add_child(halo)
		var chip := BowlingArt.gradient_panel(Vector2(NAME_W, ROW_H - 0.036), Color(1, 1, 1), Color(0.5, 0.5, 0.5))
		chip.position = Vector3(-W / 2.0 + NAME_W / 2.0 + 0.012, 0, 0.004)
		row.add_child(chip)
		var name_l := BowlingArt.label("", 0.06, Color.WHITE, 8)
		name_l.position = Vector3(-W / 2.0 + NAME_W / 2.0 + 0.012, 0, 0.012)
		row.add_child(name_l)
		var rem := BowlingArt.neon_label("", 0.14, GOLD)
		rem.outline_size = 14
		rem.position = Vector3(-0.04, 0, 0.012)
		row.add_child(rem)
		var chips: Array[Label3D] = []
		for k in 3:
			var cx := 0.21 + 0.145 * k
			var cell := BowlingArt.gradient_panel(Vector2(0.13, ROW_H - 0.05), Color(0.16, 0.2, 0.42), Color(0.07, 0.09, 0.2))
			cell.position = Vector3(cx, 0, 0.004)
			row.add_child(cell)
			var cl := BowlingArt.label("", 0.06, Color.WHITE, 8)
			cl.position = Vector3(cx, 0, 0.012)
			row.add_child(cl)
			chips.append(cl)
		_rows.append({"chip": chip, "name": name_l, "rem": rem, "darts": chips, "halo": halo})

	_hint = BowlingArt.label("", 0.05, Color(1, 0.92, 0.5), 8)
	_hint.position = Vector3(0, -top + FOOT_H / 2.0, 0.01)
	_content.add_child(_hint)

	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(W + 0.12, height + 0.12, 0.075, 0.03), 0.014)
	add_child(_marquee)


func celebrate(kind: String) -> void:
	if _marquee == null:
		return
	match kind:
		"win", "big":
			_marquee.boost("rainbow", 3.5)
		"good":
			_marquee.boost("flash", 1.5)
		"bust":
			_marquee.boost("calm", 2.0)


## players : [{name, color, remaining, target, last: Array[String]}], mode : "301"…
func refresh(players: Array, current: int, mode: String, hint: String) -> void:
	_current = current
	for i in players.size():
		if i >= _rows.size():
			break
		var p: Dictionary = players[i]
		var row: Dictionary = _rows[i]
		var col: Color = p["color"]
		var chip: MeshInstance3D = row["chip"]
		_set_gradient(chip, col.lightened(0.25), col.darkened(0.35))
		(row["name"] as Label3D).text = String(p["name"])
		var rem: Label3D = row["rem"]
		match mode:
			"horloge":
				rem.text = "BULL" if int(p["target"]) > 20 else "→ %d" % int(p["target"])
			"libre":
				rem.text = str(int(p["points"]))
			_:
				rem.text = str(int(p["remaining"]))
		var last: Array = p["last"]
		var chips: Array = row["darts"]
		for k in 3:
			var lbl: Label3D = chips[k]
			lbl.text = String(last[k]) if k < last.size() else ""
			lbl.modulate = _label_color(lbl.text)
	_hint.text = hint


func _label_color(t: String) -> Color:
	if t == "RATÉ":
		return Color(0.6, 0.62, 0.7)
	if t.begins_with("T") or t == "BULL":
		return Color(1.0, 0.45, 0.45)
	if t.begins_with("D"):
		return Color(0.5, 1.0, 0.6)
	return Color.WHITE


func _set_gradient(mi: MeshInstance3D, top: Color, bottom: Color) -> void:
	var mesh := mi.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for v in verts:
		colors.append(top if v.y > 0.0 else bottom)
	arrays[Mesh.ARRAY_COLOR] = colors
	var fresh := ArrayMesh.new()
	fresh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = fresh


func _process(delta: float) -> void:
	_t += delta
	for i in _rows.size():
		var halo := _rows[i]["halo"] as MeshInstance3D
		var hm := halo.material_override as StandardMaterial3D
		if i == _current:
			var a := 0.35 + 0.25 * sin(_t * 5.0)
			hm.albedo_color = Color(1.0, 0.85, 0.3, a)
		else:
			hm.albedo_color = Color(1, 1, 1, 0.0)
