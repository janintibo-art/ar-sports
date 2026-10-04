class_name Scoreboard
extends Node3D
## Grand tableau des scores au-dessus des quilles : une ligne par joueur,
## les marques (X, /, -) et le score cumulé de chaque frame, le total.

const NAME_W := 0.58
const FRAME_W := 0.26
const LAST_W := 0.38
const TOTAL_W := 0.42
const ROW_H := 0.2
const HEAD_H := 0.12
const STAT_W := 0.5

var _bg: MeshInstance3D
var _title: Label3D
var _header: Array[Label3D] = []
var _cells: Array = []          # [joueur][colonne] -> Label3D
var _cols: Array[float] = []    # largeurs
var _rows := 0
var _training := false
var _n_frames := 10


func build(player_count: int, n_frames: int, training: bool, title: String) -> void:
	for c in get_children():
		c.queue_free()
	_header.clear()
	_cells.clear()
	_cols.clear()
	_rows = player_count
	_training = training
	_n_frames = n_frames

	_cols.append(NAME_W)
	var heads: Array[String] = [""]
	if training:
		for h in ["Lancers", "Strikes", "Moyenne", "Dernier"]:
			_cols.append(STAT_W)
			heads.append(h)
	else:
		for f in n_frames:
			_cols.append(LAST_W if f == n_frames - 1 else FRAME_W)
			heads.append(str(f + 1))
		_cols.append(TOTAL_W)
		heads.append("Total")

	_bg = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bg.material_override = m
	add_child(_bg)

	_title = BowlingArt.label(title, 0.1, Color(1.0, 0.85, 0.3))
	_title.position = Vector3(0, HEAD_H / 2.0 + 0.1, 0.01)
	add_child(_title)

	var x := -_width() / 2.0
	for i in _cols.size():
		var h := BowlingArt.label(heads[i], 0.06, Color(0.75, 0.85, 1.0), 10)
		h.position = Vector3(x + _cols[i] / 2.0, 0.0, 0.01)
		add_child(h)
		_header.append(h)
		x += _cols[i]
	for p in player_count:
		var row: Array[Label3D] = []
		x = -_width() / 2.0
		var y := -HEAD_H / 2.0 - ROW_H * (p + 0.5)
		for i in _cols.size():
			var size := 0.075 if i == 0 else (0.062 if i < _cols.size() - 1 or training else 0.1)
			var l := BowlingArt.label("", size, Color.WHITE, 12)
			l.position = Vector3(x + _cols[i] / 2.0, y, 0.01)
			add_child(l)
			row.append(l)
			x += _cols[i]
		_cells.append(row)


## players : [{name, color, frames, stats}] ; current : index du joueur qui joue.
func refresh(players: Array, current: int, current_frame: int) -> void:
	for p in players.size():
		if p >= _cells.size():
			break
		var pl: Dictionary = players[p]
		var row: Array = _cells[p]
		(row[0] as Label3D).text = pl["name"]
		if _training:
			var st: Dictionary = pl["stats"]
			var throws: int = st["throws"]
			row[1].text = str(throws)
			row[2].text = str(st["strikes"])
			row[3].text = "-" if throws == 0 else "%.1f" % (float(st["pins"]) / throws)
			row[4].text = "-" if throws == 0 else str(st["last"])
		else:
			var frames: Array = pl["frames"]
			var rolls: Array = []
			for f in frames:
				rolls.append_array(f)
			var scores := BowlingGame.frame_scores(rolls, _n_frames)
			for f in _n_frames:
				var fr: Array = frames[f] if f < frames.size() else []
				var marks := BowlingGame.frame_marks(fr, f == _n_frames - 1)
				var cum := str(scores[f]) if f < scores.size() else ""
				row[f + 1].text = marks + "\n" + cum
			row[_n_frames + 1].text = str(0 if scores.is_empty() else scores[scores.size() - 1])
	_rebuild_bg(players, current, current_frame)


func _width() -> float:
	var w := 0.0
	for c in _cols:
		w += c
	return w


func _rebuild_bg(players: Array, current: int, current_frame: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := _width()
	var top := HEAD_H / 2.0 + 0.2
	var bottom := -HEAD_H / 2.0 - ROW_H * _rows - 0.04
	_quad(st, -w / 2.0 - 0.05, top, w + 0.1, top - bottom, Color(0.03, 0.04, 0.08), -0.004)
	_quad(st, -w / 2.0 - 0.05, top, w + 0.1, 0.012, Color(1.0, 0.7, 0.15), -0.002)
	_quad(st, -w / 2.0 - 0.05, bottom + 0.012, w + 0.1, 0.012, Color(1.0, 0.7, 0.15), -0.002)
	for p in _rows:
		var y := -HEAD_H / 2.0 - ROW_H * p
		var x := -w / 2.0
		var pc: Color = players[p]["color"] if p < players.size() else Color.GRAY
		for i in _cols.size():
			var c := Color(0.12, 0.13, 0.18)
			if i == 0:
				c = pc.darkened(0.35)
			elif p == current:
				c = Color(0.2, 0.22, 0.3)
				if not _training and i == current_frame + 1:
					c = pc.darkened(0.1)
			if p == current and i == 0:
				c = pc
			_quad(st, x + 0.006, y - 0.006, _cols[i] - 0.012, ROW_H - 0.012, c, 0.0)
			x += _cols[i]
	_bg.mesh = st.commit()


func _quad(st: SurfaceTool, x: float, y: float, w: float, h: float, c: Color, z: float) -> void:
	var a := Vector3(x, y, z)
	var b := Vector3(x + w, y, z)
	var cc := Vector3(x + w, y - h, z)
	var d := Vector3(x, y - h, z)
	for v in [a, b, cc, a, cc, d]:
		st.set_color(c)
		st.set_normal(Vector3.BACK)
		st.add_vertex(v)
