extends Node3D
## AZAZEL — o Vigia. Um olho enorme cercado de asas cobertas de olhos, sob uma coroa de anéis.
## O modelo é uma peça só: um shader dobra as asas (raiz parada, ponta batendo forte), balança as penas
## de baixo, fecha a pálpebra do olho central (piscar) e faz os olhinhos das asas piscarem um a um.
## Ataques de raio:
##   Raios do Céu · Olhar Fulminante · Varredura · Descarga · Gaiola de Raios · Olhos das Asas
## Abaixo de 50% de vida: LAMENTO — ele chora sangue pelo olho e pelas asas, os raios ficam vermelhos,
## a tempestade vira sangue e ele ataca mais rápido.

const MSC := 16.0
const BASE_Y := 5.0
const EYE := Vector3(0, .5975, .09)   # olho central no espaço do modelo

const BODY_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float flap = 0.0;      // ângulo da batida (rad)
uniform float lift = 0.0;      // sobe/desce das pontas
uniform float sway_t = 0.0;    // tempo para as penas de baixo balançarem
uniform float sway = 1.0;
uniform float blink = 0.0;     // 0 aberto, 1 fechado (olho central)
uniform float eye_glow = 0.0;  // pupila carregando raio
uniform vec3 glow_col = vec3(.5, .85, 1.0);
uniform float cry = 0.0;       // lágrimas de sangue (0..1)
uniform float red2 = 0.0;      // segunda fase: tudo puxa para o vermelho
uniform vec3 emis = vec3(0.0);
uniform float time_s = 0.0;
varying vec3 lp;
float h1(float n) { return fract(sin(n * 91.345) * 47453.21); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	lp = VERTEX;
	float ax = abs(VERTEX.x);
	float s = sign(VERTEX.x);
	// asas: nada na raiz (perto do olho), cada vez mais forte para a ponta; as de cima batem mais
	float w = smoothstep(.07, .46, ax);
	float top = smoothstep(.2, .75, VERTEX.y);
	float dx = ax - .07;
	if (dx > 0.0) {
		float a = flap * w * (.75 + top * .45);
		VERTEX.x = s * (.07 + dx * cos(a));
		VERTEX.z -= dx * sin(a);
		VERTEX.y += dx * lift * w * (.6 + top * .6);
	}
	// penas compridas de baixo: balançam como um véu
	float low = 1.0 - smoothstep(.15, .42, VERTEX.y);
	if (low > 0.0) {
		float k = (.42 - VERTEX.y) * low * sway;
		VERTEX.z += sin(sway_t * 1.3 + VERTEX.x * 9.0) * k * .16;
		VERTEX.x += sin(sway_t * .9 + VERTEX.y * 7.0) * k * .035;
	}
}
void fragment() {
	vec4 c = texture(tex, UV);
	vec3 col = c.rgb * vec3(.92, .9, .9);
	vec3 lid_col = vec3(.78, .7, .64);
	bool front = lp.z > .02;
	// --- olho central: pálpebras em amêndoa fechando de cima e de baixo ---
	float ex = lp.x / .064;
	float dy = lp.y - .5975;
	float hh = .037 * sqrt(max(0.0, 1.0 - ex * ex));
	float in_c = (front && abs(ex) < 1.0 && abs(dy) < hh + .004) ? 1.0 : 0.0;
	if (in_c > 0.0) {
		float open = hh * (1.0 - blink);
		if (abs(dy) > open) {
			// pálpebra lisa e arredondada (mais escura nas bordas), com uma dobra perto da abertura
			float u = clamp((abs(dy) - open) / max(hh - open, .002), 0.0, 1.0);
			col = lid_col * (.95 - u * .22) * (.97 + .03 * sin(lp.x * 120.0));
			col *= .88 + .12 * smoothstep(.0, .5, abs(u - .35) * 3.0);
		}
		// cílios / linha da pálpebra
		col = mix(col, vec3(.12, .06, .05), (1.0 - smoothstep(.0, .0028, abs(abs(dy) - open))) * step(.02, blink + .02));
	}
	// --- olhinhos das asas: a íris (azulada) some quando cada um pisca, cada um no seu ritmo ---
	float iris = clamp((c.b - c.r) * 9.0, 0.0, 1.0) * (1.0 - in_c);
	vec2 cell = floor(lp.xy * 38.0);
	float hc = h2(cell);
	float bl2 = smoothstep(.93, .99, sin(time_s * (.6 + hc * .8) + hc * 40.0));
	col = mix(col, lid_col * .9, iris * bl2);
	// --- lágrimas de sangue ---
	float blood = 0.0;
	if (cry > 0.0) {
		// do olho central: dois fios grossos dos cantos de baixo
		for (int k = -1; k <= 1; k += 2) {
			float x0 = float(k) * .026 + sin(lp.y * 95.0 + float(k)) * .0035;
			float y0 = .575;
			float len = cry * .42;
			float wid = .0042 + .002 * cry + .003 * smoothstep(y0 - len + .02, y0 - len, lp.y);
			if (front && abs(lp.x - x0) < wid && lp.y < y0 && lp.y > y0 - len) blood = 1.0;
		}
		// as asas também sangram: fios descendo de vários olhos
		float colx = floor(lp.x * 46.0);
		float hx = h1(colx + 3.0);
		if (hx > .68) {
			float xc = (colx + .5) / 46.0 + sin(lp.y * 60.0 + hx * 20.0) * .003;
			float ytop = .25 + h1(colx * 1.7) * .55;
			float len2 = cry * (.08 + .3 * h1(colx * 2.3));
			if (abs(lp.x - xc) < .0022 && lp.y < ytop && lp.y > ytop - len2 && lp.z > -.02) blood = 1.0;
		}
		// sangue saindo das íris
		blood = max(blood, iris * cry * .8);
	}
	// --- segunda fase: tudo puxa para o vermelho e as frestas brilham ---
	col = mix(col, col * vec3(1.0, .5, .45) * .78, red2);
	col = mix(col, vec3(.36, 0.0, .02), blood);
	ALBEDO = col;
	ROUGHNESS = mix(.62, .06, blood);
	METALLIC = .05;
	RIM = .25;
	RIM_TINT = .2;
	vec3 e = emis;
	// pupila e íris acendem quando ele carrega um raio
	float rr = length(vec2(lp.x, dy));
	if (front && rr < .03 && abs(dy) < hh * (1.0 - blink)) e += glow_col * eye_glow * (smoothstep(.03, .0, rr) * 1.1 + smoothstep(.012, .0, rr) * 1.5);
	e += glow_col * iris * (.06 + eye_glow * .35) * (1.0 - bl2);
	e += vec3(.12, 0.0, 0.0) * blood * red2;
	EMISSION = e;
}
"""
const ATTACKS := ["strike", "gaze", "sweep", "nova", "cage", "eyes"]
## só no Lamento
const ATTACKS2 := ["thousand", "storm"]

var kind = "azazel"
var alive = true
var is_boss = true
var dummy = false
var fly = true
var hp = 6200.0
var max_hp = 6200.0
var r = 5.0
var h = 14.0
var spawn_t = 3.2
var velocity = Vector3.ZERO
var burn = 0.0
var mark = null

var flash = 0.0
var phase = 0.0
var cd = 2.5
var att = ""
var at = 0.0
var fired = {}
var ad = {}
var last_att = ""
var ph2 = false
var inv = false
var dying = false
var die_t = 0.0
var mv = "orbit"
var hover = 0.0

var model: Node3D
var mats = []
var light: OmniLight3D
var halo: MeshInstance3D
var halo_mat: StandardMaterial3D
var sparks: CPUParticles3D
var drip: CPUParticles3D
var gfx = []
var flinch = 0.0
var A = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "glow": 0.0, "lean": 0.0, "rise": 0.0, "blink": 0.0, "cry": 0.0, "red": 0.0}
var T = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "glow": 0.0, "lean": 0.0, "rise": 0.0, "blink": 0.0, "cry": 0.0, "red": 0.0}
var RATE = {"blink": 30.0, "cry": .5, "red": .6}
var wph := 0.0
var blink_cd := 2.0
var blink_t := -1.0
var orbit_a := 0.0

func setup(pos: Vector3) -> void:
	position = Vector3(pos.x, 40.0, pos.z)
	model = load("res://azazel/azazel.glb").instantiate()
	model.scale = Vector3.ONE * MSC
	add_child(model)
	var bsh = Shader.new(); bsh.code = BODY_SHADER
	for mi in _meshes(model):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var src = mesh.surface_get_material(si)
			var m = ShaderMaterial.new()
			m.shader = bsh
			m.set_shader_parameter("tex", src.albedo_texture if src is StandardMaterial3D else null)
			mi.set_surface_override_material(si, m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mats.append(m)
	# auréola elétrica atrás da coroa
	halo = MeshInstance3D.new()
	var tm = TorusMesh.new(); tm.inner_radius = .95; tm.outer_radius = 1.0; tm.rings = 64; tm.ring_segments = 4
	halo.mesh = tm
	halo_mat = _addm(Color(.5, .85, 1.0), .6)
	halo.material_override = halo_mat
	halo.scale = Vector3.ONE * 3.2
	halo.rotation.x = PI / 2
	halo.position = Vector3(0, .82 * MSC, -.5)
	add_child(halo)
	# faíscas correndo pelas asas
	sparks = CPUParticles3D.new()
	sparks.amount = 60; sparks.lifetime = .5
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sparks.emission_box_extents = Vector3(7, 5, .8)
	sparks.position = Vector3(0, 8, 0)
	sparks.direction = Vector3.UP; sparks.spread = 180
	sparks.initial_velocity_min = 2; sparks.initial_velocity_max = 6
	sparks.gravity = Vector3.ZERO
	var sq = QuadMesh.new(); sq.size = Vector2(.18, .18)
	var smm = _addm(Color(.6, .85, 1.0), 1.0); smm.albedo_texture = _soft_tex(); smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = smm
	sparks.mesh = sq
	add_child(sparks)
	# pingos de sangue do olho (segunda fase)
	drip = CPUParticles3D.new()
	drip.amount = 40; drip.lifetime = 1.4; drip.emitting = false
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; drip.emission_box_extents = Vector3(.6, .1, .2)
	drip.position = Vector3(0, .26 * MSC, EYE.z * MSC)
	drip.direction = Vector3(0, -1, 0); drip.spread = 5
	drip.initial_velocity_min = .5; drip.initial_velocity_max = 2
	drip.gravity = Vector3(0, -14, 0)
	var dm = SphereMesh.new(); dm.radius = .12; dm.height = .35; dm.radial_segments = 5; dm.rings = 3
	var dmm: StandardMaterial3D = preload("res://scripts/ceu_mats.gd").blood()
	dm.material = dmm; drip.mesh = dm
	add_child(drip)
	light = OmniLight3D.new()
	light.light_color = Color(.7, .85, 1.0)
	light.omni_range = 34
	light.light_energy = 2.0
	light.position = Vector3(0, 9, 6)
	add_child(light)
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("enemy", self)
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new(); bx.size = Vector3(MSC * .75, MSC * .8, 3.0)
	cs.shape = bx
	cs.position = Vector3(0, MSC * .47, 0)
	body.add_child(cs)
	add_child(body)
	A.fold = 1.0; T.fold = 1.0; A.blink = 1.0; T.blink = 1.0
	add_to_group("azazel")
	G.snd("raio", -2, .5)

func _meshes(n: Node) -> Array:
	var out = []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out += _meshes(c)
	return out

var _st: ImageTexture
func _soft_tex() -> ImageTexture:
	if _st: return _st
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d = Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_st = ImageTexture.create_from_image(img)
	return _st

func _addm(c: Color, op := 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(c.r, c.g, c.b, op)
	mat.disable_fog = true
	return mat

func eye_pos() -> Vector3:
	return model.to_global(EYE + Vector3(0, 0, .02))

func center() -> Vector3:
	return eye_pos()

func is_head(p: Vector3) -> bool:
	return p.distance_to(eye_pos()) < 1.6

func take_damage(dmg: float, src: String, head: bool) -> bool:
	if not alive or inv: return false
	# o olho é o ponto fraco (e fechado ele protege)
	var mul = 1.0
	if head: mul = 1.6 if A.blink < .5 else .5
	hp -= dmg * mul
	flash = .09
	if dmg >= 40:
		flinch = min(1.0, flinch + dmg / 150.0)
		if blink_t < 0 and G.rng.randf() < .5: blink_t = 0.0
	if G.rng.randf() < .25: G.blood_add(1.0)
	if hp <= 0:
		die(src, head)
		return true
	return false

func _col() -> Color:
	return Color(1, .18, .1) if ph2 else Color(.55, .85, 1.0)

# ---------------- morte ----------------
func die(src: String, _head: bool) -> void:
	alive = false
	dying = true
	die_t = 0.0
	G.boss = null
	G.stats.kills += 1
	G.add_style(360, "AZAZEL CEGADO")
	_clear_gfx()
	ad = {"src": src}
	G.main.hitstop(.35)
	G.snd("porrada", 2, .6)
	G.snd("raio", 0, .4)
	for i in 14:
		G.later(.2 + i * .15, func():
			if not is_instance_valid(self): return
			var c = global_position + Vector3(G.rnd(-7, 7), G.rnd(2, 14), G.rnd(-1, 1))
			_bolt(c + Vector3(G.rnd(-6, 6), 30, 0), c, .8, .15)
			G.blast(c, .4, src)
			G.emit("blood2", c, 24, 14, .3, 1.0))

func _clear_gfx() -> void:
	for g in gfx:
		if is_instance_valid(g.get("m")): g.m.queue_free()
		for s in g.get("list", []):
			if is_instance_valid(s): s.queue_free()
	gfx.clear()

func _upd_death(dt: float) -> void:
	die_t += dt
	var k = min(1.0, die_t / 2.6)
	T.fold = .8 * k; T.flap = 0.0; T.spread = 0.0; T.glow = 1.0; T.blink = k; T.lean = .4 * k
	_anim(dt * (1.0 - k * .6))
	model.position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), 0) * .15 * k
	for m in mats: m.set_shader_parameter("emis", Vector3(.1, .2, .3).lerp(Vector3(2.0, 2.4, 3.0), k * (.6 + .4 * G.rng.randf())))
	if die_t >= 2.6 and not fired.has("boom"):
		fired.boom = true
		G.blast(center(), 1.6, ad.get("src", "parry"))
		G.emit("white", center(), 120, 32, .4, 1.6)
		G.emit("blood2", center(), 100, 30, .4, 1.6)
		G.flash = 1.0
		G.main.banner("O VIGIA SE FECHA", "A TEMPESTADE PASSA" if G.mode == "azazel" else "")
		if G.mode == "azazel": G.later(9.0, G.main.respawn_azazel)
	if die_t >= 2.6:
		var f = clamp((die_t - 2.6) / 1.2, 0.0, 1.0)
		model.scale = Vector3.ONE * MSC * max(.01, 1.0 - f)
		halo.scale = Vector3.ONE * 3.2 * (1.0 + f * 3.0)
		halo_mat.albedo_color.a = .6 * (1.0 - f)
		if f >= 1: queue_free()

# ---------------- animação ----------------
func _anim(dt: float) -> void:
	for key in A.keys():
		A[key] += (T[key] - A[key]) * (1.0 - exp(-RATE.get(key, 6.0) * dt))
	flinch *= exp(-7 * dt)
	var pw = wph
	wph += dt * (2.2 + A.flap * 4.5) * (1.0 - A.fold * .6)
	if floor(pw / TAU) != floor(wph / TAU) and A.flap > .3:
		G.snd("flapbig", -12 + A.flap * 4, .45)
	var s = sin(wph)
	# batida: desce rápido e sobe devagar (curva assimétrica), abertas na fúria, recolhidas quando ele se protege
	var stroke = s + .25 * sin(wph * 2.0)
	var amp: float = (.22 + A.flap * .32) * (1.0 - A.fold * .7)
	var fl: float = amp * stroke - A.spread * .12 + A.fold * .6 + flinch * .2
	var li: float = cos(wph) * (.12 + A.flap * .22) * (1.0 - A.fold * .6)
	# piscar: de vez em quando, ou quando leva um tiro forte
	blink_cd -= dt
	if blink_cd <= 0 and blink_t < 0 and att == "":
		blink_t = 0.0
		blink_cd = G.rnd(2.2, 5.5)
	var bl = 0.0
	if blink_t >= 0.0:
		blink_t += dt
		bl = sin(clamp(blink_t / .22, 0.0, 1.0) * PI)
		if blink_t > .22: blink_t = -1.0
	var b = max(bl, A.blink)
	for m in mats:
		m.set_shader_parameter("flap", fl)
		m.set_shader_parameter("lift", li)
		m.set_shader_parameter("sway_t", phase)
		m.set_shader_parameter("sway", 1.0 + A.flap * .8)
		m.set_shader_parameter("blink", b)
		m.set_shader_parameter("eye_glow", A.glow)
		m.set_shader_parameter("glow_col", Vector3(_col().r, _col().g, _col().b))
		m.set_shader_parameter("cry", A.cry)
		m.set_shader_parameter("red2", A.red)
		m.set_shader_parameter("time_s", phase)
	model.position.y = sin(phase * 1.1) * .5 + A.rise - s * .25 * A.flap
	model.rotation = Vector3(A.lean - flinch * .2 + sin(phase * .7) * .03, 0, sin(phase * .5) * .04 + flinch * G.rnd(-.05, .05))
	halo.scale = Vector3.ONE * (3.2 + sin(phase * 3.0) * .08 + A.glow * .5)
	var c = _col()
	halo_mat.albedo_color = Color(c.r, c.g, c.b, .35 + A.glow * .4 + sin(phase * 17.0) * .08)
	sparks.amount = 60
	(sparks.mesh as QuadMesh).material.albedo_color = Color(c.r, c.g, c.b, 1.0)
	light.light_color = c
	light.light_energy = 1.0 + A.glow * 2.5 + sin(phase * 23.0) * .2
	drip.emitting = A.cry > .3
	if not dying:
		for m in mats:
			m.set_shader_parameter("emis", Vector3(1.5, 1.8, 2.2) if flash > 0 else Vector3(0, 0, 0))

# ---------------- movimento ----------------
func _move(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var d = to.length()
	if mv == "orbit":
		# paira longe e dá voltas lentas em volta do jogador
		orbit_a += dt * (.16 if ph2 else .11)
		var want = 22.0
		var goal = Vector3(p.x, 0, p.z) + Vector3(sin(orbit_a), 0, cos(orbit_a)) * want
		var gl = Vector2(goal.x, goal.z)
		if gl.length() > 34: gl = gl.normalized() * 34
		var cur = Vector2(global_position.x, global_position.z)
		cur = cur.lerp(gl, 1.0 - exp(-(.7 if ph2 else .45) * dt))
		global_position.x = cur.x; global_position.z = cur.y
	if mv != "free":
		global_position.y += (BASE_Y + hover - global_position.y) * (1.0 - exp(-2.5 * dt))
	var want_a = atan2(p.x - global_position.x, p.z - global_position.z)
	rotation.y = lerp_angle(rotation.y, want_a, 1.0 - exp(-3.0 * dt))

# ---------------- laço ----------------
func _physics_process(dt: float) -> void:
	if G.state != "play": return
	phase += dt
	if dying:
		_upd_death(dt)
		_gfx(dt)
		return
	if not alive: return
	if spawn_t > 0:
		spawn_t -= dt
		var u = clamp(1.0 - spawn_t / 3.2, 0.0, 1.0)
		# desce das nuvens com as asas fechadas e se abre num trovão
		global_position.y = lerp(40.0, BASE_Y, 1.0 - pow(1.0 - u, 3.0))
		if u > .7 and not fired.has("open"):
			fired.open = true
			T.fold = 0.0; T.spread = 1.0; T.flap = 1.2; T.glow = 1.0; T.blink = 0.0; RATE.fold = 8.0
			G.snd("raio", 0, .7); G.snd("flapbig", 0, .5); G.snd("boom", -2, .6)
			G.shake = max(G.shake, 1.0); G.flash = max(G.flash, .5)
			for i in 6:
				var a = i * TAU / 6.0
				_bolt(global_position + Vector3(cos(a) * 10, 45, sin(a) * 10), global_position + Vector3(cos(a) * 6, -BASE_Y, sin(a) * 6), 1.0, .3)
			_nova_ring(1)
		_anim(dt)
		_gfx(dt)
		if spawn_t <= 0:
			fired.clear(); _relax()
		return
	flash -= dt
	if ph2 and G.rng.randf() < dt * 3.0:
		var o = model.to_global(Vector3(G.rnd(-.45, .45), G.rnd(.3, .8), 0))
		G.fx.bolt(o, o + Vector3(G.rnd(-4, 4), G.rnd(-6, -2), G.rnd(-2, 2)), _col(), .5, .12, 1)
	if not ph2 and hp < max_hp * .5 and att != "lament":
		_attack("lament")
	_anim(dt)
	_gfx(dt)
	_move(dt)
	if att != "":
		at += dt
		_run_attack(dt)
	else:
		cd -= dt
		if cd <= 0: _attack(_pick())

func _pick() -> String:
	var p = G.player.global_position
	var d = Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var w = {"strike": 1.2, "gaze": 1.0, "sweep": 1.0, "nova": 1.0, "cage": .8, "eyes": 1.0}
	if d < 14: w.nova += 1.2; w.sweep += .4
	else: w.gaze += .6; w.eyes += .4
	if p.y > 3: w.strike += .6; w.gaze += .4
	if ph2: w.cage += .6; w.strike += .4; w.thousand = 1.3; w.storm = 1.2
	w.erase(last_att)
	var tot = 0.0
	for k in w: tot += w[k]
	var x = G.rng.randf() * tot
	for k in w:
		x -= w[k]
		if x <= 0: return k
	return "strike"

func _once(k: String, t: float) -> bool:
	if at >= t and not fired.has(k):
		fired[k] = true
		return true
	return false

func _relax() -> void:
	for k in ["flap", "fold", "spread", "glow", "lean", "rise", "blink"]: T[k] = 0.0
	T.flap = .35
	T.glow = .25 if ph2 else 0.0
	RATE.fold = 4.0
	hover = 0.0

func _attack(k: String) -> void:
	if att != "" and k != "lament": return
	if att != "": _end(false)
	att = k
	at = 0.0
	fired.clear()
	ad = {}
	mv = "orbit"
	# toda habilidade começa com um aviso de carga no chefe
	if G.fx:
		var big = k == "lament"
		G.fx.charge(eye_pos(), _col(), 1.2 if big else .65, 7.0 * (2.0 if big else 1.0), (G.player.global_position - global_position).normalized())
	match k:
		"lament":
			inv = true; mv = "hold"; hover = 5.0
			T.fold = .9; T.blink = 1.0; T.glow = 0.0; T.flap = 0.0; T.lean = .25
			G.main.banner("LAMENTO", "O VIGIA CHORA SANGUE")
			G.snd("angel", 0, .3); G.snd("charge", -4, .3)
		"strike":
			mv = "hold"; T.spread = 1.0; T.flap = .8; T.glow = .8; T.lean = -.12
			G.snd("charge", -6, .6)
		"gaze":
			mv = "hold"; T.glow = 1.0; T.spread = .6; T.lean = .08
			G.snd("charge", -4, .8)
		"sweep":
			mv = "hold"; hover = -1.5; T.glow = 1.0; T.flap = .5; T.lean = .15
			G.snd("charge", -4, .5)
		"nova":
			mv = "hold"; hover = -2.5; T.fold = .7; T.glow = .8
			G.snd("charge", -6, .4)
		"cage":
			mv = "hold"; hover = 2.0; T.spread = 1.0; T.glow = 1.0; T.flap = 1.0
			G.snd("whirl", -4, .5)
		"eyes":
			mv = "orbit"; T.spread = 1.0; T.flap = .6; T.glow = .6
			G.snd("charge", -8, 1.1)
		"thousand":
			mv = "hold"; hover = 3.0; T.spread = 1.0; T.glow = 1.0; T.flap = .4
			G.main.banner("MIL OLHOS", "")
			G.snd("charge", -4, .7)
		"storm":
			mv = "hold"; hover = 8.0; T.spread = 1.0; T.flap = 1.2; T.glow = 1.0; T.lean = -.15
			G.main.banner("TEMPESTADE FINAL", "")
			G.snd("raio", 0, .4); G.snd("charge", -2, .4)

func _end(set_cd := true) -> void:
	last_att = att
	att = ""
	inv = false
	mv = "orbit"
	_relax()
	if set_cd:
		cd = 1.1 if ph2 else 2.0
		if ph2 and G.rng.randf() < .3: cd = .4

func _player_c() -> Vector3:
	return G.player.global_position + Vector3(0, .9, 0)

func _ground_y(x: float, z: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 20, z), Vector3(x, -3, z), 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else 0.0

## raio (usa o desenho da arena: núcleo branco, brilho e galhos)
func _bolt(a: Vector3, b: Vector3, w := 1.0, life := .16) -> void:
	var arena = G.main.get("azazel_arena")
	G.fx.bolt(a, b, _col(), w * .9, life * 1.3, 2)
	if arena: arena.flash_k = max(arena.flash_k, .5)

func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var t2 = clamp((p - a).dot(ab) / max(ab.length_squared(), .001), 0.0, 1.0)
	return p.distance_to(a + ab * t2)

# ---------------- coreografia ----------------
func _run_attack(dt: float) -> void:
	var p = G.player.global_position
	var pc = _player_c()
	match att:
		"lament":
			G.shake = max(G.shake, .1)
			# fecha o olho, treme, e abre chorando sangue
			if at > 1.4: T.blink = 0.0; T.cry = 1.0; T.red = 1.0; T.glow = 1.0
			if _once("open", 1.4):
				ph2 = true
				G.flash = 1.0; G.shake = max(G.shake, 1.2)
				G.snd("raio", 2, .45); G.snd("angel", 0, .25); G.snd("boom", 0, .5)
				T.fold = 0.0; T.spread = 1.0; T.flap = 1.3; RATE.fold = 10.0
				G.emit("blood2", eye_pos(), 80, 20, .35, 1.4)
				var arena = G.main.get("azazel_arena")
				if arena: arena.bleed()
				if G.main.has_method("azazel_bleed"): G.main.azazel_bleed()
				for i in 8:
					var a = i * TAU / 8.0
					_bolt(global_position + Vector3(cos(a) * 8, 50, sin(a) * 8), Vector3(global_position.x + cos(a) * 14, 0, global_position.z + sin(a) * 14), 1.2, .35)
				_nova_ring(2)
			if at > 3.4: _end()
		"strike":
			# marcas brilham no chão em volta de você; um segundo depois o raio cai em cada uma
			var n = 9 if ph2 else 6
			var dur = 1.6 if ph2 else 2.0
			for i in n:
				var t0 = .4 + i * dur / n
				if _once("m%d" % i, t0):
					var q = Vector3(p.x, 0, p.z)
					if i > 0:
						var a = G.rnd(0, TAU); var rr = G.rnd(2.0, 7.0)
						q += Vector3(cos(a) * rr, 0, sin(a) * rr) + Vector3(G.player.velocity.x, 0, G.player.velocity.z) * .45
					q.y = _ground_y(q.x, q.z)
					_mark(q, .85 if ph2 else 1.0, 2.6)
			if at > .4 + dur + 1.3: _end()
		"gaze":
			# o olho carrega e mira; o traço fino segue você até travar, e então o raio sai do olho
			var shots = 3 if ph2 else 1
			for i in shots:
				var t0 = 1.1 + i * .75
				if at < t0 - .22 and at > t0 - 1.0 and (i == 0 or at > t0 - .75):
					ad.aim = pc
				if at > t0 - .9 and at < t0 and ad.has("aim"):
					if G.rng.randf() < dt * 30: G.tracer(eye_pos(), ad.aim, .06, Color(_col().r, _col().g, _col().b, .5), .05)
				if _once("g%d" % i, t0) and ad.has("aim"):
					var e = eye_pos()
					var dir = (ad.aim - e).normalized()
					var q = PhysicsRayQueryParameters3D.create(e, e + dir * 120.0, 1)
					var hit = get_world_3d().direct_space_state.intersect_ray(q)
					var end = hit.position if hit else e + dir * 120.0
					_bolt(e, end, 1.6, .22)
					G.fx.beam(e, end, 1.2, _col(), .35)
					G.fx.flash(e, _col(), 6, .3)
					G.fx.shock(end, _col(), 6, .45)
					G.snd("raio", 0, G.rnd(.9, 1.1)); G.shake = max(G.shake, .4)
					G.emit("spark", end, 30, 16, .15, .6)
					if _dist_seg(pc, e, end) < 1.7:
						if G.hurt_player(24.0 if ph2 else 20.0):
							G.player.velocity += dir * 14 + Vector3(0, 6, 0)
					# o raio se divide ao bater no chão
					for k in 3:
						var a = G.rnd(0, TAU)
						_bolt(end + Vector3(0, .3, 0), end + Vector3(cos(a) * 6, .2, sin(a) * 6), .5, .14)
			if at > 1.6 + (shots - 1) * .75: _end()
		"sweep":
			# um raio sai do olho e varre o chão de um lado ao outro: pule por cima
			if at < 1.0:
				if G.rng.randf() < dt * 20: G.emit("spark", eye_pos(), 4, 6, .1, .3)
				ad.f = (Vector3(p.x, 0, p.z) - Vector3(global_position.x, 0, global_position.z)).normalized()
			elif at < 3.2:
				var u = (at - 1.0) / 2.2
				var sgn = 1.0 if ad.get("dir", 0) == 0 else -1.0
				if not ad.has("dir"): ad.dir = 0 if G.rng.randf() < .5 else 1
				var ang = lerp(-1.1, 1.1, u) * sgn
				var f: Vector3 = ad.f.rotated(Vector3.UP, ang)
				var gp = Vector3(global_position.x, 0, global_position.z) + f * 46.0
				var g0 = Vector3(global_position.x, 0, global_position.z) + f * 4.0
				var e = eye_pos()
				if int(at * 30) != int((at - dt) * 30):
					_bolt(e, g0 + Vector3(0, .5, 0), 1.0, .06)
					_bolt(g0 + Vector3(0, .5, 0), gp + Vector3(0, .5, 0), .8, .06)
					G.fx.beam(g0 + Vector3(0, .5, 0), gp + Vector3(0, .5, 0), .9, _col(), .07)
					G.fx.sprite(g0.lerp(gp, G.rng.randf()) + Vector3(0, .2, 0), "scorch_0%d" % (1 + G.rng.randi() % 3), _col(), 1.5, 3.0, .4, 0.0, true, Vector3.UP)
					G.emit("spark", g0.lerp(gp, G.rng.randf()) + Vector3(0, .5, 0), 3, 6, .1, .3)
				if int(at * 8) != int((at - dt) * 8): G.snd("raio", -10, G.rnd(1.2, 1.5))
				var py = p.y - _ground_y(p.x, p.z)
				if not ad.has("hit") and py < 1.2 and _dist_seg(Vector3(p.x, 0, p.z), g0, gp) < 1.0:
					ad.hit = true
					if G.hurt_player(20.0 if ph2 else 16.0): G.player.velocity.y += 9
			if at > 3.6: _end()
		"nova":
			# desce e solta anéis elétricos pelo chão (pule cada um)
			var n = 3 if ph2 else 2
			for i in n:
				if _once("n%d" % i, .8 + i * .7):
					G.snd("raio", -2, .7 + i * .1); G.shake = max(G.shake, .4)
					_nova_ring(1)
					G.fx.shock(Vector3(global_position.x, _ground_y(global_position.x, global_position.z), global_position.z), _col(), 16, .6, "circle_03")
					G.fx.flash(eye_pos(), _col(), 10, .35)
					for k in 4:
						var a = G.rnd(0, TAU)
						_bolt(eye_pos(), Vector3(global_position.x + cos(a) * 5, 0, global_position.z + sin(a) * 5), .8, .15)
			if at > 1.2 + n * .7: _end()
		"cage":
			# pilares de raio cercam você e vão fechando: escape pelas frestas
			if _once("spawn", .5):
				ad.c = Vector3(p.x, 0, p.z)
				ad.list = []
				var n = 10 if ph2 else 8
				for i in n:
					ad.list.append(i * TAU / n)
				G.snd("raio", -2, .6)
				G.fx.sigil(Vector3(ad.c.x, _ground_y(ad.c.x, ad.c.z), ad.c.z), 11.0, _col(), 3.2, 0)
			if ad.has("c"):
				var u = clamp((at - .5) / 2.6, 0.0, 1.0)
				var rr = lerp(11.0, 2.2, u * u)
				var rot = at * (.9 if ph2 else .6)
				for a0 in ad.list:
					var a = a0 + rot
					var q = ad.c + Vector3(cos(a), 0, sin(a)) * rr
					if int(at * 20) != int((at - dt) * 20):
						_bolt(q + Vector3(0, 40, 0), q, .6, .07)
						G.fx.sprite(q + Vector3(0, .15, 0), "circle_05", _col(), 1.5, 2.5, .12, 0.0, true, Vector3.UP)
					if not ad.has("hit") and Vector2(p.x - q.x, p.z - q.z).length() < 1.1:
						ad.hit = true
						if G.hurt_player(18.0 if ph2 else 14.0):
							var push = Vector3(p.x - ad.c.x, 0, p.z - ad.c.z).normalized()
							G.player.velocity += push * 10 + Vector3(0, 6, 0)
				if int(at * 6) != int((at - dt) * 6): G.snd("raio", -12, G.rnd(1.0, 1.3))
				if u >= 1.0 and _once("burst", at):
					_bolt(ad.c + Vector3(0, 50, 0), ad.c, 2.4, .3)
					G.snd("raio", 2, .5); G.shake = max(G.shake, .6)
					if Vector2(p.x - ad.c.x, p.z - ad.c.z).length() < 2.6:
						if G.hurt_player(22.0): G.player.velocity.y += 10
			if at > 3.6: _end()
		"thousand":
			# MIL OLHOS: olhos de luz se abrem no ar em volta de você, piscam e disparam raios que se cruzam
			var n = 10
			if _once("open", .3):
				ad.e = []
				for i in n:
					var a = i * TAU / n + G.rnd(-.2, .2)
					var off = Vector3(cos(a) * G.rnd(9, 13), G.rnd(3, 9), sin(a) * G.rnd(9, 13))
					var root = Node3D.new(); G.world.add_child(root)
					root.global_position = Vector3(p.x, 0, p.z) + off
					var q = QuadMesh.new(); q.size = Vector2.ONE * 2.6
					var glow = MeshInstance3D.new(); glow.mesh = q
					glow.material_override = G.fx.mat("light_02", Color(_col().r, _col().g, _col().b, .9), true, 1); root.add_child(glow)
					var iris = MeshInstance3D.new(); var q2 = QuadMesh.new(); q2.size = Vector2.ONE * 1.2; iris.mesh = q2
					iris.material_override = G.fx.mat("star_02", Color(1, 1, 1, 1), true, 1); root.add_child(iris)
					root.scale = Vector3.ONE * .01
					ad.e.append({"n": root, "t": .9 + i * .22})
				G.snd("ping", -6, .6)
			if ad.has("e"):
				for e in ad.e:
					if not is_instance_valid(e.n): continue
					e.n.scale = Vector3.ONE * clamp((at - .3) * 3.0, .01, 1.0) * (1.0 + sin(at * 14.0 + e.t * 5.0) * .1)
					if at > e.t - .45 and at < e.t and G.rng.randf() < dt * 25: G.tracer(e.n.global_position, pc, .04, Color(_col().r, _col().g, _col().b, .6), .04)
					if at > e.t - .45 and not e.has("aim"): e.aim = pc
					if at > e.t - .45 and at < e.t - .12: e.aim = e.aim.lerp(pc, 1.0 - exp(-8.0 * dt))
					if at >= e.t and not e.has("shot"):
						e.shot = true
						var a: Vector3 = e.n.global_position
						var end: Vector3 = a + (e.aim - a).normalized() * (a.distance_to(e.aim) + 6.0)
						_bolt(a, end, 1.0, .2)
						G.fx.flash(a, _col(), 4, .3)
						G.snd("raio", -10, G.rnd(1.1, 1.4))
						if _dist_seg(pc, a, end) < 1.3 and G.hurt_player(14.0): G.player.velocity += (end - a).normalized() * 6
						var nn = e.n
						G.later(.25, func(): if is_instance_valid(nn): nn.queue_free())
			if at > .9 + n * .22 + .6:
				for e in ad.get("e", []):
					if is_instance_valid(e.n): e.n.queue_free()
				_end()
		"storm":
			# TEMPESTADE FINAL: quatro raios rasteiros saem dele e giram pela arena; pule cada um quando passar
			var c = Vector3(global_position.x, _ground_y(global_position.x, global_position.z) + .6, global_position.z)
			if _once("sig", .2): G.fx.sigil(c - Vector3(0, .5, 0), 8.0, _col(), 5.0, 0)
			if at > 1.0 and at < 5.0:
				var rot = (at - 1.0) * (.9 if at < 3.0 else 1.25)
				for k in 4:
					var a = ad.get("a0", 0.0) + rot + k * TAU / 4.0
					var d = Vector3(cos(a), 0, sin(a))
					var end = c + d * 46.0
					if int(at * 24) != int((at - dt) * 24):
						G.fx.bolt(c, end, _col(), 1.1, .07, 1)
					var py = p.y - _ground_y(p.x, p.z)
					var rel = Vector3(p.x - c.x, 0, p.z - c.z)
					var along = rel.dot(d)
					var perp = (rel - d * along).length()
					if along > 0 and perp < 1.0 and py < 1.1 and not ad.has("h%d_%d" % [k, int(at * 2)]):
						ad["h%d_%d" % [k, int(at * 2)]] = true
						if G.hurt_player(14.0): G.player.velocity.y += 8
				if int(at * 5) != int((at - dt) * 5): G.snd("raio", -10, G.rnd(.9, 1.2))
				if G.rng.randf() < dt * 10: G.fx.shock(c - Vector3(0, .5, 0), _col(), 7, .3)
			if _once("a", .1): ad.a0 = G.rnd(0, TAU)
			if at > 5.4: _end()
		"eyes":
			# os olhos das asas disparam esferas elétricas em leque
			var vol = 4 if ph2 else 3
			for v in vol:
				if _once("v%d" % v, .6 + v * .6):
					G.snd("eshot", -4, .8)
					for k in 7:
						var lx = (k - 3) * .11
						var ly = .55 + abs(k - 3) * .04
						var o = model.to_global(Vector3(lx, ly, .05))
						var dir = (pc - o).normalized().rotated(Vector3.UP, (k - 3) * .07)
						G.main.spawn_orb(o, dir * (19.0 if ph2 else 15.0))
						var pr = G.projs[G.projs.size() - 1]
						pr.mat.albedo_color = _col()
						G.fx.attach_glow(pr.m, Color(_col().r, _col().g, _col().b, .9), 2.0, false, "spark_02")
						G.fx.flash(o, _col(), 2.0, .25)
			if at > .8 + vol * .6: _end()

## marca no chão; depois de `delay` cai um raio nela
func _mark(q: Vector3, delay: float, rad: float) -> void:
	var m = MeshInstance3D.new()
	var tm = TorusMesh.new(); tm.inner_radius = rad - .25; tm.outer_radius = rad; tm.rings = 32; tm.ring_segments = 4
	m.mesh = tm
	m.material_override = _addm(_col(), .7)
	G.world.add_child(m)
	G.fx.ring_overlay(m, _col(), m.material_override)
	m.global_position = q + Vector3(0, .08, 0)
	m.scale = Vector3(1, .1, 1)
	G.fx.sigil(q, rad * 1.15, _col(), delay + .1, 0)
	gfx.append({"kind": "mark", "m": m, "t": delay, "x": q.x, "y": q.y, "z": q.z, "r": rad})

func _nova_ring(n: int) -> void:
	for i in n:
		var m = MeshInstance3D.new()
		var tm = TorusMesh.new(); tm.inner_radius = .9; tm.outer_radius = 1.0; tm.rings = 64; tm.ring_segments = 4
		m.mesh = tm
		m.material_override = _addm(_col(), .85)
		G.world.add_child(m)
		G.fx.ring_overlay(m, _col(), m.material_override, "circle_03")
		var gy = _ground_y(global_position.x, global_position.z)
		m.global_position = Vector3(global_position.x, gy + .35, global_position.z)
		gfx.append({"kind": "wave", "m": m, "r": 2.0 - i * 6.0, "x": global_position.x, "z": global_position.z, "gy": gy, "hit": false})

func _gfx(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	for g in gfx:
		match g.kind:
			"mark":
				g.t -= dt
				g.m.material_override.albedo_color.a = .4 + .5 * abs(sin(g.t * 18.0))
				g.m.rotation.y += dt * 3.0
				if g.t <= 0:
					g.dead = true
					var q = Vector3(g.x, g.y, g.z)
					_bolt(q + Vector3(G.rnd(-4, 4), 55, G.rnd(-4, 4)), q, 1.4, .2)
					G.snd("raio", -4, G.rnd(.8, 1.1))
					G.emit("spark", q + Vector3(0, .3, 0), 24, 14, .12, .5)
					G.fx.shock(q, _col(), 5, .45)
					G.fx.flash(q + Vector3(0, .8, 0), _col(), 5, .3)
					G.shake = max(G.shake, .25)
					if Vector2(p.x - g.x, p.z - g.z).length() < g.r and p.y - g.y < 5.0:
						if G.hurt_player(20.0 if ph2 else 16.0): G.player.velocity.y += 8
			"wave":
				g.r += 22 * dt
				if g.r > 0:
					g.m.visible = true
					g.m.scale = Vector3(g.r, 1, g.r)
				else: g.m.visible = false
				g.m.material_override.albedo_color.a = max(0.0, .85 - g.r / 55.0)
				if G.rng.randf() < dt * 40 and g.r > 1:
					var a = G.rnd(0, TAU)
					G.emit("spark", Vector3(g.x + cos(a) * g.r, g.gy + .4, g.z + sin(a) * g.r), 2, 6, .1, .3)
				var d = Vector2(p.x - g.x, p.z - g.z).length()
				if not g.hit and g.r > 1 and p.y - g.gy < 1.3 and abs(d - g.r) < 1.2:
					g.hit = true
					if G.hurt_player(18.0 if ph2 else 15.0): G.player.velocity.y += 8
				if g.r > 52: g.dead = true
	for g in gfx:
		if g.get("dead", false) and is_instance_valid(g.get("m")): g.m.queue_free()
	gfx = gfx.filter(func(g): return not g.get("dead", false))
