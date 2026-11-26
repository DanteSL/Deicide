extends RefCounted
## Materiais celestes compartilhados (arena do Gabriel, entrada e trono de Deus):
## mármore branco com veios de ouro, folha de ouro e a coluna jônica.

static var _msh: Shader
static var _tex := {}
static var _col_scn: PackedScene

static func _t(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

## mármore com veios de ouro (shader com ladrilho hexagonal aleatório e corrupção)
static func marble(tint := Color(1, 1, 1), scale := .07) -> ShaderMaterial:
	if _msh == null: _msh = load("res://shaders/marmore_celeste.gdshader")
	var m = ShaderMaterial.new()
	m.shader = _msh
	m.set_shader_parameter("albedo_tex", _t("res://texturas/marmore_ouro.jpg"))
	m.set_shader_parameter("normal_tex", _t("res://texturas/marmore_ouro_n.jpg"))
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("scale", scale)
	return m

## folha de ouro (textura do jogador) projetada no mundo, metálica e com relevo
static func gold(tint := Color(1, 1, 1), glow := 0.0, scale := .18) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = _t("res://texturas/folha_ouro.jpg")
	m.albedo_color = tint
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE * scale
	m.normal_enabled = true; m.normal_texture = _t("res://texturas/folha_ouro_n.jpg"); m.normal_scale = .7
	m.metallic = .9; m.roughness = .26; m.metallic_specular = .8
	m.emission_enabled = true
	m.emission = Color("2a1a04") if glow <= 0.0 else Color("ffcf6a")
	m.emission_energy_multiplier = max(glow, .5)
	return m

## coluna jônica (base com anéis, fuste canelado, capitel com volutas douradas)
## altura do modelo: 8.59 m em escala 1. Devolve o nó já posicionado (com colisão opcional).
static func column(parent: Node3D, pos: Vector3, height: float, marble_m: Material, gold_m: Material, col := true, rot_y := 0.0) -> Node3D:
	if _col_scn == null: _col_scn = load("res://colunas/coluna_ionica.glb")
	var s = height / 8.59
	var c: Node3D = _col_scn.instantiate()
	c.scale = Vector3.ONE * s
	c.position = pos
	c.rotation.y = rot_y
	parent.add_child(c)
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(si)
			var nm = String(src.resource_name) if src else ""
			mi.set_surface_override_material(si, gold_m if nm.contains("ouro") else marble_m)
	if col:
		var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
		var cs = CollisionShape3D.new(); var cy = CylinderShape3D.new()
		cy.radius = .5 * s; cy.height = height
		cs.shape = cy; cs.position = Vector3(0, height * .5, 0)
		sb.add_child(cs); sb.position = pos
		parent.add_child(sb)
	return c
