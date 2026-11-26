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
var m_cloud: StandardMaterial3D
var clouds2_mat: ShaderMaterial
var sun_mat: StandardMaterial3D
var rays_mat: StandardMaterial3D
var iris_mat: StandardMaterial3D
var feather_mat: StandardMaterial3D
var statue_mats: Array = []
var corrupted := false
var gore: Node3D
var _orig := {}
var arena_lights: Array = []
var corrupt_k := 0.0
var blood_rain: CPUParticles3D
var trumpet_fire: Array = []

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
	var g = Gradient.new(); g.set_color(0, Color("d6d0ca")); g.set_color(1, Color("fffdfa"))
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

var M: Node
func build(_m: Node) -> void:
	M = _m
	_mats()
	_floor()
	_balustrade()
	_trumpets()
	_platforms()
	_sky()
	_feathers()
	_heaven()
	_entrance()
	# luzes quentes
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4
		var l = OmniLight3D.new()
		l.light_color = Color(1, .82, .55)
		l.light_energy = 1.6
		l.omni_range = 34
		l.position = Vector3(cos(a), 0, sin(a)) * 24 + Vector3(0, 10, 0)
		add_child(l)
		arena_lights.append(l)

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
	clouds_mat.set_shader_parameter("c_lit", Vector3(1, 1, 1)); clouds_mat.set_shader_parameter("c_shadow", Vector3(.86, .9, .98)); clouds_mat.set_shader_parameter("c_deep", Vector3(.62, .7, .86))
	_mesh(pm, clouds_mat, Vector3(0, -22, 0))
	var c2 = clouds_mat.duplicate()
	c2.set_shader_parameter("c_lit", Vector3(1, .97, .9))
	clouds2_mat = c2
	var up = _mesh(pm, c2, Vector3(0, -12, 0))
	up.scale = Vector3(.6, 1, .6)
	# nuvens fofas em volta da praça
	var cm = StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.roughness = 1
	cm.emission_enabled = true
	cm.emission = Color(.5, .5, .56)
	m_cloud = cm
	var rng = RandomNumberGenerator.new(); rng.seed = 909
	for i in 34:
		var a = rng.randf() * TAU
		var d = rng.randf_range(56, 140)
		if absf(wrapf(a - PI / 2, -PI, PI)) < .5: a += PI   # deixa livre a vista do portão
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
	var dm = StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.albedo_color = Color(1, .97, .85); dm.disable_fog = true
	sun_mat = dm
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
	rm.albedo_color = Color(1, .92, .7, .55)
	rays.material_override = rm
	rays_mat = rm
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
	var im = StandardMaterial3D.new(); im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; im.albedo_color = Color(.95, .7, .2); im.disable_fog = true
	iris_mat = im
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
	feather_mat = fm
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = fm
	p.mesh = q
	add_child(p)

func reset_state() -> void:
	blare = 0.0
	purify()
	hall_state = "off"
	_set_gate(0.0)

func _process(dt: float) -> void:
	t += dt
	_upd_hall(dt)
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

# ---------- céu angelical: estátuas de anjo nas plataformas, nuvens e feixes de luz ----------
func _heaven() -> void:
	for i in 4:
		var a = i * TAU / 4.0 + PI / 4
		var dir = Vector3(cos(a), 0, sin(a))
		var hgt = 5.0 if i % 2 == 0 else 7.0
		var c = dir * 25.0 + dir * 2.4 + Vector3(0, hgt, 0)
		if ResourceLoader.exists("res://estatua/anjo_estatua.glb"):
			var st: Node3D = load("res://estatua/anjo_estatua.glb").instantiate()
			st.scale = Vector3.ONE * 4.2
			st.position = c
			st.rotation.y = atan2(dir.z, -dir.x) + PI   # de frente para o centro
			add_child(st)
			for mi in st.find_children("*", "MeshInstance3D", true, false):
				for si in mi.mesh.get_surface_count():
					var m0 = mi.mesh.surface_get_material(si)
					if m0 is StandardMaterial3D:
						var m: StandardMaterial3D = m0.duplicate()
						m.metallic = 0.0; m.metallic_texture = null; m.roughness = .7; m.roughness_texture = null
						m.emission_enabled = true; m.emission = Color(.12, .11, .1)
						mi.set_surface_override_material(si, m)
						statue_mats.append(m)
	# feixes de luz descendo do céu
	var bm = StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(1, .95, .8, .07); bm.cull_mode = BaseMaterial3D.CULL_DISABLED; bm.disable_fog = true
	_orig["beam"] = bm
	for i in 6:
		var a = i * TAU / 6.0 + .3
		var cm = CylinderMesh.new(); cm.top_radius = 2.5; cm.bottom_radius = 5.5; cm.height = 90; cm.cap_top = false; cm.cap_bottom = false; cm.radial_segments = 16
		var b = _mesh(cm, bm, Vector3(cos(a) * 30, 44, sin(a) * 30))
		b.rotation = Vector3(sin(a) * .12, 0, -cos(a) * .12)
	# fogo dentro das campanas (só aparece no modo infernal)
	for tr in trumpets:
		var fp = CPUParticles3D.new()
		fp.amount = 40; fp.lifetime = .9; fp.emitting = false
		fp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fp.emission_sphere_radius = 2.0
		fp.direction = Vector3(0, 0, -1); fp.spread = 25; fp.initial_velocity_min = 3; fp.initial_velocity_max = 7
		fp.gravity = Vector3(0, 6, 0); fp.scale_amount_min = .8; fp.scale_amount_max = 1.8
		var qm = QuadMesh.new(); qm.size = Vector2(1.4, 1.4)
		var fm = StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.albedo_texture = _soft_tex(); fm.albedo_color = Color(1, .35, .08, .8); fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = fm; fp.mesh = qm
		fp.position = Vector3(0, 0, -(15.0 + 3.0) - 5.0)
		tr.n.add_child(fp)
		trumpet_fire.append(fp)

# ---------- Gabriel corrompido: o céu vira inferno ----------
const HELL := {"marble": Color(.42, .09, .08), "marble2": Color(.22, .04, .04), "gold": Color(.32, .12, .06), "gold_e": Color(.5, .05, 0),
	"inlay": Color(.5, 0, 0), "inlay_e": Color(1, .08, .02), "cloud": Color(.45, .06, .04), "sun": Color(.9, .1, .03), "rays": Color(1, .15, .05, .5),
	"iris": Color(1, .05, .02), "feather": Color(.15, .02, .02), "statue": Color(.55, .2, .18), "light": Color(1, .25, .12)}

func _snap() -> void:
	if _orig.has("marble"): return
	_orig.marble = m_marble.albedo_color; _orig.marble2 = m_marble2.albedo_color
	_orig.gold = m_gold.albedo_color; _orig.gold_e = m_gold.emission; _orig.goldg_e = m_gold_glow.emission
	_orig.inlay = m_inlay.albedo_color; _orig.inlay_e = m_inlay.emission
	_orig.cloud = m_cloud.albedo_color if m_cloud else Color.WHITE
	_orig.sun = sun_mat.albedo_color if sun_mat else Color.WHITE
	_orig.rays = rays_mat.albedo_color if rays_mat else Color.WHITE
	_orig.iris = iris_mat.albedo_color if iris_mat else Color.WHITE
	_orig.feather = feather_mat.albedo_color if feather_mat else Color.WHITE
	_orig.c1 = [clouds_mat.get_shader_parameter("c_lit"), clouds_mat.get_shader_parameter("c_shadow"), clouds_mat.get_shader_parameter("c_deep")]
	_orig.c2 = [clouds2_mat.get_shader_parameter("c_lit"), clouds2_mat.get_shader_parameter("c_shadow"), clouds2_mat.get_shader_parameter("c_deep")] if clouds2_mat else []
	_orig.light = arena_lights[0].light_color if arena_lights.size() else Color.WHITE

func _set_corrupt(k: float) -> void:
	_snap()
	corrupt_k = k
	m_marble.albedo_color = _orig.marble.lerp(HELL.marble, k)
	m_marble2.albedo_color = _orig.marble2.lerp(HELL.marble2, k)
	m_gold.albedo_color = _orig.gold.lerp(HELL.gold, k); m_gold.emission = _orig.gold_e.lerp(HELL.gold_e, k)
	m_gold_glow.emission = _orig.goldg_e.lerp(Color(1, .1, 0), k)
	m_inlay.albedo_color = _orig.inlay.lerp(HELL.inlay, k); m_inlay.emission = _orig.inlay_e.lerp(HELL.inlay_e, k)
	if m_cloud: m_cloud.albedo_color = _orig.cloud.lerp(HELL.cloud, k); m_cloud.emission = Color(.5, .5, .56).lerp(Color(.25, 0, 0), k)
	if sun_mat: sun_mat.albedo_color = _orig.sun.lerp(HELL.sun, k)
	if rays_mat: rays_mat.albedo_color = _orig.rays.lerp(HELL.rays, k)
	if iris_mat: iris_mat.albedo_color = _orig.iris.lerp(HELL.iris, k)
	if feather_mat: feather_mat.albedo_color = _orig.feather.lerp(HELL.feather, k)
	if _orig.has("beam"): _orig.beam.albedo_color = Color(1, .95, .8, .07).lerp(Color(1, .1, .02, .1), k)
	for m in statue_mats: m.albedo_color = Color.WHITE.lerp(HELL.statue, k)
	var hell_c = [Vector3(.75, .12, .08), Vector3(.35, .03, .03), Vector3(.12, .01, .01)]
	for i in 3:
		clouds_mat.set_shader_parameter(["c_lit", "c_shadow", "c_deep"][i], (_orig.c1[i] as Vector3).lerp(hell_c[i], k))
		if clouds2_mat and _orig.c2.size() == 3: clouds2_mat.set_shader_parameter(["c_lit", "c_shadow", "c_deep"][i], (_orig.c2[i] as Vector3).lerp(hell_c[i], k))
	for l in arena_lights: l.light_color = (_orig.light as Color).lerp(HELL.light, k)

## chamado quando o Gabriel chega à metade da vida
func corrupt() -> void:
	if corrupted: return
	corrupted = true
	var tw = create_tween()
	tw.tween_method(_set_corrupt, 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	if M: G.later(1.2, func(): if corrupted and M.level == "gabriel": M.apply_env("gabriel_inferno"))
	for fp in trumpet_fire: fp.emitting = true
	_spawn_gore()

func purify() -> void:
	corrupted = false
	if _orig.has("marble"): _set_corrupt(0.0)
	for fp in trumpet_fire: fp.emitting = false
	if gore and is_instance_valid(gore): gore.queue_free()
	gore = null
	if M and M.level == "gabriel": M.apply_env("gabriel")

func _spawn_gore() -> void:
	if gore and is_instance_valid(gore): gore.queue_free()
	gore = Node3D.new(); add_child(gore)
	var rng = RandomNumberGenerator.new(); rng.seed = 666
	var tr = M.trono if M and M.get("trono") else null
	# poças e manchas de sangue pelo chão (aparecem aos poucos)
	for i in 26:
		var a = rng.randf() * TAU; var d = rng.randf_range(4, R - 6)
		var sz = rng.randf_range(2.0, 6.5)
		var mi = MeshInstance3D.new(); mi.mesh = _planem(Vector2(sz, sz))
		if tr: mi.material_override = tr.bm(1, float(i % 9) + .37)
		else:
			var bmm = StandardMaterial3D.new(); bmm.albedo_color = Color(.35, 0, .02); bmm.roughness = .1; mi.material_override = bmm
		mi.position = Vector3(cos(a) * d, .06 + i * .002, sin(a) * d); mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * .01
		gore.add_child(mi)
		var tw = mi.create_tween(); tw.tween_interval(rng.randf_range(.3, 3.0)); tw.tween_property(mi, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# corpos de anjos caídos jogados pela arena
	if ResourceLoader.exists("res://caida/anjo_caido.glb"):
		var scn = load("res://caida/anjo_caido.glb")
		var skin = StandardMaterial3D.new(); skin.albedo_color = Color(.62, .42, .4); skin.roughness = .6
		for i in 11:
			var a = rng.randf() * TAU; var d = rng.randf_range(9, R - 7)
			var body: Node3D = scn.instantiate()
			body.scale = Vector3.ONE * 2.6
			body.position = Vector3(cos(a) * d, .25, sin(a) * d)
			body.rotation = Vector3(-PI / 2 * (1 if rng.randf() < .6 else -1), rng.randf() * TAU, rng.randf_range(-.4, .4))
			gore.add_child(body)
			var ap = body.find_children("*", "AnimationPlayer", true, false)
			if ap.size():
				var anims = ["salto", "ataque", "desfile"]
				ap[0].play(anims[i % 3]); ap[0].seek(rng.randf_range(.2, 1.0), true); ap[0].pause()
			for mi in body.find_children("*", "MeshInstance3D", true, false):
				for si in mi.mesh.get_surface_count():
					var m0 = mi.mesh.surface_get_material(si)
					if m0 is StandardMaterial3D:
						var m: StandardMaterial3D = m0.duplicate(); m.albedo_color = Color(.7, .45, .42)
						mi.set_surface_override_material(si, m)
			var pm = MeshInstance3D.new(); pm.mesh = _planem(Vector2(5, 5))
			if tr: pm.material_override = tr.bm(1, float(i % 7) + 2.37)
			pm.position = Vector3(cos(a) * d, .09, sin(a) * d); pm.rotation.y = rng.randf() * TAU
			gore.add_child(pm)
	# sangue escorrendo das plataformas
	for p in plats:
		var ring: Node3D = p.ring
		var fall = MeshInstance3D.new(); var qm = QuadMesh.new(); qm.size = Vector2(1.2, p.y0 + 1.6)
		fall.mesh = qm
		var fm = StandardMaterial3D.new(); fm.albedo_color = Color(.45, 0, .02); fm.roughness = .1; fm.emission_enabled = true; fm.emission = Color(.15, 0, 0)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED; fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		fall.material_override = fm
		fall.position = Vector3(ring.position.x * 1.18, (p.y0 + 1.6) * .5, ring.position.z * 1.18)
		gore.add_child(fall)
	# chuva de sangue
	blood_rain = CPUParticles3D.new()
	blood_rain.amount = 500; blood_rain.lifetime = 1.6
	blood_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; blood_rain.emission_box_extents = Vector3(R, 1, R)
	blood_rain.direction = Vector3(0, -1, 0); blood_rain.spread = 3; blood_rain.initial_velocity_min = 26; blood_rain.initial_velocity_max = 32
	blood_rain.gravity = Vector3(0, -10, 0)
	var dm = BoxMesh.new(); dm.size = Vector3(.04, .7, .04)
	var drm = StandardMaterial3D.new(); drm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; drm.albedo_color = Color(.55, 0, .03)
	dm.material = drm; blood_rain.mesh = dm
	blood_rain.position = Vector3(0, 40, 0)
	gore.add_child(blood_rain)

## look_at sem precisar estar na árvore (a arena é montada antes de entrar no mundo)
func _aim(n: Node3D, target: Vector3, up: Vector3) -> void:
	n.basis = Basis.looking_at(target - n.position, up)


# =====================================================================
# ENTRADA: o Pórtico da Balança (fica longe da praça; o portão leva até o Átrio)
# Ruínas → praça com mosaico rachado e a balança dourada → escadaria entre dois blocos de mármore
# com anjos ajoelhados de espada → colunas e o portão dourado em arco, com luz atrás.
# =====================================================================
const HALL := Vector3(0, 0, 168)
const GATE_Z := -18.0
var hall_state := "off" # off | wait | open | done
var gate_l: Node3D
var gate_r: Node3D
var gate_open := 0.0
var gate_bodies: Array = []
var pans: Array = []
var hall_flames: Array = []
var m_red: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_gem: StandardMaterial3D

func _h(v: Vector3) -> Vector3:
	return HALL + v

func _entrance() -> void:
	m_red = StandardMaterial3D.new(); m_red.albedo_color = Color("7a0a10"); m_red.roughness = .35; m_red.metallic = .2
	m_red.emission_enabled = true; m_red.emission = Color("2a0002")
	m_dark = StandardMaterial3D.new()
	var nt = NoiseTexture2D.new(); var nz = FastNoiseLite.new(); nz.frequency = .03; nz.seed = 71
	nt.noise = nz; nt.seamless = true
	var g = Gradient.new(); g.set_color(0, Color("231c1a")); g.set_color(1, Color("5a4d46")); nt.color_ramp = g
	m_dark.albedo_texture = nt; m_dark.uv1_triplanar = true; m_dark.uv1_world_triplanar = true; m_dark.uv1_scale = Vector3.ONE * .12
	m_dark.roughness = .95
	m_gem = StandardMaterial3D.new(); m_gem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m_gem.albedo_color = Color(.4, 1, .35)
	var white_m = m_marble.duplicate()
	white_m.albedo_color = Color(1.05, 1.0, .98)
	# --- ruínas na chegada ---
	_box(Vector3(34, 1, 30), m_dark, _h(Vector3(0, -.5, 41)))
	var rng = RandomNumberGenerator.new(); rng.seed = 5150
	for i in 9:
		var sx = -1 if i % 2 == 0 else 1
		var p = Vector3(sx * rng.randf_range(6, 14), 0, rng.randf_range(30, 52))
		if i < 4:
			_cyl(.8, .9, rng.randf_range(5, 9), m_marble2, _h(p + Vector3(0, 0, 0)), true, 10, Vector3(PI / 2, rng.randf() * TAU, 0))
		else:
			var hh = rng.randf_range(1.5, 6.5)
			_cyl(.85, .95, hh, m_marble2, _h(p + Vector3(0, hh * .5, 0)), true, 10)
		for k in 3:
			_box(Vector3(rng.randf_range(.6, 1.6), rng.randf_range(.4, 1.0), rng.randf_range(.6, 1.4)), m_marble2, _h(p + Vector3(rng.randf_range(-2, 2), .3, rng.randf_range(-2, 2))), false, Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * .5))
	# encosta de pedra escura irregular dos dois lados das ruínas
	for sx in [-1, 1]:
		for k in 7:
			var rp = Vector3(sx * rng.randf_range(17, 21), rng.randf_range(0, 2), 28 + k * 4.2)
			var rs = SphereMesh.new(); rs.radius = rng.randf_range(2.5, 4.5); rs.height = rs.radius * rng.randf_range(1.2, 2.2); rs.radial_segments = 7; rs.rings = 4
			var rk = _mesh(rs, m_dark, _h(rp), Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * .4))
	# --- degraus da praça + braseiros verdes ---
	for k in 3:
		_box(Vector3(10, .4 * (k + 1), 1.0), white_m, _h(Vector3(0, .2 * (k + 1), 26.5 - k * 1.0)))
	_ramp(_h(Vector3(0, 0, 28.0)), _h(Vector3(0, 1.2, 25.0)), 10.0)
	for sx in [-1, 1]:
		_brazier(_h(Vector3(sx * 5.8, .0, 26.5)), true)
	# --- praça com mosaico rachado ---
	_box(Vector3(32, 1.2, 26), white_m, _h(Vector3(0, .6, 11)))
	var mc = _h(Vector3(0, 1.21, 11))
	_cyl(11.5, 11.5, .04, white_m, mc, false, 48)
	for rr in [11.0, 7.4, 3.8]:
		var tm = TorusMesh.new(); tm.inner_radius = rr - .28; tm.outer_radius = rr; tm.rings = 72; tm.ring_segments = 4
		var rm = _mesh(tm, m_red, mc + Vector3(0, .02, 0)); rm.scale = Vector3(1, .12, 1)
	for i in 24:
		var a = i * TAU / 24.0
		for seg in [[3.8, 7.4], [7.4, 11.0]]:
			if seg[0] > 5 and i % 2 == 1: continue
			var a0 = Vector3(cos(a), 0, sin(a)) * seg[0]; var a1 = Vector3(cos(a), 0, sin(a)) * seg[1]
			var bx = _box(Vector3(.18, .03, seg[1] - seg[0]), m_red, mc + (a0 + a1) * .5 + Vector3(0, .02, 0), false)
			bx.rotation.y = -a + PI / 2
	# rachaduras de sangue saindo do mosaico
	for i in 16:
		var a = rng.randf() * TAU
		var p0 = Vector3(cos(a), 0, sin(a)) * rng.randf_range(9, 12)
		var pc = p0
		for k in 4:
			var d = Vector3(cos(a + rng.randf_range(-.8, .8)), 0, sin(a + rng.randf_range(-.8, .8))) * rng.randf_range(.8, 1.8)
			var bx = _box(Vector3(.09, .025, d.length()), m_red, mc + pc + d * .5 + Vector3(0, .015, 0), false)
			bx.rotation.y = atan2(d.x, d.z)
			pc += d
	# pedestal da balança
	var pp = _h(Vector3(0, 1.2, 11))
	_cyl(1.7, 1.9, 2.4, white_m, pp + Vector3(0, 1.2, 0), true, 24)
	_cyl(1.95, 1.95, .25, m_red, pp + Vector3(0, .15, 0), false, 24)
	_cyl(1.8, 1.8, .2, m_red, pp + Vector3(0, 2.3, 0), false, 24)
	_balance(pp + Vector3(0, 2.4, 0))
	# --- escadaria principal (6 m) ---
	var steps = 15
	for k in steps:
		var top = 1.2 + (k + 1) * .4
		var zc = -.47 - k * .93
		_box(Vector3(14, top, .93), white_m, _h(Vector3(0, top * .5, zc)))
		_box(Vector3(14.2, .06, .1), m_red, _h(Vector3(0, top - .03, zc + .47)), false)
	# rampa invisível por cima dos degraus: sobe andando, sem precisar pular
	_ramp(_h(Vector3(0, 1.2, .93)), _h(Vector3(0, 7.2, -13.02)), 14.0)
	# patamar de cima
	_box(Vector3(26, 7.2, 18), white_m, _h(Vector3(0, 3.6, -23)))
	# --- blocos laterais com os anjos ---
	for sx in [-1, 1]:
		# bloco baixo (pedestal dos anjos) e torre alta atrás
		_box(Vector3(13, 6, 12), white_m, _h(Vector3(sx * 13.5, 3, -2)))
		_box(Vector3(13.2, .5, 12.2), m_red, _h(Vector3(sx * 13.5, 6.1, -2)), false)
		_box(Vector3(13.2, .35, 12.2), m_red, _h(Vector3(sx * 13.5, 1.5, -2)), false)
		_box(Vector3(11, 20, 22), white_m, _h(Vector3(sx * 14.5, 10, -19)))
		for yy in [8.0, 12.5, 19.6]:
			_box(Vector3(11.2, .35, 22.2), m_red, _h(Vector3(sx * 14.5, yy, -19)), false)
		# faixas verticais vermelhas na face da torre
		for xx in [9.4, 19.6]:
			_box(Vector3(.4, 12, .2), m_red, _h(Vector3(sx * xx, 14, -7.9)), false)
		# selo em ferradura com gema verde
		var tm = TorusMesh.new(); tm.inner_radius = 1.1; tm.outer_radius = 1.45; tm.rings = 32; tm.ring_segments = 6
		_mesh(tm, m_red, _h(Vector3(sx * 13.5, 17.2, -7.85)), Vector3(PI / 2, 0, 0))
		var gs = SphereMesh.new(); gs.radius = .35; gs.height = .7
		_mesh(gs, m_gem, _h(Vector3(sx * 13.5, 17.2, -7.6)))
		_hall_statue(_h(Vector3(sx * 13.5, 6.25, -3.5)), sx)
	# --- portão celestial (aberto: dá para ver o Átrio das Trombetas lá no fundo) ---
	_gate(white_m)
	# paredes invisíveis em volta da entrada
	for w in [[Vector3(0, 10, 56), Vector3(40, 20, 1)], [Vector3(-16.5, 10, 10), Vector3(1, 20, 60)], [Vector3(16.5, 10, 10), Vector3(1, 20, 60)], [Vector3(0, 20, GATE_Z - 4), Vector3(40, 40, 1)],
			[Vector3(-11.5, 14, GATE_Z), Vector3(8.6, 14, 1)], [Vector3(11.5, 14, GATE_Z), Vector3(8.6, 14, 1)]]:
		var sh = BoxShape3D.new(); sh.size = w[1]
		_body(null, sh, _h(w[0]))
	# sangue: escorrendo do portão escada abaixo, na balança e no mosaico
	if M and M.get("trono"):
		var tr = M.trono
		for k in 12:
			var top = 1.2 + (steps - k) * .4
			var zc = -.47 - (steps - 1 - k) * .93
			var f = _mesh(_planem(Vector2(rng.randf_range(1.0, 2.4), .9)), tr.bm(1, float(k % 9) + .37), _h(Vector3(-1.2 + sin(k * .7) * .8, top + .02, zc)))
			f.rotation.y = rng.randf() * .4
		for k in 5:
			var f2 = _mesh(_planem(Vector2(rng.randf_range(2, 4), rng.randf_range(2, 4))), tr.bm(1, float(k) + 1.37), _h(Vector3(rng.randf_range(-6, 6), 1.24, rng.randf_range(4, 18))))
			f2.rotation.y = rng.randf() * TAU
		var f3 = _mesh(_planem(Vector2(3.2, 3.2)), tr.bm(1, 3.37), pp + Vector3(.6, .04, 1.6))
	# luz vermelha do salão
	for l in [[Vector3(0, 12, 8), Color(1, .25, .22), 3.0, 34.0], [Vector3(-12, 9, -6), Color(1, .3, .3), 2.0, 18.0], [Vector3(12, 9, -6), Color(1, .3, .3), 2.0, 18.0], [Vector3(0, 6, 36), Color(.9, .35, .3), 1.4, 26.0]]:
		var ol = OmniLight3D.new(); ol.position = _h(l[0]); ol.light_color = l[1]; ol.light_energy = l[2]; ol.omni_range = l[3]
		add_child(ol)

func _cylm(r: float, h: float) -> CylinderMesh:
	var c = CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 6
	return c

func _planem(sz: Vector2) -> PlaneMesh:
	var p = PlaneMesh.new(); p.size = sz
	return p

func _brazier(p: Vector3, big: bool) -> void:
	var s = 1.0 if big else .8
	_cyl(.35 * s, .5 * s, 1.0 * s, m_marble2, p + Vector3(0, .5 * s, 0), true, 8)
	var bowl = CylinderMesh.new(); bowl.top_radius = .9 * s; bowl.bottom_radius = .45 * s; bowl.height = .55 * s; bowl.radial_segments = 14
	_mesh(bowl, m_red, p + Vector3(0, 1.25 * s, 0))
	var fl = CPUParticles3D.new()
	fl.amount = 26; fl.lifetime = .8
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fl.emission_sphere_radius = .45 * s
	fl.direction = Vector3.UP; fl.spread = 12
	fl.initial_velocity_min = 1.2; fl.initial_velocity_max = 2.2; fl.gravity = Vector3(0, 1.0, 0)
	fl.scale_amount_min = .6; fl.scale_amount_max = 1.1
	var q = QuadMesh.new(); q.size = Vector2(.5, .7) * s
	var fm = StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; fm.albedo_texture = _soft_tex(); fm.vertex_color_use_as_albedo = true
	q.material = fm
	fl.mesh = q
	var gr = Gradient.new(); gr.set_color(0, Color(1, 1, .9, .9)); gr.set_color(1, Color(.3, 1, .3, 0))
	fl.color_ramp = gr
	fl.position = p + Vector3(0, 1.5 * s, 0)
	add_child(fl)
	var l = OmniLight3D.new(); l.light_color = Color(.5, 1, .5); l.light_energy = 1.6; l.omni_range = 7
	l.position = p + Vector3(0, 2.2 * s, 0); add_child(l)
	hall_flames.append(l)

## a balança dourada: haste, águia de asas abertas com a gema verde, braço e dois pratos com correntes
func _balance(p: Vector3) -> void:
	var root = Node3D.new(); root.position = p; add_child(root)
	_mesh(_cylm(.12, 3.4), m_gold, Vector3(0, 1.7, 0), Vector3.ZERO, root)
	_mesh(_cylm(.45, .25), m_gold, Vector3(0, .12, 0), Vector3.ZERO, root)
	var arm = BoxMesh.new(); arm.size = Vector3(3.4, .14, .14)
	_mesh(arm, m_gold, Vector3(0, 3.0, 0), Vector3.ZERO, root)
	for sx in [-1, 1]:
		var w = BoxMesh.new(); w.size = Vector3(1.4, .1, .5)
		_mesh(w, m_gold, Vector3(sx * .65, 3.55, 0), Vector3(0, 0, sx * .55), root)
		var w2 = BoxMesh.new(); w2.size = Vector3(1.0, .08, .4)
		_mesh(w2, m_gold, Vector3(sx * .6, 3.25, 0), Vector3(0, 0, sx * .25), root)
	var gs = SphereMesh.new(); gs.radius = .18; gs.height = .36
	_mesh(gs, m_gem, Vector3(0, 3.35, .12), Vector3.ZERO, root)
	for sx in [-1, 1]:
		var pan = Node3D.new(); pan.position = Vector3(sx * 1.6, 3.0, 0); root.add_child(pan)
		for k in 3:
			var a = k * TAU / 3.0
			var ch = _mesh(_cylm(.02, 1.25), m_gold, Vector3(cos(a) * .25, -.6, sin(a) * .25), Vector3(sin(a) * .2, 0, -cos(a) * .2), pan)
		var dish = CylinderMesh.new(); dish.top_radius = .6; dish.bottom_radius = .35; dish.height = .18; dish.radial_segments = 16
		_mesh(dish, m_gold, Vector3(0, -1.25, 0), Vector3.ZERO, pan)
		pans.append({"n": pan, "s": sx})

## rampa de colisão (sem malha): a face de cima vai de a até b (a embaixo/na frente, b em cima/atrás)
func _ramp(a: Vector3, b: Vector3, width: float) -> void:
	var d = b - a
	var L = Vector2(d.z, d.y).length()
	var ang = atan2(d.y, -d.z)
	var th = .6
	var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = Vector3(width, th, L); cs.shape = bs
	sb.add_child(cs)
	var nrm = Vector3(0, cos(ang), sin(ang))
	sb.position = (a + b) * .5 - nrm * th * .5
	sb.rotation = Vector3(ang, 0, 0)
	add_child(sb)

func _hall_statue(p: Vector3, sx: int) -> void:
	if ResourceLoader.exists("res://estatua/anjo_estatua.glb"):
		# anjo de pé com as asas abertas (modelo novo)
		var st: Node3D = load("res://estatua/anjo_estatua.glb").instantiate()
		st.position = p + Vector3(0, -.25, 0)
		st.scale = Vector3.ONE * 7.6
		st.rotation.y = -PI / 2 - sx * .3   # de frente para quem sobe a escada
		add_child(st)
		# mármore fosco (sem o brilho metálico que deixava a estátua granulada)
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count():
				var m0 = mi.mesh.surface_get_material(si)
				if m0 is StandardMaterial3D:
					var m: StandardMaterial3D = m0.duplicate()
					m.metallic = 0.0; m.metallic_texture = null
					m.roughness = .75; m.roughness_texture = null
					m.normal_scale = .6
					m.albedo_color = Color(1.0, .96, .92)
					mi.set_surface_override_material(si, m)
		_blood_tears(st)
		var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
		var cs = CollisionShape3D.new(); var cy = CylinderShape3D.new(); cy.radius = 1.9; cy.height = 7.0; cs.shape = cy
		sb.add_child(cs); sb.position = p + Vector3(0, 3.3, 0)
		add_child(sb)
		return
	_hall_statue_old(p, sx)

## a estátua chora sangue: escorre dos olhos pelo rosto e pelo peito e pinga no pedestal
func _blood_tears(st: Node3D) -> void:
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(.55, 0, .03); bmat.roughness = .1; bmat.metallic = .1
	bmat.emission_enabled = true; bmat.emission = Color(.25, 0, .02)
	# coordenadas do modelo (rosto virado para +X, altura 1)
	for side in [-1.0, 1.0]:
		var zc = .063 + side * .0075   # olhos (o rosto fica um pouco de lado no modelo)
		var pts = [Vector3(.147, .636, zc), Vector3(.149, .624, zc + side * .002), Vector3(.148, .612, zc + side * .003),
			Vector3(.142, .598, zc + side * .004), Vector3(.152, .582, zc + side * .005), Vector3(.165, .562, zc + side * .006)]
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
			var d = b - a
			var mi = MeshInstance3D.new()
			var bx = BoxMesh.new(); bx.size = Vector3(.004, d.length() + .003, .0042 - i * .0003)
			mi.mesh = bx; mi.material_override = bmat
			mi.position = (a + b) * .5
			mi.rotation.z = atan2(d.x, -d.y)
			st.add_child(mi)
		# gota na ponta
		var gm = MeshInstance3D.new(); var sp = SphereMesh.new(); sp.radius = .004; sp.height = .009
		gm.mesh = sp; gm.material_override = bmat; gm.position = pts[-1]
		st.add_child(gm)
		# pingos caindo no pedestal
		var pt = CPUParticles3D.new()
		pt.amount = 6; pt.lifetime = 1.1
		pt.direction = Vector3(0, -1, 0); pt.spread = 4
		pt.initial_velocity_min = .2; pt.initial_velocity_max = .5
		pt.gravity = Vector3(0, -9.8, 0)
		var dm = SphereMesh.new(); dm.radius = .035; dm.height = .12; dm.radial_segments = 5; dm.rings = 3
		dm.material = bmat
		pt.mesh = dm
		pt.position = pts[-1] + Vector3(.004, -.004, 0)
		st.add_child(pt)

func _hall_statue_old(p: Vector3, sx: int) -> void:
	if not ResourceLoader.exists("res://anjo/anjo.glb") or M == null or M.get("trono") == null: return
	var inst: Node3D = load("res://anjo/anjo.glb").instantiate()
	inst.position = p
	inst.scale = Vector3.ONE * 1.55
	inst.rotation.y = -sx * .25 # de frente para quem sobe, levemente virado para a escada
	add_child(inst)
	var sh = Shader.new(); sh.code = M.trono.STATUE_SHADER
	var sm = ShaderMaterial.new(); sm.shader = sh; sm.set_shader_parameter("seed", 3.3 + sx)
	var steel = StandardMaterial3D.new(); steel.albedo_color = Color(.22, .2, .21); steel.metallic = .8; steel.roughness = .3
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var mat = mesh.surface_get_material(si)
			var nm = String(mat.resource_name) if mat else ""
			var m: Material = sm
			if nm.contains("PilarScreen"): m = m_gold
			elif nm.contains("Pilar"): m = m_red
			elif nm.contains("Red"): m = m_gem
			elif nm.contains("Gray"): m = steel
			mi.set_surface_override_material(si, m)

## portão inspirado nos portões do céu: colunas brancas caneladas com capitéis de ouro,
## arco dourado com brasão e coroa, folhas de grade em forma de harpa, anjos no alto e nuvens na base
func _gate(white_m: Material) -> void:
	var gz = GATE_Z
	var y0 = 7.2
	var HW = 3.4   # meia largura do vão
	var cloud_m = StandardMaterial3D.new(); cloud_m.albedo_color = Color(1, 1, 1); cloud_m.roughness = 1.0
	cloud_m.emission_enabled = true; cloud_m.emission = Color(.45, .42, .4)
	for sx in [-1, 1]:
		for cx in [HW + 1.0, HW + 3.3]:
			var cp = _h(Vector3(sx * cx, y0, gz))
			# plinto com friso de ouro
			_box(Vector3(2.1, 1.1, 2.1), white_m, cp + Vector3(0, .55, 0))
			_box(Vector3(2.2, .18, 2.2), m_gold, cp + Vector3(0, 1.12, 0), false)
			_cyl(.95, .95, .35, m_gold, cp + Vector3(0, 1.35, 0), false, 20)
			# fuste canelado
			_cyl(.78, .82, 10.0, white_m, cp + Vector3(0, 6.5, 0), true, 24)
			for f in 14:
				var fa = f * TAU / 14.0
				_box(Vector3(.1, 9.4, .1), m_marble2, cp + Vector3(cos(fa) * .8, 6.5, sin(fa) * .8), false)
			_cyl(.9, .9, .25, m_gold, cp + Vector3(0, 11.6, 0), false, 20)
			# capitel coríntio: tambor de ouro com folhas e volutas
			_cyl(1.25, .85, 1.3, m_gold, cp + Vector3(0, 12.4, 0), false, 20)
			for f in 8:
				var fa = f * TAU / 8.0
				var lf = _box(Vector3(.35, .9, .12), m_gold_glow, cp + Vector3(cos(fa) * 1.0, 12.3, sin(fa) * 1.0), false)
				lf.rotation = Vector3(0, -fa + PI / 2, -.35)
			for sz in [-1, 1]:
				var vt = TorusMesh.new(); vt.inner_radius = .18; vt.outer_radius = .34; vt.rings = 14; vt.ring_segments = 6
				_mesh(vt, m_gold, cp + Vector3(sz * 1.05, 12.9, .9), Vector3(PI / 2, 0, 0))
			_box(Vector3(2.4, .3, 2.4), m_gold, cp + Vector3(0, 13.2, 0), false)
			# nuvens na base
			for k in 4:
				var cs = SphereMesh.new(); cs.radius = randf_range(1.0, 1.7); cs.height = cs.radius * 1.4; cs.radial_segments = 10; cs.rings = 6
				_mesh(cs, cloud_m, cp + Vector3(randf_range(-1.6, 1.6), randf_range(.2, .8), randf_range(-1.4, 1.6)))
		# entablamento sobre o par de colunas, com friso de ouro
		var ec = _h(Vector3(sx * (HW + 2.15), y0 + 14.0, gz))
		_box(Vector3(5.0, 1.4, 2.8), white_m, ec)
		_box(Vector3(5.2, .22, 3.0), m_gold, ec + Vector3(0, -.75, 0), false)
		_box(Vector3(5.4, .3, 3.1), m_gold, ec + Vector3(0, .8, 0), false)
		for k in 6:
			_box(Vector3(.35, .9, .1), m_gold_glow, ec + Vector3(-2.0 + k * .8, 0, 1.42), false)
		# anjo no alto da coluna
		_mini_angel(ec + Vector3(0, .95, 0), 2.6, -PI / 2 + sx * .25)
	# arco dourado (duplo) com brasão e coroa
	var ac = _h(Vector3(0, y0 + 10.2, gz))
	for rr in [[HW + .35, .42, m_gold], [HW - .25, .2, m_gold_glow]]:
		var at = TorusMesh.new(); at.inner_radius = rr[0] - rr[1]; at.outer_radius = rr[0] + rr[1]; at.rings = 48; at.ring_segments = 8
		var am = _mesh(at, rr[2], ac, Vector3(PI / 2, 0, 0))
	# metade de baixo do arco escondida pelos pilares de ouro do vão
	for sx in [-1, 1]:
		_box(Vector3(.75, 10.2, .7), m_gold, _h(Vector3(sx * (HW + .35), y0 + 5.1, gz)), false)
		for k in 5:
			var sc = TorusMesh.new(); sc.inner_radius = .16; sc.outer_radius = .3; sc.rings = 12; sc.ring_segments = 5
			_mesh(sc, m_gold_glow, _h(Vector3(sx * (HW + .35), y0 + 1.5 + k * 1.9, gz + .4)), Vector3(PI / 2, 0, 0))
	# faixa dourada entre os entablamentos e o brasão
	_box(Vector3(2 * HW + 1.6, .9, .9), m_gold, ac + Vector3(0, HW + .9, 0), false)
	var cr = ac + Vector3(0, HW + 2.4, 0)
	var sd = SphereMesh.new(); sd.radius = .95; sd.height = 1.9
	_mesh(sd, m_gold_glow, cr)
	for i in 14:
		var a2 = i * TAU / 14.0
		var rl = 1.7 if i % 2 == 0 else 1.25
		var rb = _box(Vector3(.16, rl, .14), m_gold, cr + Vector3(cos(a2), sin(a2), 0) * (1.0 + rl * .5), false)
		rb.rotation.z = a2 - PI / 2
	for sx in [-1, 1]:
		for k in 3:
			var sv = TorusMesh.new(); sv.inner_radius = .3 + k * .05; sv.outer_radius = .48 + k * .05; sv.rings = 16; sv.ring_segments = 5
			_mesh(sv, m_gold, cr + Vector3(sx * (1.9 + k * 1.05), -.6 - k * .3, 0), Vector3(PI / 2, 0, 0))
	# coroa no topo
	_cyl(.8, .65, .5, m_gold, cr + Vector3(0, 2.2, 0), false, 12)
	for i in 6:
		var a3 = i * TAU / 6.0
		_box(Vector3(.18, .7, .18), m_gold, cr + Vector3(cos(a3) * .7, 2.75, sin(a3) * .7), false)
		var cg = SphereMesh.new(); cg.radius = .12; cg.height = .24
		_mesh(cg, m_gem, cr + Vector3(cos(a3) * .7, 3.15, sin(a3) * .7))
	var gl = OmniLight3D.new(); gl.light_color = Color(1, .9, .7); gl.light_energy = 3.0; gl.omni_range = 16
	gl.position = _h(Vector3(0, 12, gz + 3)); add_child(gl)
	# folhas do portão: grade em harpa com topo em arco e arabescos
	for sx in [-1, 1]:
		var hinge = Node3D.new()
		hinge.position = _h(Vector3(sx * HW, y0, gz))
		add_child(hinge)
		var n = 12
		for b in n:
			var bx = (b + .5) * HW / n
			var u = bx / HW
			var bh = 7.6 + 2.4 * sqrt(max(0.0, 1.0 - pow(1.0 - u, 2)))
			_mesh(_cylm(.045, bh), m_gold, Vector3(-sx * bx, bh * .5, 0), Vector3.ZERO, hinge)
			var tip = SphereMesh.new(); tip.radius = .09; tip.height = .18
			_mesh(tip, m_gold_glow, Vector3(-sx * bx, bh + .05, 0), Vector3.ZERO, hinge)
		for yy in [.4, 3.2, 6.6]:
			var bm2 = BoxMesh.new(); bm2.size = Vector3(HW, .16, .14)
			_mesh(bm2, m_gold, Vector3(-sx * HW * .5, yy, 0), Vector3.ZERO, hinge)
		for k in 3:
			var orn = TorusMesh.new(); orn.inner_radius = .3 + k * .18; orn.outer_radius = .4 + k * .18; orn.rings = 20; orn.ring_segments = 4
			_mesh(orn, m_gold, Vector3(-sx * HW * .5, 4.9, 0), Vector3(PI / 2, 0, 0), hinge)
		for k in 2:
			var sc2 = TorusMesh.new(); sc2.inner_radius = .25; sc2.outer_radius = .36; sc2.rings = 16; sc2.ring_segments = 4
			_mesh(sc2, m_gold_glow, Vector3(-sx * (HW * .25 + k * HW * .5), 1.8, 0), Vector3(PI / 2, 0, 0), hinge)
		var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
		var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = Vector3(HW, 10.5, .4); cs.shape = bs
		cs.position = Vector3(-sx * HW * .5, 5.2, 0); sb.add_child(cs); hinge.add_child(sb)
		gate_bodies.append(cs)
		if sx < 0: gate_l = hinge
		else: gate_r = hinge
	# braseiros e anjos voando dos dois lados
	for sx in [-1, 1]:
		_brazier(_h(Vector3(sx * 9.8, y0, gz + 4.0)), false)
		var fa = Node3D.new(); fa.position = _h(Vector3(sx * 10.5, y0 + 17.0, gz + 1.5)); add_child(fa)
		_mini_angel(fa, 2.2, -PI / 2 - sx * .5)
		flyers.append({"n": fa, "y0": fa.position.y, "ph": sx * 1.3})
	# ponte de nuvens e mármore até o Átrio (é o que se vê pelo vão do portão)
	var bz0 = gz - 4.0
	var bz1 = -HALL.z + R + 2.0
	var nseg = 14
	for k in nseg:
		var u = (k + .5) / nseg
		var zc = lerp(bz0, bz1, u)
		var yc = lerp(y0 - .3, -.3, u) - sin(u * PI) * 1.5
		_box(Vector3(6.0, .5, absf(bz1 - bz0) / nseg + .2), m_marble2, _h(Vector3(0, yc, zc)), false)
		_box(Vector3(6.3, .12, .3), m_gold, _h(Vector3(0, yc + .3, zc)), false)
		for sx in [-1, 1]:
			var cs3 = SphereMesh.new(); cs3.radius = randf_range(1.4, 2.4); cs3.height = cs3.radius * 1.2; cs3.radial_segments = 10; cs3.rings = 6
			_mesh(cs3, cloud_m, _h(Vector3(sx * randf_range(3.2, 4.4), yc - .6, zc + randf_range(-2, 2))))

var flyers: Array = []
## estátua de anjo pequena (o mesmo modelo dos anjos que choram sangue)
func _mini_angel(at, sc: float, ry: float) -> void:
	if not ResourceLoader.exists("res://estatua/anjo_estatua.glb"): return
	var st: Node3D = load("res://estatua/anjo_estatua.glb").instantiate()
	st.scale = Vector3.ONE * sc
	st.rotation.y = ry
	for mi in st.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var m0 = mi.mesh.surface_get_material(si)
			if m0 is StandardMaterial3D:
				var m: StandardMaterial3D = m0.duplicate()
				m.metallic = 0.0; m.metallic_texture = null; m.roughness = .7; m.roughness_texture = null
				m.emission_enabled = true; m.emission = Color(.3, .28, .25)
				mi.set_surface_override_material(si, m)
	if at is Node3D: at.add_child(st)
	else:
		st.position = at; add_child(st)

func _set_gate(u: float) -> void:
	gate_open = u
	if gate_l: gate_l.rotation.y = -u * 1.7
	if gate_r: gate_r.rotation.y = u * 1.7
	for cs in gate_bodies: cs.disabled = u > .5

## modo Gabriel: o jogador começa nas ruínas e sobe até o portão
func start_hall() -> void:
	hall_state = "wait"
	_set_gate(0.0)

func _upd_hall(dt: float) -> void:
	for f in flyers:
		f.n.position.y = f.y0 + sin(t * 1.1 + f.ph) * .6
		f.n.rotation.z = sin(t * .8 + f.ph) * .05
	for pn in pans:
		pn.n.rotation.z = sin(t * .9) * .06 * pn.s
		pn.n.position.y = 3.0 + sin(t * .9) * .08 * pn.s
	for l in hall_flames:
		l.light_energy = 1.4 + sin(t * 13.0 + l.position.x) * .25 + randf() * .15
	if hall_state == "off" or hall_state == "done" or G.player == null: return
	var lp: Vector3 = G.player.global_position - HALL
	if hall_state == "wait" and lp.z < GATE_Z + 7.0 and lp.y > 6.0:
		hall_state = "open"
		G.snd("slam", -4, .55); G.snd("angel", -6, .7)
		G.shake = max(G.shake, .3)
		var tw = create_tween()
		tw.tween_method(_set_gate, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if hall_state == "open" and lp.z < GATE_Z - .3:
		hall_state = "done"
		if M and M.has_method("gabriel_enter"): M.gabriel_enter()
