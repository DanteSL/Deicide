extends Node3D
## Ceifadora: anjo com cajado-foice. Modelo com esqueleto (24 ossos) animado por código:
## andar de passarela (rebolado, passo cruzado), asas vivas e golpes corpo a corpo.

const SC := 2.4
var sk: Skeleton3D
var B = {}
var rest = {}
var rest_pos = {}
var ginv = {}
var acc = {}
var wing_ax = {}
var mats = []
var hip_off = Vector3.ZERO
var rest_tf = {}


func build() -> void:
	var ps: PackedScene = load("res://ceifadora.glb")
	var m = ps.instantiate()
	m.scale = Vector3.ONE * SC
	m.position = Vector3(0, 0, -.25 * SC)
	add_child(m)
	sk = _find(m)
	var tex = null
	for mi in _meshes(m):
		var src = mi.mesh.surface_get_material(0)
		if src is StandardMaterial3D: tex = src.albedo_texture
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.05, .98, .92)
	mat.roughness = .55
	mat.metallic_specular = .4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.rim_enabled = true
	mat.rim = .35
	mat.rim_tint = .6
	mats.append(mat)
	for mi in _meshes(m):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in sk.get_bone_count():
		var nm = sk.get_bone_name(i)
		B[nm] = i
		rest[i] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
		rest_pos[i] = sk.get_bone_rest(i).origin
		rest_tf[i] = sk.get_bone_rest(i)
		ginv[i] = sk.get_bone_global_rest(i).basis.orthonormalized().inverse()
	if not B.has("staff") and B.has("staff_2"): B["staff"] = B["staff_2"]
	# eixos das asas: "erguer" (ponta sobe) e "abrir" (ponta vai para fora)
	for nm in ["wing.L.1", "wing.L.2", "wing.L.3", "wing.R.1", "wing.R.2", "wing.R.3"]:
		if not B.has(nm): continue
		var i = B[nm]
		var d = sk.get_bone_global_rest(i).basis.y.normalized()
		var lift = d.cross(Vector3.UP)
		if lift.length() < .1: lift = Vector3.RIGHT
		var o = Vector3(1 if nm.contains(".L") else -1, 0, 0)
		var sp = 1.0 if Vector3.UP.cross(d).dot(o) > 0 else -1.0
		wing_ax[nm] = [lift.normalized(), sp]

func _find(n):
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r = _find(c)
		if r: return r
	return null

func _meshes(n: Node) -> Array:
	var out = []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out += _meshes(c)
	return out

func R(nm: String, ax: Vector3, ang: float) -> void:
	if abs(ang) < 1e-5 or not B.has(nm): return
	var i = B[nm]
	var la = (ginv[i] * ax).normalized()
	acc[i] = acc.get(i, Quaternion.IDENTITY) * Quaternion(la, ang)

func apply() -> void:
	for i in rest:
		sk.set_bone_pose_rotation(i, rest[i] * acc.get(i, Quaternion.IDENTITY))
	sk.set_bone_pose_position(B["hips"], rest_pos[B["hips"]] + hip_off)
	acc.clear()
	hip_off = Vector3.ZERO

# ---------- parâmetros de pose (todos em eixos do modelo: X = esquerda dela, Y = cima, Z = frente) ----------
func pose(p: Dictionary, k: float) -> void:
	if k <= 0: return
	var v = func(key): return p.get(key, 0.0) * k
	var t = v.call("twist")
	R("spine", Vector3.UP, t * .4); R("chest", Vector3.UP, t * .6)
	var l = v.call("lean")
	R("spine", Vector3.RIGHT, l * .5); R("chest", Vector3.RIGHT, l * .5)
	R("spine", Vector3.BACK, v.call("roll"))
	var c = v.call("crouch")
	if c != 0:
		hip_off.y -= .09 * c
		for s in ["L", "R"]:
			R("thigh." + s, Vector3.RIGHT, -.75 * c)
			R("shin." + s, Vector3.RIGHT, 1.25 * c)
			R("foot." + s, Vector3.RIGHT, -.5 * c)
		R("spine", Vector3.RIGHT, .35 * c)
	hip_off.z += v.call("hz")
	R("hips", Vector3.UP, v.call("hipY"))
	R("upperarm.L", Vector3.RIGHT, -v.call("aL")); R("upperarm.L", Vector3.BACK, v.call("aLz")); R("upperarm.L", Vector3.UP, v.call("aLy"))
	R("forearm.L", Vector3.RIGHT, -v.call("fL")); R("forearm.L", Vector3.UP, v.call("fLy"))
	R("upperarm.R", Vector3.RIGHT, -v.call("aR")); R("upperarm.R", Vector3.BACK, -v.call("aRz")); R("upperarm.R", Vector3.UP, v.call("aRy"))
	R("forearm.R", Vector3.RIGHT, -v.call("fR"))
	R("staff", Vector3.RIGHT, v.call("st")); R("staff", Vector3.UP, v.call("sty")); R("staff", Vector3.BACK, v.call("stz"))
	R("head", Vector3.RIGHT, v.call("head"))
	wings(v.call("wl"), v.call("ws"))
	for s in ["L", "R"]:
		var sg = 1.0 if s == "L" else -1.0
		R("thigh." + s, Vector3.RIGHT, -v.call("leg" + s))
		R("shin." + s, Vector3.RIGHT, v.call("knee" + s))

func wings(lift: float, spread: float) -> void:
	for nm in wing_ax:
		var w = wing_ax[nm]
		var seg = int(nm.right(1))
		var kl = [0.0, 1.0, .55, .35][seg]
		var ks = [0.0, 1.0, .4, .2][seg]
		R(nm, w[0], lift * kl)
		R(nm, Vector3.UP, spread * w[1] * ks)

# interpolação suave entre poses-chave (números e vetores; o que faltar vem da pose de carregar)
static func _kv(d: Dictionary, k: String):
	return d[k] if d.has(k) else CARRY.get(k, 0.0)

static func sample(keys: Array, t: float) -> Dictionary:
	var a = keys[0]
	var b = keys[0]
	var u = 0.0
	if t >= keys[keys.size() - 1][0]:
		a = keys[keys.size() - 1]; b = a
	else:
		for i in range(1, keys.size()):
			if t <= keys[i][0]:
				a = keys[i - 1]; b = keys[i]
				u = clamp((t - a[0]) / max(.0001, b[0] - a[0]), 0.0, 1.0)
				u = u * u * (3 - 2 * u)
				break
	var out = {}
	var ks = {}
	for k in a[1]: ks[k] = true
	for k in b[1]: ks[k] = true
	for k in CARRY: ks[k] = true
	for k in ks:
		var va = _kv(a[1], k)
		var vb = _kv(b[1], k)
		if va is Vector3:
			out[k] = va.lerp(vb, u)
		else:
			out[k] = lerp(float(va), float(vb), u)
	return out

# ---------- andar de passarela ----------
# base: perna esquerda trazida para baixo do corpo e cajado carregado em pé
const BASE := {"legL": 0.0, "aLz": 0.0}
func base_pose() -> void:
	R("thigh.L", Vector3.BACK, -.27)
	R("shin.L", Vector3.BACK, -.1)
	R("foot.L", Vector3.BACK, .12)
	R("thigh.R", Vector3.BACK, .03)
	R("chest", Vector3.RIGHT, -.06)

func walk(cyc: float, w: float, t: float) -> void:
	var s = sin(cyc)
	var c = cos(cyc)
	# pernas: passo cruzado (cada pé pisa na frente do outro)
	var swing = .5 * w
	R("thigh.L", Vector3.RIGHT, -s * swing)
	R("thigh.R", Vector3.RIGHT, s * swing)
	var kL = (.1 + .75 * max(0.0, c)) * w
	var kR = (.1 + .75 * max(0.0, -c)) * w
	R("shin.L", Vector3.RIGHT, kL)
	R("shin.R", Vector3.RIGHT, kR)
	R("foot.L", Vector3.RIGHT, -kL * .45 + s * .2 * w)
	R("foot.R", Vector3.RIGHT, -kR * .45 - s * .2 * w)
	R("thigh.L", Vector3.BACK, -.1 * max(0.0, s) * w)
	R("thigh.R", Vector3.BACK, .1 * max(0.0, -s) * w)
	# rebolado: quadril balança de lado, gira e cai do lado da perna que avança
	hip_off.x += -.03 * s * w
	hip_off.y += (.012 * cos(2 * cyc) - .01) * w
	R("hips", Vector3.BACK, -.13 * s * w)
	R("hips", Vector3.UP, -.2 * s * w)
	# tronco compensa (ombros vão ao contrário do quadril)
	R("spine", Vector3.BACK, .1 * s * w)
	R("chest", Vector3.UP, .22 * s * w)
	R("chest", Vector3.BACK, .04 * s * w)
	R("neck", Vector3.BACK, -.05 * s * w)
	R("head", Vector3.UP, -.1 * s * w)
	# braço livre balança com charme, punho solto
	R("upperarm.R", Vector3.RIGHT, -s * .32 * w)
	R("upperarm.R", Vector3.BACK, -.1 * w)
	R("forearm.R", Vector3.RIGHT, -(.25 + .2 * max(0.0, s)) * w)
	R("upperarm.L", Vector3.RIGHT, .06 * s * w)
	# asas acompanham o passo
	wings(.06 * s * w, 0.0)

func idle(t: float, w: float) -> void:
	R("hips", Vector3.BACK, .05 * sin(t * 1.3) * w)
	hip_off.x += .008 * sin(t * 1.3) * w
	R("spine", Vector3.RIGHT, .02 * sin(t * 2.1) * w)
	R("head", Vector3.UP, .08 * sin(t * .7) * w)

func breathe_wings(t: float, k: float) -> void:
	wings(.07 * sin(t * 2.4) + .02, .05 + .04 * sin(t * 1.2))
	if k > 0: wings(.0, 0.0)

# ---------- cinemática inversa dos braços e direção do cajado ----------
# alvos em coordenadas do modelo (X = esquerda dela, Y = cima, Z = frente; corpo em z = .25)
const CARRY := {"hL": Vector3(.15, .7, .33), "O": Vector3(-.45, .72, -.55), "roll": 0.0, "two": 0.0}

func _arc(a: Vector3, b: Vector3) -> Basis:
	a = a.normalized(); b = b.normalized()
	var c = a.cross(b)
	var d = a.dot(b)
	if c.length() < 1e-5:
		if d > 0: return Basis.IDENTITY
		var ax = a.cross(Vector3.RIGHT)
		if ax.length() < .1: ax = a.cross(Vector3.UP)
		return Basis(ax.normalized(), PI)
	return Basis(c.normalized(), atan2(c.length(), d))

func _two_bone(side: String, T: Vector3, pole: Vector3, k: float) -> Array:
	var up = B["upperarm." + side]
	var fo = B["forearm." + side]
	var ha = B["hand." + side]
	var pg: Transform3D = sk.get_bone_global_pose(sk.get_bone_parent(up))
	var S = (pg * rest_tf[up]).origin
	var l1 = rest_tf[fo].origin.length()
	var l2 = rest_tf[ha].origin.length()
	var v = T - S
	var d = clamp(v.length(), .02, l1 + l2 - .002)
	var n = v.normalized()
	var a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	var h = sqrt(max(0.0, l1 * l1 - a * a))
	var pv = (pole - S) - n * (pole - S).dot(n)
	if pv.length() < 1e-4: pv = Vector3.DOWN
	var E = S + n * a + pv.normalized() * h
	var Bu0 = pg.basis * rest_tf[up].basis
	var Bu = _arc(Bu0.y, E - S) * Bu0
	var Bf0 = Bu * rest_tf[fo].basis
	var Tc = S + n * d
	var Bf = _arc(Bf0.y, Tc - E) * Bf0
	var qu = (pg.basis.inverse() * Bu).get_rotation_quaternion()
	var qf = (Bu.inverse() * Bf).get_rotation_quaternion()
	if k < 1.0:
		qu = sk.get_bone_pose_rotation(up).slerp(qu, k)
		qf = sk.get_bone_pose_rotation(fo).slerp(qf, k)
	sk.set_bone_pose_rotation(up, qu)
	sk.set_bone_pose_rotation(fo, qf)
	return [Bf, Tc]

func arms_ik(p: Dictionary) -> void:
	var O = (p.O as Vector3).normalized()
	var T = p.hL as Vector3
	var r = _two_bone("L", T, T + Vector3(.35, -.35, -.25), 1.0)
	var Bf: Basis = r[0]
	var ha = B["hand.L"]
	var st = B["staff"]
	var Hg0 = Bf * rest_tf[ha].basis
	var cur = (Hg0 * rest_tf[st].basis).y
	var Hg = Basis(-O, p.roll) * _arc(cur, -O) * Hg0
	sk.set_bone_pose_rotation(ha, (Bf.inverse() * Hg).get_rotation_quaternion())
	sk.set_bone_pose_rotation(st, rest[st])
	var two = float(p.two)
	if two > .01:
		var grip = r[1] + Hg * rest_tf[st].origin
		var TR = grip + O * .3
		_two_bone("R", TR, TR + Vector3(-.4, -.3, -.2), two)

func apply_all(p: Dictionary) -> void:
	apply()
	arms_ik(p)

# ---------- golpes (poses-chave; alvos da mão esquerda hL e direção da ponta do cajado O) ----------
const ATK := {
	"slash": {"dur": .95, "hit": .5, "keys": [
		[0.0, {}],
		[.38, {"twist": .75, "crouch": .25, "lean": .05, "hL": Vector3(.34, .62, .14), "O": Vector3(.65, .1, -.75), "two": 1.0, "wl": .35, "ws": .3}],
		[.47, {"twist": .1, "crouch": .35, "lean": .25, "hL": Vector3(.14, .6, .5), "O": Vector3(.3, -.08, 1.0), "two": 1.0, "wl": .5, "ws": .5, "hz": .03}],
		[.55, {"twist": -.85, "crouch": .35, "lean": .3, "hL": Vector3(-.16, .6, .42), "O": Vector3(-1.0, -.12, .25), "two": .8, "wl": .4, "ws": .5, "hz": .04}],
		[.72, {"twist": -.9, "crouch": .25, "lean": .2, "hL": Vector3(-.18, .6, .38), "O": Vector3(-.9, -.25, -.1), "two": .6, "wl": .15, "ws": .25}],
		[.95, {}]]},
	"overhead": {"dur": 1.25, "hit": .74, "keys": [
		[0.0, {}],
		[.52, {"lean": -.35, "hL": Vector3(.06, 1.04, .22), "O": Vector3(0, .35, -1.0), "two": 1.0, "wl": .75, "ws": .6, "head": -.2}],
		[.65, {"lean": -.45, "hL": Vector3(.04, 1.07, .17), "O": Vector3(0, .05, -1.0), "two": 1.0, "wl": .95, "ws": .7, "head": -.25}],
		[.76, {"lean": .7, "crouch": .55, "hL": Vector3(.03, .48, .58), "O": Vector3(0, -.8, .6), "two": 1.0, "wl": -.35, "ws": .55, "head": .15, "hz": .05}],
		[1.0, {"lean": .55, "crouch": .45, "hL": Vector3(.03, .46, .55), "O": Vector3(0, -.85, .5), "two": .8, "wl": -.1, "ws": .3}],
		[1.25, {}]]},
	"spin": {"dur": 1.3, "hit": .62, "keys": [
		[0.0, {}],
		[.28, {"crouch": .3, "hL": Vector3(.3, .62, .36), "O": Vector3(1.0, -.05, .25), "two": 0.0, "aRz": 1.1, "wl": .3, "ws": .9}],
		[1.0, {"crouch": .25, "hL": Vector3(.3, .62, .36), "O": Vector3(1.0, -.1, .3), "two": 0.0, "aRz": 1.2, "wl": .5, "ws": 1.0}],
		[1.3, {}]]},
	"lunge": {"dur": 1.2, "hit": .55, "keys": [
		[0.0, {}],
		[.38, {"crouch": .8, "lean": .2, "twist": .35, "hL": Vector3(.18, .5, .1), "O": Vector3(-.15, .25, -1.0), "two": .9, "wl": .9, "ws": .5}],
		[.5, {"lean": .65, "hL": Vector3(.04, .62, .66), "O": Vector3(0, -.05, 1.0), "two": 1.0, "wl": -.6, "ws": .15, "legL": .7, "kneeL": .3, "legR": -.5, "kneeR": .2, "hz": .05}],
		[.85, {"lean": .5, "crouch": .2, "hL": Vector3(.04, .6, .6), "O": Vector3(0, -.15, 1.0), "two": .9, "wl": -.3, "legL": .6, "legR": -.4}],
		[1.2, {}]]},
}
