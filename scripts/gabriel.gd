extends Node3D
## Gabriel, o Arauto de Muitos Olhos.
## Modelo 3D com asas em dois segmentos (raiz + ponta), auréolas, mãos e corpo animados por código.
## Ataques: Julgamento (raio), Tempestade de Penas, Lanças de Luz, Queda Celestial,
## Investida, Espada do Arcanjo, Selos do Paraíso e Auréola Cortante.
## Abaixo de 50% de vida ele ascende (Julgamento Final) e passa a encadear golpes.

const GCOL := Color(1.2, .98, .74)
const GCOL2 := Color(1.45, 1.08, .7)
const GSC := 23.0
const BASE_Y := 17.0
# eixo (já convertido para o Godot) de cada auréola, medido no modelo
const RING_AX := [Vector3(-0.0239, -0.9258, -0.3772), Vector3(0.0076, 0.8364, 0.5481), Vector3(0.0358, -0.6083, 0.7929), Vector3(-0.0120, -0.2596, 0.9656), Vector3(0.0156, -0.2668, 0.9636)]
const ATTACKS := ["beam", "feathers", "spears", "quake", "dive", "sword", "orbs", "halo"]

var kind = "gabriel"
var alive = true
var is_boss = true
var dummy = false
var fly = true
var hp = 4200.0
var max_hp = 4200.0
var r = 6.5
var h = 4.0
var spawn_t = 2.6
var velocity = Vector3.ZERO
var burn = 0.0
var mark = null

var flash = 0.0
var phase = 0.0
var fph = 0.0
var ang = 0.0
var cd = 3.0
var att = ""
var at = 0.0
var fired = {}
var summoned = {}
var last_att = ""
var ph2 = false
var ascended = false
var inv = false
var dying = false
var die_t = 0.0
var hy = BASE_Y # altura desejada
var mv = "orbit" # orbit | hold | free
var ad = {} # dados do ataque atual

var model: Node3D
var N = {}
var rings = []
var eye: Node3D
var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var light: OmniLight3D
var mats = []
var gcol = GCOL
# poses animadas (A segue T suavemente)
var A = {"flap": 0.0, "hands": 0.0, "ring": 1.0, "glow": 0.0, "fold": 0.0, "spread": 0.0, "lean": 0.0, "tilt": 0.0, "rise": 0.0, "ringsz": 1.0}
var T = {"flap": 0.0, "hands": 0.0, "ring": 1.0, "glow": 0.0, "fold": 0.0, "spread": 0.0, "lean": 0.0, "tilt": 0.0, "rise": 0.0, "ringsz": 1.0}
var RATE = {"fold": 5.0, "lean": 6.0}
var flinch = 0.0
var gfx = []
var blade: Node3D
var blade_mat: StandardMaterial3D
var eye_col = Color(1, .88, .66)

func setup(pos: Vector3) -> void:
	position = Vector3(pos.x, 62, pos.z)
	var ps: PackedScene = load("res://gabriel.glb")
	model = ps.instantiate()
	model.scale = Vector3.ONE * GSC
	model.position.y = -.48 * GSC
	add_child(model)
	_index(model)
	var tex = load("res://gabriel_tex.jpg") if ResourceLoader.exists("res://gabriel_tex.jpg") else null
	for mi in _meshes(model):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var src = mesh.surface_get_material(si)
			# material sem iluminação: a cor fica igual em qualquer placa de vídeo/renderizador
			var m = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = tex if tex else (src.albedo_texture if src is StandardMaterial3D else null)
			m.albedo_color = GCOL
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.disable_fog = true
			mi.set_surface_override_material(si, m)
			mats.append(m)
	for nm in N.keys():
		if nm.begins_with("wing") or nm.begins_with("hand"): N[nm].rotation_order = EULER_ORDER_XYZ
	for k in 5:
		var node: Node3D = N.get("ring%d" % k)
		if node:
			rings.append({"o": node, "n": RING_AX[k].normalized(), "spd": (-1.0 if k % 2 else 1.0) * (.35 + k * .1), "a": G.rnd(0, TAU), "b0": node.basis, "p0": node.position})
	eye = Node3D.new()
	eye.position = Vector3(0, .615, .1)
	model.add_child(eye)
	glow = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(.14, .14)
	glow.mesh = q
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = _halo_tex()
	glow_mat.albedo_color = Color(1, .88, .66, .5)
	glow_mat.disable_fog = true
	glow.material_override = glow_mat
	glow.position = Vector3(0, .615, .12)
	model.add_child(glow)
	light = OmniLight3D.new()
	light.light_color = Color(1, .85, .63)
	light.omni_range = 40
	light.light_energy = 0
	light.position = Vector3(0, .615, .2)
	model.add_child(light)
	_build_blade()
	# área de acerto
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("enemy", self)
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 4.5
	cap.height = 20
	cs.shape = cap
	body.add_child(cs)
	add_child(body)
	ang = atan2(pos.z - G.player.global_position.z, pos.x - G.player.global_position.x)
	# entrada: desce do céu com as asas fechadas
	A.fold = 1.0; T.fold = 1.0; A.lean = -.2
	add_to_group("gabriel")
	G.snd("angel", -4, .8)

func _index(n: Node) -> void:
	if n is Node3D and n.name != "":
		N[String(n.name)] = n
	for c in n.get_children():
		_index(c)

func _meshes(n: Node) -> Array:
	var out = []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out += _meshes(c)
	return out

var _ht: ImageTexture
func _halo_tex() -> ImageTexture:
	if _ht: return _ht
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d = Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_ht = ImageTexture.create_from_image(img)
	return _ht

func _addm(c: Color, op := 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(c.r, c.g, c.b, op)
	mat.disable_fog = true
	return mat

func _box(sz: Vector3, mat: Material, p: Vector3, par: Node3D) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	m.mesh = bm
	m.material_override = mat
	m.position = p
	par.add_child(m)
	return m

# espada de luz presa à mão direita (pivô no punho, lâmina para +Y)
func _build_blade() -> void:
	blade = Node3D.new()
	blade.rotation_order = EULER_ORDER_XYZ
	blade.position = Vector3(3.9, .6, 1.6)
	add_child(blade)
	blade_mat = _addm(Color(1, .86, .5), .95)
	var core = _addm(Color(1, 1, 1), 1.0)
	_box(Vector3(1.4, 17, .3), blade_mat, Vector3(0, 9.5, 0), blade)
	_box(Vector3(.5, 17.5, .35), core, Vector3(0, 9.7, 0), blade)
	_box(Vector3(4.2, .5, .5), blade_mat, Vector3(0, 1, 0), blade)
	_box(Vector3(.5, 1.6, .5), core, Vector3(0, .2, 0), blade)
	blade.scale = Vector3.ONE * .01
	blade.visible = false

func center() -> Vector3:
	return global_position

func is_head(_p: Vector3) -> bool:
	return false

func take_damage(dmg: float, src: String, _head: bool) -> bool:
	if not alive or inv: return false
	hp -= dmg
	flash = 0.09
	if dmg >= 45: flinch = min(1.0, flinch + dmg / 160.0)
	if hp <= 0:
		die(src, false)
		return true
	return false

# ---------------- morte (sequência de 3 s antes de sumir) ----------------
func die(src: String, _head: bool) -> void:
	alive = false
	G.relic_unlock("gabriel")
	dying = true
	die_t = 0.0
	G.boss = null
	G.stats.kills += 1
	G.add_style(300, "GABRIEL ABATIDO")
	_hide_blade()
	for g in gfx:
		if is_instance_valid(g.get("m")): g.m.queue_free()
	gfx.clear()
	ad.src = src
	G.main.hitstop(.35)
	G.snd("clang", 0, .6)
	G.snd("angel", -2, .55)
	for i in 10:
		G.later(.25 + i * .2, func():
			if not is_instance_valid(self): return
			var c = global_position + Vector3(G.rnd(-7, 7), G.rnd(-6, 8), G.rnd(-2, 2))
			G.blast(c, .5, src)
			G.emit("white", c, 20, 14, .3, 1.2))

func _upd_death(dt: float) -> void:
	die_t += dt
	var k = min(1.0, die_t / 2.2)
	T.flap = 0.0; T.fold = .55 * k; T.spread = 0.0; T.hands = -.8 * k; T.ring = 6.0 * (1 - k); T.glow = 1.0
	T.lean = -.35 * k; T.tilt = .25 * k; T.ringsz = 1 + k * .6
	_anim(dt * (1.0 - k * .7))
	model.position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), 0) * .25 * k
	global_position.y -= dt * 2.5 * k
	for m in mats:
		m.albedo_color = gcol * (1.0 + (2.5 if G.rng.randf() < .3 else .6) * k)
	if die_t >= 2.2 and not fired.has("boom"):
		fired.boom = true
		var c = global_position
		G.blast(c, 1.5, ad.get("src", "parry"))
		G.emit("white", c, 90, 32, .35, 1.6)
		G.emit("spark", c, 60, 28, .2, 1.2)
		G.flash = 1.0
		G.main.banner("DIVINDADE ABATIDA", "ELE VOLTARÁ" if G.mode == "boss" else "")
		for m in mats:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if G.mode == "boss":
			G.later(9.0, G.main.respawn_gabriel)
	if die_t >= 2.2:
		var f = clamp((die_t - 2.2) / .9, 0.0, 1.0)
		for m in mats:
			m.albedo_color = Color(2.5, 2.2, 1.8, 1.0 - f)
		model.scale = Vector3.ONE * GSC * (1 + f * .15)
		glow_mat.albedo_color.a = 1.0 - f
		if f >= 1: queue_free()

# ---------------- animação ----------------
func _anim(dt: float) -> void:
	for key in A.keys():
		A[key] += (T[key] - A[key]) * (1.0 - exp(-RATE.get(key, 6.0) * dt))
	flinch *= exp(-7 * dt)
	var pf = fph
	fph += dt * ((5.6 if ph2 else 4.4) + A.flap * 3.0) * (1.0 - A.fold * .65)
	if floor((pf - PI) / TAU) != floor((fph - PI) / TAU) and A.fold < .7:
		_flap_snd(1.0)
	var au: float = (.2 + A.flap * .38) * (1.0 - A.fold * .8)
	_wing("wingUL", -1.0, 0.0, au, false)
	_wing("wingUR", 1.0, 0.0, au, false)
	_wing("wingLL", -1.0, -.7, au * .8, true)
	_wing("wingLR", 1.0, -.7, au * .8, true)
	# corpo: flutuação, inclinação (ataques), balanço e tranco ao levar dano
	model.position.y = -.48 * GSC + sin(phase * 1.1) * .45 + A.rise - sin(fph) * .25 * (1 - A.fold)
	model.position.x = 0.0
	model.rotation = Vector3(A.lean - flinch * .3 + sin(phase * .9) * .02, sin(phase * .5) * .04, sin(phase * .7) * .025 + A.tilt + flinch * G.rnd(-.06, .06))
	var hb = sin(phase * 1.6) * .07
	if N.has("handL"):
		N.handL.rotation = Vector3(hb - A.hands * .55, sin(phase * 1.2) * .05 - A.spread * .2, sin(phase * 1.3) * .05 + A.hands * .35 + A.spread * .25)
	if N.has("handR"):
		N.handR.rotation = Vector3(-hb - A.hands * .55, -sin(phase * 1.2 + 1) * .05 + A.spread * .2, -sin(phase * 1.3 + 1) * .05 - A.hands * .35 - A.spread * .25)
	for rg in rings:
		rg.a += dt * rg.spd * A.ring
		rg.o.basis = Basis(rg.n, rg.a) * rg.b0
		rg.o.scale = Vector3.ONE * A.ringsz
	glow_mat.albedo_color = Color(eye_col.r, eye_col.g, eye_col.b, .45 + A.glow * .55)
	glow.scale = Vector3.ONE * (1 + A.glow * 4 + sin(phase * 20) * A.glow * .4)
	light.light_energy = A.glow * 4
	light.light_color = eye_col
	if not dying:
		for m in mats:
			m.albedo_color = gcol * 1.9 if flash > 0 else gcol

func _flap_snd(k: float) -> void:
	var d = global_position.distance_to(G.player.global_position)
	var vol: float = clamp(1.35 - d / 70.0, .3, 1.2) * (1 + A.flap * .7) * k
	G.snd("gabriel_asas", linear_to_db(vol), (1.06 if ph2 else .94) - A.flap * .14, [1.62, 3.86, 6.1, 8.36][G.rng.randi() % 4], .8)

# asa em dois segmentos: a ponta acompanha a raiz com atraso (onda), dobra e varre para trás
func _wing(nm: String, side: float, ph: float, amp: float, lower: bool) -> void:
	var o = N.get(nm)
	if o == null: return
	var tp = N.get(nm + "t")
	var s = sin(fph + ph)
	if s < 0: s *= 1.25
	var fold = A.fold
	var spread = A.spread
	var zf = -.25 if not lower else .35 # direção de recolher a raiz
	o.rotation = Vector3(sin(fph + ph + .6) * .05 * (1 - fold),
		side * (cos(fph + ph) * (.1 + A.flap * .12) * (1 - fold) + fold * .95 - flinch * .25),
		side * (amp * s + spread * (.18 if not lower else -.12) + fold * zf + flinch * .15))
	if tp:
		var s2 = sin(fph + ph - .95)
		tp.rotation = Vector3(0, side * (fold * .8 + max(0.0, -s2) * .12 * (1 - fold)),
			side * (amp * .85 * s2 - fold * (.55 if not lower else -.35) + spread * .12 - flinch * .3))

# ---------------- movimento ----------------
func _move(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	if mv == "orbit":
		ang += dt * (.22 if ph2 else .14)
		var R = 26.0
		var tx: float = clamp(p.x + cos(ang) * R, -32.0, 32.0)
		var tz: float = clamp(p.z + sin(ang) * R, -32.0, 32.0)
		var k = 1.0 - exp(-.7 * dt)
		global_position.x += (tx - global_position.x) * k
		global_position.z += (tz - global_position.z) * k
		global_position.y += (hy - global_position.y) * (1.0 - exp(-1.6 * dt))
	elif mv == "hold":
		global_position.y += (hy - global_position.y) * (1.0 - exp(-3.0 * dt))
	if mv != "free" or att == "dive":
		var want = atan2(p.x - global_position.x, p.z - global_position.z)
		var turn = 10.0 if att in ["beam", "sword"] else 4.0
		rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-turn * dt))

# ---------------- laço ----------------
func _physics_process(dt: float) -> void:
	if G.state != "play": return
	phase += dt
	if dying:
		_upd_death(dt)
		return
	if not alive: return
	if spawn_t > 0:
		spawn_t -= dt
		var u = clamp(1.0 - spawn_t / 2.6, 0.0, 1.0)
		global_position.y = lerp(62.0, BASE_Y, 1.0 - pow(1.0 - u, 3.0))
		if spawn_t < .7 and not fired.has("intro"):
			fired.intro = true
			T.fold = 0.0; T.spread = 1.0; T.flap = 1.5; T.glow = 1.0; RATE.fold = 14.0
			G.snd("flapbig", 0); _flap_snd(1.4)
			G.flash = max(G.flash, .4); G.shake = max(G.shake, .6)
			G.emit("white", global_position, 60, 26, .3, 1.2)
		_anim(dt)
		if spawn_t <= 0:
			fired.clear(); _relax()
		return
	flash -= dt
	if not ascended and hp < max_hp * .5:
		_attack("ascend")
	_anim(dt)
	_gfx(dt)
	_move(dt)
	# corrompido: fumaça escura e brasas saindo do corpo
	if ph2 and G.rng.randf() < dt * 5.0:
		G.fx.smoke(global_position + Vector3(G.rnd(-5, 5), G.rnd(-6, 4), G.rnd(-2, 2)), Color(.18, .02, .02, .55), 1, 6.0, 2.2, 4.0)
	if ph2 and G.rng.randf() < dt * 8.0:
		G.fx.burst(global_position + Vector3(G.rnd(-6, 6), G.rnd(-6, 6), 0), Color(1, .3, .08), 3, 4, .5, 1.2, "flame_05", -3.0)
	for th in [0.75, 0.5, 0.25]:
		if hp < max_hp * th and not summoned.has(th) and att != "ascend" and at > .2:
			summoned[th] = true
			G.main.banner("GABRIEL CHAMA", "REFORÇOS")
			G.snd("angel", -6)
			for i in 3:
				G.later(i * .3, func(): G.main.spawn_enemy("husk"))
			G.later(1.0, func(): G.main.spawn_enemy("drone"))
	if att != "":
		at += dt
		_run_attack(dt)
	else:
		cd -= dt
		if cd <= 0: _attack(_pick())

func _pick() -> String:
	var p = G.player.global_position
	var d = Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var w = {"beam": 1.0, "feathers": 1.0, "spears": 1.0, "quake": 1.0, "dive": 1.0, "sword": 1.0, "orbs": 1.0, "halo": 1.0}
	if d < 20: w.quake += 1.0; w.sword += .8
	else: w.beam += .8; w.dive += .8; w.halo += .5
	if p.y > 4: w.beam += .6; w.feathers += .6 # jogador no alto
	if ph2: w.dive += .4; w.orbs += .4; w.trumpets = 1.4; w.bloodfall = 1.4
	w.erase(last_att)
	var tot = 0.0
	for k in w: tot += w[k]
	var x = G.rng.randf() * tot
	for k in w:
		x -= w[k]
		if x <= 0: return k
	return "beam"

func _once(k: String, t: float) -> bool:
	if at >= t and not fired.has(k):
		fired[k] = true
		return true
	return false

func _relax() -> void:
	T.flap = 0.0; T.hands = 0.0; T.ring = 1.0; T.glow = 0.0; T.fold = 0.0; T.spread = 0.0; T.lean = 0.0; T.tilt = 0.0; T.rise = 0.0
	T.ringsz = 1.25 if ascended else 1.0
	RATE.fold = 5.0; RATE.lean = 6.0
	eye_col = Color(1, .88, .66)

func _attack(k: String) -> void:
	if att != "" and k != "ascend": return
	if att != "": _end(false)
	att = k
	at = 0.0
	fired.clear()
	ad = {}
	mv = "orbit"
	hy = BASE_Y
	# toda habilidade começa com um aviso de carga no chefe
	if G.fx:
		var big = k == "ascend"
		G.fx.charge(eye.global_position, _fxc(), 1.2 if big else .65, 9.0 * (2.0 if big else 1.0), (G.player.global_position - global_position).normalized())
	match k:
		"ascend":
			inv = true; ascended = true; ph2 = true; mv = "hold"; hy = 27.0
			T.spread = 1.0; T.glow = 1.0; T.ring = 8.0; T.hands = -.6; T.lean = -.25; T.fold = .3
			G.main.banner("JULGAMENTO FINAL", "GABRIEL ASCENDE")
			G.snd("angel", 0, .7); G.snd("charge", -4, .5)
		"beam":
			mv = "hold"; T.spread = 1.0; T.hands = 1.0; T.ring = 5.0; T.glow = 1.0; T.lean = -.1
			ad.n = 2 if ph2 else 1; ad.k = 0
			ad.aim = G.player.global_position + Vector3(0, 1, 0)
			G.snd("charge", -4)
		"feathers":
			T.fold = .9; T.lean = -.18; T.ring = 2.0; RATE.fold = 3.5
			G.snd("whoosh", -4, .55)
		"spears":
			mv = "hold"; hy = BASE_Y + 3; T.hands = -1.0; T.glow = .6; T.ring = 4.0; T.spread = .6; T.lean = -.15
			ad.n = 8 if ph2 else 5; ad.k = 0
			G.snd("angel", -6)
		"quake":
			mv = "hold"; hy = 31.0; T.spread = 1.0; T.hands = -.6; T.ring = 3.0; T.lean = -.2
			G.snd("charge", -6, .7)
		"dive":
			mv = "free"; T.fold = 1.0; T.lean = .15; T.glow = 1.0; RATE.fold = 4.0
			eye_col = Color(1, .25, .15)
			var bk = global_position - (G.player.global_position - global_position).normalized() * 7.0
			bk.y = BASE_Y + 4
			ad.back = bk
			G.snd("angel", -4, .6); G.snd("beep", -6, .7)
		"sword":
			mv = "hold"; T.hands = .4; T.ring = 3.0; T.glow = .5
			blade.visible = true; blade.scale = Vector3.ONE * .01; blade.rotation = Vector3(-.3, 0, -.25)
			blade_mat.albedo_color.a = .95
			G.snd("angel", -4, 1.2); G.snd("charge", -6, 1.3)
		"orbs":
			mv = "hold"; T.hands = 1.0; T.spread = .8; T.ring = 3.0; T.glow = .7
			ad.orbs = []
			ad.n = 12 if ph2 else 8
			G.snd("charge", -6, 1.1)
		"halo":
			mv = "hold"; T.ring = 10.0; T.glow = .8; T.hands = -.4; T.spread = .5; T.ringsz = 1.5
			G.snd("whirl", -2, .6)
		"trumpets":
			mv = "hold"; hy = BASE_Y + 6; T.spread = 1.0; T.hands = -1.0; T.ring = 6.0; T.glow = 1.0; T.lean = -.3
			G.main.banner("TROMBETAS DO JUÍZO", "")
			G.snd("angel", 0, .45); G.snd("charge", -2, .6)
			ad.k = 0; ad.order = [0, 4, 2, 6, 1, 5, 3, 7]
		"bloodfall":
			mv = "hold"; hy = BASE_Y + 8; T.spread = 1.0; T.hands = 1.0; T.ring = 5.0; T.glow = 1.0; T.flap = 1.0
			G.main.banner("O CÉU SANGRA", "")
			G.snd("angel", -2, .5)
			ad.w = 0

func _end(set_cd := true) -> void:
	if att == "orbs":
		# selos que ainda não saíram são disparados de uma vez
		for o in ad.get("orbs", []):
			if not o.has("go") and is_instance_valid(o.p.m) and o.p.owner == "enemy":
				o.p.vel = (_player_c() - o.p.m.global_position).normalized() * 24.0
	last_att = att
	att = ""
	inv = false
	mv = "orbit"
	hy = BASE_Y
	_relax()
	_hide_blade()
	if set_cd:
		cd = 1.6 if ph2 else 2.6
		if ph2 and G.rng.randf() < .35: cd = .35 # encadeia golpes

func _hide_blade() -> void:
	if blade and blade.visible:
		var tw = create_tween()
		tw.tween_property(blade, "scale", Vector3.ONE * .01, .25)
		tw.tween_callback(func(): blade.visible = false)

func _player_c() -> Vector3:
	return G.player.global_position + Vector3(0, .9, 0)

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.length_squared(), .0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _ground_y(x: float, z: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 4.5, z), Vector3(x, -1, z), 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else 0.0

func _ray_end(a: Vector3, dir: Vector3, L: float) -> Vector3:
	var q = PhysicsRayQueryParameters3D.create(a, a + dir * L, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else a + dir * L

# ---------------- coreografia dos ataques ----------------
func _run_attack(dt: float) -> void:
	var p = G.player.global_position
	var pc = _player_c()
	var eye_p: Vector3 = eye.global_position
	match att:
		"ascend":
			G.shake = max(G.shake, .15)
			if G.rng.randf() < dt * 25: G.emit("white", global_position + Vector3(G.rnd(-8, 8), G.rnd(-10, 10), 0), 3, 6, .25, .8, Vector3(0, 8, 0), -4)
			if _once("burst", 1.7):
				# Gabriel corrompido: fica cor de sangue e o céu vira inferno
				gcol = Color(1.0, .3, .26)
				glow_mat.albedo_color = Color(1, .2, .1, .5)
				eye_col = Color(1, .1, .05)
				G.main.banner("GABRIEL CORROMPIDO", "O CÉU SANGRA")
				if G.main.gabriel_arena: G.main.gabriel_arena.corrupt()
				T.ringsz = 1.35; T.fold = 0.0; T.flap = 1.8; RATE.fold = 14.0
				G.flash = 1.0; G.shake = max(G.shake, 1.2)
				G.snd("boom", 0, .7); G.snd("flapbig", 0, .8); _flap_snd(1.5)
				G.emit("white", global_position, 120, 40, .35, 1.6)
				var push = (p - global_position); push.y = 0
				G.player.velocity += push.normalized() * 22 + Vector3(0, 8, 0)
				_wave(); _air_ring(global_position, Color(1, .9, .6))
				G.fx.flash(eye.global_position, Color(1, .2, .1), 30, .9)
				G.fx.ring_v(global_position, (G.player.global_position - global_position).normalized(), Color(1, .25, .1), 26, 1.0)
				G.fx.shock(Vector3(global_position.x, 0, global_position.z), Color(1, .2, .08), 40, 1.2)
				for i in 10: G.fx.bolt(global_position + Vector3(0, 6, 0), global_position + Vector3(cos(i * .63) * 30, -20, sin(i * .63) * 30), Color(1, .25, .1), 1.4, .4)
			if at > 2.6: _end()
		"beam":
			var tl = 1.15 + ad.k * .9 # momento de travar a mira
			var tf = tl + .3 # disparo
			if at < tl:
				ad.aim = ad.aim.lerp(pc + G.player.velocity * .12, 1.0 - exp(-7 * dt))
				G.tracer(eye_p, ad.aim, .03 + clamp(at / tl, 0.0, 1.0) * .05, Color(1, .55, .2), .04)
				if G.rng.randf() < dt * 30: G.emit("white", eye_p + Vector3(G.rnd(-3, 3), G.rnd(-3, 3), G.rnd(-3, 3)), 1, 0, .15, .25, (eye_p - global_position) * 0, 0)
			elif at < tf:
				# mira travada: dá tempo de esquivar
				if int(at * 30) % 2 == 0: G.tracer(eye_p, ad.aim, .09, Color.WHITE, .035)
				if _once("lock%d" % ad.k, tl): G.snd("beep", -4, 1.4); T.lean = -.05
			if _once("fire%d" % ad.k, tf):
				var dir = (ad.aim - eye_p).normalized()
				var end = _ray_end(eye_p, dir, 140)
				G.fx.beam(eye_p, end, 2.2, _fxc(), .55)
				G.fx.flash(end, _fxc(), 10, .5)
				G.fx.flash(eye_p, _fxc(), 8, .4)
				G.fx.shock(Vector3(end.x, end.y, end.z), _fxc(), 7, .5)
				G.emit("white", end, 30, 16, .22, .6)
				G.emit("spark", end, 26, 14, .15, .6)
				G.main.world_flash(end, 14)
				G.flash = max(G.flash, .55)
				G.shake = max(G.shake, .8)
				G.snd("beam", 0); G.snd("boomlite", -4, .7)
				T.lean = -.4; flinch = .3
				G.later(.2, func(): T.lean = -.1)
				if _seg_dist(pc, eye_p, end) < 1.7 and G.hurt_player(30.0 if ph2 else 25.0):
					G.player.velocity += dir * 12
				ad.k += 1
				if ad.k >= ad.n: ad.done = at + .5
			if ad.has("done") and at > ad.done: _end()
		"feathers":
			var vol = 2 if ph2 else 1
			for v in vol:
				var t0 = .6 + v * .75
				if _once("snap%d" % v, t0):
					# batida violenta para frente
					T.fold = -.35; T.flap = 1.8; T.lean = .2; RATE.fold = 16.0
					G.snd("flapbig", 0); _flap_snd(1.5)
					G.shake = max(G.shake, .4)
					G.fx.ring_v(global_position, (G.player.global_position - global_position).normalized(), _fxc(), 14, .5)
					G.fx.burst(global_position, Color(1, .97, .9), 30, 22, 1.2, .8, "trace_05", 0.0)
					var tips = []
					for nm in [["wingULt", -1], ["wingURt", 1], ["wingLLt", -1], ["wingLRt", 1]]:
						if N.has(nm[0]): tips.append([N[nm[0]], nm[1]])
					# modelo antigo (sem pontas separadas): usa a raiz das asas ou o próprio corpo
					if tips.is_empty():
						for nm in [["wingUL", -1], ["wingUR", 1], ["wingLL", -1], ["wingLR", 1]]:
							if N.has(nm[0]): tips.append([N[nm[0]], nm[1]])
					if tips.is_empty(): tips.append([self, 0.0])
					var n = 18 if ph2 else 12
					for i in n:
						var tp = tips[i % tips.size()]
						G.later(i * .03, func():
							if not alive: return
							var p0: Vector3 = tp[0].to_global(Vector3(tp[1] * .2, 0, 0))
							var tg = G.player.global_position + Vector3(G.rnd(-3, 3), 1 + G.rnd(-.5, 1), G.rnd(-3, 3))
							G.main.spawn_feather(p0, (tg - p0).normalized() * (25.0 if ph2 else 20.0)))
				if _once("reload%d" % v, t0 + .35) and v + 1 < vol:
					T.fold = .9; T.lean = -.18; RATE.fold = 5.0
			if at > .6 + vol * .75 + .2: _end()
		"spears":
			# lanças se formam sobre a cabeça e caem nas marcas
			if G.rng.randf() < dt * 20: G.emit("white", global_position + Vector3(G.rnd(-5, 5), 12, G.rnd(-5, 5)), 2, 4, .2, .6, Vector3(0, 10, 0), -5)
			if ad.k < ad.n and at > .35 + ad.k * .2:
				ad.k += 1
				var x = clamp(p.x + G.player.velocity.x * .55 + G.rnd(-4, 4), -40.0, 40.0)
				var z = clamp(p.z + G.player.velocity.z * .55 + G.rnd(-4, 4), -40.0, 40.0)
				if ad.k == 1: x = p.x; z = p.z
				var y = _ground_y(x, z)
				var mk = _ring_mesh(Color(1, .31, .19), .85)
				mk.position = Vector3(x, y + .06, z)
				mk.scale = Vector3(2.2, 1, 2.2)
				gfx.append({"kind": "mark", "m": mk, "x": x, "y": y, "z": z, "t": .9})
				G.fx.sigil(Vector3(x, y, z), 2.6, _fxc(), 1.15, 1)
				G.snd("ping", -10, .6)
				T.hands = -1.0 if ad.k % 2 else -.7
			if at > .35 + ad.n * .2 + .4: _end()
		"quake":
			# sobe, recolhe as asas, despenca e esmaga o chão
			if _once("fold", .85):
				T.fold = 1.0; T.lean = .35; T.spread = 0.0; RATE.fold = 9.0
				G.snd("whoosh", -2, .45)
			if at > 1.05 and not fired.has("land"):
				mv = "free"
				ad.vy = ad.get("vy", 0.0) - 160 * dt
				global_position.y += ad.vy * dt
				if G.rng.randf() < .6: G.emit("white", global_position + Vector3(G.rnd(-4, 4), 8, G.rnd(-4, 4)), 2, 2, .3, .5, Vector3(0, 20, 0), 0)
				if global_position.y <= 11.5:
					global_position.y = 11.5
					fired.land = true
					ad.tl = at
					T.fold = -.2; T.spread = 1.0; T.lean = -.1; T.hands = .3; T.flap = 1.2; RATE.fold = 16.0
					_wave()
					if ph2: G.later(.45, _wave)
					var gp = Vector3(global_position.x, .5, global_position.z)
					G.emit("dust", gp, 60, 22, .5, 1.4)
					G.emit("spark", gp, 40, 26, .15, .8)
					G.fx.shock(gp, _fxc(), 18, .7)
					G.fx.shock(gp, Color(1, 1, 1, .7), 10, .4, "circle_03")
					G.fx.flash(gp + Vector3(0, 2, 0), _fxc(), 16, .5)
					G.fx.smoke(gp, Color(.75, .7, .65, .55) if not ph2 else Color(.4, .08, .06, .6), 10, 7, 2.0)
					G.main.world_flash(gp, 18)
					G.snd("slam", 0); G.snd("boom", -2, .8)
					G.shake = max(G.shake, 1.1)
					G.flash = max(G.flash, .3)
					var dd = Vector2(p.x - gp.x, p.z - gp.z).length()
					if dd < 8 and G.hurt_player(30): G.player.velocity += Vector3(p.x - gp.x, 0, p.z - gp.z).normalized() * 20 + Vector3(0, 9, 0)
			if fired.has("land") and at > ad.tl + .7:
				mv = "hold"; hy = BASE_Y
			if fired.has("land") and at > ad.tl + 1.4: _end()
		"dive":
			# recua carregando, investe atravessando a arena e volta ao alto
			if at < .85:
				global_position = global_position.lerp(ad.back, 1.0 - exp(-3 * dt))
				if G.rng.randf() < dt * 14: G.snd("beep", -16, .6 + at)
				T.lean = -.25
			elif not fired.has("go"):
				fired.go = true
				var tgt = Vector3(p.x, 9.5, p.z) + Vector3(G.player.velocity.x, 0, G.player.velocity.z) * .25
				var d = tgt - global_position
				ad.dir = d.normalized()
				ad.a = global_position
				var bb = tgt + Vector3(d.x, 0, d.z).normalized() * 26 + Vector3(0, 6, 0)
				bb.x = clamp(bb.x, -36.0, 36.0); bb.z = clamp(bb.z, -36.0, 36.0)
				ad.b = bb
				ad.u = 0.0
				T.lean = .9; T.fold = 1.0
				G.snd("whoosh", 0, .5); G.snd("flapbig", -2, .7)
				G.shake = max(G.shake, .4)
			if fired.has("go") and not fired.has("done"):
				var L = ad.a.distance_to(ad.b)
				ad.u = min(1.0, ad.u + dt * 85.0 / max(L, 1.0))
				var e = ad.u * ad.u * (3 - 2 * ad.u)
				var prev = global_position
				global_position = ad.a.lerp(ad.b, e)
				var fwd = global_position - prev
				if fwd.length() > .01:
					rotation.y = atan2(fwd.x, fwd.z)
				for i in 3: G.emit("white", global_position + Vector3(G.rnd(-3, 3), G.rnd(-6, 6), G.rnd(-3, 3)), 1, 1, .4, .6, Vector3.ZERO, 0)
				if G.rng.randf() < .5: G.fx.sprite(global_position + Vector3(G.rnd(-2, 2), G.rnd(-4, 4), 0), "trace_05", Color(_fxc().r, _fxc().g, _fxc().b, .7), 10, 14, .35)
				# o corpo (cápsula vertical) atropela o jogador
				var lo = global_position - Vector3(0, 8, 0)
				var hi = global_position + Vector3(0, 8, 0)
				if not fired.has("hit") and _seg_dist(pc, lo, hi) < 5.0:
					fired.hit = true
					if G.hurt_player(32.0 if ph2 else 26.0):
						G.player.velocity += ad.dir * 26 + Vector3(0, 10, 0)
						G.main.hitstop(.08)
				if ad.u >= 1:
					fired.done = true
					T.fold = 0.0; T.spread = 1.0; T.flap = 1.4; T.lean = -.3; RATE.fold = 12.0
					eye_col = Color(1, .88, .66)
					_flap_snd(1.4)
					ad.tr = at
			if fired.has("done"):
				mv = "orbit"
				if at > ad.tr + .9: _end()
		"sword":
			# materializa a espada, ergue para trás, golpeia de cima e abre fendas de luz no chão
			var grow: float = clamp(at / .45, 0.0, 1.0)
			if not fired.has("swing"):
				blade.scale = Vector3.ONE * max(.01, grow)
				var up = clamp((at - .45) / .6, 0.0, 1.0)
				blade.rotation = Vector3(-.3 - up * .9, 0, -.25 + up * .1)
				T.lean = -.25 * up
				if G.rng.randf() < dt * 30: G.emit("spark", blade.to_global(Vector3(0, G.rnd(2, 16), 0)), 1, 2, .15, .4, Vector3.ZERO, 0)
			if _once("swing", 1.2):
				ad.s0 = at
				G.snd("whoosh", 0, .6)
			if fired.has("swing") and not fired.has("cut"):
				var u = clamp((at - ad.s0) / .16, 0.0, 1.0)
				blade.rotation = Vector3(-1.2 + u * 3.0, 0, -.15)
				T.lean = .4; RATE.lean = 20.0
				if u >= 1:
					fired.cut = true
					var tip = blade.to_global(Vector3(0, 16, 0))
					var o = Vector3(tip.x, 0, tip.z)
					var dd = Vector3(p.x - o.x, 0, p.z - o.z)
					if dd.length() < 1: dd = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
					var base = atan2(dd.x, dd.z)
					var angs = [0.0] if not ph2 else [-.38, 0.0, .38]
					for a in angs:
						var dv = Vector3(sin(base + a), 0, cos(base + a))
						gfx.append({"kind": "fissure", "o": o, "d": dv, "s": 0.0, "next": 0.0, "hit": false, "m": null})
					G.emit("white", o + Vector3(0, .5, 0), 40, 18, .3, .8)
					G.emit("dust", o, 40, 16, .5, 1.2)
					G.fx.slash(blade.to_global(Vector3(0, 8, 0)), Vector3(p.x - global_position.x, 0, p.z - global_position.z), 22, _fxc(), .35, "slash_03")
					G.fx.flash(o + Vector3(0, 1, 0), _fxc(), 12, .4)
					G.fx.shock(o, _fxc(), 10, .5)
					G.main.world_flash(o + Vector3(0, 1, 0), 16)
					G.snd("slam", 0); G.snd("spear", 0, .7)
					G.shake = max(G.shake, 1.0)
					G.flash = max(G.flash, .25)
			if fired.has("cut") and at > ad.s0 + .7:
				_hide_blade()
				T.lean = -.1; RATE.lean = 6.0
			if fired.has("cut") and at > ad.s0 + 1.0: _end()
		"orbs":
			# selos (esferas laranja que podem ser rebatidas com F) formam um círculo e disparam um a um
			while ad.orbs.size() < ad.n and at > .1 + ad.orbs.size() * .06:
				var i = ad.orbs.size()
				var a = i / float(ad.n) * TAU
				var off = Vector3(cos(a) * 9.0, sin(a) * 9.0 + 2.0, 3.0)
				var pos = global_transform * off
				G.main.spawn_orb(pos, Vector3.ZERO)
				var pr = G.projs.back()
				pr.life = 9.0
				ad.orbs.append({"p": pr, "off": off})
				G.emit("spark", pos, 6, 4, .1, .3)
				G.fx.flash(pos, _fxc(), 2.4, .3)
				if i == 0: G.fx.sprite(global_transform * Vector3(0, 2, 3), "magic_02", Color(_fxc().r, _fxc().g, _fxc().b, .9), 6, 20, 1.4, .8, true, (G.player.global_position - global_position).normalized())
				G.snd("ping", -10, .8 + i * .05)
			for o in ad.orbs:
				if o.has("go") or not is_instance_valid(o.p.m): continue
				if o.p.owner != "enemy":
					o.go = true
					continue
				o.p.m.global_position = global_transform * o.off
			var t0 = .1 + ad.n * .06 + .45
			for i in ad.orbs.size():
				var o = ad.orbs[i]
				if not o.has("go") and at > t0 + i * (.1 if ph2 else .14):
					o.go = true
					if is_instance_valid(o.p.m) and o.p.owner == "enemy":
						var from: Vector3 = o.p.m.global_position
						var tg = _player_c() + G.player.velocity * (from.distance_to(pc) / 30.0) * .6
						o.p.vel = (tg - from).normalized() * (32.0 if ph2 else 26.0)
						G.snd("eshot", -8, 1.1)
						T.hands = 1.0 if i % 2 else .7
			if at > t0 + ad.n * .14 + .4: _end()
		"trumpets":
			# TROMBETAS DO JUÍZO: as oito trombetas da arena apontam para você e disparam, uma de cada vez
			var arena = G.main.gabriel_arena
			if arena and arena.trumpets.size() >= 8:
				var step = .42
				for j in 8:
					var tr = arena.trumpets[ad.order[j]]
					var bell: Vector3 = tr.n.to_global(Vector3(0, 0, -21.0))
					var t0 = .5 + j * step
					if at > t0 - .7 and at < t0:
						if not ad.has("aim%d" % j): ad["aim%d" % j] = pc
						ad["aim%d" % j] = ad["aim%d" % j].lerp(pc + G.player.velocity * .2, 1.0 - exp(-6.0 * dt))
						if G.rng.randf() < dt * 25: G.tracer(bell, ad["aim%d" % j], .05, Color(1, .2, .1, .7), .04)
						tr.g.albedo_color.a = 1.0
					if _once("tf%d" % j, t0):
						var aim: Vector3 = ad.get("aim%d" % j, pc)
						var end = _ray_end(bell, (aim - bell).normalized(), 160)
						G.fx.beam(bell, end, 1.6, Color(1, .22, .1), .45)
						G.fx.flash(bell, Color(1, .4, .15), 9, .4)
						G.fx.flash(end, Color(1, .2, .1), 8, .4)
						G.fx.shock(end, Color(1, .2, .08), 6, .5)
						G.emit("fire", end, 14, 10, .25, .6)
						G.snd("beam", -4, .8 + j * .04); G.shake = max(G.shake, .35)
						if _seg_dist(pc, bell, end) < 1.6 and G.hurt_player(18.0):
							G.player.velocity += (end - bell).normalized() * 9 + Vector3(0, 5, 0)
				if at > .5 + 8 * step + .6: _end()
			else: _end()
		"bloodfall":
			# O CÉU SANGRA: três ondas de colunas de sangue caem em volta de você, avisadas por selos vermelhos
			for w in 3:
				var t0 = .5 + w * 1.15
				if _once("sig%d" % w, t0):
					var pts = []
					var c0 = Vector3(p.x, 0, p.z)
					pts.append(c0)
					var ring_n = 5 + w * 2
					for i in ring_n:
						var a = i * TAU / ring_n + w * .4
						pts.append(c0 + Vector3(cos(a), 0, sin(a)) * (5.5 + w * 2.5))
					ad["pts%d" % w] = pts
					for q in pts:
						q.y = _ground_y(q.x, q.z)
						G.fx.sigil(q, 2.4, Color(1, .12, .08), 1.0, 0)
					G.snd("ping", -8, .5)
				if _once("fall%d" % w, t0 + .85):
					G.snd("slam", -4, .7); G.shake = max(G.shake, .5)
					for q in ad["pts%d" % w]:
						var gy = _ground_y(q.x, q.z)
						var gq = Vector3(q.x, gy, q.z)
						G.fx.pillar(gq, 1.6, 40, Color(.85, .05, .04), .55)
						G.fx.burst(gq + Vector3(0, .5, 0), Color(.6, 0, .02), 12, 9, .9, .7, "circle_05", 18.0, true)
						G.emit("blood2", gq + Vector3(0, .4, 0), 14, 9, .22, .7)
						if Vector2(p.x - q.x, p.z - q.z).length() < 2.2 and p.y - gy < 4.0:
							if G.hurt_player(20.0): G.player.velocity.y += 9
			if at > 4.4: _end()
		"halo":
			# arremessa uma auréola gigante girando que vai e volta (pule por cima)
			if _once("make", .1):
				var n = 2 if ph2 else 1
				for i in n:
					var m = _ring_mesh(Color(1, .82, .4), .9)
					m.scale = Vector3.ONE * .1
					var start = global_position + Vector3(0, 9, 0)
					m.position = start
					gfx.append({"kind": "halo", "m": m, "pos": start, "st": "grow", "t": 0.0, "side": (0.0 if n == 1 else (-1.0 if i == 0 else 1.0)), "hit": false})
			if at > .8 and not gfx.any(func(g): return g.kind == "halo"): _end()
			if at > 6.0: _end()

func _wave() -> void:
	if not alive: return
	var m = _ring_mesh(Color(1, .72, .31), .7)
	m.position = Vector3(global_position.x, .25, global_position.z)
	gfx.append({"kind": "wave", "m": m, "r": 2.0, "x": global_position.x, "z": global_position.z, "hit": false})

func _air_ring(pos: Vector3, c: Color) -> void:
	var m = _ring_mesh(c, .8)
	m.position = pos
	m.rotation.x = PI / 2
	m.look_at(G.player.global_position, Vector3.UP)
	m.rotate_object_local(Vector3.RIGHT, PI / 2)
	gfx.append({"kind": "burst", "m": m, "r": 3.0})

func _ring_mesh(color: Color, op: float) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = .9
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 4
	m.mesh = tm
	m.material_override = _addm(color, op)
	G.world.add_child(m)
	if G.fx: G.fx.ring_overlay(m, color, m.material_override)
	return m

func _gfx(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	for g in gfx:
		match g.kind:
			"wave":
				g.r += 26 * dt
				g.m.scale = Vector3(g.r, 1, g.r)
				g.m.material_override.albedo_color.a = max(0.0, .7 - g.r / 70.0)
				var d = Vector2(p.x - g.x, p.z - g.z).length()
				if not g.hit and p.y < 1.3 and abs(d - g.r) < 1.4:
					g.hit = true
					if G.hurt_player(22): G.player.velocity.y += 9
				if g.r > 62: g.dead = true
			"burst":
				g.r += 60 * dt
				g.m.scale = Vector3.ONE * g.r
				g.m.material_override.albedo_color.a = max(0.0, .8 - g.r / 50.0)
				if g.r > 45: g.dead = true
			"mark":
				g.t -= dt
				g.m.material_override.albedo_color.a = .5 + .4 * sin(g.t * 30)
				var s: float = 2.2 + (.9 - g.t) * .3
				g.m.scale = Vector3(s, 1, s)
				if g.t <= 0:
					g.dead = true
					var sp = MeshInstance3D.new()
					var cm = CylinderMesh.new()
					cm.top_radius = .12; cm.bottom_radius = .35; cm.height = 9; cm.radial_segments = 6
					sp.mesh = cm
					sp.material_override = G.unshaded(Color(1, .94, .75), true)
					G.world.add_child(sp)
					sp.position = Vector3(g.x, g.y + 30, g.z)
					gfx.append({"kind": "spear", "m": sp, "x": g.x, "y": g.y, "z": g.z, "v": 0.0})
			"spear":
				g.v += 200 * dt
				g.m.position.y -= g.v * dt
				if g.m.position.y <= g.y + 4.5:
					g.m.position.y = g.y + 4.5
					g.dead = true
					var q = Vector3(g.x, g.y + .5, g.z)
					G.emit("white", q, 18, 12, .2, .5)
					G.emit("spark", q, 14, 10, .12, .4)
					G.fx.pillar(Vector3(g.x, g.y, g.z), 1.2, 22, _fxc(), .45)
					G.fx.flash(q, _fxc(), 5, .35)
					G.snd("spear", -2)
					G.shake = max(G.shake, .25)
					if Vector2(p.x - g.x, p.z - g.z).length() < 2.4 and abs(p.y - g.y) < 2.5:
						G.hurt_player(25)
					var sm = g.m
					G.later(.25, func(): if is_instance_valid(sm): sm.queue_free())
					g.m = null
			"fissure":
				# fenda que corre pelo chão soltando pilares de luz: desvie para o lado
				var ps = g.s
				g.s += 52 * dt
				while g.next <= g.s and g.next < 90:
					var q = g.o + g.d * g.next
					if abs(q.x) > 43 or abs(q.z) > 43:
						g.next = 999; break
					var y = _ground_y(q.x, q.z)
					var pil = MeshInstance3D.new()
					var bm = BoxMesh.new()
					bm.size = Vector3(.9, 5.5, .9)
					pil.mesh = bm
					pil.material_override = _addm(Color(1, .82, .45), .9)
					G.world.add_child(pil)
					pil.position = Vector3(q.x, y + 2.2, q.z)
					pil.rotation = Vector3(G.rnd(-.25, .25), G.rnd(0, TAU), G.rnd(-.25, .25))
					var tw = pil.create_tween()
					tw.tween_property(pil, "scale", Vector3(.2, 1.4, .2), .45)
					tw.parallel().tween_property(pil.material_override, "albedo_color:a", 0.0, .45)
					tw.tween_callback(pil.queue_free)
					G.emit("dust", Vector3(q.x, y + .3, q.z), 4, 6, .4, .7)
					G.fx.pillar(Vector3(q.x, y, q.z), 1.0, 9, _fxc(), .4)
					G.fx.sprite(Vector3(q.x, y + .08, q.z), "scorch_0%d" % (1 + G.rng.randi() % 3), Color(_fxc().r, _fxc().g, _fxc().b, .8), 1.5, 3.2, .6, 0.0, true, Vector3.UP)
					g.next += 1.7
				var rel = Vector3(p.x - g.o.x, 0, p.z - g.o.z)
				var along = rel.dot(g.d)
				var lat = (rel - g.d * along).length()
				if not g.hit and along > ps - 1.5 and along < g.s + 1.0 and lat < 2.3 and p.y < 3.5:
					g.hit = true
					if G.hurt_player(28.0 if ph2 else 24.0):
						G.player.velocity += Vector3(0, 12, 0) + (rel - g.d * along).normalized() * 8
				if g.s > 92: g.dead = true
			"halo":
				g.t += dt
				g.m.rotation.y += dt * 14
				match g.st:
					"grow":
						var s = min(4.2, .1 + g.t * 7)
						g.m.scale = Vector3(s, 2.5, s)
						g.pos = global_position + Vector3(0, 9, 0) if alive else g.pos
						if g.t > .65:
							g.st = "out"; g.t = 0.0
							var tg = Vector3(p.x, _ground_y(p.x, p.z) + 1.3, p.z)
							var d = tg - g.pos
							var side = Vector3(d.z, 0, -d.x).normalized()
							g.tgt = tg + side * g.side * 9 + Vector3(d.x, 0, d.z).normalized() * 6
							g.from = g.pos
							G.snd("whoosh", -2, .7); G.snd("whirl", -4, .8)
					"out":
						var L = max(1.0, g.from.distance_to(g.tgt))
						var u = min(1.0, g.t * 38.0 / L)
						var e = 1.0 - pow(1.0 - u, 2.0)
						var c = g.from.lerp(g.tgt, e)
						if g.side != 0: c += Vector3(g.tgt.z - g.from.z, 0, -(g.tgt.x - g.from.x)).normalized() * sin(u * PI) * g.side * -6
						g.pos = c
						if u >= 1:
							g.st = "hover"; g.t = 0.0; g.hit = false
					"hover":
						if g.t > .35:
							g.st = "back"; g.t = 0.0
							G.snd("whirl", -6, .9)
					"back":
						var home = global_position + Vector3(0, 9, 0) if alive else g.pos
						var to = home - g.pos
						if to.length() < 3.0 or g.t > 3.0:
							g.dead = true
						else:
							g.pos += to.normalized() * min(to.length(), (30.0 + g.t * 30.0) * dt)
				g.m.position = g.pos
				if G.rng.randf() < .7: G.emit("spark", g.pos + Vector3(G.rnd(-4, 4), 0, G.rnd(-4, 4)), 1, 2, .12, .35, Vector3.ZERO, 0)
				if G.rng.randf() < dt * 30: G.fx.sprite(g.pos + Vector3(cos(g.t * 9) * g.m.scale.x, 0, sin(g.t * 9) * g.m.scale.x), "star_04", _fxc(), 1.2, 2.4, .25)
				# disco horizontal: acerta quem está na altura dele (dá para pular por cima)
				if g.st != "grow" and not g.hit:
					var rel = Vector3(p.x - g.pos.x, 0, p.z - g.pos.z).length()
					var dy = (p.y + .9) - g.pos.y
					if rel < g.m.scale.x + .8 and abs(dy) < 1.4:
						g.hit = true
						if G.hurt_player(24.0 if ph2 else 20.0):
							G.player.velocity += Vector3(p.x - g.pos.x, 0, p.z - g.pos.z).normalized() * 14 + Vector3(0, 6, 0)
	for g in gfx:
		if g.get("dead", false) and g.m != null and is_instance_valid(g.m):
			g.m.queue_free()
	gfx = gfx.filter(func(g): return not g.get("dead", false))


func _fxc() -> Color:
	return Color(1, .22, .12) if ph2 else Color(1, .58, .12)
