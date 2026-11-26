extends CharacterBody3D
## Inimigos comuns: "husk" (corredor corpo-a-corpo), "brute" (brutamonte) e "drone" (voador que atira esferas).

var kind = "husk"
var hp = 60.0
var max_hp = 60.0
var r = 0.5
var h = 2.2
var speed = 7.0
var fly = false
var alive = true
var is_boss = false
var dummy = false
var home = Vector3.ZERO
var spawn_t = 0.6
var cd = 1.5
var wind = 0.0
var swing = 0.0
var flash = 0.0
var phase = 0.0
var seed_ = 0.0
var burn = 0.0
var burn_tick = 0.0
var lost_t = 0.0
var base_scale = 1.0

var mats: Array = []
var legs: Array = []
var arms: Array = []
var vis: Node3D
var ring: MeshInstance3D
var core: Node3D
var eye: MeshInstance3D
var mark: MeshInstance3D
# Ceifadora (corredor corpo a corpo com esqueleto)
var ceif = null
var atk = ""
var at = 0.0
var atk_hit = false
var cyc = 0.0
var fl = 0.0
var lunge_dir = Vector3.ZERO
var last_atk = ""
# Anjo Caído (modelo com animações do Blender)
var caida: Node3D = null
var cap_ap: AnimationPlayer = null
var jump_to := Vector3.ZERO
var jump_from := Vector3.ZERO

func setup(k: String, pos: Vector3, is_dummy := false) -> void:
	kind = k
	dummy = is_dummy
	phase = G.rnd(0, 10)
	seed_ = G.rnd(0, 10)
	cd = G.rnd(1.0, 2.2)
	collision_layer = 2
	collision_mask = 1
	vis = Node3D.new()
	add_child(vis)
	var shape = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	match kind:
		"drone":
			hp = 45; r = 0.9; h = 1.6; speed = 9; fly = true
			_build_drone()
			var sp = SphereShape3D.new()
			sp.radius = 0.95
			shape.shape = sp
		"caida":
			hp = 320; r = 0.6; h = 2.8; speed = 4.4
			_build_caida()
			cap.radius = 0.6; cap.height = 2.8
			shape.shape = cap
			shape.position.y = 1.4
		"brute":
			hp = 260; r = 0.85; h = 3.7; speed = 4.6; base_scale = 1.7
			_build_husk(true)
			cap.radius = 0.85; cap.height = 3.7
			shape.shape = cap
			shape.position.y = 1.85
		_:
			hp = 70; r = 0.5; h = 2.2; speed = 5.2
			ceif = preload("res://scripts/ceifadora.gd").new()
			vis.add_child(ceif)
			ceif.build()
			mats = ceif.mats
			cap.radius = 0.5; cap.height = 2.3
			shape.shape = cap
			shape.position.y = 1.15
	add_child(shape)
	max_hp = hp
	position = pos
	if fly:
		position.y = 6.0
	home = position
	vis.scale = Vector3.ONE * 0.01

func _box(sz: Vector3, mat: Material, p: Vector3, parent: Node3D) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	m.mesh = bm
	m.material_override = mat
	m.position = p
	parent.add_child(m)
	return m

const CAIDA_SC := 2.75
const CAIDA_SCN := preload("res://caida/anjo_caido.glb")
func _build_caida() -> void:
	caida = CAIDA_SCN.instantiate()
	caida.scale = Vector3.ONE * CAIDA_SC
	vis.add_child(caida)
	for n in caida.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m == null: continue
			m = m.duplicate()
			# anjo caído: ouro sujo e pele acinzentada
			m.albedo_color = Color(.78, .66, .62)
			mi.set_surface_override_material(i, m)
			mats.append(m)
	cap_ap = caida.find_children("*", "AnimationPlayer", true, false)[0]
	cap_ap.get_animation("desfile").loop_mode = Animation.LOOP_LINEAR
	cap_ap.play("desfile")

func _build_husk(brute: bool) -> void:
	var skin = G.lit(Color("4b2440") if brute else Color("7a2b22"))
	var dark = G.lit(Color("1c0c18") if brute else Color("2b1212"))
	mats = [skin, dark]
	var eyem = G.unshaded(Color("ffd23a"))
	var root = Node3D.new()
	vis.add_child(root)
	if brute:
		root.scale = Vector3.ONE * 1.7
	_box(Vector3(.8, .9, .5), skin, Vector3(0, 1.35, 0), root)
	_box(Vector3(.84, .25, .54), dark, Vector3(0, .98, 0), root)
	_box(Vector3(.5, .5, .5), skin, Vector3(0, 2.05, 0), root)
	for s in [-1, 1]:
		_box(Vector3(.12, .06, .02), eyem, Vector3(s * .12, 2.08, .26), root)
	for s in [-1, 1]:
		var lp = Node3D.new()
		lp.position = Vector3(s * .2, .9, 0)
		root.add_child(lp)
		_box(Vector3(.26, .9, .26), dark, Vector3(0, -.45, 0), lp)
		legs.append(lp)
		var ap = Node3D.new()
		ap.position = Vector3(s * .53, 1.75, 0)
		root.add_child(ap)
		_box(Vector3(.22, .85, .22), skin, Vector3(0, -.42, 0), ap)
		_box(Vector3(.27, .2, .27), dark, Vector3(0, -.88, 0), ap)
		arms.append(ap)

func _build_drone() -> void:
	var metal = G.lit(Color("5c606c"), 0.5, 0.4)
	mats = [metal]
	core = Node3D.new()
	vis.add_child(core)
	var oct = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(1.2, 0.9, 1.2)
	oct.mesh = pm
	oct.material_override = metal
	core.add_child(oct)
	var oct2 = MeshInstance3D.new()
	oct2.mesh = pm
	oct2.material_override = metal
	oct2.rotation.x = PI
	oct2.position.y = -0.9
	core.add_child(oct2)
	oct.position.y = 0.45
	_box(Vector3(.3, .3, 1.8), metal, Vector3.ZERO, core)
	eye = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	eye.mesh = sm
	eye.material_override = G.unshaded(Color("ff3020"))
	eye.position = Vector3(0, 0, .62)
	core.add_child(eye)
	ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 1.03
	tm.outer_radius = 1.17
	ring.mesh = tm
	ring.material_override = G.lit(Color("8a2a1a"))
	vis.add_child(ring)

func center() -> Vector3:
	if fly:
		return global_position
	return global_position + Vector3(0, h * 0.5, 0)

func is_head(p: Vector3) -> bool:
	if fly:
		return eye != null and p.distance_to(eye.global_position) < 0.45
	return p.y > global_position.y + h * 0.82

func take_damage(dmg: float, src: String, head: bool) -> bool:
	if not alive:
		return false
	hp -= dmg
	flash = 0.09
	if ceif or caida: fl = min(1.0, fl + .35 + dmg / 80.0)
	if hp <= 0.0:
		die(src, head)
		return true
	return false

func die(src: String, head: bool) -> void:
	alive = false
	var c = center()
	if fly:
		G.emit("metal", c, 12, 12, .22, 1.4)
		G.emit("spark", c, 16, 14, .08, .5)
	elif ceif or caida:
		G.emit("white", c + Vector3(0, .4, 0), 18, 10, .2, 1.4, Vector3(0, 3, 0), 6)
	# explode em pedaços, voa sangue e o tempo congela por um instante
	if G.main and G.main.gibs: G.main.gibs.explode(self, src)
	if G.player and G.player.global_position.distance_to(c) < 7.0:
		G.heal(40 if kind == "brute" else 20)
	G.on_kill(self, src, head)
	if G.mode == "train" and dummy:
		var hm = home
		var k = kind
		G.later(2.0, func(): if G.mode == "train": G.main.spawn_enemy(k, hm, true))
	if mark:
		mark.queue_free()
	queue_free()

func _physics_process(dt: float) -> void:
	if G.state != "play" or not alive:
		return
	if spawn_t > 0.0:
		spawn_t -= dt
		vis.scale = Vector3.ONE * clamp(1.0 - spawn_t / 0.6, 0.01, 1.0)
		return
	vis.scale = Vector3.ONE
	flash -= dt
	for m in mats:
		m.emission_enabled = flash > 0 or wind > 0
		m.emission = Color(1, 1, 1) if flash > 0 else Color("8a3000")
	phase += dt
	if burn > 0.0:
		burn -= dt
		burn_tick -= dt
		if G.rng.randf() < dt * 25:
			G.emit("fire", center() + Vector3(G.rnd(-.4, .4), G.rnd(-.6, .6), G.rnd(-.4, .4)), 1, 2, .14, .5, Vector3.ZERO, -6)
		if burn_tick <= 0.0:
			burn_tick = 0.25
			G.hurt_enemy(self, 5, "burn", center(), false)
			if not alive:
				return
	var p: Vector3 = G.player.global_position
	var dx = p.x - global_position.x
	var dz = p.z - global_position.z
	var dist: float = max(0.001, sqrt(dx * dx + dz * dz))
	var nx = dx / dist
	var nz = dz / dist
	if fly:
		_upd_drone(dt, dx, dz, dist, nx, nz, p)
	elif ceif:
		_upd_ceif(dt, dx, dz, dist, nx, nz, p)
	elif caida:
		_upd_caida(dt, dx, dz, dist, nx, nz, p)
	else:
		_upd_husk(dt, dx, dz, dist, nx, nz, p)
	# preso fora de vista: reaparece num ponto normal
	var out = abs(global_position.x) > G.A - 1 or abs(global_position.z) > G.A - 1
	var lost = out or (global_position.y > 15.0 if fly else (global_position.y > 3.2 and is_on_floor()))
	lost_t = lost_t + dt if lost else 0.0
	if lost_t > 1.5:
		var sp: Vector3 = G.main.spawn_point()
		global_position = Vector3(sp.x, 6.0 if fly else 0.5, sp.z)
		velocity = Vector3.ZERO
		lost_t = 0.0

func _upd_husk(dt: float, dx: float, dz: float, dist: float, nx: float, nz: float, p: Vector3) -> void:
	var brute = kind == "brute"
	var reach = 3.4 if brute else 2.2
	if dummy:
		var k = 1.0 - exp(-6.0 * dt)
		velocity.x -= velocity.x * k
		velocity.z -= velocity.z * k
		velocity.y -= 40.0 * dt
		move_and_slide()
		rotation.y = atan2(dx, dz)
		return
	if wind > 0.0:
		wind -= dt
		if wind <= 0.0:
			swing = 0.3
			cd = 1.6 if brute else 1.1
			velocity.x += nx * (5.0 if brute else 7.0)
			velocity.z += nz * (5.0 if brute else 7.0)
			var d3 = Vector3(dx, p.y - global_position.y, dz).length()
			if d3 < reach + 0.9 and G.hurt_player(30.0 if brute else 15.0):
				G.player.velocity += Vector3(nx * 10, 4, nz * 10)
	else:
		cd -= dt
		if dist < reach and cd <= 0.0 and abs(p.y - global_position.y) < 2.5:
			wind = 0.55 if brute else 0.35
	swing -= dt
	var want = 0.0
	if dist > 1.1:
		want = speed * 0.25 if wind > 0 else speed
	var kk = 1.0 - exp(-(8.0 if is_on_floor() else 0.8) * dt)
	velocity.x += (nx * want - velocity.x) * kk
	velocity.z += (nz * want - velocity.z) * kk
	velocity.y -= 40.0 * dt
	move_and_slide()
	if is_on_wall() and is_on_floor():
		velocity.y = 11.0
	rotation.y = atan2(dx, dz)
	var hs = Vector2(velocity.x, velocity.z).length()
	var sw = sin(phase * (7.0 if brute else 11.0)) * 0.7 * min(1.0, hs / speed)
	if legs.size() == 2:
		legs[0].rotation.x = sw
		legs[1].rotation.x = -sw
	var arm = -2.7 if wind > 0 else (-0.6 if swing > 0 else -1.25 + sw * 0.3)
	for a in arms:
		a.rotation.x += (arm - a.rotation.x) * (1.0 - exp(-(40.0 if swing > 0 else 14.0) * dt))

func _upd_drone(dt: float, dx: float, dz: float, dist: float, nx: float, nz: float, p: Vector3) -> void:
	var side = 1.0 if sin(phase * 0.6 + seed_) > 0 else -1.0
	var radial: float = clamp((dist - 15.0) * 0.8, -8.0, 8.0)
	var gx = nx * radial - nz * side * 6.0
	var gz = nz * radial + nx * side * 6.0
	var ty = p.y + 5.0 + sin(phase * 1.4 + seed_) * 1.5
	if dummy:
		gx = (home.x - global_position.x) * 2.0
		gz = (home.z - global_position.z) * 2.0
		ty = home.y + sin(phase * 1.4) * 0.6
	var k = 1.0 - exp(-2.5 * dt)
	velocity.x += (gx - velocity.x) * k
	velocity.z += (gz - velocity.z) * k
	velocity.y += ((ty - global_position.y) * 2.0 - velocity.y) * k
	move_and_slide()
	rotation.y = atan2(dx, dz)
	core.rotation.x = atan2(global_position.y - p.y - 1.2, dist)
	ring.rotation.x = PI / 2 + sin(phase * 2.0) * 0.3
	ring.rotation.y += dt * 3.0
	eye.scale = Vector3.ONE * (1.6 if wind > 0 else 1.0)
	if wind > 0.0:
		wind -= dt
		if wind <= 0.0:
			var ep = eye.global_position
			var tgt = Vector3(p.x + G.player.velocity.x * .25, p.y + 1.0, p.z + G.player.velocity.z * .25)
			G.main.spawn_orb(ep, (tgt - ep).normalized() * min(26.0, 16.0 + G.main.wave * 0.8))
			G.snd("eshot", -8)
	else:
		cd -= dt
		if cd <= 0.0 and dist < 50.0:
			wind = 0.45
			cd = G.rnd(2.2, 3.2) - min(1.0, G.main.wave * 0.08)

# ---------------- Ceifadora: anda desfilando e golpeia com o cajado-foice ----------------
const CEIF_DMG := {"slash": 14.0, "overhead": 22.0, "spin": 12.0, "lunge": 18.0}

func _start_atk(k: String) -> void:
	atk = k
	at = 0.0
	atk_hit = false
	last_atk = k
	lunge_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
	G.snd("whoosh", -14, .6)

func _pick_atk(dist: float) -> String:
	var opts = ["slash", "slash", "overhead", "spin"]
	if last_atk == "spin": opts.erase("spin")
	return opts[G.rng.randi() % opts.size()]

func _staff_tip() -> Vector3:
	var sk: Skeleton3D = ceif.sk
	var g = sk.global_transform * sk.get_bone_global_pose(ceif.B["staff"])
	return g * Vector3(0, -.82, 0)

func _ceif_hit(p: Vector3, reach: float, cosmin: float) -> bool:
	var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var f = Vector3(sin(rotation.y), 0, cos(rotation.y))
	if to.length() > reach or abs(p.y - global_position.y) > 2.4: return false
	if to.length() > .8 and to.normalized().dot(f) < cosmin: return false
	if G.hurt_player(CEIF_DMG[atk]):
		var kb = to.normalized() if to.length() > .1 else f
		G.player.velocity += kb * (13.0 if atk == "overhead" else 9.0) + Vector3(0, 5 if atk != "overhead" else 3, 0)
		G.snd("hit", -4, .7)
		return true
	return false

func _upd_ceif(dt: float, dx: float, dz: float, dist: float, nx: float, nz: float, p: Vector3) -> void:
	var C = ceif
	var face = atan2(dx, dz)
	fl *= exp(-6.0 * dt)
	var want = 0.0
	var track = 6.0
	var params = C.CARRY
	var dir = Vector3(nx, 0, nz)
	if dummy:
		var k = 1.0 - exp(-6.0 * dt)
		velocity.x -= velocity.x * k
		velocity.z -= velocity.z * k
	elif atk == "":
		wind = 0.0
		cd -= dt
		if dist > 1.7: want = speed
		if cd <= 0.0 and abs(p.y - global_position.y) < 2.6:
			if dist < 3.0:
				_start_atk(_pick_atk(dist))
			elif dist > 4.5 and dist < 10.0 and G.rng.randf() < .55:
				_start_atk("lunge")
			else:
				cd = .35
	if atk != "":
		at += dt
		var A = C.ATK[atk]
		params = C.sample(A.keys, at)
		var hit_t = A.hit
		wind = .1 if at < hit_t - .1 else 0.0
		track = 9.0 if at < hit_t - .14 else 0.0
		if absf(at - (hit_t - .1)) < dt * .6: G.snd("whoosh", -2, .75 if atk == "overhead" else .95)
		match atk:
			"slash":
				if not atk_hit and at >= hit_t:
					atk_hit = true
					_ceif_hit(p, 3.4, -.1)
				if at > hit_t - .1 and at < hit_t + .12:
					velocity.x += dir.x * 18 * dt; velocity.z += dir.z * 18 * dt
			"overhead":
				if not atk_hit and at >= hit_t:
					atk_hit = true
					var tp = _staff_tip()
					var gp = Vector3(tp.x, global_position.y + .1, tp.z)
					G.emit("dust", gp, 18, 7, .35, .8)
					G.emit("spark", gp, 14, 9, .1, .4)
					G.snd("slam", -6, 1.3)
					if global_position.distance_to(G.player.global_position) < 8: G.shake = max(G.shake, .35)
					_ceif_hit(p, 3.9, .55)
			"spin":
				want = 2.2
				track = 2.0
				if not atk_hit and at > .42 and at < 1.0:
					var to = Vector3(p.x - global_position.x, 0, p.z - global_position.z)
					if to.length() < 3.3 and abs(p.y - global_position.y) < 2.4:
						atk_hit = true
						_ceif_hit(p, 3.3, -1.0)
				if int(at * 6) != int((at - dt) * 6) and at > .3 and at < 1.0: G.snd("whoosh", -10, 1.2)
			"lunge":
				if at > .38 and at < .62:
					velocity.x = lunge_dir.x * 17.0
					velocity.z = lunge_dir.z * 17.0
					if not atk_hit and dist < 2.4:
						atk_hit = true
						_ceif_hit(p, 2.6, -.2)
				elif at < .38:
					lunge_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
		# rastro de luz na ponta do cajado durante o golpe
		if at > hit_t - .13 and at < hit_t + .18:
			var tip = _staff_tip()
			G.emit("white", tip, 2, 1.5, .16, .25, Vector3.ZERO, 0)
			G.emit("spark", tip, 1, 2, .1, .2, Vector3.ZERO, 0)
		if at >= A.dur:
			atk = ""
			wind = 0.0
			cd = G.rnd(.45, 1.1)
	if not dummy and not (atk == "lunge" and at > .38 and at < .62):
		var kk = 1.0 - exp(-(8.0 if is_on_floor() else 0.8) * dt)
		velocity.x += (nx * want - velocity.x) * kk
		velocity.z += (nz * want - velocity.z) * kk
	velocity.y -= 40.0 * dt
	move_and_slide()
	if not dummy and is_on_wall() and is_on_floor() and atk == "":
		velocity.y = 11.0
	if track > 0: rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-track * dt))
	# giro do golpe giratório (só o visual gira)
	if atk == "spin":
		var u = clamp((at - .3) / .7, 0.0, 1.0)
		vis.rotation.y = -TAU * 2.0 * (u * u * (3 - 2 * u))
	else:
		vis.rotation.y = 0.0
	# animação
	var hs = Vector2(velocity.x, velocity.z).length()
	cyc += dt * PI * min(hs, 8.0) / .85
	var w = clamp(hs / speed, 0.0, 1.0)
	if atk != "": w *= .35
	C.base_pose()
	C.walk(cyc, w, phase)
	C.idle(phase, 1.0 - w)
	C.breathe_wings(phase + seed_, 0.0)
	C.pose(params, 1.0)
	if fl > .01:
		C.R("spine", Vector3.RIGHT, -.3 * fl)
		C.R("head", Vector3.RIGHT, -.35 * fl)
		C.wings(.25 * fl, .2 * fl)
	C.R("head", Vector3.RIGHT, clamp(-(p.y - global_position.y) * .08, -.3, .3))
	C.apply_all(params)

# ---------------- Anjo Caído: desfila, golpeia com o cajado e salta cravando o cajado no chão ----------------
const CAIDA_ATK := {"ataque": {"dur": 44.0 / 30.0, "hit": 23.0 / 30.0, "dmg": 20.0},
	"salto": {"dur": 58.0 / 30.0, "up": 14.0 / 30.0, "hit": 36.0 / 30.0, "dmg": 26.0}}

func _caida_front(d: float) -> Vector3:
	return global_position + Vector3(sin(rotation.y), 0, cos(rotation.y)) * d

func _upd_caida(dt: float, dx: float, dz: float, dist: float, nx: float, nz: float, p: Vector3) -> void:
	var face = atan2(dx, dz)
	fl *= exp(-6.0 * dt)
	var want = 0.0
	var track = 5.0
	if dummy:
		var k = 1.0 - exp(-6.0 * dt)
		velocity.x -= velocity.x * k
		velocity.z -= velocity.z * k
	elif atk == "":
		wind = 0.0
		cd -= dt
		if dist > 2.2: want = speed
		if cd <= 0.0 and abs(p.y - global_position.y) < 3.0:
			if dist < 3.4:
				_caida_start("ataque")
			elif dist > 5.0 and dist < 13.0 and G.rng.randf() < .6:
				_caida_start("salto")
			else:
				cd = .4
	if atk != "":
		at += dt
		var A = CAIDA_ATK[atk]
		wind = 0.0
		match atk:
			"ataque":
				track = 7.0 if at < A.hit - .2 else 0.0
				if absf(at - (A.hit - .12)) < dt * .6: G.snd("whoosh", -2, .7)
				if at > A.hit - .1 and at < A.hit + .1:
					velocity.x += sin(rotation.y) * 16 * dt; velocity.z += cos(rotation.y) * 16 * dt
				if not atk_hit and at >= A.hit:
					atk_hit = true
					var gp = _caida_front(2.3)
					gp.y = global_position.y + .1
					G.emit("dust", gp, 14, 6, .3, .7)
					G.emit("spark", gp, 12, 8, .1, .4)
					G.snd("slam", -8, 1.25)
					_caida_hurt(p, 3.7, .35, A.dmg, 11.0)
			"salto":
				track = 6.0 if at < A.up else 0.0
				if at < A.up:
					jump_from = global_position
					var to = Vector3(p.x, global_position.y, p.z)
					var off = to - global_position
					# cai um pouco antes do jogador, com o cajado na frente
					var L = clamp(off.length() - 1.6, 0.0, 11.0)
					jump_to = global_position + off.normalized() * L if off.length() > .1 else global_position
				elif at < A.hit:
					var u = (at - A.up) / (A.hit - A.up)
					var tgt = jump_from.lerp(jump_to, u * u * (3 - 2 * u))
					velocity.x = (tgt.x - global_position.x) / max(dt, .001)
					velocity.z = (tgt.z - global_position.z) / max(dt, .001)
					if absf(at - A.up) < dt * .6:
						G.snd("whoosh", -4, .55)
						G.emit("dust", global_position + Vector3(0, .1, 0), 12, 5, .3, .6)
				else:
					velocity.x = 0; velocity.z = 0
				if not atk_hit and at >= A.hit:
					atk_hit = true
					var gp = _caida_front(1.4)
					gp.y = global_position.y + .1
					G.emit("dust", gp, 30, 11, .4, 1.0)
					G.emit("spark", gp, 22, 14, .12, .5)
					G.emit("white", gp + Vector3(0, .3, 0), 14, 9, .2, .5)
					G.snd("slam", -2, .9)
					G.snd("porrada", -8, .8)
					var pd = global_position.distance_to(G.player.global_position)
					if pd < 12: G.shake = max(G.shake, .55 - pd * .03)
					_caida_hurt(p, 4.6, -1.0, A.dmg, 14.0, gp)
		if at >= A.dur:
			atk = ""
			wind = 0.0
			cd = G.rnd(.6, 1.4)
			cap_ap.play("desfile", .25)
	if not dummy and not (atk == "salto" and at >= CAIDA_ATK.salto.up and at < CAIDA_ATK.salto.hit):
		if atk == "salto": want = 0.0
		var kk = 1.0 - exp(-(8.0 if is_on_floor() else 0.8) * dt)
		velocity.x += (nx * want - velocity.x) * kk
		velocity.z += (nz * want - velocity.z) * kk
	velocity.y -= 40.0 * dt
	move_and_slide()
	if not dummy and is_on_wall() and is_on_floor() and atk == "":
		velocity.y = 11.0
	if track > 0: rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-track * dt))
	# animação de andar acompanha a velocidade
	if atk == "":
		var hs = Vector2(velocity.x, velocity.z).length()
		if cap_ap.current_animation != "desfile": cap_ap.play("desfile", .25)
		cap_ap.speed_scale = clamp(hs / 3.2, .12, 1.6)
	else:
		cap_ap.speed_scale = 1.0
	# levou tiro: dá um tranco para trás
	vis.rotation.x = -.18 * fl

func _caida_start(k: String) -> void:
	atk = k
	at = 0.0
	atk_hit = false
	last_atk = k
	cap_ap.play(k, .12)
	cap_ap.speed_scale = 1.0
	G.snd("whoosh", -14, .55)

func _caida_hurt(p: Vector3, reach: float, cosmin: float, dmg: float, kb: float, from = null) -> void:
	var o: Vector3 = from if from != null else global_position
	var to = Vector3(p.x - o.x, 0, p.z - o.z)
	var f = Vector3(sin(rotation.y), 0, cos(rotation.y))
	if to.length() > reach or abs(p.y - global_position.y) > 2.6: return
	if from == null and to.length() > .9 and to.normalized().dot(f) < cosmin: return
	if G.hurt_player(dmg):
		var d = to.normalized() if to.length() > .1 else f
		G.player.velocity += d * kb + Vector3(0, 5, 0)
		G.snd("hit", -4, .7)
