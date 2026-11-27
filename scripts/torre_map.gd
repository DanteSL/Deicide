extends Node3D
## O Vale da Torre — o começo do jogo (prólogo; por enquanto sem chefe).
## Um vale morto entre montanhas, com cemitério e capela em ruínas; uma ponte gótica de arcos
## sobre um abismo sem fundo; e, no planalto do outro lado, uma torre tão alta que some no céu.
## Lá em cima um vórtice negro gira em volta do único ponto de luz do mundo.

const TOWER := Vector3(0, 0, -330)
const TIERS := 24
const TIER_H := 41.0
const PLINTH := 3.0               # altura do embasamento da torre
const TOP_Y := PLINTH + TIERS * TIER_H   # topo do corpo da torre (~987)
const VORTEX_Y := 1075.0
const BR_Z0 := 100.0              # borda do vale (cabeceira da ponte)
const BR_Z1 := -80.0              # borda do planalto da torre
const DECK_W := 10.0
const TX0 := -440.0
const TZ0 := -800.0
const TS := 4.0
const TW := 221                   # pontos em x: -440 .. 440
const TD := 371                   # pontos em z: -800 .. 680
## pontos de retorno: começo do vale, cabeceira da ponte, planalto
const CPS := [Vector3(0, 0, 345), Vector3(0, 0, 116), Vector3(0, 0, -100)]

# tons (multiplicam a textura de pedra)
const C_STONE := Color(.84, .85, .9)
const C_DARK := Color(.55, .56, .6)
const C_LIGHT := Color(1.05, 1.06, 1.1)
const C_WIN := Color(.04, .04, .05)
const C_BARK := Color(.5, .46, .43)

## encontros: quando o jogador passa de "z", os inimigos aparecem nas posições (x, z)
const ENC := [
	{"z": 318.0, "e": [["husk", -12, 268], ["husk", 14, 262], ["husk", 0, 250]]},
	{"z": 262.0, "e": [["husk", -34, 205], ["husk", 30, 210], ["husk", -10, 196], ["husk", 16, 190], ["drone", -20, 214], ["drone", 22, 206]]},
	{"z": 200.0, "e": [["brute", 0, 142], ["husk", -16, 152], ["husk", 16, 152], ["caida", 4, 134], ["drone", 0, 162]]},
	{"z": 98.0, "cp": 1, "e": [["drone", -12, 52], ["drone", 12, 46], ["drone", -6, 26], ["drone", 8, 16]]},
	{"z": 30.0, "e": [["husk", -2, -50], ["husk", 3, -58], ["brute", 0, -68]]},
	{"z": -94.0, "cp": 2, "e": [["husk", -30, -150], ["husk", 30, -150], ["husk", -12, -170], ["husk", 14, -172], ["brute", -24, -188], ["drone", -30, -160], ["drone", 30, -164], ["caida", 0, -200]]},
	{"z": -176.0, "e": [["brute", 20, -238], ["brute", -20, -238], ["caida", -10, -250], ["caida", 10, -250], ["husk", -36, -228], ["husk", 36, -228], ["husk", 0, -224], ["drone", -26, -248], ["drone", 26, -248], ["drone", 0, -260]]},
]
## em que encontro cada ponto de retorno recomeça
const CP_ENC := [0, 3, 5]

class Acc:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

var hmap := PackedFloat32Array()
var n_ground: FastNoiseLite
var n_mount: FastNoiseLite
var n_edge: FastNoiseLite
var rng := RandomNumberGenerator.new()
var _acc := {}
var _parr := {}
var solid: StaticBody3D
var m_stone: StandardMaterial3D
var m_top: StandardMaterial3D
var m_ground: StandardMaterial3D
var m_bark: StandardMaterial3D
var m_bird: StandardMaterial3D
var vortex_mat: ShaderMaterial
var shaft_mat: ShaderMaterial
var glow_core: MeshInstance3D
var glow_halo: MeshInstance3D
var top_light: OmniLight3D
var pivots: Array = []
var birds: Array = []
var chasm_mists: Array = []
var ash: CPUParticles3D
var t := 0.0
var flash := 0.0
var next_flash := 4.0
# progresso
var enc_i := 0
var cp := 0
var keep_cp := false
var running := false
var finale := false

# ======================================================================
# montagem
# ======================================================================
func build(_m: Node) -> void:
	rng.seed = 90210
	_noises()
	_mats()
	solid = StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	add_child(solid)
	_build_terrain()
	_build_far_ring()
	_build_bridge()
	_build_gates()
	_build_colonnade()
	_build_cemetery()
	_build_chapel()
	_build_plateau()
	_build_tower()
	_build_trees()
	_build_rocks()
	_build_walls()
	_commit("st", m_stone)
	_commit("top", m_top)
	_commit("bark", m_bark)
	_build_statues()
	_build_vortex()
	_build_debris()
	_build_birds()
	_build_mist()
	_build_ash()
	_build_grass()

func _noises() -> void:
	n_ground = FastNoiseLite.new()
	n_ground.seed = 11
	n_ground.frequency = .012
	n_ground.fractal_octaves = 3
	n_mount = FastNoiseLite.new()
	n_mount.seed = 23
	n_mount.frequency = .006
	n_mount.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_mount.fractal_octaves = 5
	n_edge = FastNoiseLite.new()
	n_edge.seed = 5
	n_edge.frequency = .02
	n_edge.fractal_octaves = 2

func _noise_tex(freq: float, seed_: int, c0: Color, c1: Color, normal := false, oct := 5) -> NoiseTexture2D:
	var n = FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = oct
	var tx = NoiseTexture2D.new()
	tx.width = 512; tx.height = 512
	tx.seamless = true
	tx.noise = n
	if normal:
		tx.as_normal_map = true
		tx.bump_strength = 10.0
	else:
		var g = Gradient.new()
		g.set_color(0, c0); g.set_color(1, c1)
		tx.color_ramp = g
	return tx

func _mats() -> void:
	m_stone = StandardMaterial3D.new()
	m_stone.albedo_texture = _noise_tex(.018, 7, Color(.3, .31, .34), Color(.52, .53, .57))
	m_stone.normal_enabled = true
	m_stone.normal_texture = _noise_tex(.03, 8, Color.BLACK, Color.WHITE, true)
	m_stone.normal_scale = .8
	m_stone.vertex_color_use_as_albedo = true
	m_stone.uv1_triplanar = true
	m_stone.uv1_world_triplanar = true
	m_stone.uv1_scale = Vector3.ONE * .12
	m_stone.roughness = .92
	# o topo da torre fica acima da neblina e é iluminado pela luz do vórtice
	m_top = m_stone.duplicate()
	m_top.disable_fog = true
	m_ground = StandardMaterial3D.new()
	m_ground.albedo_texture = _noise_tex(.02, 3, Color(.55, .55, .55), Color(1, 1, 1))
	m_ground.normal_enabled = true
	m_ground.normal_texture = _noise_tex(.045, 4, Color.BLACK, Color.WHITE, true)
	m_ground.vertex_color_use_as_albedo = true
	m_ground.uv1_triplanar = true
	m_ground.uv1_world_triplanar = true
	m_ground.uv1_scale = Vector3.ONE * .07
	m_ground.roughness = .97
	m_bark = StandardMaterial3D.new()
	m_bark.albedo_texture = _noise_tex(.05, 21, Color(.32, .3, .29), Color(.55, .52, .5), false, 3)
	m_bark.vertex_color_use_as_albedo = true
	m_bark.uv1_triplanar = true
	m_bark.uv1_world_triplanar = true
	m_bark.uv1_scale = Vector3(.6, .15, .6)
	m_bark.roughness = .95
	m_bird = StandardMaterial3D.new()
	m_bird.albedo_color = Color(.02, .02, .025)
	m_bird.roughness = .7

# ======================================================================
# acumulador de malha: todas as peças de pedra viram uma malha só
# ======================================================================
func A(key: String) -> Acc:
	if not _acc.has(key): _acc[key] = Acc.new()
	return _acc[key]

func _prim_arr(kind: String) -> Array:
	if _parr.has(kind): return _parr[kind]
	var m: PrimitiveMesh
	match kind:
		"box":
			m = BoxMesh.new()
		"prism":
			m = PrismMesh.new()
		"cyl":
			var c = CylinderMesh.new()
			c.top_radius = .5; c.bottom_radius = .5; c.height = 1.0
			c.radial_segments = 12; c.rings = 0
			m = c
		"sphere":
			var s = SphereMesh.new()
			s.radius = .5; s.height = 1.0; s.radial_segments = 7; s.rings = 4
			m = s
		"torus":
			var tm = TorusMesh.new()
			tm.inner_radius = .86; tm.outer_radius = 1.0; tm.rings = 40; tm.ring_segments = 6
			m = tm
	var a = m.get_mesh_arrays()
	_parr[kind] = [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX]]
	return _parr[kind]

func _put(key: String, kind: String, xf: Transform3D, col := C_STONE) -> void:
	var src: Array = _prim_arr(kind)
	var a: Acc = A(key)
	var base := a.v.size()
	var nb: Basis = xf.basis.inverse().transposed()
	var sv: PackedVector3Array = src[0]
	var sn: PackedVector3Array = src[1]
	var si: PackedInt32Array = src[2]
	for k in sv.size():
		a.v.append(xf * sv[k])
		a.n.append((nb * sn[k]).normalized())
		a.c.append(col)
	for k in si.size():
		a.i.append(base + si[k])

func _bx(pos: Vector3, size: Vector3, col := C_STONE, rot := Vector3.ZERO, key := "st") -> void:
	_put(key, "box", Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), col)

## caixa com colisão
func _bxc(pos: Vector3, size: Vector3, col := C_STONE, rot := Vector3.ZERO, key := "st") -> void:
	_bx(pos, size, col, rot, key)
	_cbox(pos, size, rot)

func _cbox(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	solid.add_child(cs)

## tronco de pirâmide retangular (agulhas, pináculos, contrafortes): base em c, altura h
func _fr(c: Vector3, h: float, ax0: float, az0: float, ax1: float, az1: float, col := C_STONE, key := "st", ry := 0.0) -> void:
	var a: Acc = A(key)
	var rb = Basis(Vector3.UP, ry)
	var b0 = [Vector3(-ax0, 0, -az0), Vector3(ax0, 0, -az0), Vector3(ax0, 0, az0), Vector3(-ax0, 0, az0)]
	var b1 = [Vector3(-ax1, h, -az1), Vector3(ax1, h, -az1), Vector3(ax1, h, az1), Vector3(-ax1, h, az1)]
	for s in 4:
		var p0: Vector3 = c + rb * b0[s]
		var p1: Vector3 = c + rb * b0[(s + 1) % 4]
		var q0: Vector3 = c + rb * b1[s]
		var q1: Vector3 = c + rb * b1[(s + 1) % 4]
		var mid = (p0 + p1) * .5 - c
		mid.y = 0
		var nrm = (p1 - p0).cross(q0 - p0)
		if nrm.length() < .0001: nrm = (p1 - p0).cross(q1 - p0)
		nrm = nrm.normalized()
		if nrm.dot(mid) < 0: nrm = -nrm
		var base = a.v.size()
		for p in [p0, q0, p1, q1]:
			a.v.append(p); a.n.append(nrm); a.c.append(col)
		_quad_idx(a, base, p0, q0, p1, nrm)
	if ax1 > .01 and az1 > .01:
		var base2 = a.v.size()
		for k in 4:
			a.v.append(c + rb * b1[k]); a.n.append(Vector3.UP); a.c.append(col)
		a.i.append_array([base2, base2 + 1, base2 + 2, base2, base2 + 2, base2 + 3])

## índices de um quad (p0, q0, p1, q1) com a frente virada para nrm (Godot: horário = frente)
func _quad_idx(a: Acc, base: int, p0: Vector3, q0: Vector3, p1: Vector3, nrm: Vector3) -> void:
	var rh = (q0 - p0).cross(p1 - p0)
	if rh.dot(nrm) < 0:
		a.i.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
	else:
		a.i.append_array([base, base + 2, base + 1, base + 2, base + 3, base + 1])

## segmento redondo (galhos, colunas, agulhas): de a até b, raio r0 -> r1
func _seg(a: Vector3, b: Vector3, r0: float, r1: float, sides := 6, col := C_STONE, key := "st", cap := false) -> void:
	var acc: Acc = A(key)
	var ax = b - a
	var L = ax.length()
	if L < .001: return
	var d = ax / L
	var up = Vector3.UP if abs(d.y) < .95 else Vector3.RIGHT
	var u = d.cross(up).normalized()
	var w = d.cross(u).normalized()
	var base = acc.v.size()
	var slope = (r0 - r1) / L
	for s in sides + 1:
		var ang = TAU * s / sides
		var dir = u * cos(ang) + w * sin(ang)
		var nrm = (dir + d * slope).normalized()
		acc.v.append(a + dir * r0); acc.n.append(nrm); acc.c.append(col)
		acc.v.append(b + dir * r1); acc.n.append(nrm); acc.c.append(col)
	for s in sides:
		var i0 = base + s * 2
		acc.i.append_array([i0, i0 + 1, i0 + 2, i0 + 2, i0 + 1, i0 + 3])
	if cap and r1 > .01:
		var cb = acc.v.size()
		acc.v.append(b); acc.n.append(d); acc.c.append(col)
		for s in sides + 1:
			var ang = TAU * s / sides
			acc.v.append(b + (u * cos(ang) + w * sin(ang)) * r1); acc.n.append(d); acc.c.append(col)
		for s in sides:
			acc.i.append_array([cb, cb + 2 + s, cb + 1 + s])

## pedra facetada: esfera deformada por ruído, sombreamento chapado
func _rock(pos: Vector3, size: Vector3, col := C_STONE, key := "st", rot := Vector3.ZERO) -> void:
	var src: Array = _prim_arr("sphere")
	var a: Acc = A(key)
	var sv: PackedVector3Array = src[0]
	var si: PackedInt32Array = src[2]
	var b = Basis.from_euler(rot) * Basis.from_scale(size)
	var sd = rng.randf() * 1000.0
	var pts := PackedVector3Array()
	for k in sv.size():
		var q: Vector3 = sv[k]
		var nz = n_edge.get_noise_3d(q.x * 260.0 + sd, q.y * 260.0, q.z * 260.0)
		pts.append(pos + b * (q * (1.0 + nz * .45)))
	for k in range(0, si.size(), 3):
		var p0 = pts[si[k]]; var p1 = pts[si[k + 1]]; var p2 = pts[si[k + 2]]
		var nrm = -(p1 - p0).cross(p2 - p0)
		if nrm.length() < .00001: continue
		nrm = nrm.normalized()
		var base = a.v.size()
		for p in [p0, p1, p2]:
			a.v.append(p); a.n.append(nrm); a.c.append(col)
		a.i.append_array([base, base + 1, base + 2])

func _commit(key: String, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	if not _acc.has(key): return null
	var a: Acc = _acc[key]
	_acc.erase(key)
	if a.v.is_empty(): return null
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a.v
	arr[Mesh.ARRAY_NORMAL] = a.n
	arr[Mesh.ARRAY_COLOR] = a.c
	arr[Mesh.ARRAY_INDEX] = a.i
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi

## arco gótico (ogival) no plano local XY: largura s, flecha "rise", espessura do anel e profundidade
func _arch(c: Vector3, s: float, rise: float, thick: float, depth: float, ry: float, col := C_LIGHT, key := "st", segs := 12) -> void:
	var rb = Basis(Vector3.UP, ry)
	var prev = Vector3.ZERO
	for q in segs + 1:
		var u = -1.0 + 2.0 * q / segs
		var p = Vector3(u * s * .5, _ogive(u) * rise, 0)
		if q > 0:
			var d = p - prev
			var mid = (p + prev) * .5
			var ang = atan2(d.y, d.x)
			_put(key, "box", Transform3D(rb * Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(d.length() + thick * .45, thick, depth)), c + rb * mid), col)
		prev = p

## altura normalizada (0..1) de um arco ogival equilátero em u = -1..1
func _ogive(u: float) -> float:
	var a = abs(u) + 1.0
	return sqrt(max(0.0, 4.0 - a * a)) / sqrt(3.0)

## parede com vão em arco ogival: preenche de cima do arco até y_top (tira por tira)
func _spandrel(c: Vector3, s: float, rise: float, y_top: float, depth: float, ry: float, col := C_STONE, strip := 1.0, key := "st") -> void:
	var rb = Basis(Vector3.UP, ry)
	var n = int(ceil(s / strip))
	var w = s / n
	for k in n:
		var x = -s * .5 + (k + .5) * w
		var ya = c.y + _ogive(x / (s * .5)) * rise
		var h = y_top - ya
		if h <= .05: continue
		_put(key, "box", Transform3D(rb * Basis.from_scale(Vector3(w * 1.02, h + .25, depth)), Vector3(c.x, 0, c.z) + rb * Vector3(x, 0, 0) + Vector3(0, ya + h * .5 - .125, 0)), col)

# ======================================================================
# terreno
# ======================================================================
func _path_x(z: float) -> float:
	if z > BR_Z0 + 40.0: return sin(z * .013 + .8) * 16.0 * clamp((z - BR_Z0 - 40.0) / 60.0, 0.0, 1.0)
	return 0.0

## meia-largura do chão jogável ao longo do mapa
func _hw(z: float) -> float:
	if z >= BR_Z0: return lerp(60.0, 115.0, clamp((z - BR_Z0) / 90.0, 0.0, 1.0))
	if z <= BR_Z1: return lerp(75.0, 160.0, clamp((BR_Z1 - z) / 100.0, 0.0, 1.0))
	return 50.0

func _mtn(e: float, x: float, z: float) -> float:
	if e <= 0.0: return 0.0
	var r = n_mount.get_noise_2d(x, z)
	return pow(e / 70.0, 1.5) * 45.0 * (.8 + .55 * r) + max(0.0, r) * e * .25

func _h(x: float, z: float) -> float:
	var h = n_ground.get_noise_2d(x, z) * 1.6 + n_ground.get_noise_2d(x * 3.7 + 100.0, z * 3.7) * .35
	# trilha mais plana
	var pd = abs(x - _path_x(z))
	h *= lerp(.25, 1.0, clamp((pd - 4.0) / 12.0, 0.0, 1.0))
	# praça plana em volta da torre e nas cabeceiras da ponte
	var dt = Vector2(x - TOWER.x, z - TOWER.z).length()
	h *= clamp((dt - 100.0) / 40.0, 0.0, 1.0)
	var near_head = clamp((abs(x) - 14.0) / 10.0, 0.0, 1.0)
	if abs(z - BR_Z0) < 34.0 or abs(z - BR_Z1) < 34.0:
		h = lerp(-.04, h, near_head)
	var en = n_edge.get_noise_2d(z * .6, x * .05) * 16.0
	# perto do abismo as montanhas descem (nada de paredões gigantes no cânion)
	var dch = (z - BR_Z0) if z > BR_Z0 else ((BR_Z1 - z) if z < BR_Z1 else 0.0)
	var mk = lerp(.12, 1.0, smoothstep(10.0, 170.0, dch))
	var m = _mtn(abs(x) - _hw(z) + en, x, z) * mk
	m += _mtn(z - 400.0 + n_edge.get_noise_2d(x * .7, 40.0) * 18.0, x, z + 300.0)
	m += _mtn(-525.0 - z + n_edge.get_noise_2d(x * .7, 80.0) * 18.0, x + 200.0, z)
	h += min(m, 290.0 + n_mount.get_noise_2d(x * 2.0, z * 2.0) * 50.0)
	# o abismo corta o mapa de montanha a montanha
	var nb = clamp((abs(x) - 12.0) / 10.0, 0.0, 1.0)
	var c0 = BR_Z0 + n_edge.get_noise_2d(x * 1.4, 7.0) * 9.0 * nb
	var c1 = BR_Z1 + n_edge.get_noise_2d(x * 1.4, 99.0) * 9.0 * nb
	if z < c0 and z > c1:
		var d = min(c0 - z, z - c1)
		h = lerp(h, -300.0 + n_ground.get_noise_2d(x * .2, z * .2) * 30.0, smoothstep(0.0, 1.0, clamp(d / 12.0, 0.0, 1.0)))
	return h

## altura do terreno (interpolada da mesma grade da colisão)
func ground(x: float, z: float) -> float:
	var fx = (x - TX0) / TS
	var fz = (z - TZ0) / TS
	var ix = clampi(int(floor(fx)), 0, TW - 2)
	var iz = clampi(int(floor(fz)), 0, TD - 2)
	var u = clamp(fx - ix, 0.0, 1.0)
	var v = clamp(fz - iz, 0.0, 1.0)
	var h00 = hmap[iz * TW + ix]; var h10 = hmap[iz * TW + ix + 1]
	var h01 = hmap[(iz + 1) * TW + ix]; var h11 = hmap[(iz + 1) * TW + ix + 1]
	return lerp(lerp(h00, h10, u), lerp(h01, h11, u), v)

func _build_terrain() -> void:
	hmap.resize(TW * TD)
	for iz in TD:
		var z = TZ0 + iz * TS
		for ix in TW:
			hmap[iz * TW + ix] = _h(TX0 + ix * TS, z)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(TW * TD); norms.resize(TW * TD); cols.resize(TW * TD)
	var c_earth = Color(.3, .285, .26)
	var c_grass = Color(.36, .345, .28)
	var c_path = Color(.47, .46, .44)
	var c_rock = Color(.38, .39, .43)
	var c_deep = Color(.08, .085, .1)
	var c_peak = Color(.5, .51, .56)
	for iz in TD:
		var z = TZ0 + iz * TS
		for ix in TW:
			var k = iz * TW + ix
			var x = TX0 + ix * TS
			var y = hmap[k]
			var hl = hmap[iz * TW + max(ix - 1, 0)]; var hr = hmap[iz * TW + min(ix + 1, TW - 1)]
			var hd = hmap[max(iz - 1, 0) * TW + ix]; var hu = hmap[min(iz + 1, TD - 1) * TW + ix]
			var nrm = Vector3(hl - hr, 2.0 * TS, hd - hu).normalized()
			verts[k] = Vector3(x, y, z)
			norms[k] = nrm
			var slope = 1.0 - nrm.y
			var nz = n_ground.get_noise_2d(x * 2.3, z * 2.3) * .5 + .5
			var c = c_earth.lerp(c_grass, nz)
			var pd = abs(x - _path_x(z))
			var on_path = (z > BR_Z0 or z < BR_Z1) and z > -270.0
			if on_path: c = c.lerp(c_path, clamp(1.0 - (pd - 2.0) / 3.0, 0.0, 1.0) * .85)
			c = c.lerp(c_rock, smoothstep(.1, .32, slope))
			if y < -12.0: c = c.lerp(c_deep, clamp((-12.0 - y) / 90.0, 0.0, 1.0))
			if y > 140.0: c = c.lerp(c_peak, clamp((y - 140.0) / 260.0, 0.0, .7))
			cols[k] = c
	for iz in TD - 1:
		for ix in TW - 1:
			var i00 = iz * TW + ix
			var i10 = i00 + 1
			var i01 = i00 + TW
			var i11 = i01 + 1
			idx.append_array([i00, i10, i01, i10, i11, i01])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = m_ground
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# colisão: mapa de altura na mesma grade
	var hs = HeightMapShape3D.new()
	hs.map_width = TW
	hs.map_depth = TD
	var data := PackedFloat32Array()
	data.resize(TW * TD)
	for k in TW * TD: data[k] = hmap[k] / TS
	hs.map_data = data
	var cs = CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3.ONE * TS
	cs.position = Vector3(TX0 + (TW - 1) * TS * .5, 0, TZ0 + (TD - 1) * TS * .5)
	solid.add_child(cs)

## cordilheira distante (sem colisão) fechando o horizonte
func _build_far_ring() -> void:
	var c0 = Vector3(0, 0, -60)
	var na = 180
	var nr = 16
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var hh := PackedFloat32Array()
	for j in nr:
		var r = 520.0 + 3300.0 * pow(j / float(nr - 1), 1.5)
		for i in na:
			var a = TAU * i / na
			var x = c0.x + cos(a) * r
			var z = c0.z + sin(a) * r
			var pk = n_mount.get_noise_2d(x * .3, z * .3) * .5 + .5
			var h = smoothstep(520.0, 1100.0, r) * (130.0 + 480.0 * pk * pk) * (1.0 - smoothstep(2600.0, 3820.0, r) * .55)
			verts.append(Vector3(x, h, z))
			hh.append(h)
			cols.append(Color(.2, .21, .24).lerp(Color(.3, .31, .35), pk))
	for j in nr:
		for i in na:
			var k = j * na + i
			var hl = hh[j * na + (i + na - 1) % na]; var hr = hh[j * na + (i + 1) % na]
			var hi = hh[max(j - 1, 0) * na + i]; var ho = hh[min(j + 1, nr - 1) * na + i]
			var a = TAU * i / na
			var radial = Vector3(cos(a), 0, sin(a))
			var tang = Vector3(-sin(a), 0, cos(a))
			norms.append((Vector3.UP * 40.0 + radial * (hi - ho) * .5 + tang * (hl - hr) * .5).normalized())
	for j in nr - 1:
		for i in na:
			var a0 = j * na + i
			var a1 = j * na + (i + 1) % na
			var b0 = a0 + na
			var b1 = a1 + na
			idx.append_array([a0, b0, a1, a1, b0, b1])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	var fm: StandardMaterial3D = m_ground.duplicate()
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = fm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ======================================================================
# ponte gótica sobre o abismo
# ======================================================================
func _build_bridge() -> void:
	var z0 = BR_Z0 + 8.0
	var z1 = BR_Z1 - 8.0
	var L = z0 - z1
	var zc = (z0 + z1) * .5
	_bxc(Vector3(0, -1.5, zc), Vector3(DECK_W, 3.0, L), C_DARK * .72)
	# lajes com juntas
	var z = z1 + 1.5
	while z < z0:
		_bx(Vector3(0, .012, z), Vector3(DECK_W - .5, .03, .14), C_DARK * .5)
		z += 3.0
	for s in [-1, 1]:
		# guarda-corpo com pilaretes
		_bx(Vector3(s * (DECK_W * .5 - .3), .55, zc), Vector3(.6, 1.1, L), C_DARK)
		_bx(Vector3(s * (DECK_W * .5 - .3), 1.16, zc), Vector3(.85, .16, L + .2), C_STONE)
		_cbox(Vector3(s * (DECK_W * .5 - .3), .75, zc), Vector3(.6, 1.5, L))
		var pz = z1 + 2.0
		while pz < z0:
			_bx(Vector3(s * (DECK_W * .5 - .3), .7, pz), Vector3(.8, 1.4, .8), C_LIGHT)
			pz += 5.5
		# cornija e friso por baixo do tabuleiro
		_bx(Vector3(s * (DECK_W * .5 + .25), -.45, zc), Vector3(.7, .9, L), C_LIGHT)
		var mz = z1 + 1.0
		while mz < z0:
			_bx(Vector3(s * (DECK_W * .5 + .35), -1.5, mz), Vector3(.5, 1.2, .5), C_STONE)
			mz += 2.0
	# pilares, pináculos e dois andares de arcos ogivais
	var piers: Array = []
	for k in 9: piers.append(BR_Z0 - 4.0 - k * 22.0)
	for k in piers.size():
		var pz: float = piers[k]
		_bx(Vector3(0, -153.0, pz), Vector3(DECK_W + 3.0, 300.0, 5.0), C_STONE)
		_bx(Vector3(0, -215.0, pz), Vector3(DECK_W + 9.0, 210.0, 9.0), C_DARK)
		_fr(Vector3(0, -110.0, pz), 10.0, (DECK_W + 9.0) * .5, 4.5, (DECK_W + 3.0) * .5, 2.5, C_DARK)
		_bx(Vector3(0, -26.6, pz), Vector3(DECK_W + 4.2, 1.2, 6.2), C_LIGHT)
		_bx(Vector3(0, -100.6, pz), Vector3(DECK_W + 10.2, 1.2, 10.2), C_LIGHT)
		# contrafortes laterais do pilar
		for s in [-1, 1]:
			_bx(Vector3(s * (DECK_W * .5 + 2.2), -60.0, pz), Vector3(1.4, 116.0, 3.0), C_STONE)
			_fr(Vector3(s * (DECK_W * .5 + 2.2), -2.0, pz), 2.0, .7, 1.5, .2, .4, C_STONE)
			# pináculo acima do tabuleiro
			var px = s * (DECK_W * .5 + 1.0)
			_bxc(Vector3(px, 8.0, pz), Vector3(2.2, 16.0, 2.2), C_STONE)
			_bx(Vector3(px, 16.2, pz), Vector3(2.7, .5, 2.7), C_LIGHT)
			_bx(Vector3(px, 5.0, pz), Vector3(2.5, .35, 2.5), C_LIGHT)
			_fr(Vector3(px, 16.45, pz), 12.0, 1.25, 1.25, 0.0, 0.0, C_STONE)
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					_fr(Vector3(px + cx * 1.0, 16.45, pz + cz * 1.0), 3.6, .32, .32, 0.0, 0.0, C_LIGHT)
			# nicho escuro (janela cega) no pináculo
			_bx(Vector3(px, 10.5, pz + 1.12), Vector3(.9, 3.5, .06), C_WIN)
			_bx(Vector3(px, 10.5, pz - 1.12), Vector3(.9, 3.5, .06), C_WIN)
	for k in piers.size() - 1:
		var za: float = (piers[k] + piers[k + 1]) * .5
		var span = absf(piers[k] - piers[k + 1]) - 5.0
		# arcos de cima
		_spandrel(Vector3(0, -26.0, za), span, 20.0, -3.0, DECK_W + 2.0, PI / 2, C_STONE)
		_arch(Vector3(0, -26.0, za), span, 20.0, 1.4, DECK_W + 2.7, PI / 2, C_LIGHT)
		# arcos de baixo, maiores
		var span2 = absf(piers[k] - piers[k + 1]) - 9.0
		_spandrel(Vector3(0, -100.0, za), span2, 44.0, -27.0, DECK_W + 2.0, PI / 2, C_DARK)
		_arch(Vector3(0, -100.0, za), span2, 44.0, 2.0, DECK_W + 2.8, PI / 2, C_STONE)
		# rosácea cega no tímpano de cima
		_put("st", "torus", Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis.from_scale(Vector3(2.2, 4.0, 2.2)), Vector3(DECK_W * .5 + 1.02, -9.5, za)), C_LIGHT)
		_put("st", "torus", Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis.from_scale(Vector3(2.2, 4.0, 2.2)), Vector3(-DECK_W * .5 - 1.02, -9.5, za)), C_LIGHT)

## portões com torres nas duas cabeceiras
func _build_gates() -> void:
	for gz in [BR_Z0 + 12.0, BR_Z1 - 12.0]:
		var gy = 0.0
		for s in [-1, 1]:
			var x = s * 9.5
			_bxc(Vector3(x, gy + 15.0, gz), Vector3(6.0, 30.0, 6.0), C_STONE)
			_bx(Vector3(x, gy + .8, gz), Vector3(7.0, 1.6, 7.0), C_DARK)
			_bx(Vector3(x, gy + 30.3, gz), Vector3(7.2, .8, 7.2), C_LIGHT)
			_bx(Vector3(x, gy + 21.0, gz), Vector3(6.6, .5, 6.6), C_LIGHT)
			_fr(Vector3(x, gy + 30.7, gz), 20.0, 3.0, 3.0, 0.0, 0.0, C_STONE)
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					_bx(Vector3(x + cx * 3.0, gy + 15.0, gz + cz * 3.0), Vector3(1.0, 30.0, 1.0), C_LIGHT)
					_fr(Vector3(x + cx * 3.0, gy + 30.7, gz + cz * 3.0), 6.0, .6, .6, 0.0, 0.0, C_LIGHT)
			# frestas escuras
			for fz in [-1, 1]:
				_bx(Vector3(x, gy + 24.5, gz + fz * 3.02), Vector3(1.4, 5.0, .06), C_WIN)
				_bx(Vector3(x, gy + 12.0, gz + fz * 3.02), Vector3(.7, 3.0, .06), C_WIN)
		# arco sobre a passagem
		_spandrel(Vector3(0, gy + 14.0, gz), 13.0, 10.0, gy + 28.0, 3.6, 0.0, C_STONE, .8)
		_cbox(Vector3(0, gy + 25.5, gz), Vector3(13.0, 5.0, 3.6))
		_arch(Vector3(0, gy + 14.0, gz), 13.0, 10.0, 1.0, 4.2, 0.0, C_LIGHT)
		_arch(Vector3(0, gy + 14.4, gz), 11.6, 9.0, .6, 4.5, 0.0, C_STONE)
		_bx(Vector3(0, gy + 28.4, gz), Vector3(13.2, .8, 4.2), C_LIGHT)
		for k in 5:
			_bx(Vector3(-5.2 + k * 2.6, gy + 29.6, gz), Vector3(1.2, 1.6, 3.6), C_STONE)
		_bx(Vector3(0, gy + 22.5, gz + 1.85), Vector3(2.2, 3.4, .06), C_WIN)
		_bx(Vector3(0, gy + 22.5, gz - 1.85), Vector3(2.2, 3.4, .06), C_WIN)

## colunata de pináculos e arcos ladeando o caminho até a ponte (como a da imagem)
func _build_colonnade() -> void:
	for s in [-1, 1]:
		var x = s * 12.0
		var zs: Array = []
		for k in 11: zs.append(BR_Z0 + 22.0 + k * 9.0)
		for z in zs:
			var y0 = ground(x, z) - .3
			_bxc(Vector3(x, y0 + 7.0, z), Vector3(1.6, 14.0, 1.6), C_STONE)
			_bx(Vector3(x, y0 + .6, z), Vector3(2.2, 1.2, 2.2), C_DARK)
			_bx(Vector3(x, y0 + 14.1, z), Vector3(2.0, .4, 2.0), C_LIGHT)
			_fr(Vector3(x, y0 + 14.3, z), 7.0 + rng.randf_range(-1, 2), .8, .8, 0.0, 0.0, C_STONE)
			for cz in [-1, 1]:
				_fr(Vector3(x + .7, y0 + 14.3, z + cz * .7), 2.2, .2, .2, 0.0, 0.0, C_LIGHT)
				_fr(Vector3(x - .7, y0 + 14.3, z + cz * .7), 2.2, .2, .2, 0.0, 0.0, C_LIGHT)
		for k in zs.size() - 1:
			if k == 6 and s == 1: continue # um arco caiu
			var za = (zs[k] + zs[k + 1]) * .5
			var y0 = ground(x, za) - .3
			_spandrel(Vector3(x, y0 + 8.0, za), 7.4, 4.8, y0 + 13.6, .9, PI / 2, C_STONE, .6)
			_arch(Vector3(x, y0 + 8.0, za), 7.4, 4.8, .55, 1.15, PI / 2, C_LIGHT, "st", 10)
			_bx(Vector3(x, y0 + 13.8, za), Vector3(1.2, .4, 9.0), C_LIGHT)
		# o arco caído, em pedaços no chão
		if s == 1:
			var zf = (zs[6] + zs[7]) * .5
			for j in 5:
				var p = Vector3(x + rng.randf_range(-3, 1), 0, zf + rng.randf_range(-4, 4))
				p.y = ground(p.x, p.z) + .4
				_rock(p, Vector3(rng.randf_range(1, 2.2), rng.randf_range(.7, 1.3), rng.randf_range(1, 2)), C_STONE)

# ======================================================================
# vale: cemitério, mausoléu e capela em ruínas
# ======================================================================
func _build_cemetery() -> void:
	for side in [-1, 1]:
		for row in 7:
			for col in 6:
				if rng.randf() < .22: continue
				var x = side * (22.0 + col * 6.5 + rng.randf_range(-1.2, 1.2))
				var z = 258.0 + row * 9.0 + rng.randf_range(-1.5, 1.5)
				if abs(x - _path_x(z)) < 9.0: continue
				_tomb(x, z)
	# mausoléu
	var mp = Vector3(-46, 0, 300)
	mp.y = ground(mp.x, mp.z) - .3
	_bxc(mp + Vector3(0, 4.0, 0), Vector3(8.0, 8.0, 10.0), C_STONE)
	_bx(mp + Vector3(0, .5, 0), Vector3(9.0, 1.0, 11.0), C_DARK)
	_bx(mp + Vector3(0, 8.2, 0), Vector3(8.8, .5, 10.8), C_LIGHT)
	_put("st", "prism", Transform3D(Basis.from_scale(Vector3(8.6, 4.0, 10.6)), mp + Vector3(0, 10.45, 0)), C_DARK)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_bx(mp + Vector3(cx * 4.1, 4.5, cz * 5.1), Vector3(.9, 9.0, .9), C_LIGHT)
			_fr(mp + Vector3(cx * 4.1, 9.0, cz * 5.1), 4.0, .45, .45, 0, 0, C_LIGHT)
	_bx(mp + Vector3(4.03, 3.2, 0), Vector3(.1, 5.0, 2.6), C_WIN)
	_arch(mp + Vector3(4.1, 5.7, 0), 2.8, 2.0, .35, .5, PI / 2, C_LIGHT, "st", 8)
	_fr(mp + Vector3(0, 12.4, 0), 3.0, .3, .3, .15, .15, C_LIGHT)
	_bx(mp + Vector3(0, 14.4, 0), Vector3(.25, 2.6, .25), C_LIGHT)
	_bx(mp + Vector3(0, 14.9, 0), Vector3(1.4, .25, .25), C_LIGHT)

func _tomb(x: float, z: float) -> void:
	var y = ground(x, z)
	var tilt = Vector3(rng.randf_range(-.14, .14), rng.randf_range(-.3, .3), rng.randf_range(-.12, .12))
	var tint = C_STONE * rng.randf_range(.7, 1.08)
	tint.a = 1.0
	match rng.randi() % 5:
		0, 1:
			_bx(Vector3(x, y + .55, z), Vector3(.95, 1.3, .24), tint, tilt)
			_put("st", "cyl", Transform3D(Basis.from_euler(tilt) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(.95, .24, .95)), Vector3(x, y + 1.2, z)), tint)
			_cbox(Vector3(x, y + .7, z), Vector3(.95, 1.4, .3))
		2:
			_bx(Vector3(x, y + 1.2, z), Vector3(.26, 2.6, .26), tint, tilt)
			_bx(Vector3(x, y + 1.85, z), Vector3(1.3, .26, .26), tint, tilt)
			_bx(Vector3(x, y + .2, z), Vector3(.8, .4, .6), C_DARK)
			_cbox(Vector3(x, y + 1.3, z), Vector3(.3, 2.6, .3))
		3:
			_bx(Vector3(x, y + .25, z), Vector3(1.0, .5, 1.0), C_DARK)
			_fr(Vector3(x, y + .5, z), 3.2, .34, .34, .2, .2, tint)
			_fr(Vector3(x, y + 3.7, z), .6, .2, .2, 0, 0, tint)
			_cbox(Vector3(x, y + 1.8, z), Vector3(.7, 3.6, .7))
		4:
			# lápide quebrada e uma laje caída
			_bx(Vector3(x, y + .3, z), Vector3(.9, .7, .22), tint, tilt * 2.0)
			_bx(Vector3(x, y + .08, z + .9), Vector3(.9, .16, 1.9), C_DARK, Vector3(0, tilt.y, 0))
			_cbox(Vector3(x, y + .35, z), Vector3(.9, .7, .3))

func _build_chapel() -> void:
	var c = Vector3(48, 0, 205)
	c.y = ground(c.x, c.z) - .4
	var hx = 9.0
	var z0 = c.z - 16.0
	var z1 = c.z + 14.0
	_bx(Vector3(c.x, c.y + .2, c.z - 1.0), Vector3(hx * 2 + 2.0, .6, z1 - z0 + 2.0), C_DARK)
	# paredes compridas: vãos de janela ogival entre pilares (algumas partes caídas)
	for s in [-1, 1]:
		var x = c.x + s * hx
		var nb = 5
		var bay = (z1 - z0) / nb
		for b in nb + 1:
			var z = z0 + b * bay
			var hp = rng.randf_range(9.0, 16.0)
			if s == 1 and b >= 3: hp = rng.randf_range(3.0, 6.0)
			_bxc(Vector3(x, c.y + hp * .5, z), Vector3(1.6, hp, 1.6), C_STONE)
			_fr(Vector3(x + s * .8, c.y, z), min(hp * .55, 7.0), .9, .9, .25, .7, C_DARK)
		for b in nb:
			var z = z0 + (b + .5) * bay
			var broken = s == 1 and b >= 2
			var hw_ = 3.4 if not broken else rng.randf_range(1.0, 2.5)
			_bxc(Vector3(x, c.y + hw_ * .5, z), Vector3(1.1, hw_, bay - 1.6), C_STONE)
			if not broken:
				_arch(Vector3(x, c.y + 7.5, z), bay - 1.6, 3.2, .45, 1.2, PI / 2, C_LIGHT, "st", 10)
				_spandrel(Vector3(x, c.y + 7.5, z), bay - 1.6, 3.2, c.y + 12.0, 1.0, PI / 2, C_STONE, .6)
				_bx(Vector3(x, c.y + 5.4, z), Vector3(.3, 4.0, .3), C_LIGHT)
				_cbox(Vector3(x, c.y + 10.5, z), Vector3(1.0, 3.0, bay - 1.6))
	# fachada com portal e empena quebrada
	for s in [-1, 1]:
		var hgt = 17.0 if s == -1 else 11.0
		_bxc(Vector3(c.x + s * (hx * .5 + 1.1), c.y + hgt * .5, z1), Vector3(hx - 2.0, hgt, 1.4), C_STONE)
	_spandrel(Vector3(c.x, c.y + 6.5, z1), 4.4, 3.4, c.y + 13.0, 1.4, 0.0, C_STONE, .5)
	_arch(Vector3(c.x, c.y + 6.5, z1), 4.4, 3.4, .5, 1.8, 0.0, C_LIGHT, "st", 10)
	_put("st", "torus", Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(2.2, 2.0, 2.2)), Vector3(c.x - 2.5, c.y + 14.5, z1 + .75)), C_LIGHT)
	# abside nos fundos (meio em pé)
	for k in 7:
		var a = PI + k * PI / 6.0
		var p = Vector3(c.x + cos(a) * hx, c.y, z0 + sin(a) * 7.0 * -1.0)
		var hp = 4.0 + 9.0 * abs(sin(k * 1.7))
		_bxc(p + Vector3(0, hp * .5, 0), Vector3(2.2, hp, 2.2), C_STONE, Vector3(0, -a, 0))
	# colunas internas, uma caída
	for k in 3:
		var p = Vector3(c.x - 3.0 + k * 3.0, c.y, c.z - 4.0 + k * 5.0)
		var hc = [7.0, 2.5, 5.0][k]
		_seg(p, p + Vector3(0, hc, 0), .6, .55, 10, C_LIGHT, "st", true)
		_cbox(p + Vector3(0, hc * .5, 0), Vector3(1.1, hc, 1.1))
	var fp = Vector3(c.x + 2.5, c.y + .6, c.z + 2.0)
	_seg(fp, fp + Vector3(5.5, 0, 3.0).normalized() * 6.5, .6, .6, 10, C_LIGHT, "st", true)
	# telhado: só sobraram duas vigas de pedra
	for k in 2:
		var z = c.z - 6.0 + k * 9.0
		_bx(Vector3(c.x, c.y + 14.0, z), Vector3(hx * 2 + 1.0, .9, .9), C_DARK, Vector3(0, 0, .12 if k == 0 else -.2))

# ======================================================================
# planalto da torre
# ======================================================================
func _build_plateau() -> void:
	# avenida de obeliscos até a escadaria
	var z = BR_Z1 - 28.0
	while z > -262.0:
		for s in [-1, 1]:
			var x = s * 15.0
			var y = ground(x, z) - .2
			_bxc(Vector3(x, y + .7, z), Vector3(2.6, 1.4, 2.6), C_DARK)
			_fr(Vector3(x, y + 1.4, z), 12.0, .95, .95, .55, .55, C_STONE)
			_fr(Vector3(x, y + 13.4, z), 1.8, .55, .55, 0, 0, C_LIGHT)
			_cbox(Vector3(x, y + 7.4, z), Vector3(1.6, 12.0, 1.6))
		z -= 20.0
	# anel de pedras em pé em volta da praça
	for k in 14:
		var a = TAU * k / 14.0 + .1
		var p = TOWER + Vector3(cos(a), 0, sin(a)) * 122.0
		if p.z > TOWER.z + 90.0 and abs(p.x) < 34.0: continue
		var hgt = rng.randf_range(9.0, 19.0)
		p.y = ground(p.x, p.z) - .5
		_bxc(p + Vector3(0, hgt * .5, 0), Vector3(3.0, hgt, 1.6), C_STONE, Vector3(rng.randf_range(-.06, .06), -a, rng.randf_range(-.08, .08)))
		if k % 3 == 0:
			_rock(p + Vector3(cos(a + 1.0) * 4.0, .8, sin(a + 1.0) * 4.0), Vector3(3.5, 1.6, 2.2), C_STONE)

func _tier_w(i: int) -> float:
	return lerp(104.0, 26.0, pow(clamp(i / float(TIERS - 1), 0.0, 1.0), .75))

func _build_tower() -> void:
	var T = TOWER
	# embasamento em degraus
	for k in 3:
		var w = 150.0 - k * 9.0
		_bxc(T + Vector3(0, k * 1.0 + .5, 0), Vector3(w, 1.0, w), C_DARK if k == 0 else C_STONE)
		_bx(T + Vector3(0, k * 1.0 + 1.0, 0), Vector3(w + .4, .1, w + .4), C_LIGHT)
	# escadaria da frente (rampa invisível por baixo)
	var top_edge = T.z + 66.0
	var run = 10.4
	for k in 6:
		var zb = top_edge + run - k * run / 6.0
		var hk = (k + 1) * .5
		_bx(Vector3(0, hk * .5, (top_edge + zb) * .5), Vector3(40.0, hk, zb - top_edge), C_STONE if k % 2 == 0 else C_DARK)
	var ang = atan2(PLINTH, run)
	_cbox(Vector3(0, PLINTH * .5 - .15 * cos(ang), top_edge + run * .5), Vector3(40.0, .3, sqrt(run * run + PLINTH * PLINTH)), Vector3(ang, 0, 0))
	for s in [-1, 1]:
		_bxc(Vector3(s * 21.5, 2.4, top_edge + run * .5), Vector3(3.0, 4.8, run + 1.0), C_STONE)
		_fr(Vector3(s * 21.5, 4.8, top_edge + run), 9.0, 1.2, 1.2, 0, 0, C_LIGHT)
	# andares
	for i in TIERS:
		var key = "top" if i >= TIERS - 3 else "st"
		var w = _tier_w(i)
		var wn = _tier_w(i + 1) if i < TIERS - 1 else w * .62
		var y0 = PLINTH + i * TIER_H
		var hw_ = w * .5
		_bx(T + Vector3(0, y0 + TIER_H * .5, 0), Vector3(w, TIER_H, w), C_STONE, Vector3.ZERO, key)
		if i == 0: _cbox(T + Vector3(0, y0 + TIER_H * .5, 0), Vector3(w, TIER_H, w))
		# cornija e talude até o próximo andar
		_bx(T + Vector3(0, y0 + TIER_H - .9, 0), Vector3(w + 3.0, 1.8, w + 3.0), C_LIGHT, Vector3.ZERO, key)
		_fr(T + Vector3(0, y0 + TIER_H, 0), 3.0, hw_ + 1.5, hw_ + 1.5, wn * .5, wn * .5, C_DARK, key)
		_bx(T + Vector3(0, y0 + 1.0, 0), Vector3(w + 1.4, 2.0, w + 1.4), C_DARK, Vector3.ZERO, key)
		# pilares de canto e pináculos
		var pin_h = max(4.0, 17.0 - i * .6)
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				var cp_ = T + Vector3(cx * (hw_ + .6), y0, cz * (hw_ + .6))
				_bx(cp_ + Vector3(0, TIER_H * .5, 0), Vector3(3.6, TIER_H, 3.6), C_STONE, Vector3.ZERO, key)
				_fr(cp_ + Vector3(0, TIER_H, 0), pin_h, 1.8, 1.8, 0, 0, C_STONE, key)
				for mx in [-1, 1]:
					_fr(cp_ + Vector3(mx * 1.5, TIER_H, 1.5 * mx * -cx * cz), pin_h * .32, .45, .45, 0, 0, C_LIGHT, key)
		# nervuras verticais e janelas ogivais em cada face
		var nr = 6 if w > 52.0 else (4 if w > 32.0 else 2)
		var bay = w / (nr + 1)
		for f in 4:
			var ry = f * PI / 2.0
			var rb = Basis(Vector3.UP, ry)
			for r in nr:
				var lx = -hw_ + bay * (r + 1)
				_put(key, "box", Transform3D(rb * Basis.from_scale(Vector3(1.1, TIER_H - 2.0, 1.2)), T + rb * Vector3(lx, 0, hw_ + .45) + Vector3(0, y0 + TIER_H * .5, 0)), C_LIGHT)
			for r in nr + 1:
				var lx = -hw_ + bay * (r + .5)
				var ww = bay * .42
				var wh = TIER_H * .5
				var wy = y0 + TIER_H * .42
				# vidro escuro, moldura e arco
				_put(key, "box", Transform3D(rb * Basis.from_scale(Vector3(ww, wh, .3)), T + rb * Vector3(lx, 0, hw_ + .1) + Vector3(0, wy, 0)), C_WIN)
				_put(key, "prism", Transform3D(rb * Basis.from_scale(Vector3(ww, ww * .85, .3)), T + rb * Vector3(lx, 0, hw_ + .1) + Vector3(0, wy + wh * .5 + ww * .42, 0)), C_WIN)
				_put(key, "box", Transform3D(rb * Basis.from_scale(Vector3(ww + .8, .5, .6)), T + rb * Vector3(lx, 0, hw_ + .25) + Vector3(0, wy - wh * .5 - .2, 0)), C_LIGHT)
				if w > 30.0:
					_put(key, "box", Transform3D(rb * Basis.from_scale(Vector3(.25, wh, .5)), T + rb * Vector3(lx, 0, hw_ + .2) + Vector3(0, wy, 0)), C_STONE)
	# portal: pórtico saliente com arquivoltas e porta escura
	var fz = T.z + _tier_w(0) * .5
	var pc = Vector3(0, PLINTH, fz)
	_bxc(pc + Vector3(-20.0, 29.0, 4.0), Vector3(8.0, 58.0, 8.0), C_STONE)
	_bxc(pc + Vector3(20.0, 29.0, 4.0), Vector3(8.0, 58.0, 8.0), C_STONE)
	for s in [-1, 1]:
		_fr(pc + Vector3(s * 20.0, 58.0, 4.0), 34.0, 4.0, 4.0, 0, 0, C_STONE)
		for cz in [-1, 1]:
			_fr(pc + Vector3(s * 20.0 + 3.6, 58.0, 4.0 + cz * 3.6), 10.0, .8, .8, 0, 0, C_LIGHT)
			_fr(pc + Vector3(s * 20.0 - 3.6, 58.0, 4.0 + cz * 3.6), 10.0, .8, .8, 0, 0, C_LIGHT)
		for k in 3:
			_seg(pc + Vector3(s * (14.0 - k * 1.4), 0, 2.6 + k * 1.2), pc + Vector3(s * (14.0 - k * 1.4), 31.0, 2.6 + k * 1.2), .65, .65, 8, C_LIGHT)
	_spandrel(pc + Vector3(0, 31.0, 6.0), 32.0, 20.0, PLINTH + 60.0, 4.0, 0.0, C_STONE, 1.0)
	for k in 4:
		_arch(pc + Vector3(0, 31.0, 8.0 - k * 1.4), 32.0 - k * 2.8, 20.0 - k * 1.8, 1.2, 1.5, 0.0, C_LIGHT if k % 2 == 0 else C_STONE)
	_bx(pc + Vector3(0, 17.0, .35), Vector3(24.0, 34.0, .4), C_WIN)
	_spandrel(pc + Vector3(0, 31.0, .35), 24.0, 15.0, PLINTH + 31.0 + 15.0, .4, 0.0, C_WIN, .8)
	for k in 9:
		_bx(pc + Vector3(-10.0 + k * 2.5, 17.0, .7), Vector3(.4, 34.0, .4), C_DARK * .7)
	_bx(pc + Vector3(0, 17.0, .7), Vector3(1.0, 34.0, .5), C_DARK)
	# empena e rosácea acima do portal
	_put("st", "prism", Transform3D(Basis.from_scale(Vector3(48.0, 18.0, 8.0)), pc + Vector3(0, 69.0, 4.0)), C_STONE)
	_put("st", "torus", Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(9.0, 6.0, 9.0)), pc + Vector3(0, 47.0, .7)), C_LIGHT)
	_put("st", "cyl", Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(16.0, .4, 16.0)), pc + Vector3(0, 47.0, .45)), C_WIN)
	for k in 12:
		var a = TAU * k / 12.0
		_put("st", "box", Transform3D(Basis(Vector3.FORWARD, a) * Basis.from_scale(Vector3(.45, 7.8, .6)), pc + Vector3(cos(a + PI / 2) * 3.9, 47.0 + sin(a + PI / 2) * 3.9, .8)), C_LIGHT)
	# arcobotantes nos quatro cantos
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var bp = T + Vector3(cx * 84.0, 0, cz * 84.0)
			_bxc(bp + Vector3(0, 32.0, 0), Vector3(7.0, 64.0, 7.0), C_STONE)
			_bx(bp + Vector3(0, 64.4, 0), Vector3(8.0, .8, 8.0), C_LIGHT)
			_fr(bp + Vector3(0, 64.8, 0), 22.0, 3.5, 3.5, 0, 0, C_STONE)
			for mx in [-1, 1]:
				for mz in [-1, 1]:
					_fr(bp + Vector3(mx * 3.3, 64.8, mz * 3.3), 7.0, .7, .7, 0, 0, C_LIGHT)
			# cruzes de ferro no alto das agulhas dos cantos
			_bx(bp + Vector3(0, 88.5, 0), Vector3(.5, 5.0, .5), C_DARK)
			_bx(bp + Vector3(0, 89.5, 0), Vector3(2.6, .5, .5), C_DARK)
	# coroa de pináculos nas cornijas dos primeiros andares
	for i in 4:
		var w = _tier_w(i)
		var hw_ = w * .5 + 1.0
		var y = PLINTH + (i + 1) * TIER_H
		var n = int(w / 9.0)
		for f in 4:
			var rb = Basis(Vector3.UP, f * PI / 2.0)
			for k in n:
				var lx = -hw_ + (k + .5) * (2.0 * hw_ / n)
				var hgt = 7.0 + 5.0 * float((k + i) % 2)
				_fr(T + rb * Vector3(lx, 0, hw_) + Vector3(0, y, 0), hgt, .6, .6, 0, 0, C_LIGHT)
				_bx(T + rb * Vector3(lx, 0, hw_) + Vector3(0, y + 1.2, 0), Vector3(1.5, 2.4, 1.5), C_STONE)
	# coroa no topo: agulhas em volta e a flecha central entrando no vórtice
	var ty = TOP_Y + 3.0
	var tw = _tier_w(TIERS - 1) * .62
	_bx(T + Vector3(0, ty - 1.0, 0), Vector3(tw + 4.0, 2.0, tw + 4.0), C_LIGHT, Vector3.ZERO, "top")
	_fr(T + Vector3(0, ty, 0), 80.0, tw * .5, tw * .5, 0, 0, C_STONE, "top")
	for k in 8:
		var a = TAU * k / 8.0 + PI / 8.0
		var p = T + Vector3(cos(a) * (tw * .5 + 1.5), ty, sin(a) * (tw * .5 + 1.5))
		_fr(p, 28.0 + (k % 2) * 10.0, 1.2, 1.2, 0, 0, C_STONE, "top", a)
		_seg(p + Vector3(0, 6.0, 0), p + Vector3(cos(a), 0, sin(a)) * 9.0 + Vector3(0, 14.0, 0), .5, 0.0, 5, C_LIGHT, "top")

## estátuas de anjo escurecidas guardando o portal
func _build_statues() -> void:
	if not ResourceLoader.exists("res://estatua/anjo_estatua.glb"): return
	for s in [-1, 1]:
		var st: Node3D = load("res://estatua/anjo_estatua.glb").instantiate()
		var m = m_stone.duplicate()
		m.vertex_color_use_as_albedo = false
		m.albedo_color = Color(.62, .63, .7)
		var lo = INF
		var hi = -INF
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count(): mi.set_surface_override_material(si, m)
			# transformação do pedaço relativa à raiz do modelo
			var xf = Transform3D.IDENTITY
			var nd: Node = mi
			while nd and nd != st:
				if nd is Node3D: xf = (nd as Node3D).transform * xf
				nd = nd.get_parent()
			var bb: AABB = xf * mi.get_aabb()
			lo = min(lo, bb.position.y)
			hi = max(hi, bb.end.y)
		var sc = 17.0 / max(hi - lo, .01)
		print("estatua altura modelo=", hi - lo, " escala=", sc)
		st.scale = Vector3.ONE * sc
		st.position = TOWER + Vector3(s * 34.0, PLINTH + 4.0 - lo * sc, _tier_w(0) * .5 + 9.0)
		st.rotation.y = s * -.35
		add_child(st)
		_bxc(TOWER + Vector3(s * 34.0, PLINTH + 2.0, _tier_w(0) * .5 + 9.0), Vector3(7.0, 4.0, 7.0), C_DARK)
		_commit("st", m_stone)

# ======================================================================
# árvores secas, pedras e paredes invisíveis
# ======================================================================
func _ok_spot(x: float, z: float, path_clear := 9.0) -> bool:
	if z < BR_Z0 + 6.0 and z > BR_Z1 - 6.0: return false
	if abs(x) > _hw(z) - 4.0: return false
	if abs(x - _path_x(z)) < path_clear: return false
	if z < BR_Z1 and abs(x) < 20.0: return false
	if Vector2(x - TOWER.x, z - TOWER.z).length() < 132.0: return false
	if Vector2(x - 48.0, z - 205.0).length() < 22.0: return false
	if Vector2(x + 46.0, z - 300.0).length() < 10.0: return false
	if abs(x) < 16.0 and z > BR_Z0 and z < BR_Z0 + 120.0: return false
	return true

func _build_trees() -> void:
	var n = 0
	var tries = 0
	while n < 46 and tries < 600:
		tries += 1
		var z = rng.randf_range(-480.0, 380.0)
		var x = rng.randf_range(-_hw(z), _hw(z))
		if not _ok_spot(x, z, 11.0): continue
		var y = ground(x, z)
		var h = rng.randf_range(7.0, 15.0)
		var r = h * rng.randf_range(.045, .06)
		_branch(Vector3(x, y - .5, z), Vector3(rng.randf_range(-.2, .2), 1.0, rng.randf_range(-.2, .2)).normalized(), h, r, 0)
		_cbox(Vector3(x, y + 2.0, z), Vector3(r * 2.2, 4.0, r * 2.2))
		n += 1
	# árvores retorcidas na beira do abismo e no pé da torre
	for p in [Vector3(-30, 0, 108), Vector3(26, 0, 112), Vector3(-34, 0, -90), Vector3(38, 0, -96), Vector3(-80, 0, -300), Vector3(78, 0, -350), Vector3(-70, 0, -390)]:
		var y = ground(p.x, p.z)
		_branch(Vector3(p.x, y - .5, p.z), Vector3(0, 1, 0), 13.0, .8, 0)
		_cbox(Vector3(p.x, y + 2.0, p.z), Vector3(1.6, 4.0, 1.6))

func _branch(p: Vector3, d: Vector3, L: float, r: float, depth: int) -> void:
	var segs = 4 if depth == 0 else 3
	var cur = p
	var dir = d
	var rc = r
	for s in segs:
		var sl = L / segs
		dir = (dir + Vector3(rng.randf_range(-.4, .4), rng.randf_range(-.08, .12), rng.randf_range(-.4, .4)) * (.5 if depth == 0 else 1.0)).normalized()
		var nxt = cur + dir * sl
		var r1 = r * (1.0 - (s + 1.0) / segs * .6)
		_seg(cur, nxt, rc, r1, 6 if depth < 2 else 4, C_BARK * rng.randf_range(.85, 1.1), "bark")
		if depth < 3 and s >= (1 if depth == 0 else 0) and rng.randf() < .75:
			var side = Vector3(rng.randf_range(-1, 1), rng.randf_range(.2, .9), rng.randf_range(-1, 1)).normalized()
			_branch(nxt, (side + dir * .3).normalized(), L * rng.randf_range(.38, .55), r1 * .62, depth + 1)
		cur = nxt
		rc = r1
	if depth < 3:
		for k in 2:
			var side = Vector3(rng.randf_range(-1, 1), rng.randf_range(.1, .8), rng.randf_range(-1, 1)).normalized()
			_branch(cur, (side + dir).normalized(), L * .42, rc * .7, depth + 1)

func _build_rocks() -> void:
	var n = 0
	var tries = 0
	while n < 70 and tries < 900:
		tries += 1
		var z = rng.randf_range(-500.0, 390.0)
		var x = rng.randf_range(-_hw(z) - 10.0, _hw(z) + 10.0)
		if not _ok_spot(x, z, 7.0) and abs(x) < _hw(z) - 4.0: continue
		if z < BR_Z0 + 6.0 and z > BR_Z1 - 6.0: continue
		var s = rng.randf_range(1.0, 4.5) * (1.8 if abs(x) > _hw(z) - 8.0 else 1.0)
		var y = ground(x, z)
		_rock(Vector3(x, y + s * .25, z), Vector3(s * rng.randf_range(1.0, 1.6), s * rng.randf_range(.6, 1.1), s * rng.randf_range(1.0, 1.5)), C_STONE * rng.randf_range(.75, 1.0), "st", Vector3(0, rng.randf() * TAU, 0))
		if s > 1.8: _cbox(Vector3(x, y + s * .35, z), Vector3(s * 1.2, s * .8, s * 1.1))
		n += 1
	# rochedos saindo das paredes do abismo
	for edge in [BR_Z0, BR_Z1]:
		for k in 70:
			var x = rng.randf_range(-300.0, 300.0)
			if abs(x) < 12.0: continue
			var y = rng.randf_range(-170.0, -6.0)
			var z = edge + (rng.randf_range(-6.0, 2.0) if edge == BR_Z0 else rng.randf_range(-2.0, 6.0))
			var sz = rng.randf_range(6.0, 22.0)
			_rock(Vector3(x, y, z), Vector3(sz * rng.randf_range(1.0, 2.2), sz * rng.randf_range(.6, 1.4), sz * rng.randf_range(.5, .9)), C_DARK * rng.randf_range(.8, 1.1), "st", Vector3(0, rng.randf_range(-.4, .4), rng.randf_range(-.5, .5)))
	# lascas pontudas na borda do abismo
	for edge in [BR_Z0, BR_Z1]:
		for k in 26:
			var x = rng.randf_range(-70.0, 70.0)
			if abs(x) < 16.0: continue
			var z = edge + (3.0 if edge == BR_Z0 else -3.0) + rng.randf_range(-2, 2)
			var y = ground(x, z)
			var hgt = rng.randf_range(2.0, 9.0)
			_fr(Vector3(x, y - 1.0, z), hgt, rng.randf_range(.8, 1.8), rng.randf_range(.8, 1.6), 0, 0, C_DARK, "st", rng.randf() * TAU)

func _build_walls() -> void:
	var z = -540.0
	while z < 440.0:
		for s in [-1, 1]:
			var x = s * (_hw(z + 10.0) + 32.0)
			_cbox(Vector3(x, 100.0, z + 10.0), Vector3(6.0, 300.0, 22.0))
		z += 20.0
	_cbox(Vector3(0, 100, 432.0), Vector3(500.0, 300.0, 6.0))
	_cbox(Vector3(0, 100, -548.0), Vector3(500.0, 300.0, 6.0))

# ======================================================================
# céu: vórtice negro, luz no topo, destroços girando, corvos, névoa e cinzas
# ======================================================================
const VORTEX_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform float flash = 0.0;
uniform float flash_a = 0.0;
varying vec2 p;
void vertex() { p = VERTEX.xz; }
// amostra com derivadas analíticas: sem costura no ângulo e sem serrilhado de longe
float samp(sampler2D tx, vec2 uv, vec2 dx, vec2 dy) { return textureGrad(tx, uv, dx, dy).r; }
void fragment() {
	float r = max(length(p), 8.0);
	float a = atan(p.y, p.x);
	float lr = log(r);
	float tm = TIME;
	vec2 px = dFdx(p);
	vec2 py = dFdy(p);
	float r2 = r * r;
	float dax = (p.x * px.y - p.y * px.x) / r2;
	float day = (p.x * py.y - p.y * py.x) / r2;
	float dlx = (p.x * px.x + p.y * px.y) / r2;
	float dly = (p.x * py.x + p.y * py.y) / r2;
	// espiral: gira mais rápido perto do olho e puxa as nuvens para dentro
	vec2 uv = vec2(a / 6.2831853 + lr * 0.45 + tm * (0.004 + 0.05 * exp(-r / 350.0)), lr * 0.55 - tm * 0.02);
	vec2 dux = vec2(dax / 6.2831853 + dlx * 0.45, dlx * 0.55);
	vec2 duy = vec2(day / 6.2831853 + dly * 0.45, dly * 0.55);
	vec2 s1 = vec2(3.0, 1.0);
	vec2 s2 = vec2(6.0, 1.3);
	float n1 = samp(noise_a, uv * s1, dux * s1, duy * s1);
	float n2 = samp(noise_b, uv * s2 + vec2(tm * 0.004, 0.0), dux * s2, duy * s2);
	float n3 = samp(noise_b, p * 0.00035 + vec2(tm * 0.002, 0.0), px * 0.00035, py * 0.00035);
	float dens = smoothstep(0.22, 0.85, n1 * 0.6 + n2 * 0.3 + n3 * 0.25);
	float lit = exp(-r / 230.0);
	float lit2 = exp(-r / 1300.0);
	vec3 dark = vec3(0.03, 0.034, 0.046) + vec3(0.05, 0.056, 0.075) * lit2;
	vec3 cloud = vec3(0.13, 0.145, 0.19) * (0.55 + 1.7 * lit2) + vec3(0.85, 0.9, 1.0) * lit * 2.2;
	// bordas das nuvens pegam a luz do olho
	cloud += vec3(0.25, 0.28, 0.36) * lit2 * smoothstep(0.35, 0.6, dens) * (1.0 - smoothstep(0.6, 0.95, dens));
	vec3 col = mix(dark + vec3(0.6, 0.65, 0.75) * lit * 0.9, cloud, dens);
	// o olho do vórtice: a única luz do mundo
	col += vec3(1.25, 1.3, 1.4) * smoothstep(140.0, 0.0, r) * 1.8;
	col += vec3(0.5, 0.55, 0.7) * smoothstep(300.0, 40.0, r) * (0.4 + 0.6 * dens);
	// relâmpagos dentro das nuvens
	float da = abs(mod(a - flash_a + 3.14159, 6.28318) - 3.14159);
	col += vec3(0.5, 0.55, 0.72) * flash * dens * exp(-da * 2.2) * smoothstep(3600.0, 500.0, r);
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(2900.0, 4000.0, r);
}
"""

const SHAFT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform float k = 1.0;
void fragment() {
	float edge = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	ALBEDO = vec3(0.75, 0.82, 1.0) * edge * along * 0.55 * k;
}
"""

func _build_vortex() -> void:
	var na = 140
	var nr = 54
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in nr:
		var u = j / float(nr - 1)
		var r = 4000.0 * pow(u, 2.1)
		var y = VORTEX_Y + 300.0 * (1.0 - exp(-r / 800.0)) - 18.0 * exp(-r / 60.0)
		for i in na + 1:
			var a = TAU * i / na
			verts.append(Vector3(cos(a) * r, y, sin(a) * r))
			norms.append(Vector3.DOWN)
			uvs.append(Vector2(i / float(na), u))
	for j in nr - 1:
		for i in na:
			var a0 = j * (na + 1) + i
			var b0 = a0 + na + 1
			idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.custom_aabb = AABB(Vector3(-4100, VORTEX_Y - 50, -4100), Vector3(8200, 400, 8200))
	var mi = MeshInstance3D.new()
	mi.mesh = am
	vortex_mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = VORTEX_SHADER
	vortex_mat.shader = sh
	var na_t = _noise_tex(.006, 77, Color.BLACK, Color.WHITE, false, 5)
	na_t.width = 1024; na_t.height = 1024
	var nb_t = _noise_tex(.012, 78, Color.BLACK, Color.WHITE, false, 4)
	vortex_mat.set_shader_parameter("noise_a", na_t)
	vortex_mat.set_shader_parameter("noise_b", nb_t)
	mi.material_override = vortex_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(TOWER.x, 0, TOWER.z)
	add_child(mi)
	# feixe de luz descendo do olho até a ponta da torre
	var cone = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 70.0; cm.bottom_radius = 26.0; cm.height = VORTEX_Y - TOP_Y + 60.0
	cm.radial_segments = 32; cm.rings = 1
	cm.cap_top = false; cm.cap_bottom = false
	cone.mesh = cm
	shaft_mat = ShaderMaterial.new()
	var ssh = Shader.new()
	ssh.code = SHAFT_SHADER
	shaft_mat.shader = ssh
	cone.material_override = shaft_mat
	cone.position = TOWER + Vector3(0, TOP_Y + cm.height * .5 - 20.0, 0)
	add_child(cone)
	# brilho do olho (sprites sem neblina)
	glow_halo = _glow_sprite(TOWER + Vector3(0, VORTEX_Y - 25.0, 0), 900.0, Color(.55, .62, .85, .55))
	glow_core = _glow_sprite(TOWER + Vector3(0, VORTEX_Y - 30.0, 0), 260.0, Color(1.0, 1.0, 1.05, 1.0))
	top_light = OmniLight3D.new()
	top_light.light_color = Color(.8, .86, 1.0)
	top_light.light_energy = 9.0
	top_light.omni_range = 190.0
	top_light.omni_attenuation = 1.4
	top_light.position = TOWER + Vector3(0, TOP_Y + 70.0, 0)
	add_child(top_light)

func _glow_tex() -> GradientTexture2D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, .08, .25, .55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, .75), Color(1, 1, 1, .25), Color(1, 1, 1, .06), Color(1, 1, 1, 0)])
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(.5, .5)
	gt.fill_to = Vector2(1.0, .5)
	gt.width = 256; gt.height = 256
	return gt

func _glow_sprite(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_fog = true
	m.no_depth_test = false
	m.albedo_texture = _glow_tex()
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi

## pedaços de rocha e de alvenaria girando em espiral em volta da torre, subindo para o vórtice
func _build_debris() -> void:
	for g in 5:
		var pv = Node3D.new()
		pv.position = Vector3(TOWER.x, 0, TOWER.z)
		pv.rotation.y = rng.randf() * TAU
		add_child(pv)
		var key = "deb%d" % g
		for k in 26:
			var y = rng.randf_range(90.0, 960.0)
			var r = lerp(190.0, 80.0, y / 960.0) + rng.randf_range(-20.0, 45.0)
			var a = rng.randf() * TAU
			var p = Vector3(cos(a) * r, y, sin(a) * r)
			var s = rng.randf_range(2.0, 11.0)
			if rng.randf() < .3:
				_bx(p, Vector3(s * 1.4, s * .7, s * .9), C_STONE, Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU), key)
			else:
				_rock(p, Vector3(s, s * rng.randf_range(.5, 1.0), s * rng.randf_range(.7, 1.2)), C_STONE * .9, key, Vector3(rng.randf() * TAU, rng.randf() * TAU, 0))
		_commit(key, m_stone, pv)
		pivots.append({"n": pv, "w": rng.randf_range(.012, .035) * (1.0 + g * .3)})

func _build_birds() -> void:
	var body_m = BoxMesh.new(); body_m.size = Vector3(.32, .22, .9)
	var wing_m = BoxMesh.new(); wing_m.size = Vector3(1.3, .05, .5)
	for k in 34:
		var b = Node3D.new()
		var bm = MeshInstance3D.new(); bm.mesh = body_m; bm.material_override = m_bird
		b.add_child(bm)
		var wings = []
		for s in [-1, 1]:
			var wp = Node3D.new()
			wp.position = Vector3(s * .12, .05, 0)
			var wm = MeshInstance3D.new(); wm.mesh = wing_m; wm.material_override = m_bird
			wm.position = Vector3(s * .65, 0, 0)
			wp.add_child(wm)
			b.add_child(wp)
			wings.append(wp)
		add_child(b)
		var tower_bird = k < 18
		var c = TOWER if tower_bird else Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 250))
		var info = {"n": b, "w": wings, "c": c, "r": rng.randf_range(80.0, 170.0) if tower_bird else rng.randf_range(25.0, 70.0),
			"h": rng.randf_range(60.0, 420.0) if tower_bird else rng.randf_range(28.0, 70.0), "a": rng.randf() * TAU,
			"sp": rng.randf_range(.08, .16) * (1 if rng.randf() < .7 else -1), "ph": rng.randf() * TAU,
			"sc": rng.randf_range(2.6, 4.0) if tower_bird else rng.randf_range(1.4, 2.0)}
		b.scale = Vector3.ONE * info.sc
		birds.append(info)

func _mist_mat(tex: String, col: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = load("res://fx/%s.png" % tex)
	m.albedo_color = col
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 4.0
	m.distance_fade_max_distance = 30.0
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

func _build_mist() -> void:
	var mats = [_mist_mat("smoke_07", Color(.5, .56, .68, .16)), _mist_mat("smoke_04", Color(.45, .5, .62, .13))]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	var n = 0
	var tries = 0
	while n < 95 and tries < 800:
		tries += 1
		var z = rng.randf_range(-470.0, 380.0)
		var x = rng.randf_range(-_hw(z) - 20.0, _hw(z) + 20.0)
		if z < BR_Z0 - 2.0 and z > BR_Z1 + 2.0: continue
		var mi = MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mats[n % 2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s = rng.randf_range(26.0, 50.0)
		mi.scale = Vector3(s, s * .45, s)
		mi.position = Vector3(x, ground(x, z) + s * .12, z)
		add_child(mi)
		n += 1
	# mar de névoa dentro do abismo, em camadas que deslizam devagar
	for k in 4:
		var pm = PlaneMesh.new()
		pm.size = Vector2(900, 200)
		var mi = MeshInstance3D.new()
		mi.mesh = pm
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var nt = _noise_tex(.01 + k * .004, 300 + k, Color(1, 1, 1, 0), Color(1, 1, 1, 1), false, 4)
		var gg = Gradient.new()
		gg.offsets = PackedFloat32Array([0.0, .42, 1.0])
		gg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
		nt.color_ramp = gg
		m.albedo_texture = nt
		m.albedo_color = Color(.42, .47, .58, .55 - k * .08)
		m.uv1_scale = Vector3(4.0, 1.0, 1.0)
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, -34.0 - k * 34.0, (BR_Z0 + BR_Z1) * .5)
		add_child(mi)
		chasm_mists.append({"m": m, "sp": (.004 + k * .002) * (1 if k % 2 == 0 else -1)})

## capim seco: tufos espalhados (MultiMesh em blocos, some de longe)
func _build_grass() -> void:
	var gm = ArrayMesh.new()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var r = RandomNumberGenerator.new()
	r.seed = 3
	for b in 9:
		var a = r.randf() * TAU
		var lean = Vector3(cos(a), 0, sin(a)) * r.randf_range(.15, .45)
		var h = r.randf_range(.4, 1.05)
		var base = Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * r.randf_range(0.0, .22)
		var side = Vector3(-sin(a), 0, cos(a)) * r.randf_range(.035, .06)
		var tip = base + Vector3(0, h, 0) + lean
		for p in [base - side, base + side, tip]:
			verts.append(p)
			norms.append(Vector3(0, 1, 0))
		cols.append(Color(.55, .52, .45)); cols.append(Color(.55, .52, .45)); cols.append(Color(1.1, 1.05, .9))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	gm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(.5, .47, .36)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	gm.surface_set_material(0, m)
	var cs = 60.0
	var z = -500.0
	while z < 400.0:
		var x = -150.0
		while x < 150.0:
			var xf: Array = []
			for k in 160:
				var px = x + r.randf() * cs
				var pz = z + r.randf() * cs
				if pz < BR_Z0 + 2.0 and pz > BR_Z1 - 2.0: continue
				if abs(px) > _hw(pz) - 2.0: continue
				if abs(px - _path_x(pz)) < 2.6 and (pz > BR_Z1 or pz > -270.0): continue
				if pz < BR_Z1 and abs(px) < 4.0: continue
				if Vector2(px - TOWER.x, pz - TOWER.z).length() < 82.0: continue
				var y = ground(px, pz)
				if abs(ground(px + 1.5, pz) - y) > .9 or abs(ground(px, pz + 1.5) - y) > .9: continue
				var sc = r.randf_range(.7, 1.6)
				xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(.8, 1.3), sc)), Vector3(px, y - .05, pz)))
			if xf.size() > 0:
				var mm = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = gm
				mm.instance_count = xf.size()
				for k in xf.size():
					mm.set_instance_transform(k, xf[k])
					var v = r.randf_range(.75, 1.2)
					mm.set_instance_color(k, Color(v, v * r.randf_range(.92, 1.02), v * .9))
				var mmi = MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 150.0
				add_child(mmi)
			x += cs
		z += cs

func _build_ash() -> void:
	ash = CPUParticles3D.new()
	ash.amount = 900
	ash.lifetime = 10.0
	ash.preprocess = 10.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(70, 22, 70)
	ash.direction = Vector3(.35, -1, .15)
	ash.spread = 30.0
	ash.initial_velocity_min = .6
	ash.initial_velocity_max = 1.6
	ash.gravity = Vector3(.15, -.35, 0)
	var qm = QuadMesh.new()
	qm.size = Vector2(.09, .09)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(.5, .52, .58)
	qm.material = m
	ash.mesh = qm
	ash.scale_amount_min = .5
	ash.scale_amount_max = 1.6
	add_child(ash)

# ======================================================================
# jogo
# ======================================================================
func start_pos() -> Vector3:
	var p: Vector3 = CPS[cp]
	return Vector3(p.x, ground(p.x, p.z) + 2.3, p.z)

## chamado ao trocar de nível / recomeçar
func reset_state() -> void:
	running = false
	finale = false
	if not keep_cp: cp = 0
	keep_cp = false

## o jogador entrou no mapa: começa do último ponto de retorno
func start_run() -> void:
	running = true
	finale = false
	enc_i = CP_ENC[cp]
	if cp == 0: G.main.banner("O VALE DA TORRE", "SUBA ATÉ A LUZ")
	else: G.main.banner("O VALE DA TORRE", "PONTO DE RETORNO")

## chão de verdade (pontes, escadas, terreno) logo abaixo de x, z
func floor_y(x: float, z: float, from_y := NAN) -> float:
	# começa logo acima do chão (para não cair em cima de arcos, torres e pináculos)
	if is_nan(from_y): from_y = max(ground(x, z), 0.0) + 7.0
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -400, z), 1)
	if G.player: q.exclude = [G.player.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else ground(x, z)

func _on_bridge(x: float, z: float) -> bool:
	return abs(x) < DECK_W * .5 - .6 and z < BR_Z0 + 8.0 and z > BR_Z1 - 8.0

## lugar para um inimigo reaparecer perto do jogador
func spawn_near(pp: Vector3) -> Vector3:
	for i in 30:
		var a = rng.randf() * TAU
		var r = rng.randf_range(20.0, 40.0)
		var x = pp.x + cos(a) * r
		var z = pp.z + sin(a) * r
		if z < BR_Z0 + 2.0 and z > BR_Z1 - 2.0 and not _on_bridge(x, z): continue
		if abs(x) > _hw(z) - 3.0: continue
		var y = floor_y(x, z)
		if y < -5.0: continue
		if G.in_solid(Vector3(x, y + 1.2, z)): continue
		return Vector3(x, y, z)
	return Vector3(0, floor_y(0, pp.z - 30.0), pp.z - 30.0)

## 0 = normal, 1 = perdido (volta perto do jogador), 2 = caiu no abismo (morre)
func enemy_state(e) -> int:
	var p: Vector3 = e.global_position
	if p.y < -26.0: return 2
	if abs(p.x) > _hw(p.z) + 34.0 or p.z > 430.0 or p.z < -545.0: return 1
	if e.fly and p.y > max(ground(p.x, p.z), 0.0) + 45.0: return 1
	return 0

## posição de nascimento ajustada ao chão (voadores sobem do abismo na ponte)
func place_enemy(e, at: Vector3) -> void:
	var y = floor_y(at.x, at.z)
	if e.fly:
		var base = max(y, 0.0)
		e.position = Vector3(at.x, base - 12.0 if _on_bridge(at.x, at.z) or y < -20.0 else base + 6.0, at.z)
		e.home = Vector3(at.x, base + 6.0, at.z)
	else:
		e.position = Vector3(at.x, y + .5, at.z)
		e.home = e.position

func player_fell() -> void:
	G.player.global_position = start_pos()
	G.player.velocity = Vector3.ZERO
	G.flash = .5
	G.player.dash_t = 0.0
	G.hurt_player(25.0)

func _process(dt: float) -> void:
	t += dt
	var cam: Camera3D = get_viewport().get_camera_3d()
	# vórtice e relâmpagos
	next_flash -= dt
	if next_flash <= 0.0:
		next_flash = rng.randf_range(5.0, 14.0)
		flash = 1.0
		vortex_mat.set_shader_parameter("flash_a", rng.randf() * TAU)
		var d = rng.randf_range(.6, 2.2)
		get_tree().create_timer(d).timeout.connect(func(): if is_inside_tree(): G.snd("raio", -20.0, rng.randf_range(.35, .5)))
	flash = max(0.0, flash - dt * (2.5 if flash > .5 else 1.2))
	var fl = flash * (.6 + .4 * sin(t * 60.0))
	vortex_mat.set_shader_parameter("flash", fl)
	if G.main and G.main.level == "torre" and G.main.world_sun:
		G.main.world_sun.light_energy = .55 + fl * .6
	var pulse = .5 + .5 * sin(t * .7)
	(glow_core.material_override as StandardMaterial3D).albedo_color.a = .85 + .15 * pulse + fl * .3
	(glow_halo.material_override as StandardMaterial3D).albedo_color.a = .4 + .12 * pulse + fl * .4
	top_light.light_energy = 8.0 + 2.0 * pulse + fl * 6.0
	shaft_mat.set_shader_parameter("k", .8 + .3 * pulse + fl)
	for pv in pivots:
		pv.n.rotation.y += pv.w * dt
	for b in birds:
		b.a += b.sp * dt
		var n: Node3D = b.n
		n.position = b.c + Vector3(cos(b.a) * b.r, b.h + sin(t * .4 + b.ph) * 4.0, sin(b.a) * b.r)
		n.rotation.y = -b.a + (PI if b.sp > 0 else 0.0)
		n.rotation.z = -.3 * sign(b.sp)
		var f = sin(t * 7.0 + b.ph)
		var glide = sin(t * .5 + b.ph) > .3
		var ang = (.1 if glide else f * .75)
		b.w[0].rotation.z = ang
		b.w[1].rotation.z = -ang
	for cm in chasm_mists:
		cm.m.uv1_offset.x += cm.sp * dt
	if cam and ash:
		ash.global_position = cam.global_position + Vector3(0, 8, 0)
	if running and G.state == "play" and G.player:
		_upd_game()

func _upd_game() -> void:
	var pz: float = G.player.global_position.z
	while enc_i < ENC.size() and pz < ENC[enc_i].z:
		var e: Dictionary = ENC[enc_i]
		if e.has("cp"):
			cp = e.cp
			G.heal(20)
		var k = 0
		for d in e.e:
			var kind: String = d[0]
			var at = Vector3(d[1], 0, d[2])
			G.later(.15 + k * .22, func(): if running: G.main.spawn_enemy(kind, at))
			k += 1
		enc_i += 1
	if not finale and enc_i >= ENC.size() and G.enemies.is_empty() and pz < TOWER.z + 130.0:
		finale = true
		G.heal(100)
		G.main.banner("A TORRE ESTÁ SELADA", "POR ENQUANTO...")
		G.snd("angel", -8, .5)
		G.flash = .4
