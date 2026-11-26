extends Node3D
## Arena da Lilith: o TRONO DO ABISMO.
## Uma ilha de rocha vulcânica rachada no meio de um lago de lava, dentro de uma caverna infernal.
## Pentagrama invertido em brasa no chão, ossos e caveiras, correntes pendendo do teto, espinhos de
## obsidiana em volta, cachoeiras de lava nas paredes e um trono de chifres ao fundo.
## No INFERNO (fase 2) a lava sobe pelas bordas, o céu se acende e as rachaduras do chão brilham mais.

const R := 44.0
var t := 0.0
var inferno := 0.0
var m_rock: StandardMaterial3D
var m_rock2: StandardMaterial3D
var m_floor: Material
var m_obs: StandardMaterial3D
var m_bone: StandardMaterial3D
var m_iron: StandardMaterial3D
var lava_mat: ShaderMaterial
var fall_mat: ShaderMaterial
var cracks_mat: StandardMaterial3D
var sigil_mat: StandardMaterial3D
var lava: MeshInstance3D
var lava_y0 := -1.6
var chains: Array = []
var falls: Array = []
var lights: Array = []

## rocha de lava resfriada (textura enviada pelo jogador): as rachaduras vermelhas brilham e pulsam
const FLOOR_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float glow = 1.5;
uniform float time_s = 0.0;
uniform float scale = 0.09;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
vec3 tri(vec3 p, vec3 n){
	vec3 b = pow(abs(n), vec3(4.0)); b /= (b.x + b.y + b.z);
	return texture(tex, p.yz * scale).rgb * b.x + texture(tex, p.xz * scale).rgb * b.y + texture(tex, p.xy * scale).rgb * b.z;
}
void fragment(){
	vec3 c = tri(wp, wn);
	float m = clamp((c.r - c.g - .15) * 2.5, 0.0, 1.0);
	float flick = .85 + .15 * sin(time_s * 2.3 + wp.x * .4 + wp.z * .3);
	ALBEDO = c * (1.0 - m * .6);
	EMISSION = vec3(1.0, .32, .05) * m * glow * flick;
	ROUGHNESS = .9;
}
"""

const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float time_s = 0.0;
uniform float heat = 0.0;
uniform float scale = 70.0;
uniform vec2 flow = vec2(.08, .05);
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = .5; for (int i = 0; i < 5; i++){ v += a * n(p); p *= 2.1; a *= .5; } return v; }
void fragment(){
	vec2 w = UV * scale;
	float c = fbm(w * .5 + time_s * flow);
	float c2 = fbm(w * 1.3 - vec2(time_s * .12, -time_s * .03) + c * 2.0);
	float crust = smoothstep(.45, .7, c2);
	vec3 hot = mix(vec3(1.0, .35, .02), vec3(1.0, .85, .3), smoothstep(.2, .0, abs(c - .5)) );
	vec3 col = mix(hot * (1.0 + heat * .6), vec3(.1, .025, .02), clamp(crust * 1.2, 0.0, 1.0) * (1.0 - heat * .45));
	ALBEDO = col;
}
"""

func _noise_tex(freq: float, seed_: int, c0: Color, c1: Color) -> NoiseTexture2D:
	var nz = FastNoiseLite.new(); nz.seed = seed_; nz.frequency = freq; nz.fractal_octaves = 5
	var tx = NoiseTexture2D.new(); tx.width = 512; tx.height = 512; tx.seamless = true; tx.noise = nz
	var g = Gradient.new(); g.set_color(0, c0); g.set_color(1, c1); tx.color_ramp = g
	return tx

func _mats() -> void:
	m_rock = StandardMaterial3D.new()
	m_rock.albedo_texture = _noise_tex(.02, 13, Color("0e0808"), Color("3a2420"))
	# chão da ilha: rocha de lava resfriada com as rachaduras em brasa (textura enviada pelo jogador)
	if ResourceLoader.exists("res://lilith/lava_rocha.jpg"):
		m_floor = ShaderMaterial.new()
		var fsh = Shader.new(); fsh.code = FLOOR_SHADER
		m_floor.shader = fsh
		m_floor.set_shader_parameter("tex", load("res://lilith/lava_rocha.jpg"))
	m_rock.uv1_triplanar = true; m_rock.uv1_world_triplanar = true; m_rock.uv1_scale = Vector3.ONE * .07
	m_rock.roughness = .95
	m_rock2 = m_rock.duplicate(); m_rock2.albedo_color = Color(.7, .6, .6)
	m_obs = StandardMaterial3D.new(); m_obs.albedo_color = Color("120a10"); m_obs.metallic = .4; m_obs.roughness = .15
	m_obs.emission_enabled = true; m_obs.emission = Color("1a0202")
	m_bone = StandardMaterial3D.new(); m_bone.albedo_color = Color("c8b89a"); m_bone.roughness = .8
	m_iron = StandardMaterial3D.new(); m_iron.albedo_color = Color("2a2424"); m_iron.metallic = .8; m_iron.roughness = .45
	cracks_mat = StandardMaterial3D.new(); cracks_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; cracks_mat.albedo_color = Color(1, .35, .05)
	sigil_mat = StandardMaterial3D.new(); sigil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sigil_mat.albedo_color = Color(1, .15, .05)
	lava_mat = ShaderMaterial.new(); var sh = Shader.new(); sh.code = LAVA_SHADER; lava_mat.shader = sh

func _body(mi: Node3D, shape: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
	var cs = CollisionShape3D.new(); cs.shape = shape; sb.add_child(cs)
	if mi: sb.add_child(mi)
	sb.position = pos; sb.rotation = rot
	add_child(sb)
	return sb

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, par: Node3D = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation = rot
	(par if par else self).add_child(mi)
	return mi

func _cyl(r1: float, r2: float, h: float, mat: Material, pos: Vector3, col := true, seg := 16, rot := Vector3.ZERO) -> Node3D:
	var cm = CylinderMesh.new(); cm.top_radius = r1; cm.bottom_radius = r2; cm.height = h; cm.radial_segments = seg
	if not col: return _mesh(cm, mat, pos, rot)
	var mi = MeshInstance3D.new(); mi.mesh = cm; mi.material_override = mat
	var sh = CylinderShape3D.new(); sh.radius = max(r1, r2); sh.height = h
	return _body(mi, sh, pos, rot)

func _box(sz: Vector3, mat: Material, pos: Vector3, col := true, rot := Vector3.ZERO) -> Node3D:
	var bm = BoxMesh.new(); bm.size = sz
	if not col: return _mesh(bm, mat, pos, rot)
	var mi = MeshInstance3D.new(); mi.mesh = bm; mi.material_override = mat
	var sh = BoxShape3D.new(); sh.size = sz
	return _body(mi, sh, pos, rot)

func build(_m: Node) -> void:
	_mats()
	var rng = RandomNumberGenerator.new(); rng.seed = 666
	fall_mat = lava_mat.duplicate()
	fall_mat.set_shader_parameter("scale", 6.0)
	fall_mat.set_shader_parameter("flow", Vector2(0, -.9))
	# ilha de rocha
	if m_floor == null: m_floor = m_rock
	_cyl(R, R + 2, 3.0, m_floor, Vector3(0, -1.5, 0), true, 14)
	_cyl(R + 3, R - 6, 10, m_floor, Vector3(0, -8.0, 0), false, 14)
	# lago de lava em volta (e por baixo)
	var pm = PlaneMesh.new(); pm.size = Vector2(500, 500)
	lava = _mesh(pm, lava_mat, Vector3(0, lava_y0, 0))
	# rachaduras incandescentes no chão
	for i in 34:
		var a = rng.randf() * TAU
		var p0 = Vector3(cos(a), 0, sin(a)) * rng.randf_range(6, R - 4)
		var pc = p0
		for k in rng.randi_range(3, 6):
			var d = Vector3(cos(a + rng.randf_range(-1, 1)), 0, sin(a + rng.randf_range(-1, 1))) * rng.randf_range(1.0, 3.0)
			var b = _box(Vector3(rng.randf_range(.08, .22), .04, d.length()), cracks_mat, pc + d * .5 + Vector3(0, .01, 0), false)
			b.rotation.y = atan2(d.x, d.z)
			pc += d
			if pc.length() > R - 2: break
	# pentagrama invertido em brasa
	for rr in [24.0, 21.5]:
		var tm = TorusMesh.new(); tm.inner_radius = rr - .3; tm.outer_radius = rr; tm.rings = 96; tm.ring_segments = 4
		var rm = _mesh(tm, sigil_mat, Vector3(0, .03, 0)); rm.scale = Vector3(1, .12, 1)
	var pts = []
	for i in 5:
		var a = PI / 2 + i * TAU / 5.0 # ponta virada para o trono (invertido para quem entra)
		pts.append(Vector3(cos(a), 0, sin(a)) * 21.5)
	for i in 5:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[(i + 2) % 5]
		var bx = _box(Vector3(.4, .05, a.distance_to(b)), sigil_mat, (a + b) * .5 + Vector3(0, .03, 0), false)
		bx.rotation.y = atan2(b.x - a.x, b.z - a.z)
	# velas pretas nas pontas
	for q in pts:
		for k in 3:
			var o = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			var hh = rng.randf_range(.6, 1.4)
			_cyl(.12, .14, hh, m_obs, q + o + Vector3(0, hh * .5, 0), false, 6)
			var fl = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = .08; sm.height = .22; fl.mesh = sm
			fl.material_override = cracks_mat; fl.position = q + o + Vector3(0, hh + .1, 0); add_child(fl)
	# espinhos de obsidiana na borda (e paredes invisíveis)
	for i in 40:
		var a = i * TAU / 40.0 + rng.randf_range(-.04, .04)
		var hh = rng.randf_range(3, 12) * (1.6 if i % 5 == 0 else 1.0)
		var p = Vector3(cos(a), 0, sin(a)) * (R - 1.0 + rng.randf_range(-.5, 1.5))
		var cm = CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = rng.randf_range(.9, 1.8); cm.height = hh; cm.radial_segments = 5
		_mesh(cm, m_obs, p + Vector3(0, hh * .5 - .2, 0), Vector3(rng.randf_range(-.2, .2) - cos(a) * .0, 0, rng.randf_range(-.2, .2)))
	for i in 36:
		var a = i * TAU / 36.0
		var sh = BoxShape3D.new(); sh.size = Vector3(8.5, 60, 2)
		_body(null, sh, Vector3(cos(a), 0, sin(a)) * (R + .8) + Vector3(0, 30, 0), Vector3(0, -a + PI / 2, 0))
	# ossos e caveiras espalhados
	for i in 46:
		var a = rng.randf() * TAU; var d = rng.randf_range(4, R - 4)
		var p = Vector3(cos(a), 0, sin(a)) * d
		if i % 3 == 0:
			var sk = SphereMesh.new(); sk.radius = .35; sk.height = .6; sk.radial_segments = 8; sk.rings = 4
			_mesh(sk, m_bone, p + Vector3(0, .25, 0))
		else:
			var bc = CylinderMesh.new(); bc.top_radius = .07; bc.bottom_radius = .09; bc.height = rng.randf_range(.8, 1.6); bc.radial_segments = 5
			_mesh(bc, m_bone, p + Vector3(0, .1, 0), Vector3(PI / 2, rng.randf() * TAU, 0))
	# rochedos que servem de cobertura
	for i in 7:
		var a = i * TAU / 7.0 + .3
		var p = Vector3(cos(a), 0, sin(a)) * rng.randf_range(28, 34)
		var hh = rng.randf_range(3, 6)
		_cyl(rng.randf_range(1.2, 2.0), rng.randf_range(2.2, 3.2), hh, m_floor, p + Vector3(0, hh * .5, 0), true, 7)
	# trono de chifres ao fundo, sobre a lava
	var tz = -62.0
	_cyl(9, 12, 6, m_floor, Vector3(0, 1, tz), false, 9)
	_box(Vector3(8, 14, 2), m_obs, Vector3(0, 11, tz - 2), false)
	_box(Vector3(9, 1.2, 6), m_obs, Vector3(0, 4.6, tz), false)
	for sx in [-1, 1]:
		for k in 4:
			var hc = CylinderMesh.new(); hc.top_radius = 0.0; hc.bottom_radius = .9 - k * .12; hc.height = 9.0 - k * 1.2; hc.radial_segments = 6
			_mesh(hc, m_obs, Vector3(sx * (3.0 + k * 1.6), 15 + k * 1.5, tz - 2), Vector3(0, 0, sx * (-.35 - k * .25)))
	_box(Vector3(1.2, 6, .4), sigil_mat, Vector3(0, 13, tz - .9), false)
	_box(Vector3(3.6, .9, .4), sigil_mat, Vector3(0, 11.5, tz - .9), false)
	# paredes da caverna e estalactites
	for i in 22:
		var a = i * TAU / 22.0
		var d = rng.randf_range(95, 120)
		var hh = rng.randf_range(60, 110)
		var cm = CylinderMesh.new(); cm.top_radius = rng.randf_range(10, 20); cm.bottom_radius = rng.randf_range(16, 30); cm.height = hh; cm.radial_segments = 6
		_mesh(cm, m_rock, Vector3(cos(a) * d, hh * .5 - 6, sin(a) * d), Vector3(0, rng.randf() * TAU, 0))
		# cachoeira de lava em algumas paredes
		if i % 3 == 0:
			var fm = QuadMesh.new(); fm.size = Vector2(rng.randf_range(5, 9), hh * .8)
			var fall = _mesh(fm, fall_mat, Vector3(cos(a) * (d - 18), hh * .4 - 4, sin(a) * (d - 18)))
			fall.rotation.y = -a - PI / 2
			falls.append(fall)
			var fl = OmniLight3D.new(); fl.light_color = Color(1, .4, .1); fl.light_energy = 3.0; fl.omni_range = 40
			fl.position = Vector3(cos(a) * (d - 22), 8, sin(a) * (d - 22)); add_child(fl)
	for i in 40:
		var a = rng.randf() * TAU; var d = rng.randf_range(20, 90)
		var hh = rng.randf_range(6, 22)
		var cm = CylinderMesh.new(); cm.top_radius = rng.randf_range(1.5, 4); cm.bottom_radius = 0.0; cm.height = hh; cm.radial_segments = 5
		_mesh(cm, m_rock, Vector3(cos(a) * d, 70 - hh * .5, sin(a) * d))
	# teto
	_cyl(130, 130, 4, m_rock, Vector3(0, 72, 0), false, 12)
	# correntes pendendo do teto
	for i in 8:
		var a = i * TAU / 8.0 + .2
		var top = Vector3(cos(a), 0, sin(a)) * rng.randf_range(20, 38) + Vector3(0, 70, 0)
		var ln = rng.randi_range(18, 34)
		var ch = Node3D.new(); ch.position = top; add_child(ch)
		for k in ln:
			var lk = TorusMesh.new(); lk.inner_radius = .18; lk.outer_radius = .32; lk.rings = 10; lk.ring_segments = 4
			_mesh(lk, m_iron, Vector3(0, -k * .55, 0), Vector3(0, (k % 2) * PI / 2, PI / 2), ch)
		var hook = CylinderMesh.new(); hook.top_radius = .3; hook.bottom_radius = 0.0; hook.height = 1.2
		_mesh(hook, m_iron, Vector3(0, -ln * .55 - .5, 0), Vector3.ZERO, ch)
		chains.append({"n": ch, "ph": rng.randf() * TAU})
	# brasas no ar
	var em = CPUParticles3D.new()
	em.amount = 160; em.lifetime = 7.0; em.preprocess = 7.0
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; em.emission_box_extents = Vector3(60, 2, 60)
	em.position = Vector3(0, -1, 0)
	em.direction = Vector3.UP; em.spread = 20
	em.initial_velocity_min = 2.0; em.initial_velocity_max = 5.0; em.gravity = Vector3(.5, .4, 0)
	var eq = QuadMesh.new(); eq.size = Vector2(.14, .14)
	var emm = StandardMaterial3D.new(); emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emm.albedo_color = Color(1, .5, .15); emm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	eq.material = emm
	em.mesh = eq
	add_child(em)
	# luzes
	for i in 6:
		var a = i * TAU / 6.0
		var l = OmniLight3D.new(); l.light_color = Color(1, .3, .08); l.light_energy = 2.0; l.omni_range = 30
		l.position = Vector3(cos(a), 0, sin(a)) * 30 + Vector3(0, 4, 0)
		add_child(l); lights.append(l)
	var lc = OmniLight3D.new(); lc.light_color = Color(1, .2, .1); lc.light_energy = 2.0; lc.omni_range = 30
	lc.position = Vector3(0, 8, 0); add_child(lc); lights.append(lc)

func reset_state() -> void:
	inferno = 0.0

func _process(dt: float) -> void:
	t += dt
	lava_mat.set_shader_parameter("time_s", t)
	lava_mat.set_shader_parameter("heat", inferno)
	fall_mat.set_shader_parameter("time_s", t)
	# fase 2: a lava sobe até a beira da ilha
	lava.position.y = lerp(lava_y0, -.25, inferno) + sin(t * .7) * .08
	var pulse = .6 + .4 * sin(t * 2.0)
	if m_floor is ShaderMaterial:
		m_floor.set_shader_parameter("glow", (1.3 + .6 * pulse) * (1.0 + inferno * 1.3))
		m_floor.set_shader_parameter("time_s", t)
	cracks_mat.albedo_color = Color(1, .3 + .2 * pulse * (1.0 + inferno), .05) * (1.0 + inferno * .6)
	sigil_mat.albedo_color = Color(.8 + .2 * pulse + inferno * .4, .1 + inferno * .1, .04)
	for c in chains:
		c.n.rotation = Vector3(sin(t * .5 + c.ph) * .04, 0, cos(t * .4 + c.ph) * .04)
	for l in lights:
		l.light_energy = 1.8 + inferno * 2.0 + sin(t * 9.0 + l.position.x) * .2
