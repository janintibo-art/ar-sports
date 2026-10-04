class_name PingPaddle
extends Node3D
## Raquette de ping-pong : disque dont la face « avant » regarde vers -Z
## (revêtement coloré devant, noir derrière), manche vers le bas.
## L'origine du noeud est le centre de la palette.

const RADIUS := 0.095

var front_color := Color(0.85, 0.12, 0.12)
var glow := false


func _ready() -> void:
	var wood := BowlingArt.mat(Color(0.78, 0.55, 0.3), 0.5)
	var core := BowlingArt.cylinder(RADIUS, RADIUS, 0.008, wood, Vector3.ZERO, 32)
	core.rotation_degrees = Vector3(90, 0, 0)
	add_child(core)
	var front_mat := BowlingArt.glow(front_color, 0.6) if glow else BowlingArt.mat(front_color, 0.55)
	var front := BowlingArt.cylinder(RADIUS, RADIUS, 0.004, front_mat, Vector3(0, 0, -0.006), 32)
	front.rotation_degrees = Vector3(90, 0, 0)
	add_child(front)
	var back := BowlingArt.cylinder(RADIUS, RADIUS, 0.004, BowlingArt.mat(Color(0.08, 0.08, 0.09), 0.6), Vector3(0, 0, 0.006), 32)
	back.rotation_degrees = Vector3(90, 0, 0)
	add_child(back)
	add_child(BowlingArt.box(Vector3(0.026, 0.11, 0.022), wood, Vector3(0, -RADIUS - 0.045, 0)))
	add_child(BowlingArt.box(Vector3(0.03, 0.03, 0.01), wood, Vector3(0, -RADIUS + 0.005, 0)))
