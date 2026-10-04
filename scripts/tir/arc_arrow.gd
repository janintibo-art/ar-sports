class_name ArcArrow
extends RefCounted
## Une flèche : position de la pointe, vitesse, état.

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var team := 1                 # 1 = vous, -1 = adversaire
var flying := false
var stuck := false
var node: Node3D
var points := 0
var in_target := false        # plantée dans la cible (suit la cible mobile)
var life := 0.0
