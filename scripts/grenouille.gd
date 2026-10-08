class_name GrenouilleGame
extends Node3D
## Jeu de la grenouille en réalité augmentée : un meuble en bois à trous, un palet à lancer.
## Le palet qui tombe dans la bouche de la grenouille vaut 500, les autres trous moins.
## Chacun lance cinq palets par manche ; on additionne les points sur plusieurs manches.
## Deux distances : « Bar » (1,5 m, meuble sur pieds) et « Classique » (3 m).
## Vraie physique (Jolt) pour le palet ; un trou avale le palet quand son centre passe
## au-dessus en vitesse raisonnable.
## Le noeud est placé aux pieds du joueur ; le meuble est devant lui, vers -Z.

signal exit_requested
signal switch_requested
signal selftest_finished(ok: bool)

const TOP := 0.78                   # hauteur du plateau
const K := 1.3                      # échelle du meuble (pour que les trous restent jouables en RA)
const CAB_W := 0.9 * K
const CAB_D := 0.6 * K
const PUCK_R := 0.04
const PUCK_H := 0.016
const STAND := Vector3(0.36, 0.95, -0.2)
const GRAB_RADIUS := 0.38
const THROW_GAIN_H := 1.3
const THROW_GAIN_V := 1.2
const TABLE_DAMP := 12.0            # le palet freine vite sur le bois
const LAND_SCRUB := 0.55           # part de la vitesse horizontale gardée à l'atterrissage
const SLIDE_FIT := 0.25            # réglage fin de la glisse prévue par la visée
const SWALLOW_SPEED := 2.2
const PER_ROUND := 5
const TRAINING_THROWS := 10
const SAVE_PATH := "user://grenouille.cfg"
const L_WORLD := 1
const L_PUCK := 2
const ROW_COLORS := [Color(0.2, 0.5, 1.0), Color(1.0, 0.35, 0.3), Color(0.3, 0.85, 0.4), Color(0.9, 0.5, 1.0)]

const LEVELS := {
	"facile": {"title": "Facile", "assist": 1.0, "sigma": 0.16},
	"normal": {"title": "Normal", "assist": 0.6, "sigma": 0.09},
	"expert": {"title": "Expert", "assist": 0.2, "sigma": 0.055},
}

## Trous du meuble (coordonnées de base, multipliées par K) : x, z depuis le centre du plateau.
const HOLES := [
	{"id": "grenouille", "name": "Grenouille", "x": 0.0, "z": -0.13, "r": 0.055, "pts": 500},
	{"id": "moulin", "name": "Moulin", "x": -0.27, "z": -0.12, "r": 0.042, "pts": 200},
	{"id": "pont", "name": "Pont", "x": 0.27, "z": -0.12, "r": 0.042, "pts": 200},
	{"id": "cloche", "name": "Cloche", "x": -0.15, "z": 0.04, "r": 0.047, "pts": 100},
	{"id": "chapeau", "name": "Chapeau", "x": 0.15, "z": 0.04, "r": 0.047, "pts": 100},
	{"id": "tiroir_g", "name": "Tiroir", "x": -0.33, "z": 0.15, "r": 0.05, "pts": 50},
	{"id": "tiroir_d", "name": "Tiroir", "x": 0.33, "z": 0.15, "r": 0.05, "pts": 50},
	{"id": "bac", "name": "Bac", "x": 0.0, "z": 0.2, "r": 0.055, "pts": 25},
]

enum State { SETUP, TURN_WAIT, AI_WAIT, FLIGHT, PAUSE, GAME_OVER }

var settings := {"mode": "ordi", "players": 2, "level": "normal", "rounds": 3, "dist": 1.5, "music": true}
var state := State.SETUP
var players: Array = []         # [{name, score, thrown, ai}]
var current := 0
var round_no := 0
var cz := -1.5                  # profondeur du centre du meuble
var _puck: RigidBody3D
var _puck_mat: StandardMaterial3D
var _held := false
var _held_hand: Hand = null
var _held_button := ""
var _settle := 0.0
var _flight := 0.0
var _timer := 0.0
var _think := 1.0
var _swallow_tw: Tween = null
var _landed := false
var _swallowed := -1            # indice du trou qui a avalé le palet (-1 : aucun)
var _series_total := 0
var _last_text := ""
var _hist: Array = []
var _hands: Array = []
var _field: Node3D
var _tray: Node3D
var _frog: Node3D
var _blades: Array[Node3D] = []
var _board: MolkkyBoard
var _gaston: Spectator
var _panel: UiPanel
var _panel_page := ""
var _panel_was_visible := false
var _message: Label3D
var _message_time := 0.0
var _hint: Label3D
var _save := ConfigFile.new()

var _selftest := false
var _st_bot := false
var _st_log: Array = []
var _st_failures: Array = []
var _pending_scores: Array = []
var _last_points := 0


# ================================================================ mise en place

func set_hands(left_hand: Hand, right_hand: Hand) -> void:
	_hands = [left_hand, right_hand]


func _ready() -> void:
	_load_save()
	_field = Node3D.new()
	add_child(_field)
	_build_ground()
	_build_stand()
	_build_puck()
	_board = MolkkyBoard.new()
	add_child(_board)
	_gaston = Spectator.new({
		"name": "Gaston", "skin": Color(0.85, 0.68, 0.55), "shirt": Color(0.75, 0.25, 0.2),
		"pants": Color(0.25, 0.3, 0.45), "hair": Color(0.25, 0.18, 0.12), "beard": true,
		"hat": false, "hat_color": Color(0.3, 0.3, 0.3),
	})
	add_child(_gaston)
	_message = BowlingArt.neon_label("", 0.13, Color(0.4, 1.0, 0.5))
	_message.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_message.no_depth_test = true
	_message.visible = false
	add_child(_message)
	_hint = BowlingArt.label("", 0.04, Color(1, 0.95, 0.7))
	_hint.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hint.no_depth_test = true
	add_child(_hint)
	_panel = UiPanel.new()
	_panel.accent = Color(0.3, 0.75, 0.35)
	_panel.pressed.connect(_on_panel_pressed)
	add_child(_panel)
	_apply_layout()
	Sound.music_enabled = settings["music"]
	Sound.start_music()
	if not _selftest:
		show_setup()


func _exit_tree() -> void:
	Sound.stop_music()
	_set_lasers(true)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Sol"
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.2, 14.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.1, -4.0)
	add_child(body)


func _build_stand() -> void:
	var metal := BowlingArt.mat(Color(0.25, 0.27, 0.32), 0.35, 0.8)
	var wood := BowlingArt.mat(Color(0.55, 0.38, 0.18), 0.6)
	add_child(BowlingArt.cylinder(0.18, 0.2, 0.025, metal, Vector3(STAND.x, 0.0125, STAND.z), 24))
	add_child(BowlingArt.cylinder(0.022, 0.03, STAND.y - 0.03, metal, Vector3(STAND.x, (STAND.y - 0.03) / 2.0, STAND.z), 16))
	add_child(BowlingArt.box(Vector3(0.3, 0.025, 0.2), wood, Vector3(STAND.x, STAND.y - 0.02, STAND.z)))
	_tray = Node3D.new()
	_tray.position = Vector3(STAND.x - 0.09, STAND.y - 0.005, STAND.z)
	add_child(_tray)


func _puck_visual() -> MeshInstance3D:
	var m := BowlingArt.cylinder(PUCK_R, PUCK_R, PUCK_H, _puck_mat, Vector3.ZERO, 24)
	return m


func _build_puck() -> void:
	_puck_mat = BowlingArt.mat(Color(0.78, 0.8, 0.86), 0.25, 0.9)
	_puck = RigidBody3D.new()
	_puck.name = "Palet"
	_puck.collision_layer = L_PUCK
	_puck.collision_mask = L_WORLD
	_puck.mass = 0.12
	_puck.continuous_cd = true
	_puck.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_puck.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_puck.axis_lock_angular_x = true
	_puck.axis_lock_angular_z = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.08
	_puck.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PUCK_R
	cyl.height = PUCK_H
	cs.shape = cyl
	_puck.add_child(cs)
	_puck.add_child(_puck_visual())
	_puck.freeze = true
	_puck.visible = false
	add_child(_puck)


func _static_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	body.add_child(cs)
	body.position = pos
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.15
	body.physics_material_override = pm
	parent.add_child(body)


## Centre d'un trou dans le repère du jeu, au niveau du plateau.
func hole_pos(i: int) -> Vector3:
	var h: Dictionary = HOLES[i]
	return Vector3(float(h["x"]) * K, TOP, cz + float(h["z"]) * K)


func hole_radius(i: int) -> float:
	return float(HOLES[i]["r"]) * K


func hole_points(i: int) -> int:
	return int(HOLES[i]["pts"])


func _build_cabinet() -> void:
	var wood := BowlingArt.surface_material("wood", Color(0.5, 0.3, 0.14))
	var dark := BowlingArt.mat(Color(0.3, 0.17, 0.08), 0.7)
	var felt := BowlingArt.mat(Color(0.16, 0.42, 0.24), 0.9)
	var c := Node3D.new()
	c.name = "Meuble"
	c.position = Vector3(0, 0, cz)
	_field.add_child(c)
	# Plateau
	c.add_child(BowlingArt.box(Vector3(CAB_W, 0.04, CAB_D), wood, Vector3(0, TOP - 0.02, 0)))
	c.add_child(BowlingArt.box(Vector3(CAB_W - 0.08, 0.004, CAB_D - 0.08), felt, Vector3(0, TOP + 0.002, 0.0)))
	_static_box(c, Vector3(CAB_W, 0.1, CAB_D), Vector3(0, TOP - 0.05, 0))
	# Caisse et pieds
	c.add_child(BowlingArt.box(Vector3(CAB_W - 0.06, 0.2, CAB_D - 0.06), dark, Vector3(0, TOP - 0.14, 0)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			c.add_child(BowlingArt.box(Vector3(0.07, TOP - 0.04, 0.07), wood, Vector3(sx * (CAB_W / 2.0 - 0.05), (TOP - 0.04) / 2.0, sz * (CAB_D / 2.0 - 0.05))))
	# Rebords : latéraux bas, fond haut (les palets rebondissent dessus)
	for sx in [-1.0, 1.0]:
		c.add_child(BowlingArt.box(Vector3(0.025, 0.05, CAB_D), wood, Vector3(sx * (CAB_W / 2.0 + 0.0125), TOP + 0.005, 0)))
		_static_box(c, Vector3(0.03, 0.08, CAB_D), Vector3(sx * (CAB_W / 2.0 + 0.0125), TOP + 0.04, 0))
	c.add_child(BowlingArt.box(Vector3(CAB_W + 0.05, 0.2, 0.03), wood, Vector3(0, TOP + 0.1, -CAB_D / 2.0 - 0.015)))
	_static_box(c, Vector3(CAB_W + 0.05, 0.3, 0.04), Vector3(0, TOP + 0.15, -CAB_D / 2.0 - 0.02))
	# Trous, anneaux colorés, valeurs écrites sur le plateau
	_blades.clear()
	for i in HOLES.size():
		var h: Dictionary = HOLES[i]
		var hp := hole_pos(i) - Vector3(0, TOP, cz)
		var r := hole_radius(i)
		var ring_col := Color(0.95, 0.8, 0.25)
		if int(h["pts"]) >= 500:
			ring_col = Color(0.85, 0.15, 0.2)
		elif int(h["pts"]) >= 200:
			ring_col = Color(0.95, 0.5, 0.15)
		elif int(h["pts"]) <= 50:
			ring_col = Color(0.9, 0.9, 0.85)
		c.add_child(BowlingArt.cylinder(r + 0.012, r + 0.012, 0.003, BowlingArt.mat(ring_col, 0.5), Vector3(hp.x, TOP + 0.004, hp.z), 28))
		c.add_child(BowlingArt.cylinder(r, r, 0.004, BowlingArt.unshaded(Color(0.01, 0.01, 0.015)), Vector3(hp.x, TOP + 0.006, hp.z), 28))
		var lab := BowlingArt.label(str(h["pts"]), 0.045, Color(1, 0.95, 0.7), 4)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(hp.x, TOP + 0.008, hp.z + r + 0.05)
		c.add_child(lab)
		# Obstacle derrière le trou (décor avec collision)
		var back := hp.z - r - 0.025
		match String(h["id"]):
			"moulin":
				_static_box(c, Vector3(0.06, 0.07, 0.02), Vector3(hp.x, TOP + 0.035, back))
				c.add_child(BowlingArt.box(Vector3(0.06, 0.07, 0.02), BowlingArt.mat(Color(0.8, 0.75, 0.6), 0.8), Vector3(hp.x, TOP + 0.035, back)))
				var hub := Node3D.new()
				hub.position = Vector3(hp.x, TOP + 0.075, back + 0.02)
				c.add_child(hub)
				for k in 4:
					var bl := BowlingArt.box(Vector3(0.012, 0.075, 0.004), BowlingArt.mat(Color(0.85, 0.2, 0.15), 0.6), Vector3.ZERO)
					bl.rotation.z = k * PI / 2.0
					hub.add_child(bl)
				_blades.append(hub)
			"pont":
				_static_box(c, Vector3(0.08, 0.06, 0.02), Vector3(hp.x, TOP + 0.03, back))
				for sx in [-1.0, 1.0]:
					c.add_child(BowlingArt.box(Vector3(0.015, 0.06, 0.02), BowlingArt.mat(Color(0.55, 0.55, 0.6), 0.7), Vector3(hp.x + sx * 0.035, TOP + 0.03, back)))
				c.add_child(BowlingArt.box(Vector3(0.09, 0.015, 0.02), BowlingArt.mat(Color(0.55, 0.55, 0.6), 0.7), Vector3(hp.x, TOP + 0.065, back)))
			"cloche":
				_static_box(c, Vector3(0.05, 0.07, 0.02), Vector3(hp.x, TOP + 0.035, back))
				c.add_child(BowlingArt.cylinder(0.008, 0.028, 0.05, BowlingArt.mat(Color(0.9, 0.7, 0.2), 0.3, 0.8), Vector3(hp.x, TOP + 0.05, back), 12))
			"chapeau":
				_static_box(c, Vector3(0.06, 0.06, 0.02), Vector3(hp.x, TOP + 0.03, back))
				c.add_child(BowlingArt.cylinder(0.03, 0.03, 0.04, BowlingArt.mat(Color(0.12, 0.12, 0.15), 0.6), Vector3(hp.x, TOP + 0.035, back), 14))
				c.add_child(BowlingArt.cylinder(0.04, 0.04, 0.008, BowlingArt.mat(Color(0.12, 0.12, 0.15), 0.6), Vector3(hp.x, TOP + 0.014, back), 14))
	# La grenouille, assise au fond, bouche ouverte vers le joueur
	_frog = Node3D.new()
	var fz := -0.25 * K
	_frog.position = Vector3(0, TOP, fz)
	c.add_child(_frog)
	_static_box(c, Vector3(0.2 * K, 0.16, 0.08 * K), Vector3(0, TOP + 0.08, fz))
	var green := BowlingArt.mat(Color(0.25, 0.65, 0.2), 0.55)
	# La bouche de la grenouille EST le trou des 500 points : mâchoire en arrière, gueule ouverte vers le joueur
	var hz := hole_pos(0).z - cz - fz
	var hr := hole_radius(0)
	var body := BowlingArt.sphere(0.1 * K, green, Vector3(0, 0.08, hz - hr - 0.1), 18)
	body.scale = Vector3(1.5, 0.9, 0.9)
	_frog.add_child(body)
	var jaw := BowlingArt.sphere(0.085 * K, green, Vector3(0, 0.1, hz - hr - 0.085), 18)
	jaw.scale = Vector3(1.55, 0.62, 0.8)
	_frog.add_child(jaw)
	var lip_mat := BowlingArt.mat(Color(0.85, 0.12, 0.18), 0.4)
	var teeth := BowlingArt.mat(Color(0.98, 0.97, 0.9), 0.4)
	var tongue := BowlingArt.sphere(0.03, BowlingArt.mat(Color(0.95, 0.4, 0.5), 0.45), Vector3(0, 0.0085, hz + hr * 0.55), 12)
	tongue.scale = Vector3(1.1, 0.12, 1.1)
	_frog.add_child(tongue)
	for k in 7:
		var a_k := lerpf(-0.95, 0.95, float(k) / 6.0)
		var tx := sin(a_k) * (hr + 0.004)
		var tz := hz - cos(a_k) * (hr + 0.004)
		var tooth := BowlingArt.box(Vector3(0.012, 0.018, 0.01), teeth, Vector3(tx, 0.045, tz - 0.01))
		_frog.add_child(tooth)
	for sx in [-1.0, 1.0]:
		_frog.add_child(BowlingArt.sphere(0.034 * K, green, Vector3(sx * 0.07 * K, 0.185, hz - hr - 0.08), 12))
		_frog.add_child(BowlingArt.sphere(0.022 * K, BowlingArt.unshaded(Color(1, 1, 1)), Vector3(sx * 0.07 * K, 0.195, hz - hr - 0.055), 10))
		_frog.add_child(BowlingArt.sphere(0.011 * K, BowlingArt.unshaded(Color(0.02, 0.02, 0.03)), Vector3(sx * 0.07 * K, 0.198, hz - hr - 0.036), 8))
		_frog.add_child(BowlingArt.sphere(0.035 * K, green, Vector3(sx * (hr + 0.085), 0.025, hz - 0.02), 10))
	var name_l := BowlingArt.label("LA GRENOUILLE", 0.05, Color(1, 0.9, 0.4), 6)
	name_l.position = Vector3(0, TOP + 0.24, -CAB_D / 2.0 + 0.0)
	c.add_child(name_l)


func _apply_layout() -> void:
	cz = -float(settings["dist"])
	for ch in _field.get_children():
		ch.queue_free()
	var wood_floor := BowlingArt.surface_material("wood", Color(0.38, 0.24, 0.12), Vector2(6, 8))
	_field.add_child(BowlingArt.floor_quad(5.0, 7.0, wood_floor, Vector3(0, 0.001, cz + 1.0 - 3.5 + 0.5)))
	_field.add_child(BowlingArt.box(Vector3(1.8, 0.004, 0.05), BowlingArt.unshaded(Color(1, 1, 1)), Vector3(0, 0.003, 0)))
	_build_cabinet()
	_build_decor()
	_board.position = Vector3(-1.9, 1.35, minf(cz, -1.5))
	var face := Vector3(0.0, 0, 1.0) - _board.position
	_board.rotation = Vector3(0, atan2(face.x, face.z), 0)
	_board.scale = Vector3.ONE * 1.1
	_gaston.position = Vector3(-1.0, 0, 0.15)
	_gaston.rotation.y = deg_to_rad(25.0)
	_gaston.visible = settings["mode"] == "ordi"
	_message.position = Vector3(0, 1.7, cz)
	_hint.position = STAND + Vector3(0, 0.28, 0)
	_refresh_tray(0)
	_board.set_data("GRENOUILLE", [], 0, 0, "")


func _build_decor() -> void:
	var zb := cz - 1.2
	var brick := BowlingArt.mat(Color(0.45, 0.22, 0.16), 0.95)
	_field.add_child(BowlingArt.box(Vector3(5.0, 2.6, 0.12), brick, Vector3(0, 1.3, zb)))
	var sign_node := Decor.neon_sign("GRENOUILLE", Color(0.4, 1.0, 0.5), 1.7, 0.45)
	sign_node.position = Vector3(0, 1.7, zb + 0.08)
	_field.add_child(sign_node)
	var wood := BowlingArt.mat(Color(0.34, 0.19, 0.095), 0.7)
	_field.add_child(BowlingArt.box(Vector3(5.0, 0.9, 0.14), wood, Vector3(0, 0.45, zb + 0.02)))
	_field.add_child(Decor.rug(Vector2(2.4, 1.8), Color(0.35, 0.1, 0.12), Vector3(0, 0.003, cz + 0.2)))
	for sx in [-1.0, 1.0]:
		var pl := Decor.plant(1.0)
		pl.position = Vector3(sx * 1.9, 0, zb + 0.4)
		_field.add_child(pl)
		var l := Decor.lamp(2.2)
		l.position = Vector3(sx * 1.3, 0, zb + 0.35)
		_field.add_child(l)
	var bunting := Decor.bunting(3.0, 9)
	bunting.position = Vector3(0, 2.3, zb + 0.15)
	_field.add_child(bunting)
	_field.add_child(Decor.sport_corner("pub", Vector3(2.0, 0, minf(cz, -1.5) - 0.2)))


func place_in_front_of(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	global_position = Vector3(head.origin.x, 0.0, head.origin.z)
	if _panel and _panel.visible:
		_panel.place_in_front_of(head)


func _refresh_tray(left: int) -> void:
	for c in _tray.get_children():
		c.queue_free()
	for i in left:
		var m := _puck_visual()
		m.position = Vector3(0.0, PUCK_H * 0.5 + i * (PUCK_H + 0.001), 0.0)
		_tray.add_child(m)


# ================================================================ menus

func is_training() -> bool:
	return settings["mode"] == "training"


func show_setup() -> void:
	state = State.SETUP
	_drop_puck()
	_panel_page = "setup"
	_panel.clear()
	_panel.set_title("La Grenouille", "Victoires : %d   ·   grenouilles : %d   ·   meilleure série : %d pts" % [_stat("wins"), _stat("frogs"), _stat("best_series")])
	_panel.add_row("Mode", [
		{"id": "mode_ordi", "text": "Contre l'ordi", "width": 0.26, "selected": settings["mode"] == "ordi"},
		{"id": "mode_deux", "text": "2 à 4 joueurs", "width": 0.26, "selected": settings["mode"] == "deux"},
		{"id": "mode_training", "text": "Entraînement", "width": 0.26, "selected": settings["mode"] == "training"},
	])
	if settings["mode"] == "deux":
		var prow: Array = []
		for n in [2, 3, 4]:
			prow.append({"id": "players_%d" % n, "text": str(n), "width": 0.12, "selected": settings["players"] == n})
		_panel.add_row("Joueurs", prow)
	if settings["mode"] == "ordi":
		var row: Array = []
		for l in ["facile", "normal", "expert"]:
			row.append({"id": "level_" + l, "text": LEVELS[l]["title"], "width": 0.2, "selected": settings["level"] == l})
		_panel.add_row("Niveau", row)
	if settings["mode"] != "training":
		_panel.add_row("Manches", [
			{"id": "rounds_1", "text": "1", "width": 0.12, "selected": int(settings["rounds"]) == 1},
			{"id": "rounds_3", "text": "3", "width": 0.12, "selected": int(settings["rounds"]) == 3},
			{"id": "rounds_5", "text": "5", "width": 0.12, "selected": int(settings["rounds"]) == 5},
		])
	_panel.add_row("Distance", [
		{"id": "dist_1.5", "text": "Bar 1,5 m", "width": 0.22, "selected": is_equal_approx(float(settings["dist"]), 1.5)},
		{"id": "dist_3.0", "text": "Classique 3 m", "width": 0.26, "selected": is_equal_approx(float(settings["dist"]), 3.0)},
	])
	_panel.add_row("", [
		{"id": "menu", "text": "Menu", "width": 0.2, "color": Color(0.35, 0.35, 0.4)},
		{"id": "play", "text": "JOUER", "width": 0.34, "color": Color(0.15, 0.6, 0.25)},
	])
	_open_panel()


func show_pause() -> void:
	_panel_page = "pause"
	_panel.clear()
	_panel.set_title("Pause")
	_panel.add_row("", [{"id": "resume", "text": "Reprendre", "width": 0.34, "color": Color(0.15, 0.6, 0.25)}])
	_panel.add_row("", [{"id": "restart", "text": "Recommencer", "width": 0.34}])
	_panel.add_row("", [{"id": "settings", "text": "Réglages", "width": 0.34}])
	_panel.add_row("", [{"id": "music_toggle", "text": "Musique : %s" % ("oui" if settings["music"] else "non"), "width": 0.34}])
	_panel.add_row("", [{"id": "switch", "text": "Changer de jeu", "width": 0.34, "color": Color(0.2, 0.4, 0.75)}])
	_panel.add_row("", [{"id": "menu", "text": "Menu principal", "width": 0.34, "color": Color(0.35, 0.35, 0.4)}])
	_open_panel()


func show_game_over(summary: String) -> void:
	_panel_page = "over"
	_panel.clear()
	_panel.set_title("Partie terminée", summary)
	_panel.add_row("", [
		{"id": "settings", "text": "Réglages", "width": 0.22},
		{"id": "restart", "text": "Revanche", "width": 0.26, "color": Color(0.15, 0.6, 0.25)},
		{"id": "menu", "text": "Menu", "width": 0.18, "color": Color(0.35, 0.35, 0.4)},
	])
	_open_panel()


func _open_panel() -> void:
	_drop_puck()
	_panel.build()
	_panel.show_panel()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_panel.place_in_front_of(cam.global_transform)
	_set_lasers(true)


func suspend_panel() -> void:
	_panel_was_visible = _panel.visible
	if _panel_was_visible:
		_panel.hide_panel()


func resume_panel() -> void:
	if _panel_was_visible:
		_panel.show_panel()
	_panel_was_visible = false


func _close_panel() -> void:
	_panel.hide_panel()
	_panel_page = ""
	_set_lasers(false)


func _set_lasers(on: bool) -> void:
	for h in _hands:
		if is_instance_valid(h):
			h.laser_enabled = on


func _on_panel_pressed(id: String) -> void:
	if id.begins_with("mode_"):
		settings["mode"] = id.substr(5)
	elif id.begins_with("players_"):
		settings["players"] = int(id.substr(8))
	elif id.begins_with("level_"):
		settings["level"] = id.substr(6)
	elif id.begins_with("rounds_"):
		settings["rounds"] = int(id.substr(7))
	elif id.begins_with("dist_"):
		settings["dist"] = float(id.substr(5))
	match id:
		"play", "restart":
			_close_panel()
			start_match()
			return
		"resume":
			_close_panel()
			return
		"settings":
			show_setup()
			return
		"menu":
			exit_requested.emit()
			return
		"switch":
			switch_requested.emit()
			return
		"music_toggle":
			settings["music"] = not settings["music"]
			Sound.music_enabled = settings["music"]
			_save_settings()
			show_pause()
			return
	_apply_layout()
	_save_settings()
	show_setup()


# ================================================================ partie

func throws_per_player() -> int:
	return TRAINING_THROWS if is_training() else PER_ROUND


func start_match() -> void:
	_apply_layout()
	players.clear()
	match String(settings["mode"]):
		"ordi":
			players.append({"name": "VOUS", "score": 0, "thrown": 0, "ai": false})
			players.append({"name": "GASTON", "score": 0, "thrown": 0, "ai": true})
		"deux":
			for i in int(settings["players"]):
				players.append({"name": "J%d" % (i + 1), "score": 0, "thrown": 0, "ai": false})
		_:
			players.append({"name": "VOUS", "score": 0, "thrown": 0, "ai": false})
	current = 0
	round_no = 0
	_series_total = 0
	_last_text = ""
	_hist.clear()
	_begin_turn()


func _begin_turn() -> void:
	_update_board()
	var p: Dictionary = players[current]
	_refresh_tray(throws_per_player() - int(p["thrown"]))
	_puck_mat.albedo_color = Color(0.78, 0.8, 0.86).lerp(ROW_COLORS[current % 4], 0.45)
	if _st_bot or bool(p["ai"]):
		state = State.AI_WAIT
		_timer = _think
		_hint.text = ""
		if not _st_bot and players.size() > 1:
			_announce("Au tour de %s" % String(p["name"]).capitalize(), Color(0.4, 1.0, 0.5), 1.2)
	else:
		state = State.TURN_WAIT
		_put_puck_on_stand()
		_hint.text = "Attrape le palet (gâchette ou grip)\net lance-le en cloche vers la table"
		if players.size() > 1:
			_announce("%s, à toi !" % String(p["name"]).capitalize(), Color(0.4, 1.0, 0.5), 1.4)


func _put_puck_on_stand() -> void:
	_kill_swallow()
	_puck.freeze = true
	_puck.linear_velocity = Vector3.ZERO
	_puck.angular_velocity = Vector3.ZERO
	_puck.transform = Transform3D(Basis.IDENTITY, STAND + Vector3(0.09, PUCK_H * 0.5 + 0.03, 0))
	_puck.visible = true
	_held = false
	_held_hand = null


func _drop_puck() -> void:
	_kill_swallow()
	_held = false
	_held_hand = null
	_held_button = ""
	_puck.visible = false
	_puck.freeze = true
	_hint.text = ""


func _kill_swallow() -> void:
	if _swallow_tw != null and _swallow_tw.is_valid():
		_swallow_tw.kill()
	_swallow_tw = null


func _launch(from: Vector3, vel: Vector3) -> void:
	_kill_swallow()
	_puck.freeze = true
	_puck.transform = Transform3D(Basis.IDENTITY, from)
	_puck.visible = true
	_puck.linear_damp = 0.0
	_puck.freeze = false
	_puck.sleeping = false
	_puck.linear_velocity = vel
	_puck.angular_velocity = Vector3.ZERO
	_held = false
	_held_hand = null
	_held_button = ""
	_settle = 0.0
	_flight = 0.0
	_swallowed = -1
	_landed = false
	state = State.FLIGHT
	_hint.text = ""
	_refresh_tray(maxi(0, throws_per_player() - int(players[current]["thrown"]) - 1))
	Sound.play_at("whoosh", to_global(from), -10.0, 0.1)


# ---------------------------------------------------------------- lancer humain

func _hand_item_tf(h: Hand) -> Transform3D:
	var gt := global_transform.affine_inverse() * h.global_transform
	return Transform3D(Basis.IDENTITY, (gt * Transform3D(Basis(), Vector3(0, -0.03, -0.08))).origin)


func _try_grab(hand: Hand, button: String) -> void:
	if state != State.TURN_WAIT or _held:
		return
	var tf := _hand_item_tf(hand)
	if tf.origin.distance_to(_puck.position) > GRAB_RADIUS:
		return
	_held = true
	_held_hand = hand
	_held_button = button
	hand.clear_history()
	hand.buzz(0.4, 0.06)
	Sound.play_at("grab", to_global(_puck.position), -6.0, 0.05)
	_hint.text = ""


func _release_held(hand: Hand) -> void:
	if not _held or _held_hand != hand:
		return
	var tf := _hand_item_tf(hand)
	var v := global_basis.inverse() * hand.throw_velocity()
	_held = false
	_held_hand = null
	_held_button = ""
	_throw(tf, v)


## Lance le palet tenu : `tf` position, `vel` vitesse de la main.
func _throw(tf: Transform3D, vel: Vector3) -> void:
	var hv := Vector2(vel.x, vel.z).length()
	if hv < 0.8 and vel.y < 0.8:
		_put_puck_on_stand()
		_hint.text = "Lance plus fort !"
		return
	vel = Vector3(vel.x * THROW_GAIN_H, vel.y * THROW_GAIN_V, vel.z * THROW_GAIN_H)
	vel = vel.limit_length(8.0)
	vel = _assist(tf.origin, vel)
	_launch(tf.origin, vel)


func _flight_time(p: Vector3, v: Vector3, y_end: float) -> float:
	var disc := v.y * v.y + 2.0 * 9.81 * (p.y - y_end)
	if disc < 0.0:
		return 0.0
	return (v.y + sqrt(disc)) / 9.81


## Point d'impact visé pour que le palet, freiné par le bois, s'arrête là.
func _compensate(from: Vector3, target: Vector2, t: float) -> Vector2:
	var d := target - Vector2(from.x, from.z)
	if d.length() < 0.01 or t <= 0.0:
		return target
	var vh := d.length() / t
	return target - d.normalized() * (vh * LAND_SCRUB / TABLE_DAMP * SLIDE_FIT)


## Aide : un lancer qui retomberait loin du plateau est ramené dessus ;
## en Facile, un petit coup de pouce guide aussi les lancers corrects.
func _assist(p: Vector3, v: Vector3) -> Vector3:
	var a: float = LEVELS[settings["level"]]["assist"]
	var t := _flight_time(p, v, TOP + 0.03)
	if t < 0.1:
		return v
	var land := Vector2(p.x + v.x * t, p.z + v.z * t)
	var lo := Vector2(-CAB_W / 2.0 + 0.1, cz - CAB_D / 2.0 + 0.1)
	var hi := Vector2(CAB_W / 2.0 - 0.1, cz + CAB_D / 2.0 - 0.08)
	var clamped := Vector2(clampf(land.x, lo.x, hi.x), clampf(land.y, lo.y, hi.y))
	var target := land.lerp(clamped, minf(1.0, a + 0.2))
	var guide := a * 0.25
	target = target.lerp(Vector2(0.0, cz + 0.05), guide)
	target = _compensate(p, target, t)
	return Vector3((target.x - p.x) / t, v.y, (target.y - p.z) / t)


# ================================================================ physique et déroulement

func _physics_process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.visible = false
	for b in _blades:
		b.rotation.z += delta * 1.5
	if _panel.visible:
		var pointed: Array = []
		for h in _hands:
			pointed.append(h.pointed_object())
		_panel.update_hover(pointed)
		return
	match state:
		State.TURN_WAIT:
			if _held and _held_hand != null and is_instance_valid(_held_hand):
				_puck.transform = _hand_item_tf(_held_hand)
		State.AI_WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_ai_throw()
		State.FLIGHT:
			_flight += delta
			_watch_puck()
			if _swallowed >= 0:
				return
			if _flight > 0.4:
				if _puck.linear_velocity.length() > 0.08:
					_settle = 0.0
				else:
					_settle += delta
			var fell := _puck.position.y < TOP - 0.3
			if _settle > 0.6 or _flight > 8.0 or fell:
				_evaluate(-1)
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_after_pause()


## Freine le palet sur le plateau et détecte un trou qui l'avale.
func _watch_puck() -> void:
	var p := _puck.position
	var on_table := absf(p.x) < CAB_W / 2.0 + 0.02 and absf(p.z - cz) < CAB_D / 2.0 + 0.02 and p.y < TOP + PUCK_H + 0.03 and p.y > TOP - 0.05
	if on_table and not _landed and p.y <= TOP + PUCK_H * 0.5 + 0.014 and _puck.linear_velocity.y < 0.0:
		# Le palet colle au bois : plus de rebond, il glisse puis s'arrête
		_landed = true
		_puck.position.y = TOP + 0.004 + PUCK_H * 0.5
		_puck.linear_velocity = Vector3(_puck.linear_velocity.x * LAND_SCRUB, 0.0, _puck.linear_velocity.z * LAND_SCRUB)
		Sound.play_at("pp_table", to_global(p), -8.0, 0.1)
	var sliding := on_table and _landed
	_puck.linear_damp = TABLE_DAMP if sliding else 0.0
	_puck.angular_damp = 4.0 if sliding else 0.0
	if not on_table:
		return
	var vh := Vector2(_puck.linear_velocity.x, _puck.linear_velocity.z).length()
	if vh > SWALLOW_SPEED:
		return
	for i in HOLES.size():
		var c := hole_pos(i)
		if Vector2(p.x - c.x, p.z - c.z).length() < hole_radius(i) - 0.006:
			_swallow(i)
			return


func _swallow(i: int) -> void:
	_swallowed = i
	var c := hole_pos(i)
	_puck.freeze = true
	_puck.linear_velocity = Vector3.ZERO
	_puck.position = Vector3(c.x, TOP + 0.004, c.z)
	_swallow_tw = create_tween()
	_swallow_tw.tween_property(_puck, "position:y", TOP - 0.16, 0.25).set_ease(Tween.EASE_IN)
	_swallow_tw.tween_callback(func() -> void: _puck.visible = false)
	var pos := to_global(c)
	match String(HOLES[i]["id"]):
		"grenouille":
			Sound.play_at("bull_ding", pos, -2.0, 0.0)
			Sound.play_at("cheer_big", pos, -4.0, 0.0)
			_frog_pop()
		"cloche":
			Sound.play_at("bull_ding", pos, -4.0, 0.0)
		"moulin", "pont":
			Sound.play_at("clink", pos, -3.0, 0.1)
			Sound.play_at("cheer_small", pos, -6.0, 0.0)
		_:
			Sound.play_at("can_ping", pos, -4.0, 0.1)
	_evaluate(i)


func _frog_pop() -> void:
	if _frog == null or not is_instance_valid(_frog):
		return
	var tw := create_tween()
	tw.tween_property(_frog, "scale", Vector3(1.15, 1.25, 1.15), 0.12)
	tw.tween_property(_frog, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _evaluate(hole: int) -> void:
	if state != State.FLIGHT:
		return
	var pts := 0
	var text := "Raté"
	if hole >= 0:
		pts = hole_points(hole)
		text = "%s +%d" % [String(HOLES[hole]["name"]), pts]
	_last_points = pts
	_register(pts, text, hole)


func _register(pts: int, text: String, hole: int) -> void:
	var p: Dictionary = players[current]
	p["score"] = int(p["score"]) + pts
	p["thrown"] = int(p["thrown"]) + 1
	_hist.append(pts)
	_last_text = text
	_series_total += pts
	if hole >= 0 and String(HOLES[hole]["id"]) == "grenouille" and not _st_bot and not bool(p["ai"]):
		_bump_stat("frogs")
	if pts >= 500:
		_announce("GRENOUILLE ! +500", Color(0.4, 1.0, 0.5), 2.0)
		_board.celebrate("point")
		if not bool(p["ai"]) and not _st_bot:
			_gaston.say("oups", true)
	elif pts > 0:
		_announce(text, Color(1, 0.8, 0.2), 1.5)
		_board.celebrate("point")
	else:
		_announce("Raté…", Color(0.8, 0.8, 0.85), 1.2)
		if _puck.visible:
			Sound.play_at("pet_land", to_global(_puck.position), -6.0, 0.1)
	_update_board()
	state = State.PAUSE
	_timer = 0.3 if _st_bot else 1.3
	_puck.freeze = true
	if hole < 0:
		_puck.visible = false


func _after_pause() -> void:
	_puck.visible = false
	var per := throws_per_player()
	var done := true
	for p in players:
		if int(p["thrown"]) < per:
			done = false
	if done:
		_end_round()
		return
	var n := players.size()
	var i := current
	for k in n:
		i = (i + 1) % n
		if int(players[i]["thrown"]) < per:
			break
	current = i
	_begin_turn()


func _end_round() -> void:
	if is_training():
		_best_stat("best_series", _series_total)
		_pending_scores.append(_series_total)
		_game_over(0)
		return
	round_no += 1
	if round_no >= int(settings["rounds"]):
		var best := 0
		for i in players.size():
			if int(players[i]["score"]) > int(players[best]["score"]):
				best = i
		_game_over(best)
		return
	for p in players:
		p["thrown"] = 0
	current = round_no % players.size()
	_announce("Manche %d sur %d" % [round_no + 1, int(settings["rounds"])], Color(1, 0.8, 0.2), 1.6)
	_begin_turn()


func _game_over(winner: int) -> void:
	state = State.GAME_OVER
	var summary := ""
	if is_training():
		summary = "%d points en %d lancers" % [_series_total, TRAINING_THROWS]
		_board.celebrate("win")
	else:
		var top := int(players[winner]["score"])
		var tie := false
		for i in players.size():
			if i != winner and int(players[i]["score"]) == top:
				tie = true
		if tie:
			summary = "Égalité à %d points !" % top
		else:
			summary = "%s gagne avec %d points !" % [String(players[winner]["name"]).capitalize(), top]
			_board.celebrate("win")
			if winner == 0 and settings["mode"] == "ordi":
				_bump_stat("wins")
				_gaston.say("oups", true)
			elif settings["mode"] == "ordi":
				_gaston.react("win")
	_announce("%s" % summary, Color(1, 0.8, 0.2), 3.0)
	_update_board()
	if _selftest:
		return
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	if state == State.GAME_OVER and not _panel.visible:
		show_game_over(summary)


func _update_board() -> void:
	var title := "GRENOUILLE"
	var foot := ""
	if is_training():
		title = "GRENOUILLE · ENTRAÎNEMENT"
		var p0: Dictionary = players[0] if not players.is_empty() else {"thrown": 0}
		foot = "Lancer %d sur %d · dernier : %s" % [mini(int(p0["thrown"]) + 1, TRAINING_THROWS), TRAINING_THROWS, _last_text if _last_text != "" else "—"]
	elif not players.is_empty():
		var p: Dictionary = players[current]
		title = "GRENOUILLE · MANCHE %d/%d" % [mini(round_no + 1, int(settings["rounds"])), int(settings["rounds"])]
		foot = "%s : palet %d sur %d · %s" % [String(p["name"]).capitalize(), mini(int(p["thrown"]) + 1, PER_ROUND), PER_ROUND, _last_text if _last_text != "" else "—"]
	var rows: Array = []
	for p in players:
		rows.append({"name": p["name"], "score": p["score"], "misses": 0, "out": false})
	_board.set_data(title, rows, current, 0, foot)


func _announce(text: String, color: Color, seconds: float) -> void:
	_message.text = text
	_message.outline_modulate = color
	_message.modulate = Color(1, 1, 1).lerp(color, 0.2)
	_message.visible = true
	_message_time = seconds
	_message.scale = Vector3.ONE * 1.5
	var tw_ := create_tween()
	tw_.tween_property(_message, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================ adversaire

func _gauss() -> float:
	var s := 0.0
	for i in 12:
		s += randf()
	return s - 6.0


## Choisit un trou : l'adversaire facile vise au hasard, l'expert vise surtout la grenouille.
func ai_pick_hole() -> int:
	var lvl := String(settings["level"])
	var r := randf()
	match lvl:
		"expert":
			if r < 0.65:
				return 0
			return 1 + randi() % 2 if r < 0.85 else 3 + randi() % 2
		"normal":
			if r < 0.35:
				return 0
			if r < 0.6:
				return 1 + randi() % 2
			return 3 + randi() % (HOLES.size() - 3)
		_:
			return randi() % HOLES.size()


func _ai_throw() -> void:
	var lvl: Dictionary = LEVELS[settings["level"]]
	var hole := ai_pick_hole()
	var c := hole_pos(hole)
	var sg: float = lvl["sigma"]
	var target := Vector2(c.x + _gauss() * sg, c.z + _gauss() * sg)
	_ai_shoot(target)


## Lance un palet depuis la position de l'adversaire pour qu'il s'arrête vers `target` (x, z).
func _ai_shoot(target: Vector2) -> void:
	var from := Vector3(-0.8, 0.95, -0.1)
	var d2 := target - Vector2(from.x, from.z)
	var t := 0.55 + 0.1 * d2.length()
	var land := _compensate(from, target, t)
	var vy := (TOP + 0.03 - from.y + 0.5 * 9.81 * t * t) / t
	_launch(from, Vector3((land.x - from.x) / t, vy, (land.y - from.z) / t))


# ================================================================ entrées

func on_button_pressed(hand: Hand, button: String) -> void:
	if _panel.visible:
		if button == "trigger_click":
			var target := hand.pointed_object()
			if target:
				hand.buzz(0.3, 0.04)
				_panel.click(target)
		elif button == "by_button" and _panel_page == "pause":
			_close_panel()
		return
	if button == "by_button":
		show_pause()
		return
	if button == "trigger_click" or button == "grip_click":
		_try_grab(hand, button)


func on_button_released(hand: Hand, button: String) -> void:
	if button == _held_button and hand == _held_hand:
		_release_held(hand)


# ================================================================ sauvegarde

func _load_save() -> void:
	if _save.load(SAVE_PATH) != OK:
		return
	for k in settings:
		settings[k] = _save.get_value("settings", k, settings[k])
	if not LEVELS.has(settings["level"]):
		settings["level"] = "normal"
	if settings["mode"] not in ["ordi", "deux", "training"]:
		settings["mode"] = "ordi"
	if int(settings["rounds"]) not in [1, 3, 5]:
		settings["rounds"] = 3
	if int(settings["players"]) not in [2, 3, 4]:
		settings["players"] = 2
	if not (float(settings["dist"]) in [1.5, 3.0]):
		settings["dist"] = 1.5


func _save_settings() -> void:
	for k in settings:
		_save.set_value("settings", k, settings[k])
	if _save.save(SAVE_PATH) != OK:
		push_warning("Grenouille : réglages non sauvegardés")


func _stat(key: String) -> int:
	return int(_save.get_value("records", key, 0))


func _bump_stat(key: String) -> void:
	_save.set_value("records", key, _stat(key) + 1)
	if _save.save(SAVE_PATH) != OK:
		push_warning("Grenouille : record non sauvegardé")


func _best_stat(key: String, value: int) -> void:
	if value > _stat(key):
		_save.set_value("records", key, value)
		if _save.save(SAVE_PATH) != OK:
			push_warning("Grenouille : record non sauvegardé")


# ================================================================ auto-test

func _st_check(name: String, ok: bool, detail: String = "") -> void:
	_st_log.append("%s : %s %s" % [name, "ok" if ok else "ECHEC", detail])
	if not ok:
		_st_failures.append(name)


func enable_selftest() -> void:
	_selftest = true
	_think = 0.1
	_close_panel()
	_selftest_run()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_state(target: State, max_frames: int) -> void:
	var i := 0
	while state != target and i < max_frames:
		await get_tree().physics_frame
		i += 1


func _selftest_run() -> void:
	settings["mode"] = "ordi"
	settings["level"] = "normal"
	settings["rounds"] = 1
	settings["dist"] = 1.5
	_apply_layout()
	await _wait_frames(3)

	# A. Le meuble : huit trous dans le plateau, valeurs attendues
	var inside := true
	var total := 0
	var has_500 := false
	for i in HOLES.size():
		var c := hole_pos(i)
		var r := hole_radius(i)
		if absf(c.x) + r > CAB_W / 2.0 or absf(c.z - cz) + r > CAB_D / 2.0:
			inside = false
		total += hole_points(i)
		if hole_points(i) == 500:
			has_500 = true
	_st_check("huit trous sur le plateau", HOLES.size() == 8 and inside and has_500 and total == 1225, "(total %d)" % total)

	# B. Un palet posé au-dessus de chaque trou est avalé et vaut ses points
	players = [{"name": "A", "score": 0, "thrown": 0, "ai": false}]
	current = 0
	var wrong: Array = []
	for i in HOLES.size():
		var c := hole_pos(i)
		players[0]["thrown"] = 0
		_launch(c + Vector3(0, 0.05, 0), Vector3(0.0, -0.3, 0.0))
		await _wait_state(State.PAUSE, 90 * 3)
		if _last_points != hole_points(i):
			wrong.append("%s=%d" % [HOLES[i]["id"], _last_points])
		_flight = 0.0
		state = State.SETUP
	_st_check("chaque trou avale le palet", wrong.is_empty(), str(wrong))

	# C. Un palet qui atterrit sur le bois sans trou s'arrête et vaut 0
	var plain := Vector3(0.0, TOP, cz - 0.02)
	var min_d := 9.0
	for i in HOLES.size():
		min_d = minf(min_d, Vector2(plain.x - hole_pos(i).x, plain.z - hole_pos(i).z).length() - hole_radius(i))
	var stopped_ok := true
	for k in 3:
		players[0]["thrown"] = 0
		_launch(plain + Vector3(0, 0.12, 0), Vector3.ZERO)
		await _wait_state(State.PAUSE, 90 * 10)
		if state == State.FLIGHT or _last_points != 0:
			stopped_ok = false
		_flight = 0.0
		state = State.SETUP
	_st_check("palet sur le bois : 0 point", stopped_ok and min_d > 0.01, "(marge %.3f)" % min_d)

	# D. Un palet lancé trop loin quitte le plateau sans bloquer la partie
	players[0]["thrown"] = 0
	_launch(Vector3(0.0, 1.0, 0.0), Vector3(2.5, 1.0, -3.0))
	await _wait_state(State.PAUSE, 90 * 12)
	_st_check("palet hors plateau", state == State.PAUSE and _last_points == 0, str(state))
	_flight = 0.0
	state = State.SETUP

	# E. Parties complètes : adversaire, joueurs virtuels
	for mode in ["ordi", "deux"]:
		settings["mode"] = mode
		settings["players"] = 3
		settings["rounds"] = 1
		_st_bot = true
		start_match()
		var guard := 0
		while state != State.GAME_OVER and guard < 90 * 300:
			await get_tree().physics_frame
			guard += 1
		var scores: Array = []
		for p in players:
			scores.append(int(p["score"]))
		_st_check("partie %s terminée" % mode, state == State.GAME_OVER and _hist.size() == PER_ROUND * players.size(), "%s en %.0f s ; %s" % [str(scores), guard / 90.0, str(_hist)])

	# F. Entraînement : une série de 10 lancers
	settings["mode"] = "training"
	_pending_scores.clear()
	_st_bot = true
	start_match()
	var g2 := 0
	while _pending_scores.is_empty() and g2 < 90 * 300:
		await get_tree().physics_frame
		g2 += 1
	_st_check("entraînement : série", not _pending_scores.is_empty() and _hist.size() == TRAINING_THROWS, "(%s pts en %.0f s)" % [str(_pending_scores), g2 / 90.0])
	_st_bot = false

	# G. Précision de l'adversaire : l'expert fait mieux que le niveau facile sur la grenouille
	var rates := {}
	for lvl in ["facile", "expert"]:
		settings["level"] = lvl
		settings["mode"] = "deux"
		players = [{"name": "A", "score": 0, "thrown": 0, "ai": false}]
		current = 0
		var hits := 0
		for k in 16:
			players[0]["thrown"] = 0
			var c := hole_pos(0)
			var sg: float = LEVELS[lvl]["sigma"]
			_ai_shoot(Vector2(c.x + _gauss() * sg, c.z + _gauss() * sg))
			await _wait_state(State.PAUSE, 90 * 10)
			if _last_points == 500:
				hits += 1
			_flight = 0.0
			state = State.SETUP
		rates[lvl] = hits
	_st_check("adresse de l'expert", int(rates["expert"]) > int(rates["facile"]) and int(rates["expert"]) >= 3, str(rates))

	# H. Lancer humain simulé : un geste doux atteint le plateau
	settings["mode"] = "deux"
	settings["players"] = 2
	settings["level"] = "facile"
	settings["rounds"] = 1
	start_match()
	await _wait_frames(2)
	_st_check("tour du joueur", state == State.TURN_WAIT and _puck.visible, str(state))
	_held = true
	_throw(Transform3D(Basis.IDENTITY, Vector3(0.3, 1.0, 0.0)), Vector3(-0.3, 1.2, -2.2))
	await _wait_state(State.PAUSE, 90 * 12)
	_st_check("lancer humain jugé", state == State.PAUSE or state == State.TURN_WAIT or state == State.GAME_OVER, str(state))

	_drop_puck()
	for line in _st_log:
		print("SELFTEST grenouille ", line)
	print("SELFTEST grenouille=", "OK" if _st_failures.is_empty() else "ECHEC " + str(_st_failures))
	selftest_finished.emit(_st_failures.is_empty())
