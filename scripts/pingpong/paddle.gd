class_name PingPaddle
extends Node3D
## Raquette de ping-pong : disque dont la face « avant » regarde vers -Z
## (revêtement coloré devant, noir derrière), manche vers le bas.
## L'origine du noeud est le centre de la palette.

const RADIUS := 0.095

var front_color := Color(0.85, 0.12, 0.12)
var glow := false


func _ready() -> void:
	add_child(PingArt.paddle(RADIUS, front_color, glow, VisualStyle.detailed))
