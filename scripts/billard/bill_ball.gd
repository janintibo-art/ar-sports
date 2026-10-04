class_name BillBall
extends RefCounted
## Une bille de billard : position et vitesse à plat (x, z relatifs au centre du tapis).

var id := 0                  # 0 = blanche, 1..15
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var potted := false
var node: MeshInstance3D
var shadow: MeshInstance3D

static var _textures := {}


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


## Texture procédurale partagée par numéro. Le cache évite de reconstruire la même
## image à chaque remise en place des billes. Les mipmaps stabilisent les motifs
## blancs/rayés quand les billes sont éloignées dans le casque.
static func texture_of(i: int) -> ImageTexture:
	if _textures.has(i):
		return _textures[i]

	var s: int = 128
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGB8)
	var col: Color = color_of(i)
	var white := Color(0.965, 0.96, 0.92)

	for x in s:
		for y in s:
			var u: float = (float(x) + 0.5) / float(s)
			var v: float = (float(y) + 0.5) / float(s)
			var c: Color = col

			if i >= 9:
				var edge: float = minf(absf(v - 0.30), absf(v - 0.70))
				var inside: bool = v > 0.30 and v < 0.70
				if not inside:
					c = white
				elif edge < 0.018:
					var t: float = clampf(edge / 0.018, 0.0, 1.0)
					c = white.lerp(col, t)

			if i > 0:
				for cu_value in [0.25, 0.75]:
					var cu: float = float(cu_value)
					var du: float = (u - cu) * 2.0
					var dv: float = v - 0.5
					var d2: float = du * du + dv * dv
					if d2 < 0.036:
						var rim: float = clampf((0.036 - d2) / 0.010, 0.0, 1.0)
						c = c.lerp(white, rim)

			var grain: float = 0.985 + float((x * 17 + y * 31 + i * 13) % 11) / 700.0
			c *= Color(grain, grain, grain)
			img.set_pixel(x, y, c)

	img.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_textures[i] = texture
	return texture
