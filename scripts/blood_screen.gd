extends Control
## Sangue espirrado na tela quando um inimigo estoura: manchas irregulares, gotas e filetes
## que escorrem e somem aos poucos.

var splats: Array = []
const MAX := 26

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## k: intensidade (0.25 longe … 1.2 colado no inimigo)
func add(k: float) -> void:
	var n: int = 1 + int(k * 2.0)
	var sz := size if size.x > 10 else Vector2(1280, 720)
	for i in n:
		# mais nas bordas, menos no meio (não tapa a mira)
		var a = randf() * TAU
		var r = randf_range(.32, .62)
		var p = sz * .5 + Vector2(cos(a) * sz.x * r, sin(a) * sz.y * r * .9)
		var rad = randf_range(35, 95) * (.6 + k * .5) * sz.y / 720.0
		var blobs = []
		for j in 9:
			var bo = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * rad * .7
			blobs.append([bo, rad * randf_range(.25, .6)])
		var drops = []
		for j in 10:
			var da = randf() * TAU
			drops.append([Vector2(cos(da), sin(da)) * rad * randf_range(1.0, 2.2), rad * randf_range(.04, .13)])
		var drips = []
		for j in randi_range(1, 4):
			drips.append({"x": randf_range(-rad * .6, rad * .6), "len": 0.0, "max": randf_range(rad * .8, rad * 3.0), "w": rad * randf_range(.08, .16), "spd": randf_range(30, 80) * sz.y / 720.0})
		splats.append({"p": p, "blobs": blobs, "drops": drops, "drips": drips, "t": 0.0, "life": randf_range(2.2, 3.4), "rad": rad, "col": Color(randf_range(.45, .62), .0, .02)})
	while splats.size() > MAX: splats.pop_front()

func clear() -> void:
	splats.clear()
	queue_redraw()

func _process(dt: float) -> void:
	if splats.is_empty():
		return
	for s in splats:
		s.t += dt
		for d in s.drips:
			d.len = min(d.max, d.len + d.spd * dt)
	splats = splats.filter(func(s): return s.t < s.life)
	queue_redraw() # redesenha também quando a última mancha some

func _draw() -> void:
	for s in splats:
		var a: float = 1.0
		if s.t < .06: a = s.t / .06
		var fade = clamp((s.life - s.t) / 1.0, 0.0, 1.0)
		a *= fade * .92
		var c: Color = s.col
		c.a = a
		var dark = Color(c.r * .45, 0, 0, a)
		# sombra escura por baixo, depois a mancha
		for b in s.blobs: draw_circle(s.p + b[0] + Vector2(2, 3), b[1] * 1.08, Color(dark, a * .7))
		for b in s.blobs: draw_circle(s.p + b[0], b[1], c)
		for d in s.drops: draw_circle(s.p + d[0], d[1], c)
		for d in s.drips:
			var x0: Vector2 = s.p + Vector2(d.x, s.rad * .2)
			draw_line(x0, x0 + Vector2(0, d.len), c, d.w)
			draw_circle(x0 + Vector2(0, d.len), d.w * .75, c)
		# brilho úmido
		var hl = s.blobs[0]
		draw_circle(s.p + hl[0] + Vector2(-hl[1] * .3, -hl[1] * .3), hl[1] * .22, Color(1, .6, .55, a * .25))
