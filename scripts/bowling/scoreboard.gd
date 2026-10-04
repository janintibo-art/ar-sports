class_name Scoreboard
extends Node3D
## Grand tableau des scores lumineux au-dessus des quilles : une ligne par
## joueur, marques (X jaune, / cyan) et score cumulé de chaque frame, total.
## Cadre chromé à ampoules, ligne du joueur en cours qui pulse, grandes
## annonces animées (STRIKE !, DOUBLE !, TURKEY !, SPARE !…).

const NAME_W := 0.62
const FRAME_W := 0.27
const LAST_W := 0.4
const TOTAL_W := 0.46
const ROW_H := 0.22
const HEAD_H := 0.13
const TITLE_H := 0.2
const STAT_W := 0.52
const X_COLOR := Color(1.0, 0.85, 0.15)
const SPARE_COLOR := Color(0.3, 0.9, 1.0)

var _bg: MeshInstance3D
var _focus: MeshInstance3D
var _row_glow: MeshInstance3D
var _title: Label3D
var _record: Label3D
var _cells: Array = []          # [joueur][colonne] -> Label3D
var _cols: Array[float] = []    # largeurs
var _rows := 0
var _training := false
var _n_frames := 10
var _marquee: Marquee
var _banner: Label3D
var _banner_halo: MeshInstance3D
var _banner_time := 0.0
var _banner_total := 1.0
var _banner_color := Color.WHITE
var _banner_rainbow := false
var _t := 0.0
var _current_color := Color.WHITE


func build(player_count: int, n_frames: int, training: bool, title: String, record_text: String = "") -> void:
	for c in get_children():
		c.queue_free()
	_cells.clear()
	_cols.clear()
	_rows = player_count
	_training = training
	_n_frames = n_frames

	_cols.append(NAME_W)
	var heads: Array[String] = ["Joueur"]
	if training:
		for h in ["Lancers", "Strikes", "Moyenne", "Dernier"]:
			_cols.append(STAT_W)
			heads.append(h)
	else:
		for f in n_frames:
			_cols.append(LAST_W if f == n_frames - 1 else FRAME_W)
			heads.append(str(f + 1))
		_cols.append(TOTAL_W)
		heads.append("TOTAL")

	var w := _width()
	var top := HEAD_H / 2.0 + TITLE_H
	var bottom := -HEAD_H / 2.0 - ROW_H * _rows
	var full_h := top - bottom + 0.08
	var center_y := (top + bottom) / 2.0

	# Caisson noir, cadre chromé et ampoules
	add_child(BowlingArt.box(Vector3(w + 0.14, full_h, 0.06), BowlingArt.mat(Color(0.02, 0.02, 0.04)), Vector3(0, center_y, -0.04)))
	var chrome := BowlingArt.mat(Color(0.85, 0.86, 0.9), 0.15, 0.9)
	for y in [center_y + full_h / 2.0, center_y - full_h / 2.0]:
		add_child(BowlingArt.box(Vector3(w + 0.2, 0.035, 0.09), chrome, Vector3(0, y, -0.02)))
	for x in [(w + 0.17) / 2.0, -(w + 0.17) / 2.0]:
		add_child(BowlingArt.box(Vector3(0.035, full_h + 0.035, 0.09), chrome, Vector3(x, center_y, -0.02)))
	_marquee = Marquee.new()
	_marquee.setup(Marquee.rectangle_points(w + 0.08, full_h - 0.04, 0.085, 0.03), 0.017)
	_marquee.position = Vector3(0, center_y, 0)
	add_child(_marquee)

	# Bandeau titre en dégradé
	var band := BowlingArt.gradient_panel(Vector2(w, TITLE_H - 0.03), Color(0.95, 0.25, 0.55), Color(0.45, 0.1, 0.6))
	band.position = Vector3(0, HEAD_H / 2.0 + TITLE_H / 2.0, -0.002)
	add_child(band)
	_title = BowlingArt.neon_label(title, 0.11, Color(0.6, 0.0, 0.35))
	_title.position = Vector3(-w / 2.0 + 0.06, HEAD_H / 2.0 + TITLE_H / 2.0, 0.01)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)
	_record = BowlingArt.label(record_text, 0.065, Color(1.0, 0.95, 0.7), 14)
	_record.font = BowlingArt.bold_font()
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_record.position = Vector3(w / 2.0 - 0.06, HEAD_H / 2.0 + TITLE_H / 2.0, 0.01)
	add_child(_record)

	# Fonds des cases (reconstruits à chaque mise à jour)
	_bg = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bg.material_override = m
	add_child(_bg)
	_row_glow = BowlingArt.halo(Vector2(w + 0.4, ROW_H * 2.2), Color(1, 1, 1, 0.3))
	add_child(_row_glow)
	_focus = BowlingArt.box(Vector3(FRAME_W, ROW_H, 0.004), BowlingArt.unshaded(Color.WHITE))
	add_child(_focus)

	# En-têtes de colonnes
	var x := -w / 2.0
	for i in _cols.size():
		var h := BowlingArt.label(heads[i], 0.062, Color(0.7, 0.85, 1.0), 10)
		h.font = BowlingArt.bold_font()
		h.position = Vector3(x + _cols[i] / 2.0, 0.0, 0.01)
		add_child(h)
		x += _cols[i]
	# Cases
	for p in player_count:
		var row: Array[Label3D] = []
		x = -w / 2.0
		var y := -HEAD_H / 2.0 - ROW_H * (p + 0.5)
		for i in _cols.size():
			var is_total := not training and i == _cols.size() - 1
			var size := 0.08 if i == 0 else (0.115 if is_total else 0.072)
			if training and i > 0:
				size = 0.1
			var l := BowlingArt.label("", size, Color.WHITE, 16)
			l.font = BowlingArt.bold_font()
			if is_total:
				l.modulate = X_COLOR
			l.position = Vector3(x + _cols[i] / 2.0, y, 0.012)
			add_child(l)
			row.append(l)
			x += _cols[i]
		_cells.append(row)

	# Grande annonce animée devant le tableau
	_banner_halo = BowlingArt.halo(Vector2(2.6, 0.9), Color(1, 1, 1, 0))
	_banner_halo.position = Vector3(0, center_y, 0.06)
	add_child(_banner_halo)
	_banner = BowlingArt.neon_label("", 0.36, Color.WHITE)
	_banner.position = Vector3(0, center_y, 0.08)
	_banner.no_depth_test = true
	_banner.render_priority = 10
	add_child(_banner)


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
			row[2].modulate = X_COLOR if int(st["strikes"]) > 0 else Color.WHITE
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
				var l: Label3D = row[f + 1]
				l.text = marks + "\n" + cum
				l.modulate = X_COLOR if "X" in marks else (SPARE_COLOR if "/" in marks else Color.WHITE)
			row[_n_frames + 1].text = str(0 if scores.is_empty() else scores[scores.size() - 1])
	_rebuild_bg(players, current, current_frame)


func set_record_text(text: String) -> void:
	if _record:
		_record.text = text


## Grande annonce : texte, couleur, durée ; rainbow = couleurs qui tournent.
func announce(text: String, color: Color, seconds: float = 2.5, rainbow: bool = false) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner_color = color
	_banner_time = seconds
	_banner_total = seconds
	_banner_rainbow = rainbow
	if rainbow:
		_marquee.boost("rainbow", seconds)
	else:
		_marquee.boost("flash", minf(seconds, 1.5))


func _process(delta: float) -> void:
	_t += delta
	if _focus and _focus.visible:
		var pulse := 0.55 + 0.45 * absf(sin(_t * 3.0))
		(_focus.material_override as StandardMaterial3D).albedo_color = _current_color.lightened(0.25) * Color(pulse, pulse, pulse, 1.0)
	if _row_glow:
		(_row_glow.material_override as StandardMaterial3D).albedo_color = _current_color * Color(1, 1, 1, 0.18 + 0.1 * sin(_t * 3.0))
	if _banner == null:
		return
	if _banner_time > 0.0:
		_banner_time -= delta
		var age := _banner_total - _banner_time
		# Apparition en « pop », léger rebond, puis fondu
		var s := 1.0
		if age < 0.25:
			s = lerpf(0.3, 1.15, age / 0.25)
		elif age < 0.4:
			s = lerpf(1.15, 1.0, (age - 0.25) / 0.15)
		s *= 1.0 + 0.03 * sin(age * 12.0)
		var alpha := clampf(_banner_time / 0.4, 0.0, 1.0)
		var c := _banner_color
		if _banner_rainbow:
			c = Color.from_hsv(fmod(age * 1.2, 1.0), 0.85, 1.0)
		_banner.scale = Vector3.ONE * s
		_banner.outline_modulate = c * Color(1, 1, 1, alpha)
		_banner.modulate = Color(1, 1, 1, alpha)
		(_banner_halo.material_override as StandardMaterial3D).albedo_color = c * Color(1, 1, 1, 0.5 * alpha)
		if _banner_time <= 0.0:
			_banner.text = ""
			(_banner_halo.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, 0)


func _width() -> float:
	var w := 0.0
	for c in _cols:
		w += c
	return w


func _rebuild_bg(players: Array, current: int, current_frame: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := _width()
	# Bande d'en-tête
	_quad(st, -w / 2.0, HEAD_H / 2.0, w, HEAD_H - 0.01, Color(0.08, 0.1, 0.2), Color(0.04, 0.05, 0.12), 0.0)
	_current_color = players[current]["color"] if current < players.size() else Color.WHITE
	for p in _rows:
		var y := -HEAD_H / 2.0 - ROW_H * p
		var x := -w / 2.0
		var pc: Color = players[p]["color"] if p < players.size() else Color.GRAY
		var is_cur := p == current
		for i in _cols.size():
			var top_c := Color(0.16, 0.17, 0.24)
			var bot_c := Color(0.07, 0.08, 0.12)
			if i == 0:
				top_c = pc.lightened(0.15) if is_cur else pc.darkened(0.25)
				bot_c = pc.darkened(0.2) if is_cur else pc.darkened(0.55)
			elif is_cur:
				top_c = pc.darkened(0.45)
				bot_c = pc.darkened(0.72)
			elif not _training and i == _cols.size() - 1:
				top_c = Color(0.22, 0.18, 0.08)
				bot_c = Color(0.1, 0.08, 0.03)
			_quad(st, x + 0.007, y - 0.007, _cols[i] - 0.014, ROW_H - 0.014, top_c, bot_c, 0.0)
			x += _cols[i]
	_bg.mesh = st.commit()

	# Halo derrière la ligne du joueur en cours, cadre pulsant sur la frame en cours
	var row_y := -HEAD_H / 2.0 - ROW_H * (current + 0.5)
	_row_glow.position = Vector3(0, row_y, -0.003)
	_focus.visible = not _training and current_frame < _n_frames and current < _rows
	if _focus.visible:
		var fx := -w / 2.0
		for i in current_frame + 1:
			fx += _cols[i]
		var fw := _cols[current_frame + 1]
		(_focus.mesh as BoxMesh).size = Vector3(fw - 0.004, ROW_H - 0.004, 0.003)
		_focus.position = Vector3(fx + fw / 2.0, row_y, -0.001)


func _quad(st: SurfaceTool, x: float, y: float, w: float, h: float, top_c: Color, bot_c: Color, z: float) -> void:
	var a := Vector3(x, y, z)
	var b := Vector3(x + w, y, z)
	var cc := Vector3(x + w, y - h, z)
	var d := Vector3(x, y - h, z)
	for v in [[a, top_c], [b, top_c], [cc, bot_c], [a, top_c], [cc, bot_c], [d, bot_c]]:
		st.set_color(v[1])
		st.set_normal(Vector3.BACK)
		st.add_vertex(v[0])
