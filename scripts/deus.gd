extends Node3D
## DEUS — o esqueleto colossal com auréola de sangue e braços que saem do vazio.
## Usa a animação original do modelo em trechos: repouso, braços estendidos, convulsão e recuperação.
## Ataques: Mãos do Abismo, Olhar do Criador, Chuva de Sangue, Auréola do Juízo, Convulsão e Dedo de Deus.

const SC := 1000.0
const H := 32.0
const BASE_Y := 1.0
# trechos da animação (segundos)
const SEC := {"idle": [0.0, 2.0], "reach": [2.0, 5.8], "convulse": [6.2, 10.4], "recover": [10.4, 12.8]}

var kind = "deus"
var alive = true
var is_boss = true
var dummy = false
var fly = true
var hp = 6500.0
var max_hp = 6500.0
var r = 5.0
var h = 30.0
var spawn_t = 3.0
var velocity = Vector3.ZERO
var burn = 0.0
var mark = null

var model: Node3D
var ap: AnimationPlayer
var sk: Skeleton3D
var head_bone = -1
var mats = []
var body_mats = []
var halo_mats = []
var glow_mats = []
var flash = 0.0
var phase = 0.0
var ang = 0.0
var cd = 3.5
var att = ""
var at = 0.0
var fired = {}
var summoned = {}
var ad = {}
var last_att = ""
var ph2 = false
var ascended = false
var redk = 0.0 # 0..1: quanto ele já virou sangue
var falls = []
var flood: MeshInstance3D
var flood_mat: StandardMaterial3D
var flood_y = -.6
var flood_t = .45
var hand_proj = []
var inv = false
## true enquanto Deus espera no altar / durante a cutscene: anima, mas não age
var cine = false
var dying = false
var die_t = 0.0
var gfx = []
# controle da animação por trechos
var sec = "idle"
var st = 0.0
var sdir = 1.0
var sspd = 1.0
var hy = BASE_Y
# crista de mãos decepadas em volta dele
var crest: Node3D
var crest_hands = []
var crest_spin = 0.0
var crest_spd = .18
var crest_clench = 0.0
var crest_r = 1.0
var chest_bone = -1
const N_HANDS := 14

func setup(pos: Vector3) -> void:
	position = Vector3(pos.x, 70, pos.z)
	model = load("res://deus/deus.glb").instantiate()
	model.scale = Vector3.ONE * SC
	add_child(model)
	ap = _find(model, "AnimationPlayer")
	sk = _find(model, "Skeleton3D")
	if ap:
		var an = ap.get_animation(ap.get_animation_list()[0])
		an.loop_mode = Animation.LOOP_NONE
		ap.play(ap.get_animation_list()[0])
		ap.pause()
	# procura o esqueleto do corpo (o que tem o osso da cabeça)
	for s in _all(model, "Skeleton3D"):
		var b = s.find_bone("skeleton:head")
		if b < 0: b = s.find_bone("skeleton_head")
		if b >= 0:
			sk = s; head_bone = b
			chest_bone = s.find_bone("skeleton:chest")
			if chest_bone < 0: chest_bone = s.find_bone("skeleton_chest")
	_materials()
	_build_crest()
	# área de acerto
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("enemy", self)
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 5.0
	cap.height = 30.0
	cs.shape = cap
	cs.position.y = 16.5
	body.add_child(cs)
	add_child(body)
	ang = atan2(pos.z, pos.x)
	add_to_group("gabriel")
	_play("idle", 1.0)

func _find(n, cls):
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r2 = _find(c, cls)
		if r2: return r2
	return null

func _all(n, cls) -> Array:
	var out = []
	if n.get_class() == cls: out.append(n)
	for c in n.get_children(): out += _all(c, cls)
	return out

func _materials() -> void:
	var skc = load("res://deus/skel_col.jpg")
	var skn = load("res://deus/skel_nrm.png")
	var arc = load("res://deus/arm_col.jpg")
	var arn = load("res://deus/arm_nrm.png")
	var gl = load("res://deus/glow.png")
	for mi in _all(model, "MeshInstance3D"):
		var mesh: Mesh = mi.mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in mesh.get_surface_count():
			var src = mesh.surface_get_material(si)
			var nm = String(src.resource_name) if src else ""
			var m = StandardMaterial3D.new()
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if nm.contains("skeleton_mat") or nm.contains("skeleton:skeleton"):
				m.albedo_texture = skc
				m.normal_enabled = true; m.normal_texture = skn
				m.roughness = .65
				m.albedo_color = Color(1.0, .95, .9)
				m.rim_enabled = true; m.rim = .5; m.rim_tint = .3
				m.emission_enabled = true; m.emission = Color(.12, .08, .07)
				body_mats.append(m)
			elif nm.contains("arm_mat"):
				mi.visible = false # os braços originais dão lugar à crista
				m.albedo_texture = arc
				m.normal_enabled = true; m.normal_texture = arn
				m.roughness = .5
				m.albedo_color = Color(.55, .5, .5)
				m.rim_enabled = true; m.rim = .6; m.rim_tint = .2
				m.emission_enabled = true; m.emission = Color(.05, .0, .0)
				body_mats.append(m)
			elif nm.contains("glow"):
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.albedo_texture = gl
				m.albedo_color = Color(1, .55, .45, .5)
				m.disable_fog = true
				glow_mats.append(m)
			elif nm.contains("inner_halo"):
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color(.05, 0, 0)
			else:
				# auréola e gotas de sangue: vermelho que brilha
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color(1.0, .12, .1) if not nm.contains("outter") else Color(1, .1, .05, .45)
				if nm.contains("outter"):
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.disable_fog = true
				halo_mats.append(m)
			mi.set_surface_override_material(si, m)
			mats.append(m)

# ---------------- crista de mãos ----------------
func _build_crest() -> void:
	var inst = load("res://deus/mao.glb").instantiate()
	var src: MeshInstance3D = _find(inst, "MeshInstance3D")
	var hmesh: Mesh = src.mesh
	inst.free()
	var hm = StandardMaterial3D.new()
	hm.albedo_texture = load("res://deus/arm_col.jpg")
	hm.normal_enabled = true
	hm.normal_texture = load("res://deus/arm_nrm.png")
	hm.albedo_color = Color(.62, .55, .52)
	hm.roughness = .45
	hm.rim_enabled = true; hm.rim = .7; hm.rim_tint = .2
	hm.emission_enabled = true; hm.emission = Color(.06, .0, .0)
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	body_mats.append(hm)
	mats.append(hm)
	var stump = StandardMaterial3D.new()
	stump.albedo_color = Color(.45, 0, .02)
	stump.roughness = .2
	stump.emission_enabled = true; stump.emission = Color(.35, 0, 0)
	mats.append(stump)
	var drop_mat = StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.albedo_color = Color(.6, 0, .02)
	var drop_mesh = SphereMesh.new()
	drop_mesh.radius = .1; drop_mesh.height = .3; drop_mesh.radial_segments = 6; drop_mesh.rings = 3
	drop_mesh.material = drop_mat
	var sph = SphereMesh.new()
	sph.radius = .5; sph.height = 1.0; sph.radial_segments = 10; sph.rings = 6
	var strand_m = CylinderMesh.new()
	strand_m.top_radius = .07; strand_m.bottom_radius = .03; strand_m.height = 1.0; strand_m.radial_segments = 5
	crest = Node3D.new()
	add_child(crest)
	crest.top_level = true
	for i in N_HANDS:
		var a = i / float(N_HANDS) * TAU
		var piv = Node3D.new()
		piv.rotation.z = a - PI / 2
		piv.position = Vector3(cos(a), sin(a), 0) * 6.0
		crest.add_child(piv)
		var hand = MeshInstance3D.new()
		hand.mesh = hmesh
		hand.material_override = hm
		hand.scale = Vector3.ONE * 8.5 * G.rnd(.85, 1.1)
		hand.rotation_order = EULER_ORDER_XYZ
		hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(hand)
		# ponta decepada, carne viva
		var st_ = MeshInstance3D.new()
		st_.mesh = sph
		st_.material_override = stump
		st_.scale = Vector3(.95, .35, .95)
		piv.add_child(st_)
		# fio de sangue pendurado
		var strand = MeshInstance3D.new()
		strand.mesh = strand_m
		strand.material_override = stump
		strand.top_level = true
		piv.add_child(strand)
		# gotas que pingam
		var pt = CPUParticles3D.new()
		pt.mesh = drop_mesh
		pt.amount = 7
		pt.lifetime = 1.5
		pt.local_coords = false
		pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		pt.emission_sphere_radius = .35
		pt.direction = Vector3.DOWN
		pt.spread = 15
		pt.initial_velocity_min = .5
		pt.initial_velocity_max = 2.0
		pt.gravity = Vector3(0, -22, 0)
		pt.scale_amount_min = .7
		pt.scale_amount_max = 1.6
		pt.preprocess = 1.0
		piv.add_child(pt)
		crest_hands.append({"piv": piv, "hand": hand, "strand": strand, "pt": pt, "a": a, "ph": G.rnd(0, TAU), "tw": 0.0})

func _upd_crest(dt: float) -> void:
	if crest == null: return
	var c = center() + Vector3(0, H * .12, 0)
	if sk and chest_bone >= 0:
		c = (sk.global_transform * sk.get_bone_global_pose(chest_bone)).origin
	var fwd = Vector3(sin(rotation.y), 0, cos(rotation.y))
	crest.global_position = c - fwd * 3.0
	crest_spin += dt * crest_spd
	crest.global_basis = Basis(Vector3.UP, rotation.y) * Basis(Vector3.BACK, crest_spin)
	var rr = crest_r * (6.0 + sin(phase * 1.3) * .3)
	for hd in crest_hands:
		hd.piv.position = Vector3(cos(hd.a), sin(hd.a), 0) * rr
		# dedos se contorcem; de vez em quando um tranco
		if G.rng.randf() < dt * .4: hd.tw = 1.0
		hd.tw *= exp(-8 * dt)
		var flex = sin(phase * 2.2 + hd.ph) * .16 + crest_clench * .7 + hd.tw * .5
		hd.hand.rotation = Vector3(flex, sin(phase * 1.1 + hd.ph) * .2 + hd.tw * .3, sin(phase * 1.7 + hd.ph) * .08)
		# o fio de sangue pende da ponta para baixo e balança
		var base: Vector3 = hd.piv.global_position
		var L = 1.4 + .9 * sin(phase * 1.6 + hd.ph * 2.0)
		hd.strand.global_position = base + Vector3(0, -L * .5, 0)
		hd.strand.global_basis = Basis(Vector3.BACK, sin(phase * 2.0 + hd.ph) * .15)
		hd.strand.scale = Vector3(1, L, 1)

# ---------------- animação por trechos ----------------
func _play(s: String, spd: float) -> void:
	sec = s
	sspd = spd
	sdir = 1.0
	st = SEC[s][0]

func _anim(dt: float) -> void:
	if ap == null: return
	var a = SEC[sec][0]
	var b = SEC[sec][1]
	st += dt * sspd * sdir
	if sec == "idle":
		# repouso em vai-e-volta para não dar salto no laço
		if st > b: st = b; sdir = -1.0
		if st < a: st = a; sdir = 1.0
	elif st >= b:
		st = b
	ap.seek(st, true)

func _sec_done() -> bool:
	return st >= SEC[sec][1] - .001

func head_pos() -> Vector3:
	if sk and head_bone >= 0:
		return (sk.global_transform * sk.get_bone_global_pose(head_bone)).origin
	return global_position + Vector3(0, H * .88, 0)

func center() -> Vector3:
	return global_position + Vector3(0, H * .5, 0)

func is_head(p: Vector3) -> bool:
	return p.distance_to(head_pos()) < 4.5

func take_damage(dmg: float, src: String, _head: bool) -> bool:
	if not alive or inv: return false
	hp -= dmg
	flash = .08
	if hp <= 0:
		die(src, false)
		return true
	return false

func die(src: String, _head: bool) -> void:
	alive = false
	dying = true
	die_t = 0.0
	G.boss = null
	G.stats.kills += 1
	G.add_style(500, "DEICÍDIO")
	for g in gfx:
		if g.get("m") != null and is_instance_valid(g.m): g.m.queue_free()
	gfx.clear()
	ad = {"src": src}
	fired.clear()
	G.main.hitstop(.4)
	G.snd("clang", 0, .45)
	G.snd("angel", 0, .4)
	_play("convulse", .55)
	for i in 14:
		G.later(.3 + i * .22, func():
			if not is_instance_valid(self): return
			var c = center() + Vector3(G.rnd(-4, 4), G.rnd(-8, 9), G.rnd(-3, 3))
			G.blast(c, .55, src)
			G.emit("blood2", c, 24, 14, .3, 1.2))

func _upd_death(dt: float) -> void:
	die_t += dt
	# o sangue escoa
	if flood:
		flood_y -= dt * .12
		flood.global_position = Vector3(0, flood_y, -18)
	for f in falls:
		f.pt.emitting = false
		f.col.scale.x = max(.01, f.col.scale.x - dt * .5); f.col.scale.z = f.col.scale.x
	for hpj in hand_proj:
		if is_instance_valid(hpj.n): hpj.n.queue_free()
	hand_proj.clear()
	_anim(dt)
	G.shake = max(G.shake, .25)
	for m in body_mats:
		m.emission = Color(.6, .05, .03) * (.5 + .5 * sin(die_t * 30))
	if die_t > 3.4 and not fired.has("boom"):
		fired.boom = true
		G.blast(center(), 1.6, ad.get("src", "rev"))
		G.emit("blood2", center(), 120, 34, .4, 1.8)
		G.emit("white", center(), 80, 30, .35, 1.4)
		G.flash = 1.0
		G.snd("boom", 0, .5)
		G.main.banner("DEUS ESTÁ MORTO", "E VOCÊ O MATOU")
		for m in mats:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if G.mode == "deus": G.later(10.0, G.main.respawn_deus)
	if die_t > 3.4:
		var f = clamp((die_t - 3.4) / 1.4, 0.0, 1.0)
		global_position.y -= dt * 6 * f
		for m in mats:
			var c: Color = m.albedo_color
			c.a = 1.0 - f
			m.albedo_color = c
		if f >= 1: queue_free()

# ---------------- laço ----------------
func _physics_process(dt: float) -> void:
	if G.state != "play": return
	phase += dt
	if dying:
		_upd_death(dt)
		_upd_crest(dt)
		crest_spd += dt * 2.0
		crest_r = max(.2, crest_r - dt * .15)
		return
	if not alive: return
	if cine:
		_anim(dt)
		_upd_crest(dt)
		_fx(dt)
		return
	_anim(dt)
	# reação da crista ao golpe atual
	var tsp = .18 if not ph2 else .3
	var tcl = 0.0
	var trr = 1.0
	match att:
		"maos": tsp = .9; tcl = 1.0
		"convulsao", "ascend": tsp = 2.6; trr = 1.25
		"aureola": tsp = 1.4; trr = 1.12
		"sangue": tcl = .5
		"punhos": tsp = .6; tcl = .4
		"lagrimas", "mare": tsp = 1.2; trr = 1.1
		"geiser": tcl = .8
	# tremedeira de fúria: na fase 2 o corpo inteiro treme sem parar (mais forte ao atacar)
	var tk = 0.0
	if att == "ascend": tk = clamp(at / 2.6, 0.0, 1.0) * 1.3
	elif ph2: tk = .7 + (.5 if att != "" else 0.0)
	if tk > 0:
		model.position = Vector3(G.rnd(-1, 1), G.rnd(-1, 1) * .6, G.rnd(-1, 1)) * .32 * tk
		model.rotation = Vector3(G.rnd(-1, 1) * .018, G.rnd(-1, 1) * .025, G.rnd(-1, 1) * .03) * tk
		for hd in crest_hands:
			hd.piv.rotation.z = hd.a - PI / 2 + G.rnd(-1, 1) * .06 * tk
		if G.player.global_position.distance_to(global_position) < 40: G.shake = max(G.shake, .05 * tk)
		if G.rng.randf() < dt * 3 * tk: G.snd("hit", -24, G.rnd(.35, .5))
	else:
		model.position = Vector3.ZERO
		model.rotation = Vector3.ZERO
	crest_spd += (tsp - crest_spd) * (1.0 - exp(-2.5 * dt))
	crest_clench += (tcl - crest_clench) * (1.0 - exp(-5 * dt))
	crest_r += (trr - crest_r) * (1.0 - exp(-3 * dt))
	_upd_crest(dt)
	_fx(dt)
	if spawn_t > 0:
		spawn_t -= dt
		var u = clamp(1.0 - spawn_t / 3.0, 0.0, 1.0)
		global_position.y = lerp(70.0, BASE_Y, 1.0 - pow(1.0 - u, 3.0))
		_face(dt, 3.0)
		if spawn_t <= 0:
			G.shake = max(G.shake, 1.0)
			G.flash = max(G.flash, .5)
			G.snd("boom", -2, .5)
			G.emit("blood2", global_position, 60, 20, .3, 1.2)
		return
	flash -= dt
	if ph2: redk = min(1.0, redk + dt / 2.5)
	var base_col = Color(1.0, .95, .9).lerp(Color(.95, .12, .1), redk)
	var base_em = Color(.12, .08, .07).lerp(Color(.42, .0, .01), redk)
	for m in body_mats:
		m.albedo_color = base_col
		m.emission = Color(1, .3, .25) if flash > 0 else base_em * (1.0 + .25 * sin(phase * 4.0) * redk)
	_upd_blood(dt)
	_move(dt)
	_gfx(dt)
	if ph2 and G.rng.randf() < dt * 10.0:
		G.emit("blood2", center() + Vector3(G.rnd(-5, 5), G.rnd(-8, 6), G.rnd(-2, 2)), 1, 1, .25, 1.2, Vector3.ZERO, 16)
	if ph2 and G.rng.randf() < dt * 3.0:
		G.fx.smoke(head_pos() + Vector3(G.rnd(-4, 4), G.rnd(-2, 3), 0), Color(.2, 0, .01, .55), 1, 7.0, 2.5, 3.0)
	if not ascended and hp < max_hp * .5:
		ascended = true
		_attack("ascend")
	for th in [0.7, 0.35]:
		if hp < max_hp * th and not summoned.has(th) and att != "ascend":
			summoned[th] = true
			G.main.banner("DEUS CHAMA", "SUAS SERVAS")
			for i in 3: G.later(i * .4, func(): G.main.spawn_enemy("husk"))
	if att != "":
		at += dt
		_run(dt)
	else:
		cd -= dt
		if cd <= 0: _attack(_pick())

func _face(dt: float, k: float) -> void:
	var p = G.player.global_position
	rotation.y = lerp_angle(rotation.y, atan2(p.x - global_position.x, p.z - global_position.z), 1.0 - exp(-k * dt))

func _move(dt: float) -> void:
	# paira devagar em volta da arena, sempre de frente para o jogador
	ang += dt * (.09 if ph2 else .06)
	var R = 31.0
	var tx = cos(ang) * R
	var tz = sin(ang) * R
	var k = 1.0 - exp(-.5 * dt)
	global_position.x += (tx - global_position.x) * k
	global_position.z += (tz - global_position.z) * k
	global_position.y += (hy + sin(phase * .8) * 1.2 - global_position.y) * (1.0 - exp(-1.5 * dt))
	_face(dt, 2.5)

func _fx(dt: float) -> void:
	# auréola pulsando, brilho de fundo respirando
	var pulse = .5 + .5 * sin(phase * 3.0)
	for m in halo_mats:
		var c: Color = m.albedo_color
		m.albedo_color = Color(1.0 + pulse * .5 + (0.6 if att != "" else 0.0), .12, .1, c.a)
	for m in glow_mats:
		m.albedo_color = Color(1, .45 + .1 * pulse, .38, .35 + .25 * pulse + (.3 if att != "" else 0.0))

const ATTACKS := ["maos", "olhar", "sangue", "aureola", "dedo", "punhos", "convulsao", "lagrimas", "geiser", "mare"]
## só depois que ele sangra
const ATTACKS2 := ["sois", "redemoinho"]

func _pick() -> String:
	var opts = ["maos", "olhar", "sangue", "aureola", "dedo", "punhos"]
	if ph2: opts = ["maos", "olhar", "aureola", "dedo", "punhos", "convulsao", "mare", "mare", "lagrimas", "lagrimas", "geiser", "geiser", "sois", "sois", "redemoinho", "redemoinho"]
	opts.erase(last_att)
	return opts[G.rng.randi() % opts.size()]

func _once(k: String, t: float) -> bool:
	if at >= t and not fired.has(k):
		fired[k] = true
		return true
	return false

func _attack(k: String) -> void:
	if att != "" and k != "ascend": return
	if att != "": _end(false)
	att = k
	at = 0.0
	fired.clear()
	ad = {}
	if G.fx:
		var big = k == "ascend"
		G.fx.charge(head_pos(), Color(1, .1, .05) if ph2 else Color(1, .85, .55), 1.2 if big else .7, 14.0 if big else 8.0, (G.player.global_position - global_position).normalized())
	match k:
		"ascend":
			inv = true
			_play("convulse", 1.0)
			G.main.banner("DEUS SANGRA", "E AGORA ELE ESTÁ COM RAIVA")
			G.snd("angel", 0, .45); G.snd("charge", -2, .35)
		"maos":
			_play("reach", 1.15)
			ad.n = 8 if ph2 else 5
			ad.k = 0
			G.snd("angel", -6, .5)
		"olhar":
			ad.side = -1.0 if G.rng.randf() < .5 else 1.0
			G.snd("charge", -4, .6)
		"sangue":
			ad.n = 22 if ph2 else 14
			ad.k = 0
			G.snd("angel", -8, .7)
		"aureola":
			ad.n = 4 if ph2 else 3
			ad.k = 0
			G.snd("charge", -6, .8)
		"convulsao":
			_play("convulse", 1.2)
			ad.k = 0
			G.snd("angel", -2, .4)
		"punhos":
			ad.n = 7 if ph2 else 4
			ad.k = 0
			G.snd("angel", -6, .6)
		"lagrimas":
			_play("reach", .8)
			G.snd("angel", -2, .55)
		"geiser":
			ad.n = 7
			ad.k = 0
			G.snd("charge", -6, .5)
		"sois":
			_play("reach", .8)
			G.main.banner("SÓIS DE SANGUE", "")
			G.snd("angel", -2, .4); G.snd("charge", -4, .4)
		"redemoinho":
			G.main.banner("REDEMOINHO DE SANGUE", "")
			G.snd("whirl", 0, .4)
		"mare":
			var ax = 0 if G.rng.randf() < .5 else 2
			var sgn = -1.0 if G.rng.randf() < .5 else 1.0
			ad.ax = ax; ad.sgn = sgn
			ad.gap = clamp(G.player.global_position[2 - ax] + G.rnd(-14, 14), -32.0, 32.0)
			ad.pos = -46.0 * sgn
			G.snd("angel", -2, .4); G.snd("whoosh", 0, .3)
			G.main.banner("", "MARÉ DE SANGUE")
		"dedo":
			ad.n = 2 if ph2 else 1
			ad.k = 0
			G.snd("charge", -4, .45)

func _end(set_cd := true) -> void:
	if ad.has("mk") and is_instance_valid(ad.mk): ad.mk.queue_free()
	if ad.has("w") and is_instance_valid(ad.w): ad.w.queue_free()
	last_att = att
	att = ""
	inv = false
	if sec != "idle":
		if sec == "convulse": _play("recover", 1.4)
		else: _play("idle", 1.0)
	if set_cd: cd = 1.4 if ph2 else 2.4

func _ground_y(x: float, z: float) -> float:
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 6, z), Vector3(x, -2, z), 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else 0.0

func _ring(color: Color, op: float, inner := .88) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 4
	m.mesh = tm
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, op)
	mat.disable_fog = true
	m.material_override = mat
	G.world.add_child(m)
	if G.fx: G.fx.ring_overlay(m, color, m.material_override)
	return m

func _addm(c: Color, op: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(c.r, c.g, c.b, op)
	mat.disable_fog = true
	return mat

func _pc() -> Vector3:
	return G.player.global_position + Vector3(0, .9, 0)

# ---------------- ataques ----------------
func _run(dt: float) -> void:
	var p = G.player.global_position
	match att:
		"ascend":
			G.shake = max(G.shake, .3)
			if G.rng.randf() < dt * 30: G.emit("blood2", center() + Vector3(G.rnd(-5, 5), G.rnd(-9, 9), 0), 4, 8, .25, .8)
			if _once("burst", 2.6):
				ph2 = true
				G.flash = 1.0
				G.shake = max(G.shake, 1.3)
				G.snd("boom", 0, .45)
				_blood_ring(center(), 28, 22.0)
				_start_blood()
				G.fx.flash(head_pos(), Color(1, .08, .05), 40, 1.0)
				G.fx.ring_v(head_pos(), (p - global_position).normalized(), Color(1, .1, .05), 30, 1.1)
				G.fx.shock(Vector3(global_position.x, 0, global_position.z), Color(.9, .05, .04), 46, 1.4, "circle_03")
				for i in 14: G.fx.pillar(Vector3(cos(i * TAU / 14) * 30, 0, sin(i * TAU / 14) * 30 - 30), 2.0, 50, Color(.9, .05, .05), 1.0)
				var push = p - global_position; push.y = 0
				G.player.velocity += push.normalized() * 20 + Vector3(0, 8, 0)
			if _sec_done(): _end()
		"maos":
			# mãos esqueléticas brotam do chão onde você está
			if ad.k < ad.n and at > .6 + ad.k * (.32 if ph2 else .45):
				ad.k += 1
				var x = p.x + G.player.velocity.x * .45 + (0.0 if ad.k == 1 else G.rnd(-3, 3))
				var z = p.z + G.player.velocity.z * .45 + (0.0 if ad.k == 1 else G.rnd(-3, 3))
				x = clamp(x, -41.0, 41.0); z = clamp(z, -41.0, 41.0)
				var y = _ground_y(x, z)
				var mk = _ring(Color(1, .1, .05), .9)
				mk.position = Vector3(x, y + .08, z)
				mk.scale = Vector3(2.6, 1, 2.6)
				gfx.append({"kind": "mark", "m": mk, "x": x, "y": y, "z": z, "t": .75})
				G.fx.sigil(Vector3(x, y, z), 2.8, Color(1, .12, .06), .85, 1)
				G.snd("ping", -10, .45)
			if ad.k >= ad.n and at > .6 + ad.n * .45 + 1.2: _end()
		"olhar":
			# raio vermelho que sai da cabeça e varre o chão: pule por cima
			var hp_ = head_pos()
			var toward = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
			var dist = toward.length()
			toward = toward.normalized()
			var side = Vector3(toward.z, 0, -toward.x)
			var sweep = 1.6 if not ph2 else 1.25
			var u = 0.0
			if at < 1.0:
				u = 0.0
			else:
				u = clamp((at - 1.0) / sweep, 0.0, 1.0)
			if not ad.has("o"):
				ad.o = global_position
				ad.dist = dist
				ad.fwd = toward
				ad.side_v = side
			var span = 22.0
			var lat = lerp(-span, span, u) * ad.side
			var tgt = ad.o + ad.fwd * ad.dist + ad.side_v * lat
			tgt.y = _ground_y(tgt.x, tgt.z) + .7
			if at < 1.0:
				if int(at * 24) % 2 == 0: G.tracer(hp_, ad.o + ad.fwd * ad.dist - ad.side_v * span * ad.side + Vector3(0, .7, 0), .06, Color(1, .2, .15), .04)
			elif u < 1.0:
				var dirv = (tgt - hp_).normalized()
				var end = tgt + dirv * 6
				G.fx.beam(hp_, end, 1.4, Color(1, .1, .06), .06)
				if G.rng.randf() < dt * 20: G.fx.sprite(tgt, "scorch_0%d" % (1 + G.rng.randi() % 3), Color(1, .3, .1, .9), 2.0, 4.0, .3)
				G.emit("spark", tgt, 3, 9, .15, .35)
				G.emit("blood2", tgt, 1, 4, .3, .6)
				G.shake = max(G.shake, .12)
				if not fired.has("hit"):
					var pc = _pc()
					var ab = end - hp_
					var t = clamp((pc - hp_).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if pc.distance_to(hp_ + ab * t) < 1.3:
						fired.hit = true
						if G.hurt_player(28.0 if ph2 else 22.0): G.player.velocity += Vector3(0, 9, 0) + dirv * 8
				if _once("snd", 1.0): G.snd("beam", 0, .6)
			elif at > 1.0 + sweep + .4:
				if ph2 and not fired.has("again"):
					fired.again = true
					fired.erase("hit"); fired.erase("snd")
					ad.side = -ad.side
					ad.erase("o")
					at = .7
				else:
					_end()
		"sangue":
			# gotas de sangue caem do céu (são esferas: dá para rebater com F)
			if ad.k < ad.n and at > .5 + ad.k * .09:
				ad.k += 1
				var x = clamp(p.x + G.rnd(-9, 9) + G.player.velocity.x * .6, -41.0, 41.0)
				var z = clamp(p.z + G.rnd(-9, 9) + G.player.velocity.z * .6, -41.0, 41.0)
				if ad.k % 4 == 1: x = p.x; z = p.z
				var y = _ground_y(x, z)
				var mk = _ring(Color(.9, .05, .05), .7)
				mk.position = Vector3(x, y + .06, z)
				mk.scale = Vector3(1.1, 1, 1.1)
				gfx.append({"kind": "drop", "m": mk, "x": x, "y": y, "z": z, "t": .55})
				G.fx.sigil(Vector3(x, y, z), 1.2, Color(.9, .05, .05), .65, 1)
			if ad.k >= ad.n and at > .5 + ad.n * .09 + 1.4: _end()
		"aureola":
			# a auréola dispara anéis gigantes: os baixos você pula, os altos você desliza por baixo
			if ad.k < ad.n and at > .7 + ad.k * .75:
				ad.k += 1
				var high = ph2 and ad.k % 2 == 0
				var m = _ring(Color(1, .1, .05), .85, .9)
				var gy = 0.9 if not high else 2.7
				m.position = Vector3(global_position.x, gy, global_position.z)
				gfx.append({"kind": "wave", "m": m, "r": 3.0, "y": gy, "x": global_position.x, "z": global_position.z, "hit": false, "high": high})
				G.snd("boomlite", -4, .5)
				G.flash = max(G.flash, .15)
				G.fx.flash(head_pos(), Color(1, .2, .08), 12, .4)
			if ad.k >= ad.n and at > .7 + ad.n * .75 + 1.2: _end()
		"convulsao":
			# o corpo se contorce e espirra anéis de sangue em todas as direções
			if at > .4 and at < 3.8 and int(at / .55) != int((at - dt) / .55):
				_blood_ring(head_pos(), 14 if not ph2 else 20, 15.0)
				G.shake = max(G.shake, .4)
			if _sec_done(): _end()
		"punhos":
			# as mãos da crista se soltam e voam em você
			if ad.k < ad.n and at > .4 + ad.k * (.38 if ph2 else .5):
				var avail = []
				for hd in crest_hands:
					if hd.hand.visible: avail.append(hd)
				if avail.size() > 0:
					ad.k += 1
					var hd = avail[G.rng.randi() % avail.size()]
					_launch_hand(hd)
				else:
					ad.k = ad.n
			if ad.k >= ad.n and at > .4 + ad.n * .5 + 1.4: _end()
		"lagrimas":
			# lágrimas de sangue em espiral saindo dos olhos
			var hp2 = head_pos()
			if at > .5 and at < 3.6 and int(at / .1) != int((at - dt) / .1):
				for arm in 3:
					var a = at * 2.3 + arm * TAU / 3.0
					var dir = Vector3(cos(a), -.18, sin(a)).normalized()
					G.main.spawn_orb(hp2 + dir * 2.0, dir * 17.0)
					var pr = G.projs.back()
					pr.mat.albedo_color = Color(.85, .04, .04)
					pr.life = 6.0
				if int(at / .3) != int((at - dt) / .3):
					G.snd("eshot", -12, .6)
					G.fx.flash(hp2, Color(1, .1, .05), 5, .3)
			if at > 4.2: _end()
		"sois":
			# SÓIS DE SANGUE: seis sóis vermelhos nascem da auréola; um a um, cada um marca você e despeja um raio
			var hp3 = head_pos()
			if _once("make", .3):
				ad.s = []
				for i in 6:
					var sm = MeshInstance3D.new(); var q = QuadMesh.new(); q.size = Vector2.ONE * 5; sm.mesh = q
					sm.material_override = G.fx.mat("light_01", Color(1, .1, .05, 1), true, 1)
					var core = MeshInstance3D.new(); var q2 = QuadMesh.new(); q2.size = Vector2.ONE * 3; core.mesh = q2
					core.material_override = G.fx.mat("star_09", Color(1, .6, .5, 1), true, 1); sm.add_child(core)
					G.world.add_child(sm)
					sm.global_position = hp3
					ad.s.append({"n": sm, "a": i * TAU / 6.0, "t": 1.4 + i * .55})
			if ad.has("s"):
				for i in ad.s.size():
					var o = ad.s[i]
					if not is_instance_valid(o.n): continue
					var a = o.a + at * .8
					var k = clamp((at - .3) / .8, 0.0, 1.0)
					o.n.global_position = hp3.lerp(hp3 + Vector3(cos(a) * 16, 6 + sin(a * 2.0) * 2, sin(a) * 16), k)
					if at > o.t - .7 and not o.has("sg"):
						o.c = Vector3(p.x, _ground_y(p.x, p.z), p.z)
						o.sg = G.fx.sigil(o.c, 3.2, Color(1, .06, .05), .8, 0)
					if o.has("sg") and at < o.t - .15:
						o.c = o.c.lerp(Vector3(p.x, _ground_y(p.x, p.z), p.z), 1.0 - exp(-4.0 * dt))
						if is_instance_valid(o.sg): o.sg.global_position = o.c + Vector3(0, .09, 0)
					if at >= o.t and not o.has("shot"):
						o.shot = true
						var c: Vector3 = o.c
						G.fx.beam(o.n.global_position, c, 2.6, Color(1, .08, .05), .45)
						G.fx.flash(c + Vector3(0, 1, 0), Color(1, .15, .1), 12, .45)
						G.fx.shock(c, Color(.9, .05, .04), 9, .55)
						G.fx.burst(c + Vector3(0, .5, 0), Color(.55, 0, .02), 18, 12, 1.0, .8, "circle_05", 20.0, true)
						G.emit("blood2", c + Vector3(0, .5, 0), 20, 14, .3, .8)
						G.snd("beam", -4, .5); G.shake = max(G.shake, .5)
						if Vector2(p.x - c.x, p.z - c.z).length() < 3.3 and p.y - c.y < 5.0:
							if G.hurt_player(26.0): G.player.velocity += Vector3(0, 11, 0)
						var nn = o.n
						G.later(.3, func(): if is_instance_valid(nn): nn.queue_free())
			if at > 1.4 + 6 * .55 + .6:
				for o in ad.get("s", []):
					if is_instance_valid(o.n): o.n.queue_free()
				_end()
		"redemoinho":
			# REDEMOINHO DE SANGUE: um vórtice abre onde você está e puxa; ao fechar, vira um gêiser gigante. Dê dash!
			if _once("open", .2):
				ad.c = Vector3(p.x, max(_ground_y(p.x, p.z), flood_y) + .12, p.z)
				ad.v = []
				for i in 3:
					var vm = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2.ONE; vm.mesh = pm
					vm.material_override = G.fx.mat(["twirl_01", "twirl_02", "twirl_03"][i], Color(.8, .02, .04, .9), false, 0)
					G.world.add_child(vm); vm.global_position = ad.c + Vector3(0, i * .02, 0)
					vm.scale = Vector3.ONE * (16 - i * 4)
					ad.v.append(vm)
				G.fx.sigil(ad.c, 9.0, Color(1, .05, .05), 2.4, 1)
			if ad.has("v"):
				for i in ad.v.size():
					if is_instance_valid(ad.v[i]): ad.v[i].rotation.y += dt * (3.0 + i * 1.5)
				if at < 2.4:
					var to = ad.c - p; to.y = 0
					var d = to.length()
					if d < 13.0: G.player.velocity += to.normalized() * (14.0 * (1.0 - d / 13.0) + 4.0) * dt * 4.0
					if G.rng.randf() < dt * 30: G.emit("blood2", ad.c + Vector3(G.rnd(-6, 6), .3, G.rnd(-6, 6)), 1, 3, .25, .5, Vector3(0, 1, 0), 4)
				if _once("boom", 2.4):
					for v in ad.v: if is_instance_valid(v): v.queue_free()
					G.fx.pillar(ad.c, 5.0, 45, Color(.9, .03, .03), .9)
					G.fx.flash(ad.c + Vector3(0, 3, 0), Color(1, .1, .05), 22, .6)
					G.fx.shock(ad.c, Color(.9, .04, .03), 20, .8, "circle_03")
					G.emit("blood2", ad.c + Vector3(0, 1, 0), 120, 28, .45, 1.4)
					G.snd("boom", 0, .5); G.snd("porrada", -4, .7); G.shake = max(G.shake, 1.0)
					var dd = Vector2(p.x - ad.c.x, p.z - ad.c.z).length()
					if dd < 6.5 and G.hurt_player(38.0): G.player.velocity += Vector3(0, 16, 0)
			if at > 3.0: _end()
		"geiser":
			# gêiseres de sangue perseguem você
			if ad.k < ad.n and at > .4 + ad.k * .34:
				ad.k += 1
				var x = clamp(p.x + G.player.velocity.x * .5, -41.0, 41.0)
				var z = clamp(p.z + G.player.velocity.z * .5, -41.0, 41.0)
				var y = _ground_y(x, z)
				var mk = _ring(Color(.9, .05, .05), .9)
				mk.position = Vector3(x, max(y, flood_y) + .1, z)
				mk.scale = Vector3(2.2, 1, 2.2)
				gfx.append({"kind": "gmark", "m": mk, "x": x, "y": y, "z": z, "t": .6})
				G.fx.sigil(Vector3(x, max(y, flood_y), z), 2.4, Color(1, .05, .05), .7, 0)
				G.snd("ping", -10, .4)
			if ad.k >= ad.n and at > .4 + ad.n * .34 + 1.4: _end()
		"mare":
			# muralha de sangue atravessa a arena; corra para a abertura
			var ax: int = ad.ax
			var other = 2 - ax
			if not ad.has("w"):
				var root_ = Node3D.new()
				G.world.add_child(root_)
				var wm: StandardMaterial3D = preload("res://scripts/ceu_mats.gd").blood().duplicate()
				wm.cull_mode = BaseMaterial3D.CULL_DISABLED
				wm.emission = Color(.2, 0, .01)
				for side in [-1, 1]:
					var lo = -46.0 if side < 0 else ad.gap + 3.6
					var hi = ad.gap - 3.6 if side < 0 else 46.0
					if hi - lo < .5: continue
					var b = MeshInstance3D.new()
					var bm = BoxMesh.new()
					bm.size = Vector3(1.6, 2.6, hi - lo) if ax == 0 else Vector3(hi - lo, 2.6, 1.6)
					b.mesh = bm
					b.material_override = wm
					var mid = (lo + hi) * .5
					b.position = Vector3(0, 1.3, mid) if ax == 0 else Vector3(mid, 1.3, 0)
					root_.add_child(b)
				ad.w = root_
				ad.wm = wm
				# marca a abertura com um selo de luz
				var gq = Vector3.ZERO; gq[other] = ad.gap
				G.fx.sigil(Vector3(gq.x, 0, gq.z), 3.6, Color(1, .85, .6), 4.0, 1)
			var spd = 0.0 if at < 1.0 else 15.0
			ad.pos += ad.sgn * spd * dt
			var wp = Vector3.ZERO
			wp[ax] = ad.pos
			ad.w.position = wp
			ad.w.scale.y = clamp(at / 1.0, .05, 1.0) * (1.0 + .08 * sin(phase * 9))
			if at > 1.0 and G.rng.randf() < .8:
				var q = Vector3.ZERO
				q[ax] = ad.pos; q[other] = G.rnd(-44, 44); q.y = 2.6
				if abs(q[other] - ad.gap) > 3.6:
					G.emit("blood2", q, 2, 6, .3, .7)
					if G.rng.randf() < .5: G.fx.sprite(q + Vector3(0, .4, 0), "smoke_0%d" % (1 + G.rng.randi() % 8), Color(.5, .02, .03, .8), 2.0, 4.5, .6, 1.0, false)
			if not fired.has("hit") and at > 1.0:
				var pp = G.player.global_position
				if abs(pp[ax] - ad.pos) < 1.4 and abs(pp[other] - ad.gap) > 3.4 and pp.y < 2.4:
					fired.hit = true
					var push = Vector3.ZERO; push[ax] = ad.sgn * 18.0
					if G.hurt_player(26.0): G.player.velocity += push + Vector3(0, 7, 0)
			if abs(ad.pos) > 47.0:
				ad.w.queue_free()
				ad.erase("w")
				_end()
		"dedo":
			# um círculo persegue você e depois cai uma coluna de luz do céu
			if not ad.has("mk"):
				var mk = _ring(Color(1, .9, .8), .8, .93)
				mk.position = Vector3(p.x, _ground_y(p.x, p.z) + .1, p.z)
				mk.scale = Vector3(4, 1, 4)
				ad.mk = mk
				ad.pos = Vector3(p.x, 0, p.z)
			var lock = 1.6 if not ph2 else 1.2
			if at < lock:
				ad.pos = ad.pos.lerp(Vector3(p.x, 0, p.z), 1.0 - exp(-4 * dt))
				ad.mk.position = Vector3(ad.pos.x, _ground_y(ad.pos.x, ad.pos.z) + .1, ad.pos.z)
				ad.mk.scale = Vector3.ONE * (4.0 + sin(at * 20) * .15)
				ad.mk.scale.y = 1
			if _once("lock", lock):
				G.snd("beep", -4, .5)
				ad.mk.material_override.albedo_color = Color(1, .2, .1, .9)
			if _once("fall", lock + .45):
				var q = ad.mk.position
				var col = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 4.5; cm.bottom_radius = 4.0; cm.height = 80; cm.radial_segments = 16
				col.mesh = cm
				col.material_override = _addm(Color(1, .85, .7), .85)
				G.world.add_child(col)
				col.position = q + Vector3(0, 40, 0)
				gfx.append({"kind": "pillar", "m": col, "t": .6})
				G.emit("white", q, 60, 24, .35, 1.0)
				G.emit("dust", q, 40, 18, .5, 1.2)
				G.fx.pillar(q, 4.5, 90, Color(1, .9, .7), .8)
				G.fx.flash(q + Vector3(0, 3, 0), Color(1, .9, .7), 26, .7)
				G.fx.shock(q, Color(1, .85, .6), 22, .9, "circle_03")
				G.fx.smoke(q, Color(.7, .65, .6, .5), 12, 9, 2.4)
				G.flash = max(G.flash, .5); G.shake = max(G.shake, 1.1)
				G.snd("boom", 0, .6); G.snd("slam", 0, .7)
				G.main.world_flash(q + Vector3(0, 2, 0), 24)
				if Vector2(p.x - q.x, p.z - q.z).length() < 4.6 and G.hurt_player(40.0 if ph2 else 34.0):
					G.player.velocity += Vector3(0, 12, 0)
				ad.mk.queue_free()
				ad.k += 1
				if ad.k < ad.n:
					ad.erase("mk")
					fired.erase("lock"); fired.erase("fall")
					at = .5
			if ad.k >= ad.n and at > lock + 1.3: _end()

func _blood_ring(c: Vector3, n: int, spd: float) -> void:
	var off = G.rnd(0, TAU)
	if G.fx:
		G.fx.ring_v(c, Vector3.UP, Color(1, .08, .05), 10, .5)
		G.fx.flash(c, Color(1, .15, .08), 7, .35)
		G.fx.burst(c, Color(.55, 0, .02), 18, 16, 1.0, .8, "circle_05", 10.0, true)
	for i in n:
		var a = off + i / float(n) * TAU
		var dir = Vector3(cos(a), G.rnd(-.25, .05), sin(a)).normalized()
		G.main.spawn_orb(c + dir * 2.0, dir * spd)
		var pr = G.projs.back()
		pr.mat.albedo_color = Color(.85, .04, .04)
		pr.life = 5.0

func _gfx(dt: float) -> void:
	var p: Vector3 = G.player.global_position
	for g in gfx:
		match g.kind:
			"mark":
				g.t -= dt
				g.m.material_override.albedo_color.a = .5 + .45 * sin(g.t * 35)
				if g.t <= 0:
					g.dead = true
					_hand(Vector3(g.x, g.y, g.z))
					G.fx.shock(Vector3(g.x, g.y, g.z), Color(1, .15, .05), 5, .45)
					G.fx.burst(Vector3(g.x, g.y + .5, g.z), Color(.5, 0, .02), 12, 9, .9, .7, "circle_05", 18.0, true)
					if Vector2(p.x - g.x, p.z - g.z).length() < 2.8 and abs(p.y - g.y) < 3.0:
						if G.hurt_player(25.0 if ph2 else 20.0): G.player.velocity += Vector3(0, 13, 0)
			"hand":
				g.t += dt
				var u = clamp(g.t / .12, 0.0, 1.0)
				var out = clamp((g.t - .7) / .35, 0.0, 1.0)
				g.m.position.y = g.y - 5.2 + 5.2 * u - 5.5 * out
				if out >= 1: g.dead = true
			"drop":
				g.t -= dt
				if g.t <= 0:
					g.dead = true
					var top = Vector3(g.x, g.y + 26, g.z)
					G.main.spawn_orb(top, Vector3(0, -34, 0))
					var pr = G.projs.back()
					pr.mat.albedo_color = Color(.85, .04, .04)
					pr.life = 2.0
					var gy = g.y
					var gx = g.x; var gz = g.z
					G.later(.72, func():
						G.fx.burst(Vector3(gx, max(gy, flood_y) + .3, gz), Color(.6, 0, .02), 10, 8, .8, .6, "circle_05", 18.0, true)
						G.fx.shock(Vector3(gx, max(gy, flood_y), gz), Color(.9, .05, .05), 3.0, .35))
			"wave":
				g.r += 22 * dt
				g.m.scale = Vector3(g.r, 2.0, g.r)
				g.m.material_override.albedo_color.a = max(0.0, .85 - g.r / 80.0)
				var d = Vector2(p.x - g.x, p.z - g.z).length()
				var py = p.y + .9
				var hitband = abs(py - g.y) < (1.1 if not g.high else 1.3)
				if g.high: hitband = py > 1.9 and not G.player.sliding
				if not g.hit and abs(d - g.r) < 1.0 and hitband:
					g.hit = true
					if G.hurt_player(20.0): G.player.velocity += Vector3(p.x - g.x, 0, p.z - g.z).normalized() * 10 + Vector3(0, 6, 0)
				if g.r > 75: g.dead = true
			"gmark":
				g.t -= dt
				g.m.material_override.albedo_color.a = .5 + .45 * sin(g.t * 35)
				if g.t <= 0:
					g.dead = true
					var col = MeshInstance3D.new()
					var cm = CylinderMesh.new()
					cm.top_radius = .9; cm.bottom_radius = 1.8; cm.height = 1.0; cm.radial_segments = 12
					col.mesh = cm
					col.material_override = _blood_mat()
					G.world.add_child(col)
					var gy = max(g.y, flood_y)
					col.position = Vector3(g.x, gy, g.z)
					gfx.append({"kind": "geyser", "m": col, "t": 0.0, "y": gy})
					G.emit("blood2", Vector3(g.x, gy + 1, g.z), 30, 16, .35, 1.2)
					G.fx.pillar(Vector3(g.x, gy, g.z), 1.6, 12, Color(.9, .04, .04), .5)
					G.snd("slam", -6, 1.2)
					if Vector2(p.x - g.x, p.z - g.z).length() < 2.4 and abs(p.y - g.y) < 4.0:
						if G.hurt_player(22.0): G.player.velocity += Vector3(0, 16, 0)
			"geyser":
				g.t += dt
				var hgt = 15.0 * clamp(g.t / .15, 0.0, 1.0) * (1.0 - clamp((g.t - .7) / .5, 0.0, 1.0))
				g.m.scale = Vector3(1.0 + sin(g.t * 30) * .08, max(.01, hgt), 1.0 + cos(g.t * 27) * .08)
				g.m.position.y = g.y + hgt * .5
				if G.rng.randf() < .7: G.emit("blood2", Vector3(g.m.position.x, g.y + hgt, g.m.position.z), 3, 8, .3, .8)
				if g.t > 1.2: g.dead = true
			"pillar":
				g.t -= dt
				var f = clamp(g.t / .6, 0.0, 1.0)
				g.m.scale = Vector3(f, 1, f)
				g.m.material_override.albedo_color.a = .85 * f
				if g.t <= 0: g.dead = true
	for g in gfx:
		if g.get("dead", false) and g.get("m") != null and is_instance_valid(g.m):
			g.m.queue_free()
	gfx = gfx.filter(func(g): return not g.get("dead", false))

# ---------------- sangue: cachoeiras, inundação e mãos voadoras ----------------
var _bm: StandardMaterial3D
func _blood_mat() -> StandardMaterial3D:
	if _bm == null:
		_bm = preload("res://scripts/ceu_mats.gd").blood().duplicate()
		_bm.emission = Color(.2, 0, .01)
	return _bm

func _start_blood() -> void:
	# cachoeiras: das mãos de baixo da crista e dos olhos
	var drop = SphereMesh.new()
	drop.radius = .22; drop.height = .9; drop.radial_segments = 6; drop.rings = 3
	drop.material = _blood_mat()
	var srcs = []
	var n = crest_hands.size()
	for i in [int(n * .62), int(n * .7), int(n * .8), int(n * .88)]:
		srcs.append(crest_hands[i % n].piv)
	srcs.append(null) # olho esquerdo
	srcs.append(null) # olho direito
	for k in srcs.size():
		var pt = CPUParticles3D.new()
		pt.mesh = drop
		pt.amount = 140
		pt.lifetime = 1.6
		pt.local_coords = false
		pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		pt.emission_sphere_radius = .45
		pt.direction = Vector3.DOWN
		pt.spread = 6
		pt.initial_velocity_min = 2.0
		pt.initial_velocity_max = 5.0
		pt.gravity = Vector3(0, -26, 0)
		pt.scale_amount_min = .8
		pt.scale_amount_max = 1.8
		pt.top_level = true
		add_child(pt)
		var col = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = .35; cm.bottom_radius = .7; cm.height = 1.0; cm.radial_segments = 8
		col.mesh = cm
		var cmat = _blood_mat().duplicate()
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cmat.albedo_color = Color(.55, 0, .03, .75)
		col.material_override = cmat
		col.top_level = true
		add_child(col)
		falls.append({"src": srcs[k], "eye": k - 4, "pt": pt, "col": col, "ph": G.rnd(0, TAU)})
	# a arena começa a encher de sangue
	flood = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(94, 132)   # salão inteiro, incluindo a área do altar e do trono
	pm.subdivide_width = 24; pm.subdivide_depth = 32
	flood.mesh = pm
	flood_mat = _blood_mat().duplicate()
	flood_mat.albedo_color = Color(.34, 0, .02)
	flood_mat.emission = Color(.16, 0, .01)
	flood_mat.roughness = .05
	flood_mat.metallic = .55
	flood.material_override = flood_mat
	flood.top_level = true
	flood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flood)
	flood.global_position = Vector3(0, flood_y, -18)
	for hd in crest_hands: hd.pt.amount = 14

func _upd_blood(dt: float) -> void:
	var hp2 = head_pos()
	var fwd = Vector3(sin(rotation.y), 0, cos(rotation.y))
	var right = Vector3(fwd.z, 0, -fwd.x)
	for f in falls:
		var src: Vector3
		if f.src != null: src = f.src.global_position
		else: src = hp2 + right * (f.eye * 2 - 1) * .9 + fwd * 1.2
		f.pt.global_position = src
		var gy = max(flood_y, 0.0)
		var L = max(.5, src.y - gy)
		f.col.global_position = Vector3(src.x, gy + L * .5, src.z)
		var w = 1.0 + .15 * sin(phase * 7 + f.ph)
		f.col.scale = Vector3(w, L, w)
		if G.rng.randf() < dt * 10:
			G.emit("blood2", Vector3(src.x, gy + .3, src.z), 3, 7, .3, .7)
	if flood:
		flood_y = min(flood_t, flood_y + dt * .1)
		flood.global_position = Vector3(0, flood_y + sin(phase * 1.3) * .03, -18)
		flood_mat.emission = Color(.16, 0, .01) * (1.0 + .3 * sin(phase * 2.0))
	# mãos voadoras
	for hpj in hand_proj:
		hpj.t += dt
		var n: Node3D = hpj.n
		var to = _pc() - n.global_position
		if hpj.t < .9:
			hpj.v = hpj.v.lerp(to.normalized() * 26.0, 1.0 - exp(-2.5 * dt))
		n.global_position += hpj.v * dt
		n.look_at(n.global_position + hpj.v, Vector3.UP, true)
		n.rotate_object_local(Vector3.RIGHT, PI / 2)
		if G.rng.randf() < .8: G.emit("blood2", n.global_position, 1, 2, .25, .6)
		var q = n.global_position
		var hitp = q.distance_to(_pc()) < 2.4
		if hitp or G.in_solid(q) or q.y < max(flood_y, 0.0) + .3 or hpj.t > 4.0:
			hpj.dead = true
			G.emit("blood2", q, 40, 14, .35, 1.0)
			G.fx.flash(q, Color(1, .2, .1), 9, .4)
			G.fx.shock(Vector3(q.x, max(_ground_y(q.x, q.z), flood_y), q.z), Color(1, .1, .05), 9, .5)
			G.snd("slam", -6, 1.4)
			if q.distance_to(_pc()) < 4.0 and G.hurt_player(18.0):
				G.player.velocity += (G.player.global_position - q).normalized() * 10 + Vector3(0, 6, 0)
			n.queue_free()
			var hd = hpj.hd
			G.later(3.0, func():
				if is_instance_valid(self) and alive:
					hd.hand.visible = true
					hd.hand.scale = Vector3.ONE * .5)
	hand_proj = hand_proj.filter(func(x): return not x.get("dead", false))
	for hd in crest_hands:
		if hd.hand.visible and hd.hand.scale.x < 8.0:
			hd.hand.scale = hd.hand.scale.lerp(Vector3.ONE * 8.5, 1.0 - exp(-4 * dt))

func _launch_hand(hd: Dictionary) -> void:
	var n = Node3D.new()
	G.world.add_child(n)
	var copy = MeshInstance3D.new()
	copy.mesh = hd.hand.mesh
	copy.material_override = hd.hand.material_override
	copy.scale = Vector3.ONE * 8.5
	copy.position = Vector3(0, -2.5, 0)
	n.add_child(copy)
	n.global_position = hd.piv.global_position
	hd.hand.visible = false
	var out = (hd.piv.global_position - (crest.global_position)).normalized()
	hand_proj.append({"n": n, "v": out * 14.0 + Vector3(0, 4, 0), "t": 0.0, "hd": hd})
	G.fx.attach_glow(n, Color(1, .15, .08, .8), 7.0, true, "light_01")
	G.fx.flash(hd.piv.global_position, Color(1, .3, .15), 6, .35)
	G.snd("whoosh", -4, .7)
	G.emit("blood2", hd.piv.global_position, 20, 10, .3, .8)

# mão esquelética que irrompe do chão (dedos de osso)
var _bone_mat: StandardMaterial3D
func _hand(q: Vector3) -> void:
	if _bone_mat == null:
		_bone_mat = StandardMaterial3D.new()
		_bone_mat.albedo_color = Color(.16, .13, .13)
		_bone_mat.roughness = .4
		_bone_mat.emission_enabled = true
		_bone_mat.emission = Color(.25, .02, .02)
	var hn = Node3D.new()
	G.world.add_child(hn)
	hn.position = q
	hn.rotation.y = G.rnd(0, TAU)
	for i in 5:
		var a = (i - 2) * .38
		var f = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = .05; cm.bottom_radius = .32; cm.height = 4.4 if i != 0 else 3.2; cm.radial_segments = 6; cm.rings = 1
		f.mesh = cm
		f.material_override = _bone_mat
		f.position = Vector3(sin(a) * 1.3, cm.height * .5, cos(a) * .6 - .3)
		f.rotation = Vector3(-.35 + abs(a) * .2, 0, -a * .55)
		hn.add_child(f)
	var palm = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(2.4, 1.2, 1.4)
	palm.mesh = bm; palm.material_override = _bone_mat; palm.position.y = .2
	hn.add_child(palm)
	gfx.append({"kind": "hand", "m": hn, "t": 0.0, "y": q.y})
	G.emit("dust", q, 26, 12, .45, 1.0)
	G.emit("blood2", q + Vector3(0, .5, 0), 18, 12, .25, .8)
	G.fx.sprite(q + Vector3(0, .1, 0), "dirt_03", Color(.3, .05, .04, .9), 2.0, 6.0, 1.4, 0.0, false, Vector3.UP)
	G.fx.flash(q + Vector3(0, 1, 0), Color(1, .25, .1), 5, .35)
	G.snd("slam", -4, .9)
	G.shake = max(G.shake, .3)
