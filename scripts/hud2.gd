extends Control
# HUD do personagem: vitais (vida, estamina, dash) à esquerda e arsenal (modelo da arma,
# munição, carga, slots) à direita. Tudo desenhado por código no estilo do jogo: preto, ouro e sangue.

const GOLD := Color("d9a441")
const GOLD_D := Color("7a5a22")
const BLOOD := Color("d01a14")
const BLOOD_D := Color("3a0606")
const CYAN := Color("40e8ff")
const BONE := Color("efe3cf")
const PANEL := Color(.04, .01, .015, .62)

var font: Font
var vit: Control
var ars: Control
var st = {
	"hp": 100.0, "hp_ghost": 100.0, "stam": 3.0, "walls": 3,
	"wname": "PISTOLA", "ammo": 6, "max": 6, "kind": "bullet", "inf": false,
	"bar": 0.0, "bar_col": CYAN, "status": "", "reload": 0.0,
	"slots": [], "cur": 0, "keys": "",
}
var t := 0.0
var hurt := 0.0
var _last_hp := 100.0
# prévia 3D da arma
var pv_vp: SubViewport
var pv_tex: TextureRect
var pv_holder: Node3D
var pv_cam: Camera3D
var pv_id := ""
# frasco de sangue (munição)
var vial: Control
var v_lvl := .6
var v_wave := 0.0
var v_wave_v := 0.0
var v_bub: Array = []
var v_last := 120.0
var v_gain := 0.0
var v_drops: Array = []

func _ready() -> void:
	font = ThemeDB.fallback_font
	vit = Control.new()
	vit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vit.anchor_top = 1; vit.anchor_bottom = 1
	vit.offset_left = 16; vit.offset_right = 16 + 390
	vit.offset_top = -142; vit.offset_bottom = -12
	vit.draw.connect(_draw_vitals)
	add_child(vit)
	ars = Control.new()
	ars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ars.anchor_left = 1; ars.anchor_right = 1; ars.anchor_top = 1; ars.anchor_bottom = 1
	ars.offset_left = -16 - 420; ars.offset_right = -16
	ars.offset_top = -164; ars.offset_bottom = -12
	ars.draw.connect(_draw_arsenal)
	add_child(ars)
	vial = Control.new()
	vial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vial.anchor_left = 1; vial.anchor_right = 1; vial.anchor_top = 1; vial.anchor_bottom = 1
	vial.offset_left = -16 - 420 - 104; vial.offset_right = -16 - 420 - 8
	vial.offset_top = -236; vial.offset_bottom = -8
	vial.draw.connect(_draw_vial)
	add_child(vial)
	_build_preview()

func _build_preview() -> void:
	pv_vp = SubViewport.new()
	pv_vp.size = Vector2i(300, 150)
	pv_vp.own_world_3d = true
	pv_vp.transparent_bg = true
	pv_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pv_vp)
	pv_cam = Camera3D.new()
	pv_cam.fov = 30
	pv_cam.position = Vector3(0, 0, 2)
	pv_vp.add_child(pv_cam)
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8a894")
	env.ambient_light_energy = .8
	var we = WorldEnvironment.new()
	we.environment = env
	pv_vp.add_child(we)
	var l1 = DirectionalLight3D.new()
	l1.rotation = Vector3(-.6, .7, 0)
	l1.light_energy = 1.2
	pv_vp.add_child(l1)
	var l2 = DirectionalLight3D.new()
	l2.rotation = Vector3(.3, -2.4, 0)
	l2.light_color = Color(1, .35, .2)
	l2.light_energy = .9
	pv_vp.add_child(l2)
	pv_holder = Node3D.new()
	pv_vp.add_child(pv_holder)
	pv_tex = TextureRect.new()
	pv_tex.texture = pv_vp.get_texture()
	pv_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pv_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pv_tex.position = Vector2(14, 10)
	pv_tex.size = Vector2(150, 75)
	ars.add_child(pv_tex)

# copia o modelo da arma atual para a prévia, de perfil
func set_preview(id: String, src: Node3D) -> void:
	if id == pv_id or src == null: return
	pv_id = id
	for c in pv_holder.get_children(): c.queue_free()
	var cp: Node3D = src.duplicate()
	cp.visible = true
	cp.transform = Transform3D.IDENTITY
	for n in cp.find_children("*", "Node3D", true, false):
		if n.name == "pivot" or n.get_parent() == cp: n.rotation = Vector3.ZERO
	pv_holder.add_child(cp)
	# só as malhas visíveis entram no enquadramento
	var bb := AABB()
	var first := true
	for m in cp.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null: continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var x := cp.global_transform.affine_inverse() * mi.global_transform
		var b2 := x * mi.get_aabb()
		if b2.size.length() > 3.0: continue
		if first: bb = b2; first = false
		else: bb = bb.merge(b2)
	if first: return
	# de lado: o cano aponta para a direita da tela
	pv_holder.rotation = Vector3(0, -PI / 2, 0)
	cp.position = -bb.get_center()
	var ext: float = max(bb.size.z, bb.size.y * 2.0, bb.size.x)
	pv_cam.position = Vector3(0, 0, ext * 1.75 + .04)

func push(d: Dictionary) -> void:
	for k in d: st[k] = d[k]

func _process(dt: float) -> void:
	t += dt
	var hp: float = st.hp
	if hp < _last_hp: hurt = 1.0
	_last_hp = hp
	hurt = max(0.0, hurt - dt * 2.5)
	st.hp_ghost = hp if st.hp_ghost < hp else lerp(float(st.hp_ghost), hp, 1.0 - exp(-dt * 2.2))
	pv_holder.rotation.y = -PI / 2 + sin(t * .7) * .25
	pv_holder.rotation.x = sin(t * .5) * .06
	vit.queue_redraw()
	ars.queue_redraw()
	# frasco: nível suave, líquido balança com o movimento e com a perda/ganho
	var bl: float = st.get("blood", 0.0)
	var tgt: float = bl / G.BLOOD_MAX
	if bl > v_last + .5:
		v_gain = 1.0
		v_wave_v += .8
		for i in 2: v_drops.append({"y": -10.0, "x": randf_range(-4, 4), "v": 0.0})
	elif bl < v_last - .3:
		v_wave_v -= .5
	v_last = bl
	v_lvl += (tgt - v_lvl) * (1.0 - exp(-dt * 6.0))
	var sway: float = 0.0
	if G.player: sway = clamp(G.player.look_dx * .02 + G.player.strafe * .3, -1.0, 1.0)
	v_wave_v += (-v_wave * 40.0 + sway * 6.0) * dt
	v_wave_v *= exp(-dt * 2.5)
	v_wave += v_wave_v * dt
	v_gain = max(0.0, v_gain - dt * 2.0)
	G.blood_flash = max(0.0, G.blood_flash - dt * 2.0)
	G.blood_empty = max(0.0, G.blood_empty - dt * 1.2)
	if randf() < dt * (3.0 + v_lvl * 8.0):
		v_bub.append({"x": randf_range(-18, 18), "y": 0.0, "r": randf_range(1.2, 3.0), "s": randf_range(18, 40)})
	for b in v_bub: b.y += b.s * dt
	v_bub = v_bub.filter(func(b): return b.y < 150.0 * v_lvl)
	for d in v_drops:
		d.v += 500 * dt
		d.y += d.v * dt
	v_drops = v_drops.filter(func(d): return d.y < 60)
	vial.queue_redraw()

# ---------- desenho ----------
func _slant(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color, sk := 10.0) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)]), col)

func _slant_line(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color, sk := 10.0, wd := 1.5) -> void:
	c.draw_polyline(PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x + sk, y)]), col, wd)

func _text(c: CanvasItem, p: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	c.draw_string_outline(font, p, s, align, w, size, 4, Color(0, 0, 0, .85))
	c.draw_string(font, p, s, align, w, size, col)

func _frame(c: CanvasItem, r: Rect2) -> void:
	# painel com cantos dourados
	_slant(c, r.position.x, r.position.y, r.size.x, r.size.y, PANEL, 14)
	_slant_line(c, r.position.x, r.position.y, r.size.x, r.size.y, Color(GOLD, .35), 14, 1.0)
	var k := 16.0
	var a := r.position + Vector2(14, 0)
	var b := r.position + Vector2(r.size.x, r.size.y)
	c.draw_polyline(PackedVector2Array([a + Vector2(0, k), a, a + Vector2(k + 6, 0)]), GOLD, 2.0)
	c.draw_polyline(PackedVector2Array([b - Vector2(0, k), b, b - Vector2(k + 6, 0)]), GOLD, 2.0)

func _sigil(c: CanvasItem, ctr: Vector2, r: float, col: Color, rot: float) -> void:
	# hexagrama dentro de um círculo
	c.draw_arc(ctr, r, 0, TAU, 48, Color(col, .9), 2.0, true)
	c.draw_arc(ctr, r - 6, 0, TAU, 48, Color(col, .35), 1.0, true)
	for s in 2:
		var pts = PackedVector2Array()
		for i in 4:
			var a = rot + s * PI / 3.0 + i * TAU / 3.0 - PI / 2
			pts.append(ctr + Vector2(cos(a), sin(a)) * (r - 6))
		c.draw_polyline(pts, Color(col, .55), 1.5, true)

func _draw_vitals() -> void:
	var c := vit
	var hp: float = clampf(st.hp, 0.0, 100.0)
	var low: bool = hp < 30
	var pulse := .5 + .5 * sin(t * 7.0)
	_frame(c, Rect2(0, 0, 370, 128))
	# emblema com o número da vida
	var ctr := Vector2(62, 64)
	var scol := BLOOD.lerp(Color.WHITE, hurt * .6)
	if low: scol = scol.lerp(Color(1, .3, .2), pulse)
	c.draw_circle(ctr, 44, Color(0, 0, 0, .55))
	c.draw_arc(ctr, 38, -PI / 2, -PI / 2 + TAU * hp / 100.0, 64, Color(scol, .95), 6.0, true)
	_sigil(c, ctr, 47, GOLD, t * .15)
	_text(c, ctr + Vector2(-60, 11), str(int(ceil(hp))), 32, BONE.lerp(Color(1, .4, .3), hurt), HORIZONTAL_ALIGNMENT_CENTER, 120)
	_text(c, ctr + Vector2(-60, 28), "VIDA", 10, Color(GOLD, .9), HORIZONTAL_ALIGNMENT_CENTER, 120)
	# barra de vida com rastro de dano
	var x0 := 118.0
	var bw := 232.0
	_text(c, Vector2(x0 + 10, 24), "VIDA", 11, Color(BONE, .8))
	_slant(c, x0, 29, bw, 16, BLOOD_D, 8)
	var gw := bw * clampf(float(st.hp_ghost) / 100.0, 0.0, 1.0)
	_slant(c, x0, 29, gw, 16, Color(1, .85, .7, .55), 8)
	var hw := bw * hp / 100.0
	if hw > 0: _slant(c, x0, 29, hw, 16, scol, 8)
	if hw > 0: _slant(c, x0 + 3, 31, max(0.0, hw - 6), 4, Color(1, 1, 1, .18), 8)
	for i in range(1, 10):
		var tx := x0 + bw * i / 10.0
		c.draw_line(Vector2(tx + 8, 29), Vector2(tx, 45), Color(0, 0, 0, .55), 2.0)
	_slant_line(c, x0, 29, bw, 16, Color(GOLD, .7), 8)
	# estamina (contínua) com os 3 dashes marcados
	var stam: float = clampf(st.stam, 0.0, 3.0)
	_text(c, Vector2(x0 + 6, 62), "ESTAMINA", 10, Color(BONE, .8))
	_slant(c, x0, 67, bw, 10, Color(.03, .12, .15, .9), 5)
	if stam > 0: _slant(c, x0, 67, bw * stam / 3.0, 10, CYAN.lerp(Color.WHITE, .15 if stam >= 3 else 0.0), 5)
	for i in range(1, 3):
		var tx := x0 + bw * i / 3.0
		c.draw_line(Vector2(tx + 5, 67), Vector2(tx, 77), Color(0, 0, 0, .8), 3.0)
	_slant_line(c, x0, 67, bw, 10, Color(GOLD, .45), 5, 1.0)
	# dash: losangos
	_text(c, Vector2(x0 + 2, 108), "DASH", 10, Color(BONE, .8))
	for i in 3:
		var p := Vector2(x0 + 58 + i * 30, 103)
		var f: float = clampf(stam - i, 0.0, 1.0)
		var dia := PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 0), p + Vector2(0, 12), p + Vector2(-12, 0)])
		c.draw_colored_polygon(dia, Color(.02, .08, .1, .9))
		if f >= 1.0:
			c.draw_colored_polygon(dia, CYAN)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), Color(1, 1, 1, .5))
		elif f > 0:
			# carregando: preenche de baixo para cima
			var hgt := 24.0 * f
			var yb := p.y + 12
			var poly := Geometry2D.intersect_polygons(dia, PackedVector2Array([Vector2(p.x - 13, yb - hgt), Vector2(p.x + 13, yb - hgt), Vector2(p.x + 13, yb), Vector2(p.x - 13, yb)]))
			for pg in poly: c.draw_colored_polygon(pg, Color(CYAN, .5))
		dia.append(dia[0])
		c.draw_polyline(dia, GOLD if f >= 1.0 else Color(GOLD, .4), 1.5)
	# saltos de parede
	_text(c, Vector2(x0 + 160, 108), "PAREDE", 10, Color(BONE, .6))
	for i in 3:
		var on: bool = i < int(st.walls)
		c.draw_rect(Rect2(x0 + 206 + i * 8, 97, 5, 12), GOLD if on else Color(GOLD, .2))

func _draw_arsenal() -> void:
	var c := ars
	_frame(c, Rect2(0, 0, 404, 152))
	# moldura da prévia do modelo
	var pr := Rect2(14, 10, 150, 75)
	c.draw_rect(pr, Color(0, 0, 0, .4))
	var k := 9.0
	for cor in [[pr.position, Vector2(1, 1)], [pr.position + Vector2(pr.size.x, 0), Vector2(-1, 1)], [pr.position + Vector2(0, pr.size.y), Vector2(1, -1)], [pr.end, Vector2(-1, -1)]]:
		var p: Vector2 = cor[0]; var d: Vector2 = cor[1]
		c.draw_polyline(PackedVector2Array([p + Vector2(0, k * d.y), p, p + Vector2(k * d.x, 0)]), GOLD, 2.0)
	# nome
	_text(c, Vector2(172, 28), st.wname, 19, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 220)
	c.draw_line(Vector2(200, 35), Vector2(392, 35), Color(GOLD, .5), 1.0)
	# munição
	var ammo: int = st.ammo
	var mx: int = st.max
	var low: bool = not st.inf and mx > 1 and ammo <= max(1, mx / 4)
	var acol := BONE
	if ammo == 0 and not st.inf: acol = Color(1, .25, .2).lerp(Color.WHITE, .5 + .5 * sin(t * 9))
	elif low: acol = Color("ffb060")
	if st.inf:
		if st.get("cost", 0.0) > 0:
			_text(c, Vector2(172, 74), str(st.get("shots", 0)), 40, BONE if st.get("shots", 0) > 0 else Color(1, .3, .25), HORIZONTAL_ALIGNMENT_RIGHT, 168)
			_text(c, Vector2(346, 74), "tiros", 13, Color(BONE, .55))
		else:
			_text(c, Vector2(172, 74), "∞", 36, BONE, HORIZONTAL_ALIGNMENT_RIGHT, 220)
	else:
		_text(c, Vector2(172, 74), str(ammo), 40, acol, HORIZONTAL_ALIGNMENT_RIGHT, 168)
		_text(c, Vector2(346, 74), "/ %d" % mx, 16, Color(BONE, .55))
	# ícones de munição (abaixo do número)
	if not st.inf and mx > 0:
		var n: int = min(mx, 12)
		var x := 392.0
		for i in range(n - 1, -1, -1):
			var on := i < ammo
			var a := 1.0 if on else .15
			match st.kind:
				"shell":
					x -= 11
					c.draw_rect(Rect2(x, 82, 8, 15), Color(BLOOD, a))
					c.draw_rect(Rect2(x, 93, 8, 4), Color(GOLD, a))
				"sword":
					x -= 11
					c.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 81), Vector2(x + 7, 93), Vector2(x + 1, 93)]), Color(Color("e8f4ff"), a))
					c.draw_rect(Rect2(x, 93, 8, 2), Color(GOLD, a))
					c.draw_rect(Rect2(x + 3, 95, 2, 4), Color(GOLD, a))
				"rocket":
					x -= 24
					c.draw_rect(Rect2(x, 85, 16, 9), Color(BLOOD, a))
					c.draw_colored_polygon(PackedVector2Array([Vector2(x + 16, 85), Vector2(x + 22, 89.5), Vector2(x + 16, 94)]), Color(GOLD, a))
				_:
					x -= 8
					c.draw_rect(Rect2(x, 86, 4, 12), Color(GOLD, a))
					c.draw_rect(Rect2(x, 82, 4, 4), Color(BONE, a))
	# barra de carga / calor sob a prévia
	var bar: float = st.bar
	_slant(c, 15, 92, 146, 6, Color(0, 0, 0, .6), 4)
	if bar > 0: _slant(c, 15, 92, 146 * clampf(bar, 0.0, 1.0), 6, st.bar_col, 4)
	# recarga / estado
	var rl: float = st.reload
	if rl > 0:
		_slant(c, 15, 104, 377, 4, Color(0, 0, 0, .6), 3)
		_slant(c, 15, 104, 377 * rl, 4, GOLD, 3)
		_text(c, Vector2(172, 120), "RECARREGANDO", 11, Color(GOLD, .6 + .4 * sin(t * 10)), HORIZONTAL_ALIGNMENT_RIGHT, 220)
	elif st.status != "":
		_text(c, Vector2(172, 120), st.status, 12, st.bar_col, HORIZONTAL_ALIGNMENT_RIGHT, 220)
	elif ammo == 0 and not st.inf:
		_text(c, Vector2(172, 120), "[R] RECARREGAR", 11, Color(1, .4, .3), HORIZONTAL_ALIGNMENT_RIGHT, 220)
	# slots
	var slots: Array = st.slots
	var sw := 44.0
	var sx := 404.0 - 10 - slots.size() * (sw + 3)
	for i in slots.size():
		var sd: Dictionary = slots[i]
		var r := Rect2(sx + i * (sw + 3), 124, sw, 20)
		var on: bool = sd.cur
		_slant(c, r.position.x, r.position.y, r.size.x, r.size.y, Color(GOLD, .9) if on else Color(0, 0, 0, .5), 4)
		_slant_line(c, r.position.x, r.position.y, r.size.x, r.size.y, Color(GOLD, .9 if on else .3), 4, 1.0)
		_text(c, r.position + Vector2(6, 15), str(i + 1), 9, Color.BLACK if on else Color(GOLD, .7))
		_text(c, r.position + Vector2(0, 15), sd.short, 11, Color.BLACK if on else Color(BONE, .75), HORIZONTAL_ALIGNMENT_RIGHT, sw - 2)


# ---------- frasco de sangue (munição) ----------
const VW := 96.0
func _vial_shape(cx: float, top: float, bot: float) -> PackedVector2Array:
	# ampola: gargalo estreito, ombro e um bulbo em gota
	var pts := PackedVector2Array()
	var neck := 9.0
	var bulb_r := 34.0
	var bulb_c := bot - bulb_r - 4
	pts.append(Vector2(cx - neck, top))
	pts.append(Vector2(cx - neck, top + 26))
	for i in 25:
		var a := PI * 1.3 - i / 24.0 * PI * 1.6
		var r := bulb_r
		pts.append(Vector2(cx + cos(a) * r * 1.0, bulb_c - sin(a) * r * 1.12))
	pts.append(Vector2(cx + neck, top + 26))
	pts.append(Vector2(cx + neck, top))
	return pts

func _draw_vial() -> void:
	var c := vial
	var cx := VW * .5
	var top := 34.0
	var bot := 196.0
	var shape := _vial_shape(cx, top, bot)
	var empty: bool = st.get("blood", 0.0) < 1.0
	var warn: float = G.blood_empty
	# brilho atrás
	var glow := Color(1, .1, .1, .12 + .25 * v_gain + .3 * warn * (.5 + .5 * sin(t * 20)))
	c.draw_circle(Vector2(cx, bot - 40), 54, Color(glow, glow.a * .5))
	c.draw_colored_polygon(shape, Color(.05, .0, .01, .75))
	# líquido: tudo da forma abaixo da superfície ondulada
	var ymin := top + 6.0
	var surf: float = lerp(bot - 4.0, ymin, clampf(v_lvl, 0.0, 1.0))
	if v_lvl > .003:
		var liq := PackedVector2Array()
		for i in 21:
			var x := cx - 50 + i * 5.0
			var y := surf + sin(i * .55 + t * 3.0) * 1.4 + (x - cx) * v_wave * .6
			liq.append(Vector2(x, y))
		liq.append(Vector2(cx + 50, bot + 10))
		liq.append(Vector2(cx - 50, bot + 10))
		var deep := Color(.32, 0, .02).lerp(Color(1, .5, .45), G.blood_flash * .5)
		var fresh := Color(.78, .03, .06).lerp(Color(1, .6, .55), G.blood_flash * .6)
		for pg in Geometry2D.intersect_polygons(shape, liq):
			c.draw_colored_polygon(pg, deep)
		# camada mais clara perto da superfície
		var band := PackedVector2Array()
		for i in 21:
			var x := cx - 50 + i * 5.0
			band.append(Vector2(x, surf + sin(i * .55 + t * 3.0) * 1.4 + (x - cx) * v_wave * .6))
		for i in range(20, -1, -1):
			var x := cx - 50 + i * 5.0
			band.append(Vector2(x, surf + 14 + sin(i * .4 + t * 2.0) * 2.0))
		for pg in Geometry2D.intersect_polygons(shape, band):
			c.draw_colored_polygon(pg, Color(fresh, .85))
		# bolhas
		for b in v_bub:
			var by: float = bot - 8 - b.y
			if by > surf + 3:
				c.draw_arc(Vector2(cx + b.x * (.4 + .6 * clampf((by - top) / (bot - top), 0.0, 1.0)), by), b.r, 0, TAU, 10, Color(1, .5, .45, .55), 1.0, true)
	# gotas entrando pelo gargalo
	for d in v_drops:
		c.draw_circle(Vector2(cx + d.x * .3, top + d.y), 2.6, Color(.9, .05, .08))
	# vidro: contorno e reflexos
	var outl := shape.duplicate()
	outl.append(shape[0])
	c.draw_polyline(outl, Color(1, .92, .85, .55), 2.0, true)
	c.draw_line(Vector2(cx - 18, bot - 70), Vector2(cx - 24, bot - 34), Color(1, 1, 1, .35), 3.0, true)
	c.draw_line(Vector2(cx - 5, top + 4), Vector2(cx - 5, top + 24), Color(1, 1, 1, .3), 2.0, true)
	# marcas de medida
	for i in range(1, 4):
		var y: float = lerp(bot - 4.0, ymin, i / 4.0)
		if y > top + 30: c.draw_line(Vector2(cx + 14, y), Vector2(cx + 22, y), Color(GOLD, .55), 1.5)
	# tampa dourada com coroa de espinhos
	c.draw_rect(Rect2(cx - 13, top - 8, 26, 9), GOLD)
	c.draw_rect(Rect2(cx - 13, top - 8, 26, 3), Color(1, .9, .6, .7))
	for i in 5:
		var x := cx - 12 + i * 6.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, top - 8), Vector2(x, top - 18 - (4 if i == 2 else 0)), Vector2(x + 2.5, top - 8)]), GOLD)
	# cruz invertida no topo
	c.draw_rect(Rect2(cx - 1.5, top - 34, 3, 14), GOLD)
	c.draw_rect(Rect2(cx - 5, top - 26, 10, 3), GOLD)
	# base
	c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 26, bot + 2), Vector2(cx + 26, bot + 2), Vector2(cx + 34, bot + 14), Vector2(cx - 34, bot + 14)]), GOLD_D)
	c.draw_line(Vector2(cx - 26, bot + 2), Vector2(cx + 26, bot + 2), GOLD, 2.0)
	# quantidade
	var bl: int = int(st.get("blood", 0.0))
	var tc := BONE.lerp(Color(1, .35, .3), clampf(G.blood_flash, 0.0, 1.0) * .6)
	if empty: tc = Color(1, .2, .15).lerp(Color.WHITE, .5 + .5 * sin(t * 10))
	_text(c, Vector2(0, bot - 26), str(bl), 22, tc, HORIZONTAL_ALIGNMENT_CENTER, VW)
	_text(c, Vector2(0, bot - 10), "SANGUE", 9, Color(GOLD, .9), HORIZONTAL_ALIGNMENT_CENTER, VW)
	if empty or warn > .05:
		_text(c, Vector2(-40, top - 40), "SEM SANGUE", 13, Color(1, .2, .15, max(warn, .5 + .5 * sin(t * 8))), HORIZONTAL_ALIGNMENT_CENTER, VW + 80)
