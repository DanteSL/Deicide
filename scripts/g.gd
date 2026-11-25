extends Node
## Estado global e utilidades compartilhadas (som, partículas, traçantes, dano, estilo).

const A := 44.0 # meia-largura da arena
const L_WORLD := 1
const L_ENEMY := 2

var main: Node
var player: Node
var cam: Camera3D
var world: Node3D
var enemies: Array = []
var projs: Array = []
var boss: Node = null

var mode = "waves"
var state = "menu"
var hitstop = 0.0
var shake = 0.0
var flash = 0.0
var hurt_v = 0.0
var hit_v = 0.0
var hit_kill = false
var style = 0.0
var best_rank = 0
var stats = {"kills": 0, "t": 0.0}
var sens_mult = 1.0
var fov_base = 100.0
var retro = true
var rng = RandomNumberGenerator.new()

const RANKS := [
	["D", "DEVOTO", Color("a8a29a")], ["C", "CÉTICO", Color("9fc4ff")], ["B", "HEREGE", Color("e8c45a")],
	["A", "APÓSTATA", Color("ff9a2a")], ["S", "SEM FÉ", Color("ff5a1a")], ["SS", "SEM SALVAÇÃO", Color("ff2a2a")],
	["SSS", "SUPREMO SACRILÉGIO", Color("ff1a5a")]]

## Blasfêmia: enche com o estilo (mais rápido nos ranks altos). Cheia, G libera o ritual.
var blas = 0.0
var blas_on = false

signal style_added(label: String)

var _snd_cache = {}
var _players: Array = []
var _tracers: Array = []
var _shocks: Array = []
var _timers: Array = []
var _mat_cache = {}
var _mesh_cache = {}

func _ready() -> void:
	rng.randomize()
	load_save()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 28:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func rnd(a: float, b: float) -> float:
	return rng.randf_range(a, b)

# ---------------- som ----------------
func stream(name: String) -> AudioStream:
	if _snd_cache.has(name):
		return _snd_cache[name]
	var s: AudioStream = null
	for ext in [".wav", ".ogg", ".mp3"]:
		var path: String = "res://sfx/" + name + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_snd_cache[name] = s
	return s

func snd(name: String, vol_db := 0.0, pitch := 1.0, from := 0.0, dur := -1.0) -> void:
	var s = stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[rng.randi() % _players.size()]
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play(from)
	if dur > 0.0:
		var pp = p
		get_tree().create_timer(dur / pitch).timeout.connect(func():
			if pp.stream == s: pp.stop())

# ---------------- timers de jogo (param com a pausa) ----------------
func later(t: float, fn: Callable) -> void:
	_timers.append({"t": t, "fn": fn})

func clear_timers() -> void:
	_timers.clear()

func tick_timers(dt: float) -> void:
	var due = []
	for x in _timers:
		x.t -= dt
		if x.t <= 0.0:
			due.append(x)
	for x in due:
		_timers.erase(x)
	for x in due:
		x.fn.call()

# ---------------- materiais ----------------
func unshaded(c: Color, additive := false) -> StandardMaterial3D:
	var key = str(c) + str(additive)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cache[key] = m
	return m

func lit(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

# ---------------- partículas ----------------
const PCOL := {"blood": Color("8e0a0a"), "blood2": Color("c4161a"), "spark": Color("ffd27a"), "cyan": Color("40e8ff"),
	"white": Color("ffffff"), "dust": Color("6a5a52"), "gib": Color("6a2620"), "metal": Color("5c606c"), "fire": Color("ff7a20"), "pink": Color("ff40c8")}

func emit(kind: String, pos: Vector3, n: int, speed: float, size: float, life: float, bias := Vector3.ZERO, grav := 30.0) -> void:
	if world == null or n <= 0:
		return
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.local_coords = false
	var key = kind + str(snappedf(size, 0.01))
	if not _mesh_cache.has(key):
		var bm = BoxMesh.new()
		bm.size = Vector3.ONE * size
		bm.material = unshaded(PCOL.get(kind, Color.WHITE))
		_mesh_cache[key] = bm
	p.mesh = _mesh_cache[key]
	if bias != Vector3.ZERO:
		p.direction = bias.normalized()
		p.spread = 55.0
	else:
		p.direction = Vector3.UP
		p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var cv = Curve.new()
	cv.add_point(Vector2(0, 1))
	cv.add_point(Vector2(0.65, 1))
	cv.add_point(Vector2(1, 0))
	p.scale_amount_curve = cv
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life * 1.6 + 0.2).timeout.connect(p.queue_free)

# ---------------- traçantes ----------------
var _tr_mesh: BoxMesh
func tracer(a: Vector3, b: Vector3, w: float, color: Color, life := 0.1) -> void:
	if world == null or a.distance_to(b) < 0.01:
		return
	if _tr_mesh == null:
		_tr_mesh = BoxMesh.new()
		_tr_mesh.size = Vector3.ONE
	var m = MeshInstance3D.new()
	m.mesh = _tr_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.disable_fog = true
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	var len = a.distance_to(b)
	m.global_position = (a + b) * 0.5
	var up = Vector3.UP if abs((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	m.look_at(b, up)
	m.scale = Vector3(w, w, len)
	_tracers.append({"m": m, "life": life, "max": life, "w": w, "mat": mat, "c": color})

func _process(dt: float) -> void:
	for t in _tracers:
		t.life -= dt
		var k: float = clamp(t.life / t.max, 0.0, 1.0)
		t.mat.albedo_color = Color(t.c.r, t.c.g, t.c.b, k)
		var s: Vector3 = t.m.scale
		t.m.scale = Vector3(t.w * (0.4 + 0.6 * k), t.w * (0.4 + 0.6 * k), s.z)
		if t.life <= 0:
			t.m.queue_free()
	_tracers = _tracers.filter(func(t): return t.life > 0)
	for s in _shocks:
		s.life -= dt
		var u: float = 1.0 - s.life / s.max
		s.m.scale = Vector3.ONE * (0.5 + s.r * (1.0 - pow(1.0 - clamp(u, 0.0, 1.0), 3.0)))
		s.mat.albedo_color.a = 0.8 * (1.0 - u)
		if s.life <= 0:
			s.m.queue_free()
	_shocks = _shocks.filter(func(s): return s.life > 0)

# ---------------- estilo ----------------
func add_style(pts: float, label: String) -> void:
	style = min(RANKS.size() * 100 - 1, style + pts)
	if not blas_on:
		blas = min(100.0, blas + pts * (0.05 + rank() * 0.025))
	style_added.emit(label)

func rank() -> int:
	return int(style / 100.0)

# ---------------- dano ----------------
func heal(n: float) -> void:
	if player:
		player.hp = min(100.0, player.hp + n)

func hurt_player(d: float) -> bool:
	if player == null or player.dash_t > 0.0 or player.dead:
		return false
	player.hp -= d
	if mode == "train":
		player.hp = max(1.0, player.hp)
	hurt_v = 1.0
	shake = max(shake, 0.45)
	snd("hurt", -4)
	style = max(0.0, style - 45.0)
	blas = max(0.0, blas - 4.0)
	if player.hp <= 0.0:
		main.die()
	return true

func enemy_from(col) -> Node:
	if col == null:
		return null
	if col.has_method("take_damage"):
		return col
	if col.has_meta("enemy"):
		return col.get_meta("enemy")
	return null

func hurt_enemy(e, dmg: float, src: String, point: Vector3, head: bool, dir := Vector3.ZERO) -> bool:
	if e == null or not is_instance_valid(e) or not e.alive:
		return false
	emit("blood" if rng.randf() < 0.5 else "blood2", point, int(min(18, 4 + dmg / 6.0)), 9, 0.12, 0.7, dir)
	if player and e.global_position.distance_to(player.global_position) < 7.0:
		heal(dmg * 0.3)
	if src != "burn":
		hit_v = 1.0
		hit_kill = false
		snd("hit", -10, rnd(0.95, 1.1))
	return e.take_damage(dmg, src, head)

const KILL_LABEL := {"rev": "ABATE", "rico": "RICOCHETE", "sg": "ABATE", "punch": "NOCAUTE", "parry": "DEVOLVIDO", "slam": "ESMAGADO",
	"sword": "ESPADA ALADA", "rocket": "FOGUETE", "nail": "PREGADO", "rail": "TRESPASSADO", "harp": "ARPOADO", "gren": "GRANADA", "burn": "QUEIMADO", "blas": "EXECUTADO"}
var _last_src = ""
var _streak = 0
func on_kill(e, src: String, head: bool) -> void:
	stats.kills += 1
	hit_v = 1.0
	hit_kill = true
	snd("kill", -4)
	shake = max(shake, 0.18)
	_streak = _streak + 1 if src == _last_src else 0
	_last_src = src
	var fresh = 0.5 if _streak >= 4 else 1.0
	var big: bool = e.kind == "brute"
	add_style((90.0 if big else 40.0) * fresh, ("BRUTO · " if big else "") + KILL_LABEL.get(src, "ABATE"))
	if head:
		add_style(25, "TIRO NA CABEÇA")
	if player and not player.is_on_floor():
		add_style(30, "AÉREO")
	if src != "burn" and src != "parry" and Time.get_ticks_msec() - player.weapons.switch_time < 1200:
		add_style(20, "TROCA RÁPIDA")

# ---------------- raio (tiro instantâneo) ----------------
func shoot(o: Vector3, d: Vector3, rng_len: float, pierce: bool) -> Dictionary:
	var space = world.get_world_3d().direct_space_state
	var end = o + d * rng_len
	var q = PhysicsRayQueryParameters3D.create(o, end, 1)
	var wh = space.intersect_ray(q)
	var wall_d = rng_len
	if wh:
		wall_d = o.distance_to(wh.position)
	var hits = []
	var excl: Array[RID] = []
	for i in 12:
		var q2 = PhysicsRayQueryParameters3D.create(o, o + d * wall_d, 2)
		q2.exclude = excl
		var h = space.intersect_ray(q2)
		if not h:
			break
		excl.append(h.rid)
		var e = enemy_from(h.collider)
		if e and e.alive:
			hits.append({"e": e, "point": h.position, "head": e.is_head(h.position)})
			if not pierce:
				break
	var end_d = wall_d
	if not pierce and hits.size() > 0:
		end_d = o.distance_to(hits[0].point)
	return {"hits": hits, "end": o + d * end_d, "wall": hits.is_empty() and wh}

func los(a: Vector3, b: Vector3) -> bool:
	var q = PhysicsRayQueryParameters3D.create(a, b, 1)
	return not world.get_world_3d().direct_space_state.intersect_ray(q)

func in_solid(p: Vector3) -> bool:
	var q = PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_point(q, 1).size() > 0

# ---------------- explosão ----------------
var _sph: SphereMesh
func blast(q: Vector3, k := 1.0, src := "parry") -> void:
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0:
			continue
		var d: float = q.distance_to(e.center())
		if d < 10.0 * k:
			hurt_enemy(e, 140.0 * k * (1.0 - d / (12.0 * k)), src, q, false)
			if is_instance_valid(e) and e.alive and not e.is_boss:
				e.velocity += (e.center() - q).normalized() * 18.0 + Vector3(0, 9, 0)
	emit("cyan", q, int(50 * k), 26 * k, 0.22, 0.8)
	emit("spark", q, int(60 * k), 32 * k, 0.14, 0.8)
	emit("dust", q, int(30 * k), 14 * k, 0.4, 1.2)
	if _sph == null:
		_sph = SphereMesh.new()
		_sph.radius = 1.0
		_sph.height = 2.0
	for spec in [[Color(1, 1, 1), 9.0 * k, 0.35], [Color("40e8ff"), 12.0 * k, 0.55]]:
		var m = MeshInstance3D.new()
		m.mesh = _sph
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = spec[0]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		world.add_child(m)
		m.global_position = q
		_shocks.append({"m": m, "mat": mat, "r": spec[1], "life": spec[2], "max": spec[2]})
	if main:
		main.world_flash(q, 16.0)
	flash = max(flash, 0.7)
	shake = max(shake, 1.3)
	snd("boom", 0)

# ---------------- arsenal: armas, melhorias e equipamento ----------------
const WEAP := [
	{"id": "rev", "name": "REVÓLVER", "short": "REV", "desc": "6 balas. Direito (segurar): gira a arma e carrega o ricochete entre inimigos."},
	{"id": "sg", "name": "ESCOPETA", "short": "ESC", "desc": "6 cartuchos, gira a cada tiro. Direito: rajada dupla (coice que te empurra — mire no chão para voar)."},
	{"id": "sword", "name": "ESPADAS ALADAS", "short": "ESP", "desc": "4 espadas sobre as mãos. Clique arremessa uma; direito: tempestade teleguiada (com espadas fora, chama de volta)."},
	{"id": "rocket", "name": "LANÇA-FOGUETES", "short": "FOG", "desc": "Foguete explosivo; perto de você, te arremessa. Direito: míssil guiado pela mira enquanto segura, soltar detona."},
	{"id": "nail", "name": "PREGADORA", "short": "PRE", "desc": "Rajada contínua de pregos. Esquenta e trava se superaquecer. Direito: descarga térmica num leque incandescente."},
	{"id": "rail", "name": "FUZIL DE RAIO", "short": "RAI", "desc": "Raio que atravessa tudo na linha, dano altíssimo, recarga lenta. Direito: luneta (zoom)."},
	{"id": "harp", "name": "ARPÃO", "short": "ARP", "desc": "Arpão com cabo que fisga inimigos. Direito: gancho, te puxa até a parede ou o inimigo."},
	{"id": "gren", "name": "LANÇA-GRANADAS", "short": "GRA", "desc": "Granadas que quicam e explodem no pavio ou ao tocar um inimigo. Direito: detona todas."}]
const UPG := {
	"rev": [["ext", "Tambor estendido", "8 balas em vez de 6."], ["fast", "Ricochete rápido", "Carrega o ricochete na metade do tempo."], ["pierce", "Bala perfurante", "O tiro normal atravessa inimigos."]],
	"sg": [["fire", "Cartuchos incendiários", "O chumbo põe fogo: inimigos queimam por 3 s."], ["drum", "Carregador de tambor", "10 cartuchos."], ["fast", "Bombeamento rápido", "Atira e recarrega bem mais rápido."]],
	"sword": [["boom", "Lâminas explosivas", "Explodem no primeiro inimigo que atingem."], ["fast", "Asas velozes", "Voam e voltam muito mais rápido."], ["heal", "Lâminas sagradas", "Cada acerto cura 6 de vida."]],
	"rocket": [["fast", "Recarga automática", "Recarrega na metade do tempo."], ["frag", "Fragmentação", "A explosão espalha estilhaços incandescentes."], ["jump", "Salto potente", "Salto-foguete 50% mais forte."]],
	"nail": [["cool", "Refrigeração", "Esquenta 40% mais devagar."], ["bounce", "Pregos saltitantes", "Pregos quicam uma vez nas paredes."], ["magnet", "Ímã", "Pregos curvam até o inimigo mais próximo."]],
	"rail": [["cap", "Capacitor", "Recarga do raio em 0,9 s."], ["chain", "Sobrecarga", "Cada acerto solta arcos elétricos em 2 inimigos próximos."], ["wide", "Raio largo", "Atinge também quem estiver perto da linha do raio."]],
	"harp": [["long", "Cabo longo", "Alcance do arpão de 40 para 70."], ["barb", "Arpão farpado", "Puxa o inimigo atingido até você."], ["impact", "Aterrissagem", "Chegar pelo gancho causa uma explosão."]],
	"gren": [["sticky", "Aderentes", "Grudam em inimigos e superfícies."], ["frag", "Bomba cacho", "Explode em 3 mini-granadas."], ["short", "Pavio curto", "Explode em 0,8 s e voa mais longe."]]}
var UP := {}
var vol = 0.8
var mvol = 0.8
var loadout: Array = [0, 1, 2, 3, 4, 5, 6, 7]
const SAVE := "user://save.cfg"

func load_save() -> void:
	var cf = ConfigFile.new()
	var ok = cf.load(SAVE) == OK
	for k in UPG:
		UP[k] = {}
		for u in UPG[k]:
			UP[k][u[0]] = ok and bool(cf.get_value("up", k + "." + u[0], false))
	if ok:
		var lo = cf.get_value("arsenal", "loadout", loadout)
		if lo is Array and lo.size() > 0: loadout = lo.duplicate()
		sens_mult = float(cf.get_value("cfg", "sens", sens_mult))
		fov_base = float(cf.get_value("cfg", "fov", fov_base))
		retro = bool(cf.get_value("cfg", "retro", retro))
		vol = float(cf.get_value("cfg", "vol", vol))
		mvol = float(cf.get_value("cfg", "mvol", mvol))
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_mute(0, vol <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(vol, 0.001)))

func save() -> void:
	var cf = ConfigFile.new()
	for k in UP:
		for u in UP[k]: cf.set_value("up", k + "." + u, UP[k][u])
	cf.set_value("arsenal", "loadout", loadout)
	cf.set_value("cfg", "sens", sens_mult)
	cf.set_value("cfg", "fov", fov_base)
	cf.set_value("cfg", "retro", retro)
	cf.set_value("cfg", "vol", vol)
	cf.set_value("cfg", "mvol", mvol)
	cf.save(SAVE)
