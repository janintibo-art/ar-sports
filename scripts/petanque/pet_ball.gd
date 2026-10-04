class_name PetBall
extends RefCounted
## Une boule (ou le cochonnet) : position, vitesse et déplacement simple.
## Gravité, rebond amorti sur le gravier, puis roulement qui ralentit jusqu'à l'arrêt.

const G := 9.81
const LAND_KEEP := 0.45      # part de la vitesse horizontale gardée à l'atterrissage (le gravier freine)
const ROLL_DECEL := 3.2      # ralentissement du roulement (m/s²)

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var r := 0.0375
var mass := 0.7
var team := 0                # 1 = vous, -1 = adversaire, 0 = cochonnet
var moving := true
var dead := false            # boule sortie du terrain
var touched := false         # a déjà touché le sol
var land_keep := LAND_KEEP   # réglable par jeu (palet : planche)
var roll_decel := ROLL_DECEL
var ground_y := -1.0         # hauteur du centre au repos (-1 : le rayon)
var spin := true             # false : disque, il ne roule pas
var land_speed := 0.0        # vitesse d'impact du dernier atterrissage (le jeu la lit puis la remet à 0)
var node: MeshInstance3D
var shadow: MeshInstance3D


func move(dt: float) -> void:
	if not moving:
		return
	vel.y -= G * dt
	pos += vel * dt
	var gy := r if ground_y < 0.0 else ground_y
	if pos.y > gy:
		return
	pos.y = gy
	touched = true
	if vel.y < -0.8:
		land_speed = -vel.y
		vel.y = -vel.y * 0.08
		vel.x *= land_keep
		vel.z *= land_keep
		return
	vel.y = 0.0
	var sp := Vector2(vel.x, vel.z).length()
	if sp <= roll_decel * dt + 0.03:
		vel = Vector3.ZERO
		moving = false
	else:
		var k := (sp - roll_decel * dt) / sp
		vel.x *= k
		vel.z *= k


## Choc entre deux boules (masses différentes : le cochonnet part vite). Renvoie la vitesse d'impact.
static func collide(a: PetBall, b: PetBall, e: float = 0.55) -> float:
	var d := a.pos - b.pos
	var dist := d.length()
	var rr := a.r + b.r
	if dist >= rr or dist < 0.0001:
		return 0.0
	var n := d / dist
	var vn := (a.vel - b.vel).dot(n)
	# séparation (au prorata des masses)
	var over := rr - dist
	var wa := b.mass / (a.mass + b.mass)
	a.pos += n * over * wa
	b.pos -= n * over * (1.0 - wa)
	if vn >= 0.0:
		return 0.0
	var j := -(1.0 + e) * vn / (1.0 / a.mass + 1.0 / b.mass)
	a.vel += n * (j / a.mass)
	b.vel -= n * (j / b.mass)
	a.moving = true
	b.moving = true
	return -vn
