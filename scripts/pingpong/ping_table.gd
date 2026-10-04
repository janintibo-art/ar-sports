class_name PingTable
extends Node3D
## Table de ping-pong : plateau bleu, lignes blanches, filet, pieds.
## Le noeud est placé au centre du plateau (sur le filet), longueur le long de Z.

const TOP_Y := 0.76
const NET_H := 0.1525

var length := 2.74
var width := 1.525


func _ready() -> void:
	var blue := BowlingArt.surface_material("fabric", Color(0.035, 0.24, 0.5), Vector2(4, 6))
	var white := BowlingArt.mat(Color(0.95, 0.95, 0.97), 0.6)
	var steel := BowlingArt.mat(Color(0.2, 0.2, 0.24), 0.35, 0.7)
	# Plateau
	add_child(BowlingArt.box(Vector3(width, 0.03, length), blue, Vector3(0, TOP_Y - 0.015, 0)))
	add_child(BowlingArt.box(Vector3(width + 0.02, 0.012, length + 0.02), BowlingArt.mat(Color(0.03, 0.03, 0.05), 0.6), Vector3(0, TOP_Y - 0.036, 0)))
	# Lignes : tour de table et ligne centrale
	var ly := TOP_Y + 0.0006
	for sx in [-1.0, 1.0]:
		add_child(BowlingArt.box(Vector3(0.02, 0.001, length), white, Vector3(sx * (width / 2.0 - 0.01), ly, 0)))
	for sz in [-1.0, 1.0]:
		add_child(BowlingArt.box(Vector3(width, 0.001, 0.02), white, Vector3(0, ly, sz * (length / 2.0 - 0.01))))
	add_child(BowlingArt.box(Vector3(0.006, 0.001, length), white, Vector3(0, ly, 0)))
	# Pieds
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_child(BowlingArt.box(Vector3(0.06, TOP_Y - 0.04, 0.06), steel, Vector3(sx * (width / 2.0 - 0.15), (TOP_Y - 0.04) / 2.0, sz * (length / 2.0 - 0.25))))
		add_child(BowlingArt.box(Vector3(0.04, 0.04, length - 0.5), steel, Vector3(sx * (width / 2.0 - 0.15), 0.12, 0)))
	# Filet : maille translucide, bande blanche, deux poteaux
	var net_mat := BowlingArt.net_material()
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(BowlingArt.box(Vector3(width + 0.3, NET_H - 0.02, 0.004), net_mat, Vector3(0, TOP_Y + (NET_H - 0.02) / 2.0, 0)))
	add_child(BowlingArt.box(Vector3(width + 0.3, 0.02, 0.008), white, Vector3(0, TOP_Y + NET_H - 0.01, 0)))
	for sx in [-1.0, 1.0]:
		add_child(BowlingArt.box(Vector3(0.02, NET_H + 0.02, 0.02), steel, Vector3(sx * (width / 2.0 + 0.15), TOP_Y + NET_H / 2.0, 0)))
	var blob := BowlingArt.make_blob(maxf(width, length) * 1.1)
	blob.top_level = false
	blob.scale = Vector3(width / maxf(width, length) * 1.05, 1, length / maxf(width, length) * 1.05)
	blob.position = Vector3(0, 0.003, 0)
	add_child(blob)
