extends Control
# Barra de vida dos chefes: moldura com segmentos, pontas curvas, ornamento no topo e nome
# estilizado acima. Cada chefe tem o seu modelo (Deus: púrpura, espinhos, olho coroado e sangue
# pingando; Gabriel: marfim e ouro, asas abertas, auréola e espada).

const W := 820.0
const BAR_Y := 98.0
const BAR_H := 22.0

var kind := "deus"
var hp := 1.0
var dmg := 1.0
var t := 0.0
var f_name: Font
var f_sub: Font
var drops = []
var _last_hp := 1.0
var hit := 0.0

const THEMES := {
	"deus": {
		"name": "DEUS", "sub": "SENHOR DO TRONO DE CINZA E OURO",
		"frame": Color("2a1430"), "edge": Color("0e0510"), "hi": Color("6a3a7a"),
		"cell": Color("120610"), "fill": Color("c0141c"), "fill_hi": Color("ff5a4a"),
		"ghost": Color("f0c0b0"), "orn": Color("0c040e"), "orn2": Color("d9a441"),
		"name_col": Color("f2e6d6"), "name_edge": Color("5a0a12"), "sub_col": Color("c9a06a"),
	},
	"azazel": {
		"name": "AZAZEL", "sub": "O VIGIA DA TEMPESTADE",
		"frame": Color("10141e"), "edge": Color("03040a"), "hi": Color("5a7aa8"),
		"cell": Color("070a12"), "fill": Color("3a8ae0"), "fill_hi": Color("bfe6ff"),
		"ghost": Color("e0f0ff"), "orn": Color("d8d4cc"), "orn2": Color("7ac8ff"),
		"name_col": Color("e8f0ff"), "name_edge": Color("0a1428"), "sub_col": Color("8ab0e0"),
	},
	"lilith": {
		"name": "LILITH", "sub": "A RAINHA DO ABISMO",
		"frame": Color("1a0606"), "edge": Color("040000"), "hi": Color("a02a1a"),
		"cell": Color("0c0202"), "fill": Color("e0300a"), "fill_hi": Color("ffb040"),
		"ghost": Color("ffd0a0"), "orn": Color("120404"), "orn2": Color("ff4a14"),
		"name_col": Color("ffd8c8"), "name_edge": Color("6a0a02"), "sub_col": Color("ff8a5a"),
	},
	"miguel": {
		"name": "MIGUEL", "sub": "O ARCANJO VELADO",
		"frame": Color("1c1824"), "edge": Color("050407"), "hi": Color("8a7aa0"),
		"cell": Color("0b0910"), "fill": Color("a8101c"), "fill_hi": Color("ff6050"),
		"ghost": Color("c8b8e8"), "orn": Color("d8cfc4"), "orn2": Color("c89a3a"),
		"name_col": Color("e8e0f0"), "name_edge": Color("2a0610"), "sub_col": Color("a898c8"),
	},
	"gabriel": {
		"name": "GABRIEL", "sub": "ARCANJO DA IRA DIVINA",
		"frame": Color("e6dccb"), "edge": Color("3a2a1a"), "hi": Color("ffffff"),
		"cell": Color("2a1c14"), "fill": Color("c81e1e"), "fill_hi": Color("ffd27a"),
		"ghost": Color("ffe9a8"), "orn": Color("f4eee2"), "orn2": Color("d9a441"),
		"name_col": Color("fff6e0"), "name_edge": Color("8a6a20"), "sub_col": Color("e8c878"),
	},
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_name = load("res://fontes_ui/cinzel_decorative_900.woff2") if ResourceLoader.exists("res://fontes_ui/cinzel_decorative_900.woff2") else ThemeDB.fallback_font
	f_sub = load("res://fontes_ui/cinzel_700.woff2") if ResourceLoader.exists("res://fontes_ui/cinzel_700.woff2") else ThemeDB.fallback_font

func set_boss(k: String) -> void:
	kind = k if THEMES.has(k) else "deus"
	drops.clear()

func set_hp(v: float, ghost: float) -> void:
	if v < _last_hp - .001: hit = 1.0
	_last_hp = v
	hp = clampf(v, 0.0, 1.0)
	dmg = clampf(ghost, 0.0, 1.0)

func _process(dt: float) -> void:
	if not visible: return
	t += dt
	hit = max(0.0, hit - dt * 3.0)
	# sangue pingando da barra (Deus)
	if (kind == "deus" or kind == "lilith") and randf() < dt * 6.0 and hp > 0:
		var x0 := (size.x - W) * .5 + 40
		drops.append({"x": x0 + randf() * (W - 80) * hp, "y": BAR_Y + BAR_H * .5 + 6, "v": 0.0, "l": 1.0, "r": randf_range(1.5, 3.0)})
	for d in drops:
		d.v += 260.0 * dt
		d.y += d.v * dt
		d.l -= dt * 1.4
	drops = drops.filter(func(d): return d.l > 0)
	queue_redraw()

# ---------- auxiliares ----------
func _spaced(f: Font, center: Vector2, s: String, sz: int, col: Color, sp: float, outline: Color, ow: int) -> void:
	var total := 0.0
	var ws = []
	for ch in s:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		ws.append(w); total += w + sp
	total -= sp
	var x := center.x - total * .5
	for i in s.length():
		var ch: String = s[i]
		if ow > 0: draw_string_outline(f, Vector2(x, center.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ow, outline)
		draw_string(f, Vector2(x, center.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		x += ws[i] + sp

func _capsule(r: Rect2, col: Color) -> void:
	var rad := r.size.y * .5
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2, r.size.y), col)
	draw_circle(r.position + Vector2(rad, rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)

func _hook(p: Vector2, dir: float, col: Color, edge: Color, th: Dictionary) -> void:
	# ponta curva nas extremidades (como uma garra virada para dentro)
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var a := PI * .5 + i / float(n) * PI * 1.25
		var rr := 15.0 - i * .55
		pts.append(p + Vector2(cos(a) * rr * dir, sin(a) * rr))
	for i in range(n, -1, -1):
		var a := PI * .5 + i / float(n) * PI * 1.25
		var rr := 7.0 - i * .3
		pts.append(p + Vector2(cos(a) * rr * dir, sin(a) * rr))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, edge, 2.0, true)
	draw_circle(p + Vector2(-4 * dir, 0), 3.0, th.orn2)

func _feather(base: Vector2, ang: float, ln: float, wd: float, col: Color, edge: Color) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([base - nrm * wd * .3, base + d * ln * .55 - nrm * wd, base + d * ln, base + d * ln * .55 + nrm * wd, base + nrm * wd * .3])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, edge, 1.2, true)
	draw_line(base, base + d * ln * .9, Color(edge, .5), 1.0)

# ---------- ornamentos por chefe ----------
func _orn_deus(c: Vector2, th: Dictionary) -> void:
	# espinhos negros abertos como asas (como na referência), olho coroado com raios
	var col: Color = th.orn
	for s in [-1, 1]:
		for i in 9:
			var a: float = -PI * .5 + s * (.35 + i * .16)
			var ln := 26.0 + (i % 3) * 9.0 + (8 - i) * 2.0
			var d := Vector2(cos(a), sin(a))
			var b: Vector2 = c + Vector2(s * (8 + i * 4), 6)
			var nrm := Vector2(-d.y, d.x) * 4.0
			draw_colored_polygon(PackedVector2Array([b - nrm, b + d * ln, b + nrm]), col)
		# franja de espinhos por baixo da barra
		for i in 7:
			var b2: Vector2 = c + Vector2(s * (14 + i * 9), 30)
			draw_colored_polygon(PackedVector2Array([b2 + Vector2(-4, 0), b2 + Vector2(0, 10 + (i % 2) * 7), b2 + Vector2(4, 0)]), col)
	# raios dourados
	for i in 13:
		var a := PI + i / 12.0 * PI
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 18, c + d * (30 + (i % 2) * 8), Color(th.orn2, .8), 2.0, true)
	# coroa
	var cr := PackedVector2Array([c + Vector2(-14, -10), c + Vector2(-14, -22), c + Vector2(-7, -15), c + Vector2(0, -27), c + Vector2(7, -15), c + Vector2(14, -22), c + Vector2(14, -10)])
	draw_colored_polygon(cr, th.orn2)
	# olho
	draw_circle(c + Vector2(0, 2), 15, col)
	var eye := PackedVector2Array()
	for i in 24:
		var a := i / 24.0 * TAU
		eye.append(c + Vector2(0, 2) + Vector2(cos(a) * 12, sin(a) * 6.5))
	draw_colored_polygon(eye, Color("f2e6d6"))
	var blink := .5 + .5 * sin(t * 2.0)
	draw_circle(c + Vector2(sin(t * .8) * 3, 2), 4.5, Color(.7, .02, .05).lerp(Color(1, .2, .1), blink * hit))
	draw_circle(c + Vector2(sin(t * .8) * 3, 2), 1.8, Color.BLACK)
	# lágrima de sangue
	draw_line(c + Vector2(0, 9), c + Vector2(0, 22 + sin(t * 3) * 2), Color(.7, .02, .05), 2.5)

func _orn_azazel(c: Vector2, th: Dictionary) -> void:
	var bone: Color = th.orn
	var el: Color = th.orn2
	var red: bool = G.boss != null and G.boss.get("ph2") == true
	if red: el = Color(1, .2, .1)
	# asas de penas em leque dos dois lados
	for s in [-1, 1]:
		for k in 6:
			var a: float = -PI * .5 + s * (.35 + k * .2)
			var ln: float = 54.0 - k * 5.0 + sin(t * 2.4 + k * .7) * 3.0
			var p0 := c + Vector2(s * 10, 0)
			var p1 := p0 + Vector2(cos(a) * ln * (1 if s > 0 else 1), sin(a) * ln) * Vector2(1, .55)
			draw_line(p0, p1, bone, 3.0 - k * .3)
			draw_circle(p1, 2.0, bone)
	# coroa de anéis
	draw_arc(c + Vector2(0, -16), 13, 0, TAU, 32, bone, 1.6)
	draw_arc(c + Vector2(0, -16), 9, 0, TAU, 32, el, 1.0)
	# olho central que pisca
	var bl: float = clampf(sin(t * 1.3) * 8.0 - 7.0, 0.0, 1.0)
	var hh: float = 7.0 * (1.0 - bl)
	var pts := PackedVector2Array()
	for i in 13:
		var u: float = float(i) / 12.0
		pts.append(c + Vector2(lerp(-16.0, 16.0, u), -sin(u * PI) * hh))
	for i in range(11, 0, -1):
		var u: float = float(i) / 12.0
		pts.append(c + Vector2(lerp(-16.0, 16.0, u), sin(u * PI) * hh))
	if hh > .5:
		draw_colored_polygon(pts, Color(.92, .9, .86))
		draw_circle(c, min(5.5, hh), el)
		draw_circle(c, min(2.2, hh), Color.BLACK)
	draw_line(c + Vector2(-16, 0), c + Vector2(16, 0), bone, 1.4)
	# lágrimas de sangue na segunda fase
	if red:
		for s in [-1, 1]:
			draw_line(c + Vector2(s * 6, 5), c + Vector2(s * 7, 22 + sin(t * 3 + s) * 2), Color(.7, .02, .05), 2.5)

func _orn_lilith(c: Vector2, th: Dictionary) -> void:
	var dark: Color = th.orn
	var fire: Color = th.orn2
	# asas de morcego com membrana e ossos
	for s in [-1, 1]:
		var tips: Array = []
		for k in 4:
			var a: float = -PI * .5 + s * (.5 + k * .32)
			var ln: float = 58.0 - k * 7.0 + sin(t * 2.0 + k) * 2.0
			tips.append(c + Vector2(cos(a) * ln * s * s, sin(a) * ln) + Vector2(s * 6, 4))
		var mem := PackedVector2Array([c + Vector2(s * 6, 4)])
		for k in tips.size():
			mem.append(tips[k])
			if k < tips.size() - 1:
				var mid: Vector2 = (tips[k] + tips[k + 1]) * .5
				mem.append(mid.lerp(c + Vector2(s * 6, 4), .35))
		draw_colored_polygon(mem, Color(.45, .04, .03, .9))
		for tp in tips: draw_line(c + Vector2(s * 6, 4), tp, dark, 2.5, true)
		draw_line(c + Vector2(s * 6, 4), tips[0], Color(fire, .7), 1.0, true)
	# chifres
	for s in [-1, 1]:
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			pts.append(c + Vector2(s * (5 + u * 12 + sin(u * 3.0) * 4), -8 - u * 26))
		draw_polyline(pts, dark, 5.0 - 0.0, true)
		draw_polyline(pts, Color(fire, .5), 1.5, true)
	# cabeça e olhos em brasa
	draw_circle(c + Vector2(0, -4), 9, dark)
	var glow := .6 + .4 * sin(t * 6.0)
	for s in [-1, 1]:
		draw_circle(c + Vector2(s * 3.5, -5), 1.8, Color(1, .4, .1, glow))
	# cruz invertida em brasa
	draw_rect(Rect2(c + Vector2(-1.5, 8), Vector2(3, 22)), fire)
	draw_rect(Rect2(c + Vector2(-6, 22), Vector2(12, 3)), fire)
	# chamas lambendo a barra
	for i in 7:
		var x := (i - 3) * 10.0
		var hgt: float = 6.0 + 5.0 * abs(sin(t * 5.0 + i * 1.3))
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 4, 16), c + Vector2(x, 16 - hgt), c + Vector2(x + 4, 16)]), Color(1, .4 + .2 * sin(t * 7 + i), .05, .8))

func _orn_miguel(c: Vector2, th: Dictionary) -> void:
	var bone: Color = th.orn
	var gold: Color = th.orn2
	# asas de penas pálidas com olhos
	for s in [-1, 1]:
		for i in 6:
			var a: float = (PI if s < 0 else 0.0) + s * (-.75 + i * .2)
			_feather(c + Vector2(s * 8, 2), a, 44.0 - i * 3.0 + sin(t * 1.2 + i) * 1.2, 6.5, Color(bone, .92), Color(.25, .1, .1))
		for k in 2:
			var ep: Vector2 = c + Vector2(s * (26 + k * 13), -6 + k * 6)
			var blink: float = clampf(abs(sin(t * .9 + k * 1.7 + s)) * 3.0, 0.0, 1.0)
			var eye := PackedVector2Array()
			for j in 16:
				var a2 := j / 16.0 * TAU
				eye.append(ep + Vector2(cos(a2) * 5.0, sin(a2) * 2.8 * blink))
			draw_colored_polygon(eye, Color(.1, .02, .02))
			draw_circle(ep, 1.6 * blink, Color(1, .25, .15))
		# quatro braços com garras
		for k in 2:
			var b0: Vector2 = c + Vector2(s * 10, 14 + k * 9)
			var b1: Vector2 = b0 + Vector2(s * (30 + k * 6), 6 + k * 8)
			draw_line(b0, b1, Color(.75, .68, .62), 3.0, true)
			for f in 3:
				draw_line(b1, b1 + Vector2(s * (6 + f * 2), 3 + f * 3), Color(.75, .68, .62), 1.5, true)
	# auréola de raios
	var hc := c + Vector2(0, -12)
	for i in 12:
		var a3 := i / 12.0 * TAU + t * .2
		var ln := 22.0 if i % 2 == 0 else 15.0
		var d := Vector2(cos(a3), sin(a3))
		draw_colored_polygon(PackedVector2Array([hc + d * 11 + Vector2(-d.y, d.x) * 2.2, hc + d * ln, hc + d * 11 - Vector2(-d.y, d.x) * 2.2]), gold)
	draw_arc(hc, 11, 0, TAU, 32, gold, 2.5, true)
	# capuz/véu escuro com fenda vermelha
	draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -12), hc + Vector2(9, -2), hc + Vector2(8, 16), hc + Vector2(-8, 16), hc + Vector2(-9, -2)]), Color(.06, .04, .08))
	draw_line(hc + Vector2(-4, 2), hc + Vector2(4, 2), Color(1, .2, .15, .6 + .4 * sin(t * 4)), 2.0)

func _orn_gabriel(c: Vector2, th: Dictionary) -> void:
	var col: Color = th.orn
	var edge: Color = th.orn2
	# asas abertas
	for s in [-1, 1]:
		for i in 8:
			var a: float = (PI if s < 0 else 0.0) + s * (-.95 + i * .2)
			var ln := 50.0 - i * 3.5 + sin(t * 1.5 + i) * 1.5
			_feather(c + Vector2(s * 10, 4 + i * .5), a, ln, 6.0, col, edge)
		for i in 5:
			var a2: float = (PI if s < 0 else 0.0) + s * (-.5 + i * .22)
			_feather(c + Vector2(s * 8, 8), a2, 26.0, 5.0, Color(col, .95), Color(edge, .8))
	# auréola
	draw_arc(c + Vector2(0, -16), 15, 0, TAU, 40, Color(edge, .9), 3.0, true)
	draw_arc(c + Vector2(0, -16), 19, 0, TAU, 40, Color(edge, .25 + .2 * sin(t * 2)), 2.0, true)
	# espada descendo pela barra
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -4), c + Vector2(3, -4), c + Vector2(3, 36), c + Vector2(0, 44), c + Vector2(-3, 36)]), Color("f8f4ec"))
	draw_rect(Rect2(c + Vector2(-12, -6), Vector2(24, 4)), edge)
	draw_circle(c + Vector2(0, -10), 4, edge)

func _draw() -> void:
	var th: Dictionary = THEMES[kind]
	var x0 := (size.x - W) * .5
	var cx := size.x * .5
	var low := hp < .3
	var pulse := .5 + .5 * sin(t * 8.0)
	# nome
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * hit
	var ny := 44.0
	_spaced(f_name, Vector2(cx, ny) + shake + Vector2(2, 3), th.name, 40, Color(0, 0, 0, .6), 10.0, Color(0, 0, 0, 0), 0)
	_spaced(f_name, Vector2(cx, ny) + shake, th.name, 40, th.name_col, 10.0, th.name_edge, 6)
	var nw: float = f_name.get_string_size(th.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + th.name.length() * 10.0
	for s in [-1, 1]:
		var a: Vector2 = Vector2(cx + s * (nw * .5 + 16), ny - 13)
		var b: Vector2 = Vector2(cx + s * (nw * .5 + 150), ny - 13)
		draw_line(a, b, Color(th.orn2, .8), 2.0)
		draw_line(a + Vector2(0, 5), b - Vector2(s * 40, -5), Color(th.orn2, .35), 1.0)
		var dm: Vector2 = a + Vector2(s * 8, 0)
		draw_colored_polygon(PackedVector2Array([dm + Vector2(-6, 0), dm + Vector2(0, -6), dm + Vector2(6, 0), dm + Vector2(0, 6)]), th.orn2)
		draw_circle(b, 3, th.orn2)
	# barra
	var r := Rect2(x0, BAR_Y, W, BAR_H)
	_capsule(r.grow(5), th.edge)
	_capsule(r.grow(3), th.frame)
	draw_line(Vector2(x0 + 10, BAR_Y - 2), Vector2(x0 + W - 10, BAR_Y - 2), Color(th.hi, .5), 1.0)
	var inner := r.grow(-3)
	_capsule(inner, th.cell)
	var fw := inner.size.x
	if dmg > hp:
		_capsule(Rect2(inner.position, Vector2(max(inner.size.y, fw * dmg), inner.size.y)), th.ghost)
	if hp > 0:
		var fc: Color = th.fill
		if low: fc = fc.lerp(Color(1, .35, .25), pulse * .6)
		fc = fc.lerp(Color.WHITE, hit * .5)
		var fr := Rect2(inner.position, Vector2(max(inner.size.y, fw * hp), inner.size.y))
		_capsule(fr, fc)
		draw_rect(Rect2(fr.position + Vector2(6, 2), Vector2(max(0.0, fr.size.x - 12), 3)), Color(th.fill_hi, .55))
		draw_rect(Rect2(fr.position + Vector2(6, fr.size.y - 4), Vector2(max(0.0, fr.size.x - 12), 2)), Color(0, 0, 0, .3))
	# divisões em segmentos (10)
	for i in range(1, 10):
		var sx := inner.position.x + inner.size.x * i / 10.0
		draw_line(Vector2(sx, inner.position.y - 1), Vector2(sx, inner.end.y + 1), th.frame, 3.0)
		draw_line(Vector2(sx + 1.5, inner.position.y), Vector2(sx + 1.5, inner.end.y), Color(th.edge, .7), 1.0)
	# pontas curvas
	_hook(Vector2(x0 - 4, BAR_Y + BAR_H * .5), -1, th.frame, th.edge, th)
	_hook(Vector2(x0 + W + 4, BAR_Y + BAR_H * .5), 1, th.frame, th.edge, th)
	# sangue pingando
	for d in drops:
		draw_circle(Vector2(d.x, d.y), d.r, Color(.6, .02, .04, d.l))
		draw_line(Vector2(d.x, d.y - d.r * 3), Vector2(d.x, d.y), Color(.6, .02, .04, d.l * .6), d.r * .8)
	# ornamento central
	var oc := Vector2(cx, BAR_Y - 8)
	if kind == "gabriel": _orn_gabriel(oc, th)
	elif kind == "miguel": _orn_miguel(oc, th)
	elif kind == "lilith": _orn_lilith(oc, th)
	elif kind == "azazel": _orn_azazel(oc, th)
	else: _orn_deus(oc, th)
	# título abaixo da barra
	_spaced(f_sub, Vector2(cx, BAR_Y + BAR_H + 30), th.sub, 12, th.sub_col, 3.0, Color(0, 0, 0, .8), 3)
	# porcentagem discreta
	draw_string_outline(f_sub, Vector2(x0 + W - 60, BAR_Y + BAR_H + 22), "%d%%" % int(ceil(hp * 100)), HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, 3, Color(0, 0, 0, .8))
	draw_string(f_sub, Vector2(x0 + W - 60, BAR_Y + BAR_H + 22), "%d%%" % int(ceil(hp * 100)), HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(th.sub_col, .8))
