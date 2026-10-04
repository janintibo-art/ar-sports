class_name BfRod
extends RefCounted
## Une barre de baby-foot : sa place sur la longueur, ses joueurs, son décalage et son angle.

var idx := 0
var team := 1                 # 1 = vous (attaque vers +x), -1 = ordinateur
var dir := 1                  # sens du tir : +1 vers +x, -1 vers -x
var x := 0.0
var men: Array[float] = []    # position de chaque joueur sur la barre (sans le décalage)
var off := 0.0                # décalage de la barre (le long de la largeur)
var off_prev := 0.0
var theta := 0.0              # angle : positif = pied vers l'avant (sens du tir)
var theta_prev := 0.0
var omega := 0.0
var lim := 0.3                # décalage maximal
var kick_t := 0.0
var cd := 0.0
var track_y := 0.0
var held_by: Object = null
var hand_z0 := 0.0
var off0 := 0.0
var node: Node3D              # la barre entière (glisse en z)
var pivot: Node3D             # les joueurs (tournent autour de la barre)


func foot(i: int, leg: float) -> Vector2:
	return Vector2(x + dir * leg * sin(theta), men[i] + off)


func foot_prev(i: int, leg: float) -> Vector2:
	return Vector2(x + dir * leg * sin(theta_prev), men[i] + off_prev)


func pivot_pos(i: int) -> Vector2:
	return Vector2(x, men[i] + off)
