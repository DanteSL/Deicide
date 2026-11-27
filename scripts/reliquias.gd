extends Node
## Relíquias: a arma de cada chefe, ganha ao matá-lo (tecla 9 passa por elas; 1–8 voltam às armas normais).
## Os modelos e as animações foram feitos no Blender junto com os braços humanos (maos.glb: uma malha
## "Reliquia_<id>" e as ações "<id>_saque/parado/ataque1/ataque2/ataque3/especial/inspecao").
## Aqui ficam a troca, o momento de cada golpe e as mecânicas.
##   Garras do Abismo (Lilith)   cortes que queimam; quem morre queimando solta a alma; beijo: puxa, crava e rouba sangue
##   Rosário Velado (Miguel)     chicote de contas; laço que puxa o inimigo; com a pisada (slam) abre um mini-eclipse
##   Trombeta do Juízo (Gabriel) cone sônico que empurra e devolve projéteis; toque carregado atravessa paredes e atordoa
##   Olho da Tempestade (Azazel) raio em cadeia (até 4); arremessa o olho: torre de raios por 8 s (atire nele para explodir)
##   Mãos do Criador (Deus)      mãos de mármore que agarram e esmagam; o aperto explode todas; enche a Blasfêmia mais rápido

const IDS := ["garras", "rosario", "trombeta", "olho", "maos"]
const NOME := {"garras": "GARRAS DO ABISMO", "rosario": "ROSÁRIO VELADO", "trombeta": "TROMBETA DO JUÍZO",
	"olho": "OLHO DA TEMPESTADE", "maos": "MÃOS DO CRIADOR"}
const DE_CHEFE := {"lilith": "garras", "miguel": "rosario", "gabriel": "trombeta", "azazel": "olho", "deus": "maos"}
## momentos (segundos) dos golpes dentro de cada animação
const EV := {
	"garras_ataque1": [[.24, "rasgo"]],
	"garras_ataque2": [[.24, "rasgo"]],
	"garras_ataque3": [[.3, "rasgo_x"]],
	"garras_especial": [[.3, "agarra"], [.64, "crava"], [.84, "suga"], [.94, "suga"], [1.04, "suga"]],
	"rosario_ataque1": [[.26, "chicote"]],
	"rosario_ataque2": [[.26, "chicote"]],
	"rosario_ataque3": [[.37, "desce"]],
	"rosario_especial": [[.33, "laco"], [.74, "puxa"]],
	"trombeta_ataque1": [[.13, "toque"]],
	"trombeta_ataque2": [[.13, "toque"], [.4, "toque"]],
	"trombeta_ataque3": [[.36, "sino"]],
	"trombeta_especial": [[.15, "carrega"], [.96, "juizo"]],
	"olho_ataque1": [[.17, "raio"]],
	"olho_ataque2": [[.2, "raio"]],
	"olho_ataque3": [[.4, "raio"]],
	"olho_especial": [[.97, "arremessa"]],
	"maos_ataque1": [[.2, "mao_r"]],
	"maos_ataque2": [[.2, "mao_l"]],
	"maos_ataque3": [[.23, "mao_r"], [.24, "mao_l"]],
	"maos_especial": [[.3, "carrega"], [1.02, "aperto"]],
}
const ALT_CD := {"garras": 4.5, "rosario": 5.0, "trombeta": 6.0, "olho": 9.0, "maos": 1.2}
const FIRE_CD := {"garras": [.3, .3, .5], "rosario": [.42, .42, .6], "trombeta": [.5, .78, .62],
	"olho": [.42, .45, .6], "maos": [.4, .4, .55]}
const RANGED := ["trombeta", "olho", "maos"]
const CANCEL := .62

var W: Node            # weapons.gd
var arms: Node3D
var ap: AnimationPlayer
var base_anim := ""
var base_xf: Transform3D
var cur := ""          # relíquia em uso ("" = armas normais)
var last := ""
var meshes := {}
var act := ""          # animação de ação em curso ("" ou "parado" = livre)
var act_t := 0.0
var act_len := 0.0
var done := {}         # eventos já disparados nesta ação
var combo := 0
var combo_t := 0.0
var cd := 0.0
var cd_alt := 0.0
var held := false
var target: Node = null
var mats := {}         # materiais com brilho de cada relíquia (pulsam)
var pulse := 0.0

func setup(w: Node) -> void:
	W = w
	arms = w.arms
	ap = w.arms_ap
	base_anim = ap.current_animation
	base_xf = arms.transform
	for mi in W._all_meshes(arms):
		var nm := String(mi.name)
		if nm.begins_with("Reliquia_"):
			var id := nm.substr(9)
			meshes[id] = mi
			mi.visible = false
			_prep_mats(id, mi)
	for id in IDS:
		if ap.has_animation(id + "_parado"):
			ap.get_animation(id + "_parado").loop_mode = Animation.LOOP_LINEAR
	ap.playback_default_blend_time = .1

## materiais importados do Blender: o mundo das armas não tem reflexo de céu, então os metais
## claros (ouro, prata) perdem um pouco do metálico para a cor aparecer; o brilho pulsa
func _prep_mats(id: String, mi: MeshInstance3D) -> void:
	mats[id] = []
	var mesh: Mesh = mi.mesh
	for si in mesh.get_surface_count():
		var sm = mesh.surface_get_material(si)
		if not (sm is BaseMaterial3D): continue
		var m: BaseMaterial3D = sm.duplicate()
		var nm := String(sm.resource_name)
		if nm.contains("Brilho") or nm.contains("Luz"):
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 3.0
			mats[id].append(m)
		elif m.metallic > .5:
			if m.albedo_color.get_luminance() > .25:
				m.metallic = .45
				m.roughness = max(m.roughness, .32)
				m.metallic_specular = .8
			else:
				m.metallic_specular = .7
		if nm.contains("Marmore"):
			m.albedo_color = Color(.78, .76, .72)
			m.roughness = .35
		mi.set_surface_override_material(si, m)

func unlocked() -> Array:
	var out = []
	for id in IDS:
		if meshes.has(id) and (G.mode == "train" or G.relics.get(id, false)):
			out.append(id)
	return out

## tecla 9: entra na relíquia (a última usada) ou passa para a próxima
func next() -> void:
	var u := unlocked()
	if u.is_empty():
		if G.main: G.main.banner("NENHUMA RELÍQUIA", "mate um chefe para ganhar a arma dele")
		return
	var id: String
	if cur == "":
		id = last if last in u else u[0]
	else:
		id = u[(u.find(cur) + 1) % u.size()]
	enter(id)

func enter(id: String) -> void:
	if cur == id or not meshes.has(id): return
	if cur != "": meshes[cur].visible = false
	cur = id
	last = id
	meshes[id].visible = true
	W.on_relic(true)
	combo = 0
	cd = .35
	cd_alt = .5
	target = null
	held = false
	_play("saque", .08)
	G.snd("draw", -6)
	if G.main and G.main.has_method("on_weapon_changed"): G.main.on_weapon_changed()
	if previews.has(id) and G.main and G.main.hud2: G.main.hud2.set_preview("relic_" + id, previews[id])

func leave() -> void:
	if cur == "": return
	meshes[cur].visible = false
	cur = ""
	act = ""
	held = false
	pull_e = null
	arms.transform = base_xf
	ap.play(base_anim, .15)
	W.on_relic(false)

func _play(nm: String, blend := .06) -> void:
	var full := cur + "_" + nm
	if not ap.has_animation(full): return
	ap.play(full, blend)
	if nm != "parado": ap.queue(cur + "_parado")
	act = nm
	act_t = 0.0
	act_len = ap.get_animation(full).length
	done = {}

func free_to_act(frac := CANCEL) -> bool:
	return act == "" or act == "parado" or act == "inspecao" or act_t >= act_len * frac

## barra e texto do HUD (recarga do especial)
func hud_state() -> Dictionary:
	var mx: float = ALT_CD.get(cur, 3.0)
	var k: float = 1.0 - clamp(cd_alt / mx, 0.0, 1.0)
	var col: Color = {"garras": Color("ff2a2a"), "rosario": Color("b48cff"), "trombeta": Color("ffd56a"),
		"olho": Color("40e8ff"), "maos": Color("f2e6d0")}.get(cur, Color.WHITE)
	var st := "ESPECIAL PRONTO" if k >= 1.0 else ""
	if cur == "maos":
		var n := latched_count()
		st = ("%d MÃOS PRESAS" % n) if n > 0 else "SEM MÃOS PRESAS"
	if cur == "olho" and is_instance_valid(turret_node): st = "OLHO VIGIANDO"
	return {"bar": k, "col": col, "status": st}

# ---------------- entrada ----------------
func fire() -> void:
	if _dbg(): print("  fire ", cur, " cd=", snapped(cd, .01), " act=", act, " t=", snapped(act_t, .01), "/", snapped(act_len, .01), " combo=", combo, " ct=", snapped(combo_t, .01), " fps=", Engine.get_frames_per_second())
	if cur == "" or cd > 0.0 or G.player.dead: return
	if not free_to_act(): return
	if cur in RANGED and not G.blood_can(cur):
		G.blood_out()
		cd = .3
		return
	if combo_t <= 0.0: combo = 0
	var i: int = combo % 3
	_play(["ataque1", "ataque2", "ataque3"][i], .05)
	combo += 1
	combo_t = act_len + .45
	cd = FIRE_CD[cur][i]
	G.snd("whoosh", -7, G.rnd(.9, 1.15))

func alt_press() -> void:
	if _dbg(): print("  alt ", cur, " cd_alt=", snapped(cd_alt, .01), " act=", act, " t=", snapped(act_t, .01))
	if cur == "" or G.player.dead: return
	held = true
	if cd_alt > 0.0 or not free_to_act(.8): return
	match cur:
		"garras": target = best_target(18.0, 16.0)
		"rosario": target = best_target(17.0, 14.0)
		"maos":
			if latched_count() == 0:
				if G.main: G.main.banner("", "nenhuma mão presa")
				return
			if not G.blood_can("maos", 5.0):
				G.blood_out()
				return
			G.blood_take("maos", 5.0)
	cd_alt = ALT_CD.get(cur, 3.0)
	cd = .9
	_play("especial", .06)
	G.snd("whoosh", -4, .7)

func alt_release() -> void:
	held = false

func punch() -> void:
	if cur == "": return
	if cur == "garras" or cur == "rosario":
		fire()
	elif free_to_act() and cd <= 0.0:
		# empurrão rápido com a relíquia
		var f := -cam_xf().basis.z
		for e in in_cone(3.0, 50.0):
			hit(e, 25.0, "punch", f)
			knock(e, f * 14.0 + Vector3(0, 5, 0))
		G.snd("punch", -4)
		cd = .35

func inspect() -> void:
	if cur == "" or not free_to_act(1.0) or act == "inspecao": return
	_play("inspecao", .15)
	G.snd("whoosh", -10)

# ---------------- quadro a quadro ----------------
func _process(dt: float) -> void:
	if G.state != "play": return
	_upd_hands(dt)
	_upd_turret(dt)

func process(dt: float) -> void:
	if cur == "": return
	act_t += dt
	cd -= dt
	cd_alt -= dt
	combo_t -= dt
	pulse += dt
	if act != "" and act != "parado" and act_t >= act_len:
		act = "parado"
	var key := cur + "_" + act
	if EV.has(key):
		for i in EV[key].size():
			var ev = EV[key][i]
			if not done.has(i) and act_t >= ev[0]:
				done[i] = true
				_event(ev[1])
	for m in mats.get(cur, []):
		var boost := 2.5 if act.begins_with("especial") else 0.0
		m.emission_energy_multiplier = 2.4 + .9 * sin(pulse * 3.1) + boost
	_sway(dt)
	_upd_pull(dt)
	if not previews.has(cur) and ((act == "parado" and act_t > .05) or (act == "saque" and act_t > act_len * .95)):
		_make_preview(cur)


## prévia do HUD: a malha da relíquia "assada" na pose atual (sem os braços)
var previews := {}
func _make_preview(id: String) -> void:
	var mi: MeshInstance3D = meshes[id]
	if not mi.has_method("bake_mesh_from_current_skeleton_pose"): return
	var am: ArrayMesh = mi.bake_mesh_from_current_skeleton_pose()
	if am == null: return
	var root := Node3D.new()
	var m := MeshInstance3D.new()
	m.mesh = am
	for si in am.get_surface_count():
		m.set_surface_override_material(si, mi.get_surface_override_material(si))
	root.add_child(m)
	previews[id] = root
	if G.main and G.main.hud2: G.main.hud2.set_preview("relic_" + id, root)

## balanço dos braços (olhar, passo, inclinação): gira em volta da câmera, não dos pés
func _sway(_dt: float) -> void:
	var p = G.player
	if p == null: return
	var bx = sin(W.bob_ph) * .012 * W.bob_a
	var by = -abs(cos(W.bob_ph)) * .014 * W.bob_a
	var air = 0.0 if p.is_on_floor() else clamp(-p.velocity.y / 30.0, -1.0, 1.0) * .02
	var rot = Vector3(W.sway.y * 1.6, -W.sway.x * 1.6, W.tilt * .5)
	var off = Vector3(bx + W.sway.x * .8, by + W.sway.y * .8 - p.land * .04 + air, 0)
	arms.transform = Transform3D(Basis.from_euler(rot), off) * base_xf

# ---------------- utilidades de combate ----------------
func cam_xf() -> Transform3D:
	return G.cam.global_transform

## ponto do mundo que corresponde a um ponto da arma na tela (direita, cima, frente em metros)
func vm_point(rx: float, uy: float, fz: float) -> Vector3:
	var c := cam_xf()
	return c.origin + c.basis.x * rx + c.basis.y * uy - c.basis.z * fz

## inimigos dentro de um cone à frente (alcance, meia-abertura em graus)
func in_cone(rng: float, half_deg: float, max_n := 99, need_los := true) -> Array:
	var c := cam_xf()
	var o := c.origin
	var f := -c.basis.z
	var out = []
	for e in G.enemies:
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
		var v: Vector3 = e.center() - o
		var d := v.length()
		if d > rng + e.r: continue
		if d > .8 and rad_to_deg(f.angle_to(v)) > half_deg: continue
		if need_los and not G.los(o, e.center()): continue
		out.append([d, e])
	out.sort_custom(func(a, b): return a[0] < b[0])
	var r = []
	for x in out.slice(0, max_n): r.append(x[1])
	if G.boss and is_instance_valid(G.boss) and G.boss.alive and not (G.boss in r):
		var v: Vector3 = G.boss.center() - o
		if v.length() < rng + 3.0 and rad_to_deg(f.angle_to(v)) < half_deg + 10:
			r.append(G.boss)
	return r

func best_target(rng: float, half_deg: float) -> Node:
	var c := cam_xf()
	var f := -c.basis.z
	var best = null
	var bs := 1e9
	for e in G.enemies:
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
		var v: Vector3 = e.center() - c.origin
		var d := v.length()
		if d > rng: continue
		var a := rad_to_deg(f.angle_to(v))
		if a > half_deg: continue
		if not G.los(c.origin, e.center()): continue
		var s := a * 2.0 + d
		if s < bs:
			bs = s
			best = e
	if best == null and G.boss and is_instance_valid(G.boss) and G.boss.alive:
		var v2: Vector3 = G.boss.center() - c.origin
		if v2.length() < rng + 6.0 and rad_to_deg(f.angle_to(v2)) < half_deg + 6: best = G.boss
	return best

## corte desenhado no mundo, na frente da câmera (ang = inclinação do corte na tela, em graus)
func slash_fx(ang: float, col: Color, size := 2.6, dist := 1.7, tname := "slash_04", life := .22) -> void:
	var c := cam_xf()
	var f := -c.basis.z
	var pos := c.origin + f * dist - c.basis.y * .15
	G.fx.slash(pos, f, size, col, life, tname)
	var it = G.fx.items[-1]
	var up := c.basis.y.rotated(f, deg_to_rad(ang))
	it.n.basis = Basis.looking_at(f, up)
	it.n.scale = Vector3.ONE * size * .8

var dmg_total := 0.0 # (testes)
func hit(e: Node, dmg: float, src: String, dir := Vector3.ZERO) -> bool:
	if e == null or not is_instance_valid(e) or not e.alive: return false
	dmg_total += dmg
	return G.hurt_enemy(e, dmg, src, e.center(), false, dir)

func knock(e: Node, v: Vector3) -> void:
	if is_instance_valid(e) and e.alive and not e.is_boss and "velocity" in e:
		e.velocity += v

func stun(e: Node, t: float) -> void:
	if is_instance_valid(e) and e.alive and not e.is_boss and "stun" in e:
		e.stun = max(e.stun, t)

# ================================================================ eventos dos golpes
var _dbg_on := -1
func _dbg() -> bool:
	if _dbg_on < 0: _dbg_on = 1 if OS.get_cmdline_user_args().has("--autotest=relfx") else 0
	return _dbg_on == 1

func _event(ev: String) -> void:
	if _dbg(): print("  evento ", cur, " ", act, " ", ev, " alvos=", in_cone(8.0, 60.0).size())
	match ev:
		# ---------- Garras do Abismo ----------
		"rasgo", "rasgo_x":
			var big := ev == "rasgo_x"
			var right := act == "ataque1"
			if big:
				slash_fx(-40, Color(1, .15, .1, .95), 3.2, 1.7, "scratch_01")
				slash_fx(40, Color(1, .15, .1, .95), 3.2, 1.75, "scratch_01")
			else:
				slash_fx(-38.0 if right else 38.0, Color(1, .12, .08, .95), 2.8, 1.7, "scratch_01")
			var f := -cam_xf().basis.z
			var any := false
			for e in in_cone(3.6 if big else 3.2, 62.0 if big else 55.0):
				any = true
				if hit(e, 75.0 if big else 42.0, "garras", f):
					_soul(e.center())
				elif is_instance_valid(e) and e.alive:
					if "burn" in e: e.burn = max(e.burn, 3.0)
					e.set_meta("lilith", Time.get_ticks_msec())
					knock(e, f * (7.0 if big else 4.0) + Vector3(0, 2, 0))
			if any:
				G.shake = max(G.shake, .35 if big else .22)
				if G.main: G.main.hitstop(.05 if big else .03)
				G.snd("hit", -4, .8)
		"agarra":
			var e = target
			if e and is_instance_valid(e) and e.alive:
				pull_e = e
				pull_t = .34
				pull_k = 16.0
				G.fx.beam(vm_point(-.1, -.12, .8), e.center(), .35, Color(1, .1, .15, .9), .3)
				G.snd("whirl", -6, .6)
		"crava":
			var e = pull_e if pull_e else target
			if e and is_instance_valid(e) and e.alive:
				G.emit("blood2", e.center(), 30, 10, .16, .9, -cam_xf().basis.z)
				if hit(e, 70.0, "garras", -cam_xf().basis.z):
					_soul(e.center())
				G.shake = max(G.shake, .5)
				if G.main: G.main.hitstop(.08)
			slash_fx(0, Color(1, .1, .1, .8), 1.6, 1.4, "slash_02", .18)
		"suga":
			var e = pull_e if pull_e else target
			if e and is_instance_valid(e) and e.alive:
				hit(e, 14.0, "garras")
				G.heal(8.0)
				G.blood_add(10.0)
				G.fx.beam(e.center(), vm_point(0, -.3, .6), .25, Color(.9, .05, .08, .8), .2)
				G.emit("blood", e.center(), 10, 4, .12, .6)
		# ---------- Rosário Velado ----------
		"chicote":
			var right2 := act == "ataque1"
			slash_fx(-12.0 if right2 else 12.0, Color(.7, .45, 1, .9), 4.2, 2.6, "slash_03", .26)
			var f2 := -cam_xf().basis.z
			var side := cam_xf().basis.x * (1.0 if right2 else -1.0)
			var any2 := false
			for e in in_cone(6.2, 62.0):
				any2 = true
				hit(e, 38.0, "rosario", f2)
				knock(e, -side * 9.0 + f2 * 4.0 + Vector3(0, 3, 0))
				G.emit("pink", e.center(), 10, 8, .12, .5)
			if any2:
				G.shake = max(G.shake, .25)
				G.snd("hit", -4, .7)
		"desce":
			var c := cam_xf()
			var f3 := -c.basis.z
			var any3 := false
			var where := c.origin + Vector3(f3.x, 0, f3.z).normalized() * 4.5 + Vector3(0, -1.4, 0)
			for e in in_cone(6.8, 32.0):
				any3 = true
				where = e.center()
				hit(e, 85.0, "rosario", f3)
				stun(e, .8)
			_eclipse_ring(where, 2.6, 45.0, false)
			G.shake = max(G.shake, .45 if any3 else .25)
			if any3 and G.main: G.main.hitstop(.05)
		"laco":
			var e = target
			if e and is_instance_valid(e) and e.alive:
				pull_e = e
				pull_t = .55
				pull_k = 9.0
				hit(e, 30.0, "rosario")
				stun(e, 1.6)
				G.fx.beam(vm_point(-.08, -.05, .6), e.center(), .3, Color(.7, .45, 1, .9), .45)
				G.snd("whirl", -4, .8)
		"puxa":
			var e = pull_e if pull_e else target
			if e and is_instance_valid(e) and e.alive:
				hit(e, 22.0, "rosario")
				G.emit("pink", e.center(), 18, 8, .14, .6)
				G.shake = max(G.shake, .3)
		# ---------- Trombeta do Juízo ----------
		"toque":
			G.blood_take("trombeta")
			_sonic(24.0, 24.0, 34.0, 14.0, false)
		"sino":
			var f4 := -cam_xf().basis.z
			slash_fx(-70, Color(1, .85, .45, .85), 3.4, 1.8, "slash_04", .2)
			for e in in_cone(3.8, 70.0):
				hit(e, 60.0, "trombeta", f4)
				knock(e, f4 * 18.0 + Vector3(0, 6, 0))
				G.shake = max(G.shake, .35)
			G.snd("clang", -6, 1.2)
		"carrega":
			if cur == "trombeta":
				G.fx.charge(vm_point(.05, -.05, 1.6), Color(1, .9, .55), .8, 2.4, -cam_xf().basis.z)
				G.snd("whirl", -6, .5)
			elif cur == "maos":
				G.fx.charge(vm_point(0, -.05, 1.2), Color(1, .85, .5), .7, 2.0, -cam_xf().basis.z)
		"juizo":
			_sonic(42.0, 36.0, 90.0, 22.0, true)
			G.flash = max(G.flash, .5)
			G.add_style(10, "JUÍZO")
		# ---------- Olho da Tempestade ----------
		"raio":
			G.blood_take("olho")
			_chain(vm_point(-.12, .1, .75), 4, 30.0)
		"arremessa":
			_turret_spawn()
		# ---------- Mãos do Criador ----------
		"mao_r", "mao_l":
			if ev == "mao_r" or act != "ataque3": G.blood_take("maos")
			_hand_shot(ev == "mao_r")
		"aperto":
			_crush_all()

# ================================================================ GARRAS: puxão e alma
var pull_e: Node = null
var pull_t := 0.0
var pull_k := 16.0

## puxa o alvo (beijo das garras / laço do rosário) até a frente do jogador
func _upd_pull(dt: float) -> void:
	if pull_e == null: return
	if not is_instance_valid(pull_e) or not pull_e.alive or act != "especial":
		pull_e = null
		return
	var c := cam_xf()
	var dst: Vector3 = G.player.global_position + (-c.basis.z * Vector3(1, 0, 1)).normalized() * 1.8
	if pull_t > 0.0:
		pull_t -= dt
		var k := 1.0 - exp(-pull_k * dt)
		if not pull_e.is_boss:
			pull_e.global_position = pull_e.global_position.lerp(Vector3(dst.x, pull_e.global_position.y, dst.z), k)
			pull_e.velocity = Vector3.ZERO
	elif not pull_e.is_boss:
		pull_e.velocity = Vector3.ZERO

## quem morre queimando pelas garras solta a alma: ela voa até o jogador e cura
func _soul(p: Vector3) -> void:
	G.emit("pink", p, 18, 6, .18, .9, Vector3(0, 3, 0), -2)
	G.fx.beam(p, vm_point(0, -.4, .5), .4, Color(1, .3, .4, .8), .35)
	G.heal(10.0)
	G.blood_add(12.0)
	G.add_style(20, "ALMA ROUBADA")

# ================================================================ ROSÁRIO: eclipse
## anel escuro que se abre no chão (descida do rosário e eclipse da pisada)
func _eclipse_ring(p: Vector3, radius: float, dmg: float, big: bool) -> void:
	G.fx.shock(p, Color(.55, .3, 1.0, .95), radius * 1.3, .5)
	G.fx.ring_v(p + Vector3(0, .8, 0), Vector3.UP, Color(.2, .05, .35, .9), radius, .45)
	G.emit("pink", p, 26 if big else 14, 12, .16, .7)
	for e in G.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
		var d: float = e.center().distance_to(p)
		if d < radius + e.r:
			hit(e, dmg * (1.0 - .4 * d / (radius + .01)), "eclipse" if big else "rosario")
			stun(e, 1.4 if big else .6)
			knock(e, (e.center() - p).normalized() * 6.0 + Vector3(0, 7 if big else 3, 0))

## pisada (slam) com o rosário em mãos: mini-eclipse em volta de onde caiu
func eclipse(p: Vector3) -> void:
	if cur != "rosario": return
	_eclipse_ring(p, 6.5, 120.0, true)
	G.fx.flash(p + Vector3(0, 1.5, 0), Color(.4, .2, .8), 9.0, .45)
	if G.main: G.main.world_flash(p, 10.0)
	G.shake = max(G.shake, .9)
	G.add_style(30, "ECLIPSE")
	G.snd("boom", -4, .6)

# ================================================================ TROMBETA: cone sônico
## rng/half: alcance e meia-abertura; walls = o toque do juízo (atravessa paredes e atordoa)
func _sonic(rng: float, half: float, dmg: float, push: float, walls: bool) -> void:
	var c := cam_xf()
	var f := -c.basis.z
	var mouth := vm_point(.08, -.12, 1.1)
	for i in 5:
		var d := 1.5 + i * (3.8 if walls else 2.2)
		var r := 1.0 + d * tan(deg_to_rad(half)) * .8
		G.fx.ring_v(mouth + f * d, f, Color(1, .92, .6, .8 - i * .12), r, .35 + i * .06)
	G.fx.flash(mouth, Color(1, .9, .6), 3.0, .25)
	G.shake = max(G.shake, .5 if walls else .3)
	if G.main: G.main.world_flash(mouth, 8.0 if walls else 4.0)
	G.snd("boom", -2 if walls else -8, .8 if walls else 1.5)
	var n := 0
	for e in in_cone(rng, half, 99, not walls):
		var dd: float = c.origin.distance_to(e.center())
		var k: float = clamp(1.0 - dd / (rng * 1.15), .25, 1.0)
		hit(e, dmg * k, "trombeta", f)
		knock(e, f * push * k + Vector3(0, 4.0 * k, 0))
		if walls: stun(e, 2.5)
		n += 1
	# projéteis inimigos no caminho voltam
	var back := 0
	for p in G.projs:
		if p.owner != "enemy" or p.life <= 0: continue
		var to: Vector3 = p.m.global_position - c.origin
		if to.length() < (30.0 if walls else 14.0) and rad_to_deg(f.angle_to(to)) < half + 8:
			G.main.parry_proj(p, f)
			back += 1
	if back > 0: G.add_style(25 * back, "DEVOLVIDO")
	if walls and n > 1: G.add_style(15 * n, "ATORDOADOS")

# ================================================================ OLHO: raio em cadeia e torre
func _chain(from: Vector3, max_hits: int, dmg: float) -> void:
	var first := best_target(36.0, 24.0)
	var c := cam_xf()
	if G.main: G.main.world_flash(from, 5.0)
	G.snd("whirl", -8, 1.7)
	if first == null:
		var r = G.shoot(c.origin, -c.basis.z, 36.0, false)
		G.fx.bolt(from, r.end, Color(.4, .85, 1.0), 1.0, .2, 3)
		return
	var hitset := [first]
	var a := from
	var e: Node = first
	var k := 1.0
	for i in max_hits:
		G.fx.bolt(a, e.center(), Color(.45, .85, 1.0), 1.1 - i * .15, .22, 2)
		var ec: Vector3 = e.center()
		hit(e, dmg * k, "olho", (ec - a).normalized())
		G.emit("cyan", ec, 10, 8, .1, .4)
		a = ec
		k *= .8
		var nxt: Node = null
		var bd := 9.0
		for o in G.enemies:
			if not is_instance_valid(o) or not o.alive or o in hitset or o.spawn_t > 0: continue
			var d: float = o.center().distance_to(a)
			if d < bd and G.los(a, o.center()):
				bd = d
				nxt = o
		if nxt == null: break
		hitset.append(nxt)
		e = nxt
	if hitset.size() >= 3: G.add_style(10 * hitset.size(), "CADEIA ×%d" % hitset.size())

var turret_node: Node3D = null
var turret_t := 0.0
var turret_cd := 0.0

## o olho arremessado: flutua onde caiu por 8 s soltando raios; um tiro nele faz ele explodir
func _turret_spawn() -> void:
	if is_instance_valid(turret_node): _turret_explode(false)
	var c := cam_xf()
	var r = G.shoot(c.origin, -c.basis.z, 14.0, false)
	var p: Vector3 = r.end + c.basis.z * .8
	p.y = max(p.y, c.origin.y - .6)
	var body := StaticBody3D.new()
	body.set_script(preload("res://scripts/olho_torre.gd"))
	G.world.add_child(body)
	body.global_position = p
	body.R = self
	turret_node = body
	turret_t = 8.0
	turret_cd = .3
	G.fx.flash(p, Color(.4, .85, 1), 3.0, .3)
	G.snd("whoosh", -4, 1.4)

func _turret_explode(by_shot: bool) -> void:
	if not is_instance_valid(turret_node): return
	var p := turret_node.global_position
	turret_node.queue_free()
	turret_node = null
	if by_shot:
		for e in G.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
			var d: float = e.center().distance_to(p)
			if d < 7.5:
				hit(e, 110.0 * (1.0 - d / 9.0), "olho")
				knock(e, (e.center() - p).normalized() * 14.0 + Vector3(0, 7, 0))
		for i in 6:
			var a := randf() * TAU
			G.fx.bolt(p, p + Vector3(cos(a) * 6, randf_range(-1, 3), sin(a) * 6), Color(.45, .85, 1), 1.2, .3, 2)
		G.fx.flash(p, Color(.5, .9, 1), 10.0, .45)
		G.fx.shock(p - Vector3(0, 1.2, 0), Color(.4, .85, 1), 8.0, .5)
		G.shake = max(G.shake, 1.0)
		G.snd("boom", 0, 1.2)
		G.add_style(40, "OLHO ESTOURADO")
		if G.main: G.main.world_flash(p, 14.0)
	else:
		G.fx.flash(p, Color(.4, .85, 1), 3.0, .3)

func _upd_turret(dt: float) -> void:
	if not is_instance_valid(turret_node): return
	turret_t -= dt
	turret_cd -= dt
	if turret_t <= 0.0:
		_turret_explode(false)
		return
	if turret_cd <= 0.0:
		turret_cd = .6
		var p := turret_node.global_position
		var best: Node = null
		var bd := 20.0
		for e in G.enemies:
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
			var d: float = e.center().distance_to(p)
			if d < bd and G.los(p, e.center()):
				bd = d
				best = e
		if best:
			G.fx.bolt(p, best.center(), Color(.45, .85, 1), .8, .18, 1)
			hit(best, 18.0, "olho")

# ================================================================ MÃOS DO CRIADOR: mãos que agarram
var hands := []   # {"n", "e" (inimigo preso ou null), "v", "t", "ofs", "tick", "big", "tgt"}
var _hand_scene: PackedScene = null

func latched_count() -> int:
	var n := 0
	for h in hands:
		if h.e != null and is_instance_valid(h.e) and h.e.alive: n += 1
	return n

func _hand_shot(right: bool) -> void:
	if _hand_scene == null:
		_hand_scene = load("res://reliquias/mao_projetil.glb")
	var c := cam_xf()
	var f := -c.basis.z
	var start := vm_point(-.12 if right else .12, -.08, .7)
	var n: Node3D = _hand_scene.instantiate()
	G.world.add_child(n)
	var big: bool = G.blas_on
	var s := 2.6 if big else 1.15
	n.global_position = start
	var tgt := best_target(40.0, 10.0)
	var dir := f
	if tgt: dir = (tgt.center() - start).normalized()
	n.basis = Basis.looking_at(-dir, Vector3.UP).scaled(Vector3.ONE * s)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	G.fx.attach_glow(n, Color(1, .85, .5, .8), 2.0 if big else .9, true)
	hands.append({"n": n, "e": null, "v": dir * 42.0, "t": 6.0, "ofs": Vector3.ZERO, "tick": .4, "big": big, "tgt": tgt, "s": s})
	G.snd("whoosh", -6, 1.3)

func _upd_hands(dt: float) -> void:
	if hands.is_empty(): return
	var keep := []
	for h in hands:
		if not is_instance_valid(h.n):
			continue
		h.t -= dt
		if h.e == null:
			# voo com leve busca do alvo
			var tg = h.tgt
			if tg and is_instance_valid(tg) and tg.alive:
				var want: Vector3 = (tg.center() - h.n.global_position).normalized() * h.v.length()
				h.v = h.v.lerp(want, 1.0 - exp(-4.0 * dt))
			var from: Vector3 = h.n.global_position
			var to: Vector3 = from + h.v * dt
			var got: Node = null
			for e in G.enemies:
				if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
				if Geometry3D.get_closest_point_to_segment(e.center(), from, to).distance_to(e.center()) < e.r + (.9 if h.big else .45):
					got = e
					break
			if got == null and G.boss and is_instance_valid(G.boss) and G.boss.alive:
				if Geometry3D.get_closest_point_to_segment(G.boss.center(), from, to).distance_to(G.boss.center()) < 3.0:
					got = G.boss
			if got:
				h.e = got
				var rr: float = got.r * .8 if "r" in got else .5
				h.ofs = (from - got.center()).limit_length(rr)
				h.t = 4.0
				hit(got, 22.0 * (2.0 if h.big else 1.0), "maos", h.v.normalized())
				G.emit("white", from, 10, 6, .12, .4)
				G.snd("hit", -6, .6)
			elif not G.los(from, to) or h.t <= 0.0:
				G.emit("dust", from, 8, 4, .3, .6)
				h.n.queue_free()
				continue
			else:
				h.n.global_position = to
				h.n.basis = Basis.looking_at(-h.v.normalized(), Vector3.UP).scaled(Vector3.ONE * h.s)
		else:
			if not is_instance_valid(h.e) or not h.e.alive or h.t <= 0.0:
				h.n.queue_free()
				continue
			h.n.global_position = h.e.center() + h.ofs
			# aperta: pulsa e tira vida aos poucos
			h.tick -= dt
			var sq := 1.0 + .08 * sin(Time.get_ticks_msec() * .02)
			h.n.basis = h.n.basis.orthonormalized().scaled(Vector3.ONE * h.s * sq)
			if h.tick <= 0.0:
				h.tick = .4
				hit(h.e, 8.0 * (2.0 if h.big else 1.0), "maos")
				G.emit("blood", h.n.global_position, 4, 3, .1, .4)
		keep.append(h)
	hands = keep

## aperto do Criador: todas as mãos presas explodem
func _crush_all() -> void:
	var n := 0
	for h in hands:
		if h.e == null or not is_instance_valid(h.e) or not h.e.alive or not is_instance_valid(h.n): continue
		var p: Vector3 = h.n.global_position
		var k := 2.0 if h.big else 1.0
		hit(h.e, 50.0 * k, "maos")
		for e in G.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
			var d: float = e.center().distance_to(p)
			if d < 3.5 * k:
				hit(e, 70.0 * k * (1.0 - d / (4.5 * k)), "maos")
				knock(e, (e.center() - p).normalized() * 8.0 + Vector3(0, 6, 0))
		G.fx.flash(p, Color(1, .85, .5), 4.0 * k, .35)
		G.fx.ring_v(p, Vector3.UP, Color(1, .8, .45, .9), 3.0 * k, .4)
		G.emit("white", p, 16, 12, .14, .6)
		G.emit("blood2", p, 16, 10, .14, .8)
		h.n.queue_free()
		n += 1
	if n > 0:
		G.shake = max(G.shake, .6 + .1 * n)
		G.snd("boom", -3, .9)
		if G.main: G.main.hitstop(.06)
		G.add_style(20 * n, "ESMAGADOS ×%d" % n)

## limpa o que ficou no mundo (troca de fase, morte, menu)
func reset_world() -> void:
	for h in hands:
		if is_instance_valid(h.n): h.n.queue_free()
	hands.clear()
	if is_instance_valid(turret_node): turret_node.queue_free()
	turret_node = null
	pull_e = null
