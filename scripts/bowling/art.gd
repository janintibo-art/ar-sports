class_name BowlingArt
extends RefCounted
## Textures et maillages générés par le code (aucun fichier image) : bois de piste,
## quille tournée, boule marbrée, ombres douces, matériaux.

static var _wood: ImageTexture
static var _pin_mesh: ArrayMesh
static var _blob: ImageTexture
static var _marble_cache := {}


# ---------------------------------------------------------------- matériaux

static func mat(color: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := mat(color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := mat(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func box(size: Vector3, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	return mi


static func cylinder(radius_top: float, radius_bottom: float, height: float, material: Material, pos := Vector3.ZERO, segments := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius_top
	cm.bottom_radius = radius_bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	return mi


static func sphere(radius: float, material: Material, pos := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = segments / 2
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	return mi


static func capsule(radius: float, height: float, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = max(height, radius * 2.0)
	cm.radial_segments = 14
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	return mi


static func label(text: String, height: float, color := Color.WHITE, outline := 18) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = height / 96.0
	l.outline_size = outline
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- bois de piste

## Lattes d'érable vernies : 39 planches sur la largeur, joints décalés, veinage.
static func wood_texture() -> ImageTexture:
	if _wood:
		return _wood
	var w := 256
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grain := FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grain.frequency = 0.02
	grain.fractal_octaves = 3
	grain.seed = 11
	var boards := 39
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tones: Array[float] = []
	var joints: Array[int] = []
	for b in boards:
		tones.append(rng.randf_range(-0.06, 0.06))
		joints.append(rng.randi_range(0, h - 1))
	for x in w:
		var bf := float(x) / w * boards
		var b := int(bf)
		var edge := absf(bf - b - 0.5) > 0.46
		for y in h:
			var g := grain.get_noise_2d(x * 6.0 + b * 50.0, y * 0.35)
			var v := 0.5 + 0.5 * g
			var r := 0.86 + tones[b] + (v - 0.5) * 0.12
			var gg := 0.68 + tones[b] * 0.9 + (v - 0.5) * 0.1
			var bb := 0.47 + tones[b] * 0.7 + (v - 0.5) * 0.07
			var c := Color(r, gg, bb)
			if edge or absi(y - joints[b]) < 1:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_wood = ImageTexture.create_from_image(img)
	return _wood


static func wood_material(length: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = wood_texture()
	m.uv1_scale = Vector3(1, length / 1.6, 1)
	m.roughness = 0.28
	m.metallic_specular = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Plan texturé (face vers le haut) avec UV 0..1 sur la largeur et la longueur.
static func floor_quad(size_x: float, size_z: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size_x, size_z)
	mi.mesh = pm
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- quille

## Quille réglementaire tournée (profil réel, 38 cm) avec ses deux bandes rouges.
static func pin_mesh() -> ArrayMesh:
	if _pin_mesh:
		return _pin_mesh
	# (rayon, hauteur) du pied vers la tête
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.034, 0.008), Vector2(0.045, 0.03),
		Vector2(0.055, 0.065), Vector2(0.0605, 0.114), Vector2(0.0585, 0.15), Vector2(0.05, 0.185),
		Vector2(0.036, 0.218), Vector2(0.026, 0.238), Vector2(0.0232, 0.25), Vector2(0.0225, 0.262),
		Vector2(0.0232, 0.274), Vector2(0.026, 0.29), Vector2(0.031, 0.31), Vector2(0.0325, 0.33),
		Vector2(0.03, 0.35), Vector2(0.022, 0.368), Vector2(0.011, 0.378), Vector2(0.0, 0.381),
	]
	var white := Color(0.97, 0.97, 0.95)
	var red := Color(0.82, 0.06, 0.08)
	var stripes := [Vector2(0.236, 0.248), Vector2(0.262, 0.274)]
	# Ajoute des points juste avant/après chaque bande pour des bords nets.
	var pts: Array[Vector2] = []
	var cols: Array[Color] = []
	for i in profile.size():
		pts.append(profile[i])
		if i < profile.size() - 1:
			for s in stripes:
				for edge in [s.x, s.y]:
					if profile[i].y < edge and profile[i + 1].y > edge:
						var t: float = (edge - profile[i].y) / (profile[i + 1].y - profile[i].y)
						var p := profile[i].lerp(profile[i + 1], t)
						pts.append(Vector2(p.x, edge - 0.0004))
						pts.append(Vector2(p.x, edge + 0.0004))
	for p in pts:
		var c := white
		for s in stripes:
			if p.y > s.x and p.y < s.y:
				c = red
		cols.append(c)
	var seg := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.19
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := (b - a)
		var n2 := Vector2(d.y, -d.x).normalized()
		if d.length() < 0.00001:
			continue
		for j in seg:
			var t0 := TAU * j / seg
			var t1 := TAU * (j + 1) / seg
			var c0 := Vector3(cos(t0), 0, sin(t0))
			var c1 := Vector3(cos(t1), 0, sin(t1))
			var v00 := c0 * a.x + Vector3(0, a.y - half, 0)
			var v01 := c1 * a.x + Vector3(0, a.y - half, 0)
			var v10 := c0 * b.x + Vector3(0, b.y - half, 0)
			var v11 := c1 * b.x + Vector3(0, b.y - half, 0)
			var n0 := (c0 * n2.x + Vector3(0, n2.y, 0)).normalized()
			var n1 := (c1 * n2.x + Vector3(0, n2.y, 0)).normalized()
			for v in [[v00, n0, cols[i]], [v10, n0, cols[i + 1]], [v11, n1, cols[i + 1]],
					[v00, n0, cols[i]], [v11, n1, cols[i + 1]], [v01, n1, cols[i]]]:
				st.set_color(v[2])
				st.set_normal(v[1])
				st.add_vertex(v[0])
	_pin_mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.22
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pin_mesh.surface_set_material(0, m)
	return _pin_mesh


# ---------------------------------------------------------------- boule

## Texture marbrée façon boule de bowling en résine, dans la couleur du joueur.
static func marble_texture(base: Color) -> ImageTexture:
	var key := base.to_html()
	if _marble_cache.has(key):
		return _marble_cache[key]
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.fractal_octaves = 4
	n.seed = int(base.h * 1000)
	var light := base.lightened(0.45)
	var dark := base.darkened(0.55)
	for x in w:
		for y in h:
			var ang := TAU * x / w
			var v := n.get_noise_3d(cos(ang) * 40.0, y * 1.3, sin(ang) * 40.0)
			var swirl := sin(v * 9.0 + y * 0.12)
			var c := base
			if swirl > 0.55:
				c = base.lerp(light, (swirl - 0.55) / 0.45)
			elif swirl < -0.4:
				c = base.lerp(dark, (-swirl - 0.4) / 0.6)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_marble_cache[key] = tex
	return tex


static func ball_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = marble_texture(base)
	m.roughness = 0.08
	m.metallic = 0.15
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.25
	return m


# ---------------------------------------------------------------- ombre douce

static func blob_texture() -> ImageTexture:
	if _blob:
		return _blob
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for x in s:
		for y in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.75))
	_blob = ImageTexture.create_from_image(img)
	return _blob


## Ombre au sol (tache sombre floue) qui donne l'impression que l'objet est posé.
static func make_blob(diameter: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = blob_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.render_priority = -1
	var mi := floor_quad(diameter, diameter, m, Vector3.ZERO)
	mi.top_level = true
	return mi
