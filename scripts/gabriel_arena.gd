extends Node3D
## Arena do Gabriel: o ÁTRIO DAS TROMBETAS.
## Uma praça octogonal de mármore branco flutuando acima de um mar de nuvens douradas, ao nascer do sol.
## Oito trombetas gigantes de ouro apontam para o céu, quatro plataformas suspensas com escadas dão altura
## para enfrentar o arcanjo no ar, penas caem o tempo todo e um olho gigante no céu acompanha você.

const R := 46.0
var t := 0.0
var m_marble: StandardMaterial3D
var m_marble2: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_gold_glow: StandardMaterial3D
var m_inlay: StandardMaterial3D
var clouds_mat: ShaderMaterial
var puffs: Array = []
var plats: Array = []
var eye: Node3D
var eye_iris: MeshInstance3D
var eye_lid: Array = []
var trumpets: Array = []
var rays: MeshInstance3D
var blare := 0.0 # brilho das trombetas (Gabriel na segunda fase)

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
uniform float time_s = 0.0;
uniform vec3 c_lit = vec3(1.0, 0.86, 0.62);
uniform vec3 c_shadow = vec3(0.95, 0.55, 0.45);
uniform vec3 c_deep = vec3(0.55, 0.4, 0.55);
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = .5; for (int i = 0; i < 5; i++){ v += a * n(p); p *= 2.03; a *= .5; } return v; }
void fragment(){
	vec2 w = (UV - .5) * 60.0;
	float d = length(UV - .5) * 2.0;
	float c = fbm(w * .35 + vec2(time_s * .05, time_s * .02));
	float c2 = fbm(w * .9 - vec2(time_s * .03, 0.0));
	float v = smoothstep(.3, .75, c * .7 + c2 * .4);
	vec3 col = mix(c_deep, c_shadow, v);
	col = mix(col, c_lit, smoothstep(.55, .9, v + c2 * .2));
	ALBEDO = col;
	ALPHA = (1.0 - smoothstep(.75, 1.0, d)) * (.82 + .18 * v);
}
"""

func _mats() -> void:
	m_marble = StandardMaterial3D.new()
	var nt = NoiseTexture2D.new()
	var nz = FastNoiseLite.new(); nz.frequency = .02; nz.fractal_octaves = 5; nz.seed = 33
	nt.noise = nz; nt.seamless = true; nt.width = 512; nt.height = 512
	var g = Gradient.new(); g.set_color(0, Color("b8aea4")); g.set_color(1, Color("efe8e0"))
	nt.color_ramp = g
	m_marble.albedo_texture = nt
	m_marble.uv1_triplanar = true; m_marble.uv1_world_triplanar = true
	m_marble.uv1_scale = Vector3.ONE * .06
	m_marble.roughness = .35
	m_marble2 = m_marble.duplicate()
	m_marble2.albedo_color = Color(.88, .85, .82)
	m_gold = StandardMaterial3D.new()
	m_gold.albedo_color = Color("d8a640")
	m_gold.metallic = .75
	m_gold.roughness = .28
	m_gold.emission_enabled = true
	m_gold.emission = Color("3a2408")
	m_gold_glow = m_gold.duplicate()
	m_gold_glow.emission = Color("ffcf6a")
	m_gold_glow.emission_energy_multiplier = .6
	m_inlay = StandardMaterial3D.new()
	m_inlay.albedo_color = Color("e0b04a")
	m_inlay.metallic = .6
	m_inlay.roughness = .3
	m_inlay.emission_enabled = true
	m_inlay.emission = Color("ffc860")
	m_inlay.emission_energy_multiplier = .35

func _body(mi: Node3D, shape: Shape3D, pos: Vector3, rot := Vector3.ZERO, shape_pos := Vector3.ZERO) -> StaticBody3D:
	var sb = StaticBody3D.new()
	sb.collision_layer = 1; sb.collision_mask = 0
	var cs = CollisionShape3D.new(); cs.shape = shape; cs.position = shape_pos
	sb.add_child(cs)
	if mi: sb.add_child(mi)
	sb.position = pos; sb.rotation = rot
	add_child(sb)
	return sb

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, par: Node3D = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat
	mi.position = pos; mi.rotation = rot
	(par if par else self).add_child(mi)
	return mi

func _box(sz: Vector3, mat: Material, pos: Vector3, col := true, rot := Vector3.ZERO) -> Node3D:
	var bm = BoxMesh.new(); bm.size = sz
	if not col: return _mesh(bm, mat, pos, rot)
	var mi = MeshInstance3D.new(); mi.mesh = bm; mi.material_override = mat
	var sh = BoxShape3D.new(); sh.size = sz
	return _body(mi, sh, pos, rot)

func _cyl(r1: float, r2: float, h: float, mat: Material, pos: Vector3, col := true, seg := 16, rot := Vector3.ZERO) -> Node3D:
	var cm = CylinderMesh.new(); cm.top_radius = r1; cm.bottom_radius = r2; cm.height = h; cm.radial_segments = seg
	if not col: return _mesh(cm, mat, pos, rot)
	var mi = MeshInstance3D.new(); mi.mesh = cm; mi.material_override = mat
	var sh = CylinderShape3D.new(); sh.radius = max(r1, r2); sh.height = h
	return _body(mi, sh, pos, rot)

func build(_m: Node) -> void:
	_mats()
	_floor()
	_balustrade()
	_trumpets()
	_platforms()
	_sky()
	_feathers()
	# luzes quentes
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4
		var l = OmniLight3D.new()
		l.light_color = Color(1, .82, .55)
		l.light_energy = 1.6
		l.omni_range = 34
		l.position = Vector3(cos(a), 0, sin(a)) * 24 + Vector3(0, 10, 0)
		add_child(l)

# ---------- piso octogonal com estrela de ouro ----------
func _floor() -> void:
	_cyl(R, R, 2.0, m_marble, Vector3(0, -1.0, 0), true, 8)
	# borda em degraus por baixo (a praça flutua)
	_cyl(R + .6, R - 2, 2.4, m_marble2, Vector3(0, -3.2, 0), false, 8)
	_cyl(R - 3, 14, 18, m_marble2, Vector3(0, -13.4, 0), false, 8)
	_cyl(14, 2, 14, m_gold, Vector3(0, -29.4, 0), false, 8)
	# frisos de ouro na borda
	var tm = TorusMesh.new(); tm.inner_radius = R - .5; tm.outer_radius = R + .3; tm.rings = 8; tm.ring_segments = 6
	var ring = _mesh(tm, m_gold, Vector3(0, -.05, 0))
	ring.rotation.y = PI / 8
	ring.scale = Vector3(1, .5, 1)
	# estrela de 8 pontas e anéis embutidos
	for rr in [30.0, 13.0]:
		var t2 = TorusMesh.new(); t2.inner_radius = rr - .3; t2.outer_radius = rr; t2.rings = 96; t2.ring_segments = 4
		var rm = _mesh(t2, m_inlay, Vector3(0, .02, 0))
		rm.scale = Vector3(1, .12, 1)
	for i in 8:
		var a = i * TAU / 8.0
		var tip = Vector3(cos(a), 0, sin(a)) * 30.0
		for s in [-1, 1]:
			var b = Vector3(cos(a + s * PI / 8), 0, sin(a + s * PI / 8)) * 13.0
			var ln = b.distance_to(tip)
			var bx = _box(Vector3(.35, .04, ln), m_inlay, (b + tip) * .5 + Vector3(0, .02, 0), false)
			_aim(bx, tip + Vector3(0, .02, 0), Vector3.UP)
	# estrado central com o selo das trombetas
	_cyl(8.0, 8.6, .5, m_marble2, Vector3(0, .25, 0), true, 32)
	_cyl(6.5, 6.5, .08, m_inlay, Vector3(0, .52, 0), false, 32)
	var sun_disc = _cyl(2.2, 2.2, .1, m_gold_glow, Vector3(0, .58, 0), false, 24)
	for i in 16:
		var a = i * TAU / 16.0
		var ray_len = 3.6 if i % 2 == 0 else 2.7
		var rb = _box(Vector3(.22, .06, ray_len), m_gold, Vector3(cos(a), 0, sin(a)) * (2.2 + ray_len * .5) + Vector3(0, .56, 0), false)
		rb.rotation.y = -a + PI / 2

# ---------- balaustrada na borda + paredes invisíveis ----------
func _balustrade() -> void:
	for i in 8:
		var a0 = i * TAU / 8.0 + PI / 8
		var a1 = a0 + TAU / 8.0
		var p0 = Vector3(cos(a0), 0, sin(a0)) * (R - .8)
		var p1 = Vector3(cos(a1), 0, sin(a1)) * (R - .8)
		var ln = p0.distance_to(p1)
		var mid = (p0 + p1) * .5
		var rail = _box(Vector3(ln, .3, .6), m_marble2, mid + Vector3(0, 1.15, 0), false)
		_aim(rail, p1 + Vector3(0, 1.15, 0), Vector3.UP); rail.rotate_object_local(Vector3.UP, PI / 2)
		var base = _box(Vector3(ln, .3, .8), m_marble2, mid + Vector3(0, .15, 0), false)
		_aim(base, p1 + Vector3(0, .15, 0), Vector3.UP); base.rotate_object_local(Vector3.UP, PI / 2)
		for k in 14:
			var q = p0.lerp(p1, (k + .5) / 14.0)
			_cyl(.12, .2, .9, m_marble, q + Vector3(0, .75, 0), false, 6)
		# parede invisível (alta, Gabriel e os projéteis continuam livres por cima)
		var sh = BoxShape3D.new(); sh.size = Vector3(ln + 1, 60, 1.2)
		var wall = _body(null, sh, mid + Vector3(0, 30, 0))
		_aim(wall, p1 + Vector3(0, 30, 0), Vector3.UP); wall.rotate_object_local(Vector3.UP, PI / 2)

# ---------- oito trombetas gigantes ----------
func _trumpets() -> void:
	for i in 8:
		var a = i * TAU / 8.0
		var dir = Vector3(cos(a), 0, sin(a))
		var base = dir * (R - 4.5)
		# pedestal
		_cyl(2.3, 2.8, 2.0, m_marble2, base + Vector3(0, 1.0, 0), true, 8)
		_cyl(2.5, 2.5, .3, m_gold, base + Vector3(0, 2.1, 0), false, 8)
		var tr = Node3D.new()
		tr.position = base + Vector3(0, 2.2, 0)
		add_child(tr)
		# inclinada para fora e para cima
		_aim(tr, tr.position + dir * .8 + Vector3(0, 1, 0), Vector3.UP if abs(dir.y) < .9 else Vector3.FORWARD)
		var L = 15.0 + (i % 2) * 3.0
		var tube = CylinderMesh.new(); tube.top_radius = .32; tube.bottom_radius = .45; tube.height = L; tube.radial_segments = 12
		_mesh(tube, m_gold, Vector3(0, 0, -L * .5), Vector3(PI / 2, 0, 0), tr)
		# anéis do tubo
		for k in 3:
			var rg = TorusMesh.new(); rg.inner_radius = .38; rg.outer_radius = .58; rg.rings = 16; rg.ring_segments = 6
			_mesh(rg, m_gold_glow, Vector3(0, 0, -L * (.2 + k * .25)), Vector3(PI / 2, 0, 0), tr)
		# campana
		var bell = CylinderMesh.new(); bell.top_radius = 3.0; bell.bottom_radius = .4; bell.height = 6.0; bell.radial_segments = 20; bell.rings = 6
		bell.cap_top = false
		_mesh(bell, m_gold, Vector3(0, 0, -L - 2.9), Vector3(-PI / 2, 0, 0), tr)
		var lip = TorusMesh.new(); lip.inner_radius = 2.85; lip.outer_radius = 3.3; lip.rings = 32; lip.ring_segments = 6
		_mesh(lip, m_gold_glow, Vector3(0, 0, -L - 5.9), Vector3(PI / 2, 0, 0), tr)
		# luz de dentro da campana
		var glow = MeshInstance3D.new()
		var dq = QuadMesh.new(); dq.size = Vector2(6.5, 6.5)
		glow.mesh = dq
		var gm = StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_texture = _soft_tex()
		gm.albedo_color = Color(1, .8, .45, .35)
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow.material_override = gm
		glow.position = Vector3(0, 0, -L - 5.5)
		tr.add_child(glow)
		trumpets.append({"n": tr, "g": gm, "ph": i * .7})

var _st: ImageTexture
func _soft_tex() -> ImageTexture:
	if _st: return _st
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d = Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_st = ImageTexture.create_from_image(img)
	return _st

# ---------- plataformas suspensas com escadas ----------
func _platforms() -> void:
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4
		var dir = Vector3(cos(a), 0, sin(a))
		var c = dir * 25.0
		var hgt = 5.0 if i % 2 == 0 else 7.0
		var pl = Node3D.new()
		add_child(pl)
		# disco flutuante
		_cyl(4.6, 4.6, .8, m_marble, c + Vector3(0, hgt - .4, 0), true, 8)
		_cyl(4.8, 4.8, .25, m_gold, c + Vector3(0, hgt - .85, 0), false, 8)
		_cyl(3.6, .6, 3.0, m_marble2, c + Vector3(0, hgt - 2.4, 0), false, 8)
		# anel de luz sob a plataforma
		var lr = TorusMesh.new(); lr.inner_radius = 3.9; lr.outer_radius = 4.2; lr.rings = 32; lr.ring_segments = 4
		var lm = _mesh(lr, m_gold_glow, c + Vector3(0, hgt - 1.6, 0))
		plats.append({"ring": lm, "y0": hgt - 1.6, "ph": i})
		# escada em espiral para dentro (degraus flutuantes)
		var side = Vector3(-dir.z, 0, dir.x)
		var steps = int(hgt / .55)
		for k in steps:
			var u = (k + 1.0) / steps
			var p = c - dir * (5.2 + k * .25) + side * (5.0 * (1.0 - u) - 1.0) + Vector3(0, u * hgt - .3, 0)
			var st = _box(Vector3(2.2, .3, 1.2), m_marble2, p, true)
			_aim(st, p + dir, Vector3.UP)
		# pequeno obelisco com auréola em cima
		_cyl(.25, .5, 3.0, m_marble2, c + Vector3(0, hgt + 1.5, 0), false, 6)
		var hr = TorusMesh.new(); hr.inner_radius = .7; hr.outer_radius = .85; hr.rings = 24; hr.ring_segments = 4
		_mesh(hr, m_gold_glow, c + Vector3(0, hgt + 3.4, 0), Vector3(PI / 2, -a + PI / 2, 0))

# ---------- céu: mar de nuvens, sol nascente, olho no céu ----------
func _sky() -> void:
	var pm = PlaneMesh.new(); pm.size = Vector2(900, 900); pm.subdivide_width = 1; pm.subdivide_depth = 1
	clouds_mat = ShaderMaterial.new()
	var sh = Shader.new(); sh.code = CLOUD_SHADER
	clouds_mat.shader = sh
	_mesh(pm, clouds_mat, Vector3(0, -22, 0))
	var c2 = clouds_mat.duplicate()
	c2.set_shader_parameter("c_lit", Vector3(1, .92, .78))
	var up = _mesh(pm, c2, Vector3(0, -12, 0))
	up.scale = Vector3(.6, 1, .6)
	# nuvens fofas em volta da praça
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color(1, .93, .84)
	cm.roughness = 1
	cm.emission_enabled = true
	cm.emission = Color(.55, .38, .3)
	var rng = RandomNumberGenerator.new(); rng.seed = 909
	for i in 34:
		var a = rng.randf() * TAU
		var d = rng.randf_range(56, 140)
		var cl = Node3D.new()
		cl.position = Vector3(cos(a) * d, rng.randf_range(-14, 10), sin(a) * d)
		add_child(cl)
		for k in rng.randi_range(3, 6):
			var s = SphereMesh.new(); s.radius = rng.randf_range(3, 8); s.height = s.radius * 1.6; s.radial_segments = 10; s.rings = 6
			_mesh(s, cm, Vector3(rng.randf_range(-7, 7), rng.randf_range(-1, 2), rng.randf_range(-7, 7)), Vector3.ZERO, cl)
		puffs.append({"n": cl, "a": a, "d": d, "spd": rng.randf_range(.004, .012)})
	# sol nascente atrás com raios
	var sun = Node3D.new()
	sun.position = Vector3(0, 18, -260)
	add_child(sun)
	var disc = SphereMesh.new(); disc.radius = 26; disc.height = 52
	var dm = StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.albedo_color = Color(1, .9, .6); dm.disable_fog = true
	_mesh(disc, dm, Vector3.ZERO, Vector3.ZERO, sun)
	rays = MeshInstance3D.new()
	var rq = QuadMesh.new(); rq.size = Vector2(260, 260)
	rays.mesh = rq
	var rm = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.disable_fog = true
	rm.albedo_texture = _rays_tex()
	rm.albedo_color = Color(1, .75, .45, .55)
	rays.material_override = rm
	rays.position.z = -3
	sun.add_child(rays)
	# o olho no céu (Gabriel, o Arauto de Muitos Olhos, está sempre olhando)
	eye = Node3D.new()
	eye.position = Vector3(0, 150, -230)
	add_child(eye)
	var white = MeshInstance3D.new()
	var wq = QuadMesh.new(); wq.size = Vector2(70, 34)
	white.mesh = wq
	var wm = StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.disable_fog = true
	wm.albedo_texture = _eye_tex()
	white.material_override = wm
	eye.add_child(white)
	eye_iris = MeshInstance3D.new()
	var iq = SphereMesh.new(); iq.radius = 8; iq.height = 2
	eye_iris.mesh = iq
	var im = StandardMaterial3D.new(); im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; im.albedo_color = Color(.95, .55, .1); im.disable_fog = true
	eye_iris.material_override = im
	eye_iris.position.z = .5
	eye.add_child(eye_iris)
	var pup = MeshInstance3D.new()
	var pq = SphereMesh.new(); pq.radius = 3.4; pq.height = 1
	pup.mesh = pq
	var pmm = StandardMaterial3D.new(); pmm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pmm.albedo_color = Color(.08, .02, .02); pmm.disable_fog = true
	pup.material_override = pmm
	pup.position.z = 1.0
	eye_iris.add_child(pup)

func _rays_tex() -> ImageTexture:
	var n = 256
	var img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c = Vector2(n, n) * .5
	for y in n:
		for x in n:
			var v = Vector2(x, y) - c
			var d = v.length() / (n * .5)
			var a = atan2(v.y, v.x)
			var r = pow(abs(sin(a * 9.0)), 6.0) * .8 + .2
			var al = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, al * al * r))
	return ImageTexture.create_from_image(img)

func _eye_tex() -> ImageTexture:
	var w = 256; var h2 = 124
	var img = Image.create(w, h2, false, Image.FORMAT_RGBA8)
	for y in h2:
		for x in w:
			var u = (x - w * .5) / (w * .5)
			var v = (y - h2 * .5) / (h2 * .5)
			var edge = 1.0 - u * u # forma de amêndoa
			var inside = abs(v) < edge
			var a = 0.0
			if inside: a = clamp((edge - abs(v)) * 8.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, .97, .9, a * .95))
	return ImageTexture.create_from_image(img)

# ---------- penas caindo ----------
func _feathers() -> void:
	var p = CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(48, 1, 48)
	p.position = Vector3(0, 32, 0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25
	p.initial_velocity_min = 1.0; p.initial_velocity_max = 2.5
	p.gravity = Vector3(.4, -.6, 0)
	p.angular_velocity_min = -90; p.angular_velocity_max = 90
	p.scale_amount_min = .6; p.scale_amount_max = 1.2
	var q = QuadMesh.new(); q.size = Vector2(.18, .5)
	var fm = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1, .97, .9)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = fm
	p.mesh = q
	add_child(p)

func reset_state() -> void:
	blare = 0.0

func _process(dt: float) -> void:
	t += dt
	if clouds_mat: clouds_mat.set_shader_parameter("time_s", t)
	for pf in puffs:
		pf.a += pf.spd * dt
		pf.n.position.x = cos(pf.a) * pf.d
		pf.n.position.z = sin(pf.a) * pf.d
	for p in plats:
		p.ring.position.y = p.y0 + sin(t * 1.2 + p.ph) * .15
		p.ring.rotation.y += dt * .4
	if rays: rays.rotation.z += dt * .03
	var gb = G.boss if G.boss and is_instance_valid(G.boss) and G.boss.get("kind") == "gabriel" else null
	var hot: float = blare
	if gb and gb.get("ph2"): hot = max(hot, .6)
	for tr in trumpets:
		tr.g.albedo_color.a = .25 + .2 * sin(t * 1.5 + tr.ph) + hot * .5
	# olho do céu acompanha o jogador e pisca de vez em quando
	if eye and G.player:
		var to: Vector3 = (G.player.global_position - eye.global_position)
		var lx: float = clamp(to.x / 200.0, -.4, .4)
		var ly: float = clamp((to.y + 60.0) / 200.0, -.35, .35)
		eye_iris.position.x = lerp(eye_iris.position.x, lx * 30.0, 1.0 - exp(-3.0 * dt))
		eye_iris.position.y = lerp(eye_iris.position.y, ly * 22.0, 1.0 - exp(-3.0 * dt))
		var blink: float = 0.0
		var bp: float = fmod(t, 7.0)
		if bp > 6.7: blink = sin((bp - 6.7) / .3 * PI)
		eye.scale.y = lerp(1.0, .05, blink)

## look_at sem precisar estar na árvore (a arena é montada antes de entrar no mundo)
func _aim(n: Node3D, target: Vector3, up: Vector3) -> void:
	n.basis = Basis.looking_at(target - n.position, up)
