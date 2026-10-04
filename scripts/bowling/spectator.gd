class_name Spectator
extends Node3D
## Personnage spectateur fait de formes simples, animé par le code :
## respire, regarde le joueur, applaudit, saute de joie, se désole, boit sa bière.

const LINES := {
	"strike": ["STRIIIKE !", "Trop fort !", "Quel bras !", "Bowling royal !"],
	"spare": ["Bien rattrapé !", "Spare, bravo !", "Joli !"],
	"gutter": ["Aïe… la rigole !", "Oups !", "Ça arrive à tout le monde…"],
	"low": ["Allez, la prochaine !", "Concentre-toi !", "Pas grave !"],
	"good": ["Pas mal !", "Presque !", "Bien joué !"],
	"cheers": ["Santé !", "À la tienne !", "Tchin !"],
	"empty": ["Cul sec !", "Elle était bonne ?", "Une autre ?"],
	"win": ["Champion !", "Bravo !", "Quelle partie !"],
	"carreau": ["Carreau !", "Au fer, bravo !", "Boum, dehors !"],
	"pointe": ["Joli point !", "Collée au cochonnet !", "Quelle main !"],
	"oups": ["Aïe, trop long…", "Pas de chance !", "Rien ne va plus…"],
	"fanny": ["Fanny !", "On n'a pas vu le jeu…"],
}

var display_name := ""
var mug: Node3D = null      # chope tenue dans la main droite (décor)

var _style: Dictionary
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _bubble: Label3D
var _bubble_time := 0.0
var _anim := "idle"
var _anim_time := 0.0
var _t := 0.0
var _drink_timer := 0.0
var _drink_phase := -1.0
var _phase_offset := 0.0


## style : {name, skin, shirt, pants, hair, hat, ponytail, beard}
func _init(style: Dictionary) -> void:
	_style = style
	display_name = style.get("name", "")
	_phase_offset = randf() * 10.0
	_drink_timer = randf_range(5.0, 10.0)


func _ready() -> void:
	var skin := BowlingArt.mat(_style.get("skin", Color(0.93, 0.76, 0.62)), 0.7)
	var shirt := BowlingArt.mat(_style.get("shirt", Color(0.2, 0.4, 0.8)), 0.85)
	var pants := BowlingArt.mat(_style.get("pants", Color(0.15, 0.17, 0.25)), 0.9)
	var hair := BowlingArt.mat(_style.get("hair", Color(0.25, 0.15, 0.08)), 0.9)
	var shoe := BowlingArt.mat(Color(0.1, 0.1, 0.1), 0.5)
	var dark := BowlingArt.mat(Color(0.05, 0.05, 0.06), 0.3)

	var blob := BowlingArt.make_blob(0.7)
	add_child(blob)
	blob.position = Vector3(0, 0.003, 0)
	blob.top_level = false

	# Jambes et chaussures
	for side in [-1.0, 1.0]:
		add_child(BowlingArt.capsule(0.082, 0.84, pants, Vector3(side * 0.1, 0.44, 0)))
		add_child(BowlingArt.box(Vector3(0.11, 0.07, 0.22), shoe, Vector3(side * 0.1, 0.035, 0.04)))

	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.86, 0)
	add_child(_hips)
	var pelvis := BowlingArt.sphere(0.18, pants, Vector3(0, 0.02, 0), 14)
	pelvis.scale = Vector3(1.05, 0.6, 0.75)
	_hips.add_child(pelvis)

	_torso = Node3D.new()
	_hips.add_child(_torso)
	var chest := BowlingArt.capsule(0.2, 0.7, shirt, Vector3(0, 0.3, 0))
	chest.scale = Vector3(1.0, 1.0, 0.7)
	_torso.add_child(chest)
	# Petit logo de bowling sur le t-shirt
	var logo := BowlingArt.sphere(0.035, BowlingArt.mat(Color(0.95, 0.95, 0.9)), Vector3(0.09, 0.42, 0.135), 10)
	logo.scale = Vector3(1, 1, 0.3)
	_torso.add_child(logo)

	_arm_l = _make_arm(-1.0, shirt, skin)
	_arm_r = _make_arm(1.0, shirt, skin)

	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, 0)
	_torso.add_child(_head)
	_head.add_child(BowlingArt.cylinder(0.045, 0.05, 0.08, skin, Vector3(0, 0.02, 0), 10))
	var face := BowlingArt.sphere(0.115, skin, Vector3(0, 0.15, 0), 18)
	face.scale = Vector3(0.95, 1.08, 1.0)
	_head.add_child(face)
	for side in [-1.0, 1.0]:
		_head.add_child(BowlingArt.sphere(0.016, dark, Vector3(side * 0.04, 0.17, 0.1), 8))
		_head.add_child(BowlingArt.sphere(0.022, skin, Vector3(side * 0.112, 0.15, 0.0), 8))
	_head.add_child(BowlingArt.sphere(0.02, skin, Vector3(0, 0.135, 0.115), 8))
	var mouth := BowlingArt.box(Vector3(0.05, 0.008, 0.01), BowlingArt.mat(Color(0.5, 0.15, 0.15)), Vector3(0, 0.09, 0.105))
	_head.add_child(mouth)
	# Cheveux
	var top := BowlingArt.sphere(0.12, hair, Vector3(0, 0.19, -0.012), 16)
	top.scale = Vector3(1.0, 0.75, 1.02)
	_head.add_child(top)
	if _style.get("ponytail", false):
		var tail := BowlingArt.capsule(0.04, 0.2, hair, Vector3(0, 0.13, -0.13))
		tail.rotation_degrees = Vector3(25, 0, 0)
		_head.add_child(tail)
	if _style.get("beard", false):
		var beard := BowlingArt.sphere(0.09, hair, Vector3(0, 0.08, 0.05), 12)
		beard.scale = Vector3(1.05, 0.7, 0.8)
		_head.add_child(beard)
		_head.add_child(BowlingArt.box(Vector3(0.05, 0.008, 0.01), BowlingArt.mat(Color(0.5, 0.15, 0.15)), Vector3(0, 0.095, 0.112)))
	if _style.get("hat", false):
		var cap_mat := BowlingArt.mat(_style.get("hat_color", Color(0.85, 0.15, 0.15)), 0.8)
		_head.add_child(BowlingArt.cylinder(0.118, 0.122, 0.07, cap_mat, Vector3(0, 0.255, 0), 18))
		var brim := BowlingArt.box(Vector3(0.17, 0.012, 0.11), cap_mat, Vector3(0, 0.225, 0.13))
		_head.add_child(brim)

	_bubble = BowlingArt.label("", 0.06, Color(1, 1, 0.85))
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 2.07, 0)
	_bubble.no_depth_test = true
	add_child(_bubble)

	var tag := BowlingArt.label(display_name, 0.035, Color(0.8, 0.9, 1.0, 0.8))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 1.96, 0)
	add_child(tag)


func _make_arm(side: float, shirt: Material, skin: Material) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * 0.235, 0.54, 0)
	_torso.add_child(shoulder)
	shoulder.add_child(BowlingArt.capsule(0.065, 0.32, shirt, Vector3(0, -0.12, 0)))
	shoulder.add_child(BowlingArt.capsule(0.05, 0.3, skin, Vector3(0, -0.35, 0)))
	var hand := BowlingArt.sphere(0.055, skin, Vector3(0, -0.52, 0), 10)
	hand.name = "Main"
	shoulder.add_child(hand)
	shoulder.rotation_degrees = Vector3(0, 0, side * 8)
	return shoulder


## Donne une chope au personnage (dans la main droite).
func hold_mug(m: Node3D) -> void:
	mug = m
	var hand := _arm_r.get_node("Main")
	hand.add_child(m)
	m.position = Vector3(0.0, 0.02, 0.06)
	m.rotation = Vector3.ZERO


func say(kind: String, force: bool = false) -> void:
	if not LINES.has(kind):
		return
	if _bubble_time > 0.0 and not force:
		return
	var list: Array = LINES[kind]
	_bubble.text = list[randi() % list.size()]
	_bubble_time = 2.6


## Réaction à un évènement de jeu : strike, spare, gutter, low, good, win.
func react(kind: String) -> void:
	match kind:
		"strike", "win", "carreau":
			_play("cheer", 2.2)
		"spare", "good", "pointe":
			_play("clap", 1.6)
		"gutter", "low", "oups", "fanny":
			_play("sad", 2.0)
	# Chacun ne parle pas forcément à chaque fois
	if randf() < 0.75 or kind == "strike":
		say(kind, true)


func _play(anim: String, duration: float) -> void:
	_anim = anim
	_anim_time = duration
	_drink_phase = -1.0


func _process(delta: float) -> void:
	_t += delta
	var t := _t + _phase_offset
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.text = ""

	if _anim_time > 0.0:
		_anim_time -= delta
		if _anim_time <= 0.0:
			_anim = "idle"

	var arm_l := Vector3(0, 0, -8)
	var arm_r := Vector3(0, 0, 8)
	var head_pitch := 0.0
	var hop := 0.0
	var lean := sin(t * 0.7) * 2.0

	match _anim:
		"cheer":
			var k := sin(t * 14.0)
			arm_l = Vector3(0, 0, -160 + k * 12)
			arm_r = Vector3(0, 0, 160 - k * 12)
			hop = absf(sin(t * 7.0)) * 0.09 * clampf(_anim_time, 0.0, 1.0)
			head_pitch = -12.0
		"clap":
			var k := absf(sin(t * 11.0))
			arm_l = Vector3(-75, 0, -10 + k * 22)
			arm_r = Vector3(-75, 0, 10 - k * 22)
		"sad":
			arm_l = Vector3(0, 0, -4)
			arm_r = Vector3(-150, 0, -25)
			head_pitch = 22.0
			lean = 0.0
		_:
			# Boire une gorgée de temps en temps
			if mug:
				_drink_timer -= delta
				if _drink_timer <= 0.0 and _drink_phase < 0.0:
					_drink_phase = 0.0
				if _drink_phase >= 0.0:
					_drink_phase += delta
					var p := clampf(sin(PI * clampf(_drink_phase / 2.0, 0, 1)) * 1.4, 0, 1)
					arm_r = Vector3(-115 * p, 0, 8 + 20 * p)
					head_pitch = -18.0 * p
					if _drink_phase >= 2.0:
						_drink_phase = -1.0
						_drink_timer = randf_range(8.0, 15.0)
				else:
					arm_r = Vector3(-45, 0, 10)
			arm_l.x += sin(t * 1.3) * 3.0

	_arm_l.rotation_degrees = _arm_l.rotation_degrees.lerp(arm_l, minf(1.0, delta * 10.0))
	_arm_r.rotation_degrees = _arm_r.rotation_degrees.lerp(arm_r, minf(1.0, delta * 10.0))
	if mug:
		# La chope reste droite… sauf quand on boit.
		var sip := 0.0
		if _drink_phase >= 0.0:
			sip = clampf(sin(PI * clampf(_drink_phase / 2.0, 0, 1)) * 1.4, 0, 1)
		mug.rotation_degrees = Vector3(-_arm_r.rotation_degrees.x - 55.0 * sip, 0, -_arm_r.rotation_degrees.z)
	_hips.position.y = 0.86 + hop
	_torso.scale = Vector3(1, 1.0 + sin(t * 1.8) * 0.012, 1)
	_torso.rotation_degrees.z = lean

	# La tête suit le joueur (caméra) dans une limite naturelle
	var cam := get_viewport().get_camera_3d()
	var yaw := 0.0
	if cam:
		var local := to_local(cam.global_position)
		yaw = clampf(rad_to_deg(atan2(local.x, local.z)), -70.0, 70.0)
	var target := Vector3(head_pitch, yaw, 0)
	_head.rotation_degrees = _head.rotation_degrees.lerp(target, minf(1.0, delta * 5.0))
