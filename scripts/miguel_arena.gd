extends Node3D
## Arena do Arcanjo Miguel: um santuário em ruínas suspenso no vazio, sob um eclipse.
## Piso circular de pedra negra com um selo de sangue, anel de colunas quebradas,
## arcos góticos partidos, rochas flutuando e um sol negro com coroa vermelha.

const R := 46.0
var m_stone: StandardMaterial3D
var m_stone2: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_sigil: StandardMaterial3D
var m_void: StandardMaterial3D
var rocks: Array = []
var sun: Node3D
var corona: MeshInstance3D
var t := 0.0
var sigil_mats: Array = []
var eclipse := 0.0 # 0..1, Miguel escurece o céu na segunda fase

func _noise_tex(freq: float, seed_: int, c0: Color, c1: Color) -> NoiseTexture2D:
	var n = FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 5
	var tx = NoiseTexture2D.new()
	tx.width = 512; tx.height = 512
	tx.seamless = true
	tx.noise = n
	var g = Gradient.new()
	g.set_color(0, c0); g.set_color(1, c1)
	tx.color_ramp = g
	return tx

func _mats() -> void:
	m_stone = StandardMaterial3D.new()
	m_stone.albedo_texture = _noise_tex(.012, 7, Color("15121a"), Color("4a4350"))
	m_stone.uv1_triplanar = true; m_stone.uv1_world_triplanar = true
	m_stone.uv1_scale = Vector3.ONE * .05
	m_stone.roughness = .85
	m_stone2 = m_stone.duplicate()
	m_stone2.albedo_color = Color(.8, .76, .86)
	m_gold = StandardMaterial3D.new()
	m_gold.albedo_color = Color("9a7428")
	m_gold.metallic = .6
	m_gold.roughness = .35
	m_gold.emission_enabled = true
	m_gold.emission = Color("2a1a04")
	m_sigil = StandardMaterial3D.new()
	m_sigil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_sigil.albedo_color = Color(.75, .03, .06)
	m_void = StandardMaterial3D.new()
	m_void.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_void.albedo_color = Color(0, 0, 0)

func _body(mesh_i: MeshInstance3D, shape: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	if mesh_i: sb.add_child(mesh_i)
	sb.position = pos
	sb.rotation = rot
	add_child(sb)
	return sb

func _cyl(r1: float, r2: float, h: float, mat: Material, pos: Vector3, col := true, seg := 16, rot := Vector3.ZERO) -> Node3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r1; cm.bottom_radius = r2; cm.height = h; cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	if not col:
		mi.position = pos; mi.rotation = rot
		add_child(mi)
		return mi
	var sh = CylinderShape3D.new(); sh.radius = max(r1, r2); sh.height = h
	return _body(mi, sh, pos, rot)

func _box(sz: Vector3, mat: Material, pos: Vector3, col := true, rot := Vector3.ZERO) -> Node3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	if not col:
		mi.position = pos; mi.rotation = rot
		add_child(mi)
		return mi
	var sh = BoxShape3D.new(); sh.size = sz
	return _body(mi, sh, pos, rot)

func build(_m: Node) -> void:
	_mats()
	# piso: disco grande, borda quebrada e degrau
	_cyl(R, R, 2.0, m_stone, Vector3(0, -1.0, 0), true, 64)
	_cyl(R + 3, R + 1, 1.2, m_stone2, Vector3(0, -2.4, 0), false, 64)
	# anel dourado e selo de sangue (hexagrama) gravado no chão
	for rr in [R - 3.0, 24.0, 9.0]:
		var ring = MeshInstance3D.new()
		var tm = TorusMesh.new(); tm.inner_radius = rr - .35; tm.outer_radius = rr; tm.rings = 96; tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = m_gold if rr > 30 else m_sigil
		if rr <= 30: sigil_mats.append(ring.material_override)
		ring.scale = Vector3(1, .15, 1)
		ring.position.y = .02
		add_child(ring)
	for s in 2:
		var pts = []
		for i in 3:
			var a = s * PI / 3.0 + i * TAU / 3.0
			pts.append(Vector3(cos(a), 0, sin(a)) * 24.0)
		for i in 3:
			var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 1) % 3]
			var ln = a.distance_to(b)
			var bx = _box(Vector3(.45, .05, ln), m_sigil, (a + b) * .5 + Vector3(0, .03, 0), false)
			_aim(bx, b + Vector3(0, .03, 0), Vector3.UP)
	# colunas quebradas em anel
	var rng = RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 18:
		var a = i * TAU / 18.0 + .08
		var p = Vector3(cos(a), 0, sin(a)) * (R - 6.5)
		var hgt = rng.randf_range(5.0, 22.0)
		if i % 3 == 0: hgt = rng.randf_range(2.0, 4.0) # tocos
		_cyl(1.9, 2.3, 1.2, m_stone2, p + Vector3(0, .6, 0), true, 8)
		_cyl(1.25, 1.4, hgt, m_stone, p + Vector3(0, 1.2 + hgt * .5, 0), true, 12)
		# topo quebrado, torto
		_cyl(.4, 1.4, 1.4, m_stone, p + Vector3(rng.randf_range(-.3, .3), 1.2 + hgt + .4, 0), false, 7, Vector3(rng.randf_range(-.4, .4), 0, rng.randf_range(-.4, .4)))
		if i % 2 == 1:
			var cap = _cyl(1.8, 1.8, .5, m_gold, p + Vector3(0, 1.2 + hgt * .62, 0), false, 12)
			cap.scale = Vector3(1, 1, 1)
		# pedaço caído
		if i % 4 == 2:
			var fa = a + .12
			var fp = Vector3(cos(fa), 0, sin(fa)) * (R - 12.0)
			_cyl(1.2, 1.2, 7.0, m_stone, fp + Vector3(0, 1.1, 0), true, 12, Vector3(PI / 2, -fa, 0))
	# arcos góticos partidos atrás das colunas
	for i in 9:
		var a = i * TAU / 9.0 + .2
		var p = Vector3(cos(a), 0, sin(a)) * (R + 1.5)
		var face = -a + PI / 2
		var hh = rng.randf_range(16, 30)
		for s in [-1, 1]:
			var off = Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * s * 4.2
			_box(Vector3(1.8, hh, 2.2), m_stone2, p + off + Vector3(0, hh * .5 - 1.5, 0), false, Vector3(0, face, 0))
		if i % 2 == 0:
			var arch = MeshInstance3D.new()
			var tm = TorusMesh.new(); tm.inner_radius = 3.4; tm.outer_radius = 5.0; tm.rings = 24; tm.ring_segments = 6
			arch.mesh = tm
			arch.material_override = m_stone2
			arch.position = p + Vector3(0, hh - 1.5, 0)
			arch.rotation = Vector3(PI / 2, face, 0)
			arch.scale = Vector3(1, .5, 1.3)
			add_child(arch)
	# parede invisível na borda (o vazio fica do lado de fora)
	for i in 36:
		var a = i * TAU / 36.0
		var sh = BoxShape3D.new(); sh.size = Vector3(9.0, 60, 2)
		_body(null, sh, Vector3(cos(a), 0, sin(a)) * (R + .5) + Vector3(0, 30, 0), Vector3(0, -a + PI / 2, 0))
	# rochas flutuando no vazio
	for i in 26:
		var a = rng.randf() * TAU
		var d = rng.randf_range(62, 120)
		var r = MeshInstance3D.new()
		var sm = SphereMesh.new(); sm.radius = rng.randf_range(1.5, 6.0); sm.height = sm.radius * rng.randf_range(1.0, 1.8); sm.radial_segments = 6; sm.rings = 3
		r.mesh = sm
		r.material_override = m_stone
		r.position = Vector3(cos(a) * d, rng.randf_range(-30, 35), sin(a) * d)
		r.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		add_child(r)
		rocks.append({"m": r, "y0": r.position.y, "ph": rng.randf() * TAU, "spin": rng.randf_range(-.2, .2)})
	# sol negro com coroa vermelha
	sun = Node3D.new()
	sun.position = Vector3(0, 95, -210)
	add_child(sun)
	var disc = MeshInstance3D.new()
	var dq = SphereMesh.new(); dq.radius = 34; dq.height = 68
	disc.mesh = dq
	disc.material_override = m_void
	sun.add_child(disc)
	corona = MeshInstance3D.new()
	var cq = QuadMesh.new(); cq.size = Vector2(150, 150)
	corona.mesh = cq
	var cm = StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cm.disable_fog = true
	cm.albedo_texture = _corona_tex()
	cm.albedo_color = Color(1, .35, .25, .9)
	corona.material_override = cm
	corona.position.z = -2
	sun.add_child(corona)
	disc.material_override = m_void.duplicate()
	(disc.material_override as StandardMaterial3D).disable_fog = true
	# luzes
	for i in 6:
		var a = i * TAU / 6.0
		var l = OmniLight3D.new()
		l.light_color = Color(.85, .18, .2) if i % 2 == 0 else Color(.5, .35, .9)
		l.light_energy = 2.2
		l.omni_range = 28
		l.position = Vector3(cos(a), 0, sin(a)) * 30 + Vector3(0, 7, 0)
		add_child(l)
	var lc = OmniLight3D.new()
	lc.light_color = Color(1, .8, .7)
	lc.light_energy = 1.2
	lc.omni_range = 40
	lc.position = Vector3(0, 18, 0)
	add_child(lc)

func _corona_tex() -> ImageTexture:
	var n = 256
	var img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c = Vector2(n, n) * .5
	var noise = FastNoiseLite.new()
	noise.frequency = .05
	for y in n:
		for x in n:
			var d = Vector2(x, y).distance_to(c) / (n * .5)
			var a = atan2(y - c.y, x - c.x)
			var rays = .55 + .45 * noise.get_noise_2d(cos(a) * 40, sin(a) * 40)
			var v = 0.0
			if d > .44: v = pow(clamp(1.0 - (d - .44) / (.56 * rays + .05), 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	return ImageTexture.create_from_image(img)

var rain: CPUParticles3D
func M_level() -> String:
	var mm = G.main
	return mm.level if mm else ""

func reset_state() -> void:
	eclipse = 0.0
	if rain: rain.emitting = false

func _process(dt: float) -> void:
	t += dt
	for r in rocks:
		r.m.position.y = r.y0 + sin(t * .3 + r.ph) * 1.5
		r.m.rotation.y += r.spin * dt
	if corona:
		var cm: StandardMaterial3D = corona.material_override
		cm.albedo_color = Color(1, .35 - eclipse * .2, .25 - eclipse * .15, .75 + .15 * sin(t * .8) + eclipse * .25)
		corona.scale = Vector3.ONE * (1.0 + eclipse * .35 + sin(t * .5) * .02)
	# eclipse: relâmpagos vermelhos no céu e chuva de sangue
	if eclipse > .5 and G.fx and M_level() == "miguel" and randf() < dt * .9:
		var a = randf() * TAU; var d = randf_range(80, 200)
		var b = Vector3(cos(a) * d, -30, sin(a) * d)
		G.fx.bolt(b + Vector3(randf_range(-30, 30), 160, randf_range(-30, 30)), b, Color(1, .1, .1), 3.0, .3, 3)
	if rain:
		rain.emitting = eclipse > .5 and M_level() == "miguel"
	elif eclipse > .5:
		rain = CPUParticles3D.new()
		rain.amount = 600; rain.lifetime = 1.2
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(46, 1, 46)
		rain.direction = Vector3(0, -1, 0); rain.spread = 2; rain.initial_velocity_min = 30; rain.initial_velocity_max = 36
		var dm = BoxMesh.new(); dm.size = Vector3(.04, .8, .04)
		var rm = StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(.55, 0, .03)
		dm.material = rm; rain.mesh = dm
		rain.position = Vector3(0, 36, 0)
		add_child(rain)
	var pulse = .55 + .45 * sin(t * 1.6)
	for m in sigil_mats:
		m.albedo_color = Color(.45 + .4 * pulse + eclipse * .3, .02, .05)

## look_at sem precisar estar na árvore (a arena é montada antes de entrar no mundo)
func _aim(n: Node3D, target: Vector3, up: Vector3) -> void:
	n.basis = Basis.looking_at(target - n.position, up)
