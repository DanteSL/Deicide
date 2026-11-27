extends Node
## Armas em primeira pessoa (renderizadas num mundo próprio, sem atravessar paredes):
## revólver (giro, ricochete carregado, recarga com tambor), escopeta (giro a cada tiro, recarga invertida bala por bala) e soco/aparar.

var cur = 0
var prev = 1
var switch_time = 0
var zoom = false

# estado de animação
var recoil = 0.0
var spin_t = 1.0
var spin_dur = 0.8
var spin_a0 = 0.0
var spin_a1 = 0.0
var spin_axis = "x"
var spin_toss = 0.0
var inspecting = false
var cock_after = false
var draw_t = 1.0
var cd = 0.0
var hammer = 0.0
var drum_a = 0.0
var drum_t = 0.0
var pump_t = 2.0
var charge = 0.0
var charging = false
var c_ang = 0.0
var flash_t = 0.0
var sb = 0.0
var rb = 0.0
var punch_t = 1.0
var jab_t := -1.0 # tempo desde o início do jab (-1 = parado)
var sway = Vector2.ZERO
var bob_ph = 0.0
var bob_a = 0.0
var tilt = 0.0

# munição
var rv_ammo = 6
var rv_max = 6
var rv_reloading = false
var rv_t = 0.0
var rv_ev = 0
var sg_ammo = 6
var sg_max = 6
var sg_reloading = false
var sg_phase = ""
var sg_t = 0.0
var sg_ins = false

var root: Node3D # raiz do viewmodel
var rev = {}
var sg = {}
var fist: Node3D
var glow_mat: StandardMaterial3D
var vparts = []
var vlight: OmniLight3D
var X: Node # armas extras
const IDS := ["rev", "sg", "sword", "rocket", "nail", "rail", "harp", "gren"]

const SG_LT := 0.46

func _ready() -> void:
	call_deferred("_build")

func _mat(c: String, rough := 0.5, metal := 0.3) -> StandardMaterial3D:
	return G.lit(Color(c), rough, metal)

func mk(sz: Vector3, mat: Material, p: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	m.mesh = bm
	m.material_override = mat
	m.position = p
	m.rotation_order = EULER_ORDER_XYZ
	m.rotation = rot
	parent.add_child(m)
	return m

func cyl(r1: float, r2: float, hgt: float, seg: int, mat: Material, p: Vector3, parent: Node3D, rot := Vector3(PI / 2, 0, 0)) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r2
	cm.height = hgt
	cm.radial_segments = seg
	cm.rings = 1
	m.mesh = cm
	m.material_override = mat
	m.position = p
	m.rotation_order = EULER_ORDER_XYZ
	m.rotation = rot
	parent.add_child(m)
	return m

# ---------------- braços (modelo enviado pelo jogador): pele branca rachada de sangue ----------------
# ---- braços em primeira pessoa (modelo animado enviado pelo jogador) ----
const ARMS_POS := Vector3(0, -1.66, -.2)
var arms: Node3D
var arms_ik: SkeletonModifier3D
var grips = {} # id da arma -> {"r": Node3D, "l": Node3D, "lmode": String}
var fist_grip: Node3D
var rl_marker: Node3D # mão esquerda na recarga da pistola
var rl_w := 0.0
# giro de pistoleiro: mão aberta, só o indicador dobrado dentro do guarda-mato, a arma roda em volta dele
const SPIN_PIVOT := Vector3(0, -.012, .01)
var spin_w := 0.0
var spin_r: Node3D
var spin_l: Node3D
const SPIN_HAND := Vector3(.3, -.15, -.68) # onde a mão aberta fica durante o giro (espaço da câmera)
var rack := 0.0
var load_grip: Node3D

func _hex_of(m: Material) -> String:
	return (m as StandardMaterial3D).albedo_color.to_html(false) if m is StandardMaterial3D else ""


func _marker(par: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	par.add_child(n)
	return n

func _setup_arms() -> void:
	var glove_hex = Color("3a2c2a").to_html(false)
	var sleeve_hex = Color("7a1410").to_html(false)
	var groups = {}
	for mi in _all_meshes(root):
		var hx = _hex_of(mi.material_override)
		if hx != glove_hex and hx != sleeve_hex: continue
		mi.visible = false # as mãos/mangas provisórias somem
		if hx != glove_hex: continue
		var par: Node3D = mi.get_parent()
		if not groups.has(par) or (mi.mesh as BoxMesh).size.length() > (groups[par].mesh as BoxMesh).size.length():
			groups[par] = mi
	for c in fist.get_children():
		if c is MeshInstance3D: c.visible = false
	if "--noarms" in OS.get_cmdline_user_args(): return
	if not ResourceLoader.exists("res://maos/maos.glb"): return
	for par in groups:
		var pos: Vector3 = groups[par].position
		if par == rev.root:
			grips.rev = {"r": _marker(par, pos + PISTOL_HAND_OFS), "l": null, "lmode": "pistol"}
			grips.rev.l = grips.rev.r
		elif par == sg.root:
			if not grips.has("sg"): grips.sg = {}
			grips.sg.r = _marker(par, pos)
		elif par == sg.left:
			if not grips.has("sg"): grips.sg = {}
			grips.sg.l = _marker(par, Vector3(0, -.045, .03)); grips.sg.lmode = "barrel"
		elif par == sg.load_hand:
			load_grip = _marker(par, pos)
		elif par == fist:
			fist_grip = _marker(par, Vector3.ZERO)
		elif par.get_parent() == X.hands:
			if not grips.has("sword"): grips.sword = {"lmode": "hand"}
			grips.sword["r" if par.position.x > 0 else "l"] = _marker(par, pos + Vector3(0, -.02, .03))
		else:
			for k in IDS:
				var md = model(IDS.find(k))
				if md.get("root") == par:
					grips[k] = {"r": _marker(par, pos), "l": null, "lmode": "barrel"}
	for k in SUPPORT:
		var md = model(IDS.find(k))
		if grips.has(k) and md.has("body"):
			grips[k].l = _marker(md.body, SUPPORT[k])
	rl_marker = _marker(rev.root, Vector3.ZERO)
	spin_r = _marker(root, SPIN_HAND)
	spin_l = _marker(rev.root, Vector3(-.22, -.55, .3))
	spin_l.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)) # palma para trás, dedos para cima
	arms = load("res://maos/maos.glb").instantiate()
	arms.rotation = Vector3(0, PI, 0)
	arms.position = ARMS_POS
	root.add_child(arms)
	for m in _all_meshes(arms):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 4.0
	_skin_materials(arms)
	var ap: AnimationPlayer = arms.find_children("*", "AnimationPlayer", true, false)[0]
	arms_ap = ap
	var an: String = ap.get_animation_list()[0]
	for a in ap.get_animation_list():
		if String(a).contains("fps_test"): an = a
	ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	ap.play(an)
	var sk: Skeleton3D = arms.find_children("*", "Skeleton3D", true, false)[0]
	arms_ik = preload("res://scripts/fp_ik.gd").new()
	sk.add_child(arms_ik)
	arms_ik.W = self
	arms_ik.rig = arms
	arms_ik.setup()
	R = preload("res://scripts/reliquias.gd").new()
	R.name = "Reliquias"
	add_child(R)
	R.setup(self)

## pele humana (duas texturas misturadas, cores de vértice) e unhas
var skin_mat: ShaderMaterial
var nail_mat: StandardMaterial3D
var arms_ap: AnimationPlayer
var R: Node = null # relíquias (armas dos chefes)
func _skin_materials(n: Node) -> void:
	skin_mat = ShaderMaterial.new()
	skin_mat.shader = load("res://shaders/pele.gdshader")
	for k in [["cor1", "pele1_cor"], ["cor2", "pele2_cor"], ["nrm1", "pele1_normal"], ["nrm2", "pele2_normal"], ["liso1", "pele1_liso"], ["liso2", "pele2_liso"]]:
		skin_mat.set_shader_parameter(k[0], load("res://maos/%s.jpg" % k[1]))
	var fn = FastNoiseLite.new()
	fn.frequency = .01
	var nt = NoiseTexture2D.new()
	nt.width = 256; nt.height = 256; nt.seamless = true; nt.noise = fn
	skin_mat.set_shader_parameter("manchas", nt)
	nail_mat = StandardMaterial3D.new()
	nail_mat.albedo_color = Color(.86, .7, .66)
	nail_mat.roughness = .3
	nail_mat.clearcoat_enabled = true
	nail_mat.clearcoat = .6
	nail_mat.clearcoat_roughness = .25
	nail_mat.vertex_color_use_as_albedo = false
	for mi in _all_meshes(n):
		if not String(mi.name).begins_with("Braco"): continue
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var sm = mesh.surface_get_material(si)
			var nm = String(sm.resource_name) if sm else ""
			if nm.begins_with("Faixa"): continue
			mi.set_surface_override_material(si, nail_mat if nm.begins_with("Unha") else skin_mat)

# chamado pelo IK a cada quadro: escolhe onde cada mão deve estar
func fp_targets(ik) -> void:
	if R and R.cur != "":
		ik.aim_r = null; ik.aim_l = null; ik.mode_l = ""
		ik.free_l = null; ik.free_w = 0.0; ik.free_r = null; ik.free_rw = 0.0; ik.finger_w = 0.0
		ik.grip_r = null; ik.grip_l = null; ik.trigger = false; ik.trig = 0.0; ik.fist_lw = 0.0
		arms.visible = true
		return
	var g = grips.get(IDS[cur], {})
	var md = W()
	var shown: bool = md.has("root") and md.root.visible
	if IDS[cur] == "sword": shown = X.hands.visible
	ik.aim_r = g.get("r") if shown else null
	ik.aim_l = g.get("l") if shown else null
	ik.mode_l = g.get("lmode", "")
	ik.free_l = null; ik.free_w = 0.0
	ik.free_r = null; ik.free_rw = 0.0; ik.finger_w = 0.0
	if shown and cur == 0 and rl_marker:
		ik.free_l = rl_marker; ik.free_w = rl_w
		if spin_w > .001 and not rv_reloading:
			ik.free_r = spin_r; ik.free_rw = spin_w; ik.finger_w = spin_w
			ik.free_l = spin_l; ik.free_w = spin_w
	elif shown and cur == 1:
		ik.free_l = sg.load_hand; ik.free_w = sb
	# dedos: o cabo de cada arma (cilindro no referencial da mão direita) e a mão de apoio
	var fit: Dictionary = GRIP_FIT.get(IDS[cur], {})
	ik.grip_r = fit.get("r", "relax")
	ik.grip_l = fit.get("l", "support")
	ik.trigger = fit.get("trig", false)
	ik.trig = clamp(trig_v, 0.0, 1.0)
	if ik.mode_l == "pistol": ik.grip_l = "cup"
	if ik.free_w > .5 and ik.free_l != null: ik.grip_l = "relax"
	ik.fist_lw = 0.0
	if fist_grip and fist.visible:
		ik.aim_l = fist_grip; ik.mode_l = "free"
		ik.free_l = fist_grip; ik.free_w = 1.0
		ik.fist_lw = jab_fw
	arms.visible = ik.aim_r != null or ik.aim_l != null

## cabo de cada arma para os dedos fecharem em volta (c = centro, u = eixo, r = raio; referencial da mão direita:
## +X dorso, +Y para os dedos, +Z lado do polegar)
const GRIP_FIT := {
	"rev": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.28, 1), "r": .0145}, "trig": true},
	"sg": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .0165}, "trig": true, "l": "support"},
	"sword": {"r": "relax", "l": "relax"},
	"rocket": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .0175}, "trig": true, "l": "support"},
	"nail": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .016}, "trig": true, "l": "support"},
	"rail": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .016}, "trig": true, "l": "support"},
	"harp": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .016}, "trig": true, "l": "support"},
	"gren": {"r": {"c": Vector3(-.03, .075, .0), "u": Vector3(0, -.22, 1), "r": .017}, "trig": true, "l": "support"},
}
var trig_v := 0.0 # gatilho puxado (decai sozinho)

# ponto da mão direita na pistola (ajuste fino sobre a luva antiga)
const PISTOL_HAND_OFS := Vector3(-.005, .05, .0)
# onde a mão esquerda segura o cano das armas de duas mãos (no corpo da arma)
const SUPPORT := {
	"rocket": Vector3(0, -.05, -.12),
	"nail": Vector3(0, -.045, -.12),
	"rail": Vector3(0, -.05, -.12),
	"harp": Vector3(0, -.045, -.12),
	"gren": Vector3(0, -.05, -.12),
}

func _all_meshes(n: Node) -> Array:
	var out = []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out += _all_meshes(c)
	return out

# texturas feitas por código (o modelo não tem UV: usamos projeção triplanar)
func _noise_tex(freq: float, seed_: int, c0: Color, c1: Color, sx := 1.0) -> NoiseTexture2D:
	var n = FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 4
	var t = NoiseTexture2D.new()
	t.width = 256; t.height = 256
	t.seamless = true
	t.noise = n
	var g = Gradient.new()
	g.set_color(0, c0); g.set_color(1, c1)
	t.color_ramp = g
	return t

func _wood_tex() -> ImageTexture:
	var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	var n = FastNoiseLite.new()
	n.frequency = .03
	var dark = Color(.22, .1, .05)
	var light = Color(.52, .27, .12)
	for y in 256:
		for x in 256:
			var w = sin((x + n.get_noise_2d(x * .3, y * 2.0) * 40.0) * .35) * .5 + .5
			w = pow(w, 3.0)
			var c = light.lerp(dark, w)
			c = c.lerp(Color(.12, .05, .02), clamp(n.get_noise_2d(x * 2.0, y * 8.0) * .6, 0.0, 1.0))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _rev_mats() -> Dictionary:
	var steel = StandardMaterial3D.new()
	steel.albedo_texture = _noise_tex(.02, 3, Color(.13, .15, .2), Color(.3, .33, .4))
	steel.metallic = .85
	steel.roughness = .38
	steel.roughness_texture = _noise_tex(.06, 7, Color(.45, .45, .45), Color(.95, .95, .95))
	steel.normal_enabled = true
	steel.normal_scale = .35
	var nt = _noise_tex(.08, 11, Color.BLACK, Color.WHITE)
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	steel.normal_texture = nt
	steel.uv1_triplanar = true
	steel.uv1_scale = Vector3.ONE * 6.0
	steel.rim_enabled = true; steel.rim = .35
	steel.emission_enabled = true
	steel.emission = Color(.25, .9, 1.0)
	steel.emission_energy_multiplier = 0.0
	var drum = steel.duplicate()
	drum.albedo_texture = _noise_tex(.025, 5, Color(.38, .39, .43), Color(.62, .63, .67))
	drum.roughness = .3
	var wood = StandardMaterial3D.new()
	wood.albedo_texture = _wood_tex()
	wood.roughness = .55
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(9, 9, 9)
	wood.rim_enabled = true; wood.rim = .2
	var brass = StandardMaterial3D.new()
	brass.albedo_color = Color(.78, .56, .25)
	brass.metallic = 1.0
	brass.roughness = .28
	return {"steel": steel, "drum": drum, "wood": wood, "brass": brass}

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var r = _find_mesh(c)
		if r: return r
	return null

func rig(pivot: Vector3) -> Dictionary:
	var o = {"root": Node3D.new(), "pivot": Node3D.new(), "body": Node3D.new()}
	for k in o: o[k].rotation_order = EULER_ORDER_XYZ
	o.root.add_child(o.pivot)
	o.pivot.add_child(o.body)
	o.pivot.position = pivot
	o.body.position = -pivot
	root.add_child(o.root)
	return o

func _flash_quad(size: float, parent: Node3D) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = _flash_tex()
	mat.albedo_color = Color(1, .85, .55)
	m.material_override = mat
	m.visible = false
	parent.add_child(m)
	return m

var _ftex: ImageTexture
func _flash_tex() -> ImageTexture:
	if _ftex: return _ftex
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dx = x - 15.5
			var dy = y - 15.5
			var r = sqrt(dx * dx + dy * dy) / 16.0
			var a = atan2(dy, dx)
			var star: float = 0.55 + 0.45 * abs(cos(a * 5.0))
			var v: float = clamp(1.0 - r / star, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 0.8 + 0.2 * v, 0.4 + 0.6 * v * v, v))
	_ftex = ImageTexture.create_from_image(img)
	return _ftex

func _build() -> void:
	root = G.main.vm_root
	vlight = OmniLight3D.new()
	vlight.omni_range = 2.5
	vlight.light_color = Color(1, .75, .4)
	vlight.light_energy = 0
	vlight.position = Vector3(.2, -.05, -.8)
	root.add_child(vlight)
	var glove = _mat("3a2c2a", .9, 0)
	var sleeve = _mat("7a1410", .9, 0)
	var gold = _mat("b88a30", .35, .8)
	var dark = _mat("2a2c33", .5, .5)
	var wood = _mat("6e3b22", .8, 0)
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(0.25, 0.9, 1.0, 0)
	# ---- pistola (modelo enviado pelo jogador) no lugar do revólver: mesmo tiro, ricochete e giro ----
	rev = rig(SPIN_PIVOT)
	var b: Node3D = rev.body
	var p_metal = _mat("2e3139", .35, .75)
	var p_black = _mat("141519", .55, .2)
	var p_light = _mat("8f949d", .28, .85)
	rev.pistol = true
	# revólver de dois canos (modelo enviado pelo jogador)
	var p_main = _mat("b8571a", .4, .55) # faixas cobre
	var p_grey = _mat("3a3d44", .5, .45)
	var p_white = _mat("9aa0a8", .3, .8)
	p_white.emission_enabled = true
	p_white.emission = Color.BLACK
	rev.steel = p_white
	var pist: Node3D = load("res://revolver/revolver.glb").instantiate()
	b.add_child(pist)
	for mi in _all_meshes(pist):
		var mesh: Mesh = mi.mesh
		for si in mesh.get_surface_count():
			var sm = mesh.surface_get_material(si)
			var nm = String(sm.resource_name) if sm else ""
			var mt: Material = p_black
			match nm:
				"Main": mt = p_main
				"Grey": mt = p_grey
				"White": mt = p_white
			mi.set_surface_override_material(si, mt)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if rev.has("slide"): rev.slide_base = rev.slide.position
	# pente: fica escondido na empunhadura e cai/entra na recarga
	rev.drum_base = Vector3(0, -.05, .085)
	rev.drum_open = Vector3(0, -.15, .035)
	rev.drum = Node3D.new()
	rev.drum.position = rev.drum_base
	rev.drum.rotation.x = -.25
	b.add_child(rev.drum)
	mk(Vector3(.03, .1, .045), p_black, Vector3(0, .005, 0), rev.drum)
	mk(Vector3(.036, .012, .052), p_metal, Vector3(0, -.05, 0), rev.drum)
	cyl(.006, .006, .03, 6, gold, Vector3(0, .058, -.008), rev.drum, Vector3(PI / 2, 0, 0))
	rev.hammer = Node3D.new()
	b.add_child(rev.hammer)
	rev.muzzle = Node3D.new()
	rev.muzzle.position = Vector3(0, .09, -.35)
	b.add_child(rev.muzzle)
	rev.fl = _flash_quad(.22, rev.muzzle)
	mk(Vector3(.075, .07, .09), glove, Vector3(.005, -.092, .078), rev.root, Vector3(-.3, 0, 0))
	mk(Vector3(.08, .08, .42), sleeve, Vector3(.025, -.183, .285), rev.root, Vector3(.45, 0, 0))
	rev.rest = Vector3(.17, -.15, -.5)
	rev.kz = .09; rev.kr = .5; rev.lr = .25
	# ---- escopeta ----
	sg = rig(Vector3(0, 0, -.12))
	b = sg.body
	var redm = _mat("5a1e1e", .5, .5)
	cyl(.028, .028, .62, 10, dark, Vector3(0, .035, -.38), b)
	cyl(.022, .022, .5, 10, dark, Vector3(0, -.012, -.32), b)
	cyl(.033, .033, .025, 10, gold, Vector3(0, .035, -.64), b)
	mk(Vector3(.08, .11, .24), redm, Vector3(0, .01, 0), b)
	mk(Vector3(.082, .02, .2), dark, Vector3(0, .068, 0), b)
	mk(Vector3(.012, .02, .02), gold, Vector3(0, .06, -.68), b)
	mk(Vector3(.066, .11, .3), wood, Vector3(0, -.035, .24), b, Vector3(.15, 0, 0))
	mk(Vector3(.07, .12, .03), dark, Vector3(0, -.055, .39), b, Vector3(.15, 0, 0))
	mk(Vector3(.04, .006, .09), G.unshaded(Color(0.07, 0.07, 0.07)), Vector3(0, -.047, .02), b)
	sg.pump = Node3D.new()
	sg.pump.position = Vector3(0, -.012, -.3)
	b.add_child(sg.pump)
	mk(Vector3(.07, .065, .17), wood, Vector3.ZERO, sg.pump)
	for i in [-1, 0, 1]:
		mk(Vector3(.074, .01, .012), dark, Vector3(0, -.02, i * .045), sg.pump)
	sg.left = Node3D.new()
	sg.pump.add_child(sg.left)
	mk(Vector3(.08, .07, .09), glove, Vector3(-.025, -.04, 0), sg.left)
	mk(Vector3(.07, .07, .36), sleeve, Vector3(-.1, -.2, .15), sg.left, Vector3(.6, .45, 0))
	sg.muzzle = Node3D.new()
	sg.muzzle.position = Vector3(0, .035, -.72)
	b.add_child(sg.muzzle)
	sg.fl = _flash_quad(.38, sg.muzzle)
	mk(Vector3(.075, .075, .09), glove, Vector3(0, -.075, .1), sg.root, Vector3(-.3, 0, 0))
	mk(Vector3(.08, .08, .42), sleeve, Vector3(.03, -.16, .3), sg.root, Vector3(.45, 0, 0))
	sg.load_hand = Node3D.new()
	sg.load_hand.rotation_order = EULER_ORDER_XYZ
	b.add_child(sg.load_hand)
	mk(Vector3(.08, .065, .085), glove, Vector3(0, -.01, .01), sg.load_hand)
	mk(Vector3(.06, .06, .26), sleeve, Vector3(.09, .08, .13), sg.load_hand, Vector3(.55, -.6, 0))
	sg.shell = Node3D.new()
	sg.shell.position = Vector3(0, .03, -.075)
	sg.load_hand.add_child(sg.shell)
	cyl(.021, .021, .075, 8, _mat("b01818", .6, 0), Vector3.ZERO, sg.shell)
	cyl(.023, .023, .018, 8, gold, Vector3(0, 0, .045), sg.shell)
	sg.load_hand.visible = false
	sg.rest = Vector3(.22, -.25, -.62)
	sg.kz = .12; sg.kr = .35; sg.lr = .1
	# ---- punho do soco ----
	fist = Node3D.new()
	fist.rotation_order = EULER_ORDER_XYZ
	root.add_child(fist)
	mk(Vector3(.09, .09, .45), sleeve, Vector3(0, 0, .22), fist)
	mk(Vector3(.12, .11, .13), glove, Vector3(0, 0, -.04), fist)
	mk(Vector3(.126, .03, .025), gold, Vector3(0, .035, -.105), fist)
	X = preload("res://scripts/extra_weapons.gd").new()
	add_child(X)
	X.build(self)
	_setup_arms()
	apply_upgrades()
	cur = G.loadout[0] if G.loadout.size() > 0 else 0
	prev = G.loadout[1] if G.loadout.size() > 1 else cur
	switch_to(cur, true)

func _strut(par: Node3D, p: Vector3, q: Vector3, t: float, m: Material) -> void:
	var dy = q.y - p.y
	var dz = q.z - p.z
	var l = sqrt(dy * dy + dz * dz)
	mk(Vector3(t, t, l), m, (p + q) * 0.5, par, Vector3(atan2(-dy, dz), 0, 0))

func W() -> Dictionary:
	return model(cur)

func model(i: int) -> Dictionary:
	if i == 0: return rev
	if i == 1: return sg
	return X.models[IDS[i]]

func id() -> String:
	return IDS[cur]

func upg(w: String, u: String) -> bool:
	return G.UP.get(w, {}).get(u, false)

func apply_upgrades() -> void:
	rv_max = 8 if upg("rev", "ext") else 6
	sg_max = 10 if upg("sg", "drum") else 6
	rv_ammo = rv_max
	sg_ammo = sg_max
	rv_reloading = false
	sg_reloading = false

func sg_lt() -> float:
	return .28 if upg("sg", "fast") else SG_LT

# troca por posição no equipamento (teclas 1–8)
func select_slot(n: int) -> void:
	if n < G.loadout.size(): switch_to(G.loadout[n])

func cycle(dirn: int) -> void:
	var lo: Array = G.loadout
	if lo.size() < 2: return
	var k = lo.find(cur)
	k = 0 if k < 0 else (k + dirn + lo.size()) % lo.size()
	switch_to(lo[k])

func quick_swap() -> void:
	if R and R.cur != "": switch_to(cur, true); return
	if prev in G.loadout and prev != cur: switch_to(prev)
	else: cycle(1)

func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func start_spin(turns: float, dur: float, axis: String, from := 0.0, toss := 0.0) -> void:
	spin_a0 = from
	spin_a1 = ceil(from / TAU - 1e-6) * TAU + turns * TAU
	spin_t = 0.0
	spin_dur = dur
	spin_axis = axis
	spin_toss = toss

func spin_angle() -> float:
	return spin_a0 + (spin_a1 - spin_a0) * ease_out(spin_t)

func switch_to(i: int, force := false) -> void:
	if rev.is_empty(): return
	if R and R.cur != "":
		R.leave()
		force = true
	if i == cur and not force: return
	if charging:
		charging = false
	sg_reloading = false
	rv_reloading = false
	sb = 0; rb = 0
	cock_after = false
	if i != cur: prev = cur
	cur = i
	draw_t = 0
	recoil = 0
	cd = 0.22
	inspecting = false
	switch_time = Time.get_ticks_msec()
	if i == 0: start_spin(2, .55, "x")
	elif i == 1:
		spin_t = 1
		pump_t = -.4
	else:
		start_spin(1, .45, "x")
	for k in IDS.size(): model(k).root.visible = k == i
	X.on_switch(IDS[i])
	G.snd("draw", -8)
	if G.main: G.main.on_weapon_changed()

## tecla 9
func relic_next() -> void:
	if R: R.next()

## chamado pelas relíquias ao entrar (on) e sair: esconde/mostra a arma normal e zera os estados dela
func on_relic(on: bool) -> void:
	charging = false; sg_reloading = false; rv_reloading = false; zoom = false
	inspecting = false; spin_t = 1; jab_t = -1.0; sb = 0; rb = 0
	for k in IDS.size(): model(k).root.visible = (not on) and k == cur
	X.on_switch("relic" if on else IDS[cur])
	if not on:
		draw_t = 0
		switch_time = Time.get_ticks_msec()
		start_spin(1, .45, "x")
		if G.main: G.main.on_weapon_changed()

func reset_ammo() -> void:
	if R: R.reset_world()
	rv_ammo = rv_max
	sg_ammo = sg_max
	rv_reloading = false
	sg_reloading = false
	if X: X.reset()

func muzzle_world() -> Vector3:
	var c = G.cam.global_transform
	return c.origin + c.basis.x * .22 - c.basis.y * .17 - c.basis.z * .7

func cam_dir() -> Vector3:
	return -G.cam.global_transform.basis.z

func muzzle_flash(w: Dictionary) -> void:
	w.fl.visible = true
	w.fl.rotation.z = G.rnd(0, TAU)
	flash_t = 0.05
	vlight.light_energy = 3
	G.main.world_flash(G.cam.global_position, 2.5)

func inspect() -> void:
	if R and R.cur != "":
		R.inspect(); return
	if spin_t < 1 or charging or draw_t < 1 or sg_reloading or rv_reloading: return
	if cur == 1 and sg_ammo < sg_max:
		start_sg_reload(); return
	if cur == 0 and rv_ammo < rv_max:
		start_rev_reload(); return
	if cur >= 2:
		if cur == 2: return
		inspecting = true
		start_spin(1, .7, "x", 0, .6)
		G.snd("whoosh", -8)
		return
	inspecting = true
	if cur == 0: start_spin(3, .85, "x")
	else: start_spin(1, .75, "x", 0, 1)
	G.snd("whoosh", -8)

func on_spin_end() -> void:
	recoil += .22
	G.snd("click", -10)
	if cock_after:
		cock_after = false
		pump_t = -.001
	if inspecting:
		inspecting = false
		if G.enemies.size() > 0 and Time.get_ticks_msec() - _last_flourish > 4000:
			G.add_style(15, "FLOREIO")
			_last_flourish = Time.get_ticks_msec()
		if cur == 1: pump_t = -.001
	if cur == 1 and sg_ammo == 0: start_sg_reload()
	if cur == 0 and rv_ammo == 0: start_rev_reload()
var _last_flourish = 0

# ---------------- tiro ----------------
func try_fire() -> void:
	if R and R.cur != "":
		R.fire(); return
	if cur == 2:
		if draw_t >= .6: X.fire("sword")
		return
	if cd > 0 or draw_t < .6 or charging: return
	if cur >= 2:
		spin_t = 1
		inspecting = false
		if not G.blood_can(IDS[cur]):
			if cd <= 0: G.blood_out(); cd = .3
			return
		var cd0 = cd
		X.fire(IDS[cur])
		if cd > cd0 + .001: G.blood_take(IDS[cur])
		return
	if cur == 0:
		if rv_reloading: return
		if rv_ammo <= 0:
			G.snd("click", -6); start_rev_reload(); return
		fire_rev()
		return
	if sg_reloading:
		if sg_ammo > 0: sg_reloading = false
		else: return
	if sg_ammo <= 0:
		start_sg_reload(); return
	fire_sg(false)

func fire_rev() -> void:
	spin_t = 1
	inspecting = false
	var d = cam_dir()
	var o = G.cam.global_position
	var r = G.shoot(o, d, 220, upg("rev", "pierce"))
	var kills = 0
	for h in r.hits:
		if G.hurt_enemy(h.e, 68.0 if h.head else 34.0, "rev", h.point, h.head, d): kills += 1
	if kills > 1: G.add_style(30 * kills, "PERFURAÇÃO ×%d" % kills)
	if r.wall: G.emit("spark", r.end, 6, 8, .08, .3)
	G.tracer(muzzle_world(), r.end, .016, Color(1, .88, .6), .08)
	cd = .36; recoil = 1; hammer = 1; drum_t += TAU / 6
	_eject_casing()
	muzzle_flash(rev)
	G.shake = max(G.shake, .12)
	G.snd("rev", -2, G.rnd(.96, 1.04))
	G.snd("click", -18, G.rnd(.9, 1.05))
	rv_ammo -= 1
	if rv_ammo <= 0:
		G.later(.3, func(): if cur == 0 and rv_ammo <= 0: start_rev_reload())

## cápsula saindo da janela de ejeção da pistola
func _eject_casing() -> void:
	if not rev.has("pistol"): return
	var m = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = .006; cm.bottom_radius = .006; cm.height = .022; cm.radial_segments = 6
	m.mesh = cm
	m.material_override = G.lit(Color("b88a30"), .3, .8)
	root.add_child(m)
	m.global_position = rev.body.to_global(Vector3(.012, .085, -.08))
	vparts.append({"m": m, "v": Vector3(G.rnd(.5, .8), G.rnd(.4, .7), G.rnd(.05, .2)), "life": .7, "spin": G.rnd(-25, 25)})

func bounces(ch: float) -> int:
	return 1 + int(floor(ch * 7.999))

func fire_rico(ch: float) -> void:
	var d = cam_dir()
	var o = G.cam.global_position
	var n = bounces(ch)
	var dmg = 45.0 + 35.0 * ch
	var r = G.shoot(o, d, 220, false)
	var visited = []
	var start: Vector3
	var count = [0]
	G.tracer(muzzle_world(), r.end, .04 + .07 * ch, Color("40e8ff"), .35)
	if r.hits.size() > 0:
		var h = r.hits[0]
		visited.append(h.e)
		count[0] = 1
		start = h.point
		G.hurt_enemy(h.e, dmg * 2.0 if h.head else dmg, "rico", h.point, h.head, d)
	else:
		start = r.end - d * .4
		G.emit("cyan", start, 10, 8, .09, .4)
		G.snd("ping", -6)
	_hop(start, n, visited, count, dmg, ch)
	cd = .55; recoil = 1.6; hammer = 1; drum_t += TAU / 6
	_eject_casing()
	muzzle_flash(rev)
	G.shake = max(G.shake, .5)
	G.snd("big", 0, G.rnd(.9, .96))
	rv_ammo -= 1

func _hop(from: Vector3, left: int, visited: Array, count: Array, dmg: float, ch: float) -> void:
	G.later(.075, func():
		var best = null
		var bd = 48.0
		for e in G.enemies:
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0 or e in visited: continue
			var dd: float = e.center().distance_to(from)
			if dd < bd and G.los(from, e.center()):
				bd = dd
				best = e
		if best == null or left <= 0:
			if count[0] >= 2: G.add_style(15 * count[0], "RICOCHETE ×%d" % count[0])
			return
		visited.append(best)
		count[0] += 1
		var c: Vector3 = best.center()
		G.tracer(from, c, .035 + .05 * ch, Color("9ff4ff"), .3)
		G.emit("cyan", c, 8, 7, .09, .35)
		G.snd("ping", -6, G.rnd(.95, 1.1))
		G.hurt_enemy(best, dmg, "rico", c, false, (c - from).normalized())
		_hop(c, left - 1, visited, count, dmg, ch))

func fire_sg(dbl: bool) -> void:
	var d = cam_dir()
	var o = G.cam.global_position
	var acc = {}
	var mw = muzzle_world()
	var np = 26 if dbl else 12
	var spread = .15 if dbl else .1
	var bx = G.cam.global_transform.basis.x
	var by = G.cam.global_transform.basis.y
	for i in np:
		var a = G.rnd(0, TAU)
		var s = sqrt(G.rng.randf()) * spread
		var pd = (d + bx * cos(a) * s + by * sin(a) * s).normalized()
		var r = G.shoot(o, pd, 120, false)
		if r.hits.size() > 0:
			var h = r.hits[0]
			if not acc.has(h.e): acc[h.e] = {"dmg": 0.0, "point": h.point, "head": false}
			acc[h.e].dmg += 16.0 if h.head else 11.0
			acc[h.e].head = acc[h.e].head or h.head
		elif r.wall and i % 3 == 0:
			G.emit("spark", r.end, 3, 6, .07, .25)
		G.tracer(mw, r.end, .01, Color(1, .82, .48), .06)
	var kills = 0
	for e in acc.keys():
		var x = acc[e]
		if upg("sg", "fire") and is_instance_valid(e) and "burn" in e: e.burn = 1.5 if e.is_boss else 3.0
		if G.hurt_enemy(e, x.dmg, "sg", x.point, x.head, d): kills += 1
		elif is_instance_valid(e) and e.kind != "brute" and not e.is_boss:
			e.velocity += d * (26.0 if dbl else 12.0) + Vector3(0, 8.0 if dbl else 3.0, 0)
	if kills > 1: G.add_style(60, "MULTI ABATE ×%d" % kills)
	if dbl:
		sg_ammo -= 2; cd = .95; recoil = 2.4; pump_t = -.55
		start_spin(2, .8, "x", 0, 1.3)
		muzzle_flash(sg); sg.fl.scale = Vector3.ONE * 1.8
		G.shake = max(G.shake, .8)
		G.player.velocity += d * (-14.0 if G.player.is_on_floor() else -22.0)
		if d.y < -.5: G.player.velocity.y = max(G.player.velocity.y, 16)
		G.flash = max(G.flash, .15)
		G.snd("sg", 0); G.later(.03, func(): G.snd("sg", -2)); G.snd("boomlite", -6)
		G.add_style(25 if acc.size() > 0 else 10, "RAJADA DUPLA")
		return
	sg.fl.scale = Vector3.ONE
	sg_ammo -= 1; cd = .42 if upg("sg", "fast") else .62; recoil = 1.35; pump_t = -.3
	start_spin(1, .55, "x", 0, 1)
	muzzle_flash(sg)
	G.shake = max(G.shake, .35)
	G.snd("sg", 0, G.rnd(.95, 1.03))

# ---------------- botão direito ----------------
func alt_press() -> void:
	if R and R.cur != "":
		R.alt_press(); return
	if G.player.dead: return
	if cur >= 2:
		if cur != 2 and draw_t < .6: return
		if cur != 2 and IDS[cur] != "rail" and not G.blood_can(IDS[cur], 1.5) and not (IDS[cur] in ["rocket", "gren"]):
			G.blood_out(); return
		var cd1 = cd
		X.alt_press(IDS[cur])
		if cd > cd1 + .001 and IDS[cur] != "rail": G.blood_take(IDS[cur], 1.5)
		return
	if cur == 1:
		if cd > 0 or draw_t < .6: return
		if sg_reloading:
			if sg_ammo > 0: sg_reloading = false
			else: return
		if sg_ammo <= 0:
			start_sg_reload(); return
		fire_sg(sg_ammo >= 2)
		return
	if draw_t < .6 or rv_reloading: return
	if rv_ammo <= 0:
		G.snd("click", -6); start_rev_reload(); return
	charging = true
	charge = 0
	c_ang = fmod(spin_angle(), TAU) if spin_t < 1 else 0.0
	spin_t = 1
	inspecting = false

func alt_release() -> void:
	if R and R.cur != "":
		R.alt_release(); return
	if cur >= 2 or zoom:
		X.alt_release(IDS[cur])
		return
	if not charging: return
	charging = false
	var from = fmod(c_ang, TAU)
	if charge > .1 and cd <= 0:
		fire_rico(charge)
		start_spin(1, .6, "x", from)
	else:
		start_spin(0, .35, "x", from)
	charge = 0

# ---------------- recargas ----------------
var rv_fill := 6
func start_rev_reload() -> void:
	if cur != 0 or rv_reloading or rv_ammo >= rv_max or charging: return
	var can: int = min(rv_max - rv_ammo, int(G.blood / G.BLOOD_COST.rev))
	if can <= 0:
		G.blood_out(); return
	G.blood_take("rev", can)
	rv_fill = rv_ammo + can
	rv_reloading = true; rv_t = 0; rv_ev = 0; spin_t = 1; inspecting = false
	G.snd("draw", -8)

func _upd_rev_reload(dt: float) -> void:
	if not rv_reloading: return
	if rev.has("pistol"):
		_upd_pistol_reload(dt)
		return
	rv_t += dt
	var t = rv_t
	var n = rv_max
	var tc = .42 + n * .09 + .03
	if rv_ev == 0 and t >= .22:
		rv_ev = 1; G.snd("latch", -6)
	if rv_ev == 1 and t >= .3:
		rv_ev = 2
		for i in rv_max - rv_ammo:
			var m = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = .009; cm.bottom_radius = .009; cm.height = .04; cm.radial_segments = 6
			m.mesh = cm
			m.material_override = G.lit(Color("b88a30"), .3, .8)
			root.add_child(m)
			m.global_position = rev.drum.global_position
			vparts.append({"m": m, "v": Vector3(G.rnd(-.25, .05), G.rnd(-.1, .2), G.rnd(.05, .25)), "life": .9, "spin": G.rnd(-15, 15)})
		G.snd("casings", -8)
	if rv_ev >= 2 and rv_ev < 2 + n and t >= .42 + (rv_ev - 2) * .09:
		rv_ev += 1
		rv_ammo = min(rv_max, rv_ammo + 1)
		drum_t += TAU / 6
		G.snd("shell", -8)
	if rv_ev == 2 + n and t >= tc:
		rv_ev += 1; G.snd("latch", -6)
	if t >= tc + .1:
		rv_reloading = false
		rv_ammo = rv_max
		start_spin(2, .5, "x")
		cd = .15

## recarga da pistola: a mão esquerda solta o pente, busca outro, encaixa e puxa o ferrolho
const PR_END := 1.15
func _upd_pistol_reload(dt: float) -> void:
	rv_t += dt
	var t = rv_t
	if rv_ev == 0 and t >= .18:
		rv_ev = 1
		G.snd("latch", -6)
		# o pente vazio cai
		var mag = rev.drum.duplicate()
		root.add_child(mag)
		mag.global_transform = rev.drum.global_transform
		vparts.append({"m": mag, "v": Vector3(G.rnd(-.05, .05), -.4, .1), "life": .8, "spin": G.rnd(-6, 6)})
	if rv_ev == 1 and t >= .7:
		rv_ev = 2
		G.snd("latch", -4, 1.15)
		rv_ammo = rv_fill
	if rv_ev == 2 and t >= .8:
		rv_ev = 3
		G.snd("click", -10, .8)
	if rv_ev == 3 and t >= .9:
		rv_ev = 4
		hammer = 1.0
		G.snd("pump", -8, 1.5)
	if t >= PR_END:
		rv_reloading = false
		rv_ammo = rv_fill
		cd = .1

func _sm(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

# pose da mão esquerda na recarga da pistola (no espaço da raiz da pistola)
func _pistol_reload_pose(t: float) -> Array:
	var grip := Vector3(-.03, -.06, .05)
	var drum: Vector3 = rev.root.to_local(rev.drum.global_position)
	var up := Vector3.UP
	var keys = [
		[0.0, grip, Vector3(1, .3, 0), Vector3(0, -.2, -1)],
		[.2, Vector3(-.05, -.17, .1), Vector3(.3, 1, 0), Vector3(0, -.3, -1)],
		[.34, Vector3(-.1, -.3, .14), up, Vector3(.2, 0, -1)],
		[.46, drum + Vector3(0, -.075, .0), up, Vector3(0, .1, -1)],
		[.7, drum + Vector3(0, -.075, .0), up, Vector3(0, .1, -1)],
		[.8, Vector3(-.01, .105, -.02), Vector3(-.3, -1, 0), Vector3(1, 0, -.5)],
		[.88, Vector3(-.01, .105, .045), Vector3(-.3, -1, 0), Vector3(1, 0, -.5)],
		[.95, Vector3(-.05, .12, .06), Vector3(-.3, -1, 0), Vector3(1, .2, -.5)],
		[PR_END, grip, Vector3(1, .3, 0), Vector3(0, -.2, -1)],
	]
	var i = 0
	while i < keys.size() - 2 and t > keys[i + 1][0]: i += 1
	var k0 = keys[i]; var k1 = keys[i + 1]
	var u = _sm((t - k0[0]) / max(.001, k1[0] - k0[0]))
	# entre .46 e .7 a mão acompanha o pente subindo
	return [k0[1].lerp(k1[1], u), k0[2].lerp(k1[2], u).normalized(), k0[3].lerp(k1[3], u).normalized()]

func start_sg_reload() -> void:
	if cur != 1 or sg_reloading or sg_ammo >= sg_max or draw_t < 1: return
	if not G.blood_can("sg"):
		G.blood_out(); return
	sg_reloading = true; sg_phase = "raise"; sg_t = 0; sg_ins = false; spin_t = 1; inspecting = false
	G.snd("draw", -8)

func _upd_sg_reload(dt: float) -> void:
	if not sg_reloading: return
	sg_t += dt
	if sg_phase == "raise":
		if sg_t >= .3:
			sg_phase = "load"; sg_t = 0
	elif sg_phase == "load":
		var u = sg_t / sg_lt()
		if u >= .55 and not sg_ins:
			sg_ins = true
			sg_ammo += 1
			G.blood_take("sg")
			G.snd("shell", -6)
		if u >= 1:
			sg_t = 0; sg_ins = false
			if sg_ammo >= sg_max or not G.blood_can("sg"):
				sg_reloading = false; sg_phase = ""
				pump_t = -.12
				cd = .45

# ---------------- soco / aparar ----------------
func punch() -> void:
	if R and R.cur != "":
		R.punch(); return
	if punch_t < 1 or G.player.dead: return
	punch_t = 0
	# jab: se a mão ainda está na guarda, sai direto de lá
	jab_t = JAB_GUARD_FROM if (jab_t > .3 and jab_t < .82) else 0.0
	G.snd("punch", -4)
	var d = cam_dir()
	var o = G.cam.global_position
	var parried = 0
	for p in G.projs:
		if p.owner != "enemy" or p.life <= 0: continue
		var to: Vector3 = p.m.global_position - o
		if to.length() < 4.5 and to.normalized().dot(d) > .3:
			G.main.parry_proj(p, d)
			parried += 1
	if parried > 0:
		G.main.hitstop(.25)
		G.flash = max(G.flash, .3)
		G.shake = max(G.shake, .25)
		G.heal(40)
		G.snd("clang", 0)
		G.later(.25, func():
			G.flash = 1.0
			G.shake = max(G.shake, 1.0)
			G.snd("boom", -2))
		G.add_style(100, "APARADO")
	for e in G.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
		var to: Vector3 = e.center() - o
		if to.length() < 3.4 + (6.0 if e.is_boss else 0.0) and to.normalized().dot(d) > .45:
			G.hurt_enemy(e, 30, "punch", e.center(), false, d)
			if is_instance_valid(e) and e.alive and not e.is_boss:
				var k = .3 if e.kind == "brute" else 1.0
				e.velocity += d * 16 * k + Vector3(0, 6 * k, 0)
			G.shake = max(G.shake, .2)

# ---------------- jab ----------------
const JAB_END := .98
const JAB_GUARD_FROM := .06
var jab_fw := 0.0
# [tempo, posição do pulso (espaço da câmera), direção do soco, giro da mão (0 = palma para baixo)]
const JAB_KEYS := [
	[0.0, Vector3(-.36, -.66, -.1), Vector3(.1, .7, -.7), 1.2],
	[.06, Vector3(-.25, -.27, -.22), Vector3(.12, .55, -.83), 1.45],
	[.15, Vector3(-.11, -.06, -.6), Vector3(.12, .12, -1), .05],
	[.22, Vector3(-.11, -.06, -.59), Vector3(.12, .12, -1), .05],
	[.4, Vector3(-.21, -.1, -.44), Vector3(.2, .45, -.87), .55],
	[.72, Vector3(-.21, -.11, -.44), Vector3(.2, .43, -.88), .55],
	[JAB_END, Vector3(-.36, -.68, -.12), Vector3(.1, .7, -.7), 1.2],
]
func _jab_pose(t: float) -> Array:
	var i = 0
	while i < JAB_KEYS.size() - 2 and t > JAB_KEYS[i + 1][0]: i += 1
	var k0 = JAB_KEYS[i]; var k1 = JAB_KEYS[i + 1]
	var u: float = clamp((t - k0[0]) / max(.001, k1[0] - k0[0]), 0.0, 1.0)
	# o golpe sai seco; o resto é suave
	u = ease_out(u) if i == 1 else _sm(u)
	var pos: Vector3 = k0[1].lerp(k1[1], u)
	if i == 4: pos += Vector3(0, sin(t * 9.0) * .006, 0) # respira na guarda
	var fwd: Vector3 = k0[2].lerp(k1[2], u).normalized()
	var roll: float = lerp(float(k0[3]), float(k1[3]), u)
	# palma (= +Y do marcador) para baixo, girando para dentro com 'roll'
	var palm := Vector3(0, 1, 0).rotated(fwd, -roll)
	palm = (palm - fwd * palm.dot(fwd)).normalized()
	var ext: float = clamp(1.0 - pos.distance_to(Vector3(-.11, -.06, -.6)) / .5, 0.0, 1.0)
	var fw: float = clamp(t / .05, 0.0, 1.0) * (1.0 - _sm((t - .9) / .08))
	return [Transform3D(Basis(fwd.cross(palm).normalized(), palm, -fwd).orthonormalized(), pos), ext, fw]

# ---------------- pose (animação) ----------------
var _last_recoil := 0.0
func _process(dt: float) -> void:
	# dedo no gatilho: puxa quando a arma dispara (o recuo sobe) e solta devagar
	if recoil > _last_recoil + .15: trig_v = 1.0
	_last_recoil = recoil
	trig_v = max(0.0, trig_v - dt * 5.0)
	if rev.is_empty(): return
	var p = G.player
	recoil *= exp(-dt * 9)
	hammer *= exp(-dt * 12)
	cd -= dt
	draw_t = min(1.0, draw_t + dt / .4)
	flash_t -= dt
	punch_t = min(1.0, punch_t + dt / .3)
	if flash_t <= 0:
		for k in IDS.size():
			var mm = model(k)
			if mm.has("fl"): mm.fl.visible = false
	vlight.light_energy *= exp(-dt * 30)
	if charging:
		charge = min(1.0, charge + dt / (1.1 if upg("rev", "fast") else 2.2))
		var pa = c_ang
		c_ang += dt * TAU * (1.3 + 5.2 * charge)
		if floor(pa / PI) != floor(c_ang / PI): G.snd("whirl", -10, 0.8 + charge * 0.8)
		if floor(pa / (TAU / 6)) != floor(c_ang / (TAU / 6)): G.snd("click", -20, G.rnd(.95, 1.1))
	if spin_t < 1:
		var pa = spin_angle()
		spin_t = min(1.0, spin_t + dt / spin_dur)
		var na = spin_angle()
		if cur == 0 and floor(pa / (TAU / 6)) != floor(na / (TAU / 6)): G.snd("click", -16)
		if floor(pa / PI) != floor(na / PI) and na - pa > .15: G.snd("whirl", -12)
		if spin_t >= 1: on_spin_end()
	if cur == 1 and pump_t < 1.2:
		var pv = pump_t
		pump_t += dt / .38
		if pv < 0 and pump_t >= 0: G.snd("pump", -6)
	_upd_sg_reload(dt)
	_upd_rev_reload(dt)
	for vp in vparts:
		vp.v.y -= 4 * dt
		vp.m.position += vp.v * dt
		vp.m.rotation.x += vp.spin * dt
		vp.life -= dt
		if vp.life <= 0: vp.m.queue_free()
	vparts = vparts.filter(func(x): return x.life > 0)
	if p == null: return
	var ks = 1.0 - exp(-10 * dt)
	sway.x += (clamp(-p.look_dx * .0004, -.05, .05) - sway.x) * ks
	sway.y += (clamp(p.look_dy * .0004, -.05, .05) - sway.y) * ks
	var hs = Vector2(p.velocity.x, p.velocity.z).length()
	var grounded: bool = p.is_on_floor() and not p.sliding and p.dash_t <= 0
	if grounded: bob_ph += dt * hs * .55
	bob_a += ((min(1.0, hs / 16.0) if grounded else 0.0) - bob_a) * ks
	tilt += ((-.35 if p.sliding else 0.0) - p.strafe * .05 + (.12 if p.dash_t > 0 else 0.0) - tilt) * ks
	var bx = sin(bob_ph) * .012 * bob_a
	var by = -abs(cos(bob_ph)) * .014 * bob_a
	var air = 0.0 if p.is_on_floor() else clamp(-p.velocity.y / 30.0, -1.0, 1.0) * .02
	var s = spin_t
	var ang = spin_angle() if s < 1 else 0.0
	var lift = sin(PI * s) if s < 1 else 0.0
	var de = ease_out(draw_t)
	var w = W()
	var R: Vector3 = w.rest
	var toss = lift * spin_toss
	var cl = .5 + .5 * charge if charging else 0.0
	w.root.position = Vector3(R.x + bx + sway.x - lift * .02, R.y + by + sway.y - (1 - de) * .32 + lift * .05 + toss * .16 + cl * .03 - p.land * .05 + air, R.z + recoil * w.kz - toss * .5)
	# three.js usa ordem XYZ nos ângulos; reproduzimos com Basis
	var rot = Vector3(recoil * w.kr + sway.y * 2 + lift * .12, -sway.x * 2 + lift * .08, tilt + lift * w.lr + cl * .3)
	if cur >= 2:
		w.pivot.rotation = Vector3(ang, 0, 0)
	if cur == 0:
		rb += ((1.0 if rv_reloading else 0.0) - rb) * (1.0 - exp(-12 * dt))
		var tcl = .42 + rv_max * .09 - .07
		var open = 0.0
		if rv_reloading and rev.has("pistol"):
			# pente some para baixo (já caiu) e um novo sobe até encaixar
			if rv_t < .18: open = 0.0
			elif rv_t < .46: open = 1.0
			elif rv_t < .7: open = 1.0 - _sm((rv_t - .46) / .24)
			else: open = 0.0
		elif rv_reloading:
			if rv_t < .3: open = ease_out(min(1.0, rv_t / .28))
			elif rv_t < tcl: open = 1.0
			else: open = 1.0 - clamp((rv_t - tcl) / .12, 0.0, 1.0)
		var pr = rev.has("pistol")
		if pr:
			# fase do ferrolho: a arma desce e deita para a esquerda, perto da mão de apoio
			var rkw = 0.0
			if rv_reloading: rkw = _sm((rv_t - .72) / .1) * (1.0 - _sm((rv_t - .93) / .18))
			rot += Vector3(rb * .42 - rkw * .3, rb * .3 + rkw * .15, -rb * .28 + rkw * .55)
			w.root.position += Vector3(-rb * .07 - rkw * .03, rb * .13 - rkw * .14, rb * .02 - rkw * .02)
		else:
			rot += Vector3(rb * .4, rb * .25, rb * .95)
			w.root.position += Vector3(-rb * .06, rb * .05, 0)
		rev.drum.position = rev.drum_base + rev.drum_open * open
		rev.steel.emission = Color(.25, .9, 1.0) * (charge * 1.2 if charging else 0.0)
		# no giro a pistola deita de lado sobre a palma e roda em volta do eixo vertical
		var sa: float = c_ang if charging else ang
		rev.pivot.rotation = Vector3(sa, 0, 0)
		rev.hammer.rotation.x = .6 * (1 - hammer)
		drum_a += (drum_t - drum_a) * (1.0 - exp(-25 * dt))
		if rev.has("pistol"):
			rev.drum.visible = rv_reloading and rv_t >= .42
			rack = 0.0
			if rv_reloading:
				if rv_t >= .8 and rv_t < .88: rack = _sm((rv_t - .8) / .08)
				elif rv_t >= .88 and rv_t < .9: rack = 1.0
			if rev.has("slide"): rev.slide.position = rev.slide_base + Vector3(0, 0, .055 * max(hammer, rack))
			var tw: float = 0.0
			if rv_reloading: tw = _sm(rv_t / .14) * (1.0 - _sm((rv_t - .95) / .2))
			rl_w = tw
			# giro no dedo (floreio, fim de troca e carga do ricochete)
			var spinning: bool = (s < 1 or charging) and not rv_reloading
			spin_w += ((1.0 if spinning else 0.0) - spin_w) * (1.0 - exp(-(16.0 if spinning else 9.0) * dt))
			if spin_r:
				# dedos para cima, palma virada para a arma (esquerda): o indicador dobrado aponta para ela
				# dedos inclinados 60° para a frente e a mão deitada um pouco para a direita
				var fd := Vector3(.28, .5, -.866).normalized()
				var palm := Vector3(-1, .4, .1)
				palm = (palm - fd * palm.dot(fd)).normalized()
				# a mão acompanha o giro como no vídeo: o pulso dá um tranco a cada volta,
				# a mão sobe e desce num pequeno círculo e gira um pouco em volta do dedo
				var sa2: float = c_ang if charging else ang
				var ph := sa2 + .6
				var hb := Basis(fd.cross(palm).normalized(), palm, -fd).orthonormalized()
				hb = Basis(Vector3(1, 0, 0), sin(ph) * .32) * Basis(Vector3(0, 0, 1), sin(ph * 2.0) * .06) * hb
				var hp := SPIN_HAND + Vector3(bx + sway.x, by + sway.y, 0)
				hp += Vector3(sin(ph) * .012, cos(ph) * .03 + lift * .05, sin(ph) * .025)
				spin_r.transform = Transform3D(hb, hp)
			if rl_marker and rv_reloading:
				var ps = _pistol_reload_pose(rv_t)
				var fwd: Vector3 = ps[2]
				var palm: Vector3 = (ps[1] - fwd * ps[1].dot(fwd)).normalized()
				rl_marker.transform = Transform3D(Basis(fwd.cross(palm).normalized(), palm, -fwd).orthonormalized(), ps[0])
		else:
			rev.drum.rotation.z = drum_a
		glow_mat.albedo_color.a = charge if charging else 0.0
		if charging:
			w.root.position += Vector3(G.rnd(-1, 1), G.rnd(-1, 1), 0) * .003 * charge
	elif cur == 1:
		var u: float = clamp(pump_t, 0.0, 1.0)
		var pm = sin(u * PI)
		sg.pump.position.z = -.3 + pm * .13
		rot += Vector3(pm * .08, 0, pm * .22)
		sb += ((1.0 if sg_reloading else 0.0) - sb) * (1.0 - exp(-11 * dt))
		# recarga: a escopeta deita para a direita, mostrando a janela de carga para a mão esquerda
		w.root.position += Vector3(-sb * .07, sb * .1, sb * .07)
		rot += Vector3(sb * .3, sb * .32, -sb * .6)
		sg.pivot.rotation = Vector3(ang if spin_axis == "x" else 0.0, 0, (ang if spin_axis == "z" else 0.0) - (1 - de) * TAU)
		sg.left.visible = s >= 1 and de > .85 and sb < .3
		var LH: Node3D = sg.load_hand
		LH.visible = sg_reloading
		if LH.visible:
			var v = sg_t / sg_lt() if sg_phase == "load" else 0.0
			# busca o cartucho embaixo, leva até a janela e empurra para dentro
			var k = _sm(v / .4) if v < .4 else (1.0 if v < .62 else 1.0 - _sm((v - .62) / .38))
			var push = 0.0 if v < .4 else (_sm((v - .4) / .2) if v < .6 else 1.0)
			LH.position = Vector3(-.07 + .07 * k, -.24 + .15 * k + .015 * push, .15 - .02 * k - .075 * push * k)
			LH.rotation = Vector3(-.35 * (1 - k), .25 * (1 - k), .2 * (1 - k))
			sg.shell.visible = sg_phase == "load" and (v < .58 or v > .8)
	rot = X.pose(IDS[cur], w, dt, rot, Time.get_ticks_msec() / 1000.0)
	w.root.basis = Basis.from_euler(rot, EULER_ORDER_XYZ)
	# no giro, o guarda-mato da pistola fica preso ao indicador da mão aberta
	if cur == 0 and spin_w > .001 and arms_ik and arms_ik.index_ok:
		var pg: Vector3 = rev.pivot.global_position
		w.root.global_position += (arms_ik.index_pt - pg) * clamp(spin_w * 1.4, 0.0, 1.0)
	# jab com o braço inteiro: sobe, estica, recolhe para a guarda, segura e desce
	var ext = 0.0
	if jab_t >= 0.0:
		jab_t += dt
		var jp = _jab_pose(jab_t)
		fist.transform = jp[0]
		ext = jp[1]
		jab_fw = jp[2]
		if jab_t >= JAB_END: jab_t = -1.0
	fist.visible = jab_t >= 0.0
	w.root.position.y -= ext * .03
	if self.R and self.R.cur != "":
		fist.visible = false
		w.root.visible = false
		self.R.process(dt)
