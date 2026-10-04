class_name TirGame
extends Node3D
## Groupe « Tir » : un écran de choix de discipline, puis la discipline choisie (une partie
## complète comme les autres jeux). Disciplines : tir à l'arc, carabine à plomb, ball-trap, lancer de couteau. Les prochaines s'ajoutent ici.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const DISCIPLINES := [
	{"id": "arc", "title": "Tir à l'arc", "script": "res://scripts/tir/arc.gd"},
	{"id": "carabine", "title": "Carabine à plomb", "script": "res://scripts/tir/carabine.gd"},
	{"id": "balltrap", "title": "Ball-trap", "script": "res://scripts/tir/balltrap.gd"},
	{"id": "couteau", "title": "Lancer de couteau", "script": "res://scripts/tir/couteau.gd"},
]

var _hands: Array = []
var _panel: UiPanel
var _child: Node = null
var _panel_was_visible := false
var _head := Transform3D.IDENTITY
var _placed := false
var _selftest := false


func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_panel = UiPanel.new()
	_panel.accent = Color(0.95, 0.35, 0.3)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)
	if not _selftest:
		show_choice()


func _exit_tree() -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = true


func place_in_front_of(head: Transform3D) -> void:
	_head = head
	_placed = true
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if _child:
		_child.place_in_front_of(head)
	elif _panel and _panel.visible:
		_panel.place_in_front_of(head)


func show_choice() -> void:
	if _child:
		_child.queue_free()
		_child = null
	_panel.clear()
	_panel.set_title("Tir", "Choisis ta discipline")
	for d in DISCIPLINES:
		_panel.add_row("", [{"id": "disc_" + String(d["id"]), "text": d["title"], "width": 0.42, "color": Color(0.7, 0.2, 0.15)}])
	_panel.add_row("", [{"id": "menu", "text": "Menu", "width": 0.2, "color": Color(0.35, 0.35, 0.4)}])
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	elif _placed:
		_panel.place_in_front_of(_head)
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = true


func start_discipline(id: String) -> void:
	for d in DISCIPLINES:
		if d["id"] == id:
			_panel.hide_panel()
			_child = load(String(d["script"])).new()
			if _child.has_method("set_hands"):
				_child.set_hands(_hands[0], _hands[1])
			_child.exit_requested.connect(_on_child_exit)
			_child.switch_requested.connect(func(): switch_requested.emit())
			add_child(_child)
			if _placed:
				_child.place_in_front_of(_head)
			return


func _on_child_exit() -> void:
	show_choice()


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("disc_"):
		start_discipline(id.substr(5))
	elif id == "menu":
		exit_requested.emit()


func suspend_panel() -> void:
	if _child:
		_child.suspend_panel()
		return
	_panel_was_visible = _panel.visible
	if _panel_was_visible:
		_panel.hide_panel()


func resume_panel() -> void:
	if _child:
		_child.resume_panel()
		return
	if _panel_was_visible:
		_panel.show_panel()
	_panel_was_visible = false


func _physics_process(_delta: float) -> void:
	if _child == null and _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)


func on_button_pressed(hand: Hand, button: String) -> void:
	if _child:
		_child.on_button_pressed(hand, button)
		return
	if _panel.visible and button == "trigger_click":
		var target := hand.pointed_object()
		if target:
			hand.buzz(0.3, 0.04)
			_panel.click(target)


func on_button_released(hand: Hand, button: String) -> void:
	if _child:
		_child.on_button_released(hand, button)


func enable_selftest() -> void:
	_selftest = true
	_run_selftest()


func _run_selftest() -> void:
	var all_ok := true
	for d in DISCIPLINES:
		var g = load(String(d["script"])).new()
		g.set_hands(_hands[0], _hands[1])
		add_child(g)
		g.enable_selftest()
		var ok: bool = await g.selftest_finished
		all_ok = all_ok and ok
		g.queue_free()
	print("SELFTEST tir=", "OK" if all_ok else "ECHEC")
	selftest_finished.emit(all_ok)
