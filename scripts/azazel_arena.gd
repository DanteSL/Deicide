extends Node3D
## Arena do Azazel: O OLHO DA TEMPESTADE.
## Um templo circular de pedra molhada flutuando sobre um mar de nuvens de tempestade, à noite.
## Lajes de pedra com rejunte, poças de chuva, três anéis de runas que brilham, um grande olho em mosaico
## no centro, oito torres-para-raio de obsidiana com coroas de cobre e olhos de pedra, pilares quebrados,
## ilhas de rocha flutuando, chuva e relâmpagos caindo ao longe.
## Segunda fase (o Azazel chora sangue): o céu fica vermelho, a chuva vira sangue, as runas sangram,
## os olhos das torres choram e o chão se enche de poças de sangue.

const R := 44.0
var t := 0.0
var phase2 := 0.0
var M: Node
var m_floor: ShaderMaterial
var m_stone: StandardMaterial3D
var m_stone2: StandardMaterial3D
var m_obs: StandardMaterial3D
var m_copper: StandardMaterial3D
var m_rune: StandardMaterial3D
var m_eye: ShaderMaterial
var clouds_mat: ShaderMaterial
var rain: CPUParticles3D
var rain_mat: StandardMaterial3D
var spires: Array = []
var tears: Array = []
var lights: Array = []
var sky_bolt_cd := 2.0
var flash_l: OmniLight3D
var flash_k := 0.0
var rocks: Array = []

const FLOOR_SHADER := """
shader_type spatial;
uniform float time_s = 0.0;
uniform float blood = 0.0;      // 0 = chuva, 1 = sangue
uniform vec3 rune_col = vec3(.35, .8, 1.0);
uniform float flash = 0.0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = .5, s = 0.0; for (int i = 0; i < 5; i++) { s += vn(p) * a; p *= 2.03; a *= .5; } return s; }
// lajes: voronoi (distância até a borda da célula + id)
vec3 vor(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 9.0, d2 = 9.0; vec2 id = vec2(0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = h22(i + g) * .8 + .1;
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
	}
	return vec3(d2 - d1, h21(id), h21(id + 7.3));
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// lajes em anéis: coordenada polar para as pedras seguirem o círculo perto do centro
	vec3 v = vor(p * .33);
	float grout = smoothstep(.02, .07, v.x);
	float grain = fbm(p * 1.7 + v.y * 10.0);
	float fine = fbm(p * 9.0);
	vec3 base = mix(vec3(.13, .14, .16), vec3(.27, .27, .3), v.y * .6 + grain * .5);
	base *= .85 + fine * .3;
	// musgo/sal nas juntas e manchas de liquens
	base = mix(base, vec3(.18, .2, .17), smoothstep(.6, .8, fbm(p * .4 + 3.0)) * .35);
	vec3 col = mix(vec3(.04, .045, .05), base, grout);
	// poças de chuva: escuras e espelhadas
	float pud = smoothstep(.56, .66, fbm(p * .12 + vec2(4.0, 1.0)));
	float rough = mix(.62, .08, max(pud, (1.0 - grout) * .5));
	col *= 1.0 - pud * .35;
	// anéis de runas (três)
	float em = 0.0;
	for (int k = 0; k < 3; k++) {
		float rr = 12.0 + float(k) * 10.0;
		float band = 1.0 - smoothstep(.0, .12, abs(abs(r - rr) - .55));
		float seg = floor((ang + 3.14159) / 6.28318 * (24.0 + float(k) * 12.0));
		float sh = h21(vec2(seg, float(k)));
		float local = fract((ang + 3.14159) / 6.28318 * (24.0 + float(k) * 12.0));
		// glifo: barras e pontos dentro da faixa
		float gx = step(.2, local) * step(local, .8);
		float gy = abs(r - rr);
		float glyph = gx * step(gy, .42) * (step(.5, sh) * step(abs(local - .5), .07) + step(sh, .5) * step(abs(gy - .2), .06) + step(.8, sh) * step(abs(local - .3), .05));
		em += band + glyph;
		col = mix(col, vec3(.05, .05, .06), band * .8);
	}
	// olho em mosaico no centro
	vec2 q = p / vec2(9.0, 4.6);
	float almond = 1.0 - smoothstep(.96, 1.0, length(vec2(q.x, q.y / max(.05, 1.0 - q.x * q.x * .0))));
	float lid = smoothstep(.0, .06, 1.0 - abs(q.y) - q.x * q.x);
	float eye_in = step(abs(q.x), 1.0) * smoothstep(0.0, .04, (1.0 - q.x * q.x) * .55 - abs(q.y) * .55);
	float iris = 1.0 - smoothstep(2.6, 2.75, r);
	float pupil = 1.0 - smoothstep(1.0, 1.1, r);
	float outline = eye_in * (1.0 - smoothstep(0.0, .06, abs((1.0 - q.x * q.x) * .55 - abs(q.y) * .55)));
	vec3 tess = vec3(.75, .73, .68) * (.8 + .2 * v.z);
	col = mix(col, tess * grout, eye_in * .9);
	col = mix(col, mix(vec3(.12, .35, .45), vec3(.6, .1, .08), blood) * (.7 + .3 * fine), iris);
	col = mix(col, vec3(.01), pupil);
	em += outline * .8 + iris * (1.0 - pupil) * (.25 + .2 * sin(time_s * 2.0));
	// sangue: enche as juntas e forma poças
	float bp = smoothstep(.5, .6, fbm(p * .1 + vec2(9.0, 2.0) + blood * .2)) * blood;
	float bg = (1.0 - grout) * blood;
	vec3 bc = vec3(.3, .0, .015) * (.8 + .3 * fine);
	col = mix(col, bc, clamp(bp + bg * .9, 0.0, 1.0));
	rough = mix(rough, .05, clamp(bp + bg, 0.0, 1.0));
	// chuva batendo nas poças
	float drops = step(.985, h21(floor(p * 6.0) + floor(time_s * 9.0))) * max(pud, bp);
	col += drops * .15;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = .05;
	SPECULAR = .6;
	float pulse = .65 + .35 * sin(time_s * 1.7 - r * .25);
	EMISSION = rune_col * em * pulse * 1.4 + vec3(.6, .7, 1.0) * flash * .15 * (1.0 - blood);
}
"""

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float time_s = 0.0;
uniform vec3 c_lit = vec3(.32, .36, .46);
uniform vec3 c_dark = vec3(.03, .035, .05);
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(.7, .8, 1.0);
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = .5, s = 0.0; for (int i = 0; i < 6; i++) { s += vn(p) * a; p *= 2.07; a *= .5; } return s; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * .012 + vec2(time_s * .006, time_s * .002);
	float c = fbm(p + fbm(p * 1.7 - time_s * .01));
	float c2 = fbm(p * 3.0 + 5.0);
	vec3 col = mix(c_dark, c_lit, smoothstep(.3, .85, c * .8 + c2 * .3));
	float d = length(wp.xz) / 450.0;
	col += flash_col * flash * smoothstep(.4, .9, c) * .9;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(.75, 1.0, d);
}
"""

const EYE_STONE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float time_s = 0.0;
uniform float blink = 0.0;
uniform float cry = 0.0;
uniform vec3 glow = vec3(.4, .85, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	// olho de pedra entalhado: pálpebra amendoada, íris que brilha, lágrimas de sangue na fase 2
	vec2 q = lp.xy;
	float h = .5 * (1.0 - q.x * q.x);
	float open = h * (1.0 - blink);
	float in_eye = step(abs(q.x), 1.0) * step(abs(q.y), open);
	float iris = 1.0 - smoothstep(.28, .32, length(q));
	float pupil = 1.0 - smoothstep(.1, .13, length(q));
	vec3 stone = vec3(.2, .2, .22);
	vec3 col = mix(stone, vec3(.85, .82, .78), in_eye);
	col = mix(col, glow * .4, in_eye * iris);
	col = mix(col, vec3(0), in_eye * pupil);
	float tear = 0.0;
	for (int k = -1; k <= 1; k += 2) {
		float x0 = float(k) * .35 + sin(lp.y * 9.0) * .03;
		tear += step(abs(q.x - x0), .05) * step(q.y, -.2) * step(-.2 - cry * 3.0, q.y);
	}
	col = mix(col, vec3(.35, 0, .02), clamp(tear, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(.7, .1, clamp(tear, 0.0, 1.0));
	EMISSION = glow * in_eye * iris * (1.0 - pupil) * (1.2 + .5 * sin(time_s * 3.0));
}
"""

## globo ocular de verdade: íris tirada do olho do próprio Azazel, esclera úmida com veias,
## brilho molhado; acende antes de disparar e fica injetado de sangue na segunda fase
const EYEBALL_SHADER := """
shader_type spatial;
uniform sampler2D iris_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float glow = 0.0;
uniform vec3 glow_col = vec3(.5, .85, 1.0);
uniform float blood = 0.0;
varying vec3 n;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { n = normalize(VERTEX); }
void fragment() {
	// frente do olho = -Z (para onde o look_at aponta)
	float fz = -n.z;
	vec2 q = vec2(-n.x, n.y);
	// esclera: branco-amarelado com veias finas que ficam vermelhas no sangue
	float ang = atan(q.y, q.x);
	float vein = smoothstep(.72, .95, vn(vec2(ang * 6.0, fz * 9.0)) * vn(vec2(ang * 17.0, fz * 23.0)) * 1.8);
	vein *= smoothstep(.95, .3, fz);
	vec3 col = mix(vec3(.88, .84, .78), vec3(.93, .9, .86), vn(q * 8.0));
	col = mix(col, vec3(.65, .08, .06), vein * (.45 + blood * .5));
	col = mix(col, vec3(.75, .2, .18), blood * .35 * (1.0 - fz));
	// íris: textura do olho do Azazel projetada na frente
	float ri = .46;
	vec2 uv = q / (ri * 2.0 * .786) + .5;
	vec4 ir = texture(iris_tex, uv);
	float in_i = ir.a * step(0.0, fz) * step(length(q), ri * 1.05);
	vec3 irc = mix(ir.rgb, ir.rgb * vec3(.55, .8, 1.0), .5) * .75;
	irc = mix(irc, vec3(.45, .05, .04), blood * .5);
	col = mix(col, irc, in_i);
	// sombra suave na borda da íris (limbo)
	float rr = length(q) / ri;
	col *= 1.0 - smoothstep(.85, 1.0, rr) * (1.0 - smoothstep(1.0, 1.15, rr)) * .7;
	col = mix(col, vec3(.01), (1.0 - smoothstep(.33, .38, rr)) * step(0.0, fz));
	ALBEDO = col;
	ROUGHNESS = .06;
	SPECULAR = .9;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = .05;
	float pup = 1.0 - smoothstep(.28, .36, rr);
	EMISSION = glow_col * glow * in_i * (1.2 + pup * 2.0);
}
"""

func _mats() -> void:
	m_floor = ShaderMaterial.new(); var fs = Shader.new(); fs.code = FLOOR_SHADER; m_floor.shader = fs
	m_stone = StandardMaterial3D.new()
	var nt = NoiseTexture2D.new(); var nz = FastNoiseLite.new(); nz.frequency = .04; nz.fractal_octaves = 5; nz.seed = 9
	nt.noise = nz; nt.seamless = true; nt.width = 512; nt.height = 512
	var g = Gradient.new(); g.set_color(0, Color("15161a")); g.set_color(1, Color("4a4c54")); nt.color_ramp = g
	m_stone.albedo_texture = nt; m_stone.uv1_triplanar = true; m_stone.uv1_world_triplanar = true; m_stone.uv1_scale = Vector3.ONE * .15
	m_stone.roughness = .4
	var nm = NoiseTexture2D.new(); nm.noise = nz; nm.seamless = true; nm.as_normal_map = true; nm.bump_strength = 6.0; nm.width = 512; nm.height = 512
	m_stone.normal_enabled = true; m_stone.normal_texture = nm; m_stone.normal_scale = .8
	m_stone2 = m_stone.duplicate(); m_stone2.albedo_color = Color(.7, .72, .8)
	m_obs = StandardMaterial3D.new(); m_obs.albedo_color = Color("0b0a10"); m_obs.metallic = .4; m_obs.roughness = .12
	m_obs.normal_enabled = true; m_obs.normal_texture = nm; m_obs.normal_scale = .4
	m_copper = StandardMaterial3D.new(); m_copper.albedo_color = Color("3f7a6a"); m_copper.metallic = .8; m_copper.roughness = .35
	m_copper.emission_enabled = true; m_copper.emission = Color("0c2a24")
	m_rune = StandardMaterial3D.new(); m_rune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m_rune.albedo_color = Color(.4, .85, 1.0)
	m_eye = ShaderMaterial.new(); var es = Shader.new(); es.code = EYE_STONE_SHADER; m_eye.shader = es

func _body(mi: Node3D, shape: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb = StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
	if mi: sb.add_child(mi)
	var cs = CollisionShape3D.new(); cs.shape = shape; sb.add_child(cs)
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
	M = _m
	_mats()
	var rng = RandomNumberGenerator.new(); rng.seed = 7171
	# --- piso: disco de lajes e a borda em degraus, flutuando ---
	var fl = _cyl(R, R, 2.0, m_floor, Vector3(0, -1.0, 0), true, 64)
	_cyl(R + .8, R + .2, .6, m_stone, Vector3(0, -.2, 0), false, 64)
	_cyl(R - 1, 16, 16, m_stone2, Vector3(0, -10.0, 0), false, 32)
	_cyl(16, 1.5, 22, m_obs, Vector3(0, -29.0, 0), false, 16)
	# raízes de rocha penduradas sob o templo
	for i in 14:
		var a = rng.randf() * TAU; var d = rng.randf_range(10, R - 6)
		var hh = rng.randf_range(6, 18)
		_cyl(rng.randf_range(1.5, 3.5), .2, hh, m_stone2, Vector3(cos(a) * d, -4 - hh * .5, sin(a) * d), false, 6)
	# mureta baixa na borda (com vão para ver o abismo) + parede invisível
	for i in 32:
		var a = i * TAU / 32.0
		if i % 4 == 0: continue
		var p = Vector3(cos(a), 0, sin(a)) * (R - .6)
		var b = _box(Vector3(.9, 1.1, 8.2), m_stone, p + Vector3(0, .55, 0), false)
		b.rotation.y = -a
	for i in 16:
		var a0 = i * TAU / 16.0; var a1 = a0 + TAU / 16.0
		var p0 = Vector3(cos(a0), 0, sin(a0)) * (R - .3); var p1 = Vector3(cos(a1), 0, sin(a1)) * (R - .3)
		var sh = BoxShape3D.new(); sh.size = Vector3(p0.distance_to(p1) + 1, 60, 1.2)
		var w = _body(null, sh, (p0 + p1) * .5 + Vector3(0, 30, 0))
		w.rotation.y = -atan2((p1 - p0).z, (p1 - p0).x)
	# --- oito torres-para-raio com coroa de cobre e olho de pedra ---
	for i in 8:
		var a = i * TAU / 8.0 + PI / 8
		var dir = Vector3(cos(a), 0, sin(a))
		var c = dir * (R - 6.5)
		var hgt = 22.0 + (i % 2) * 6.0
		_cyl(2.6, 3.2, 1.6, m_stone, c + Vector3(0, .8, 0), true, 8)
		_cyl(1.2, 2.0, hgt, m_obs, c + Vector3(0, 1.6 + hgt * .5, 0), true, 6)
		# anéis de cobre
		for k in 3:
			var tm = TorusMesh.new(); tm.inner_radius = 1.5 - k * .15; tm.outer_radius = 1.9 - k * .15; tm.rings = 16; tm.ring_segments = 6
			_mesh(tm, m_copper, c + Vector3(0, 4 + k * hgt * .3, 0))
		# olho de verdade numa órbita de pedra, virado para o centro (depois segue o jogador)
		var eh = c + Vector3(0, hgt * .62, 0) - dir * 1.35
		var rig = _eyeball(eh, dir)
		var em: ShaderMaterial = rig.mat
		# coroa: pontas de cobre
		var top = c + Vector3(0, 1.6 + hgt, 0)
		for k in 5:
			var ka = k * TAU / 5.0
			var sp = _cyl(0, .25, 3.2, m_copper, top + Vector3(cos(ka) * .8, 1.2, sin(ka) * .8), false, 5)
			sp.rotation = Vector3(sin(ka) * .25, 0, -cos(ka) * .25)
		_cyl(.05, .3, 6, m_copper, top + Vector3(0, 3, 0), false, 5)
		spires.append({"top": top + Vector3(0, 6, 0), "eyep": eh, "eye": em, "ball": rig.ball, "lt": rig.lt, "lb": rig.lb, "cd": rng.randf_range(4, 12), "charge": -1.0, "aim": Vector3.ZERO, "blink": rng.randf_range(1, 6), "ph": rng.randf() * 10})
	# --- pilares quebrados e escombros ---
	for i in 10:
		var a = rng.randf() * TAU; var d = rng.randf_range(20, R - 12)
		var hh = rng.randf_range(2, 9)
		var p = Vector3(cos(a) * d, hh * .5, sin(a) * d)
		_cyl(1.1, 1.3, hh, m_stone, p, true, 12)
		for k in 3:
			_box(Vector3(rng.randf_range(.6, 1.6), rng.randf_range(.4, 1), rng.randf_range(.6, 1.4)), m_stone, p + Vector3(rng.randf_range(-2.5, 2.5), -hh * .5 + .3, rng.randf_range(-2.5, 2.5)), false, Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * .5))
	# --- ilhas de rocha flutuando em volta ---
	for i in 12:
		var a = rng.randf() * TAU; var d = rng.randf_range(70, 160)
		var n = Node3D.new(); n.position = Vector3(cos(a) * d, rng.randf_range(-15, 25), sin(a) * d); add_child(n)
		var s = rng.randf_range(4, 12)
		var sm = SphereMesh.new(); sm.radius = s; sm.height = s * 1.2; sm.radial_segments = 8; sm.rings = 5
		var top_m = _mesh(sm, m_stone2, Vector3.ZERO, Vector3.ZERO, n); top_m.scale = Vector3(1, .45, 1)
		var cm = CylinderMesh.new(); cm.top_radius = s * .9; cm.bottom_radius = .5; cm.height = s * 2; cm.radial_segments = 7
		_mesh(cm, m_stone2, Vector3(0, -s, 0), Vector3.ZERO, n)
		if i % 3 == 0:
			var oc = CylinderMesh.new(); oc.top_radius = .3; oc.bottom_radius = 1.2; oc.height = s * 1.5; oc.radial_segments = 6
			_mesh(oc, m_obs, Vector3(0, s * .7, 0), Vector3.ZERO, n)
		rocks.append({"n": n, "y0": n.position.y, "ph": rng.randf() * 10, "spd": rng.randf_range(.2, .5)})
	# --- mar de nuvens de tempestade ---
	clouds_mat = ShaderMaterial.new(); var cs = Shader.new(); cs.code = CLOUD_SHADER; clouds_mat.shader = cs
	var pm = PlaneMesh.new(); pm.size = Vector2(900, 900)
	_mesh(pm, clouds_mat, Vector3(0, -40, 0))
	var c2: ShaderMaterial = clouds_mat.duplicate()
	var p2 = _mesh(pm, c2, Vector3(0, 95, 0)); p2.rotation.x = PI
	c2.set_shader_parameter("c_lit", Vector3(.16, .18, .24)); c2.set_shader_parameter("c_dark", Vector3(.02, .02, .03))
	_orig_c2 = c2
	# --- chuva ---
	rain = CPUParticles3D.new()
	rain.amount = 900; rain.lifetime = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(R + 6, 1, R + 6)
	rain.direction = Vector3(.15, -1, .05); rain.spread = 2; rain.initial_velocity_min = 38; rain.initial_velocity_max = 44
	rain.gravity = Vector3(0, -10, 0)
	var dm = BoxMesh.new(); dm.size = Vector3(.025, .9, .025)
	rain_mat = StandardMaterial3D.new(); rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rain_mat.albedo_color = Color(.65, .75, .9, .35)
	dm.material = rain_mat; rain.mesh = dm
	rain.position = Vector3(0, 32, 0)
	add_child(rain)
	# --- luzes ---
	for i in 4:
		var a = i * TAU / 4.0
		var l = OmniLight3D.new(); l.light_color = Color(.55, .7, 1.0); l.light_energy = 2.2; l.omni_range = 40
		l.position = Vector3(cos(a), 0, sin(a)) * 22 + Vector3(0, 12, 0)
		add_child(l); lights.append(l)
	flash_l = OmniLight3D.new(); flash_l.light_color = Color(.75, .85, 1.0); flash_l.omni_range = 140; flash_l.light_energy = 0.0
	flash_l.position = Vector3(0, 60, 0); add_child(flash_l)

var _orig_c2: ShaderMaterial
var _eye_sh: Shader
var _iris: Texture2D

## órbita de pedra com pálpebras de carne petrificada + globo ocular que gira
func _eyeball(p: Vector3, dir: Vector3) -> Dictionary:
	if _eye_sh == null:
		_eye_sh = Shader.new(); _eye_sh.code = EYEBALL_SHADER
		_iris = load("res://azazel/iris.png") if ResourceLoader.exists("res://azazel/iris.png") else null
	var R0 = 1.05
	var socket = Node3D.new(); socket.position = p; add_child(socket)
	socket.basis = Basis.looking_at(-dir, Vector3.UP)   # frente (-Z) aponta para o centro
	# moldura: anel de pedra em amêndoa
	var tm = TorusMesh.new(); tm.inner_radius = R0 * 1.02; tm.outer_radius = R0 * 1.45; tm.rings = 32; tm.ring_segments = 10
	var fr = _mesh(tm, m_stone, Vector3(0, 0, -.25), Vector3(PI / 2, 0, 0), socket); fr.scale = Vector3(1.25, 1, .85)
	var ball = Node3D.new(); socket.add_child(ball)
	var sm = SphereMesh.new(); sm.radius = R0; sm.height = R0 * 2; sm.radial_segments = 32; sm.rings = 16
	var mat = ShaderMaterial.new(); mat.shader = _eye_sh; mat.set_shader_parameter("iris_tex", _iris)
	_mesh(sm, mat, Vector3.ZERO, Vector3.ZERO, ball)
	# pálpebras: duas meias-esferas de pele/pedra que fecham por cima e por baixo
	var lid_m = StandardMaterial3D.new(); lid_m.albedo_color = Color(.42, .38, .37); lid_m.roughness = .55
	lid_m.normal_enabled = true; lid_m.normal_texture = m_stone.normal_texture; lid_m.normal_scale = .5
	var hs = SphereMesh.new(); hs.radius = R0 * 1.08; hs.height = R0 * 1.08; hs.is_hemisphere = true; hs.radial_segments = 24; hs.rings = 8
	var lt = Node3D.new(); socket.add_child(lt); _mesh(hs, lid_m, Vector3.ZERO, Vector3.ZERO, lt)
	var lb = Node3D.new(); socket.add_child(lb); _mesh(hs, lid_m, Vector3.ZERO, Vector3(PI, 0, 0), lb)
	return {"ball": ball, "lt": lt, "lb": lb, "mat": mat}

func reset_state() -> void:
	set_phase2(0.0)
	for tr in tears:
		if is_instance_valid(tr): tr.queue_free()
	tears.clear()

## 0 = tempestade azul, 1 = tempestade de sangue
func set_phase2(k: float) -> void:
	phase2 = k
	m_floor.set_shader_parameter("blood", k)
	m_floor.set_shader_parameter("rune_col", Vector3(.35, .8, 1.0).lerp(Vector3(1.0, .08, .03), k))
	clouds_mat.set_shader_parameter("c_lit", Vector3(.32, .36, .46).lerp(Vector3(.5, .06, .05), k))
	clouds_mat.set_shader_parameter("c_dark", Vector3(.03, .035, .05).lerp(Vector3(.06, 0, 0), k))
	clouds_mat.set_shader_parameter("flash_col", Vector3(.7, .8, 1.0).lerp(Vector3(1, .2, .1), k))
	if _orig_c2:
		_orig_c2.set_shader_parameter("c_lit", Vector3(.16, .18, .24).lerp(Vector3(.3, .03, .02), k))
		_orig_c2.set_shader_parameter("flash_col", Vector3(.7, .8, 1.0).lerp(Vector3(1, .2, .1), k))
	rain_mat.albedo_color = Color(.65, .75, .9, .35).lerp(Color(.6, 0, .03, .8), k)
	m_copper.emission = Color("0c2a24").lerp(Color("4a0402"), k)
	m_rune.albedo_color = Color(.4, .85, 1.0).lerp(Color(1, .1, .05), k)
	for s in spires:
		s.eye.set_shader_parameter("glow_col", Vector3(.5, .85, 1.0).lerp(Vector3(1, .1, .05), k))
		s.eye.set_shader_parameter("blood", k)
	for l in lights: l.light_color = Color(.55, .7, 1.0).lerp(Color(1, .3, .25), k)
	flash_l.light_color = Color(.75, .85, 1.0).lerp(Color(1, .25, .15), k)

## a arena sangra: chamado quando o Azazel começa a chorar
func bleed() -> void:
	var tw = create_tween()
	tw.tween_method(set_phase2, 0.0, 1.0, 3.5).set_trans(Tween.TRANS_SINE)
	# sangue escorrendo dos olhos das torres
	for s in spires:
		var pt = CPUParticles3D.new()
		pt.amount = 30; pt.lifetime = 1.6
		pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pt.emission_box_extents = Vector3(.5, .1, .1)
		pt.direction = Vector3(0, -1, 0); pt.spread = 4; pt.initial_velocity_min = .5; pt.initial_velocity_max = 1.5
		pt.gravity = Vector3(0, -12, 0)
		var dm = SphereMesh.new(); dm.radius = .09; dm.height = .3; dm.radial_segments = 5; dm.rings = 3
		var mm = StandardMaterial3D.new(); mm.albedo_color = Color(.5, 0, .03); mm.roughness = .1
		dm.material = mm; pt.mesh = dm
		pt.position = s.eyep + Vector3(0, -1.1, 0) - Vector3(s.eyep.x, 0, s.eyep.z).normalized() * .9
		add_child(pt)
		tears.append(pt)

## relâmpago ao longe ou em uma torre
func sky_bolt(to_spire := false) -> void:
	var a: Vector3
	var b: Vector3
	if to_spire:
		var s = spires[randi() % spires.size()]
		b = s.top; a = b + Vector3(randf_range(-20, 20), 90, randf_range(-20, 20))
	else:
		var ang = randf() * TAU; var d = randf_range(90, 220)
		b = Vector3(cos(ang) * d, -38, sin(ang) * d); a = b + Vector3(randf_range(-30, 30), 140, randf_range(-30, 30))
	var col = Color(.75, .85, 1.0).lerp(Color(1, .2, .1), phase2)
	bolt(a, b, col, 1.2 if to_spire else 2.2, .22)
	flash_k = 1.0 if to_spire else .7
	G.later(randf_range(.1, .9), func(): G.snd("raio", -10 if to_spire else -16, randf_range(.6, .9)))

## raio em zigue-zague feito de traços (núcleo branco + brilho colorido + galhos)
func bolt(a: Vector3, b: Vector3, col: Color, w: float, life: float, branches := 3) -> void:
	w *= .28
	var n = 12
	var d = b - a
	var side = d.cross(Vector3.UP).normalized()
	if side.length() < .1: side = Vector3.RIGHT
	var up2 = d.cross(side).normalized()
	var prev = a
	var pts = [a]
	for i in range(1, n):
		var u = float(i) / n
		var off = (side * randf_range(-1, 1) + up2 * randf_range(-1, 1)) * d.length() * .045 * sin(u * PI)
		var p = a + d * u + off
		pts.append(p)
	pts.append(b)
	for i in pts.size() - 1:
		G.tracer(pts[i], pts[i + 1], w, Color(col.r, col.g, col.b, .55), life * 1.4)
		G.tracer(pts[i], pts[i + 1], w * .35, Color(1, 1, 1, .95), life)
	for k in branches:
		var i0 = randi_range(2, n - 3)
		var o: Vector3 = pts[i0]
		var e = o + (d.normalized() * .5 + Vector3(randf_range(-1, 1), randf_range(-.4, .2), randf_range(-1, 1))).normalized() * d.length() * randf_range(.12, .25)
		var bp = o
		for j in 4:
			var q = o.lerp(e, (j + 1) / 4.0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * d.length() * .015
			G.tracer(bp, q, w * .45, Color(col.r, col.g, col.b, .45), life * 1.2)
			bp = q

func _process(dt: float) -> void:
	t += dt
	m_floor.set_shader_parameter("time_s", t)
	clouds_mat.set_shader_parameter("time_s", t)
	if _orig_c2: _orig_c2.set_shader_parameter("time_s", t * 1.6)
	for r in rocks:
		r.n.position.y = r.y0 + sin(t * r.spd + r.ph) * 1.5
		r.n.rotation.y += dt * .02
	var fight: bool = M != null and M.level == "azazel" and G.state == "play" and G.boss != null and is_instance_valid(G.boss) and G.boss.get("kind") == "azazel" and G.player != null
	var shooters := 0
	for s in spires:
		if s.charge >= 0: shooters += 1
	for s in spires:
		s.blink -= dt
		var bl = 0.0
		if s.blink < 0:
			bl = sin(clamp(-s.blink / .22, 0.0, 1.0) * PI)
			if s.blink < -.22: s.blink = randf_range(2.0, 7.0)
		if s.charge >= 0: bl = 0.0
		# pálpebras: abertas ~55° para cima e para baixo; fechando no piscar
		var op = lerp(1.05, 0.0, bl)
		s.lt.rotation.x = op
		s.lb.rotation.x = -op
		# o olho encara o jogador durante a luta (com limite dentro da órbita); fora dela, passeia
		var ball: Node3D = s.ball
		var want: Basis
		if fight:
			var tgt: Vector3 = G.player.global_position + Vector3(0, 1.4, 0)
			var lt = ball.get_parent().global_transform.affine_inverse() * tgt
			var dirl = lt.normalized()
			if dirl.z > -.25: dirl = (dirl + Vector3(0, 0, -.6)).normalized()
			want = Basis.looking_at(dirl, Vector3.UP)
		else:
			want = Basis.from_euler(Vector3(sin(t * .7 + s.ph) * .3, sin(t * .5 + s.ph * 2.0) * .5, 0))
		ball.basis = ball.basis.slerp(want, 1.0 - exp(-6.0 * dt)).orthonormalized()
		# dispara um raiozinho de vez em quando para atrapalhar
		var glow := 0.0
		if fight:
			if s.charge < 0:
				s.cd -= dt
				if s.cd <= 0 and shooters < (2 if phase2 > .5 else 1):
					s.charge = 0.0; shooters += 1
					G.snd("charge", -14, 1.6)
			else:
				s.charge += dt
				glow = clamp(s.charge / .9, 0.0, 1.0)
				if s.charge < .75: s.aim = G.player.global_position + Vector3(0, .9, 0)
				var eyep: Vector3 = ball.global_position + (ball.global_transform.basis * Vector3(0, 0, -1.05))
				if s.charge > .3 and randf() < dt * 20: G.tracer(eyep, s.aim, .03, Color(.6, .85, 1.0, .35).lerp(Color(1, .2, .1, .35), phase2), .04)
				if s.charge >= .95:
					s.charge = -1.0
					s.cd = randf_range(7.0, 13.0) * (.65 if phase2 > .5 else 1.0)
					var col = Color(.75, .85, 1.0).lerp(Color(1, .2, .1), phase2)
					var end: Vector3 = eyep + (s.aim - eyep).normalized() * (eyep.distance_to(s.aim) + 4.0)
					bolt(eyep, end, col, .7, .14, 1)
					G.snd("raio", -12, randf_range(1.3, 1.6))
					G.emit("spark", s.aim, 10, 8, .1, .4)
					var pc: Vector3 = G.player.global_position + Vector3(0, .9, 0)
					var ab = end - eyep
					var tt = clamp((pc - eyep).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if pc.distance_to(eyep + ab * tt) < 1.3:
						if G.hurt_player(8.0 if phase2 < .5 else 11.0): G.player.velocity += ab.normalized() * 6 + Vector3(0, 3, 0)
		else:
			s.charge = -1.0
		s.eye.set_shader_parameter("glow", glow)
	# relâmpagos ao longe
	if M and M.level == "azazel":
		sky_bolt_cd -= dt
		if sky_bolt_cd <= 0:
			sky_bolt_cd = randf_range(1.2, 4.0) * (.6 if phase2 > .5 else 1.0)
			sky_bolt(randf() < .25)
	flash_k *= exp(-7.0 * dt)
	flash_l.light_energy = flash_k * 6.0
	clouds_mat.set_shader_parameter("flash", flash_k)
	if _orig_c2: _orig_c2.set_shader_parameter("flash", flash_k)
	m_floor.set_shader_parameter("flash", flash_k)
	rain.emitting = M != null and M.level == "azazel"
