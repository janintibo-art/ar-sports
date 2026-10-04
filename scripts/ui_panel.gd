class_name UiPanel
extends Node3D
## Petit panneau d'interface flottant (titre, lignes de boutons) piloté au laser.
## Les boutons sont des StaticBody3D sur le calque 2, visés par les mains.

signal pressed(id: String)

const BTN_H := 0.075
const ROW_GAP := 0.03
const CAPTION_W := 0.22

var _buttons: Array[StaticBody3D] = []
var _hovered: StaticBody3D = null
var _root: Node3D
var _bg: MeshInstance3D
var _rows: Array = []   # chaque ligne : {caption, items:[{id,text,selected,color,width}]}
var _title := ""
var _subtitle := ""
var accent := Color(1.0, 0.72, 0.2)   # couleur du jeu (cadre, titre, ampoules)


func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)


func clear() -> void:
	_rows.clear()
	_title = ""
	_subtitle = ""


func set_title(title: String, subtitle: String = "") -> void:
	_title = title
	_subtitle = subtitle


## Ajoute une ligne de boutons. items : [{id, text, selected?, color?, width?}]
func add_row(caption: String, items: Array) -> void:
	_rows.append({"caption": caption, "items": items})


## Construit (ou reconstruit) le panneau.
func build() -> void:
	for c in _root.get_children():
		c.queue_free()
	_buttons.clear()
	_hovered = null

	var y := 0.0
	var width := 0.9
	var nodes: Array = []
	var header_h := 0.0
	if _title != "":
		var t := BowlingArt.neon_label(_title, 0.07, accent)
		t.position = Vector3(0, y - 0.005, 0.014)
		nodes.append(t)
		y -= 0.075
		header_h = 0.12
	if _subtitle != "":
		var s := BowlingArt.label(_subtitle, 0.04, Color(1, 0.92, 0.6))
		s.position = Vector3(0, y, 0.012)
		nodes.append(s)
		y -= 0.03 + 0.04 * _subtitle.count("\n")
	y -= 0.04
	var rows_top := y
	for row in _rows:
		var items: Array = row["items"]
		var gap := 0.02
		var total := 0.0
		for it in items:
			total += float(it.get("width", 0.16)) + gap
		total -= gap
		var x0 := -total / 2.0
		if row["caption"] != "":
			x0 = -total / 2.0 + CAPTION_W / 2.0
			var cap := BowlingArt.label(row["caption"], 0.038, Color(0.85, 0.9, 1.0))
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cap.position = Vector3(x0 - 0.03, y - BTN_H / 2.0, 0.012)
			nodes.append(cap)
			width = maxf(width, total + CAPTION_W * 2.0 + 0.1)
		else:
			width = maxf(width, total + 0.1)
		var x := x0
		for it in items:
			var w: float = it.get("width", 0.16)
			var b := _make_button(it, w)
			b.position = Vector3(x + w / 2.0, y - BTN_H / 2.0, 0.0)
			nodes.append(b)
			_buttons.append(b)
			x += w + gap
		y -= BTN_H + ROW_GAP
	var height := -y + 0.1
	var cy := -height / 2.0 + 0.07
	var top := 0.07
	var bot := -height + 0.07
	# Halo lumineux derrière le panneau
	var glow := BowlingArt.halo(Vector2(width * 1.3, height * 1.4), accent * Color(1, 1, 1, 0.28))
	glow.position = Vector3(0, cy, -0.03)
	_root.add_child(glow)
	# Fond : dégradé nuit teinté de la couleur du jeu
	_bg = BowlingArt.gradient_panel(Vector2(width, height), accent.darkened(0.82).lerp(Color(0.1, 0.07, 0.2), 0.5), Color(0.02, 0.02, 0.06))
	_bg.position = Vector3(0, cy, -0.012)
	_root.add_child(_bg)
	# Bandeau de titre
	if header_h > 0.0:
		var band := BowlingArt.gradient_panel(Vector2(width, header_h), accent.darkened(0.25), accent.darkened(0.7))
		band.position = Vector3(0, top - header_h / 2.0, -0.008)
		_root.add_child(band)
		var sep := BowlingArt.box(Vector3(width * 0.92, 0.003, 0.004), BowlingArt.unshaded(accent.lightened(0.4)), Vector3(0, rows_top + 0.045, -0.004))
		_root.add_child(sep)
	# Cadre
	var frame_mat := BowlingArt.unshaded(accent.lightened(0.15))
	for fy in [top, bot]:
		_root.add_child(BowlingArt.box(Vector3(width + 0.012, 0.008, 0.012), frame_mat, Vector3(0, fy, -0.006)))
	for fx in [-width / 2.0, width / 2.0]:
		_root.add_child(BowlingArt.box(Vector3(0.008, height + 0.008, 0.012), frame_mat, Vector3(fx, cy, -0.006)))
	# Ampoules de fête foraine autour
	var marq := Marquee.new()
	marq.base_color = accent.lightened(0.35)
	marq.setup(Marquee.rectangle_points(width + 0.05, height + 0.05, 0.062, 0.0), 0.0105)
	marq.position = Vector3(0, cy, -0.002)
	_root.add_child(marq)
	for n in nodes:
		_root.add_child(n)
	_root.position = Vector3(0, height / 2.0 - 0.07, 0)


func show_panel() -> void:
	visible = true
	for b in _buttons:
		b.collision_layer = 2
	if _root:
		_root.scale = Vector3.ONE * 0.88
		var tw_ := create_tween()
		tw_.tween_property(_root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	visible = false
	update_hover([])
	for b in _buttons:
		b.collision_layer = 0


## Place le panneau devant le regard, légèrement sous les yeux.
func place_in_front_of(head: Transform3D, distance: float = 0.85) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var pos := head.origin + forward * distance
	pos.y = maxf(head.origin.y - 0.2, 0.8)
	global_position = pos
	global_basis = Basis.looking_at(forward, Vector3.UP)


func update_hover(objects: Array) -> void:
	var target: StaticBody3D = null
	if visible:
		for obj in objects:
			if obj is StaticBody3D and _buttons.has(obj):
				target = obj
				break
	if target == _hovered:
		return
	if _hovered and is_instance_valid(_hovered):
		_highlight(_hovered, false)
	_hovered = target
	if _hovered:
		_highlight(_hovered, true)


func click(obj: Object) -> bool:
	if not visible or not (obj is StaticBody3D and _buttons.has(obj)):
		return false
	Sound.play("ui_click", -4.0)
	pressed.emit(String(obj.get_meta("ui_id")))
	return true


func _make_button(it: Dictionary, w: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2 if visible else 0
	body.collision_mask = 0
	body.set_meta("ui_id", it["id"])
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, BTN_H, 0.02)
	shape.shape = bs
	body.add_child(shape)
	var selected: bool = it.get("selected", false)
	var base: Color = it.get("color", Color(0.22, 0.25, 0.32))
	if selected:
		base = Color(0.98, 0.7, 0.18)
	body.set_meta("base_color", base)
	var face := BowlingArt.gradient_panel(Vector2(w, BTN_H), base.lightened(0.28), base.darkened(0.3))
	face.name = "Fond"
	face.position = Vector3(0, 0, 0.0)
	body.add_child(face)
	# Liseré clair en haut (effet bouton bombé) et ombre en bas
	body.add_child(BowlingArt.box(Vector3(w, 0.004, 0.002), BowlingArt.unshaded(base.lightened(0.6)), Vector3(0, BTN_H / 2.0 - 0.002, 0.002)))
	body.add_child(BowlingArt.box(Vector3(w, 0.004, 0.002), BowlingArt.unshaded(base.darkened(0.6)), Vector3(0, -BTN_H / 2.0 + 0.002, 0.002)))
	if selected:
		var h := BowlingArt.halo(Vector2(w * 1.25, BTN_H * 1.9), Color(1.0, 0.75, 0.2, 0.55))
		h.position = Vector3(0, 0, -0.004)
		body.add_child(h)
	var l := BowlingArt.label(it["text"], 0.036, Color(0.08, 0.05, 0.0) if selected else Color.WHITE, 0 if selected else 12)
	l.position = Vector3(0, 0, 0.006)
	body.add_child(l)
	return body


func _highlight(b: StaticBody3D, on: bool) -> void:
	var mesh := b.get_node("Fond") as MeshInstance3D
	var m := mesh.material_override as StandardMaterial3D
	m.albedo_color = Color(1.4, 1.4, 1.4, 1.0) if on else Color.WHITE
	b.scale = Vector3.ONE * (1.06 if on else 1.0)
	b.position.z = 0.012 if on else 0.0
