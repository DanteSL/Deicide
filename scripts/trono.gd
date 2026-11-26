extends Node3D
## A Sala do Trono: antecâmara, portão dourado, salão de mármore branco e ouro lavado de sangue,
## fontes e cachoeiras de sangue, altar em degraus e o trono. Também dirige a cutscene de Deus.

const DOOR_Z := 47.0
const ALTAR_TOP := 8.0
const DEUS_POS := Vector3(0, ALTAR_TOP, -60)
const CUT_Z := 14.0
const LINES := [
	["ASHRA VETH KALON.", "Eu te vi, criatura."],
	["UMAI SERETHAL.", "Ajoelhe-se."],
	["NOHM IRA DETH.", "Nenhum anjo te salvará."],
	["ELORÁ KAZUUN.", "Eu sou o fim."],
]

var main: Node
var stage := "door"   # door → hall → cut → fight
var m_marble: StandardMaterial3D
var m_marble2: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_gold_dark: StandardMaterial3D
var m_blood_still: ShaderMaterial
var m_blood_flow: ShaderMaterial
var m_blood_fall: ShaderMaterial
var _blood_sh: Shader
var _bm_cache = {}

## material de sangue (veja o shader: 0 faixa, 1 poça, 2 mancha seca, 3 superfície)
func bm(mode: int, seed: float, flow := 0.0, stretch := Vector2.ONE) -> ShaderMaterial:
	var key = "%d/%.2f/%.2f/%s" % [mode, seed, flow, stretch]
	if _bm_cache.has(key): return _bm_cache[key]
	var m = ShaderMaterial.new()
	m.shader = _blood_sh
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("stretch", stretch)
	_bm_cache[key] = m
	return m

## poça irregular no chão
func pool(x: float, z: float, r: float, y := .03, sq := 1.0) -> void:
	var f = flat(Vector3(x, y, z), Vector2(r * 2, r * 2 * sq), bm(1, float(randi() % 9) + .37))
	f.rotation.y = G.rnd(0, TAU)

## mancha seca com filetes numa parede (normal = direção para fora da parede)
func stain(p: Vector3, nrm: Vector3, w: float, h: float) -> void:
	var q = quad(p + nrm * .02, Vector2(w, h), bm(2, float(randi() % 11) + .5))
	q.rotation = Vector3(0, atan2(nrm.x, nrm.z), 0)
var m_carpet: StandardMaterial3D
var door_l: Node3D
var door_r: Node3D
var door_open := 0.0
var door_target := 0.0
var door_snd_done := false
var halo: MeshInstance3D
var flames: Array = []
var spouts: Array = []
var deus: Node = null
var cam: Camera3D
var ct := 0.0
var shot_i := -1
var said := {}
var voice: AudioStreamPlayer
var ov: CanvasLayer
var bar_t: ColorRect
var bar_b: ColorRect
var sub_a: Label
var sub_b: Label
var skip_lbl: Label
var surge := 0.0

const BLOOD_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// sangue procedural: mode 0 = faixa escorrendo, 1 = poça irregular, 2 = mancha seca com filetes, 3 = superfície cheia
uniform int mode = 1;
uniform float seed = 0.0;
uniform float flow = 0.0;
uniform vec2 stretch = vec2(1.0, 1.0);
uniform vec4 fresh : source_color = vec4(.50, .015, .025, 1.0);
uniform vec4 deep : source_color = vec4(.13, .0, .008, 1.0);
uniform vec4 dried : source_color = vec4(.20, .025, .02, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = .5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= .5; } return v; }
void fragment() {
	vec2 uv = UV;
	vec2 q = (uv - .5) * 2.0;
	float m = 1.0;
	float thick = 1.0;
	if (mode == 1) {
		float r = length(q);
		float edge = .55 + .45 * fbm(q * 1.8 + seed);
		m = step(r, edge);
		float drops = step(.80, fbm(uv * 11.0 + seed * 3.7)) * step(r, 1.0);
		m = max(m, drops);
		thick = smoothstep(edge, 0.0, r);
	} else if (mode == 0) {
		float w = .62 + .38 * fbm(vec2(uv.y * 3.0 * stretch.y + seed, TIME * .25 + seed));
		m = step(abs(uv.x - .5) * 2.0, w);
		thick = 1.0 - abs(uv.x - .5) * 2.0 / max(w, .01);
	} else if (mode == 2) {
		// respingo: mancha irregular em cima, respingos em volta e filetes escorrendo dela
		vec2 c = (uv - vec2(.5, .27)) * vec2(1.0, 1.5);
		float edge = .30 + .22 * fbm(uv * 4.0 + seed);
		float blot = step(length(c), edge);
		float spk = step(.74, fbm(uv * 15.0 + seed * 2.0)) * step(uv.y, .6) * step(length(c), .62);
		float cols = 6.0;
		float colx = floor(uv.x * cols);
		float has = step(.25, hash(vec2(colx, seed + 3.0)));
		float x0 = abs(fract(uv.x * cols) - .5);
		float wdt = .12 + .2 * hash(vec2(colx + 7.0, seed));
		float st = .3;
		float len = st + (1.0 - st) * (.2 + .8 * hash(vec2(colx, seed)));
		float tp = mix(1.0, .5, clamp((uv.y - st) / max(len - st, .01), 0.0, 1.0));
		float run = has * step(x0, wdt * tp) * step(uv.y, len) * step(st - .05, uv.y);
		float head = has * step(length(vec2(x0, (uv.y - len) * cols * .55)), wdt * 1.3);
		float inx = step(abs(uv.x - .5), edge * .9);
		m = max(max(blot, spk), max(run, head) * inx);
		thick = .45;
	}
	if (m < .5) discard;
	vec2 fuv = uv * stretch + vec2(0.0, -TIME * flow);
	float n = fbm(fuv * 4.0 + seed);
	float n2 = fbm(fuv * 13.0 - seed);
	vec3 col = mix(fresh.rgb, deep.rgb, clamp(thick * .75 + n * .45 - .15, 0.0, 1.0));
	if (mode == 2) col = mix(fresh.rgb * .85, dried.rgb, clamp(.25 + n * .55, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mode == 2 ? .3 : .06 + n2 * .12;
	SPECULAR = mode == 2 ? .5 : .85;
	float e = .02;
	float hx = fbm(fuv * 8.0 + vec2(e, 0.0)) - fbm(fuv * 8.0 - vec2(e, 0.0));
	float hy = fbm(fuv * 8.0 + vec2(0.0, e)) - fbm(fuv * 8.0 - vec2(0.0, e));
	NORMAL_MAP = normalize(vec3(-hx * 5.0, -hy * 5.0, 1.0)) * .5 + .5;
	NORMAL_MAP_DEPTH = mode == 2 ? .2 : .8;
	EMISSION = fresh.rgb * (mode == 2 ? .0 : .06);
}
"""

# ---------------- materiais ----------------
func _mats() -> void:
	var nt = NoiseTexture2D.new()
	nt.width = 256; nt.height = 256; nt.seamless = true
	var fn = FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	fn.frequency = .02
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	nt.noise = fn
	var gr = Gradient.new()
	gr.set_color(0, Color("8f8780")); gr.set_color(1, Color("e2ddd6"))
	gr.add_point(.15, Color("cfc8c0"))
	nt.color_ramp = gr
	m_marble = StandardMaterial3D.new()
	m_marble.albedo_texture = nt
	m_marble.uv1_triplanar = true; m_marble.uv1_world_triplanar = true
	m_marble.uv1_scale = Vector3.ONE * .06
	m_marble.roughness = .25
	m_marble.metallic_specular = .7
	m_marble2 = m_marble.duplicate()
	m_marble2.albedo_color = Color(.78, .74, .72)
	m_gold = StandardMaterial3D.new()
	m_gold.albedo_color = Color("d09a32")
	m_gold.metallic = .55
	m_gold.roughness = .3
	m_gold.emission_enabled = true
	m_gold.emission = Color("4a3008")
	m_gold.rim_enabled = true; m_gold.rim = .6; m_gold.rim_tint = .8
	m_gold_dark = m_gold.duplicate()
	m_gold_dark.albedo_color = Color("9a7428")
	m_gold_dark.emission = Color("2a1a04")
	_blood_sh = Shader.new()
	_blood_sh.code = BLOOD_SHADER
	m_blood_still = bm(3, 1.0)
	m_blood_flow = bm(0, 2.0, .35, Vector2(1, 10))
	m_blood_fall = bm(0, 3.0, 1.3, Vector2(1, 3))
	m_carpet = StandardMaterial3D.new()
	m_carpet.albedo_color = Color("5a0610")
	m_carpet.roughness = .9

# ---------------- primitivas ----------------
func blk(cx: float, y0: float, cz: float, w: float, h: float, d: float, mat: Material, col := true) -> Node3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = mat
	if not col:
		mi.position = Vector3(cx, y0 + h * .5, cz)
		add_child(mi)
		return mi
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.add_child(mi)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(w, h, d)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(cx, y0 + h * .5, cz)
	add_child(sb)
	return sb

func cyl(cx: float, y0: float, cz: float, rt: float, rb: float, h: float, mat: Material, col := true, segs := 20) -> Node3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = segs; cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	var root: Node3D = mi
	if col:
		var sb = StaticBody3D.new()
		sb.collision_layer = 1; sb.collision_mask = 0
		sb.add_child(mi)
		var cs = CollisionShape3D.new()
		var s = CylinderShape3D.new()
		s.radius = max(rt, rb); s.height = h
		cs.shape = s
		sb.add_child(cs)
		root = sb
	root.position = Vector3(cx, y0 + h * .5, cz)
	add_child(root)
	return root

func quad(p: Vector3, size: Vector2, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat
	mi.position = p
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func flat(p: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	return quad(p, size, mat, Vector3(-PI / 2, 0, 0))

func disc(p: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = .04; cm.radial_segments = 28; cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func glow(c: Color, a := 1.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, a)
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func light(p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = c; l.light_energy = e; l.omni_range = r
	l.position = p
	add_child(l)
	return l

# ---------------- construção ----------------
func build(m: Node) -> void:
	main = m
	_mats()
	_hall()
	_corridor()
	_door()
	_altar()
	for p in [Vector2(-24, -18), Vector2(24, -18), Vector2(-24, 20), Vector2(24, 20)]: _fountain(p.x, p.y)
	for side in [-1, 1]:
		for z in [-58, -34, -10, 14, 36]: _bloodfall(side, z)
	_candles()
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 400
	add_child(cam)
	voice = AudioStreamPlayer.new()
	voice.volume_db = 2
	add_child(voice)
	_build_overlay()

func _hall() -> void:
	# piso e paredes (salão de 96 x 132, z de -84 a 48)
	blk(0, -2, -18, 96, 2, 132, m_marble)
	blk(-47, 0, -18, 2, 46, 132, m_marble2)
	blk(47, 0, -18, 2, 46, 132, m_marble2)
	blk(0, 0, -85, 96, 46, 2, m_marble2)
	blk(-27.5, 0, DOOR_Z, 41, 46, 2, m_marble2)
	blk(27.5, 0, DOOR_Z, 41, 46, 2, m_marble2)
	blk(0, 22, DOOR_Z, 14, 24, 2, m_marble2)
	# frisos dourados
	for y in [.0, 22.0, 45.0]:
		blk(-45.9, y, -18, .3, 1.0, 132, m_gold, false)
		blk(45.9, y, -18, .3, 1.0, 132, m_gold, false)
		blk(0, y, -83.9, 92, 1.0, .3, m_gold, false)
		if y > 21.0:
			blk(0, y, DOOR_Z - 1.1, 92, 1.0, .3, m_gold, false)
		else:  # no chão, o friso para no portão
			blk(-26.9, y, DOOR_Z - 1.1, 38.2, 1.0, .3, m_gold, false)
			blk(26.9, y, DOOR_Z - 1.1, 38.2, 1.0, .3, m_gold, false)
	# moldura do portão
	blk(-7.8, 0, DOOR_Z - 1.2, 1.6, 22, .8, m_gold, false)
	blk(7.8, 0, DOOR_Z - 1.2, 1.6, 22, .8, m_gold, false)
	blk(0, 21, DOOR_Z - 1.2, 17.2, 1.6, .8, m_gold, false)
	# colunas ao longo das paredes
	for z in range(-78, 46, 12):
		for sx in [-1, 1]:
			var x = sx * 42.6
			blk(x, 0, z, 4.4, 1.2, 4.4, m_gold)
			cyl(x, 1.2, z, 1.4, 1.65, 38.0, m_marble)
			blk(x, 39.2, z, 4.6, 1.4, 4.6, m_gold, false)
	# estandartes vermelhos entre as colunas
	var banner = StandardMaterial3D.new()
	banner.albedo_color = Color("7a0a12"); banner.roughness = .8; banner.cull_mode = BaseMaterial3D.CULL_DISABLED
	for z in range(-72, 42, 24):
		for sx in [-1, 1]:
			quad(Vector3(sx * 45.85, 30, z), Vector2(5, 15), banner, Vector3(0, -sx * PI / 2, 0))
			blk(sx * 45.6, 37.4, z, .4, .4, 6, m_gold, false)
	# piso: tapete de sangue até o altar, frisos de ouro, anel central
	blk(0, 0, 0.25, 7, .06, 96.5, m_carpet, false)
	for sx in [-1, 1]:
		blk(sx * 3.7, 0, 0.25, .4, .08, 96.5, m_gold, false)
	for s in [[0, -46, 92, .5], [0, 46, 92, .5]]:
		blk(s[0], 0, s[1] - .6, s[2], .05, s[3], m_gold, false)
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 17.2; tm.outer_radius = 18.0; tm.rings = 64; tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = m_gold
	ring.scale = Vector3(1, .05, 1)
	ring.position = Vector3(0, .02, 0)
	add_child(ring)
	# poças de sangue espalhadas
	seed(7)
	for p in [[-12, 8, 3.6], [14, -6, 2.8], [-30, -30, 4.4], [31, 30, 3.4], [-8, -34, 2.6], [20, 38, 3.0], [-34, 10, 2.4], [9, 24, 2.0], [-18, 30, 1.6], [27, -36, 2.2], [5, -20, 1.4], [-22, -8, 1.8]]:
		pool(p[0], p[1], p[2], .03 + randf() * .01)
	# sangue acumulado nos cantos e no rodapé
	for c in [[-43.5, -81.5], [43.5, -81.5], [-43.5, 43.5], [43.5, 43.5]]:
		pool(c[0], c[1], 4.5, .035, .8)
	for z in range(-74, 42, 9):
		for sx in [-1, 1]:
			if randf() < .55: pool(sx * 44.6, z + randf() * 4, G.rnd(1.2, 2.6), .036, .5)
	# rosácea no alto da parede norte
	var rz = -83.8
	var win_c = Vector3(0, 33, rz)
	disc(win_c, 3.0, glow(Color(1, .2, .1))).rotation.x = PI / 2
	for i in 16:
		var a = i * TAU / 16
		var petal = quad(win_c + Vector3(cos(a), sin(a), 0) * 6.0 + Vector3(0, 0, .05), Vector2(2.6, 5.5),
			glow(Color(1, .82, .4) if i % 2 == 0 else Color(.95, .12, .08)), Vector3(0, 0, a - PI / 2))
		petal.rotation = Vector3(0, 0, a - PI / 2)
	var rim = MeshInstance3D.new()
	var rt = TorusMesh.new()
	rt.inner_radius = 9.4; rt.outer_radius = 10.4; rt.rings = 48
	rim.mesh = rt
	rim.material_override = m_gold
	rim.rotation.x = PI / 2
	rim.position = win_c + Vector3(0, 0, .3)
	add_child(rim)
	# feixes de luz da rosácea até o altar
	for i in 3:
		var beam = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 4.0 - i; cm.bottom_radius = 9.0 - i * 2; cm.height = 40; cm.radial_segments = 16
		beam.mesh = cm
		beam.material_override = glow(Color(1, .7, .45), .05)
		beam.position = Vector3(0, 18, -72)
		beam.rotation.x = -.45
		add_child(beam)
	# luz geral do salão
	light(Vector3(0, 30, -60), Color(1, .8, .62), 2.2, 70)
	light(Vector3(0, 20, 0), Color(1, .78, .66), 1.0, 70)
	light(Vector3(0, 6, -50), Color(1, .15, .1), 3.0, 30)

func _corridor() -> void:
	# antecâmara escura: z de 48 a 112
	blk(0, -2, 80, 20, 2, 66, m_marble2)
	blk(-10, 0, 80, 2, 24, 66, m_marble2)
	blk(10, 0, 80, 2, 24, 66, m_marble2)
	blk(0, 24, 80, 22, 2, 66, m_marble2)
	blk(0, 0, 113, 22, 26, 2, m_marble2)
	for y in [.0, 23.0]:
		blk(-8.9, y, 80, .2, 1, 64, m_gold, false)
		blk(8.9, y, 80, .2, 1, 64, m_gold, false)
	# canaletas de sangue correndo em direção ao portão
	for sx in [-1, 1]:
		blk(sx * 8.2, -.02, 80, 1.6, .1, 64, m_gold_dark, false)
		var f = flat(Vector3(sx * 8.2, .1, 80), Vector2(1.3, 64), bm(0, 4.0 + sx, .25, Vector2(1, 30)))
		f.rotation.y = PI
	seed(11)
	for i in 5: pool(G.rnd(-6, 6), G.rnd(54, 108), G.rnd(.8, 1.8), .07)
	blk(0, 0, 80, 7, .06, 65, m_carpet, false)
	for sx in [-1, 1]:
		blk(sx * 3.7, 0, 80, .4, .08, 65, m_gold, false)
	# arcos dourados no teto
	for z in range(54, 112, 9):
		blk(0, 22.6, z, 18, 1.2, .8, m_gold, false)
		blk(-8.6, 0, z, .8, 22.6, .8, m_gold, false)
		blk(8.6, 0, z, .8, 22.6, .8, m_gold, false)
	# mãos decepadas pregadas nas paredes, pingando
	var hm = _hand_mesh()
	for z in range(58, 110, 9):
		for sx in [-1, 1]:
			if hm: _hand(hm, Vector3(sx * 8.7, 9.5, z + 4.5), sx)
	for z in [62, 80, 98]:
		light(Vector3(0, 12, z), Color(1, .35, .25), 1.4, 16)
	_door_frame()
	_corridor_decor()

func _hand_mesh() -> Mesh:
	if not ResourceLoader.exists("res://deus/mao.glb"): return null
	var inst = load("res://deus/mao.glb").instantiate()
	var src = _find_mesh(inst)
	var mesh: Mesh = src.mesh if src else null
	inst.free()
	return mesh

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var r = _find_mesh(c)
		if r: return r
	return null

var _hand_mat: StandardMaterial3D
func _hand(mesh: Mesh, p: Vector3, side: int, idx := 0) -> void:
	if _hand_mat == null:
		_hand_mat = StandardMaterial3D.new()
		_hand_mat.albedo_texture = load("res://deus/arm_col.jpg")
		_hand_mat.albedo_color = Color(.75, .66, .62)
		_hand_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var piv = Node3D.new()
	piv.position = p
	add_child(piv)
	var h = MeshInstance3D.new()
	h.mesh = mesh
	h.material_override = _hand_mat
	var aabb = mesh.get_aabb()
	var k = 1.6 / max(aabb.size.y, max(aabb.size.x, aabb.size.z))
	h.scale = Vector3.ONE * k
	h.position = -aabb.get_center() * k
	piv.add_child(h)
	piv.rotation = Vector3(0, -side * PI / 2 if side != 0 else 0.0, PI + (idx - 3) * .12)
	# cravo dourado e sangue pingando
	var nail = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = .14; sm.height = .28
	nail.mesh = sm; nail.material_override = m_gold
	piv.add_child(nail)
	var pt = CPUParticles3D.new()
	pt.amount = 4
	pt.lifetime = 1.4
	pt.direction = Vector3(0, -1, 0); pt.spread = 4
	pt.initial_velocity_min = .2; pt.initial_velocity_max = .5
	pt.gravity = Vector3(0, -12, 0)
	var dm = SphereMesh.new(); dm.radius = .05; dm.height = .16; dm.radial_segments = 5; dm.rings = 3
	dm.material = glow(Color(.6, 0, .02))
	pt.mesh = dm
	pt.top_level = true
	pt.position = p + Vector3(0, -.9, 0)
	piv.add_child(pt)

func _door() -> void:
	door_l = Node3D.new(); door_l.position = Vector3(-7, 0, DOOR_Z - .2); add_child(door_l)
	door_r = Node3D.new(); door_r.position = Vector3(7, 0, DOOR_Z - .2); add_child(door_r)
	for pair in [[door_l, 1], [door_r, -1]]:
		var pv: Node3D = pair[0]
		var s: int = pair[1]
		var sb = StaticBody3D.new()
		sb.collision_layer = 1; sb.collision_mask = 0
		pv.add_child(sb)
		var mi = MeshInstance3D.new()
		var bm_ = BoxMesh.new(); bm_.size = Vector3(7, 21, .9)
		mi.mesh = bm_; mi.material_override = m_gold_dark
		sb.add_child(mi)
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new(); bs.size = bm_.size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(s * 3.5, 10.5, 0)
		for f in [1, -1]:
			_leaf_face(sb, s, f)

func _db(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rz := 0.0) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var b = BoxMesh.new(); b.size = size
	m.mesh = b; m.material_override = mat
	m.position = pos; m.rotation.z = rz
	parent.add_child(m)
	return m

func _ring_at(parent: Node3D, pos: Vector3, r: float, tube: float, mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var t = TorusMesh.new(); t.inner_radius = r - tube; t.outer_radius = r + tube; t.rings = 32; t.ring_segments = 8
	m.mesh = t; m.material_override = mat
	m.rotation.x = PI / 2
	m.position = pos
	parent.add_child(m)
	return m

## relevos de uma face da folha (f = +1 corredor, -1 salão); s indica para que lado fica o centro do portão
func _leaf_face(sb: Node3D, s: int, f: int) -> void:
	var z = f * .5
	var g = m_gold
	# moldura externa
	_db(sb, Vector3(0, 10.1, z), Vector3(6.8, .4, .14), g)
	_db(sb, Vector3(0, -10.1, z), Vector3(6.8, .4, .14), g)
	_db(sb, Vector3(-3.2, 0, z), Vector3(.4, 20.6, .14), g)
	_db(sb, Vector3(3.2, 0, z), Vector3(.4, 20.6, .14), g)
	# arco: quarto de círculo centrado no meio do portão
	var cx = s * 3.5
	var cy = 3.6
	var R = 5.4
	var n = 12
	for i in n:
		var a0 = PI / 2 + (s * 1.0) * (float(i) / n) * PI / 2
		var a1 = PI / 2 + (s * 1.0) * (float(i + 1) / n) * PI / 2
		var am = (a0 + a1) * .5
		var px = cx - s * abs(cos(am)) * R
		var py = cy + sin(am) * R
		var seg = _db(sb, Vector3(px, py, z * 1.02), Vector3(.34, R * PI / 2 / n + .05, .16), g)
		seg.rotation.z = am
	_db(sb, Vector3(cx - s * R, cy - 6.4, z * 1.02), Vector3(.34, 12.8, .16), g)
	# medalhão com raios de sol e rubi
	var mc = Vector3(cx - s * 2.75, -1.2, z * 1.06)
	_ring_at(sb, mc, 1.75, .26, g)
	_ring_at(sb, mc, 1.25, .1, g)
	var disc_ = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = 1.5; cm.bottom_radius = 1.5; cm.height = .08; cm.radial_segments = 24
	disc_.mesh = cm; disc_.material_override = m_gold_dark
	disc_.rotation.x = PI / 2; disc_.position = mc - Vector3(0, 0, f * .04)
	sb.add_child(disc_)
	for k in 16:
		var a = k * TAU / 16
		var ray = _db(sb, mc + Vector3(cos(a), sin(a), 0) * .78, Vector3(.1, .62 if k % 2 == 0 else .4, .1), g)
		ray.rotation.z = a - PI / 2
	var boss = MeshInstance3D.new()
	var sp = SphereMesh.new(); sp.radius = .42; sp.height = .6
	boss.mesh = sp; boss.material_override = _gem_mat()
	boss.position = mc + Vector3(0, 0, f * .1)
	sb.add_child(boss)
	# volutas acima e abaixo do medalhão
	for k in [-1, 1]:
		_ring_at(sb, Vector3(mc.x + k * .9, 2.6, z * 1.04), .55, .1, g)
		_ring_at(sb, Vector3(mc.x + k * .9, -5.4, z * 1.04), .5, .1, g)
	_db(sb, Vector3(mc.x, 2.0, z * 1.03), Vector3(.18, 2.0, .12), g)
	_db(sb, Vector3(mc.x, -4.6, z * 1.03), Vector3(.18, 2.0, .12), g)
	# painel inferior e flor no alto do arco
	_db(sb, Vector3(mc.x, -8.0, z * 1.01), Vector3(3.6, 2.6, .1), m_gold_dark)
	_db(sb, Vector3(mc.x, -8.0, z * 1.03), Vector3(3.0, .2, .1), g)
	_ring_at(sb, Vector3(mc.x, 6.2, z * 1.04), .45, .1, g)
	# cravos ao longo da emenda
	for k in 9:
		var st = MeshInstance3D.new()
		var ss = SphereMesh.new(); ss.radius = .17; ss.height = .34
		st.mesh = ss; st.material_override = g
		st.position = Vector3(s * 3.32, -9.4 + k * 2.35, z * 1.1)
		sb.add_child(st)

var _gem: StandardMaterial3D
func _gem_mat() -> StandardMaterial3D:
	if _gem == null:
		_gem = StandardMaterial3D.new()
		_gem.albedo_color = Color("b0101a")
		_gem.roughness = .12
		_gem.metallic_specular = 1.0
		_gem.emission_enabled = true; _gem.emission = Color(.35, 0, .02)
	return _gem

## moldura do portão do lado do corredor: colunas, pedestais com máscaras, entablamento e palmeta
func _door_frame() -> void:
	var zf = DOOR_Z + 1.0   # face da parede no corredor
	for sx in [-1, 1]:
		var x = sx * 8.1
		# pedestal com máscara de anjo chorando sangue
		blk(x, 0, zf + .8, 1.9, 3.2, 1.6, m_gold)
		blk(x, 3.2, zf + .8, 2.1, .3, 1.8, m_gold, false)
		blk(x, .5, zf + 1.62, 1.3, 2.0, .06, m_gold_dark, false)
		var head = MeshInstance3D.new()
		var hs = SphereMesh.new(); hs.radius = .48; hs.height = .96
		head.mesh = hs; head.material_override = m_gold
		head.scale = Vector3(1, 1.2, .55)
		head.position = Vector3(x, 1.6, zf + 1.68)
		add_child(head)
		for ex in [-.17, .17]:
			blk(x + ex, 1.72, zf + 1.92, .17, .08, .04, glow(Color(.08, 0, 0)), false)
			blk(x + ex, 1.1, zf + 1.92, .06, .62, .03, glow(Color(.55, 0, .02)), false)
		# fuste canelado com anéis
		cyl(x, 3.5, zf + .8, .62, .66, 15.8, m_gold)
		for k in 10:
			var a = k * TAU / 10
			blk(x + cos(a) * .64, 3.6, zf + .8 + sin(a) * .64, .1, 15.6, .1, m_gold_dark, false)
		for y in [8.0, 13.5]:
			var r = MeshInstance3D.new()
			var tm = TorusMesh.new(); tm.inner_radius = .6; tm.outer_radius = .86; tm.rings = 24
			r.mesh = tm; r.material_override = m_gold
			r.position = Vector3(x, y, zf + .8)
			add_child(r)
		# capitel
		cyl(x, 19.3, zf + .8, .95, .62, .8, m_gold, false)
		blk(x, 20.0, zf + .8, 2.0, .3, 1.8, m_gold, false)
	# entablamento: arquitrave, friso com dentículos e volutas, cornija
	blk(0, 20.2, zf + .75, 19.4, 1.0, 1.5, m_gold, false)
	blk(0, 21.2, zf + .7, 18.8, 1.5, 1.4, m_gold_dark, false)
	for i in 32:
		blk(-9.0 + i * .58, 22.15, zf + 1.45, .32, .4, .16, m_gold, false)
	for i in 8:
		var r = MeshInstance3D.new()
		var tm = TorusMesh.new(); tm.inner_radius = .26; tm.outer_radius = .4; tm.rings = 16
		r.mesh = tm; r.material_override = m_gold
		r.rotation.x = PI / 2
		r.position = Vector3(-7.7 + i * 2.2, 21.45, zf + 1.42)
		add_child(r)
	blk(0, 22.7, zf + .8, 19.8, .5, 1.8, m_gold, false)
	blk(0, 23.2, zf + .85, 20.0, .55, 2.0, m_gold, false)
	# palmeta no centro, sobre o vão
	var pc = Vector3(0, 19.0, zf + .35)
	for i in 9:
		var a = PI / 2 + (i - 4) * .3
		var leaf = blk(pc.x + cos(a) * .9, pc.y + sin(a) * .9 - .45, pc.z, .26, 1.5, .2, m_gold, false)
		leaf.rotation.z = a - PI / 2
	var gem = MeshInstance3D.new()
	var gs = SphereMesh.new(); gs.radius = .38; gs.height = .6
	gem.mesh = gs; gem.material_override = _gem_mat()
	gem.position = pc + Vector3(0, -.2, .2)
	add_child(gem)

func _altar() -> void:
	# altar em 5 degraus, topo em y = 8
	for i in 5:
		var w = 46.0 - i * 7.0
		var d = 32.0 - i * 4.0
		var front = -46.0 - i * 2.6
		blk(0, i * 1.6, front - d * .5, w, 1.6, d, m_marble)
		blk(0, (i + 1) * 1.6 - .05, front - .2, w + .1, .12, .45, m_gold, false)
	_stair_river()
	pool(0, -43.5, 5.5, .04, .6)
	# trono
	var tz = -71.0
	_throne(tz)
	# raios de sol atrás do trono
	var sun_c = Vector3(0, 37, tz - 3.6)
	for i in 18:
		var a = i * TAU / 18
		var r = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = .05; cm.bottom_radius = .55; cm.height = 9.0 if i % 2 == 0 else 5.5
		cm.radial_segments = 6
		r.mesh = cm
		r.material_override = m_gold
		r.position = sun_c + Vector3(cos(a), sin(a), 0) * (16.0 + cm.height * .5)
		r.rotation.z = a - PI / 2
		add_child(r)
	halo = MeshInstance3D.new()
	var hr = TorusMesh.new()
	hr.inner_radius = 14.2; hr.outer_radius = 15.6; hr.rings = 64
	halo.mesh = hr
	halo.material_override = glow(Color(1, .78, .35))
	# de pé, parada, atrás do encosto do trono (sem atravessá-lo)
	halo.rotation = Vector3(PI / 2, 0, 0)
	halo.position = sun_c + Vector3(0, 0, -2.4)
	add_child(halo)
	# braseiros nos cantos do topo
	for sx in [-1, 1]:
		cyl(sx * 5.6, ALTAR_TOP, -61.3, .5, .8, 3.0, m_gold, false)
		_flame(Vector3(sx * 5.6, ALTAR_TOP + 3.6, -61.3), 1.0)
	_creek()

# ---------------- cascata de sangue na escada do altar ----------------
func _stair_river() -> void:
	var W = 2.4
	for i in range(4, -1, -1):
		var front = -46.0 - i * 2.6
		# espelho do degrau: o sangue cai pela frente
		var riser = quad(Vector3(0, i * 1.6 + .8, front + .03), Vector2(W, 1.66), bm(0, 40.0 + i, 1.5, Vector2(1, .7)))
		# piso do degrau de baixo: o sangue corre até a próxima queda
		if i > 0:
			var prev_front = -46.0 - (i - 1) * 2.6
			flat(Vector3(0, i * 1.6 + .03, (front + prev_front) * .5), Vector2(W, 2.62), bm(0, 50.0 + i, .7, Vector2(1, 1.3)))
		var pt = CPUParticles3D.new()
		pt.amount = 12; pt.lifetime = .5
		pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		pt.emission_box_extents = Vector3(W * .4, .02, .1)
		pt.direction = Vector3(0, .8, 1); pt.spread = 35
		pt.initial_velocity_min = .8; pt.initial_velocity_max = 1.8
		pt.gravity = Vector3(0, -9.8, 0)
		var dm = SphereMesh.new(); dm.radius = .05; dm.height = .14; dm.radial_segments = 5; dm.rings = 3
		dm.material = glow(Color(.6, .01, .03))
		pt.mesh = dm
		pt.position = Vector3(0, i * 1.6 + .08, front + .25)
		add_child(pt)

# ---------------- corredor: estátuas retorcidas e quadros grotescos ----------------
func _corridor_decor() -> void:
	var spots = [[-1, 58.0], [1, 67.0], [-1, 76.0], [1, 85.0], [-1, 94.0], [1, 103.0]]
	for i in spots.size():
		var sx: int = spots[i][0]
		var z: float = spots[i][1]
		_statue(Vector3(sx * 6.4, 0, z), sx, i)
		_painting(Vector3(sx * 8.93, 13.2, z), sx, i)

func _seg(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material = null) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	if mesh:
		var m = MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat if mat else m_marble
		n.add_child(m)
	return n

func _sc(n: Node3D, v: Vector3) -> void:
	(n.get_child(0) as Node3D).scale = v

func _cylm(r0: float, r1: float, h: float) -> CylinderMesh:
	var c = CylinderMesh.new(); c.top_radius = r0; c.bottom_radius = r1; c.height = h; c.radial_segments = 10; c.rings = 1
	return c

## osso: articulação em 'pos' com rotação 'rot'; a peça vai da articulação até (0, length, 0)
func _bone(parent: Node3D, pos: Vector3, rot: Vector3, length: float, r0: float, r1: float, mat: Material = null) -> Node3D:
	var j = Node3D.new()
	j.position = pos
	j.rotation = rot
	parent.add_child(j)
	if length > 0.0:
		var m = MeshInstance3D.new()
		var c = CylinderMesh.new(); c.bottom_radius = r0; c.top_radius = r1; c.height = length; c.radial_segments = 12; c.rings = 2
		m.mesh = c; m.material_override = mat if mat else m_statue
		m.position = Vector3(0, length * .5, 0)
		j.add_child(m)
		# junta arredondada
		var ball = MeshInstance3D.new()
		var sp = SphereMesh.new(); sp.radius = r0 * 1.02; sp.height = r0 * 2.04; sp.radial_segments = 10; sp.rings = 6
		ball.mesh = sp; ball.material_override = m.material_override
		j.add_child(ball)
	return j

func _blob(parent: Node3D, pos: Vector3, scl: Vector3, mat: Material = null) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var sp = SphereMesh.new(); sp.radius = .5; sp.height = 1.0; sp.radial_segments = 14; sp.rings = 8
	m.mesh = sp; m.material_override = mat if mat else m_statue
	m.position = pos; m.scale = scl
	parent.add_child(m)
	return m

var m_statue: StandardMaterial3D

## anjo de mármore ajoelhado, torcido em agonia, chorando sangue, num pedestal
func _statue(p: Vector3, sx: int, idx: int) -> void:
	if m_statue == null:
		m_statue = m_marble.duplicate()
		m_statue.albedo_color = Color(1.0, .98, .95)
		m_statue.roughness = .3
	var r = RandomNumberGenerator.new(); r.seed = 700 + idx
	var red = glow(Color(.6, 0, .03))
	# pedestal
	blk(p.x, 0, p.z, 2.1, 1.5, 2.1, m_marble2)
	blk(p.x, 1.4, p.z, 2.3, .22, 2.3, m_gold, false)
	blk(p.x, .05, p.z, 2.3, .2, 2.3, m_gold, false)
	stain(Vector3(p.x - sx * 1.06, .85, p.z), Vector3(-sx, 0, 0), 1.6, 1.3)
	pool(p.x - sx * 1.6, p.z + r.randf_range(-.6, .6), r.randf_range(.9, 1.4), .05)
	var root = Node3D.new()
	root.position = Vector3(p.x, 1.62, p.z)
	root.rotation.y = (PI / 2 if sx < 0 else -PI / 2) + r.randf_range(-.35, .35)   # de frente para o meio do corredor
	add_child(root)
	# quadril e pernas ajoelhadas (coxas descem até o joelho no chão, canelas vão para trás)
	var pelvis = Node3D.new(); pelvis.position = Vector3(0, 1.05, 0); root.add_child(pelvis)
	_blob(pelvis, Vector3(0, 0, 0), Vector3(.62, .38, .42))
	for side in [-1, 1]:
		var lift = .25 if (side == 1 and idx % 2 == 0) else 0.0   # uma perna apoiada à frente em algumas
		var thigh = _bone(pelvis, Vector3(side * .19, 0, 0), Vector3(PI - .35 - lift * 1.2, 0, side * .06), 1.0, .17, .14)
		var shin = _bone(thigh, Vector3(0, 1.0, 0), Vector3(1.75 if lift == 0.0 else 1.2, 0, 0), .95, .13, .09)
		_blob(shin, Vector3(0, .98, .06), Vector3(.13, .1, .26))
	# coluna arqueada para trás e torcida em espiral
	var twist = r.randf_range(.17, .24) * (1 if idx % 2 else -1)
	var spine: Node3D = pelvis
	var pos = Vector3(0, .12, 0)
	for k in 5:
		var rad = .27 + .05 * sin(float(k) / 4.0 * PI)
		spine = _bone(spine, pos, Vector3(-.1, twist, r.randf_range(-.05, .05)), .3, rad, rad * .97)
		pos = Vector3(0, .3, 0)
	var chest = Node3D.new(); chest.position = Vector3(0, .3, 0); chest.rotation = Vector3(-.15, twist, 0); spine.add_child(chest)
	_blob(chest, Vector3(0, .1, 0), Vector3(.9, .5, .48))
	# pescoço e cabeça jogada para trás, boca aberta, olhos chorando sangue
	var neck = _bone(chest, Vector3(0, .3, 0), Vector3(-.55, twist * 1.5, r.randf_range(-.25, .25)), .3, .1, .09)
	var head = Node3D.new(); head.position = Vector3(0, .42, .02); head.rotation = Vector3(-.5, 0, 0); neck.add_child(head)
	_blob(head, Vector3.ZERO, Vector3(.4, .5, .44))
	for ex in [-.09, .09]:
		_blob(head, Vector3(ex, .05, .19), Vector3(.08, .05, .04), glow(Color(.05, 0, 0)))
		_db(head, Vector3(ex, -.09, .2), Vector3(.025, .22, .02), red)
	_blob(head, Vector3(0, -.13, .19), Vector3(.1, .14, .05), glow(Color(.03, 0, 0)))
	# braços: um erguido arranhando o ar, o outro cravando os dedos no rosto
	var up_side = 1 if idx % 2 else -1
	for side in [-1, 1]:
		var shoulder = Node3D.new(); shoulder.position = Vector3(side * .44, .22, 0); chest.add_child(shoulder)
		var upper: Node3D
		var fore: Node3D
		if side == up_side:
			upper = _bone(shoulder, Vector3.ZERO, Vector3(r.randf_range(-.4, .1), 0, -side * 2.6), .7, .1, .085)
			fore = _bone(upper, Vector3(0, .7, 0), Vector3(r.randf_range(-.5, -.2), 0, side * .35), .62, .08, .06)
		else:
			upper = _bone(shoulder, Vector3.ZERO, Vector3(-1.2, 0, -side * .5), .65, .1, .085)
			fore = _bone(upper, Vector3(0, .65, 0), Vector3(-2.0, 0, side * .5), .58, .08, .06)
		var hand = Node3D.new(); hand.position = Vector3(0, .62, 0); fore.add_child(hand)
		_blob(hand, Vector3(0, .07, 0), Vector3(.17, .2, .08))
		for fi in 4:
			_bone(hand, Vector3(-.06 + fi * .04, .15, 0), Vector3(r.randf_range(-.9, -.2), 0, (fi - 1.5) * .15), .17, .018, .012)
	# asas: inteiras em umas, quebradas em outras
	for side in [-1, 1]:
		var broken = (idx + (0 if side < 0 else 1)) % 3 == 0
		var w = Node3D.new()
		w.position = Vector3(side * .2, .15, -.22)
		w.rotation = Vector3(.3 if not broken else 1.3, side * .4, -side * (.5 if not broken else -.4))
		chest.add_child(w)
		for fi in 5:
			var f = _bone(w, Vector3(side * .12 * fi, -.05 * fi, -.02 * fi), Vector3(0, 0, -side * (.25 + fi * .18)), 1.5 - fi * .16, .07, .025)
			(f.get_child(0) as MeshInstance3D).scale = Vector3(1.6, 1, .35)
	# gotas de sangue caindo dos olhos
	var pt = CPUParticles3D.new()
	pt.amount = 6; pt.lifetime = 1.6
	pt.direction = Vector3(0, -1, 0); pt.spread = 5
	pt.initial_velocity_min = .2; pt.initial_velocity_max = .4
	pt.gravity = Vector3(0, -9.8, 0)
	var dm = SphereMesh.new(); dm.radius = .045; dm.height = .14; dm.radial_segments = 5; dm.rings = 3
	dm.material = red
	pt.mesh = dm
	pt.local_coords = false
	head.add_child(pt)
	pt.position = Vector3(0, -.2, .22)

## quadro grotesco com moldura preta e dourada
func _painting(p: Vector3, sx: int, idx: int) -> void:
	var root = Node3D.new()
	root.position = p
	root.rotation.y = -sx * PI / 2
	add_child(root)
	var W = 4.4
	var H = 5.6
	var canvas = MeshInstance3D.new()
	var q = QuadMesh.new(); q.size = Vector2(W, H)
	canvas.mesh = q
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(_paint(idx))
	m.albedo_color = Color(.82, .78, .76)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	canvas.material_override = m
	canvas.position.z = .06
	root.add_child(canvas)
	var black = StandardMaterial3D.new(); black.albedo_color = Color(.03, .02, .02); black.roughness = .3
	for e in [[0, H * .5 + .14, W + .56, .28], [0, -H * .5 - .14, W + .56, .28]]:
		_db(root, Vector3(e[0], e[1], .1), Vector3(e[2], e[3], .16), black)
	for e in [[W * .5 + .14, 0, .28, H], [-W * .5 - .14, 0, .28, H]]:
		_db(root, Vector3(e[0], e[1], .1), Vector3(e[2], e[3], .16), black)
	for e in [[0, H * .5 + .5, W + 1.3, .45], [0, -H * .5 - .5, W + 1.3, .45]]:
		_db(root, Vector3(e[0], e[1], .14), Vector3(e[2], e[3], .26), m_gold)
	for e in [[W * .5 + .5, 0, .45, H + 1.3], [-W * .5 - .5, 0, .45, H + 1.3]]:
		_db(root, Vector3(e[0], e[1], .14), Vector3(e[2], e[3], .26), m_gold)
	for c in [[1, 1], [1, -1], [-1, 1], [-1, -1]]:
		var o = MeshInstance3D.new()
		var sp = SphereMesh.new(); sp.radius = .32; sp.height = .64
		o.mesh = sp; o.material_override = m_gold
		o.position = Vector3(c[0] * (W * .5 + .5), c[1] * (H * .5 + .5), .3)
		root.add_child(o)
	var cart = _db(root, Vector3(0, H * .5 + .85, .2), Vector3(1.3, .5, .2), m_gold)
	var gm = MeshInstance3D.new()
	var gs = SphereMesh.new(); gs.radius = .16; gs.height = .26
	gm.mesh = gs; gm.material_override = _gem_mat()
	gm.position = Vector3(0, H * .5 + .85, .33)
	root.add_child(gm)

# ---- pintura procedural (pixel art 96 x 122) ----
func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height(): img.set_pixel(x, y, c)

func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, jag := 0.0) -> void:
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var dx = (x - cx) / rx; var dy = (y - cy) / ry
			var j = 1.0 + jag * (sin(atan2(dy, dx) * 7.0 + cx) * .5)
			if dx * dx + dy * dy <= j * j: _px(img, x, y, c)

func _ln(img: Image, x0: float, y0: float, x1: float, y1: float, w: float, c: Color) -> void:
	var n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
	for i in n + 1:
		var t = float(i) / n
		_ell(img, lerp(x0, x1, t), lerp(y0, y1, t), w, w, c)

func _drip(img: Image, x: int, y: int, l: int, c: Color) -> void:
	for k in l: _px(img, x, y + k, c)
	_px(img, x - 1, y + l, c); _px(img, x + 1, y + l, c); _px(img, x, y + l + 1, c)

func _paint(idx: int) -> Image:
	var Wd = 96; var Ht = 122
	var img = Image.create(Wd, Ht, false, Image.FORMAT_RGBA8)
	var r = RandomNumberGenerator.new(); r.seed = 31 + idx
	var bg0 = [Color("2a0806"), Color("120608"), Color("0b0a14"), Color("6a4a14"), Color("140405"), Color("5c4010")][idx]
	var bg1 = [Color("0c0202"), Color("3a0a0a"), Color("02030a"), Color("b08a38"), Color("050101"), Color("a07a2a")][idx]
	for y in Ht:
		for x in Wd:
			var c: Color = bg0.lerp(bg1, float(y) / Ht)
			c = c.lightened(r.randf_range(0, .05))
			img.set_pixel(x, y, c)
	var pale = Color("d9cdb8"); var blood = Color("8a0a10"); var dark = Color("0a0303"); var gold = Color("e0b04a")
	match idx:
		0: # O Olhar: rosto magro com olhos demais, chorando sangue
			_ell(img, 48, 58, 26, 38, pale.darkened(.1))
			for e in [[36, 40], [60, 40], [48, 54], [32, 66], [64, 66], [48, 30], [42, 80]]:
				_ell(img, e[0], e[1], 5, 3, Color.WHITE)
				_ell(img, e[0], e[1], 2, 2, blood)
				_drip(img, e[0], e[1] + 3, r.randi_range(6, 24), blood)
			_ell(img, 48, 92, 7, 3, dark)
		1: # O Grito: espiral vermelha e uma boca escancarada
			for k in 260:
				var a = k * .19
				var rr = 4 + k * .17
				_ell(img, 48 + cos(a) * rr, 60 + sin(a) * rr * 1.2, 2, 2, Color("6a1010").lerp(Color("c03018"), float(k % 30) / 30.0))
			_ell(img, 48, 60, 18, 26, pale)
			_ell(img, 48, 66, 9, 14, dark)
			for t in 6: _px(img, 42 + t * 2, 53, Color.WHITE); _px(img, 42 + t * 2, 79, Color.WHITE)
			_ell(img, 41, 46, 3, 4, dark); _ell(img, 55, 46, 3, 4, dark)
		2: # Anjo Caído: asas rasgadas, auréola partida, poça de sangue
			_ell(img, 48, 112, 36, 7, blood)
			_ln(img, 48, 40, 40, 100, 3, pale); _ln(img, 48, 40, 56, 100, 3, pale)
			_ell(img, 48, 34, 6, 7, pale)
			for side in [-1, 1]:
				for k in 6:
					_ln(img, 48 + side * 6, 50, 48 + side * (18 + k * 4), 30 + k * 10 + r.randi_range(-3, 3), 1, pale.darkened(.2))
			for k in 10:
				var a = -PI + k * .25
				if k != 5 and k != 6: _px(img, int(48 + cos(a) * 11), int(26 + sin(a) * 4), gold)
			for k in 8: _drip(img, r.randi_range(36, 60), r.randi_range(60, 96), r.randi_range(4, 14), blood)
		3: # A Mão: mão pálida com um olho na palma, fundo de ícone dourado
			_ell(img, 48, 76, 20, 24, pale)
			for f in 4: _ln(img, 34 + f * 9, 56, 32 + f * 10, 16 + abs(f - 1.5) * 6, 3.5, pale)
			_ln(img, 28, 80, 14, 60, 4, pale)
			for f in 4: _ell(img, 32 + f * 10, 17 + abs(f - 1.5) * 6, 2, 2, dark)
			_ell(img, 48, 78, 9, 5, Color.WHITE)
			_ell(img, 48, 78, 4, 4, blood); _ell(img, 48, 78, 2, 2, dark)
			_drip(img, 48, 84, 30, blood)
		4: # Coroa de Mãos: círculo de mãos em volta de um olho vermelho
			for k in 12:
				var a = k * TAU / 12
				var hx = 48 + cos(a) * 32; var hy = 60 + sin(a) * 38
				_ell(img, hx, hy, 5, 7, pale.darkened(.15))
				_ln(img, hx, hy, 48 + cos(a) * 22, 60 + sin(a) * 26, 1, blood)
			_ell(img, 48, 60, 14, 14, blood.darkened(.3))
			_ell(img, 48, 60, 10, 6, Color("ffd0a0"))
			_ell(img, 48, 60, 4, 5, dark)
		5: # Santo sem Rosto: ícone dourado, manto vermelho, rosto vazio chorando sangue
			_ell(img, 48, 36, 18, 18, gold.lightened(.2))
			_ell(img, 48, 38, 12, 14, pale)
			_ell(img, 48, 40, 7, 9, dark, .3)
			_ln(img, 48, 54, 26, 118, 6, Color("7a0a12")); _ln(img, 48, 54, 70, 118, 6, Color("7a0a12"))
			_ell(img, 48, 92, 18, 28, Color("7a0a12"))
			_drip(img, 44, 44, 40, blood); _drip(img, 52, 44, 32, blood)
	return img

# ---------------- córrego de sangue em volta do trono ----------------
## nasce em duas bocas douradas na base do trono, contorna a frente fazendo curvas e despenca escada abaixo.
## Cada braço é um caminho contínuo (retas + arcos); sangue, leito e meio-fios são gerados ao longo dele.
func _creek() -> void:
	var Y = ALTAR_TOP
	var lx = 7.9        # pernas laterais
	var zb = -64.2      # nascente (junto à base do trono)
	var zf = -58.6      # trecho da frente
	var zo = -56.35     # borda do altar (onde começa o rio da escada)
	var W = 1.3
	var R1 = 2.6        # curva da lateral para a frente
	var R2 = 1.7        # curva da frente para a descida
	var CW = .24        # largura do meio-fio
	for sx in [-1, 1]:
		var pts = []
		pts.append(Vector2(sx * lx, zb))
		_arc(pts, Vector2(sx * (lx - R1), zf - R1), R1, PI if sx < 0 else 0.0, PI / 2, 14)
		_arc(pts, Vector2(sx * R2, zf + R2), R2, -PI / 2, PI if sx > 0 else 0.0, 10, true)
		pts.append(Vector2(0, zo))
		pts = _resample(pts, .2)
		var n_arc2 = 0  # índice onde começa a última curva (o meio-fio de dentro para ali)
		for i in pts.size():
			if abs(pts[i].x) <= R2 + .01 and pts[i].y >= zf - .01:
				n_arc2 = i; break
		var y_off = .07 + (.006 if sx > 0 else 0.0)
		add_child(_ribbon(pts, W, Y + y_off, bm(0, 21.0 + sx, .5, Vector2.ONE), true))
		add_child(_ribbon(pts, W + .5, Y + .015, m_gold_dark, false))
		# meio-fio de fora (lado da escada): o caminho inteiro; de dentro: só até a última curva
		var outer = sx  # o lado esquerdo do braço esquerdo é o de dentro; o de fora é o direito (negativo)
		add_child(_curb(pts, outer * (W * .5 + CW * .5), CW, Y))
		add_child(_curb(pts.slice(0, n_arc2 + 1), -outer * (W * .5 + CW * .5), CW, Y))
	# meio-fio do encontro, do lado do trono
	blk(0, Y, zf - (W * .5 + CW * .5), 2 * R2, .22, CW, m_gold, false)
	# as bocas de onde o sangue brota
	for sx in [-1, 1]:
		var x = sx * lx
		blk(x, Y, zb - .9, 1.6, 1.4, 1.2, m_gold, false)
		var mouth = MeshInstance3D.new()
		var mm = BoxMesh.new(); mm.size = Vector3(.8, .35, .1)
		mouth.mesh = mm; mouth.material_override = glow(Color(.25, 0, .02))
		mouth.position = Vector3(x, Y + .7, zb - .28)
		add_child(mouth)
		var fall = quad(Vector3(x, Y + .38, zb - .2), Vector2(.6, .62), bm(0, 30.0 + sx, 1.4, Vector2(1, 1)))
		var pt = CPUParticles3D.new()
		pt.amount = 18; pt.lifetime = .5
		pt.direction = Vector3(0, .6, 1); pt.spread = 30
		pt.initial_velocity_min = .8; pt.initial_velocity_max = 1.8
		pt.gravity = Vector3(0, -9.8, 0)
		var dm = SphereMesh.new(); dm.radius = .05; dm.height = .14; dm.radial_segments = 5; dm.rings = 3
		dm.material = glow(Color(.6, .01, .03))
		pt.mesh = dm
		pt.position = Vector3(x, Y + .12, zb + .1)
		add_child(pt)
	# respingo onde o córrego despenca na escada
	var sp = CPUParticles3D.new()
	sp.amount = 26; sp.lifetime = .7
	sp.direction = Vector3(0, .4, 1); sp.spread = 35
	sp.initial_velocity_min = 1.2; sp.initial_velocity_max = 2.6
	sp.gravity = Vector3(0, -9.8, 0)
	var dm2 = SphereMesh.new(); dm2.radius = .06; dm2.height = .16; dm2.radial_segments = 5; dm2.rings = 3
	dm2.material = glow(Color(.6, .01, .03))
	sp.mesh = dm2
	sp.position = Vector3(0, Y + .1, zo)
	add_child(sp)

func _arc(pts: Array, c: Vector2, r: float, a0: float, a1: float, n: int, ccw := false) -> void:
	# acrescenta um arco de a0 a a1 pelo caminho mais curto
	var d = wrapf(a1 - a0, -PI, PI)
	for i in n + 1:
		var a = a0 + d * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)

func _resample(pts: Array, step: float) -> Array:
	var out = [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector2 = out[out.size() - 1]
		var b: Vector2 = pts[i]
		var L = a.distance_to(b)
		if L < 1e-4: continue
		var k = int(ceil(L / step))
		for j in range(1, k + 1): out.append(a.lerp(b, float(j) / k))
	return out

func _left(pts: Array, i: int) -> Vector2:
	var a: Vector2 = pts[max(0, i - 1)]
	var b: Vector2 = pts[min(pts.size() - 1, i + 1)]
	var d = (b - a).normalized()
	return Vector2(d.y, -d.x)

## faixa ao longo do caminho (uv.x atravessa, uv.y segue o comprimento)
func _ribbon(pts: Array, w: float, y: float, mat: Material, uv := true) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s = 0.0
	var prev = []
	for i in pts.size():
		if i > 0: s += (pts[i] as Vector2).distance_to(pts[i - 1])
		var l = _left(pts, i) * w * .5
		var L3 = Vector3(pts[i].x + l.x, y, pts[i].y + l.y)
		var R3 = Vector3(pts[i].x - l.x, y, pts[i].y - l.y)
		var cur = [L3, R3, s * .5]
		if i > 0:
			for v in [[prev[0], 0.0, prev[2]], [prev[1], 1.0, prev[2]], [cur[0], 0.0, cur[2]], [cur[0], 0.0, cur[2]], [prev[1], 1.0, prev[2]], [cur[1], 1.0, cur[2]]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], v[2] / 4.0))
				st.add_vertex(v[0])
		prev = cur
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

var _gold2: StandardMaterial3D

## meio-fio dourado contínuo, deslocado 'off' para a esquerda do caminho
func _curb(pts: Array, off: float, w: float, y0: float, h := .22) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev = []
	for i in pts.size():
		var l = _left(pts, i)
		var c = pts[i] + l * off
		var a = c + l * w * .5
		var b = c - l * w * .5
		var cur = [Vector3(a.x, y0, a.y), Vector3(a.x, y0 + h, a.y), Vector3(b.x, y0 + h, b.y), Vector3(b.x, y0, b.y)]
		if i > 0:
			for f in [[0, 1], [1, 2], [2, 3]]:
				var p0 = prev[f[0]]; var p1 = prev[f[1]]; var q0 = cur[f[0]]; var q1 = cur[f[1]]
				for v in [p0, p1, q0, q0, p1, q1]: st.add_vertex(v)
		prev = cur
	st.generate_normals()
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	if _gold2 == null:
		_gold2 = m_gold.duplicate()
		_gold2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _gold2
	return mi

# ---------------- trono detalhado ----------------
var m_velvet: StandardMaterial3D
var m_gem: StandardMaterial3D

func _throne(tz: float) -> void:
	var Y = ALTAR_TOP
	m_velvet = StandardMaterial3D.new()
	m_velvet.albedo_color = Color("6e0a14")
	m_velvet.roughness = .6
	m_velvet.rim_enabled = true; m_velvet.rim = .55; m_velvet.rim_tint = .35
	m_velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_gem = StandardMaterial3D.new()
	m_gem.albedo_color = Color("b0101a")
	m_gem.roughness = .12
	m_gem.metallic_specular = 1.0
	m_gem.emission_enabled = true; m_gem.emission = Color(.35, 0, .02)
	# plataforma em dois degraus, com friso dourado
	blk(0, Y, tz - .5, 22, .7, 13, m_marble)
	blk(0, Y + .7, tz - .8, 18, .6, 11, m_marble2)
	for e in [[0, Y + .66, tz + 6.05, 22.1, .12, .2], [0, Y + 1.26, tz + 4.75, 18.1, .12, .2]]:
		blk(e[0], e[1], e[2], e[3], e[4], e[5], m_gold, false)
	var B = Y + 1.3  # base do trono
	# assento esculpido
	blk(0, B, tz + 2, 10, 3.0, 7, m_marble2)
	blk(0, B + 2.7, tz + 2, 10.3, .45, 7.3, m_gold, false)                 # faixa dourada
	blk(0, B + .6, tz + 5.52, 7.6, 1.6, .12, m_gold_dark, false)           # painel da frente
	for i in 13:                                                            # greca (faixa ornamental)
		var x = -4.5 + i * .75
		blk(x, B + .15, tz + 5.56, .5, .22 if i % 2 else .45, .1, m_gold, false)
	blk(0, B + 3.0, tz + 2, 8.6, .55, 6.2, m_velvet, false)                 # almofada
	# apoios de braço com braçadeiras e voluta na ponta
	for sx in [-1, 1]:
		blk(sx * 5.6, B, tz + 2, 1.9, 5.2, 7, m_marble)
		for zz in [tz + .3, tz + 3.4]:
			blk(sx * 5.6, B + 3.6, zz, 2.1, .9, .5, m_gold, false)
		var sc = cyl(sx * 5.6, B + 4.6, tz + 5.6, .9, .9, 2.0, m_gold, false)
		sc.rotation.z = PI / 2
		sc.position = Vector3(sx * 5.6, B + 4.9, tz + 5.4)
	# encosto: mármore com moldura de ouro e painel de veludo
	var bz = tz - 2.4
	blk(0, B, bz, 12, 30, 1.8, m_marble2)
	blk(0, B + 4, bz + .95, 9, 22, .12, m_velvet, false)
	for f in [[0, B + 3.6, 9.8, .5], [0, B + 26.0, 9.8, .5]]:
		blk(f[0], f[1], bz + 1.0, f[2], f[3], .2, m_gold, false)
	for sx in [-1, 1]: blk(sx * 4.7, B + 3.6, bz + 1.0, .45, 22.9, .2, m_gold, false)
	# coroa do encosto em arco escalonado com um olho de rubi
	for i in 5:
		blk(0, B + 30 + i * 1.1, bz, 10 - i * 2.0, 1.1, 1.8, m_gold)
	var eye = MeshInstance3D.new()
	var es = SphereMesh.new(); es.radius = .9; es.height = 1.2
	eye.mesh = es; eye.material_override = m_gem
	eye.position = Vector3(0, B + 31.6, bz + 1.0)
	add_child(eye)
	# pilares laterais com losangos, cravos e pináculos
	for sx in [-1, 1]:
		var px = sx * 7.6
		var pz = tz - 1.8
		blk(px, B, pz, 2.6, 34, 2.6, m_marble)
		blk(px, B, pz, 3.1, 1.2, 3.1, m_gold, false)
		blk(px, B + 33, pz, 3.1, 1.0, 3.1, m_gold, false)
		for k in 7:
			var y = B + 5.5 + k * 3.8
			# losango dourado com rubi na face da frente
			var d = MeshInstance3D.new()
			var dm = BoxMesh.new(); dm.size = Vector3(1.5, 1.5, .2)
			d.mesh = dm; d.material_override = m_gold
			d.position = Vector3(px, y, pz + 1.36)
			d.rotation.z = PI / 4
			add_child(d)
			var g = MeshInstance3D.new()
			var gm = BoxMesh.new(); gm.size = Vector3(.8, .8, .2)
			g.mesh = gm; g.material_override = m_gem
			g.position = Vector3(px, y, pz + 1.48)
			g.rotation.z = PI / 4
			add_child(g)
			# cravo apontando para fora (o pilar direito fica coberto pelo manto)
			if sx > 0: continue
			var sp = MeshInstance3D.new()
			var cm = CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = .35; cm.height = 1.3; cm.radial_segments = 8
			sp.mesh = cm; sp.material_override = m_gold
			sp.position = Vector3(px + sx * 1.9, y, pz)
			sp.rotation.z = -sx * PI / 2
			add_child(sp)
		# pináculo em forma de cetro
		var top = B + 34
		cyl(px, top, pz, .95, 1.2, .7, m_gold, false)
		var ball = MeshInstance3D.new()
		var bs = SphereMesh.new(); bs.radius = .85; bs.height = 1.7
		ball.mesh = bs; ball.material_override = m_gold
		ball.position = Vector3(px, top + 1.5, pz)
		add_child(ball)
		cyl(px, top + 2.2, pz, .28, .38, 3.2, m_gold, false)
		cyl(px, top + 5.3, pz, .6, .3, .5, m_gold, false)
		cyl(px, top + 5.8, pz, 0.0, .55, 3.0, m_gold, false, 8)
	# manto de veludo caindo do pilar direito até o chão
	# encostado na face de fora do pilar direito, do topo até o primeiro degrau
	add_child(_drape(Vector3(7.6 + 1.32, B + 33.0, tz - 1.8), 3.4, (B + 33.0) - (Y + .72)))

## manto: malha com dobras pendurada numa face vertical (largura ao longo de z, dobras para fora em +x),
## que se esparrama sobre o degrau no fim
func _drape(top: Vector3, w: float, h: float) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NU = 30
	var NV = 60
	var pos = []
	for j in NV + 1:
		var v = float(j) / NV
		var row = []
		for i in NU + 1:
			var u = float(i) / NU
			var width = w * (.85 + .35 * v)
			var z = (u - .5) * width
			var fold = (.5 + .5 * sin(u * PI * 6.0 + v * 2.2)) * (.12 + .7 * v) + (.5 + .5 * sin(u * PI * 15.0)) * .06
			var x = .03 + fold
			var y = -v * h
			var pool_v = clamp((v - .9) / .1, 0.0, 1.0)
			if pool_v > 0.0:
				y = -h
				x += pool_v * 1.0
				z += (u - .5) * pool_v * 1.2 + pool_v * .6
			row.append(Vector3(x, y, z))
		pos.append(row)
	for j in NV:
		for i in NU:
			var a = pos[j][i]; var b = pos[j][i + 1]; var c = pos[j + 1][i]; var d = pos[j + 1][i + 1]
			for p in [a, c, b, b, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_velvet
	mi.position = top
	# dobra que passa por cima do topo do pilar
	var cap = MeshInstance3D.new()
	var cb = BoxMesh.new(); cb.size = Vector3(2.9, .35, w * .9)
	cap.mesh = cb; cap.material_override = m_velvet
	cap.position = Vector3(-1.3, .2, 0)
	mi.add_child(cap)
	return mi

func _fountain(x: float, z: float) -> void:
	cyl(x, 0, z, 4.2, 4.6, 1.3, m_marble2)
	var rim = MeshInstance3D.new()
	var tm = TorusMesh.new(); tm.inner_radius = 3.95; tm.outer_radius = 4.35; tm.rings = 40
	rim.mesh = tm; rim.material_override = m_gold
	rim.position = Vector3(x, 1.32, z)
	add_child(rim)
	disc(Vector3(x, 1.18, z), 3.95, m_blood_still)
	cyl(x, 1.3, z, .65, .9, 2.6, m_marble2)
	cyl(x, 3.9, z, 1.9, 1.1, .7, m_gold, false)
	disc(Vector3(x, 4.58, z), 1.75, m_blood_still)
	# jorro central
	var pt = CPUParticles3D.new()
	pt.amount = 70
	pt.lifetime = 1.5
	pt.direction = Vector3(0, 1, 0); pt.spread = 14
	pt.initial_velocity_min = 5.0; pt.initial_velocity_max = 6.5
	pt.gravity = Vector3(0, -9.8, 0)
	pt.scale_amount_min = .7; pt.scale_amount_max = 1.3
	var dm = SphereMesh.new(); dm.radius = .09; dm.height = .26; dm.radial_segments = 5; dm.rings = 3
	dm.material = glow(Color(.65, .01, .03))
	pt.mesh = dm
	pt.position = Vector3(x, 4.7, z)
	add_child(pt)
	spouts.append(pt)
	# transbordo da bacia de cima
	var pt2 = CPUParticles3D.new()
	pt2.amount = 50; pt2.lifetime = .8
	pt2.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pt2.emission_ring_radius = 1.8; pt2.emission_ring_inner_radius = 1.7; pt2.emission_ring_height = .05
	pt2.emission_ring_axis = Vector3.UP
	pt2.direction = Vector3(0, -1, 0); pt2.spread = 5
	pt2.initial_velocity_min = .3; pt2.initial_velocity_max = .8
	pt2.gravity = Vector3(0, -9.8, 0)
	pt2.mesh = dm
	pt2.position = Vector3(x, 4.5, z)
	add_child(pt2)

func _bloodfall(side: int, z: float) -> void:
	var wx = side * 45.85
	# boca dourada de onde jorra
	blk(side * 45.2, 30.5, z, 1.6, 1.8, 3.0, m_gold, false)
	stain(Vector3(side * 45.85, 21, z), Vector3(-side, 0, 0), 4.5, 20)
	var f = quad(Vector3(side * 45.6, 15.4, z), Vector2(3.0, 30.4), bm(0, 5.0 + z * .01, 1.3, Vector2(1, 3)), Vector3(0, -side * PI / 2, 0))
	f.rotation = Vector3(0, -side * PI / 2, 0)
	pool(side * 42.0, z, 2.2, .04, .7)
	# calha no chão
	blk(side * 44.2, 0, z, 3.0, .8, 4.6, m_gold)
	flat(Vector3(side * 44.2, .82, z), Vector2(2.6, 4.2), m_blood_still)
	var pt = CPUParticles3D.new()
	pt.amount = 24; pt.lifetime = .6
	pt.direction = Vector3(-side, 1.5, 0); pt.spread = 40
	pt.initial_velocity_min = 1.5; pt.initial_velocity_max = 3.5
	pt.gravity = Vector3(0, -12, 0)
	var dm = SphereMesh.new(); dm.radius = .08; dm.height = .2; dm.radial_segments = 5; dm.rings = 3
	dm.material = glow(Color(.7, .02, .04))
	pt.mesh = dm
	pt.position = Vector3(side * 45.2, .9, z)
	add_child(pt)

func _candles() -> void:
	var li = 0
	for z in [34, 18, 2, -14, -30]:
		for sx in [-1, 1]:
			var x = sx * 10.0
			cyl(x, 0, z, .7, .9, .4, m_gold, false)
			cyl(x, .4, z, .12, .16, 5.2, m_gold, false)
			cyl(x, 5.6, z, .8, .3, .35, m_gold, false)
			_flame(Vector3(x, 6.25, z), .7)
			if li % 3 == 0: light(Vector3(x, 7, z), Color(1, .65, .35), 1.2, 14)
			li += 1

func _flame(p: Vector3, s: float) -> void:
	var f = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = .35 * s; sm.height = 1.1 * s; sm.radial_segments = 8; sm.rings = 4
	f.mesh = sm
	f.material_override = glow(Color(1, .6, .2))
	f.position = p
	add_child(f)
	var core = MeshInstance3D.new()
	var cm = SphereMesh.new(); cm.radius = .18 * s; cm.height = .55 * s; cm.radial_segments = 6; cm.rings = 3
	core.mesh = cm
	core.material_override = glow(Color(1, .95, .75))
	core.position = Vector3(0, -.1 * s, 0)
	f.add_child(core)
	flames.append([f, G.rnd(0, 10)])

# ---------------- estado ----------------
func reset_state() -> void:
	stage = "door"
	door_open = 0.0
	door_target = 0.0
	door_snd_done = false
	ct = 0.0
	shot_i = -1
	said.clear()
	deus = null
	surge = 0.0
	_apply_door()
	_overlay(false, true)
	if voice: voice.stop()

func _apply_door() -> void:
	var a = door_open * deg_to_rad(100)
	door_l.rotation.y = a
	door_r.rotation.y = -a

func _process(dt: float) -> void:
	if not is_inside_tree(): return
	var tt = Time.get_ticks_msec() / 1000.0
	for f in flames:
		f[0].scale = Vector3.ONE * (1.0 + .12 * sin(tt * 13 + f[1]) + .08 * sin(tt * 23 + f[1] * 2))
	surge = max(0.0, surge - dt * .4)
	for s in spouts:
		s.initial_velocity_min = 5.0 + surge * 6
		s.initial_velocity_max = 6.5 + surge * 8
	if G.state != "play" or G.mode != "deus": return
	var p = G.player.global_position
	# portão
	if stage == "door" and p.z < DOOR_Z + 13 and abs(p.x) < 9:
		door_target = 1.0
		if not door_snd_done:
			door_snd_done = true
			G.snd("boom", -6, .35)
			G.snd("clang", -10, .4)
			G.shake = max(G.shake, .3)
	if stage == "door" and p.z < DOOR_Z - 4: stage = "hall"
	if stage == "hall" and p.z < CUT_Z: _start_cut()
	if door_open != door_target:
		door_open = move_toward(door_open, door_target, dt / 3.2)
		_apply_door()
		if Engine.get_process_frames() % 20 == 0: G.shake = max(G.shake, .08)
	if stage == "cut": _run_cut(dt)

# ---------------- cutscene ----------------
func _build_overlay() -> void:
	ov = CanvasLayer.new()
	ov.layer = 8
	main.add_child(ov)
	bar_t = ColorRect.new(); bar_t.color = Color.BLACK
	bar_t.anchor_right = 1; bar_t.offset_bottom = 0
	ov.add_child(bar_t)
	bar_b = ColorRect.new(); bar_b.color = Color.BLACK
	bar_b.anchor_top = 1; bar_b.anchor_bottom = 1; bar_b.anchor_right = 1
	ov.add_child(bar_b)
	var fv = FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = 9
	fv.variation_embolden = .5
	sub_a = Label.new()
	sub_a.add_theme_font_override("font", fv)
	sub_a.add_theme_font_size_override("font_size", 30)
	sub_a.add_theme_color_override("font_color", Color("e0a83a"))
	sub_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_a.anchor_left = 0; sub_a.anchor_right = 1; sub_a.anchor_top = 1; sub_a.anchor_bottom = 1
	sub_a.offset_top = -92; sub_a.offset_bottom = -52
	ov.add_child(sub_a)
	sub_b = Label.new()
	sub_b.add_theme_font_size_override("font_size", 19)
	sub_b.add_theme_color_override("font_color", Color(1, 1, 1, .85))
	sub_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_b.anchor_left = 0; sub_b.anchor_right = 1; sub_b.anchor_top = 1; sub_b.anchor_bottom = 1
	sub_b.offset_top = -50; sub_b.offset_bottom = -20
	ov.add_child(sub_b)
	skip_lbl = Label.new()
	skip_lbl.text = "ESPAÇO  ·  PULAR"
	skip_lbl.add_theme_font_override("font", fv)
	skip_lbl.add_theme_font_size_override("font_size", 12)
	skip_lbl.add_theme_color_override("font_color", Color(1, 1, 1, .4))
	skip_lbl.anchor_left = 1; skip_lbl.anchor_right = 1
	skip_lbl.offset_left = -220; skip_lbl.offset_right = -30; skip_lbl.offset_top = 30
	skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ov.add_child(skip_lbl)
	_overlay(false, true)

func _overlay(on: bool, instant := false) -> void:
	var h = 88.0 if on else 0.0
	if instant:
		bar_t.offset_bottom = h; bar_b.offset_top = -h
	else:
		var tw = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(bar_t, "offset_bottom", h, .8)
		tw.tween_property(bar_b, "offset_top", -h, .8)
	sub_a.text = ""; sub_b.text = ""
	skip_lbl.visible = on

func _start_cut() -> void:
	stage = "cut"
	ct = 0.0
	shot_i = -1
	said.clear()
	G.player.frozen = true
	G.player.fire_held = false
	G.player.velocity = Vector3.ZERO
	main.hud.visible = false
	main.vpc2.visible = false
	_overlay(true)
	cam.global_position = G.player.cam.global_position
	cam.make_current()
	G.snd("boom", -4, .3)

func _say(i: int) -> void:
	if said.has(i): return
	said[i] = true
	var s = load("res://sfx/deus_voz_%d.wav" % (i + 1)) if ResourceLoader.exists("res://sfx/deus_voz_%d.wav" % (i + 1)) else null
	if s:
		voice.stream = s
		voice.play()
	sub_a.text = LINES[i][0]
	sub_b.text = LINES[i][1]
	sub_a.modulate.a = 0; sub_b.modulate.a = 0
	var tw = create_tween().set_parallel()
	tw.tween_property(sub_a, "modulate:a", 1.0, .4)
	tw.tween_property(sub_b, "modulate:a", 1.0, .6)

func _clear_sub() -> void:
	var tw = create_tween().set_parallel()
	tw.tween_property(sub_a, "modulate:a", 0.0, .5)
	tw.tween_property(sub_b, "modulate:a", 0.0, .5)

func _ease(u: float) -> float:
	u = clamp(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

func _shot(t0: float, t1: float, a: Vector3, b: Vector3, la: Vector3, lb: Vector3) -> void:
	var u = _ease((ct - t0) / (t1 - t0))
	cam.global_position = a.lerp(b, u)
	var look = la.lerp(lb, u)
	if cam.global_position.distance_to(look) > .01:
		cam.look_at(look, Vector3.UP)
	if G.shake > 0.01:
		cam.global_position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), G.rnd(-1, 1)) * G.shake * .25
	G.shake *= .93

func _run_cut(dt: float) -> void:
	ct += dt
	if Input.is_action_just_pressed("jump"):
		_end_cut(true)
		return
	var head: Vector3 = deus.head_pos() if is_instance_valid(deus) else DEUS_POS + Vector3(0, 28, 0)
	var chest = DEUS_POS + Vector3(0, 20, 0)
	var pe = G.player.global_position + Vector3(0, 1.6, 0)
	# 1. de trás do jogador, olhando o altar lá no alto
	if ct < 3.2:
		_shot(0, 3.2, pe + Vector3(1.5, .6, 5), pe + Vector3(.8, 1.2, 1.5), DEUS_POS + Vector3(0, 10, 0), head)
	# 2. rosto de Deus — primeira fala
	elif ct < 7.4:
		if shot_i < 2: shot_i = 2; G.snd("angel", -8, .4)
		_shot(3.2, 7.4, head + Vector3(9, -2, 26), head + Vector3(4, -1, 15), head, head + Vector3(0, -.5, 0))
		if ct > 3.6: _say(0)
	# 3. a crista se abre — "ajoelhe-se"
	elif ct < 11.6:
		if shot_i < 3:
			shot_i = 3
			_clear_sub()
			if is_instance_valid(deus): deus._play("reach", .9); deus.crest_spd = 2.0; deus.crest_r = 1.3
		_shot(7.4, 11.6, chest + Vector3(-34, -6, 30), chest + Vector3(-22, -2, 22), chest, head)
		if ct > 7.9:
			_say(1)
			G.shake = max(G.shake, .25)
	# 4. visão do jogador, de joelhos, olhando para cima
	elif ct < 16.0:
		if shot_i < 4:
			shot_i = 4
			_clear_sub()
			surge = 1.0
			G.snd("boom", -10, .25)
		var kneel = G.player.global_position + Vector3(0, .9, 0)
		_shot(11.6, 16.0, kneel, kneel + Vector3(0, -.15, -.6), head + Vector3(0, -12, 0), head)
		if ct > 12.0: _say(2)
	# 5. plano aberto — "eu sou o fim" — Deus se ergue
	elif ct < 21.5:
		if shot_i < 5:
			shot_i = 5
			_clear_sub()
			if is_instance_valid(deus): deus._play("idle", 1.0)
		_shot(16.0, 21.5, Vector3(36, 9, 14), Vector3(26, 14, -4), DEUS_POS + Vector3(0, 16, 0), DEUS_POS + Vector3(0, 26, 0))
		if ct > 16.3: _say(3)
		if ct > 19.0 and is_instance_valid(deus):
			deus.global_position.y = lerp(deus.global_position.y, ALTAR_TOP + 10.0, 1.0 - exp(-1.2 * dt))
			deus.crest_spd = 3.0
			G.shake = max(G.shake, .35)
		if ct > 19.0 and not said.has("rise"):
			said["rise"] = true
			G.snd("angel", -2, .35)
			surge = 1.0
	else:
		_end_cut(false)

func _end_cut(skipped: bool) -> void:
	stage = "fight"
	voice.stop()
	_overlay(false)
	G.player.cam.make_current()
	G.player.frozen = false
	main.hud.visible = true
	main.vpc2.visible = true
	G.flash = 1.0
	G.shake = 1.0
	G.snd("boom", -2, .5)
	main.banner("DEUS", "O CRIADOR")
	door_target = 0.0
	if is_instance_valid(deus):
		deus.cine = false
		deus.inv = false
		deus._play("idle", 1.0)
		deus.cd = 2.0
