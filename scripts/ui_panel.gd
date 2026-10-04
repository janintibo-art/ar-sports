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
	if _title != "":
		var t := BowlingArt.label(_title, 0.075)
		t.position = Vector3(0, y, 0.012)
		nodes.append(t)
		y -= 0.075
	if _subtitle != "":
		var s := BowlingArt.label(_subtitle, 0.04, Color(1, 0.92, 0.6))
		s.position = Vector3(0, y, 0.012)
		nodes.append(s)
		y -= 0.03 + 0.04 * _subtitle.count("\n")
	y -= 0.04
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
	_bg = BowlingArt.box(Vector3(width, height, 0.008), BowlingArt.unshaded(Color(0.06, 0.07, 0.1)))
	_bg.position = Vector3(0, -height / 2.0 + 0.07, -0.01)
	_root.add_child(_bg)
	var frame_mat := BowlingArt.unshaded(Color(0.95, 0.75, 0.25))
	_root.add_child(BowlingArt.box(Vector3(width, 0.006, 0.01), frame_mat, Vector3(0, 0.07, -0.008)))
	_root.add_child(BowlingArt.box(Vector3(width, 0.006, 0.01), frame_mat, Vector3(0, -height + 0.07, -0.008)))
	for n in nodes:
		_root.add_child(n)
	_root.position = Vector3(0, height / 2.0 - 0.07, 0)


func show_panel() -> void:
	visible = true
	for b in _buttons:
		b.collision_layer = 2


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
		base = Color(0.95, 0.65, 0.15)
	var mesh := BowlingArt.box(Vector3(w, BTN_H, 0.016), BowlingArt.unshaded(base))
	mesh.name = "Fond"
	body.add_child(mesh)
	body.set_meta("base_color", base)
	var l := BowlingArt.label(it["text"], 0.036, Color(0.08, 0.05, 0.0) if selected else Color.WHITE, 0 if selected else 12)
	l.position = Vector3(0, 0, 0.0095)
	body.add_child(l)
	return body


func _highlight(b: StaticBody3D, on: bool) -> void:
	var mesh := b.get_node("Fond") as MeshInstance3D
	var m := mesh.material_override as StandardMaterial3D
	var base: Color = b.get_meta("base_color")
	m.albedo_color = base.lightened(0.3) if on else base
	b.scale = Vector3.ONE * (1.05 if on else 1.0)
