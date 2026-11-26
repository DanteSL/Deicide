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
var index_pt := Vector3.ZERO # meio do indicador direito (global), usado no giro
var index_ok := false
var ib2 := -1
var ib3 := -1
var GRIP_FWD := .075
var GRIP_PALM := .03
var GRIP_UP := .0 # "pistol" (envolve a mão direita), "barrel" (segura o cano), "hand", "punch"

func setup() -> void:
	var sk := get_skeleton()
	for side in ["r", "l"]:
		bones[side] = [sk.find_bone("upperarm_" + side), sk.find_bone("lowerarm_" + side), sk.find_bone("hand_" + side)]
	for nm in ["index_01_r", "index_02_r", "index_03_r", "middle_01_r", "middle_02_r", "middle_03_r", "ring_01_r", "ring_02_r", "ring_03_r", "pinky_01_r", "pinky_02_r", "pinky_03_r", "thumb_01_r", "thumb_02_r", "thumb_03_r"]:
		var b = sk.find_bone(nm)
		if b >= 0 and nm != "index_01_r": index_r.append(b)
	ib2 = sk.find_bone("index_02_r"); ib3 = sk.find_bone("index_03_r")

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
	if finger_w > 0.0:
		for b in index_r:
			var q0: Quaternion = sk.get_bone_pose_rotation(b)
			var q1: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(b, q0.slerp(q1, clamp(finger_w, 0.0, 1.0)))
	if ib2 >= 0 and ib3 >= 0:
		index_pt = skg * ((sk.get_bone_global_pose(ib2).origin + sk.get_bone_global_pose(ib3).origin) * .5)
		index_ok = true
	if tl != null: _solve(sk, bones.l, inv * tl, ib * Vector3(-.8, -1, .25))

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
