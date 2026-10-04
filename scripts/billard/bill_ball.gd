class_name BillBall
extends RefCounted
## Une bille de billard : position et vitesse à plat (x, z relatifs au centre du tapis).

var id := 0                  # 0 = blanche, 1..15
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var potted := false
var node: MeshInstance3D
var shadow: MeshInstance3D


func is_moving() -> bool:
	return not potted and vel.length_squared() > 0.0


## 1..7 pleines, 9..15 rayées, 8 la noire, 0 la blanche.
static func group_of(i: int) -> String:
	if i == 8:
		return "eight"
	if i >= 1 and i <= 7:
		return "solid"
	if i >= 9:
		return "stripe"
	return ""


static func color_of(i: int) -> Color:
	var cols := [Color(0.95, 0.95, 0.92), Color(1.0, 0.82, 0.1), Color(0.1, 0.25, 0.8), Color(0.9, 0.12, 0.12),
		Color(0.45, 0.12, 0.6), Color(1.0, 0.45, 0.05), Color(0.05, 0.55, 0.2), Color(0.5, 0.05, 0.1), Color(0.03, 0.03, 0.04)]
	if i == 0:
		return cols[0]
	var k := i if i <= 8 else i - 8
	return cols[k]


static func texture_of(i: int) -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var col := color_of(i)
	var white := Color(0.96, 0.96, 0.93)
	for x in s:
		for y in s:
			var v: float = float(y) / s
			var c := col
			if i >= 9:
				c = col if (v > 0.30 and v < 0.70) else white
			# pastille blanche (deux faces) pour les billes numérotées
			if i > 0:
				var u: float = float(x) / s
				for cu in [0.25, 0.75]:
					var du: float = (u - cu) * 2.0
					var dv: float = v - 0.5
					if du * du + dv * dv < 0.035:
						c = white
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
