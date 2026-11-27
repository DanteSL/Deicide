extends Node3D
## LILITH — a Rainha do Abismo. Asas de morcego, uma mão em garra e a outra erguida com a cruz invertida.
## O modelo foi separado em partes (2 asas, 2 braços, cabeça) e tudo é animado por código.
## Para ficar mais demoníaca: brilho vermelho nas bordas, olhos em brasa, coroa de fogo atrás da cabeça,
## brasas e fumaça saindo do corpo e um círculo de fogo sob os pés.
## Ataques (nenhum repete os outros chefes):
##   Garras Rasgantes · Cruzes Caídas · Chuva de Enxofre · Beijo da Súcubo
##   Mergulho Infernal · Fendas de Lava · Almas Penadas
## Abaixo de 50% de vida: INFERNO — o lago de lava sobe pelas bordas, o fogo fica mais forte e ela acelera.

const MSC := 13.0
const BASE_Y := 1.6
## as asas fazem parte do corpo: um shader dobra os vértices das costas (mais forte na ponta,
## nada na raiz), então elas batem presas ao corpo, sem se soltar
const BODY_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint = vec3(1.2, 1.25, 1.35);
uniform float neutral = .45; // tira parte do vermelho que a luz da arena joga nela
uniform vec3 emis = vec3(.05, 0.0, 0.0);
uniform float flap = 0.0;   // ângulo atual da batida (rad)
uniform float lift = 0.0;   // sobe/desce das pontas
uniform float wings = 1.0;  // 1 no corpo, 0 nas outras partes
uniform float leg_t = 0.0;  // tempo do balanço das pernas
uniform float leg_amp = 1.0;
// física do tecido: deslocamento de mola (espaço do modelo) + ondas que descem pelo pano
uniform vec3 cloth_off = vec3(0.0);
uniform float cloth_t = 0.0;
uniform float cloth_amp = 1.0;
// tecido vermelho trançado (Plain Red Dimout) nos panos
uniform sampler2D fab_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fab_rough : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform sampler2D fab_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float fab_scale = 22.0;
varying float cw;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	// panos = abaixo da cintura, menos o miolo das pernas de armadura
	float leg = 1.0 - smoothstep(.045, .085, abs(VERTEX.x - .015));
	cw = (1.0 - smoothstep(.40, .56, VERTEX.y)) * (1.0 - leg * .9) * wings;
	if (cw > 0.0) {
		float k = clamp((.56 - VERTEX.y) / .56, 0.0, 1.0);
		float kk = k * k;
		// arrasto e balanço de mola (mais forte na barra do pano)
		VERTEX += cloth_off * kk * cw * 1.3;
		// ondas descendo pelo tecido, mais rápidas quando ela se move
		float w1 = sin(cloth_t * 3.1 - VERTEX.y * 16.0 + VERTEX.x * 9.0);
		float w2 = sin(cloth_t * 4.7 - VERTEX.y * 27.0 - VERTEX.x * 13.0 + 1.7);
		VERTEX.z += (w1 * .022 + w2 * .008) * k * cw * cloth_amp;
		VERTEX.x += sin(cloth_t * 2.3 - VERTEX.y * 11.0 + VERTEX.z * 8.0) * .011 * k * cw * cloth_amp;
	}
	float ax = abs(VERTEX.x);
	float s = sign(VERTEX.x);
	float w = smoothstep(.09, .42, ax) * clamp((-VERTEX.z + .01) / .07, 0.0, 1.0) * smoothstep(.3, .52, VERTEX.y) * wings;
	// pernas e saia balançam como se flutuasse: quanto mais baixo, mais balança; cada perna num ritmo
	float lw = (1.0 - smoothstep(.2, .52, VERTEX.y)) * (1.0 - smoothstep(.16, .3, ax)) * wings;
	if (lw > 0.0) {
		float k = (.52 - VERTEX.y) * lw * leg_amp;
		float side = clamp(-VERTEX.x * 14.0, -1.0, 1.0); // contínuo: nada rasga entre as pernas
		float ph = leg_t * 1.6 + side * 1.1;
		VERTEX.z += sin(ph) * k * .11;
		VERTEX.x += sin(leg_t * 1.1) * k * .04;
		VERTEX.y += cos(ph) * k * .015;
	}
	float dx = ax - .08;
	if (dx > 0.0 && w > 0.0) {
		float a = flap * w;
		VERTEX.x = s * (.08 + dx * cos(a));
		VERTEX.z -= dx * sin(a);
		VERTEX.y += dx * lift * w;
	}
}
void fragment() {
	vec4 c = texture(tex, UV);
	vec3 col = c.rgb * tint;
	// o mapa tem bastante vermelho; puxa o tecido e a pele para cinza-grafite, mantendo os detalhes vermelhos fortes
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0);
	float g = dot(col, vec3(.3, .59, .11));
	col = mix(col, vec3(g) * vec3(.95, .97, 1.05), neutral * (1.0 - red * .6));
	// tecido: só nos panos (não na fumaça azulada nem nos enfeites brilhantes)
	float lum = dot(c.rgb, vec3(.3, .59, .11));
	float smoke = smoothstep(.0, .06, c.b - c.r) * smoothstep(.18, .3, lum);
	float fab = clamp(cw * 1.4, 0.0, 1.0) * (1.0 - smoke) * (1.0 - smoothstep(.45, .6, lum));
	vec2 fuv = (abs(ln.x) > abs(ln.z) ? vec2(lp.z, lp.y) : vec2(lp.x, lp.y)) * fab_scale;
	vec3 fc = texture(fab_tex, fuv).rgb;
	// mantém as dobras e sombras do modelo, troca a cor pelo tecido
	vec3 fabcol = fc * (lum * 1.9 + .12);
	col = mix(col, fabcol, fab * .85);
	ALBEDO = col;
	EMISSION = emis;
	ROUGHNESS = mix(.55, texture(fab_rough, fuv).r * .9, fab);
	METALLIC = mix(.15, .0, fab);
	SPECULAR = mix(.5, .35, fab);
	// brilho acetinado que corre pelas dobras
	ANISOTROPY = .35 * fab;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	NORMAL_MAP = mix(vec3(.5, .5, 1.0), texture(fab_nrm, fuv).rgb, fab);
	NORMAL_MAP_DEPTH = 1.2;
	RIM = .45;
	RIM_TINT = .15;
}
"""
var FAB = [load("res://lilith/seda_cor.jpg"), load("res://lilith/seda_r.jpg"), load("res://lilith/seda_n.jpg")]
# física do tecido (mola)
var cl_off := Vector3.ZERO
var cl_vel := Vector3.ZERO
var cl_prev := Vector3.ZERO
var cl_t := 0.0
const ATTACKS := ["claw", "crosses", "brimstone", "kiss", "dive", "rift", "souls"]
## só no inferno
const ATTACKS2 := ["abyss", "meteor"]

var kind = "lilith"
var alive = true
var is_boss = true
var dummy = false
var fly = true
var hp = 5800.0
var max_hp = 5800.0
var r = 3.5
var h = 12.0
var spawn_t = 3.0
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
var mv = "stalk" # stalk | hold | free
var hover = 0.0

var model: Node3D
var N = {}
var mats = []
var base_col := Color(1, 1, 1)
var light: OmniLight3D
var crown: MeshInstance3D
var crown_mat: StandardMaterial3D
var eyes = []
var embers: CPUParticles3D
var smoke: CPUParticles3D
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var gfx = []
var souls = []
var flinch = 0.0
var A = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "raise": 0.0, "claw": 0.0, "cast": 0.0, "lean": 0.0, "nod": 0.0, "glow": 0.0, "rise": 0.0, "spin": 0.0}
var T = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "raise": 0.0, "claw": 0.0, "cast": 0.0, "lean": 0.0, "nod": 0.0, "glow": 0.0, "rise": 0.0, "spin": 0.0}
var RATE = {"fold": 4.0, "lean": 6.0}
var swing := 0.0
var head_look := Vector2.ZERO
var wph := 0.0

func setup(pos: Vector3) -> void:
	position = Vector3(pos.x, -14.0, pos.z)
	model = load("res://lilith/lilith.glb").instantiate()
	model.scale = Vector3.ONE * MSC
	add_child(model)
	_index(model)
	var tex = load("res://lilith/lilith_cor.jpg") if ResourceLoader.exists("res://lilith/lilith_cor.jpg") else null
	var bsh = Shader.new(); bsh.code = BODY_SHADER
	for mi in _meshes(model):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var m = ShaderMaterial.new()
			m.shader = bsh
			m.set_shader_parameter("tex", tex)
			m.set_shader_parameter("fab_tex", FAB[0]); m.set_shader_parameter("fab_rough", FAB[1]); m.set_shader_parameter("fab_nrm", FAB[2])
			m.set_shader_parameter("wings", 1.0 if String(mi.name).begins_with("body") or String(mi.get_parent().name).begins_with("body") else 0.0)
			mi.set_surface_override_material(si, m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mats.append(m)
	for nm in N.keys():
		if nm.begins_with("wing") or nm.begins_with("arm") or nm == "head": N[nm].rotation_order = EULER_ORDER_XYZ
	var hn: Node3D = N.get("head", model)
	# olhos em brasa
	for sx in [-1, 1]:
		var e = MeshInstance3D.new()
		var q = QuadMesh.new(); q.size = Vector2(.03, .018)
		e.mesh = q
		var em = _addm(Color(1, .25, .05), 1.0)
		em.albedo_texture = _soft_tex()
		em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		e.material_override = em
		e.position = Vector3(sx * .016, .838, .09) - hn.position
		hn.add_child(e)
		eyes.append(em)
	# coroa de fogo atrás da cabeça (anel de espinhos invertido)
	crown = MeshInstance3D.new()
	var cq = QuadMesh.new(); cq.size = Vector2(.42, .42)
	crown.mesh = cq
	crown_mat = _addm(Color(1, .3, .08), .7)
	crown_mat.albedo_texture = _crown_tex()
	crown.material_override = crown_mat
	crown.position = Vector3(0, .87, -.05) - hn.position
	hn.add_child(crown)
	# brasas e fumaça
	embers = CPUParticles3D.new()
	embers.amount = 70; embers.lifetime = 2.2
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; embers.emission_box_extents = Vector3(3, 5, 1.5)
	embers.position = Vector3(0, 6, 0)
	embers.direction = Vector3.UP; embers.spread = 30
	embers.initial_velocity_min = 1.5; embers.initial_velocity_max = 4.0
	embers.gravity = Vector3(0, 1.5, 0)
	var eq = QuadMesh.new(); eq.size = Vector2(.12, .12)
	var emm = _addm(Color(1, .45, .1), 1.0); emm.albedo_texture = _soft_tex(); emm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	eq.material = emm
	embers.mesh = eq
	add_child(embers)
	smoke = CPUParticles3D.new()
	smoke.amount = 30; smoke.lifetime = 3.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; smoke.emission_sphere_radius = 1.5
	smoke.position = Vector3(0, .5, 0)
	smoke.direction = Vector3.UP; smoke.spread = 40
	smoke.initial_velocity_min = .5; smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0, .6, 0)
	smoke.scale_amount_min = 3.0; smoke.scale_amount_max = 6.0
	var sq = QuadMesh.new(); sq.size = Vector2(1, 1)
	var smm = StandardMaterial3D.new(); smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; smm.albedo_texture = _soft_tex(); smm.albedo_color = Color(.08, .02, .02, .45)
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = smm
	smoke.mesh = sq
	add_child(smoke)
	# círculo de fogo sob os pés
	ring = MeshInstance3D.new()
	var rq = QuadMesh.new(); rq.size = Vector2(9, 9)
	ring.mesh = rq
	ring_mat = _addm(Color(1, .25, .05), .8)
	ring_mat.albedo_texture = _sigil_tex()
	ring.material_override = ring_mat
	ring.rotation.x = -PI / 2
	add_child(ring)
	light = OmniLight3D.new()
	light.light_color = Color(1, .86, .74)
	light.omni_range = 26
	light.light_energy = 2.0
	light.position = Vector3(0, 9, 3)
	add_child(light)
	# luz fria de recorte pela frente, para a silhueta escura ler no meio do fogo
	var fill = OmniLight3D.new()
	fill.light_color = Color(.82, .84, 1.0)
	fill.light_energy = 2.4
	fill.omni_range = 22
	fill.position = Vector3(0, 8, 9)
	add_child(fill)
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("enemy", self)
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new(); cap.radius = 3.0; cap.height = 12.0
	cs.shape = cap
	cs.position = Vector3(0, 6.5, 0)
	body.add_child(cs)
	add_child(body)
	A.fold = 1.0; T.fold = 1.0
	add_to_group("lilith")
	G.snd("angel", -2, .3)

func _index(n: Node) -> void:
	if n is Node3D and n.name != "": N[String(n.name)] = n
	for c in n.get_children(): _index(c)

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

func _crown_tex() -> ImageTexture:
	var n = 128
	var img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c = Vector2(n, n) * .5
	for y in n:
		for x in n:
			var v = Vector2(x, y) - c
			var d = v.length() / (n * .5)
			var a = atan2(v.y, v.x)
			var spike = .55 + .35 * pow(abs(cos(a * 6.0)), 8.0) * (1.0 if v.y < 0 else .6)
			var al = 0.0
			if d < spike and d > .38: al = 1.0 - abs(d - (spike + .38) * .5) / ((spike - .38) * .5 + .001)
			al = clamp(al, 0.0, 1.0)
			al = max(al, clamp(1.0 - abs(d - .4) * 20.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, al))
	return ImageTexture.create_from_image(img)

func _sigil_tex() -> ImageTexture:
	var n = 256
	var img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c = Vector2(n, n) * .5
	var pts = []
	for i in 5:
		var a = -PI / 2 + PI + i * TAU / 5.0 # pentagrama invertido
		pts.append(c + Vector2(cos(a), sin(a)) * n * .4)
	for y in n:
		for x in n:
			var p = Vector2(x, y)
			var d = p.distance_to(c) / (n * .5)
			var al = clamp(1.0 - abs(d - .92) * 30.0, 0.0, 1.0) + clamp(1.0 - abs(d - .82) * 40.0, 0.0, 1.0) * .7
			for i in 5:
				var a2: Vector2 = pts[i]; var b2: Vector2 = pts[(i + 2) % 5]
				var ab = b2 - a2
				var t2 = clamp((p - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
				al = max(al, clamp(1.0 - p.distance_to(a2 + ab * t2) / 2.2, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, clamp(al, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _addm(c: Color, op := 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(c.r, c.g, c.b, op)
	mat.disable_fog = true
	return mat

func center() -> Vector3:
	return global_position + Vector3(0, 7.5, 0)

func is_head(p: Vector3) -> bool:
	return p.y > global_position.y + 10.3

func take_damage(dmg: float, src: String, head: bool) -> bool:
	if not alive or inv: return false
	hp -= dmg * (1.25 if head else 1.0)
	flash = .09
	if dmg >= 40: flinch = min(1.0, flinch + dmg / 150.0)
	# o sangue dela também vira munição
	if G.rng.randf() < .25: G.blood_add(1.0)
	if hp <= 0:
		die(src, head)
		return true
	return false

# ---------------- morte ----------------
func die(src: String, _head: bool) -> void:
	alive = false
	G.relic_unlock("lilith")
	dying = true
	die_t = 0.0
	G.boss = null
	G.stats.kills += 1
	G.add_style(340, "LILITH BANIDA")
	_clear_gfx()
	ad = {"src": src}
	G.main.hitstop(.35)
	G.snd("porrada", 2, .6)
	G.snd("angel", -2, .25)
	for i in 12:
		G.later(.2 + i * .17, func():
			if not is_instance_valid(self): return
			var c = global_position + Vector3(G.rnd(-4, 4), G.rnd(2, 12), G.rnd(-2, 2))
			G.blast(c, .4, src)
			G.emit("blood2", c, 24, 14, .3, 1.0))

func _clear_gfx() -> void:
	for g in gfx:
		if is_instance_valid(g.get("m")): g.m.queue_free()
		for s in g.get("list", []):
			if is_instance_valid(s): s.queue_free()
	gfx.clear()
	souls.clear()

func _upd_death(dt: float) -> void:
	die_t += dt
	var k = min(1.0, die_t / 2.4)
	T.fold = .7 * k; T.raise = 1.0; T.spread = 1.0 - k; T.lean = -.5 * k; T.nod = -.7 * k; T.glow = 1.0
	_anim(dt * (1.0 - k * .6))
	model.position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), 0) * .12 * k
	for m in mats: m.set_shader_parameter("emis", Vector3(.25, .02, .01).lerp(Vector3(2.5, .5, .1), k * (.6 + .4 * G.rng.randf())))
	if die_t >= 2.4 and not fired.has("boom"):
		fired.boom = true
		G.blast(center(), 1.6, ad.get("src", "parry"))
		G.emit("blood2", center(), 120, 30, .4, 1.6)
		G.emit("fire", center(), 80, 28, .4, 1.2)
		G.flash = 1.0
		G.main.banner("RAINHA BANIDA", "O ABISMO SE CALA" if G.mode == "lilith" else "")
		if G.main.has_method("respawn_lilith") and G.mode == "lilith":
			G.later(9.0, G.main.respawn_lilith)
	if die_t >= 2.4:
		var f = clamp((die_t - 2.4) / 1.2, 0.0, 1.0)
		model.scale = Vector3.ONE * MSC * max(.01, 1.0 - f)
		global_position.y -= dt * 6.0 * f
		if f >= 1: queue_free()

# ---------------- animação ----------------
func _anim(dt: float) -> void:
	for key in A.keys():
		A[key] += (T[key] - A[key]) * (1.0 - exp(-RATE.get(key, 6.0) * dt))
	flinch *= exp(-7 * dt)
	var pw = wph
	wph += dt * (3.0 + A.flap * 5.0) * (1.0 - A.fold * .5)
	if floor(pw / TAU) != floor(wph / TAU) and A.flap > .4:
		G.snd("flapbig", -10 + A.flap * 4, .55)
	var s = sin(wph)
	var fold: float = A.fold
	var amp: float = (.26 + A.flap * .3) * (1.0 - fold * .7)
	# batida: as pontas vão para trás e para a frente e sobem/descem; recolhidas, ficam para trás
	var fl: float = amp * s + A.spread * .15 - fold * .55 + flinch * .15
	var li: float = sin(wph + .6) * (.1 + A.flap * .25) * (1.0 - fold * .7) + A.spread * .1
	# ---- tecido: arrasto contra o movimento + mola com sobra (balança e assenta) ----
	var wp: Vector3 = model.global_position
	var v: Vector3 = (wp - cl_prev) / max(dt, .001) if cl_prev != Vector3.ZERO else Vector3.ZERO
	cl_prev = wp
	if v.length() > 60.0: v = Vector3.ZERO
	var vl: Vector3 = model.global_transform.basis.inverse() * v   # já dividido pela escala
	var tgt: Vector3 = -vl * 1.6 + Vector3(0, -vl.y * .4, 0)
	tgt += Vector3(swing * -.03, 0, 0) + Vector3(0, 0, -A.lean * .04)
	tgt = tgt.limit_length(.11)
	cl_vel += ((tgt - cl_off) * 38.0 - cl_vel * 5.5) * dt
	cl_off += cl_vel * dt
	var spd = v.length()
	cl_t += dt * (1.0 + min(spd, 25.0) * .09 + A.flap * .6)
	for m in mats:
		m.set_shader_parameter("cloth_off", cl_off)
		m.set_shader_parameter("cloth_t", cl_t)
		m.set_shader_parameter("cloth_amp", 1.0 + min(spd, 25.0) * .07 + A.flap * .5 + (.8 if att == "dive" else 0.0))
		m.set_shader_parameter("leg_t", phase)
		m.set_shader_parameter("leg_amp", 1.0 + A.flap * .6 + (.6 if att == "dive" else 0.0))
		m.set_shader_parameter("flap", fl)
		m.set_shader_parameter("lift", li)
	var ph = phase
	# braço erguido (esquerdo dela): ergue a cruz e conjura
	var al: Node3D = N.get("armL")
	if al:
		# gira a cruz no alto como quem conjura, mão ondulando
		al.rotation = Vector3(-A.cast * .7 + sin(ph * 1.1) * .16, sin(ph * .7) * .2 + sin(ph * 2.3) * .05, -A.raise * .35 + sin(ph * .9 + 1.0) * .14)
	# braço da garra (direito): rasga
	var ar: Node3D = N.get("armR")
	if ar:
		# garra abre e fecha, braço sobe e desce devagar
		ar.rotation = Vector3(sin(ph * 1.3) * .15 - A.claw * .6, -A.claw * .7 + swing * 1.4 + sin(ph * .8 + .5) * .18, A.raise * .4 - swing * .3 + sin(ph * 1.7) * .1)
	var hd: Node3D = N.get("head")
	if hd:
		# cabeça firme, sempre encarando o jogador
		var look := Vector2.ZERO
		if G.player:
			var to: Vector3 = (G.player.global_position + Vector3(0, 1.6, 0)) - hd.global_position
			var d: Vector3 = model.global_transform.basis.orthonormalized().inverse() * to
			look.x = clamp(-atan2(d.y, Vector2(d.x, d.z).length()), -.5, .6)
			look.y = clamp(atan2(d.x, d.z), -.8, .8)
		head_look = head_look.lerp(look, 1.0 - exp(-6.0 * dt))
		hd.rotation = Vector3(head_look.x + A.nod * .3, head_look.y, flinch * G.rnd(-.06, .06))
	model.position.y = sin(ph * 1.4) * .35 + A.rise
	model.rotation = Vector3(A.lean - flinch * .25, A.spin, sin(ph * .9) * .03 + flinch * G.rnd(-.05, .05))
	# fogo
	var hot: float = A.glow + (.5 if ph2 else 0.0)
	crown.rotation.z = sin(ph * 2.0) * .04
	crown.scale = Vector3.ONE * (1.0 + sin(ph * 7.0) * .04 + hot * .25)
	crown_mat.albedo_color = Color(1, .3 - hot * .1, .08, .55 + hot * .35 + sin(ph * 11.0) * .08)
	for e in eyes: e.albedo_color.a = .7 + .3 * sin(ph * 9.0) + hot * .3
	ring.position.y = -global_position.y + _floor_y() + .08
	ring.rotation.y += dt * (.4 + hot)
	ring_mat.albedo_color.a = .35 + hot * .5
	light.light_energy = 1.6 + hot * 1.2 + sin(ph * 13.0) * .15
	embers.amount = 70
	if not dying:
		for m in mats:
			m.set_shader_parameter("emis", Vector3(2.2, .5, .3) if flash > 0 else Vector3(.05 + hot * .12, .0, .0))

var _fy := 0.0
func _floor_y() -> float:
	return _fy

# ---------------- movimento ----------------
func _move(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var d = to.length()
	if mv == "stalk":
		var want = 18.0
		var spd = (7.0 if ph2 else 5.0)
		if d > want + 2: global_position += to.normalized() * min(spd * dt, d - want)
		elif d < want - 5: global_position -= to.normalized() * spd * .7 * dt
		# flutua em zigue-zague, como serpente
		var side = to.normalized().cross(Vector3.UP)
		global_position += side * sin(phase * .6) * 4.0 * dt
	if mv != "free":
		global_position.y += (BASE_Y + hover - global_position.y) * (1.0 - exp(-3.0 * dt))
	var lim = 40.0
	var hp2 = Vector2(global_position.x, global_position.z)
	if hp2.length() > lim:
		hp2 = hp2.normalized() * lim
		global_position.x = hp2.x; global_position.z = hp2.y
	if mv != "free" or att == "dive":
		var want_a = atan2(p.x - global_position.x, p.z - global_position.z)
		rotation.y = lerp_angle(rotation.y, want_a, 1.0 - exp(-(8.0 if att in ["claw", "kiss"] else 3.5) * dt))

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
		var u = clamp(1.0 - spawn_t / 3.0, 0.0, 1.0)
		# sobe do chão em chamas
		global_position.y = lerp(-14.0, BASE_Y, 1.0 - pow(1.0 - u, 3.0))
		if G.rng.randf() < dt * 30: G.emit("fire", Vector3(global_position.x, .5, global_position.z) + Vector3(G.rnd(-3, 3), 0, G.rnd(-3, 3)), 4, 10, .4, .8, Vector3(0, 8, 0), -4)
		if u > .75 and not fired.has("land"):
			fired.land = true
			T.fold = 0.0; T.spread = 1.0; T.flap = 1.2; T.raise = 1.0; T.glow = 1.0; T.nod = -.4; RATE.fold = 10.0
			G.snd("boom", 0, .6); G.snd("angel", 0, .3); G.snd("flapbig", 0, .5)
			G.shake = max(G.shake, 1.0); G.flash = max(G.flash, .4)
			G.emit("fire", Vector3(global_position.x, .5, global_position.z), 80, 26, .5, 1.3)
			_wave(Color(1, .3, .05))
		_anim(dt)
		_gfx(dt)
		if spawn_t <= 0:
			fired.clear(); _relax()
		return
	flash -= dt
	if ph2 and G.rng.randf() < dt * 14.0:
		var wx = G.rnd(-1, 1)
		G.fx.sprite(model.to_global(Vector3(wx * .42, .55 + G.rnd(0, .3), -.05)), "flame_0%d" % (5 + G.rng.randi() % 2), Color(1, .4, .08, .9), 2.0, 4.5, .5)
	if ph2 and G.rng.randf() < dt * 5.0:
		G.fx.smoke(model.to_global(Vector3(G.rnd(-.2, .2), .2, 0)), Color(.12, .02, .02, .6), 1, 5.0, 2.0, 3.0)
	if not ph2 and hp < max_hp * .5 and att != "inferno":
		_attack("inferno")
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
	var w = {"claw": 1.0, "crosses": 1.0, "brimstone": 1.0, "kiss": 1.0, "dive": 1.0, "rift": 1.0, "souls": 1.0}
	if d < 16: w.claw += 1.3; w.kiss += .4
	else: w.dive += .8; w.souls += .5; w.rift += .5
	if p.y > 4: w.brimstone += .6; w.souls += .5
	if ph2: w.crosses += .4; w.rift += .4; w.abyss = 1.4; w.meteor = 1.3
	w.erase(last_att)
	var tot = 0.0
	for k in w: tot += w[k]
	var x = G.rng.randf() * tot
	for k in w:
		x -= w[k]
		if x <= 0: return k
	return "souls"

func _once(k: String, t: float) -> bool:
	if at >= t and not fired.has(k):
		fired[k] = true
		return true
	return false

func _relax() -> void:
	for k in T.keys(): T[k] = 0.0
	T.glow = .3 if ph2 else 0.0
	RATE.fold = 4.0; RATE.lean = 6.0
	swing = 0.0
	hover = 0.0

func _attack(k: String) -> void:
	if att != "" and k != "inferno": return
	if att != "": _end(false)
	att = k
	at = 0.0
	fired.clear()
	ad = {}
	mv = "stalk"
	# toda habilidade começa com um aviso de carga no chefe
	if G.fx:
		var big = k == "inferno"
		G.fx.charge(center(), Color(1, .4, .08), 1.2 if big else .65, 6.0 * (2.0 if big else 1.0), (G.player.global_position - global_position).normalized())
	match k:
		"inferno":
			inv = true; mv = "hold"; hover = 4.0
			T.spread = 1.0; T.raise = 1.0; T.cast = 1.0; T.glow = 1.0; T.nod = -.6; T.flap = 1.0; T.lean = -.25
			G.main.banner("INFERNO", "A RAINHA DESPERTA O ABISMO")
			G.snd("angel", 0, .25); G.snd("charge", -4, .35)
		"claw":
			T.claw = 1.0; T.lean = .2; T.glow = .5
			G.snd("whoosh", -6, .7)
		"crosses":
			mv = "hold"; T.cast = 1.0; T.raise = .5; T.glow = .8
			G.snd("charge", -6, .7)
		"brimstone":
			mv = "hold"; hover = 3.0; T.cast = 1.0; T.spread = 1.0; T.flap = .5; T.glow = .7
			G.snd("charge", -4, .5)
		"kiss":
			mv = "hold"; T.raise = 1.0; T.spread = 1.0; T.nod = .3; T.glow = 1.0
			G.snd("angel", -6, .8)
		"dive":
			mv = "free"; T.fold = .6; T.flap = 1.0; T.lean = .5
			G.snd("flapbig", 0, .5)
		"rift":
			mv = "hold"; T.claw = 1.0; T.lean = .4; T.nod = .5
			G.snd("charge", -6, .45)
		"souls":
			mv = "hold"; T.raise = .6; T.cast = .7; T.spread = .6; T.glow = .6
			G.snd("whirl", -4, .4)
		"abyss":
			mv = "hold"; hover = 2.0; T.claw = 1.0; T.raise = 1.0; T.glow = 1.0; T.nod = .4
			G.main.banner("COROA DO ABISMO", "")
			G.snd("charge", -2, .4)
		"meteor":
			mv = "hold"; hover = 6.0; T.cast = 1.0; T.raise = 1.0; T.spread = 1.0; T.flap = 1.0; T.glow = 1.0
			G.main.banner("ESTRELA CAÍDA", "")
			G.snd("angel", -2, .3); G.snd("charge", -4, .5)

func _end(set_cd := true) -> void:
	last_att = att
	att = ""
	inv = false
	mv = "stalk"
	_relax()
	if set_cd:
		cd = 1.2 if ph2 else 2.1
		if ph2 and G.rng.randf() < .3: cd = .4

func _player_c() -> Vector3:
	return G.player.global_position + Vector3(0, .9, 0)

func _ground_y(x: float, z: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 8, z), Vector3(x, -2, z), 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else 0.0

func _hand(nm: String) -> Vector3:
	var a: Node3D = N.get(nm)
	if a == null: return center()
	if nm == "armL": return a.to_global(Vector3(.12, .2, -.05))
	return a.to_global(Vector3(-.18, -.12, -.06))

func _orb(p0: Vector3, vel: Vector3, col := Color(1, .35, .05)) -> Dictionary:
	G.main.spawn_orb(p0, vel)
	var pr = G.projs[G.projs.size() - 1]
	pr.mat.albedo_color = col
	return pr

func _fwd() -> Vector3:
	return global_transform.basis.z.normalized()

# ---------------- coreografia ----------------
func _run_attack(dt: float) -> void:
	var p = G.player.global_position
	var pc = _player_c()
	match att:
		"inferno":
			G.shake = max(G.shake, .12)
			if G.rng.randf() < dt * 40: G.emit("fire", center() + Vector3(G.rnd(-5, 5), G.rnd(-5, 5), G.rnd(-2, 2)), 3, 8, .3, .8, Vector3(0, 6, 0), -3)
			var arena = G.main.get("lilith_arena")
			if arena: arena.inferno = clamp(at / 2.0, 0.0, 1.0)
			if _once("burst", 2.0):
				ph2 = true
				G.flash = 1.0; G.shake = max(G.shake, 1.2)
				G.snd("boom", 0, .5); G.snd("angel", 0, .25)
				G.emit("fire", center(), 140, 34, .5, 1.6)
				var push = (p - global_position); push.y = 0
				G.player.velocity += push.normalized() * 20 + Vector3(0, 7, 0)
				_wave(Color(1, .25, .05))
				G.fx.flash(center(), Color(1, .4, .1), 30, .9)
				G.fx.ring_v(center(), (p - global_position).normalized(), Color(1, .35, .05), 24, 1.0)
				G.fx.shock(Vector3(global_position.x, _ground_y(global_position.x, global_position.z), global_position.z), Color(1, .3, .05), 38, 1.2, "circle_03")
				for i in 12: G.fx.pillar(Vector3(cos(i * TAU / 12) * 14 + global_position.x, 0, sin(i * TAU / 12) * 14 + global_position.z), 1.4, 22, Color(1, .35, .05), .9, "beam_soft")
				if G.main.has_method("lilith_inferno"): G.main.lilith_inferno()
			if at > 3.0: _end()
		"claw":
			# avança e rasga três vezes: cada garra solta uma onda de fogo rasteira (pule)
			if at < .6:
				var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
				if to.length() > 9.0: global_position += to.normalized() * min(to.length() - 9.0, 24 * dt)
			for i in 3:
				var t0 = .7 + i * .45
				if _once("c%d" % i, t0):
					ad.st = at; ad.sw = i
					G.snd("whoosh", 0, .9); G.snd("clang", -12, .5)
					var dir = _fwd().rotated(Vector3.UP, (i - 1) * .35)
					var o = Vector3(global_position.x, _ground_y(global_position.x, global_position.z) + .5, global_position.z) + dir * 3.0
					_fire_wave(o, dir)
					G.fx.slash(center() + dir * 4.0, dir, 14, Color(1, .35, .06), .3, "slash_01" if i % 2 else "slash_02")
			if ad.has("st"):
				var u = clamp((at - ad.st) / .18, 0.0, 1.0)
				swing = (u * 2.0 - 1.0) * (1.0 if ad.sw % 2 == 0 else -1.0)
			if at > 2.2: _end()
		"crosses":
			# cruzes invertidas aparecem no ar sobre você e caem cravando no chão
			var n = 7 if ph2 else 5
			if _once("spawn", .5):
				for i in n:
					var a = i * TAU / n + G.rnd(0, .5)
					var rr = 0.0 if i == 0 else G.rnd(3.5, 7.0)
					var q = Vector3(p.x + cos(a) * rr, 0, p.z + sin(a) * rr)
					var gy = _ground_y(q.x, q.z)
					_cross_spawn(q, gy, .9 + i * .12)
			if at > 3.0: _end()
		"brimstone":
			# chuva de enxofre: bolas de fogo sobem da mão erguida e caem em volta de você
			if at > .6 and at < 2.6:
				ad.acc = ad.get("acc", 0.0) + dt
				var rate = .09 if ph2 else .13
				while ad.acc > rate:
					ad.acc -= rate
					var tg = p + G.player.velocity * .5 + Vector3(G.rnd(-6, 6), 0, G.rnd(-6, 6))
					var o = _hand("armL")
					var tf = 1.1
					var v = (tg - o) / tf
					v.y = (tg.y - o.y) / tf + 0.5 * 26.0 * tf
					var pr = _orb(o, v, Color(1, .5, .08))
					pr.grav = 26.0
					G.fx.attach_glow(pr.m, Color(1, .45, .1, .9), 2.2, true, "flame_02")
					G.fx.sigil(Vector3(tg.x, _ground_y(tg.x, tg.z), tg.z), 1.6, Color(1, .35, .05), 1.15, 1)
					G.fx.flash(o, Color(1, .5, .1), 2, .2)
					G.snd("ping", -18, .7)
			if at > 3.2: _end()
		"kiss":
			# Beijo da Súcubo: puxa você para perto; quando o anel fecha, explode. Dê dash para fora!
			if at < 2.0:
				var to = global_position + Vector3(0, 1, 0) - G.player.global_position
				to.y = 0
				var pull = (12.0 if ph2 else 9.0) * clamp(at / .6, 0.0, 1.0)
				G.player.velocity += to.normalized() * pull * dt * 4.0
				if G.rng.randf() < dt * 25: G.tracer(pc, center(), .05, Color(1, .3, .5), .06)
				if G.rng.randf() < dt * 20: G.fx.sprite(pc.lerp(center(), G.rng.randf()), "star_06", Color(1, .3, .55), .8, 1.6, .3)
				if _once("ring", .1):
					var rm = _ring_mesh(Color(1, .2, .4), .7)
					rm.position = Vector3(global_position.x, _ground_y(global_position.x, global_position.z) + .1, global_position.z)
					rm.scale = Vector3(12, 1, 12)
					ad.ring = rm
					G.fx.sigil(rm.position - Vector3(0, .07, 0), 12.0, Color(1, .2, .45), 2.0, 0)
				if is_instance_valid(ad.get("ring")):
					var k = 12.0 - at * 2.0
					ad.ring.scale = Vector3(k, 1, k)
					ad.ring.material_override.albedo_color.a = .4 + .4 * sin(at * 30.0)
			if _once("boom", 2.0):
				if is_instance_valid(ad.get("ring")): ad.ring.queue_free()
				G.snd("boom", 0, .7); G.snd("porrada", -4, .8)
				G.shake = max(G.shake, .9); G.flash = max(G.flash, .3)
				var c = Vector3(global_position.x, 1, global_position.z)
				G.emit("fire", c, 90, 26, .45, 1.0)
				G.fx.flash(c + Vector3(0, 2, 0), Color(1, .35, .5), 18, .6)
				G.fx.shock(c - Vector3(0, .9, 0), Color(1, .25, .45), 14, .7)
				G.fx.smoke(c, Color(.25, .02, .04, .7), 10, 7, 2.0)
				var dd = Vector2(p.x - c.x, p.z - c.z).length()
				if dd < 8.5 and G.hurt_player(32.0 if ph2 else 26.0):
					G.player.velocity += Vector3(p.x - c.x, 0, p.z - c.z).normalized() * 22 + Vector3(0, 9, 0)
			if at > 2.6: _end()
		"dive":
			# sobe, mira e mergulha atravessando a arena, deixando um rastro de fogo no chão
			if at < .8:
				global_position.y += (14.0 - global_position.y) * (1.0 - exp(-4 * dt))
				ad.tgt = Vector3(p.x, 0, p.z)
			elif not fired.has("go"):
				fired.go = true
				ad.from = global_position
				var dir = (ad.tgt - Vector3(global_position.x, 0, global_position.z)).normalized()
				ad.to = ad.tgt + dir * 16.0
				ad.to.x = clamp(ad.to.x, -38.0, 38.0); ad.to.z = clamp(ad.to.z, -38.0, 38.0)
				ad.t0 = at
				G.snd("whoosh", 0, .4); G.snd("angel", -6, .5)
				T.lean = .9; T.fold = 1.0
			if fired.has("go") and not fired.has("done"):
				if G.rng.randf() < dt * 40: G.fx.sprite(center() + Vector3(G.rnd(-2, 2), G.rnd(-3, 3), G.rnd(-2, 2)), "flame_0%d" % (1 + G.rng.randi() % 4), Color(1, .4, .08, .9), 4, 8, .4)
				var u = clamp((at - ad.t0) / .75, 0.0, 1.0)
				var pos: Vector3 = ad.from.lerp(ad.to, u)
				pos.y = lerp(ad.from.y, BASE_Y, sin(u * PI * .5))
				global_position = pos
				ad.acc = ad.get("acc", 0.0) + dt
				if ad.acc > .05 and u > .3:
					ad.acc = 0.0
					_fire_patch(Vector3(pos.x, 0, pos.z))
				if _seg_hit(pc, center(), 4.0) and not ad.get("hit", false):
					ad.hit = true
					if G.hurt_player(28.0 if ph2 else 22.0): G.player.velocity += _fwd() * 20 + Vector3(0, 8, 0)
				if u >= 1: fired.done = true; ad.lt = at; G.shake = max(G.shake, .5)
			if fired.has("done") and at > ad.lt + .7: _end()
			if at > 4.0: _end()
		"rift":
			# crava a garra no chão: fendas de lava se abrem em leque na sua direção e explodem
			if _once("slam", .7):
				G.snd("slam", -2, .6); G.shake = max(G.shake, .5)
				var base_dir = Vector3(p.x - global_position.x, 0, p.z - global_position.z).normalized()
				var nl = 5 if ph2 else 3
				for i in nl:
					var dir = base_dir.rotated(Vector3.UP, (i - (nl - 1) * .5) * .32)
					for k in 12:
						var q = Vector3(global_position.x, 0, global_position.z) + dir * (4.0 + k * 3.0)
						if Vector2(q.x, q.z).length() > 42: break
						_rift_mark(q, .6 + k * .06)
			if at > 2.6: _end()
		"abyss":
			# COROA DO ABISMO: três anéis de colunas de fogo explodem do chão em volta dela, abrindo para fora
			var c = Vector3(global_position.x, 0, global_position.z)
			for w in 3:
				var t0 = .7 + w * .55
				var rr = 6.0 + w * 7.0
				var n = 10 + w * 6
				var gap = G.rnd(0, TAU) if not ad.has("gap%d" % w) else ad["gap%d" % w]
				if _once("m%d" % w, t0 - .55):
					ad["gap%d" % w] = G.rnd(0, TAU)
					for i in n:
						var a = i * TAU / n
						if absf(wrapf(a - ad["gap%d" % w], -PI, PI)) < .45: continue
						var q = c + Vector3(cos(a), 0, sin(a)) * rr
						G.fx.sigil(Vector3(q.x, _ground_y(q.x, q.z), q.z), 1.6, Color(1, .3, .05), .65, 1)
				if _once("e%d" % w, t0):
					G.snd("boom", -6, .9 - w * .1); G.shake = max(G.shake, .5)
					for i in n:
						var a = i * TAU / n
						if absf(wrapf(a - ad["gap%d" % w], -PI, PI)) < .45: continue
						var q = c + Vector3(cos(a), 0, sin(a)) * rr
						var gy = _ground_y(q.x, q.z)
						G.fx.pillar(Vector3(q.x, gy, q.z), 1.3, 12, Color(1, .38, .06), .55)
						G.emit("fire", Vector3(q.x, gy + 1, q.z), 6, 10, .35, .6, Vector3(0, 1, 0), -4)
						if Vector2(p.x - q.x, p.z - q.z).length() < 2.0 and p.y - gy < 5.0:
							if G.hurt_player(20.0): G.player.velocity += Vector3(p.x - c.x, 0, p.z - c.z).normalized() * 10 + Vector3(0, 9, 0)
			if at > 2.6: _end()
		"meteor":
			# ESTRELA CAÍDA: ela ergue um sol de fogo, que cresce e cai sobre você; corra para longe do selo
			if _once("make", .2):
				var sm = MeshInstance3D.new(); var q = QuadMesh.new(); q.size = Vector2.ONE; sm.mesh = q
				sm.material_override = G.fx.mat("light_01", Color(1, .45, .1, 1), true, 1)
				var core = MeshInstance3D.new(); core.mesh = q
				core.material_override = G.fx.mat("star_09", Color(1, .85, .5, 1), true, 1)
				core.scale = Vector3.ONE * .6; sm.add_child(core)
				G.world.add_child(sm)
				sm.global_position = _hand("armL") + Vector3(0, 6, 0)
				ad.sun = sm
				ad.tgt = Vector3(p.x, _ground_y(p.x, p.z), p.z)
			if is_instance_valid(ad.get("sun")):
				var sz = clamp(at / 2.0, 0.0, 1.0) * 16.0 + 2.0
				ad.sun.scale = Vector3.ONE * sz * (1.0 + sin(at * 20.0) * .05)
				if G.rng.randf() < dt * 30: G.emit("fire", ad.sun.global_position + Vector3(G.rnd(-1, 1), G.rnd(-1, 1), G.rnd(-1, 1)) * sz * .3, 2, 6, .4, .6, Vector3.ZERO, -2)
				if at < 1.8:
					ad.tgt = ad.tgt.lerp(Vector3(p.x, _ground_y(p.x, p.z), p.z), 1.0 - exp(-2.5 * dt))
				if _once("sig", 1.8):
					ad.sg = G.fx.sigil(ad.tgt, 10.0, Color(1, .3, .05), 1.4, 0)
					G.snd("charge", -2, .35)
				if at > 2.2:
					var u = clamp((at - 2.2) / .9, 0.0, 1.0)
					ad.sun.global_position = ad.sun.global_position.lerp(ad.tgt + Vector3(0, 2, 0), u * u)
				if _once("hit", 3.1):
					var gq: Vector3 = ad.tgt
					ad.sun.queue_free()
					G.fx.flash(gq + Vector3(0, 3, 0), Color(1, .5, .15), 40, 1.0)
					G.fx.shock(gq, Color(1, .35, .05), 30, 1.0, "circle_03")
					G.fx.shock(gq, Color(1, .9, .6), 14, .5)
					G.fx.smoke(gq, Color(.2, .05, .02, .75), 18, 12, 3.0, 4.0)
					for i in 10: G.fx.pillar(gq + Vector3(cos(i * .63) * 7, 0, sin(i * .63) * 7), 1.2, 14, Color(1, .4, .06), .7)
					G.emit("fire", gq + Vector3(0, 1, 0), 140, 30, .5, 1.2)
					G.snd("boom", 2, .5); G.snd("porrada", 0, .6)
					G.shake = max(G.shake, 1.3); G.flash = max(G.flash, .5)
					var dd = Vector2(p.x - gq.x, p.z - gq.z).length()
					if dd < 10.0 and G.hurt_player(40.0 * (1.0 - dd / 14.0)):
						G.player.velocity += Vector3(p.x - gq.x, 0, p.z - gq.z).normalized() * 24 + Vector3(0, 12, 0)
			if at > 3.8: _end()
		"souls":
			# almas penadas: caveiras de fogo que perseguem você devagar (rebata no soco!)
			var n = 6 if ph2 else 4
			if at > .6 and fired.size() < n:
				var i = fired.size()
				if at > .6 + i * .25 and _once("s%d" % i, .6 + i * .25):
					var a = i * TAU / n
					var o = center() + Vector3(cos(a) * 3.0, 2.0 + sin(a) * 2.0, 0)
					var pr = _orb(o, Vector3(cos(a), 1, sin(a)) * 4.0, Color(.55, 1, .35))
					pr.life = 6.0
					G.fx.attach_glow(pr.m, Color(.5, 1, .35, .9), 3.0, true, "smoke_07")
					G.fx.flash(o, Color(.5, 1, .35), 3, .35)
					souls.append(pr)
					G.snd("ping", -14, .5)
			if at > .6 + n * .25 + .5: _end()

func _seg_hit(p: Vector3, c: Vector3, rr: float) -> bool:
	return p.distance_to(c) < rr

# ---------------- efeitos ----------------
func _ring_mesh(color: Color, op: float) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var tm = TorusMesh.new(); tm.inner_radius = .9; tm.outer_radius = 1.0; tm.rings = 48; tm.ring_segments = 4
	m.mesh = tm
	m.material_override = _addm(color, op)
	G.world.add_child(m)
	if G.fx: G.fx.ring_overlay(m, color, m.material_override)
	return m

func _wave(c: Color) -> void:
	var m = _ring_mesh(c, .7)
	m.position = Vector3(global_position.x, .25, global_position.z)
	gfx.append({"kind": "wave", "m": m, "r": 2.0, "x": global_position.x, "z": global_position.z, "hit": false})

func _fire_wave(o: Vector3, dir: Vector3) -> void:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(4.5, 1.1, .5)
	m.mesh = bm
	m.material_override = _addm(Color(1, .35, .05), .85)
	G.world.add_child(m)
	m.global_position = o
	m.basis = Basis.looking_at(dir, Vector3.UP)
	gfx.append({"kind": "fwave", "m": m, "dir": dir, "t": 0.0, "hit": false})

func _fire_patch(q: Vector3) -> void:
	var y = _ground_y(q.x, q.z)
	var m = MeshInstance3D.new()
	var pm = QuadMesh.new(); pm.size = Vector2(3.2, 3.2)
	m.mesh = pm
	var mt = _addm(Color(1, .35, .05), .8); mt.albedo_texture = G.fx.tex("scorch_02") if G.fx else _soft_tex()
	m.material_override = mt
	m.rotation.x = -PI / 2
	G.world.add_child(m)
	m.global_position = Vector3(q.x, y + .06, q.z)
	gfx.append({"kind": "patch", "m": m, "x": q.x, "y": y, "z": q.z, "t": 0.0, "tick": 0.0})

func _cross_spawn(q: Vector3, gy: float, delay: float) -> void:
	var cr = Node3D.new()
	G.world.add_child(cr)
	var red = G.unshaded(Color(.85, .05, .08))
	var bars = [[Vector3(.35, 5.0, .35), Vector3(0, 0, 0)], [Vector3(2.4, .35, .35), Vector3(0, -1.3, 0)]] # cruz invertida
	for b in bars:
		var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = b[0]; mi.mesh = bm; mi.material_override = red
		mi.position = b[1]; cr.add_child(mi)
	var tip = MeshInstance3D.new(); var cm = CylinderMesh.new(); cm.top_radius = .3; cm.bottom_radius = 0.0; cm.height = 1.2; tip.mesh = cm; tip.material_override = red
	tip.position = Vector3(0, -3.1, 0); cr.add_child(tip)
	cr.global_position = Vector3(q.x, gy + 16.0, q.z)
	if G.fx:
		G.fx.attach_glow(cr, Color(1, .15, .1, .8), 6.0, true, "light_01")
	var mk = _ring_mesh(Color(1, .1, .1), .8)
	mk.position = Vector3(q.x, gy + .07, q.z)
	mk.scale = Vector3(1.6, 1, 1.6)
	G.fx.sigil(Vector3(q.x, gy, q.z), 1.8, Color(1, .15, .1), delay + .5, 0)
	gfx.append({"kind": "cross", "m": cr, "mk": mk, "x": q.x, "y": gy, "z": q.z, "t": -delay, "hit": false, "stuck": 0.0})

func _rift_mark(q: Vector3, delay: float) -> void:
	var y = _ground_y(q.x, q.z)
	var mk = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(1.4, .06, 2.6)
	mk.mesh = bm
	mk.material_override = _addm(Color(1, .3, .05), .7)
	G.world.add_child(mk)
	mk.global_position = Vector3(q.x, y + .05, q.z)
	mk.rotation.y = atan2(q.x - global_position.x, q.z - global_position.z)
	gfx.append({"kind": "rift", "m": mk, "x": q.x, "y": y, "z": q.z, "t": delay})

func _gfx(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	# almas: perseguem o jogador enquanto forem dela
	var keep = []
	for s in souls:
		if not is_instance_valid(s.m) or s.owner != "enemy": continue
		var to = (_player_c() - s.m.global_position).normalized()
		s.vel = s.vel.lerp(to * (11.0 if ph2 else 8.5), 1.0 - exp(-1.6 * dt))
		if G.rng.randf() < dt * 20: G.emit("fire", s.m.global_position, 1, 1, .2, .4)
		keep.append(s)
	souls = keep
	for g in gfx:
		match g.kind:
			"wave":
				g.r += 24 * dt
				g.m.scale = Vector3(g.r, 1, g.r)
				g.m.material_override.albedo_color.a = max(0.0, .7 - g.r / 60.0)
				var d = Vector2(p.x - g.x, p.z - g.z).length()
				if not g.hit and p.y < 1.3 and abs(d - g.r) < 1.3:
					g.hit = true
					if G.hurt_player(20): G.player.velocity.y += 8
				if g.r > 50: g.dead = true
			"fwave":
				g.t += dt
				g.m.global_position += g.dir * (24.0 if ph2 else 20.0) * dt
				g.m.scale = Vector3(1.0 + g.t * .8, 1, 1)
				if G.rng.randf() < dt * 30: G.emit("fire", g.m.global_position, 2, 6, .3, .5, Vector3(0, 5, 0), -2)
				if G.rng.randf() < dt * 22: G.fx.sprite(g.m.global_position + g.dir.cross(Vector3.UP) * G.rnd(-2.2, 2.2) * g.m.scale.x, "flame_0%d" % (5 + G.rng.randi() % 2), Color(1, .45, .1, .9), 1.6, 3.2, .35)
				var rel = p - g.m.global_position
				if not g.hit and abs(rel.dot(g.dir)) < 1.0 and abs(rel.dot(g.dir.cross(Vector3.UP))) < 2.4 * g.m.scale.x and rel.y < 1.0:
					g.hit = true
					if G.hurt_player(18.0 if ph2 else 15.0): G.player.velocity.y += 7
				if g.t > 2.2: g.dead = true
			"patch":
				g.t += dt
				g.tick -= dt
				g.m.material_override.albedo_color.a = (.8 if g.t < 3.0 else .8 * (1.0 - (g.t - 3.0))) * (.8 + .2 * sin(g.t * 20.0))
				if G.rng.randf() < dt * 6: G.emit("fire", Vector3(g.x, g.y + .3, g.z), 2, 4, .3, .6, Vector3(0, 6, 0), -3)
				if g.tick <= 0 and Vector2(p.x - g.x, p.z - g.z).length() < 1.6 and p.y - g.y < 1.4:
					g.tick = .5
					G.hurt_player(6.0)
				if g.t > 4.0: g.dead = true
			"cross":
				g.t += dt
				if is_instance_valid(g.mk): g.mk.material_override.albedo_color.a = .45 + .4 * sin(g.t * 30)
				if g.t > 0 and g.stuck <= 0.0:
					var cy = g.m.global_position.y - 60.0 * dt
					if cy <= g.y + 3.0:
						cy = g.y + 3.0
						g.stuck = .01
						G.snd("spear", -4, .7); G.shake = max(G.shake, .25)
						G.emit("fire", Vector3(g.x, g.y + .3, g.z), 20, 10, .3, .6)
						G.fx.shock(Vector3(g.x, g.y, g.z), Color(1, .15, .1), 5, .5)
						G.fx.flash(Vector3(g.x, g.y + 1, g.z), Color(1, .3, .1), 5, .3)
						if is_instance_valid(g.mk): g.mk.queue_free()
						if Vector2(p.x - g.x, p.z - g.z).length() < 1.9 and p.y - g.y < 4.0:
							if G.hurt_player(20.0 if ph2 else 16.0): G.player.velocity.y += 9
					g.m.global_position.y = cy
				elif g.stuck > 0:
					g.stuck += dt
					if g.stuck > 1.5:
						g.m.global_position.y -= dt * 4.0
					if g.stuck > 2.5: g.dead = true
			"rift":
				g.t -= dt
				g.m.material_override.albedo_color.a = .35 + .4 * sin(g.t * 30)
				if g.t <= 0:
					g.dead = true
					G.emit("fire", Vector3(g.x, g.y + .5, g.z), 14, 14, .4, .7, Vector3(0, 1, 0), 10)
					G.fx.pillar(Vector3(g.x, g.y, g.z), .9, 7, Color(1, .4, .06), .4)
					G.emit("blood2", Vector3(g.x, g.y + .5, g.z), 4, 8, .2, .5)
					if Vector2(p.x - g.x, p.z - g.z).length() < 1.8 and p.y - g.y < 3.0:
						if G.hurt_player(16.0 if ph2 else 13.0): G.player.velocity.y += 10
	for g in gfx:
		if g.get("dead", false):
			if is_instance_valid(g.get("m")): g.m.queue_free()
			if is_instance_valid(g.get("mk")): g.mk.queue_free()
	gfx = gfx.filter(func(g): return not g.get("dead", false))
