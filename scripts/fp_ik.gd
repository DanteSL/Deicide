extends SkeletonModifier3D
# Braços em primeira pessoa: a animação (respiração + pegada da pistola) roda normalmente
# e aqui as duas mãos são levadas até os pontos de pegada da arma atual (IK de dois ossos).

var W: Node # weapons.gd
var rig: Node3D # raiz do modelo dos braços
var bones = {}
var aim_r: Node3D = null # alvos (Node3D) da mão direita/esquerda; null = pose da animação
var aim_l: Node3D = null
var mode_l := ""
var free_l: Node3D = null # alvo livre da mão esquerda (recargas): palma = +Y do nó, dedos = -Z
var free_w := 0.0
var free_r: Node3D = null # alvo livre da mão direita (giro no dedo)
var free_rw := 0.0
var finger_w := 0.0 # abre a mão direita (dedos e polegar esticados)
var index_r = []
var fist_lw := 0.0
var FIST_SIGN := 1.0 # fecha a mão esquerda em punho (soco)
var fingers_l = [] # [[b1,b2,b3], ...]
var thumb_l = []
var index_pt := Vector3.ZERO # meio do indicador direito (global), usado no giro
var index_ok := false
var ib1 := -1
var ib2 := -1
var ib3 := -1
var GRIP_FWD := .075
var GRIP_PALM := .03
var GRIP_UP := .0 # "pistol" (envolve a mão direita), "barrel" (segura o cano), "hand", "punch"
# ---- dedos que envolvem o cabo da arma ----
# grip_r/grip_l: null = pose da animação; "relax" = mão solta; "support" = apoio sob o cano;
# "cup" = mão em concha (segura a outra mão); ou {"c","u","r"} = cilindro do cabo no referencial da mão
var grip_r = null
var grip_l = null
var grip_w := 1.0
var trigger := false # indicador no gatilho (não envolve o cabo)
var trig := 0.0      # gatilho puxado 0..1
var CH = {}          # lado -> dedo -> [b1, b2, b3, ponta]
const FR := {"thumb": .0112, "index": .0098, "middle": .01, "ring": .0095, "pinky": .0085}
const MAXC := [1.7, 1.9, 1.35]
const RELAX := {"index": [.16, .26, .14], "middle": [.22, .34, .18], "ring": [.28, .42, .22], "pinky": [.34, .5, .26], "thumb": [.06, .14, .1]}
const SUPPORT_P := {"index": [.36, .42, .26], "middle": [.42, .5, .3], "ring": [.46, .56, .32], "pinky": [.5, .62, .34], "thumb": [.12, .3, .22]}
const CUP_P := {"index": [.7, .9, .5], "middle": [.8, 1.0, .55], "ring": [.85, 1.05, .6], "pinky": [.9, 1.1, .62], "thumb": [.2, .45, .35]}
const TRIG_P := [.42, .78, .38]
# ossos de torção do antebraço: repartem o giro da mão ao longo do braço (sem "embrulho de bala" no pulso)
var twist = {}
var rest_rel = {}

func setup() -> void:
	var sk := get_skeleton()
	for side in ["r", "l"]:
		bones[side] = [sk.find_bone("upperarm_" + side), sk.find_bone("lowerarm_" + side), sk.find_bone("hand_" + side)]
	for nm in ["index_01_r", "index_02_r", "index_03_r", "middle_01_r", "middle_02_r", "middle_03_r", "ring_01_r", "ring_02_r", "ring_03_r", "pinky_01_r", "pinky_02_r", "pinky_03_r", "thumb_01_r", "thumb_02_r", "thumb_03_r"]:
		var b = sk.find_bone(nm)
		if b >= 0 and nm != "index_01_r": index_r.append(b)
	for f in ["index", "middle", "ring", "pinky"]:
		var ch = []
		for k in ["01", "02", "03"]: ch.append(sk.find_bone("%s_%s_l" % [f, k]))
		if ch.min() >= 0: fingers_l.append(ch)
	for k in ["01", "02", "03"]:
		var tb = sk.find_bone("thumb_%s_l" % k)
		if tb >= 0: thumb_l.append(tb)
	ib1 = sk.find_bone("index_01_r"); ib2 = sk.find_bone("index_02_r"); ib3 = sk.find_bone("index_03_r")
	for side in ["r", "l"]:
		CH[side] = {}
		for f in ["thumb", "index", "middle", "ring", "pinky"]:
			var ch = []
			for k in ["01", "02", "03", "04_leaf"]: ch.append(sk.find_bone("%s_%s_%s" % [f, k, side]))
			if ch.min() >= 0: CH[side][f] = ch
		var t1 = sk.find_bone("lowerarm_twist_01_" + side)
		var t2 = sk.find_bone("lowerarm_twist_02_" + side)
		if t1 >= 0 and t2 >= 0:
			twist[side] = [t1, t2]
			var L0: Basis = sk.get_bone_global_rest(bones[side][1]).basis.orthonormalized()
			var H0: Basis = sk.get_bone_global_rest(bones[side][2]).basis.orthonormalized()
			rest_rel[side] = (L0.inverse() * H0).get_rotation_quaternion()

func _process_modification_with_delta(_dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or bones.is_empty() or W == null: return
	W.fp_targets(self)
	var skg: Transform3D = sk.global_transform
	var inv := skg.affine_inverse()
	var hr: Transform3D = skg * sk.get_bone_global_pose(bones.r[2])
	var hl: Transform3D = skg * sk.get_bone_global_pose(bones.l[2])
	# referencial da "arma" da animação: na mão direita, olhando para a frente do personagem
	# o centro do cabo fica dentro da mão direita (à frente do pulso, do lado da palma)
	var gc: Vector3 = hr.origin + hr.basis.y.normalized() * GRIP_FWD - hr.basis.x.normalized() * GRIP_PALM + hr.basis.z.normalized() * GRIP_UP
	var f0 := Transform3D(rig.global_transform.basis.orthonormalized() * Basis(Vector3.UP, PI), gc)
	var c_r := f0.affine_inverse() * hr
	var c_l := f0.affine_inverse() * hl
	var tr = null
	var tl = null
	if aim_r:
		tr = aim_r.global_transform.orthonormalized() * c_r
	if aim_l:
		var g: Transform3D = aim_l.global_transform.orthonormalized()
		match mode_l:
			"pistol":
				tl = g * c_l
			"barrel":
				# palma para cima sob o cano, dedos para a frente e para a direita
				var y := (g.basis * Vector3(.45, .2, -.87)).normalized()
				var x := (g.basis * Vector3(.55, .85, 0))
				x = (x - y * x.dot(y)).normalized()
				# o alvo é o ponto de apoio sob o cano; o osso da mão fica no pulso
				tl = Transform3D(Basis(x, y, x.cross(y)), g.origin - y * .075 - x * .04)
			"hand":
				tl = Transform3D(g.basis * _mirror(c_r.basis), g.origin)
			"punch":
				var fwd := -g.basis.z
				tl = Transform3D(Basis(-g.basis.y, fwd, g.basis.x), g.origin)
	if free_l and free_w > 0.0:
		var g2: Transform3D = free_l.global_transform.orthonormalized()
		var fy := -g2.basis.z
		var fx := g2.basis.y
		fx = (fx - fy * fx.dot(fy)).normalized()
		var ft := Transform3D(Basis(fx, fy, fx.cross(fy)), g2.origin - fy * .07)
		tl = ft if tl == null else (tl as Transform3D).interpolate_with(ft, clamp(free_w, 0.0, 1.0))
	# cotovelos sempre para baixo e para fora (nunca subindo na frente da câmera)
	var ib := skg.basis.inverse()
	if free_r and free_rw > 0.0:
		var g3: Transform3D = free_r.global_transform.orthonormalized()
		var ry := -g3.basis.z
		var rx := -g3.basis.y # mão direita: a palma é o -X do osso
		rx = (rx - ry * rx.dot(ry)).normalized()
		var rt := Transform3D(Basis(rx, ry, rx.cross(ry)), g3.origin - ry * .07)
		tr = rt if tr == null else (tr as Transform3D).interpolate_with(rt, clamp(free_rw, 0.0, 1.0))
	if tr != null: _solve(sk, bones.r, inv * tr, ib * Vector3(.8, -1, .25))
	if grip_r != null and finger_w < .99: _fingers(sk, "r", grip_r, grip_w * (1.0 - finger_w))
	if finger_w > 0.0:
		# indicador dobrado 90° na junta da base, apontando para onde a palma olha (entra no guarda-mato)
		if ib1 >= 0:
			var H := sk.get_bone_global_pose(bones.r[2])
			# entre a direção da palma e a esquerda da tela: o dedo atravessa a arma de lado, como no giro de pistoleiro
			var left_dir := (skg.basis.inverse() * Vector3(-1, 0, 0)).normalized()
			var palm_dir := (-H.basis.x.normalized() * .45 + left_dir).normalized()
			var G1 := sk.get_bone_global_pose(ib1)
			var q := Quaternion(G1.basis.y.normalized(), palm_dir)
			var qw := Quaternion.IDENTITY.slerp(q, clamp(finger_w, 0.0, 1.0))
			sk.set_bone_global_pose(ib1, Transform3D(Basis(qw) * G1.basis, G1.origin))
		for b in index_r:
			var q0: Quaternion = sk.get_bone_pose_rotation(b)
			var q1: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(b, q0.slerp(q1, clamp(finger_w, 0.0, 1.0)))
	if ib2 >= 0 and ib3 >= 0:
		var p3 := sk.get_bone_global_pose(ib3).origin
		var p2 := sk.get_bone_global_pose(ib2).origin
		index_pt = skg * (p3 + (p3 - p2) * .3) # perto da ponta do indicador
		index_ok = true
	if tl != null: _solve(sk, bones.l, inv * tl, ib * Vector3(-.8, -1, .25))
	if grip_l != null and fist_lw < .99: _fingers(sk, "l", grip_l, grip_w * (1.0 - fist_lw))
	if fist_lw > 0.0: _fist_l(sk, clamp(fist_lw, 0.0, 1.0))
	for side in twist: _twist(sk, side)

## dedos: pose fixa (solta, apoio, concha) ou fecham até encostar no cilindro do cabo
func _fingers(sk: Skeleton3D, side: String, g, w: float) -> void:
	if w <= 0.001 or not CH.has(side): return
	var H := sk.get_bone_global_pose(bones[side][2])
	var c := Vector3.ZERO
	var u := Vector3.ZERO
	var R := 0.0
	var wrap: bool = g is Dictionary
	if wrap:
		var hb := H.basis.orthonormalized()
		c = H.origin + hb * (g.c as Vector3)
		u = (hb * (g.u as Vector3)).normalized()
		R = g.r
	for f in CH[side]:
		var ch: Array = CH[side][f]
		var fixed = null
		if not wrap:
			fixed = {"relax": RELAX, "support": SUPPORT_P, "cup": CUP_P}.get(g, RELAX)[f]
		elif f == "index" and trigger and side == "r":
			fixed = [TRIG_P[0] + trig * .12, TRIG_P[1] + trig * .38, TRIG_P[2] + trig * .2]
		_wrap(sk, ch, c, u, R, FR[f], w, fixed)

func _wrap(sk: Skeleton3D, ch: Array, c: Vector3, u: Vector3, R: float, rf: float, w: float, fixed) -> void:
	var q_anim := []
	for k in 3:
		q_anim.append(sk.get_bone_pose_rotation(ch[k]))
		sk.set_bone_pose_rotation(ch[k], sk.get_bone_rest(ch[k]).basis.get_rotation_quaternion())
	for k in 3:
		var th := 0.0
		if fixed != null:
			th = fixed[k]
		else:
			var G := sk.get_bone_global_pose(ch[k])
			var piv := G.origin
			var ax := G.basis.x.normalized()
			var nxt := sk.get_bone_global_pose(ch[k + 1]).origin
			var v := nxt - piv
			var lim: float = MAXC[k]
			if _cd(piv + Basis(ax, lim) * v, c, u) >= R + rf:
				th = lim
			elif _cd(nxt, c, u) >= R + rf:
				var lo := 0.0
				var hi := lim
				for it in 10:
					var mid := (lo + hi) * .5
					if _cd(piv + Basis(ax, mid) * v, c, u) >= R + rf: lo = mid
					else: hi = mid
				th = lo
		var rq: Quaternion = sk.get_bone_rest(ch[k]).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(ch[k], rq * Quaternion(Vector3(1, 0, 0), th))
	if w < .999:
		for k in 3:
			sk.set_bone_pose_rotation(ch[k], (q_anim[k] as Quaternion).slerp(sk.get_bone_pose_rotation(ch[k]), w))

func _cd(p: Vector3, c: Vector3, u: Vector3) -> float:
	var d := p - c
	return (d - u * d.dot(u)).length()

## torção: a parte do giro da mão em volta do eixo do antebraço vai 1/3 e 2/3 para os ossos de torção
func _twist(sk: Skeleton3D, side: String) -> void:
	var L: Basis = sk.get_bone_global_pose(bones[side][1]).basis.orthonormalized()
	var Hb: Basis = sk.get_bone_global_pose(bones[side][2]).basis.orthonormalized()
	var rel: Quaternion = (L.inverse() * Hb).get_rotation_quaternion()
	var d: Quaternion = rel * rest_rel[side].inverse()
	var ang := 2.0 * atan2(d.y, d.w)
	ang = clamp(wrapf(ang, -PI, PI), -2.6, 2.6)
	sk.set_bone_pose_rotation(twist[side][0], Quaternion(Vector3.UP, ang * .33))
	sk.set_bone_pose_rotation(twist[side][1], Quaternion(Vector3.UP, ang * .66))

# espelha uma pegada da mão direita para a esquerda (eixos do esqueleto espelhados em X)
func _mirror(b: Basis) -> Basis:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var x := m * b.x
	var y := m * b.y
	var z := m * b.z
	return Basis(-x, y, z)

func _solve(sk: Skeleton3D, ch: Array, t: Transform3D, hint: Vector3) -> void:
	var ua: int = ch[0]; var la: int = ch[1]; var hd: int = ch[2]
	var A := sk.get_bone_global_pose(ua)
	var B := sk.get_bone_global_pose(la)
	var C := sk.get_bone_global_pose(hd)
	var a := A.origin; var b := B.origin; var c := C.origin
	var l1 := a.distance_to(b); var l2 := b.distance_to(c)
	var to := t.origin - a
	# alvo longe demais: o ombro (fora da tela) avança em direção à arma
	var over := to.length() - (l1 + l2) * .97
	if over > 0.0:
		a += to.normalized() * min(over, .45)
		sk.set_bone_global_pose(ua, Transform3D(A.basis, a))
		A = sk.get_bone_global_pose(ua)
		b = sk.get_bone_global_pose(la).origin
		to = t.origin - a
	var d: float = clamp(to.length(), abs(l1 - l2) + .001, (l1 + l2) * .999)
	var dir := to.normalized()
	var pole := hint - dir * hint.dot(dir)
	if pole.length() < .0001: pole = (b - a) - dir * (b - a).dot(dir)
	pole = pole.normalized()
	var ca: float = clamp((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var b2 := a + dir * (l1 * ca) + pole * (l1 * sqrt(1.0 - ca * ca))
	var t2 := a + dir * d
	var q1 := Quaternion((b - a).normalized(), (b2 - a).normalized())
	sk.set_bone_global_pose(ua, Transform3D(Basis(q1) * A.basis, a))
	var B1 := sk.get_bone_global_pose(la)
	var cnow := sk.get_bone_global_pose(hd).origin
	var q2 := Quaternion((cnow - B1.origin).normalized(), (t2 - B1.origin).normalized())
	sk.set_bone_global_pose(la, Transform3D(Basis(q2) * B1.basis, B1.origin))
	var H := sk.get_bone_global_pose(hd)
	var sc := H.basis.get_scale()
	sk.set_bone_global_pose(hd, Transform3D(t.basis.orthonormalized().scaled_local(sc), H.origin))


# dobra cada falange em direção à palma (palma da mão esquerda = +X do osso da mão)
func _fist_l(sk: Skeleton3D, w: float) -> void:
	var H := sk.get_bone_global_pose(bones.l[2])
	var palm := -H.basis.x.normalized() * FIST_SIGN
	var ang := [1.6, 1.8, 1.4]
	for ch in fingers_l:
		for k in 3:
			var b: int = ch[k]
			var G0 := sk.get_bone_global_pose(b)
			var by := G0.basis.y.normalized()
			var ax := by.cross(palm)
			if ax.length() < .001: continue
			var q := Quaternion(ax.normalized(), ang[k] * w)
			sk.set_bone_global_pose(b, Transform3D(Basis(q) * G0.basis, G0.origin))
			palm = (Basis(q) * palm).normalized() if k == 0 else palm
	# polegar: atravessa por cima dos dedos dobrados
	var hy := H.basis.y.normalized()
	var p0 := -H.basis.x.normalized() * FIST_SIGN
	for i in thumb_l.size():
		var b: int = thumb_l[i]
		var G1 := sk.get_bone_global_pose(b)
		var ty := G1.basis.y.normalized()
		var ax2: Vector3 = ty.cross(p0) if i > 0 else ty.cross(hy)
		if ax2.length() < .001: continue
		var a2: float = [.5, .6, .5][i]
		sk.set_bone_global_pose(b, Transform3D(Basis(Quaternion(ax2.normalized(), a2 * w)) * G1.basis, G1.origin))
