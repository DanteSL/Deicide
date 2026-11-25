extends Node
## Armas extras: espadas aladas (Força), lança-foguetes, pregadora, fuzil de raio, arpão e lança-granadas.
## Cada uma tem modelo em primeira pessoa, projéteis no mundo, botão direito próprio e 3 melhorias.

var W: Node # weapons.gd
var root: Node3D
var models = {}

# estado
var sw = [] # espadas
var sword_cd = 0.0
var force_t = 1.0
var hands: Node3D
var rockets = []
var guiding = null
var rk_t = 1.0
var rk_l = true
var nails = []
var heat = 0.0
var over = 0.0
var nl_spin = 0.0
var nl_firing = 0.0
var rail_max = 1.4
var zb = 0.0
var harps = []
var hp_t = 1.0
var grens = []
var drum2_t = 0.0
var drum2_a = 0.0

const SLOTS := [Vector3(-.21, -.1, -.55), Vector3(.21, -.1, -.55), Vector3(-.31, .04, -.62), Vector3(.31, .04, -.62)]
const LABEL := {"sword": "ESPADA ALADA", "rocket": "FOGUETE", "nail": "PREGADO", "rail": "TRESPASSADO", "harp": "ARPOADO", "gren": "GRANADA"}

func up(w: String, u: String) -> bool:
	return G.UP.get(w, {}).get(u, false)

func _m(c: String, rough := .5, metal := .3, emi := "") -> StandardMaterial3D:
	var m = G.lit(Color(c), rough, metal)
	if emi != "":
		m.emission_enabled = true
		m.emission = Color(emi)
	return m

func build(weapons: Node) -> void:
	W = weapons
	root = W.root
	var glove = _m("3a2c2a", .9, 0)
	var sleeve = _m("7a1410", .9, 0)
	# ---- mãos abertas (espadas) ----
	hands = Node3D.new()
	root.add_child(hands)
	for s in [-1, 1]:
		var h = Node3D.new()
		h.rotation_order = EULER_ORDER_XYZ
		h.position = Vector3(s * .21, -.19, -.46)
		h.rotation = Vector3(-.12, s * .1, s * .35)
		hands.add_child(h)
		W.mk(Vector3(.09, .03, .1), glove, Vector3.ZERO, h)
		for f in 4:
			W.mk(Vector3(.017, .017, .055), glove, Vector3((f - 1.5) * .022, .012, -.07), h, Vector3(.55, 0, 0))
		W.mk(Vector3(.02, .02, .045), glove, Vector3(s * -.05, .01, -.02), h, Vector3(.3, 0, s * .6))
		W.mk(Vector3(.08, .08, .4), sleeve, Vector3(0, -.05, .22), h, Vector3(-.2, 0, 0))
	hands.visible = false
	var blank: Dictionary = W.rig(Vector3.ZERO)
	blank.rest = Vector3.ZERO
	blank.kz = 0.0; blank.kr = 0.0; blank.lr = 0.0
	models.sword = blank
	var swq = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	for i in 4:
		var vm = Node3D.new()
		vm.rotation_order = EULER_ORDER_XYZ
		var inner = make_sword()
		inner.basis = swq
		vm.add_child(inner)
		root.add_child(vm)
		var w = Node3D.new()
		var wi = make_sword()
		wi.rotation.z = PI / 2
		wi.scale = Vector3.ONE * 4.5
		w.add_child(wi)
		w.visible = false
		G.world.add_child(w)
		sw.append({"i": i, "vm": vm, "w": w, "state": "dock", "dock": 1.0, "t": 0.0, "stuck": 0.0, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "hit": [], "target": null, "boomed": false})
	# ---- lança-foguetes ----
	var rk: Dictionary = W.rig(Vector3(0, 0, -.1))
	var b: Node3D = rk.body
	var tube = _m("3b3631", .6, .2)
	var dk = _m("1f1d1b", .6, .2)
	var red = _m("8a1a12", .5, .1)
	var br = _m("b7794a", .3, .8)
	W.cyl(.055, .055, .62, 12, tube, Vector3(0, .03, -.15), b)
	W.cyl(.062, .062, .045, 12, br, Vector3(0, .03, -.455), b)
	W.cyl(.072, .058, .07, 12, dk, Vector3(0, .03, .18), b)
	for z in [-.3, -.05]: W.cyl(.058, .058, .02, 12, red, Vector3(0, .03, z), b)
	rk.war = Node3D.new()
	rk.war.position = Vector3(0, .03, -.5)
	b.add_child(rk.war)
	W.cyl(.036, .036, .07, 10, red, Vector3(0, 0, .02), rk.war)
	W.cyl(0.0, .036, .1, 10, dk, Vector3(0, 0, -.06), rk.war, Vector3(-PI / 2, 0, 0))
	W.mk(Vector3(.035, .11, .045), dk, Vector3(0, -.07, 0), b, Vector3(-.3, 0, 0))
	W.mk(Vector3(.03, .085, .035), dk, Vector3(0, -.06, -.22), b, Vector3(.1, 0, 0))
	W.mk(Vector3(.03, .05, .09), dk, Vector3(-.065, .07, -.1), b)
	W.mk(Vector3(.02, .02, .005), G.unshaded(Color("ff3a2a")), Vector3(-.065, .08, -.146), b)
	W.mk(Vector3(.09, .075, .1), dk, Vector3(0, .03, .24), b)
	W.mk(Vector3(.075, .07, .09), glove, Vector3(0, -.09, .02), rk.root, Vector3(-.3, 0, 0))
	W.mk(Vector3(.08, .08, .42), sleeve, Vector3(.03, -.17, .22), rk.root, Vector3(.45, 0, 0))
	rk.muzzle = Node3D.new(); rk.muzzle.position = Vector3(0, .03, -.5); b.add_child(rk.muzzle)
	rk.fl = W._flash_quad(.35, rk.muzzle)
	rk.rest = Vector3(.21, -.2, -.52); rk.kz = .14; rk.kr = .25; rk.lr = .08
	models.rocket = rk
	# ---- pregadora ----
	var nl: Dictionary = W.rig(Vector3(0, 0, -.08))
	b = nl.body
	var st = _m("5a5f69", .35, .7)
	nl.heat_mat = StandardMaterial3D.new()
	nl.heat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nl.heat_mat.albedo_color = Color("331008")
	W.mk(Vector3(.07, .09, .22), dk, Vector3.ZERO, b)
	W.mk(Vector3(.072, .02, .18), st, Vector3(0, .05, -.01), b)
	nl.barrels = Node3D.new(); nl.barrels.position = Vector3(0, .005, -.2); b.add_child(nl.barrels)
	for i in 4:
		var a = i / 4.0 * TAU
		W.cyl(.011, .011, .3, 6, st, Vector3(cos(a) * .024, sin(a) * .024, -.05), nl.barrels)
	W.cyl(.042, .042, .015, 8, br, Vector3(0, 0, -.2), nl.barrels)
	W.cyl(.042, .042, .015, 8, dk, Vector3(0, 0, .08), nl.barrels)
	for i in 3: W.mk(Vector3(.05, .01, .025), nl.heat_mat, Vector3(0, .062, .05 - i * .045), b)
	W.cyl(.04, .04, .038, 12, dk, Vector3(-.055, -.02, -.05), b, Vector3(0, 0, PI / 2))
	W.mk(Vector3(.045, .13, .05), dk, Vector3(0, -.09, .07), b, Vector3(-.3, 0, 0))
	W.mk(Vector3(.075, .07, .09), glove, Vector3(0, -.08, .08), nl.root, Vector3(-.3, 0, 0))
	W.mk(Vector3(.08, .08, .42), sleeve, Vector3(.025, -.16, .29), nl.root, Vector3(.45, 0, 0))
	nl.muzzle = Node3D.new(); nl.muzzle.position = Vector3(0, .005, -.42); b.add_child(nl.muzzle)
	nl.fl = W._flash_quad(.15, nl.muzzle)
	nl.rest = Vector3(.2, -.2, -.5); nl.kz = .025; nl.kr = .05; nl.lr = .02
	models.nail = nl
	# ---- fuzil de raio ----
	var rl: Dictionary = W.rig(Vector3(0, 0, -.1))
	b = rl.body
	var wh = _m("d8dde6", .5, .1)
	rl.coil = StandardMaterial3D.new()
	rl.coil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rl.coil.albedo_color = Color("1a4a55")
	W.mk(Vector3(.07, .09, .3), dk, Vector3(0, 0, .02), b)
	for s in [-1, 1]: W.mk(Vector3(.014, .03, .52), st, Vector3(s * .026, .015, -.36), b)
	W.mk(Vector3(.03, .02, .5), dk, Vector3(0, -.01, -.34), b)
	for i in 5: W.cyl(.045, .045, .025, 10, rl.coil, Vector3(0, .01, -.18 - i * .08), b)
	W.mk(Vector3(.05, .04, .12), dk, Vector3(0, .075, -.02), b)
	W.cyl(.022, .022, .14, 8, st, Vector3(0, .075, -.02), b)
	W.cyl(.018, .018, .01, 8, G.unshaded(Color("60ffff")), Vector3(0, .075, -.092), b)
	W.mk(Vector3(.05, .1, .22), wh, Vector3(0, -.03, .25), b, Vector3(.1, 0, 0))
	W.mk(Vector3(.04, .11, .05), dk, Vector3(0, -.08, .06), b, Vector3(-.3, 0, 0))
	W.mk(Vector3(.075, .07, .09), glove, Vector3(0, -.1, .07), rl.root, Vector3(-.3, 0, 0))
	W.mk(Vector3(.08, .08, .42), sleeve, Vector3(.03, -.18, .28), rl.root, Vector3(.45, 0, 0))
	rl.muzzle = Node3D.new(); rl.muzzle.position = Vector3(0, .015, -.63); b.add_child(rl.muzzle)
	rl.fl = W._flash_quad(.3, rl.muzzle)
	rl.rest = Vector3(.2, -.21, -.55); rl.kz = .1; rl.kr = .3; rl.lr = .05
	models.rail = rl
	# ---- arpão ----
	var hp: Dictionary = W.rig(Vector3(0, 0, -.1))
	b = hp.body
	var wd = _m("5a3420", .8, 0)
	var stl = _m("9aa3b0", .35, .7)
	W.mk(Vector3(.06, .07, .44), wd, Vector3(0, 0, -.08), b)
	W.mk(Vector3(.07, .03, .46), dk, Vector3(0, .035, -.1), b)
	for s in [-1, 1]:
		W.mk(Vector3(.22, .022, .03), dk, Vector3(s * .11, .03, -.27), b, Vector3(0, s * .35, 0))
		W.mk(Vector3(.005, .005, .2), G.unshaded(Color(.07, .07, .07)), Vector3(s * .1, .035, -.2), b, Vector3(0, -s * .55, 0))
	hp.bolt = Node3D.new(); hp.bolt.position = Vector3(0, .06, -.22); b.add_child(hp.bolt)
	W.mk(Vector3(.012, .012, .42), stl, Vector3.ZERO, hp.bolt)
	W.cyl(0.0, .025, .07, 6, stl, Vector3(0, 0, -.24), hp.bolt, Vector3(-PI / 2, 0, 0))
	for s in [-1, 1]: W.mk(Vector3(.006, .03, .008), stl, Vector3(s * .012, 0, -.2), hp.bolt, Vector3(0, 0, s * .6))
	hp.reel = Node3D.new(); hp.reel.position = Vector3(.055, -.02, -.02); b.add_child(hp.reel)
	W.cyl(.04, .04, .03, 10, dk, Vector3.ZERO, hp.reel, Vector3(0, 0, PI / 2))
	W.mk(Vector3(.034, .075, .008), stl, Vector3.ZERO, hp.reel)
	W.mk(Vector3(.04, .11, .05), dk, Vector3(0, -.08, .08), b, Vector3(-.3, 0, 0))
	W.mk(Vector3(.05, .08, .18), wd, Vector3(0, -.02, .24), b, Vector3(.15, 0, 0))
	W.mk(Vector3(.075, .07, .09), glove, Vector3(0, -.1, .09), hp.root, Vector3(-.3, 0, 0))
	W.mk(Vector3(.08, .08, .42), sleeve, Vector3(.03, -.18, .3), hp.root, Vector3(.45, 0, 0))
	hp.muzzle = Node3D.new(); hp.muzzle.position = Vector3(0, .06, -.46); b.add_child(hp.muzzle)
	hp.fl = W._flash_quad(.12, hp.muzzle)
	hp.rest = Vector3(.2, -.2, -.5); hp.kz = .06; hp.kr = .2; hp.lr = .05
	models.harp = hp
	# ---- lança-granadas ----
	var gl: Dictionary = W.rig(Vector3(0, 0, -.1))
	b = gl.body
	var ol = _m("4c4a2e", .7, .1)
	W.cyl(.05, .05, .3, 10, dk, Vector3(0, .03, -.3), b)
	W.cyl(.057, .057, .03, 10, br, Vector3(0, .03, -.45), b)
	W.cyl(.03, .03, .01, 10, G.unshaded(Color(.03, .03, .03)), Vector3(0, .03, -.466), b)
	gl.drum = Node3D.new(); gl.drum.position = Vector3(0, -.005, -.08); b.add_child(gl.drum)
	W.cyl(.078, .078, .14, 8, ol, Vector3.ZERO, gl.drum)
	for i in 6:
		var a = i / 6.0 * TAU
		W.cyl(.021, .021, .145, 6, dk, Vector3(cos(a) * .047, sin(a) * .047, 0), gl.drum)
	W.mk(Vector3(.06, .08, .18), dk, Vector3(0, .02, .08), b)
	W.mk(Vector3(.05, .09, .2), ol, Vector3(0, -.02, .26), b, Vector3(.1, 0, 0))
	W.mk(Vector3(.04, .11, .05), dk, Vector3(0, -.08, .1), b, Vector3(-.3, 0, 0))
	W.mk(Vector3(.035, .08, .04), dk, Vector3(0, -.05, -.25), b)
	W.mk(Vector3(.075, .07, .09), glove, Vector3(0, -.1, .11), gl.root, Vector3(-.3, 0, 0))
	W.mk(Vector3(.08, .08, .42), sleeve, Vector3(.03, -.18, .32), gl.root, Vector3(.45, 0, 0))
	gl.muzzle = Node3D.new(); gl.muzzle.position = Vector3(0, .03, -.47); b.add_child(gl.muzzle)
	gl.fl = W._flash_quad(.3, gl.muzzle)
	gl.rest = Vector3(.21, -.21, -.52); gl.kz = .1; gl.kr = .3; gl.lr = .08
	models.gren = gl

# ---------------- espada alada (lâmina cromada com farpas, asas de penas, joia brilhante) ----------------
var _sw_mats = {}
func make_sword() -> Node3D:
	if _sw_mats.is_empty():
		_sw_mats.chrome = _m("e6eaf1", .2, .6, "1c2230")
		_sw_mats.chrome2 = _m("b8c0cc", .25, .6, "161a24")
		_sw_mats.feather = _m("f3f5f9", .7, 0, "3c4458")
		_sw_mats.grip = _m("8d94a0", .3, .6)
		_sw_mats.gem = G.unshaded(Color.WHITE)
	var g = Node3D.new()
	var ch: StandardMaterial3D = _sw_mats.chrome
	var ch2: StandardMaterial3D = _sw_mats.chrome2
	for i in 6:
		var z0 = .02 + i * .05
		var w = .032 - i * .0035
		W.mk(Vector3(.01, w, .052), ch, Vector3(0, 0, z0 + .026), g)
		for s in [-1, 1]: W.mk(Vector3(.006, .012, .026), ch2, Vector3(0, s * (w / 2 + .003), z0 + .012), g, Vector3(s * .65, 0, 0))
	W.mk(Vector3(.013, .006, .3), ch2, Vector3(0, 0, .17), g)
	W.mk(Vector3(.01, .02, .02), ch, Vector3(0, 0, .33), g, Vector3(PI / 4, 0, 0))
	W.mk(Vector3(.008, .008, .03), ch, Vector3(0, 0, .35), g)
	W.mk(Vector3(.016, .055, .022), ch, Vector3.ZERO, g)
	var gem = MeshInstance3D.new()
	var sm = SphereMesh.new(); sm.radius = .014; sm.height = .028
	gem.mesh = sm
	gem.material_override = _sw_mats.gem
	g.add_child(gem)
	for s in [-1, 1]:
		for k in 6:
			var a = deg_to_rad(32 + k * 9.5)
			var l: float = [.2, .19, .17, .15, .12, .09][k]
			var dy = s * cos(a)
			var dz = -sin(a)
			var by = s * (.022 + k * .004)
			var bz = -.004 * k
			W.mk(Vector3(.004, .02, l), _sw_mats.feather, Vector3(0, by + dy * l / 2, bz + dz * l / 2), g, Vector3(atan2(-dy, dz), 0, 0))
			if k < 5:
				var l2 = l * .45
				W.mk(Vector3(.005, .024, l2), ch2, Vector3(.002, by * .9 + dy * l2 / 2, bz + .01 + dz * l2 / 2), g, Vector3(atan2(-dy, dz), 0, 0))
	W.mk(Vector3(.012, .014, .07), _sw_mats.grip, Vector3(0, 0, -.046), g)
	W.mk(Vector3(.016, .016, .016), ch, Vector3(0, 0, -.09), g, Vector3(PI / 4, 0, 0))
	for s in [-1, 1]: W.mk(Vector3(.006, .012, .01), ch, Vector3(0, s * .013, -.09), g)
	W.mk(Vector3(.006, .006, .022), ch, Vector3(0, 0, -.108), g)
	return g

static func face(n: Node3D, dir: Vector3) -> void:
	if dir.length_squared() < 1e-6: return
	var upv = Vector3.UP if abs(dir.normalized().y) < .98 else Vector3.RIGHT
	var s = n.scale
	n.global_basis = Basis.looking_at(dir.normalized(), upv, true)
	n.scale = s

# ---------------- troca de arma ----------------
func on_switch(id: String) -> void:
	hands.visible = id == "sword"
	if guiding:
		_explode_rocket(guiding)
		guiding = null
	W.zoom = false

func reset() -> void:
	for s in sw:
		s.state = "dock"; s.dock = 1.0; s.w.visible = false
	for r in rockets: if is_instance_valid(r.g): r.g.queue_free()
	rockets.clear()
	for n in nails: if is_instance_valid(n.m): n.m.queue_free()
	nails.clear()
	for h in harps:
		if is_instance_valid(h.g): h.g.queue_free()
		if is_instance_valid(h.cable): h.cable.queue_free()
	harps.clear()
	for g in grens: if is_instance_valid(g.g): g.g.queue_free()
	grens.clear()
	rk_t = 1.0; rk_l = true; guiding = null; heat = 0.0; over = 0.0; W.zoom = false

# ---------------- clique / botão direito ----------------
func fire(id: String) -> void:
	match id:
		"sword": throw_sword(null, false)
		"rocket": if rk_t >= 1: fire_rocket(false)
		"nail": fire_nail()
		"rail": fire_rail()
		"harp": if harps.is_empty(): fire_harp(false)
		"gren": fire_gren()

func alt_press(id: String) -> void:
	match id:
		"sword": sword_storm()
		"rocket":
			if rk_t >= 1 and W.cd <= 0 and W.draw_t >= .6 and guiding == null: fire_rocket(true)
			else: detonate_rockets()
		"nail": if W.cd <= 0 and W.draw_t >= .6: nail_discharge()
		"rail": W.zoom = true
		"harp": if W.cd <= 0 and W.draw_t >= .6 and harps.is_empty(): fire_harp(true)
		"gren": detonate_grens()

func alt_release(_id: String) -> void:
	W.zoom = false
	if guiding:
		_explode_rocket(guiding)
		guiding = null

# ---------------- espadas ----------------
func throw_sword(target, force: bool) -> void:
	if (sword_cd > 0 and not force) or G.player.dead: return
	var s = null
	for x in sw:
		if x.state == "dock" and x.dock >= 1:
			s = x; break
	if s == null: return
	sword_cd = .18
	s.target = target
	s.boomed = false
	var c = G.cam.global_transform
	var d: Vector3 = -c.basis.z
	var sl: Vector3 = SLOTS[s.i]
	s.pos = c.origin + c.basis.x * sl.x * 2 - c.basis.y * .15 - c.basis.z * 1.2
	var aim: Vector3
	if target and is_instance_valid(target): aim = target.center()
	else:
		var q = PhysicsRayQueryParameters3D.create(c.origin, c.origin + d * 200, 3)
		var hit = G.world.get_world_3d().direct_space_state.intersect_ray(q)
		aim = hit.position if hit else c.origin + d * 200
	s.vel = (aim - s.pos).normalized() * (100.0 if up("sword", "fast") else 68.0)
	s.state = "fly"; s.t = 0.0; s.stuck = 0.0; s.hit = []; s.dock = 0.0
	s.w.visible = true
	s.w.global_position = s.pos
	force_t = 0.0
	G.shake = max(G.shake, .15)
	G.snd("whoosh", -6, 1.4)
	G.snd("ping", -14, 1.6)

func recall_swords() -> void:
	var any = false
	for s in sw:
		if s.state != "dock":
			s.state = "ret"; s.stuck = 0.0; s.hit = []; any = true
	if any:
		force_t = 0.0
		G.snd("whirl", -8)

func sword_storm() -> void:
	for s in sw:
		if s.state != "dock":
			recall_swords(); return
	var rdy = sw.filter(func(x): return x.dock >= 1)
	if rdy.is_empty(): return
	var tg = G.enemies.filter(func(e): return is_instance_valid(e) and e.alive and e.spawn_t <= 0 and e.global_position.distance_to(G.player.global_position) < 70 and G.los(G.cam.global_position, e.center()))
	tg.sort_custom(func(a, b): return a.global_position.distance_to(G.player.global_position) < b.global_position.distance_to(G.player.global_position))
	for i in rdy.size():
		var t = tg[i % tg.size()] if tg.size() > 0 else null
		G.later(i * .07, func(): throw_sword(t, true))
	G.flash = max(G.flash, .12)
	G.shake = max(G.shake, .3)
	G.snd("whoosh", -4, 1.2)
	G.add_style(20, "TEMPESTADE")

func _sword_step(s: Dictionary, step: Vector3) -> bool:
	s.pos += step
	for p in G.projs:
		if p.owner != "enemy" or p.life <= 0: continue
		if p.m.global_position.distance_to(s.pos) < 1.5:
			var q: Vector3 = p.m.global_position
			p.life = 0
			p.m.queue_free()
			G.blast(q, .6, "sword")
			G.add_style(40, "INTERCEPTADO")
	for e in G.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0 or e in s.hit: continue
		if e.center().distance_to(s.pos) < e.r + 1.0:
			s.hit.append(e)
			if s.target == e: s.target = null
			if up("sword", "heal"): G.heal(6)
			if up("sword", "boom") and not s.boomed:
				s.boomed = true
				G.blast(s.pos, .45, "sword")
			G.hurt_enemy(e, 70, "sword", s.pos, false, s.vel.normalized())
			G.snd("hit", -6, .7)
	if s.state == "fly" and G.in_solid(s.pos):
		s.pos -= step
		s.stuck = .35
		G.emit("spark", s.pos, 10, 8, .08, .35)
		G.snd("click", -4, .55)
		return false
	return true

func _upd_swords(dt: float) -> void:
	if sword_cd > 0: sword_cd -= dt
	for s in sw:
		if s.state == "dock": continue
		if s.stuck > 0:
			s.stuck -= dt
			if s.stuck <= 0:
				s.state = "ret"; s.hit = []; G.snd("whirl", -10)
			continue
		if s.state == "ret":
			var to: Vector3 = G.cam.global_position - Vector3(0, .3, 0) - s.pos
			if to.length() < 1.6:
				s.state = "dock"; s.dock = 0.0; s.w.visible = false
				G.snd("ping", -14, 1.3)
				continue
			s.vel = s.vel.lerp(to.normalized() * (115.0 if up("sword", "fast") else 80.0), 1.0 - exp(-9 * dt))
		if s.state == "fly" and s.target != null:
			if is_instance_valid(s.target) and s.target.alive:
				s.vel = s.vel.lerp((s.target.center() - s.pos).normalized() * (105.0 if up("sword", "fast") else 78.0), 1.0 - exp(-12 * dt))
			else: s.target = null
		var st: Vector3 = s.vel * dt
		var n: int = max(1, int(ceil(st.length() / .5)))
		st /= n
		for k in n:
			if not _sword_step(s, st): break
		s.t += dt
		if s.state == "fly" and s.t > (1.8 if s.target != null else 1.1) and s.stuck <= 0:
			s.state = "ret"; s.hit = []; G.snd("whirl", -10)
		s.w.global_position = s.pos
		if s.stuck <= 0: face(s.w, s.vel)
		if G.rng.randf() < .8: G.emit("white" if G.rng.randf() < .6 else "cyan", s.pos, 1, 1.5, .08, .3, Vector3.ZERO, 0)

# ---------------- foguetes ----------------
var _rk_mats = {}
func fire_rocket(guided: bool) -> void:
	if _rk_mats.is_empty():
		_rk_mats.a = G.lit(Color("8a1a12")); _rk_mats.b = G.lit(Color("2a2622")); _rk_mats.f = G.unshaded(Color("ffb040"))
	var d: Vector3 = W.cam_dir()
	var o: Vector3 = W.muzzle_world()
	var g = Node3D.new()
	G.world.add_child(g)
	var body = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = .12; cm.bottom_radius = .12; cm.height = .6; cm.radial_segments = 8
	body.mesh = cm; body.material_override = _rk_mats.a; body.rotation.x = PI / 2
	g.add_child(body)
	var tip = MeshInstance3D.new()
	var tm = CylinderMesh.new(); tm.top_radius = 0; tm.bottom_radius = .12; tm.height = .3; tm.radial_segments = 8
	tip.mesh = tm; tip.material_override = _rk_mats.b; tip.rotation.x = PI / 2; tip.position.z = .45
	g.add_child(tip)
	var fl = MeshInstance3D.new()
	var fs = SphereMesh.new(); fs.radius = .2; fs.height = .4; fs.radial_segments = 6; fs.rings = 3
	fl.mesh = fs; fl.material_override = _rk_mats.f; fl.position.z = -.42
	g.add_child(fl)
	g.global_position = o
	face(g, d)
	var r = {"g": g, "fl": fl, "vel": d * (34.0 if guided else 48.0), "life": 7.0 if guided else 4.0, "guided": guided, "dead": false}
	rockets.append(r)
	if guided:
		guiding = r
		G.snd("beep", -10)
	models.rocket.war.visible = false
	rk_t = 0.0; rk_l = false
	W.cd = .95; W.recoil = 1.2
	W.muzzle_flash(models.rocket)
	G.shake = max(G.shake, .45)
	G.snd("whoosh", -2, .6)
	G.snd("boomlite", -6, 1.3)

func _explode_rocket(r: Dictionary) -> void:
	if r.dead: return
	r.dead = true
	if guiding == r: guiding = null
	var q: Vector3 = r.g.global_position
	r.g.queue_free()
	G.blast(q, .85, "rocket")
	if up("rocket", "frag"):
		for i in 12:
			var d = Vector3(G.rnd(-1, 1), G.rnd(-.2, 1), G.rnd(-1, 1)).normalized()
			_make_nail(q, d * 60, .6, 14.0, true)
	var pc: Vector3 = G.player.global_position + Vector3(0, .9, 0)
	var dd = pc.distance_to(q)
	if dd < 6.5:
		var k = 1.0 - dd / 7.0
		var jm = 1.5 if up("rocket", "jump") else 1.0
		var dir = (pc - q).normalized()
		G.player.velocity += dir * 24 * k * jm + Vector3(0, (11 * k + 4) * jm, 0)
		G.player.slamming = false
		G.player.sliding = false
		if not G.player.is_on_floor(): G.add_style(20, "SALTO-FOGUETE")

func detonate_rockets() -> void:
	var n = 0
	for r in rockets:
		if not r.dead:
			_explode_rocket(r); n += 1
	if n: G.add_style(15, "DETONAÇÃO")

func _guide_aim() -> Vector3:
	var c = G.cam.global_transform
	var d: Vector3 = -c.basis.z
	var q = PhysicsRayQueryParameters3D.create(c.origin, c.origin + d * 250, 3)
	var hit = G.world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else c.origin + d * 250

func _upd_rockets(dt: float) -> void:
	for r in rockets:
		if r.dead: continue
		r.life -= dt
		if r.guided and guiding == r:
			var aim = _guide_aim()
			var sp: float = r.vel.length()
			r.vel = r.vel.lerp((aim - r.g.global_position).normalized() * sp, 1.0 - exp(-7 * dt))
			r.vel = r.vel.normalized() * min(60.0, sp + dt * 14)
			face(r.g, r.vel)
			G.tracer(W.muzzle_world(), aim, .012, Color("ff2a1a"), .035)
			G.emit("spark", aim, 1, 1, .12, .08, Vector3.ZERO, 0)
			if G.rng.randf() < dt * 6: G.snd("beep", -16)
		var st: Vector3 = r.vel * dt / 3.0
		for k in 3:
			if r.dead: break
			r.g.global_position += st
			var q: Vector3 = r.g.global_position
			if G.in_solid(q):
				r.g.global_position -= st
				_explode_rocket(r)
				break
			for e in G.enemies:
				if is_instance_valid(e) and e.alive and e.spawn_t <= 0 and e.center().distance_to(q) < e.r + .9:
					_explode_rocket(r)
					break
		if not r.dead:
			r.fl.scale = Vector3.ONE * G.rnd(.8, 1.4)
			G.emit("dust", r.g.global_position, 1, 1.5, .3, 1.0, Vector3.ZERO, -2)
			if r.life <= 0: _explode_rocket(r)
	rockets = rockets.filter(func(r): return not r.dead)

# ---------------- pregos ----------------
var _nail_mesh: BoxMesh
func _make_nail(o: Vector3, vel: Vector3, life: float, dmg: float, hot: bool) -> void:
	if _nail_mesh == null:
		_nail_mesh = BoxMesh.new(); _nail_mesh.size = Vector3(.035, .035, .55)
	var m = MeshInstance3D.new()
	m.mesh = _nail_mesh
	m.material_override = G.unshaded(Color("ff7a20") if hot else Color("d6dae2"))
	if hot: m.scale = Vector3(1.6, 1.6, 1.2)
	G.world.add_child(m)
	m.global_position = o
	face(m, vel)
	nails.append({"m": m, "vel": vel, "life": life, "dmg": dmg, "hot": hot, "dead": false, "bounced": false})

func fire_nail() -> void:
	if over > 0: return
	var b = G.cam.global_transform.basis
	var d: Vector3 = (W.cam_dir() + b.x * G.rnd(-.018, .018) + b.y * G.rnd(-.018, .018)).normalized()
	_make_nail(W.muzzle_world(), d * 120, 1.2, 8.0, false)
	models.nail.fl.scale = Vector3.ONE
	W.cd = .065
	heat = min(1.0, heat + .028 * (.6 if up("nail", "cool") else 1.0))
	W.recoil = min(.7, W.recoil + .3)
	models.nail.fl.visible = true
	models.nail.fl.rotation.z = G.rnd(0, TAU)
	W.flash_t = .03
	nl_firing = .12
	G.shake = max(G.shake, .05)
	G.snd("click", -8, G.rnd(.55, .68))
	G.snd("hit", -10, .8)
	if heat >= 1:
		over = 1.4
		G.snd("charge", -8, .5)

func nail_discharge() -> void:
	if over > 0 or heat < .2:
		G.snd("click", -6); return
	var k = heat
	var n = 8 + int(round(k * 22))
	var d0: Vector3 = W.cam_dir()
	var o: Vector3 = W.muzzle_world()
	var b = G.cam.global_transform.basis
	for i in n:
		var a = G.rnd(0, TAU)
		var sp = sqrt(G.rng.randf()) * (.05 + .1 * k)
		var d = (d0 + b.x * cos(a) * sp + b.y * sin(a) * sp).normalized()
		_make_nail(o, d * G.rnd(95, 115), 1.2, 10 + 14 * k, true)
	heat = 0.0
	W.cd = .5; W.recoil = 1.4; nl_spin = 40
	models.nail.fl.visible = true
	models.nail.fl.scale = Vector3.ONE * 2.5
	W.flash_t = .08
	G.shake = max(G.shake, .25 + .35 * k)
	G.player.velocity += d0 * -6 * k
	G.snd("boomlite", -4, 1.4)
	G.snd("sg", -6, 1.5)
	G.add_style(30 if k > .8 else 10, "DESCARGA TOTAL" if k > .8 else "DESCARGA")

func _bounce_axis(pos: Vector3, vel: Vector3, dt: float) -> Vector3:
	var v = vel
	for ax in 3:
		var t = pos
		t[ax] += vel[ax] * dt
		if G.in_solid(t): v[ax] = -v[ax]
	return v

func _upd_nails(dt: float) -> void:
	for n in nails:
		if n.dead: continue
		n.life -= dt
		if up("nail", "magnet"):
			var best = null
			var bd = 14.0
			for e in G.enemies:
				if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
				var c: Vector3 = e.center()
				var dd = c.distance_to(n.m.global_position)
				if dd < bd and (c - n.m.global_position).normalized().dot(n.vel.normalized()) > .4:
					bd = dd; best = e
			if best:
				var spd: float = n.vel.length()
				n.vel = n.vel.lerp((best.center() - n.m.global_position).normalized() * spd, 1.0 - exp(-7 * dt))
				face(n.m, n.vel)
		var st: Vector3 = n.vel * dt / 4.0
		for k in 4:
			if n.dead: break
			n.m.global_position += st
			var q: Vector3 = n.m.global_position
			if G.in_solid(q):
				if up("nail", "bounce") and not n.bounced:
					n.m.global_position -= st
					n.vel = _bounce_axis(n.m.global_position, n.vel, dt)
					n.bounced = true
					face(n.m, n.vel)
					G.emit("spark", q, 2, 4, .05, .2)
					break
				G.emit("spark", q, 3, 5, .06, .2)
				n.dead = true
				break
			for e in G.enemies.duplicate():
				if is_instance_valid(e) and e.alive and e.spawn_t <= 0 and e.center().distance_to(q) < e.r + .35:
					if n.hot: G.emit("spark", q, 4, 6, .08, .3)
					G.hurt_enemy(e, n.dmg, "nail", q, false, n.vel.normalized())
					if is_instance_valid(e) and e.alive and not e.is_boss: e.velocity += n.vel * .006
					n.dead = true
					break
		if n.life <= 0: n.dead = true
		if n.dead: n.m.queue_free()
	nails = nails.filter(func(n): return not n.dead)

# ---------------- fuzil de raio ----------------
func fire_rail() -> void:
	var d: Vector3 = W.cam_dir()
	var o: Vector3 = G.cam.global_position
	var r: Dictionary = G.shoot(o, d, 300, true)
	var mw: Vector3 = W.muzzle_world()
	var kills = 0
	var len = o.distance_to(r.end)
	if up("rail", "wide"):
		for e in G.enemies:
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
			if r.hits.any(func(h): return h.e == e): continue
			var c: Vector3 = e.center()
			var t = (c - o).dot(d)
			if t < 0 or t > len: continue
			if (o + d * t).distance_to(c) < e.r + 1.4: r.hits.append({"e": e, "point": c, "head": false})
	for h in r.hits:
		var pt: Vector3 = h.point
		if G.hurt_enemy(h.e, 240.0 if h.head else 120.0, "rail", pt, h.head, d): kills += 1
		if up("rail", "chain"):
			var others = G.enemies.filter(func(o2): return is_instance_valid(o2) and o2.alive and o2 != h.e and o2.spawn_t <= 0 and o2.center().distance_to(pt) < 14)
			others.sort_custom(func(a, b): return a.center().distance_to(pt) < b.center().distance_to(pt))
			for o2 in others.slice(0, 2):
				var c2: Vector3 = o2.center()
				G.tracer(pt, c2, .04, Color("9ff4ff"), .3)
				G.emit("cyan", c2, 6, 6, .08, .3)
				G.hurt_enemy(o2, 50, "rail", c2, false)
	G.tracer(mw, r.end, .14, Color("40e8ff"), .45)
	G.tracer(mw, r.end, .05, Color.WHITE, .3)
	var L = mw.distance_to(r.end)
	var i = 1.0
	while i < L:
		G.emit("cyan", mw.lerp(r.end, i / L), 1, 1.5, .12, .6, Vector3.ZERO, 0)
		i += 2.2
	G.emit("cyan", r.end, 14, 10, .12, .5)
	if kills > 1: G.add_style(40 * kills, "TRESPASSE ×%d" % kills)
	W.cd = .9 if up("rail", "cap") else 1.4
	rail_max = W.cd
	W.recoil = 1.8
	W.muzzle_flash(models.rail)
	G.flash = max(G.flash, .12)
	G.shake = max(G.shake, .5)
	G.player.velocity += d * -4
	G.snd("beam", -4, 1.4)
	G.snd("rev", -6, .7)

# ---------------- arpão ----------------
var _hp_mat: StandardMaterial3D
func fire_harp(grap: bool) -> void:
	if _hp_mat == null: _hp_mat = G.lit(Color("9aa3b0"), .35, .7)
	var d: Vector3 = W.cam_dir()
	var o: Vector3 = W.muzzle_world()
	var g = Node3D.new()
	G.world.add_child(g)
	W.mk(Vector3(.07, .07, 1.2), _hp_mat, Vector3.ZERO, g)
	W.cyl(0.0, .11, .28, 6, _hp_mat, Vector3(0, 0, .72), g, Vector3(PI / 2, 0, 0))
	g.global_position = o
	face(g, d)
	var cable = MeshInstance3D.new()
	var cb = BoxMesh.new(); cb.size = Vector3.ONE
	cable.mesh = cb
	cable.material_override = G.unshaded(Color("1a1614"))
	G.world.add_child(cable)
	harps.append({"g": g, "cable": cable, "pos": o, "vel": d * 95, "grap": grap, "state": "fly", "t": 0.0, "dist": 0.0, "enemy": null, "anchor": null, "range": 70.0 if up("harp", "long") else 40.0, "dead": false})
	models.harp.bolt.visible = false
	hp_t = 0.0
	W.cd = .35 if grap else .6
	W.recoil = 1.0
	G.shake = max(G.shake, .15)
	G.snd("whoosh", -6, 1.5)

func _upd_harps(dt: float) -> void:
	var mw: Vector3 = W.muzzle_world()
	for h in harps:
		h.t += dt
		match h.state:
			"fly":
				var st: Vector3 = h.vel * dt / 3.0
				for k in 3:
					if h.state != "fly": break
					h.pos += st
					h.dist += st.length()
					for e in G.enemies.duplicate():
						if is_instance_valid(e) and e.alive and e.spawn_t <= 0 and e.center().distance_to(h.pos) < e.r + .6:
							h.enemy = e
							if h.grap:
								h.state = "pull"; h.t = 0.0
							else:
								G.hurt_enemy(e, 45, "harp", h.pos, false, h.vel.normalized())
								if up("harp", "barb") and is_instance_valid(e) and e.alive and e.kind != "brute" and not e.is_boss:
									var dd: Vector3 = G.player.global_position - e.global_position
									dd.y = 0
									e.velocity += dd.normalized() * 30 + Vector3(0, 7, 0)
									G.add_style(15, "FISGADO")
								h.state = "stuck"; h.t = 0.0
							G.snd("hit", -4, .6)
							break
					if h.state == "fly" and G.in_solid(h.pos):
						h.pos -= st
						h.anchor = h.pos
						G.emit("spark", h.pos, 8, 6, .08, .3)
						G.snd("click", -4, .55)
						h.state = "pull" if h.grap else "stuck"
						h.t = 0.0
					if h.state == "fly" and h.dist > h.range: h.state = "ret"
			"pull":
				var tg = null
				if h.enemy != null:
					if is_instance_valid(h.enemy) and h.enemy.alive: tg = h.enemy.center()
				else: tg = h.anchor
				if tg == null: h.state = "ret"
				else:
					h.pos = tg
					var pc: Vector3 = G.player.global_position + Vector3(0, .9, 0)
					var dir: Vector3 = tg - pc
					if dir.length() < 2.6 or h.t > 1.6:
						h.state = "ret"
						if up("harp", "impact"): G.blast(G.player.global_position + Vector3(0, .5, 0), .5, "harp")
						if h.enemy != null: G.player.velocity *= .3
					else:
						G.player.velocity = dir.normalized() * 40
						G.player.slamming = false
						G.player.sliding = false
			"stuck":
				if h.enemy != null and is_instance_valid(h.enemy) and h.enemy.alive: h.pos = h.enemy.center()
				if h.t > .35: h.state = "ret"
			"ret":
				var to: Vector3 = mw - h.pos
				if to.length() < 1.6: h.dead = true
				else: h.pos += to.normalized() * min(to.length(), 110 * dt)
		if h.dead:
			h.g.queue_free(); h.cable.queue_free(); continue
		h.g.global_position = h.pos
		if h.state == "fly": face(h.g, h.vel)
		var L = mw.distance_to(h.pos)
		if L > .05:
			h.cable.global_position = (mw + h.pos) * .5
			var up_v = Vector3.UP if abs((h.pos - mw).normalized().y) < .98 else Vector3.RIGHT
			h.cable.look_at(h.pos, up_v)
			h.cable.scale = Vector3(.025, .025, L)
	harps = harps.filter(func(h): return not h.dead)

# ---------------- granadas ----------------
var _gr_mats = {}
func _make_gren(pos: Vector3, vel: Vector3, fuse: float, mini: bool) -> void:
	if _gr_mats.is_empty():
		_gr_mats.b = G.lit(Color("4c4a2e")); _gr_mats.l = G.unshaded(Color("ff3020"))
	var g = Node3D.new()
	var b = MeshInstance3D.new()
	var s = SphereMesh.new(); s.radius = .24; s.height = .48; s.radial_segments = 8; s.rings = 6
	b.mesh = s; b.material_override = _gr_mats.b
	g.add_child(b)
	var l = MeshInstance3D.new()
	var ls = SphereMesh.new(); ls.radius = .08; ls.height = .16; ls.radial_segments = 6; ls.rings = 4
	l.mesh = ls; l.material_override = _gr_mats.l; l.position.y = .22
	g.add_child(l)
	if mini: g.scale = Vector3.ONE * .6
	G.world.add_child(g)
	g.global_position = pos
	grens.append({"g": g, "l": l, "pos": pos, "vel": vel, "fuse": fuse, "max": fuse, "mini": mini, "stuck": null, "off": Vector3.ZERO, "dead": false})

func fire_gren() -> void:
	var d: Vector3 = W.cam_dir()
	var v: Vector3 = d * (38.0 if up("gren", "short") else 30.0) + Vector3(0, 4, 0) + G.player.velocity * .4
	_make_gren(W.muzzle_world(), v, .8 if up("gren", "short") else 1.6, false)
	W.cd = .55
	W.recoil = 1.0
	drum2_t += TAU / 6
	W.muzzle_flash(models.gren)
	G.shake = max(G.shake, .2)
	G.snd("boomlite", -8, 1.6)
	G.snd("click", -8, .6)

func _explode_gren(n: Dictionary) -> void:
	if n.dead: return
	n.dead = true
	n.g.queue_free()
	var q: Vector3 = n.pos
	G.blast(q, .42 if n.mini else .72, "gren")
	var pc: Vector3 = G.player.global_position + Vector3(0, .9, 0)
	var d = pc.distance_to(q)
	if d < 5:
		var k = 1.0 - d / 6.0
		G.player.velocity += (pc - q).normalized() * 16 * k + Vector3(0, 7 * k + 2, 0)
	if up("gren", "frag") and not n.mini:
		for i in 3:
			var a = i / 3.0 * TAU + G.rnd(-.3, .3)
			_make_gren(q + Vector3(0, .4, 0), Vector3(cos(a) * 7, 9, sin(a) * 7), .55, true)

func detonate_grens() -> void:
	var n = 0
	for g in grens.duplicate():
		if not g.dead:
			_explode_gren(g); n += 1
	if n: G.add_style(10 * n, "DETONAÇÃO")

func _upd_grens(dt: float) -> void:
	for n in grens.duplicate():
		if n.dead: continue
		n.fuse -= dt
		if n.stuck != null:
			if typeof(n.stuck) == TYPE_OBJECT:
				if is_instance_valid(n.stuck) and n.stuck.alive: n.pos = n.stuck.center() + n.off
				else: n.stuck = "world"
		else:
			n.vel.y -= 25 * dt
			for ax in 3:
				n.pos[ax] += n.vel[ax] * dt
				if G.in_solid(n.pos):
					n.pos[ax] -= n.vel[ax] * dt
					if up("gren", "sticky"):
						n.stuck = "world"; n.vel = Vector3.ZERO; break
					n.vel[ax] *= -.45
					for o in 3:
						if o != ax: n.vel[o] *= .8
					if abs(n.vel[ax]) > 3: G.snd("click", -14, 1.6)
			for e in G.enemies:
				if is_instance_valid(e) and e.alive and e.spawn_t <= 0 and e.center().distance_to(n.pos) < e.r + .45:
					if up("gren", "sticky"):
						n.stuck = e; n.off = n.pos - e.center()
					elif not n.mini:
						_explode_gren(n)
						G.add_style(15, "IMPACTO DIRETO")
					break
		if n.dead: continue
		n.g.global_position = n.pos
		n.g.rotation.x += dt * 6
		n.l.visible = sin((n.max - n.fuse) * (6 + 30 * (1 - n.fuse / n.max))) > 0
		if n.fuse <= 0: _explode_gren(n)
	grens = grens.filter(func(n): return not n.dead)

func _physics_process(dt: float) -> void:
	if G.state != "play": return
	_upd_swords(dt)
	_upd_rockets(dt)
	_upd_nails(dt)
	_upd_harps(dt)
	_upd_grens(dt)

# ---------------- pose em primeira pessoa ----------------
func pose(id: String, w: Dictionary, dt: float, rot: Vector3, now: float) -> Vector3:
	force_t = min(1.0, force_t + dt / .32)
	# espadas e mãos
	var on = id == "sword"
	var de: float = W.ease_out(W.draw_t)
	if on:
		hands.position = Vector3(W.sway.x * .5, -(1 - de) * .25 + sin(W.bob_ph) * .008 * W.bob_a, 0)
	for s in sw:
		if s.state == "dock": s.dock = min(1.0, s.dock + dt / .35)
		var sl: Vector3 = SLOTS[s.i]
		var e: float = W.ease_out(s.dock)
		var bob = sin(now * 2 + s.i * 2.1) * .016
		s.vm.visible = on and s.state == "dock" and s.dock > .02
		s.vm.scale = Vector3.ONE * max(.01, e) * .6
		s.vm.position = Vector3(sl.x + W.sway.x * .8, sl.y + bob + W.sway.y * .8 - (1 - e) * .12 - (1 - de) * .3, sl.z)
		var sd = 1.0 if sl.x > 0 else -1.0
		s.vm.rotation = Vector3(.1 + sin(now * 1.6 + s.i) * .03, sd * .08 + sin(now * 1.1 + s.i * 2) * .03, sd * .65 + sin(now * 1.3 + s.i) * .05)
	# calor da pregadora (esfria mesmo guardada)
	if id != "nail":
		if over > 0:
			over -= dt
			if over <= 0: heat = .25
		elif nl_firing <= 0: heat = max(0.0, heat - dt * .45)
	match id:
		"rocket":
			if rk_t < 1:
				rk_t = min(1.0, rk_t + dt / (.45 if up("rocket", "fast") else .9))
				if not rk_l and rk_t > .82:
					rk_l = true
					G.snd("shell", -4, .6); G.snd("click", -8, .5)
			var u = rk_t
			var dip = sin(u * PI) if u < 1 else 0.0
			var wi: float = clamp((u - .4) / .42, 0.0, 1.0)
			rot += Vector3(-dip * .4, 0, dip * .15)
			w.root.position.y -= dip * .05
			w.war.visible = u >= .4
			w.war.position.z = -.5 - (1 - W.ease_out(wi)) * .28
		"nail":
			nl_firing -= dt
			if over > 0:
				over -= dt
				if over <= 0: heat = .25
				rot.z += .15
				w.root.position.x += G.rnd(-1, 1) * .002
			elif nl_firing <= 0:
				heat = max(0.0, heat - dt * .45)
			nl_spin += ((30.0 if nl_firing > 0 else 0.0) - nl_spin) * (1.0 - exp(-(6.0 if nl_firing > 0 else 2.0) * dt))
			w.barrels.rotation.z += nl_spin * dt
			var hh = G.rnd(.7, 1.0) if over > 0 else heat
			w.heat_mat.albedo_color = Color(.2 + .8 * hh, .06 + .36 * hh * hh, .03)
		"rail":
			var k: float = 1.0 - W.cd / rail_max if W.cd > 0 else 1.0
			w.coil.albedo_color = Color(.1 + .2 * k, .3 + .65 * k, .35 + .65 * k)
			zb += ((1.0 if W.zoom else 0.0) - zb) * (1.0 - exp(-14 * dt))
			w.root.position += Vector3(-zb * .12, -zb * .14, 0)
		"harp":
			if harps.is_empty() and hp_t < 1:
				hp_t = min(1.0, hp_t + dt / .35)
				if hp_t >= 1: G.snd("click", -8)
			w.bolt.visible = harps.is_empty()
			w.bolt.position.z = -.22 + (1 - W.ease_out(hp_t)) * .16
			if not harps.is_empty(): w.reel.rotation.x += dt * 25
		"gren":
			drum2_a += (drum2_t - drum2_a) * (1.0 - exp(-18 * dt))
			w.drum.rotation.z = drum2_a
	return rot

func ammo_info(id: String) -> Array:
	# [atual, máximo, tipo] para o HUD
	match id:
		"rocket": return [1 if rk_t >= 1 else 0, 1, "rk"]
		"sword":
			var n = 0
			for s in sw: if s.state == "dock" and s.dock >= 1: n += 1
			return [n, 4, "sw"]
	return [0, 0, ""]
