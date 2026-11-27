extends Node3D
## Biblioteca de efeitos visuais (texturas do Kenney Particle Pack, CC0, em res://fx).
## Acesso global por G.fx. Tudo aqui some sozinho no fim da vida do efeito.
##   flash(pos, cor, tamanho)        clarão com estrela e halo
##   shock(pos, cor, raio)           onda de choque no chão (anel que se abre)
##   ring_v(pos, normal, cor, raio)  anel vertical (explosão de energia)
##   sigil(pos, raio, cor, vida)     círculo mágico de aviso no chão (gira e pulsa)
##   beam(a, b, largura, cor, vida)  feixe de luz texturizado
##   bolt(a, b, cor, largura, vida)  raio com galhos
##   slash(pos, dir, tamanho, cor)   corte em arco
##   smoke(pos, cor, n, tamanho)     fumaça
##   pillar(pos, raio, altura, cor)  coluna de luz/fogo
##   sprite(...)                     sprite genérico animado

const PATH := "res://fx/%s.png"
var _tex := {}
var _mats := {}
var items: Array = []
## arena clara (céu do Gabriel): efeitos com mistura normal, senão o brilho somado some no branco
var bright := false
var _cross: ArrayMesh
var _quad: QuadMesh
var _flat: PlaneMesh

func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(PATH % name) if ResourceLoader.exists(PATH % name) else null
	return _tex[name]

## material de sprite (aditivo por padrão; alpha para fumaça e sangue)
func mat(tname: String, col: Color, additive := true, billboard := 1, shared := false) -> StandardMaterial3D:
	var key = "%s|%s|%s|%d|%s" % [tname, col, additive, billboard, bright]
	if shared and _mats.has(key): return _mats[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive and not bright: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex(tname)
	m.albedo_color = col
	m.disable_fog = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.no_depth_test = false
	m.vertex_color_use_as_albedo = true
	if billboard == 1: m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.billboard_keep_scale = true
	elif billboard == 2: m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if shared: _mats[key] = m
	return m

func _quadm() -> QuadMesh:
	if _quad == null: _quad = QuadMesh.new(); _quad.size = Vector2.ONE
	return _quad

func _flatm() -> PlaneMesh:
	if _flat == null: _flat = PlaneMesh.new(); _flat.size = Vector2.ONE
	return _flat

## dois quads cruzados ao longo de Z (para feixes que se vê de qualquer ângulo)
func cross_mesh() -> ArrayMesh:
	if _cross: return _cross
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ax = Vector3(1, 0, 0) if k == 0 else Vector3(0, 1, 0)
		var p = [ax * -.5 + Vector3(0, 0, -.5), ax * .5 + Vector3(0, 0, -.5), ax * .5 + Vector3(0, 0, .5), ax * -.5 + Vector3(0, 0, .5)]
		var uv = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i]); st.add_vertex(p[i])
	_cross = st.commit()
	return _cross

func _world() -> Node:
	return G.world if G.world else self

## sprite genérico: cresce de s0 a s1 e some (alpha) ao longo de `life`
func sprite(pos: Vector3, tname: String, col: Color, s0: float, s1: float, life: float, spin := 0.0, additive := true, flat_normal := Vector3.ZERO, ease_out := true) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var flat = flat_normal != Vector3.ZERO
	mi.mesh = _flatm() if flat else _quadm()
	var m = mat(tname, col, additive, 0 if flat else 1)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world().add_child(mi)
	mi.global_position = pos
	if flat:
		var up = flat_normal.normalized()
		var side = up.cross(Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < .9 else Vector3.RIGHT).normalized()
		mi.basis = Basis(side, up, side.cross(up))
	mi.scale = Vector3.ONE * s0
	items.append({"n": mi, "m": m, "t": 0.0, "life": life, "s0": s0, "s1": s1, "a": col.a, "spin": spin, "flat": flat, "ease": ease_out, "rot": randf() * TAU})
	return mi

# ---------------- efeitos prontos ----------------
func flash(pos: Vector3, col: Color, size := 6.0, life := .35) -> void:
	sprite(pos, "star_09", Color(col.r, col.g, col.b, 1.0), size * .4, size * 1.3, life * .8)
	sprite(pos, "light_01", Color(col.r, col.g, col.b, .8), size * .3, size * 1.6, life)
	sprite(pos, "circle_05", Color(col.r, col.g, col.b, .9), size * .6, size * 1.1, life * .6)
	sprite(pos, "magic_05", Color(1, 1, 1, .9), size * .5, size * .9, life * .4, 2.0)

func shock(pos: Vector3, col: Color, radius := 8.0, life := .5, tname := "circle_02") -> void:
	sprite(pos + Vector3(0, .12, 0), tname, col, radius * .15, radius * 2.0, life, 0.0, true, Vector3.UP)
	sprite(pos + Vector3(0, .1, 0), "light_03", Color(col.r, col.g, col.b, col.a * .6), radius * .1, radius * 1.6, life * .8, 0.0, true, Vector3.UP)

func ring_v(pos: Vector3, normal: Vector3, col: Color, radius := 6.0, life := .45) -> void:
	sprite(pos, "circle_03", col, radius * .2, radius * 2.0, life, 0.0, true, normal)
	sprite(pos, "twirl_01", Color(col.r, col.g, col.b, col.a * .7), radius * .3, radius * 1.6, life, 6.0, true, normal)

## círculo mágico de aviso no chão (devolve o nó; some sozinho em `life`)
func sigil(pos: Vector3, radius: float, col: Color, life: float, style := 0) -> Node3D:
	var root = Node3D.new()
	_world().add_child(root)
	root.global_position = pos + Vector3(0, .09, 0)
	var layers = [["circle_03", 1.0, .6], ["magic_03" if style == 0 else "magic_02", .92, -1.2], ["magic_01" if style == 0 else "star_03", .7, 1.8], ["light_02", 1.15, 0.0]]
	var ms = []
	for i in layers.size():
		var L = layers[i]
		var mi = MeshInstance3D.new(); mi.mesh = _flatm()
		var m = mat(L[0], Color(col.r, col.g, col.b, 0.0), true, 0)
		mi.material_override = m
		mi.scale = Vector3.ONE * radius * 2.0 * L[1]
		mi.position.y = i * .01
		root.add_child(mi)
		ms.append({"n": mi, "m": m, "spin": L[2]})
	items.append({"sigil": true, "n": root, "layers": ms, "t": 0.0, "life": life, "a": col.a})
	return root

## feixe de luz: núcleo branco + brilho colorido, com pulsar
func beam(a: Vector3, b: Vector3, width: float, col: Color, life := .2, tname := "beam_soft") -> void:
	_stretch(a, b, width * 2.4, tname, Color(col.r, col.g, col.b, col.a), life)
	_stretch(a, b, width * .9, "beam_core", Color(1, 1, 1, col.a), life * .8)
	sprite(b, "star_08", col, width * 2.0, width * 4.0, life, 3.0)

func _stretch(a: Vector3, b: Vector3, width: float, tname: String, col: Color, life: float) -> MeshInstance3D:
	var d = b - a
	if d.length() < .01: return null
	var mi = MeshInstance3D.new()
	mi.mesh = cross_mesh()
	var m = mat(tname, col, true, 0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world().add_child(mi)
	mi.global_position = (a + b) * .5
	var up = Vector3.UP if abs(d.normalized().y) < .99 else Vector3.RIGHT
	mi.basis = Basis.looking_at(d, up)
	mi.scale = Vector3(width, width, d.length())
	items.append({"n": mi, "m": m, "t": 0.0, "life": life, "a": col.a, "beam": true, "w": width})
	return mi

## raio com zigue-zague (textura de raio do pack esticada em cada trecho) e galhos
func bolt(a: Vector3, b: Vector3, col: Color, width := 1.0, life := .18, branches := 2) -> void:
	var n = 7
	var d = b - a
	var side = d.cross(Vector3.UP).normalized()
	if side.length() < .1: side = Vector3.RIGHT
	var up2 = d.cross(side).normalized()
	var pts = [a]
	for i in range(1, n):
		var u = float(i) / n
		pts.append(a + d * u + (side * randf_range(-1, 1) + up2 * randf_range(-1, 1)) * d.length() * .05 * sin(u * PI))
	pts.append(b)
	for i in pts.size() - 1:
		_stretch(pts[i], pts[i + 1], width * 2.2, "beam_soft", Color(col.r, col.g, col.b, .7), life * 1.3)
		_stretch(pts[i], pts[i + 1], width * 1.4, "spark_05", Color(1, 1, 1, 1), life)
	for k in branches:
		var o: Vector3 = pts[randi_range(1, n - 1)]
		var e = o + (d.normalized() * .4 + Vector3(randf_range(-1, 1), randf_range(-.5, .3), randf_range(-1, 1))).normalized() * d.length() * randf_range(.1, .22)
		_stretch(o, e, width * 1.2, "spark_06", Color(col.r, col.g, col.b, .9), life)
	sprite(b, "spark_02", col, width * 3.0, width * 6.0, life * 1.4, 4.0)
	sprite(b, "light_01", Color(col.r, col.g, col.b, .7), width * 2.0, width * 7.0, life * 1.5)

func slash(pos: Vector3, dir: Vector3, size: float, col: Color, life := .28, tname := "slash_04") -> void:
	var mi = MeshInstance3D.new(); mi.mesh = _quadm()
	var m = mat(tname, col, true, 0)
	mi.material_override = m
	_world().add_child(mi)
	mi.global_position = pos
	var f = dir.normalized()
	var up = Vector3.UP if abs(f.y) < .95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(f, up)
	mi.scale = Vector3.ONE * size
	items.append({"n": mi, "m": m, "t": 0.0, "life": life, "s0": size * .8, "s1": size * 1.2, "a": col.a, "spin": 0.0, "flat": true, "ease": true, "rot": 0.0, "keep_basis": true})

func smoke(pos: Vector3, col: Color, n := 6, size := 3.0, life := 1.6, rise := 2.0) -> void:
	for i in n:
		var p = pos + Vector3(randf_range(-1, 1), randf_range(0, .6), randf_range(-1, 1)) * size * .4
		var s = sprite(p, "smoke_0%d" % randi_range(1, 9), col, size * .5, size * randf_range(1.1, 1.6), life * randf_range(.7, 1.1), randf_range(-.6, .6), false)
		items[-1]["vel"] = Vector3(randf_range(-.5, .5), rise * randf_range(.5, 1.0), randf_range(-.5, .5))

## coluna de luz (ou de fogo/sangue) que sobe do chão
func pillar(pos: Vector3, radius: float, height: float, col: Color, life := .6, tname := "beam_soft") -> void:
	_stretch(pos, pos + Vector3(0, height, 0), radius * 2.4, tname, col, life)
	_stretch(pos, pos + Vector3(0, height, 0), radius * .8, "beam_core", Color(1, 1, 1, col.a), life * .8)
	shock(pos, col, radius * 1.6, life * .8)

## faíscas texturizadas (substitui os cubinhos)
func burst(pos: Vector3, col: Color, n := 16, speed := 10.0, size := .5, life := .5, tname := "star_04", grav := 0.0, alpha_blend := false) -> void:
	var p = CPUParticles3D.new()
	p.one_shot = true; p.amount = max(1, n); p.lifetime = life; p.explosiveness = 1.0; p.randomness = .5
	p.local_coords = false
	var q = QuadMesh.new(); q.size = Vector2.ONE * size
	q.material = mat(tname, col, not alpha_blend, 2, true)
	p.mesh = q
	p.direction = Vector3.UP; p.spread = 180
	p.initial_velocity_min = speed * .3; p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.angle_min = 0; p.angle_max = 360
	var cv = Curve.new(); cv.add_point(Vector2(0, 1)); cv.add_point(Vector2(.6, .8)); cv.add_point(Vector2(1, 0))
	p.scale_amount_curve = cv
	_world().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life * 1.6 + .2).timeout.connect(p.queue_free)

## aviso de carga: brilho que cresce, faíscas sugadas para o ponto e um selo vertical atrás
func charge(pos: Vector3, col: Color, dur := .7, size := 5.0, face := Vector3.ZERO) -> void:
	sprite(pos, "light_01", Color(col.r, col.g, col.b, .9), size * .2, size * 1.4, dur, 0.0, true, Vector3.ZERO, false)
	sprite(pos, "star_08", Color(1, 1, 1, .9), size * .1, size * .8, dur, 4.0, true, Vector3.ZERO, false)
	if face != Vector3.ZERO:
		sprite(pos - face.normalized() * .5, "magic_03", Color(col.r, col.g, col.b, .8), size * .4, size * 1.6, dur * 1.2, 1.5, true, face)
	var p = CPUParticles3D.new()
	p.one_shot = true; p.amount = 26; p.lifetime = dur; p.explosiveness = .2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = size * 1.2
	p.radial_accel_min = -size * 6.0; p.radial_accel_max = -size * 4.0
	p.gravity = Vector3.ZERO; p.initial_velocity_min = 0; p.initial_velocity_max = .5
	var q = QuadMesh.new(); q.size = Vector2.ONE * size * .14
	q.material = mat("star_06", col, true, 2, true)
	p.mesh = q
	var cv = Curve.new(); cv.add_point(Vector2(0, .4)); cv.add_point(Vector2(.7, 1)); cv.add_point(Vector2(1, 0)); p.scale_amount_curve = cv
	_world().add_child(p); p.global_position = pos; p.emitting = true
	get_tree().create_timer(dur * 1.6 + .2).timeout.connect(p.queue_free)

## brilho que acompanha um nó (projéteis, penas, mãos...)
func attach_glow(n: Node3D, col: Color, size := 2.0, trail := true, tname := "circle_05") -> Dictionary:
	var g = MeshInstance3D.new(); var q = QuadMesh.new(); q.size = Vector2.ONE * size; g.mesh = q
	var gm = mat(tname, col, true, 1)
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	var out = {"glow": g, "gm": gm}
	if trail:
		var tr = CPUParticles3D.new()
		tr.amount = 20; tr.lifetime = .35; tr.local_coords = false
		tr.gravity = Vector3.ZERO; tr.initial_velocity_min = 0; tr.initial_velocity_max = .3; tr.spread = 180
		var tq = QuadMesh.new(); tq.size = Vector2.ONE * size * .55
		tq.material = mat("circle_05", Color(col.r, col.g, col.b, col.a * .7), true, 2)
		tr.mesh = tq
		var cv = Curve.new(); cv.add_point(Vector2(0, 1)); cv.add_point(Vector2(1, 0)); tr.scale_amount_curve = cv
		n.add_child(tr)
		out.trail = tr
	return out

## anel texturizado deitado, para pôr dentro dos anéis de torus (ondas, marcas, auréolas)
## (a transparência acompanha a do material do anel)
var overlays: Array = []
func ring_overlay(ring: Node3D, col: Color, src: Material = null, tname := "circle_02") -> MeshInstance3D:
	var mi = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2.ONE * 2.3; mi.mesh = pm
	var m = mat(tname, Color(col.r, col.g, col.b, 1.0), true, 0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(mi)
	# brilho largo por baixo
	var mi2 = MeshInstance3D.new(); var pm2 = PlaneMesh.new(); pm2.size = Vector2.ONE * 2.6; mi2.mesh = pm2
	var m2 = mat("light_03", Color(col.r, col.g, col.b, .6), true, 0)
	mi2.material_override = m2; mi2.position.y = -.01
	ring.add_child(mi2)
	overlays.append({"n": ring, "src": src, "m": [m, m2], "a": [1.0, .6]})
	return mi

func _process(dt: float) -> void:
	var ko = []
	for o in overlays:
		if not is_instance_valid(o.n): continue
		if o.src and o.src is BaseMaterial3D:
			var a: float = o.src.albedo_color.a
			for i in 2: o.m[i].albedo_color.a = a * o.a[i] * 1.2
		ko.append(o)
	overlays = ko
	if G.state != "play" and G.state != "dead": return
	var cam = get_viewport().get_camera_3d()
	for it in items:
		it.t += dt
		var u: float = clamp(it.t / it.life, 0.0, 1.0)
		if not is_instance_valid(it.n):
			it.t = it.life + 1; continue
		if it.has("sigil"):
			# acende rápido, pulsa e apaga no fim
			var a = min(1.0, u * 6.0) * (1.0 - smoothstep(.85, 1.0, u)) * it.a
			for L in it.layers:
				L.n.rotation.y += L.spin * dt
				L.m.albedo_color.a = a * (.75 + .25 * sin(it.t * 18.0))
			continue
		var fade = 1.0 - u
		fade = fade * fade if it.get("ease", true) else fade
		it.m.albedo_color.a = it.a * fade
		if it.has("beam"):
			var w = it.w * (1.0 + .25 * sin(it.t * 60.0)) * (.6 + .4 * fade)
			it.n.scale.x = w; it.n.scale.y = w
			continue
		var e = 1.0 - pow(1.0 - u, 3.0)
		var s = lerp(it.s0, it.s1, e)
		if it.has("vel"): it.n.global_position += it.vel * dt
		it.rot += it.spin * dt
		if it.flat:
			if it.get("keep_basis", false):
				it.n.scale = Vector3.ONE * s
			else:
				var b: Basis = it.n.basis.orthonormalized()
				it.n.basis = b.rotated(b.y.normalized(), it.spin * dt) if it.spin != 0.0 else b
				it.n.scale = Vector3.ONE * s
		else:
			it.n.scale = Vector3.ONE * s
			if it.spin != 0.0: it.n.rotation.z = it.rot
	var keep = []
	for it in items:
		if it.t >= it.life:
			if is_instance_valid(it.n): it.n.queue_free()
		else: keep.append(it)
	items = keep
