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
	# sobre o portão, uma fileira de mãos
	if hm:
		for i in 7:
			_hand(hm, Vector3(-6 + i * 2, 21.5, DOOR_Z + 1.3), 0, i)

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
		var bm = BoxMesh.new(); bm.size = Vector3(7, 21, .9)
		mi.mesh = bm; mi.material_override = m_gold
		sb.add_child(mi)
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new(); bs.size = bm.size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(s * 3.5, 10.5, 0)
		# relevos: painéis, cravos e meia auréola com olho
		for py in [3.0, 9.5, 16.0]:
			var pn = MeshInstance3D.new()
			var pb = BoxMesh.new(); pb.size = Vector3(5.2, 4.8, .2)
			pn.mesh = pb; pn.material_override = m_gold_dark
			pn.position = Vector3(0, py - 10.5, .5)
			sb.add_child(pn)
			var pn2 = pn.duplicate(); pn2.position.z = -.5; sb.add_child(pn2)
		for i in 6:
			var st_ = MeshInstance3D.new()
			var ss = SphereMesh.new(); ss.radius = .25; ss.height = .5
			st_.mesh = ss; st_.material_override = m_gold
			st_.position = Vector3(-s * 3.1, -9 + i * 3.6, .55)
			sb.add_child(st_)
	# olho no centro do portão (metade em cada folha)
	var eye_m = glow(Color(1, .15, .08))
	for pair in [[door_l, 1], [door_r, -1]]:
		var e = MeshInstance3D.new()
		var cm = CylinderMesh.new(); cm.top_radius = 1.6; cm.bottom_radius = 1.6; cm.height = .2; cm.radial_segments = 20
		e.mesh = cm; e.material_override = eye_m
		e.rotation.x = PI / 2
		e.position = Vector3(pair[1] * 6.3, 10.5, .58)
		e.scale = Vector3(.45, 1, .9)
		pair[0].add_child(e)

func _altar() -> void:
	# altar em 5 degraus, topo em y = 8
	for i in 5:
		var w = 46.0 - i * 7.0
		var d = 32.0 - i * 4.0
		var front = -46.0 - i * 2.6
		blk(0, i * 1.6, front - d * .5, w, 1.6, d, m_marble)
		blk(0, (i + 1) * 1.6 - .05, front - .2, w + .1, .12, .45, m_gold, false)
	# rio de sangue descendo os degraus
	var top_front = -46.0 - 4 * 2.6
	var run = -(top_front + 46.0)
	var L = sqrt(ALTAR_TOP * ALTAR_TOP + run * run)
	var riv = quad(Vector3(0, ALTAR_TOP * .5 + .12, -46.0 - run * .5), Vector2(3.4, L + .6), m_blood_fall)
	riv.rotation = Vector3(atan2(-run, ALTAR_TOP), 0, 0)
	pool(0, -43.5, 5.5, .04, .6)
	# trono
	var tz = -71.0
	blk(0, ALTAR_TOP, tz + 2, 10, 3.2, 7, m_gold)
	blk(-5.6, ALTAR_TOP, tz + 2, 1.8, 5.5, 7, m_gold)
	blk(5.6, ALTAR_TOP, tz + 2, 1.8, 5.5, 7, m_gold)
	blk(0, ALTAR_TOP, tz - 2.2, 13, 34, 1.8, m_gold)
	blk(0, ALTAR_TOP + 34, tz - 2.2, 7, 4, 1.8, m_gold, false)
	blk(0, ALTAR_TOP + 3.2, tz + 2, 7.5, .3, 5.5, m_carpet, false)
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
		cyl(sx * 6.5, ALTAR_TOP, -59, .5, .8, 3.0, m_gold, false)
		_flame(Vector3(sx * 6.5, ALTAR_TOP + 3.6, -59), 1.0)

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
