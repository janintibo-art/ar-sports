class_name MeshMerge
extends RefCounted
## Fusionne les petits maillages fixes d'un objet en un seul (un par matériau identique).
## Résultat visuellement identique, mais beaucoup moins d'appels de dessin sur Quest.
## Sont laissés tels quels : maillages animés (nœud avec script), transparents, cachés.

static func _mat_key(m: Material) -> String:
	if m is StandardMaterial3D:
		var s := m as StandardMaterial3D
		var tex := 0
		if s.albedo_texture:
			tex = s.albedo_texture.get_instance_id()
		return "%s|%.3f|%.3f|%d|%s|%s|%d|%d|%d|%s" % [s.albedo_color, s.roughness, s.metallic, tex, s.uv1_scale, s.emission if s.emission_enabled else Color(0, 0, 0), s.shading_mode, s.cull_mode, int(s.vertex_color_use_as_albedo), s.emission_enabled]
	if m == null:
		return "none"
	return str(m.get_instance_id())


static func _mergeable(mi: MeshInstance3D) -> bool:
	if not mi.visible or mi.mesh == null or mi.get_script() != null:
		return false
	if mi.mesh is ArrayMesh or mi.mesh is PrimitiveMesh:
		pass
	else:
		return false
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.material_override if mi.material_override != null else mi.get_active_material(i)
		if m == null:
			return false
		if m is StandardMaterial3D:
			var s := m as StandardMaterial3D
			if s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or s.albedo_color.a < 0.999:
				return false
		elif not (m is Material):
			return false
		else:
			return false
	return true


static func _relative(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _collect(n: Node, root: Node3D, skip: Node, out: Array) -> void:
	for c in n.get_children():
		if c == skip:
			continue
		if c.get_script() != null:
			continue
		if c is MeshInstance3D and _mergeable(c as MeshInstance3D):
			out.append(c)
		_collect(c, root, skip, out)


## Fusionne les maillages fixes sous `root` (sauf le sous-arbre `skip`). Renvoie le nombre de nœuds retirés.
static func merge_static(root: Node3D, skip: Node = null, node_name: String = "Fusion") -> int:
	var list: Array = []
	_collect(root, root, skip, list)
	if list.size() < 2:
		return 0
	var groups := {}
	for mi in list:
		var m: MeshInstance3D = mi
		var xf := _relative(m, root)
		for i in m.mesh.get_surface_count():
			var mat: Material = m.material_override if m.material_override != null else m.get_active_material(i)
			var key := _mat_key(mat) + "|" + str(m.cast_shadow)
			if not groups.has(key):
				groups[key] = {"mat": mat, "shadow": m.cast_shadow, "parts": []}
			groups[key]["parts"].append([m.mesh, i, xf])
	var am := ArrayMesh.new()
	var shadow_on := false
	for key in groups:
		var g: Dictionary = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in g["parts"]:
			st.append_from(part[0], part[1], part[2])
		st.set_material(g["mat"])
		st.commit(am)
		if g["shadow"] != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow_on = true
	var out := MeshInstance3D.new()
	out.name = node_name
	out.mesh = am
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in list:
		var m2: Node = mi
		m2.get_parent().remove_child(m2)
		m2.queue_free()
	root.add_child(out)
	return list.size()
