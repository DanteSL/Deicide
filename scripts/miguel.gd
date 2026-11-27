extends Node3D
## MIGUEL — o Arcanjo Velado. Quatro braços, asas cobertas de olhos e uma auréola de raios.
## O modelo foi separado em partes (asas, quatro braços, cabeça) e tudo é animado por código.
## Ataques (nenhum repete os de Gabriel ou de Deus):
##   Ceifa dos Quatro Braços · Olhar das Asas · Cruz de Sangue · Corrente de Penitência
##   Passo do Eclipse · Rosário de Sangue · Coroa de Espinhos
## Abaixo de 50% de vida vem o ECLIPSE: o céu escurece, a auréola sangra e ele fica mais rápido.

const MSC := 15.0
const BASE_Y := 0.25
const ATTACKS := ["sweep", "eyes", "cross", "chain", "blink", "rosary", "crown"]
## só no eclipse
const ATTACKS2 := ["blacksun", "reaping"]
# olhos das asas (coordenadas do modelo no Godot, antes da escala) e a asa a que pertencem
const EYES := [["wingR", Vector3(-.21, .85, -.03)], ["wingR", Vector3(-.2, .79, -.03)], ["wingR", Vector3(-.3, .70, -.05)],
	["wingL", Vector3(.24, .845, -.03)], ["wingL", Vector3(.21, .77, -.03)], ["wingL", Vector3(.32, .68, -.05)]]
const HALO_P := Vector3(0, .875, -.035)

var kind = "miguel"
var alive = true
var is_boss = true
var dummy = false
var fly = true
var hp = 5200.0
var max_hp = 5200.0
var r = 4.5
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
var mv = "stalk" # stalk | hold | free
var hover = 0.0

var model: Node3D
var N = {}
var mats = []
var base_col := Color(1, 1, 1)
var eyes = [] # {node, glow}
var halo: MeshInstance3D
var halo_mat: StandardMaterial3D
var halo2: MeshInstance3D
var light: OmniLight3D
var gfx = []
var flinch = 0.0
# poses (A segue T)
var A = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "raise": 0.0, "wind": 0.0, "slam": 0.0, "point": 0.0, "lean": 0.0, "nod": 0.0, "glow": 0.0, "eyes": 0.0, "rise": 0.0, "spin": 0.0}
var T = {"flap": 0.0, "fold": 0.0, "spread": 0.0, "raise": 0.0, "wind": 0.0, "slam": 0.0, "point": 0.0, "lean": 0.0, "nod": 0.0, "glow": 0.0, "eyes": 0.0, "rise": 0.0, "spin": 0.0}
var RATE = {"fold": 4.0, "lean": 6.0}
var swing := 0.0 # golpe dos braços (direto, sem suavizar)
var wph := 0.0

func setup(pos: Vector3) -> void:
	position = Vector3(pos.x, 40.0, pos.z)
	model = load("res://miguel/miguel.glb").instantiate()
	model.scale = Vector3.ONE * MSC
	model.position.y = -.1 * MSC
	add_child(model)
	_index(model)
	var tex_c = load("res://miguel/miguel_cor.jpg") if ResourceLoader.exists("res://miguel/miguel_cor.jpg") else null
	var tex_n = load("res://miguel/miguel_normal.jpg") if ResourceLoader.exists("res://miguel/miguel_normal.jpg") else null
	for mi in _meshes(model):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var m = StandardMaterial3D.new()
			m.albedo_texture = tex_c
			if tex_n:
				m.normal_enabled = true
				m.normal_texture = tex_n
				m.normal_scale = .8
			m.roughness = .7
			m.metallic = 0.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.rim_enabled = true; m.rim = .35; m.rim_tint = .2
			m.emission_enabled = true
			m.emission = Color(.05, .02, .06)
			m.albedo_color = Color(1.25, 1.2, 1.25)
			mi.set_surface_override_material(si, m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mats.append(m)
	base_col = Color(1.05, 1.0, 1.05)
	for nm in N.keys():
		if nm.begins_with("wing") or nm.begins_with("arm") or nm == "head": N[nm].rotation_order = EULER_ORDER_XYZ
	# olhos que brilham nas asas
	for e in EYES:
		var par: Node3D = N.get(e[0], model)
		var o = Node3D.new()
		o.position = e[1] - (par.position if par != model else Vector3.ZERO)
		par.add_child(o)
		var gq = MeshInstance3D.new()
		var q = QuadMesh.new(); q.size = Vector2(.05, .05)
		gq.mesh = q
		var gm = _addm(Color(1, .25, .15), 0.0)
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gm.albedo_texture = _soft_tex()
		gq.material_override = gm
		o.add_child(gq)
		eyes.append({"o": o, "m": gm})
	# auréola de luz por trás da auréola esculpida
	var hn: Node3D = N.get("head", model)
	halo = MeshInstance3D.new()
	var tm = TorusMesh.new(); tm.inner_radius = .088; tm.outer_radius = .1; tm.rings = 64; tm.ring_segments = 6
	halo.mesh = tm
	halo_mat = _addm(Color(1, .8, .45), .65)
	halo.material_override = halo_mat
	halo.position = HALO_P - hn.position + Vector3(0, 0, -.03) # parada, logo atrás da cabeça
	halo.rotation = Vector3(PI / 2, 0, 0)
	hn.add_child(halo)
	halo2 = MeshInstance3D.new()
	var dq = QuadMesh.new(); dq.size = Vector2(.42, .42)
	halo2.mesh = dq
	var hm = _addm(Color(1, .7, .4), .45)
	hm.albedo_texture = _soft_tex()
	halo2.material_override = hm
	halo2.position = HALO_P - hn.position + Vector3(0, 0, -.05)
	hn.add_child(halo2)
	light = OmniLight3D.new()
	light.light_color = Color(1, .75, .5)
	light.omni_range = 26
	light.light_energy = 1.5
	light.position = Vector3(0, .88 * MSC, 3)
	add_child(light)
	# área de acerto
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("enemy", self)
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 4.0
	cap.height = 14.5
	cs.shape = cap
	cs.position = Vector3(0, 7.6, 0)
	body.add_child(cs)
	add_child(body)
	A.fold = 1.0; T.fold = 1.0; T.spread = 0.0
	add_to_group("miguel")
	G.snd("angel", -2, .45)

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
	return global_position + Vector3(0, 8.2, 0)

func is_head(p: Vector3) -> bool:
	return p.y > global_position.y + 11.7

func take_damage(dmg: float, src: String, head: bool) -> bool:
	if not alive or inv: return false
	hp -= dmg * (1.25 if head else 1.0)
	flash = .09
	if dmg >= 40: flinch = min(1.0, flinch + dmg / 150.0)
	if hp <= 0:
		die(src, head)
		return true
	return false

# ---------------- morte ----------------
func die(src: String, _head: bool) -> void:
	alive = false
	dying = true
	die_t = 0.0
	G.boss = null
	G.stats.kills += 1
	G.add_style(320, "MIGUEL ABATIDO")
	for g in gfx:
		if is_instance_valid(g.get("m")): g.m.queue_free()
	gfx.clear()
	ad = {"src": src}
	G.main.hitstop(.35)
	G.snd("clang", 0, .5)
	G.snd("angel", -2, .4)
	for i in 12:
		G.later(.2 + i * .18, func():
			if not is_instance_valid(self): return
			var c = global_position + Vector3(G.rnd(-4, 4), G.rnd(2, 10), G.rnd(-2, 2))
			G.blast(c, .4, src)
			G.emit("blood2", c, 24, 14, .3, 1.0))

func _upd_death(dt: float) -> void:
	die_t += dt
	var k = min(1.0, die_t / 2.4)
	T.fold = .6 * k; T.raise = .9 * k; T.slam = 0.0; T.spread = 1.0 - k; T.lean = -.4 * k; T.nod = -.6 * k; T.eyes = 1.0; T.glow = 1.0
	_anim(dt * (1.0 - k * .6))
	model.position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), 0) * .12 * k
	for m in mats:
		m.albedo_color = base_col * (1.0 + (2.0 if G.rng.randf() < .3 else .4) * k)
	if die_t >= 2.4 and not fired.has("boom"):
		fired.boom = true
		G.blast(center(), 1.5, ad.get("src", "parry"))
		G.emit("blood2", center(), 120, 30, .4, 1.6)
		G.emit("white", center(), 60, 26, .3, 1.2)
		G.flash = 1.0
		G.main.banner("ARCANJO ABATIDO", "O VÉU SE RASGA" if G.mode == "miguel" else "")
		for m in mats: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if G.main.has_method("respawn_miguel") and G.mode == "miguel":
			G.later(9.0, G.main.respawn_miguel)
	if die_t >= 2.4:
		var f = clamp((die_t - 2.4) / 1.0, 0.0, 1.0)
		for m in mats: m.albedo_color = Color(2.0, .4, .4, 1.0 - f)
		model.scale = Vector3.ONE * MSC * (1 + f * .1)
		if f >= 1: queue_free()

# ---------------- animação ----------------
func _anim(dt: float) -> void:
	for key in A.keys():
		A[key] += (T[key] - A[key]) * (1.0 - exp(-RATE.get(key, 6.0) * dt))
	flinch *= exp(-7 * dt)
	var pw = wph
	wph += dt * (1.6 + A.flap * 4.0) * (1.0 - A.fold * .6)
	if floor(pw / TAU) != floor(wph / TAU) and A.flap > .4:
		G.snd("flapbig", -10 + A.flap * 4, .7)
	var s = sin(wph)
	var fold: float = A.fold
	var amp: float = (.07 + A.flap * .3) * (1.0 - fold * .7)
	for side in [1.0, -1.0]:
		var w: Node3D = N.get("wingL" if side > 0 else "wingR")
		if w:
			w.rotation = Vector3(sin(wph + .5) * .04,
				side * (fold * .85 - A.spread * .15 - flinch * .2),
				side * (amp * s + A.spread * .18 - fold * .25 + flinch * .1))
	# braços: balanço de dedos/garras + poses de ataque
	var ph = phase
	var sw = swing
	for side in [1.0, -1.0]:
		var nmU = "armUL" if side > 0 else "armUR"
		var nmD = "armDL" if side > 0 else "armDR"
		var au: Node3D = N.get(nmU)
		var ab: Node3D = N.get(nmD)
		var pnt = A.point if side < 0 else 0.0
		if au:
			au.rotation = Vector3(sin(ph * 1.3 + side) * .04,
				side * (A.wind * .9 - sw * 1.5) + sin(ph * .9 + side * 2) * .05 - pnt * side * 1.25,
				side * (A.raise * .85 - A.slam * .55 + sin(ph * 1.1 + side) * .05) + pnt * .15)
		if ab:
			ab.rotation = Vector3(sin(ph * 1.5 + side * 3) * .05,
				side * (A.wind * .7 - sw * 1.3) + sin(ph * 1.2 + side) * .06,
				side * (A.raise * .55 - A.slam * .75 + sin(ph * 1.4 + side * 2) * .06))
	var hd: Node3D = N.get("head")
	if hd:
		hd.rotation = Vector3(A.nod * .5 + sin(ph * .7) * .04, sin(ph * .5) * .08, sin(ph * .6) * .04 + flinch * G.rnd(-.1, .1))
	model.position.y = -.1 * MSC + sin(ph * 1.2) * .25 + A.rise
	model.rotation = Vector3(A.lean - flinch * .25, A.spin, sin(ph * .8) * .02 + flinch * G.rnd(-.05, .05))
	# olhos, auréola e luz
	for e in eyes:
		e.m.albedo_color.a = A.eyes * (.75 + .25 * sin(ph * 9 + e.o.position.x * 40))
		e.o.scale = Vector3.ONE * (1.0 + A.eyes * 1.6)
	var hc = Color(1, .8, .45) if not ph2 else Color(1, .2, .15)
	halo_mat.albedo_color = Color(hc.r, hc.g, hc.b, .45 + A.glow * .5)
	(halo2.material_override as StandardMaterial3D).albedo_color = Color(hc.r, hc.g, hc.b, .25 + A.glow * .5)
	halo2.scale = Vector3.ONE * (1.0 + A.glow * .6 + sin(ph * 3) * .03)
	light.light_color = hc
	light.light_energy = 1.2 + A.glow * 3.5
	if not dying:
		for m in mats:
			m.albedo_color = base_col * 1.9 if flash > 0 else base_col

# ---------------- movimento ----------------
func _move(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var d = to.length()
	if mv == "stalk":
		var want = 17.0
		var spd = (5.5 if ph2 else 4.0)
		if d > want + 2: global_position += to.normalized() * min(spd * dt, d - want)
		elif d < want - 4: global_position -= to.normalized() * spd * .6 * dt
		var side = to.normalized().cross(Vector3.UP)
		global_position += side * sin(phase * .4) * 2.0 * dt
	if mv != "free":
		global_position.y += (BASE_Y + hover - global_position.y) * (1.0 - exp(-3.0 * dt))
	var lim = 40.0
	var hp2 = Vector2(global_position.x, global_position.z)
	if hp2.length() > lim:
		hp2 = hp2.normalized() * lim
		global_position.x = hp2.x; global_position.z = hp2.y
	if mv != "free" or att == "blink":
		var want_a = atan2(p.x - global_position.x, p.z - global_position.z)
		rotation.y = lerp_angle(rotation.y, want_a, 1.0 - exp(-(8.0 if att in ["chain", "sweep"] else 3.5) * dt))

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
		global_position.y = lerp(40.0, BASE_Y, 1.0 - pow(1.0 - min(1.0, u * 1.25), 3.0))
		if u > .8 and not fired.has("land"):
			fired.land = true
			T.fold = 0.0; T.spread = 1.0; T.flap = 1.2; T.raise = .8; T.glow = 1.0; T.eyes = 1.0; T.nod = -.4; RATE.fold = 10.0
			G.snd("slam", 0, .7); G.snd("angel", 0, .5); G.snd("flapbig", 0, .6)
			G.shake = max(G.shake, 1.0); G.flash = max(G.flash, .5)
			G.emit("dust", Vector3(global_position.x, .4, global_position.z), 70, 24, .5, 1.4)
			_wave(Color(.9, .2, .25))
		_anim(dt)
		_gfx(dt)
		if spawn_t <= 0:
			fired.clear(); _relax()
		return
	flash -= dt
	if ph2 and G.rng.randf() < dt * 6.0:
		G.fx.smoke(center() + Vector3(G.rnd(-4, 4), G.rnd(-4, 3), G.rnd(-2, 2)), Color(.1, 0, .02, .6), 1, 5.0, 2.0, 3.0)
	if ph2 and G.rng.randf() < dt * 10.0:
		G.emit("blood2", center() + Vector3(G.rnd(-6, 6), G.rnd(-2, 4), G.rnd(-1, 1)), 1, 1, .18, 1.0, Vector3.ZERO, 14)
	if not ph2 and hp < max_hp * .5 and att != "eclipse":
		_attack("eclipse")
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
	var w = {"sweep": 1.0, "eyes": 1.0, "cross": 1.0, "chain": 1.0, "blink": 1.0, "rosary": 1.0, "crown": 1.0}
	if d < 14: w.sweep += 1.4; w.crown += .4
	else: w.chain += .8; w.eyes += .6; w.blink += .5
	if p.y > 4: w.eyes += .8; w.chain += .5
	if ph2: w.rosary += .5; w.blink += .4; w.blacksun = 1.3; w.reaping = 1.3
	w.erase(last_att)
	var tot = 0.0
	for k in w: tot += w[k]
	var x = G.rng.randf() * tot
	for k in w:
		x -= w[k]
		if x <= 0: return k
	return "eyes"

func _once(k: String, t: float) -> bool:
	if at >= t and not fired.has(k):
		fired[k] = true
		return true
	return false

func _relax() -> void:
	T.flap = 0.0; T.fold = 0.0; T.spread = 0.0; T.raise = 0.0; T.wind = 0.0; T.slam = 0.0; T.point = 0.0
	T.lean = 0.0; T.nod = 0.0; T.glow = .3 if ph2 else 0.0; T.eyes = .35 if ph2 else 0.0; T.rise = 0.0; T.spin = 0.0
	RATE.fold = 4.0; RATE.lean = 6.0
	swing = 0.0
	hover = 0.0

func _attack(k: String) -> void:
	if att != "" and k != "eclipse": return
	if att != "": _end(false)
	att = k
	at = 0.0
	fired.clear()
	ad = {}
	mv = "stalk"
	# toda habilidade começa com um aviso de carga no chefe
	if G.fx:
		var big = k == "eclipse"
		G.fx.charge(center(), (Color(1, .12, .18) if ph2 else Color(1, .75, .55)), 1.2 if big else .65, 6.0 * (2.0 if big else 1.0), (G.player.global_position - global_position).normalized())
	match k:
		"eclipse":
			inv = true; mv = "hold"; hover = 5.0
			T.spread = 1.0; T.raise = 1.0; T.glow = 1.0; T.eyes = 1.0; T.nod = -.6; T.flap = 1.0; T.lean = -.2
			G.main.banner("ECLIPSE", "MIGUEL SE LIBERTA")
			G.snd("angel", 0, .35); G.snd("charge", -4, .4)
		"sweep":
			T.wind = 1.0; T.raise = .25; T.lean = .15; T.glow = .6
			G.snd("whoosh", -6, .6)
		"eyes":
			mv = "hold"; T.spread = 1.0; T.flap = .4; T.eyes = 1.0; T.raise = .3; T.nod = .2
			ad.n = 5 if ph2 else 3; ad.k = 0
			G.snd("charge", -6, .8)
		"cross":
			mv = "hold"; T.raise = 1.0; T.glow = .8; T.nod = -.3
			G.snd("charge", -4, .6)
		"chain":
			mv = "hold"; T.point = 1.0; T.lean = .1; T.glow = .5
			ad.aim = G.player.global_position + Vector3(0, 1, 0)
			G.snd("beep", -8, .5)
		"blink":
			mv = "free"; T.fold = 1.0; T.raise = 1.0; T.glow = 1.0
			G.snd("whoosh", -2, .4)
		"rosary":
			mv = "hold"; hover = 4.0; T.spread = 1.0; T.raise = .7; T.glow = 1.0; T.flap = .6
			G.snd("whirl", -2, .5)
		"crown":
			mv = "hold"; T.slam = 1.0; T.lean = .3; T.nod = .4
			G.snd("charge", -6, .5)
		"blacksun":
			mv = "hold"; hover = 6.0; T.raise = 1.0; T.spread = 1.0; T.glow = 1.0; T.eyes = 1.0; T.nod = -.5
			G.main.banner("SOL NEGRO", "")
			G.snd("angel", -2, .3); G.snd("charge", -4, .3)
		"reaping":
			mv = "hold"; T.wind = 1.0; T.glow = 1.0; T.lean = .2
			G.main.banner("CEIFA CARMESIM", "")
			G.snd("whoosh", -4, .5)

func _end(set_cd := true) -> void:
	last_att = att
	att = ""
	inv = false
	mv = "stalk"
	_relax()
	if set_cd:
		cd = 1.3 if ph2 else 2.3
		if ph2 and G.rng.randf() < .3: cd = .4

func _player_c() -> Vector3:
	return G.player.global_position + Vector3(0, .9, 0)

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.length_squared(), .0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _ground_y(x: float, z: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 6, z), Vector3(x, -2, z), 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else 0.0

func _hand(nm: String) -> Vector3:
	var a: Node3D = N.get(nm)
	if a == null: return center()
	var side = 1.0 if nm.ends_with("L") else -1.0
	return a.to_global(Vector3(side * .2, -.02, .02))

func _orb(p0: Vector3, vel: Vector3, col := Color(.85, .1, .25)) -> void:
	G.main.spawn_orb(p0, vel)
	var pr = G.projs[G.projs.size() - 1]
	pr.mat.albedo_color = col

# ---------------- coreografia ----------------
func _run_attack(dt: float) -> void:
	var p = G.player.global_position
	var pc = _player_c()
	match att:
		"eclipse":
			G.shake = max(G.shake, .12)
			if G.rng.randf() < dt * 30: G.emit("blood2", center() + Vector3(G.rnd(-5, 5), G.rnd(-4, 5), G.rnd(-2, 2)), 3, 6, .25, .8, Vector3(0, 6, 0), -3)
			var arena = G.main.get("miguel_arena")
			if arena: arena.eclipse = clamp(at / 2.0, 0.0, 1.0)
			if _once("burst", 2.0):
				ph2 = true
				base_col = Color(1.1, .9, .95)
				G.flash = 1.0; G.shake = max(G.shake, 1.2)
				G.snd("boom", 0, .6); G.snd("angel", 0, .35)
				G.emit("blood2", center(), 140, 36, .4, 1.6)
				var push = (p - global_position); push.y = 0
				G.player.velocity += push.normalized() * 20 + Vector3(0, 7, 0)
				_wave(Color(1, .15, .2))
				G.fx.flash(center(), Color(1, .1, .15), 28, .9)
				G.fx.ring_v(center(), (p - global_position).normalized(), Color(1, .12, .18), 22, 1.0)
				G.fx.shock(Vector3(global_position.x, 0, global_position.z), Color(1, .08, .12), 36, 1.2)
				G.fx.smoke(center(), Color(.12, 0, .02, .7), 14, 10, 2.4, 3.0)
				if G.main.has_method("miguel_eclipse"): G.main.miguel_eclipse()
			if at > 3.0: _end()
		"sweep":
			# avança, puxa os quatro braços para trás e ceifa duas vezes (pule!)
			if at < .7:
				var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
				if to.length() > 9.0: global_position += to.normalized() * min(to.length() - 9.0, 26 * dt)
			for i in 2:
				var t0 = .85 + i * .65
				if at > t0 - .25 and at < t0:
					T.wind = -1.0 if i % 2 else 1.0
					if G.rng.randf() < dt * 30: G.emit("blood", _hand("armUL" if i == 0 else "armUR"), 2, 3, .15, .4)
				if _once("cut%d" % i, t0):
					ad.sw = i
					ad.st = at
					G.snd("whoosh", 0, .8); G.snd("clang", -10, .6)
					G.shake = max(G.shake, .35)
					var dir = (-global_transform.basis.z).normalized() * -1.0 # frente do modelo = +Z
					dir = global_transform.basis.z.normalized()
					var o = global_position + Vector3(0, .9, 0)
					var side = 1.0 if i == 0 else -1.0
					for k in 13:
						var a0 = -1.1 + k * (2.2 / 12.0)
						var a1 = a0 + 2.2 / 12.0
						var d0 = dir.rotated(Vector3.UP, a0 * side)
						var d1 = dir.rotated(Vector3.UP, a1 * side)
						G.tracer(o + d0 * 13.5, o + d1 * 13.5, .45, Color(1, .15, .2), .25 + k * .01)
						G.tracer(o + d0 * 10.5, o + d1 * 10.5, .25, Color(1, .6, .5), .2)
					G.fx.slash(o + dir * 6.0 + Vector3(0, .4, 0), dir.rotated(Vector3.UP, 0.0), 26, Color(1, .12, .16, 1), .35, "slash_04")
					G.fx.slash(o + dir * 6.0 + Vector3(0, .5, 0), dir, 20, Color(1, .8, .7, .8), .25, "slash_03")
					G.fx.burst(o + dir * 8, Color(.7, 0, .05), 18, 14, .9, .6, "circle_05", 20.0, true)
					var rel = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
					if rel.length() < 14.5 and rel.normalized().dot(dir) > -.2 and p.y - global_position.y < 2.0:
						if G.hurt_player(26.0 if ph2 else 22.0):
							G.player.velocity += rel.normalized() * 16 + Vector3(0, 6, 0)
			if ad.has("st"):
				var u = clamp((at - ad.st) / .22, 0.0, 1.0)
				swing = (u * 2.0 - 1.0) * (1.0 if ad.sw == 0 else -1.0)
				T.wind = 0.0
			if at > 2.25: _end()
		"eyes":
			# os olhos das asas abrem e disparam rajadas (dá para devolver com o soco)
			if ad.k < ad.n and at > .7 + ad.k * .45:
				ad.k += 1
				G.snd("beam", -10, 1.6)
				T.flap = 1.0
				for e in eyes:
					var o: Vector3 = e.o.global_position
					var tg = pc + G.player.velocity * .25 + Vector3(G.rnd(-1.5, 1.5), G.rnd(-.5, .8), G.rnd(-1.5, 1.5))
					_orb(o, (tg - o).normalized() * (24.0 if ph2 else 19.0))
					G.emit("blood", o, 4, 6, .15, .3)
					G.fx.flash(o, Color(1, .2, .25), 2.6, .25)
			if at > .7 + ad.n * .45 + .5: _end()
		"cross":
			# cruz de gêiseres de sangue centrada no jogador; na fase 2, também em X
			if _once("mark", .6):
				T.slam = 1.0; T.raise = 0.0; T.lean = .3
				G.snd("slam", -4, .8)
				G.shake = max(G.shake, .4)
				var c = Vector3(p.x, 0, p.z)
				var dirs = [Vector3(1, 0, 0), Vector3(0, 0, 1)]
				if ph2: dirs += [Vector3(1, 0, 1).normalized(), Vector3(1, 0, -1).normalized()]
				var rot = G.rnd(0, PI)
				G.fx.shock(Vector3(c.x, _ground_y(c.x, c.z), c.z), Color(1, .1, .15), 6, .5)
				for d in dirs:
					var dd: Vector3 = d.rotated(Vector3.UP, rot)
					for k in range(-9, 10):
						var q = c + dd * k * 2.2
						if Vector2(q.x, q.z).length() > 44: continue
						_geyser_mark(q, .95 + abs(k) * .03)
			if at > 2.2: _end()
		"chain":
			# corrente: mira, trava e dispara; se pegar, puxa e esmaga
			var hand = _hand("armUR")
			var tl = .95
			if at < tl:
				ad.aim = ad.aim.lerp(pc + G.player.velocity * .15, 1.0 - exp(-6 * dt))
				G.tracer(hand, ad.aim, .04, Color(1, .2, .2), .04)
			elif at < tl + .25:
				if int(at * 30) % 2 == 0: G.tracer(hand, ad.aim, .1, Color(1, .9, .8), .035)
				if _once("lock", tl): G.snd("beep", -4, .9)
			if _once("fire", tl + .25):
				var dir = (ad.aim - hand).normalized()
				var end = hand + dir * 48.0
				var q = PhysicsRayQueryParameters3D.create(hand, end, 1)
				var hit = get_world_3d().direct_space_state.intersect_ray(q)
				if hit: end = hit.position
				G.snd("clang", -2, .7)
				for k in 24:
					var a = hand.lerp(end, k / 24.0)
					var b = hand.lerp(end, (k + .7) / 24.0)
					G.tracer(a, b, .22, Color(.8, .7, .6), .35)
				G.fx.beam(hand, end, .7, Color(1, .2, .2), .35)
				G.fx.flash(hand, Color(1, .3, .3), 4, .3)
				if _seg_dist(pc, hand, end) < 1.6:
					ad.grab = true
					ad.gt = at
					G.snd("hit", 0, .6)
					G.fx.flash(pc, Color(1, .3, .3), 5, .4)
					G.main.banner("", "PRESO NA CORRENTE")
			if ad.get("grab", false):
				var hand2 = _hand("armUR")
				var to = hand2 - pc
				G.tracer(hand2, pc, .2, Color(.8, .7, .6), .03)
				G.player.velocity = to.normalized() * min(34.0, to.length() * 6.0)
				if to.length() < 4.0 or at - ad.gt > .9:
					ad.grab = false
					T.point = 0.0; T.slam = 1.0
					G.snd("slam", 0, .9); G.shake = max(G.shake, .8)
					G.emit("blood2", pc, 30, 14, .25, .8)
					G.fx.shock(Vector3(pc.x, _ground_y(pc.x, pc.z), pc.z), Color(1, .15, .2), 10, .5)
					G.fx.flash(pc, Color(1, .25, .25), 8, .4)
					if G.hurt_player(30.0 if ph2 else 24.0):
						var back = (pc - global_position); back.y = 0
						G.player.velocity = back.normalized() * 22 + Vector3(0, 10, 0)
					ad.done = at + .5
			elif fired.has("fire") and not ad.has("done"):
				ad.done = at + .6
			if ad.has("done") and at > ad.done: _end()
		"blink":
			# some em sombra, reaparece no alto atrás do jogador e esmaga com os quatro braços
			if _once("vanish", .45):
				G.emit("blood2", center(), 50, 14, .35, .8)
				G.fx.smoke(center(), Color(.08, 0, .02, .8), 10, 8, 1.4, 2.0)
				G.fx.flash(center(), Color(1, .1, .15), 12, .4)
				G.snd("whoosh", 0, .3)
				model.visible = false
				inv = true
				var back = Vector3(-sin(G.player.yaw), 0, -cos(G.player.yaw)) * -7.0
				ad.dest = Vector3(p.x, 0, p.z) + back
				ad.dest.x = clamp(ad.dest.x, -38.0, 38.0); ad.dest.z = clamp(ad.dest.z, -38.0, 38.0)
				ad.ring = _ring_mesh(Color(1, .15, .2), .8)
				ad.ring.position = Vector3(ad.dest.x, .08, ad.dest.z)
				ad.ring.scale = Vector3(8, 1, 8)
				G.fx.sigil(Vector3(ad.dest.x, _ground_y(ad.dest.x, ad.dest.z), ad.dest.z), 8.0, Color(1, .1, .15), 1.0, 0)
			if at > .45 and at < 1.15 and ad.has("ring"):
				ad.ring.material_override.albedo_color.a = .4 + .4 * sin(at * 40)
			if _once("appear", 1.15):
				global_position = ad.dest + Vector3(0, 14, 0)
				model.visible = true
				inv = false
				ad.vy = 0.0
				G.snd("angel", -4, .6)
			if fired.has("appear") and not fired.has("land"):
				ad.vy -= 120 * dt
				global_position.y += ad.vy * dt
				T.slam = 1.0; T.raise = 0.0
				if global_position.y <= BASE_Y:
					global_position.y = BASE_Y
					fired.land = true
					ad.lt = at
					if is_instance_valid(ad.get("ring")): ad.ring.queue_free()
					G.snd("slam", 0); G.snd("boom", -2, .7)
					G.shake = max(G.shake, 1.1); G.flash = max(G.flash, .3)
					var gp = Vector3(global_position.x, .4, global_position.z)
					G.emit("dust", gp, 60, 22, .5, 1.3)
					G.emit("blood2", gp, 40, 18, .25, .9)
					G.fx.shock(gp, Color(1, .1, .15), 16, .7)
					G.fx.flash(gp + Vector3(0, 2, 0), Color(1, .2, .2), 14, .45)
					G.main.world_flash(gp, 16)
					_wave(Color(1, .2, .25))
					var dd = Vector2(p.x - gp.x, p.z - gp.z).length()
					if dd < 8.0 and G.hurt_player(30.0 if ph2 else 25.0):
						G.player.velocity += Vector3(p.x - gp.x, 0, p.z - gp.z).normalized() * 18 + Vector3(0, 9, 0)
			if fired.has("land") and at > ad.lt + .9: _end()
			if at > 4.0: _end()
		"rosary":
			# rosário de sangue: espiral de contas girando para fora
			T.spin = sin(at * 2.0) * .3
			var arms = 4 if ph2 else 3
			if _once("rs", .5):
				G.fx.sprite(global_position + Vector3(0, 1.4 + hover * .2, 0), "twirl_02", Color(1, .1, .2, .9), 4, 14, 2.6, 3.0, true, Vector3.UP, false)
				G.fx.sprite(global_position + Vector3(0, 1.5 + hover * .2, 0), "magic_02", Color(1, .2, .3, .8), 6, 10, 2.6, -1.5, true, Vector3.UP, false)
			if at > .6 and at < 3.0:
				ad.acc = ad.get("acc", 0.0) + dt
				while ad.acc > .085:
					ad.acc -= .085
					ad.a = ad.get("a", 0.0) + .23
					for k in arms:
						var a = ad.a + k * TAU / arms
						var dir = Vector3(cos(a), 0, sin(a))
						var o = global_position + Vector3(0, 1.4 + hover * .2, 0) + dir * 2.5
						_orb(o, dir * (15.0 if ph2 else 12.0) + Vector3(0, -.6, 0), Color(.75, .05, .12))
					G.snd("ping", -18, 1.4)
			if at > 3.4: _end()
		"blacksun":
			# SOL NEGRO: o sol do eclipse persegue você com um selo; quando trava, um raio desce do céu
			var sun: Vector3 = Vector3(0, 95, -210)
			var arena = G.main.get("miguel_arena")
			if arena and arena.get("sun"): sun = arena.sun.global_position
			for k in 5:
				var t0 = .6 + k * .75
				if at > t0 - .7 and at < t0:
					ad["c%d" % k] = ad.get("c%d" % k, Vector3(p.x, 0, p.z)).lerp(Vector3(p.x, 0, p.z), 1.0 - exp(-5.0 * dt))
					if G.rng.randf() < dt * 20: G.tracer(sun, ad["c%d" % k], .12, Color(1, .1, .12, .5), .05)
				if _once("s%d" % k, t0 - .7):
					ad["c%d" % k] = Vector3(p.x, 0, p.z)
					var cc: Vector3 = ad["c%d" % k]
					ad["sg%d" % k] = G.fx.sigil(Vector3(cc.x, _ground_y(cc.x, cc.z), cc.z), 3.5, Color(1, .05, .1), .9, 0)
				if ad.has("sg%d" % k) and is_instance_valid(ad["sg%d" % k]) and at < t0:
					var cc2: Vector3 = ad["c%d" % k]
					ad["sg%d" % k].global_position = Vector3(cc2.x, _ground_y(cc2.x, cc2.z) + .09, cc2.z)
				if _once("hit%d" % k, t0):
					var c: Vector3 = ad["c%d" % k]
					var gy = _ground_y(c.x, c.z)
					var gq = Vector3(c.x, gy, c.z)
					G.fx.beam(sun, gq, 4.0, Color(1, .06, .1), .5)
					G.fx.pillar(gq, 3.0, 60, Color(1, .1, .12), .5)
					G.fx.flash(gq + Vector3(0, 1, 0), Color(1, .15, .15), 14, .5)
					G.fx.shock(gq, Color(1, .1, .12), 10, .6)
					G.emit("blood2", gq + Vector3(0, .5, 0), 24, 14, .25, .8)
					G.snd("beam", -2, .6); G.snd("boom", -6, .8); G.shake = max(G.shake, .6)
					if Vector2(p.x - c.x, p.z - c.z).length() < 3.6 and p.y - gy < 6.0:
						if G.hurt_player(24.0): G.player.velocity += Vector3(p.x - c.x, 0, p.z - c.z).normalized() * 12 + Vector3(0, 9, 0)
			if at > 4.6: _end()
		"reaping":
			# CEIFA CARMESIM: três ondas de corte em arco correm pelo chão; a alta você desliza, a baixa você pula
			for k in 3:
				var t0 = .7 + k * .7
				if _once("r%d" % k, t0):
					var dir = Vector3(p.x - global_position.x, 0, p.z - global_position.z).normalized()
					var high = k == 1
					var m = MeshInstance3D.new(); var q = QuadMesh.new(); q.size = Vector2(16, 8); m.mesh = q
					m.material_override = G.fx.mat("slash_04", Color(1, .1, .15, 1), true, 0)
					G.world.add_child(m)
					var y0 = _ground_y(global_position.x, global_position.z) + (2.6 if high else .9)
					m.global_position = Vector3(global_position.x, y0, global_position.z) + dir * 3.0
					m.basis = Basis.looking_at(dir, Vector3.UP)
					var core = MeshInstance3D.new(); core.mesh = q
					core.material_override = G.fx.mat("slash_03", Color(1, .85, .8, .9), true, 0)
					core.scale = Vector3(.7, .5, 1); m.add_child(core)
					gfx.append({"kind": "reap", "m": m, "dir": dir, "t": 0.0, "hit": false, "high": high, "y": y0})
					G.snd("whoosh", 0, .7 + k * .1); G.snd("clang", -12, .5)
					T.wind = -1.0 if k % 2 else 1.0
					swing = 1.0 if k % 2 else -1.0
			if at > 3.4: _end()
		"crown":
			# coroa de espinhos: anel de espinhos se fecha no jogador (pule por cima)
			if _once("ring", .55):
				G.snd("slam", -4, .7)
				G.shake = max(G.shake, .35)
				gfx.append({"kind": "crown", "c": Vector3(p.x, 0, p.z), "r": 13.0, "spikes": [], "hit": false, "t": 0.0})
				G.fx.sigil(Vector3(p.x, _ground_y(p.x, p.z), p.z), 13.0, Color(1, .1, .15, .7), 1.8, 1)
			if at > 2.4: _end()

# ---------------- efeitos ----------------
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

func _wave(c: Color) -> void:
	var m = _ring_mesh(c, .7)
	m.position = Vector3(global_position.x, .25, global_position.z)
	gfx.append({"kind": "wave", "m": m, "r": 2.0, "x": global_position.x, "z": global_position.z, "hit": false})

func _geyser_mark(q: Vector3, delay: float) -> void:
	var y = _ground_y(q.x, q.z)
	var mk = _ring_mesh(Color(1, .1, .15), .8)
	mk.position = Vector3(q.x, y + .06, q.z)
	mk.scale = Vector3(1.3, 1, 1.3)
	gfx.append({"kind": "gmark", "m": mk, "x": q.x, "y": y, "z": q.z, "t": delay})
	G.fx.sigil(Vector3(q.x, y, q.z), 1.5, Color(1, .08, .12), delay + .15, 1)

func _geyser(x: float, y: float, z: float) -> void:
	var sp = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = .25; cm.bottom_radius = .7; cm.height = 6.0; cm.radial_segments = 7
	sp.mesh = cm
	sp.material_override = preload("res://scripts/ceu_mats.gd").blood()
	G.fx.pillar(Vector3(x, y, z), .9, 9, Color(.9, .06, .08), .5)
	G.fx.burst(Vector3(x, y + 1, z), Color(.55, 0, .02), 10, 10, .8, .8, "circle_05", 22.0, true)
	G.world.add_child(sp)
	sp.position = Vector3(x, y - 3.0, z)
	gfx.append({"kind": "geyser", "m": sp, "y": y, "t": 0.0})
	G.emit("blood2", Vector3(x, y + .5, z), 10, 12, .2, .7, Vector3(0, 1, 0), 25)

func _gfx(dt: float) -> void:
	var p: Vector3 = G.player.global_position
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
			"reap":
				g.t += dt
				g.m.global_position += g.dir * 30.0 * dt
				g.m.scale = Vector3.ONE * (1.0 + g.t * .6)
				g.m.material_override.albedo_color.a = 1.0 - clamp((g.t - 1.2) / .4, 0.0, 1.0)
				if G.rng.randf() < dt * 30: G.emit("blood2", g.m.global_position + Vector3(G.rnd(-4, 4), -.5, 0), 2, 4, .2, .4)
				var rel = p - g.m.global_position
				var side = g.dir.cross(Vector3.UP)
				if not g.hit and abs(rel.dot(g.dir)) < 1.2 and abs(rel.dot(side)) < 8.0 * g.m.scale.x:
					var py = p.y - (g.y - (2.6 if g.high else .9))
					# alta: acerta quem está em pé (deslize por baixo); baixa: acerta quem está no chão (pule)
					var hit = (py > .8) if g.high else (py < 1.4)
					if g.high and G.player.get("sliding") == true: hit = false
					if hit:
						g.hit = true
						if G.hurt_player(20.0): G.player.velocity += g.dir * 12 + Vector3(0, 6, 0)
				if g.t > 1.6: g.dead = true
			"gmark":
				g.t -= dt
				g.m.material_override.albedo_color.a = .45 + .4 * sin(g.t * 30)
				if g.t <= 0:
					g.dead = true
					_geyser(g.x, g.y, g.z)
					if Vector2(p.x - g.x, p.z - g.z).length() < 1.6 and p.y - g.y < 4.0:
						if G.hurt_player(18.0 if ph2 else 15.0): G.player.velocity.y += 11
			"geyser":
				g.t += dt
				var u: float = g.t / .7
				var hgt: float = sin(clamp(u, 0.0, 1.0) * PI)
				g.m.position.y = g.y - 3.0 + hgt * 5.5
				g.m.scale = Vector3(1.0 - u * .4, 1, 1.0 - u * .4)
				if u >= 1: g.dead = true
			"crown":
				g.t += dt
				if g.spikes.is_empty():
					for k in 28:
						var sp = MeshInstance3D.new()
						var cm = CylinderMesh.new()
						cm.top_radius = 0.0; cm.bottom_radius = .45; cm.height = 1.8; cm.radial_segments = 5
						sp.mesh = cm
						sp.material_override = G.unshaded(Color(.55, .03, .06))
						G.world.add_child(sp)
						G.fx.attach_glow(sp, Color(1, .1, .15, .7), 2.0, false, "flame_05")
						g.spikes.append({"m": sp, "a": k * TAU / 28.0})
					G.snd("spear", -6, .6)
				# o anel cresce do chão e depois se fecha
				var rise: float = clamp(g.t / .35, 0.0, 1.0)
				if g.t > .55: g.r = max(0.0, g.r - (16.0 if ph2 else 12.0) * dt)
				for s in g.spikes:
					var q = g.c + Vector3(cos(s.a + g.t * .4), 0, sin(s.a + g.t * .4)) * g.r
					s.m.position = Vector3(q.x, -1.0 + rise * 1.85, q.z)
					if G.rng.randf() < dt * 3: G.emit("blood2", s.m.position + Vector3(0, .8, 0), 1, 3, .18, .5)
				var dd = Vector2(p.x - g.c.x, p.z - g.c.z).length()
				if not g.hit and g.t > .55 and abs(dd - g.r) < .9 and p.y < 1.6:
					g.hit = true
					if G.hurt_player(22.0 if ph2 else 18.0): G.player.velocity.y += 10
				if g.r <= .1 or g.t > 3.0:
					g.dead = true
					for s in g.spikes: s.m.queue_free()
					G.emit("blood2", g.c + Vector3(0, .5, 0), 30, 14, .25, .8)
					G.fx.flash(g.c + Vector3(0, 1, 0), Color(1, .15, .2), 8, .4)
					G.fx.shock(g.c, Color(1, .1, .15), 6, .4)
	for g in gfx:
		if g.get("dead", false) and g.kind != "crown" and is_instance_valid(g.get("m")): g.m.queue_free()
	gfx = gfx.filter(func(g): return not g.get("dead", false))
