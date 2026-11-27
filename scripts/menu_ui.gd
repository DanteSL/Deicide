extends Control
## Menu principal e de pausa do Deicide, desenhado em código:
## catedral escura, raios de luz, auréola quebrada cheia de olhos, cinzas e sangue pingando.

const GOLD := Color("e0a83a")
const RED := Color("e8261a")
const PALE := Color("c9b2a6")
const DIM := Color("7d6a63")

const MODES := {
	"torre": ["A TORRE", "O começo de tudo. Um vale morto entre montanhas, uma ponte sobre o abismo e uma torre tão alta que some no vórtice negro — o único lugar onde ainda existe luz.", 3],
	"waves": ["ONDAS", "Hordas sem fim de anjos. A cada 5 ondas desce Gabriel; a cada 10, o próprio Deus.", 3],
	"train": ["TREINO", "Alvos que sempre voltam, e aqui você não morre. Teste as armas, as melhorias e a Blasfêmia.", 0],
	"boss": ["GABRIEL", "O Arauto de Muitos Olhos. Oito ataques e uma segunda fase de julgamento, no Átrio das Trombetas acima das nuvens.", 4],
	"lilith": ["LILITH", "A Rainha do Abismo: asas de morcego, garras e fogo, numa ilha de rocha cercada por um lago de lava.", 4],
	"azazel": ["AZAZEL", "O Vigia: um olho gigante de asas cobertas de olhos, que comanda os raios no Olho da Tempestade. Na metade da vida ele chora sangue.", 5],
	"miguel": ["MIGUEL", "O Arcanjo Velado: quatro braços, asas cheias de olhos e uma arena só dele sob o eclipse.", 4],
	"deus": ["DEUS", "O Criador em pessoa, coroado de mãos decepadas. Quando ele sangra, a arena afoga.", 5],
}
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

var main: Node
var paused := false
var t := 0.0
var ash: Array = []
var drips: Array = []
var eyes_blink: Array = []

var title_box: HBoxContainer
var tag: Label
var sub: Label
var list: VBoxContainer
var panel: PanelContainer
var pages = {}
var info = {}
var buttons: Array = []
var cont_btn: Button
var exit_btn: Button
var f_title: FontVariation
var f_wide: FontVariation
var f_deco: Font
var f_cin: Font
var left: VBoxContainer
var title_art: Control
var pause_head: Control
var blur: ColorRect
var deco: Control
var foot: Label
var hint: Label
var lay_tw: Tween
var t_drips: Array = []

## fundo da pausa: o jogo continua visível atrás, borrado e escurecido
const PAUSE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, 2.2 * amount).rgb;
	float g = dot(c, vec3(.3, .59, .11));
	c = mix(c, vec3(g) * vec3(1.05, .9, .85), .45);
	float v = smoothstep(.95, .2, length(uv - .5) * 1.3);
	c *= mix(.22, .5, v);
	COLOR = vec4(c, amount);
}
"""

func setup(m: Node) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	f_title = FontVariation.new()
	f_title.base_font = ThemeDB.fallback_font
	f_title.spacing_glyph = 14
	f_title.variation_embolden = .9
	f_wide = FontVariation.new()
	f_wide.base_font = ThemeDB.fallback_font
	f_wide.spacing_glyph = 5
	f_wide.variation_embolden = .35
	f_deco = load("res://fontes_ui/cinzel_decorative_900.woff2") if ResourceLoader.exists("res://fontes_ui/cinzel_decorative_900.woff2") else f_title
	f_cin = load("res://fontes_ui/cinzel_700.woff2") if ResourceLoader.exists("res://fontes_ui/cinzel_700.woff2") else f_wide
	for i in 70: ash.append(_new_ash(true))
	for i in 9: eyes_blink.append(randf() * 6.0)
	_build()

# ---------------- montagem ----------------
func _lbl(text: String, size: int, color: Color, font: Font = null, outline := 0) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font: l.add_theme_font_override("font", font)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build() -> void:
	# coluna da esquerda: título + lista
	# fundo borrado da pausa (fica atrás de tudo)
	blur = ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm = ShaderMaterial.new(); var bsh = Shader.new(); bsh.code = PAUSE_SHADER; bm.shader = bsh
	blur.material = bm
	blur.visible = false
	add_child(blur)
	deco = Control.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_pause_deco)
	add_child(deco)
	left = VBoxContainer.new()
	left.anchor_left = 0; left.anchor_top = 0; left.anchor_right = 0; left.anchor_bottom = 1
	left.offset_left = 86; left.offset_top = 70; left.offset_right = 640; left.offset_bottom = -40
	left.add_theme_constant_override("separation", 0)
	add_child(left)
	title_box = HBoxContainer.new()
	left.add_child(title_box)
	# título desenhado: letras góticas douradas, brilho de brasa, rachadura e sangue escorrendo
	title_art = Control.new()
	title_art.custom_minimum_size = Vector2(560, 150)
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_art.draw.connect(_draw_title)
	title_box.add_child(title_art)
	tag = _lbl("", 1, PALE)
	tag.visible = false
	left.add_child(tag)
	# cabeçalho da pausa
	pause_head = Control.new()
	pause_head.custom_minimum_size = Vector2(520, 120)
	pause_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_head.draw.connect(_draw_pause_head)
	pause_head.visible = false
	left.add_child(pause_head)
	var sp = Control.new(); sp.custom_minimum_size = Vector2(0, 4); left.add_child(sp)
	sub = _lbl("", 17, GOLD, f_wide)
	left.add_child(sub)
	var sp2 = Control.new(); sp2.custom_minimum_size = Vector2(0, 6); left.add_child(sp2)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	left.add_child(list)
	cont_btn = _entry("CONTINUAR", "", func(): main.resume(), "cont")
	_entry("A TORRE", "", func(): main.start_mode("torre"), "torre")
	_entry("ONDAS", "", func(): main.start_mode("waves"), "waves")
	_entry("TREINO", "", func(): main.start_mode("train"), "train")
	_entry("GABRIEL", "", func(): main.start_mode("boss"), "boss")
	_entry("MIGUEL", "", func(): main.start_mode("miguel"), "miguel")
	_entry("LILITH", "", func(): main.start_mode("lilith"), "lilith")
	_entry("AZAZEL", "", func(): main.start_mode("azazel"), "azazel")
	_entry("DEUS", "", func(): main.start_mode("deus"), "deus")
	var gap = Control.new(); gap.custom_minimum_size = Vector2(0, 6); list.add_child(gap)
	_entry("CONFIGURAÇÕES", "", func(): _show_page("cfg"), "cfg", true)
	_entry("CONTROLES", "", func(): _show_page("ctl"), "ctl", true)
	exit_btn = _entry("SAIR", "", func(): _exit(), "exit", true)
	_number_entries()
	# painel da direita
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(.045, .008, .012, .86)
	sb.border_color = Color(GOLD, .35)
	sb.border_width_left = 3
	sb.set_content_margin_all(26)
	sb.skew = Vector2(-.08, 0)
	sb.shadow_color = Color(0, 0, 0, .5)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_top = 1; panel.anchor_bottom = 1
	panel.offset_left = -560; panel.offset_right = -70; panel.offset_top = -350; panel.offset_bottom = -70
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var stack = VBoxContainer.new()
	panel.add_child(stack)
	pages.info = _page_info()
	pages.cfg = _page_cfg()
	pages.ctl = _page_ctl()
	for k in pages:
		stack.add_child(pages[k])
		pages[k].visible = k == "info"
	# rodapé
	foot = _lbl("DEICIDE  ·  GODOT 4.7  ·  github.com/DanteSL/Deicide", 12, DIM, f_wide)
	foot.anchor_top = 1; foot.anchor_bottom = 1
	foot.offset_left = 86; foot.offset_top = -40
	add_child(foot)
	hint = _lbl("MOUSE OU ↑ ↓  ·  ENTER", 12, DIM, f_wide)
	hint.anchor_left = 1; hint.anchor_right = 1; hint.anchor_top = 1; hint.anchor_bottom = 1
	hint.offset_left = -300; hint.offset_right = -70; hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)

func _tw() -> Tween:
	return create_tween().set_ignore_time_scale()

func _entry(text: String, _desc: String, cb: Callable, key: String, small := false) -> Button:
	var b = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", f_wide)
	b.add_theme_font_size_override("font_size", 22 if small else 32)
	b.add_theme_color_override("font_color", DIM if small else PALE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_hover_pressed_color", GOLD)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, .8))
	b.add_theme_constant_override("outline_size", 4)
	var st = StyleBoxEmpty.new()
	st.content_margin_left = 58
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	b.custom_minimum_size = Vector2(440, 33 if small else 44)
	b.set_meta("st", st)
	b.set_meta("key", key)
	b.set_meta("small", small)
	# faixa vermelha inclinada que cresce no foco
	var bar = Panel.new()
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(RED, .9)
	bs.skew = Vector2(-.45, 0)
	bar.add_theme_stylebox_override("panel", bs)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(30, 7)
	bar.size = Vector2(0, (44 if not small else 33) - 14)
	bar.show_behind_parent = true
	b.add_child(bar)
	b.set_meta("bar", bar)
	var num = _lbl("", 14 if small else 16, GOLD, f_wide)
	num.position = Vector2(0, 11 if not small else 8)
	b.add_child(num)
	b.set_meta("num", num)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(_on_focus.bind(b, true))
	b.focus_exited.connect(_on_focus.bind(b, false))
	b.pressed.connect(func():
		G.snd("click", -3, .8)
		cb.call())
	list.add_child(b)
	buttons.append(b)
	return b

func _number_entries() -> void:
	var i = 0
	for b in buttons:
		if not b.visible: continue
		b.get_meta("num").text = ROMAN[i] if i < ROMAN.size() else ""
		i += 1

func _on_focus(b: Button, on: bool) -> void:
	var st: StyleBoxEmpty = b.get_meta("st")
	var bar: Panel = b.get_meta("bar")
	var num: Label = b.get_meta("num")
	var tw = _tw().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "content_margin_left", 84.0 if on else 58.0, .16)
	var w = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	tw.tween_property(bar, "size:x", (w + 80.0) if on else 0.0, .2)
	tw.tween_property(num, "position:x", 8.0 if on else 0.0, .16)
	num.add_theme_color_override("font_color", Color.WHITE if on else GOLD)
	if on:
		G.snd("click", -16, 1.7)
		var k = b.get_meta("key")
		if MODES.has(k): _show_info(k)
		elif k == "cont": _show_info(G.mode)

func _show_page(k: String) -> void:
	for p in pages: pages[p].visible = p == k
	if paused:
		panel.visible = k != "info"
		# na pausa a coluna desliza para a esquerda para abrir espaço ao painel
		var off := -560.0 if k != "info" else -250.0
		if lay_tw: lay_tw.kill()
		lay_tw = _tw().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		lay_tw.tween_property(left, "offset_left", off, .25)
		lay_tw.tween_property(left, "offset_right", off + 500.0, .25)
	pages[k].modulate.a = 0
	_tw().tween_property(pages[k], "modulate:a", 1.0, .18)

func _page_info() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	info.cap = _lbl("MODO", 13, DIM, f_wide)
	v.add_child(info.cap)
	info.nm = _lbl("ONDAS", 44, GOLD, f_title, 6)
	v.add_child(info.nm)
	info.desc = _lbl("", 17, PALE)
	info.desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.desc.custom_minimum_size = Vector2(380, 0)
	v.add_child(info.desc)
	var sp = Control.new(); sp.custom_minimum_size = Vector2(0, 8); v.add_child(sp)
	var dh = HBoxContainer.new()
	dh.add_theme_constant_override("separation", 6)
	dh.add_child(_lbl("PERIGO", 13, DIM, f_wide))
	var gap = Control.new(); gap.custom_minimum_size = Vector2(10, 0); dh.add_child(gap)
	info.skulls = []
	for i in 5:
		var r = Panel.new()
		var s = StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, .12)
		s.skew = Vector2(-.4, 0)
		r.add_theme_stylebox_override("panel", s)
		r.custom_minimum_size = Vector2(26, 14)
		dh.add_child(r)
		info.skulls.append(s)
	v.add_child(dh)
	info.rec = _lbl("", 14, PALE, f_wide)
	v.add_child(info.rec)
	return v

func _show_info(k: String) -> void:
	if not MODES.has(k): return
	if not pages.info.visible: _show_page("info")
	var M = MODES[k]
	info.nm.text = M[0]
	info.desc.text = M[1]
	for i in 5:
		info.skulls[i].bg_color = (RED if M[2] >= 4 else GOLD) if i < M[2] else Color(1, 1, 1, .12)
	var r = G.rec.get(k, {})
	if r.is_empty():
		info.rec.text = "RECORDE  ·  —"
	elif k == "waves":
		info.rec.text = "RECORDE  ·  ONDA %d  ·  RANK %s" % [r.get("wave", 0), G.RANKS[int(r.get("rank", 0))][0]]
	else:
		info.rec.text = "RECORDE  ·  RANK %s  ·  %d ABATES" % [G.RANKS[int(r.get("rank", 0))][0], int(r.get("kills", 0))]
	info.nm.modulate.a = 0
	_tw().tween_property(info.nm, "modulate:a", 1.0, .15)

func _slider_theme(sl: HSlider) -> void:
	var track = StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, .1)
	track.content_margin_top = 3; track.content_margin_bottom = 3
	var fill = StyleBoxFlat.new()
	fill.bg_color = RED
	fill.content_margin_top = 3; fill.content_margin_bottom = 3
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	var fill2: StyleBoxFlat = fill.duplicate()
	fill2.bg_color = Color("ff4a3a")
	sl.add_theme_stylebox_override("grabber_area_highlight", fill2)
	var img = Image.create(14, 18, false, Image.FORMAT_RGBA8)
	img.fill(GOLD)
	var tex = ImageTexture.create_from_image(img)
	var img2 = Image.create(14, 18, false, Image.FORMAT_RGBA8)
	img2.fill(Color.WHITE)
	sl.add_theme_icon_override("grabber", tex)
	sl.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(img2))

var cfg_tabs = {}
var cfg_tab_btns = {}

func _page_cfg() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	for k in ["VÍDEO", "JOGO", "ÁUDIO"]:
		var b = Button.new()
		b.text = k
		b.flat = true
		b.add_theme_font_override("font", f_wide)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.pressed.connect(func(): _cfg_tab(k); G.snd("click", -10, 1.4))
		head.add_child(b)
		cfg_tab_btns[k] = b
	var sep = ColorRect.new(); sep.color = Color(GOLD, .25); sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)
	# --- vídeo
	var vid = VBoxContainer.new(); vid.add_theme_constant_override("separation", 7)
	var res_names = []
	for r in G.RES_LIST: res_names.append(r[0])
	var ss = DisplayServer.screen_get_size()
	res_names[0] = "Nativa (%d × %d)" % [ss.x, ss.y]
	vid.add_child(_choice("Modo de tela", G.WIN_MODES, func(): return G.win_mode, func(i): G.win_mode = i; main.apply_video()))
	vid.add_child(_choice("Resolução", res_names, func(): return G.res_i, func(i): G.res_i = i; main.apply_video()))
	vid.add_child(_choice("VSync", ["Desligado", "Ligado"], func(): return 1 if G.vsync else 0, func(i): G.vsync = i == 1; main.apply_video()))
	var fps_names = []
	for f in G.FPS_LIST: fps_names.append("Sem limite" if f == 0 else str(f))
	vid.add_child(_choice("Limite de FPS", fps_names, func(): return max(0, G.FPS_LIST.find(int(G.max_fps))), func(i): G.max_fps = G.FPS_LIST[i]; main.apply_video()))
	vid.add_child(_choice("Antisserrilhado", G.MSAA_LIST, func(): return G.msaa_i, func(i): G.msaa_i = i; main._apply_render()))
	var ui_names = ["Automático", "100%", "125%", "150%", "200%"]
	vid.add_child(_choice("Interface", ui_names, func(): return G.ui_i, func(i): G.ui_i = i; main._apply_render()))
	vid.add_child(_slider("Brilho", .6, 1.5, .05, "%d%%", func(): return G.bright, func(x): G.bright = x; main._apply_render(), 100.0))
	vid.add_child(_choice("Visual retrô", ["Desligado", "Ligado"], func(): return 1 if G.retro else 0, func(i): G.retro = i == 1; main._apply_settings()))
	vid.add_child(_choice("Mostrar FPS", ["Não", "Sim"], func(): return 1 if G.show_fps else 0, func(i): G.show_fps = i == 1; main._apply_render()))
	v.add_child(vid); cfg_tabs["VÍDEO"] = vid
	# --- jogo
	var jg = VBoxContainer.new(); jg.add_theme_constant_override("separation", 7)
	jg.add_child(_slider("Sensibilidade", .3, 3.0, .1, "%.1f×", func(): return G.sens_mult, func(x): G.sens_mult = x))
	jg.add_child(_choice("Inverter mouse", ["Não", "Sim"], func(): return 1 if G.invert_y else 0, func(i): G.invert_y = i == 1))
	jg.add_child(_slider("Campo de visão", 80, 130, 1, "%d°", func(): return G.fov_base, func(x): G.fov_base = x))
	jg.add_child(_slider("Tremor de tela", 0, 1.0, .05, "%d%%", func(): return G.shake_k, func(x): G.shake_k = x, 100.0))
	v.add_child(jg); cfg_tabs["JOGO"] = jg
	# --- áudio
	var au = VBoxContainer.new(); au.add_theme_constant_override("separation", 7)
	au.add_child(_slider("Volume geral", 0, 1.0, .01, "%d%%", func(): return G.vol, func(x): G.vol = x; G.apply_volume(), 100.0))
	au.add_child(_slider("Música", 0, 1.0, .01, "%d%%", func(): return G.mvol, func(x): G.mvol = x; G.apply_volume(), 100.0))
	au.add_child(_slider("Efeitos", 0, 1.0, .01, "%d%%", func(): return G.svol, func(x): G.svol = x; G.apply_volume(), 100.0))
	v.add_child(au); cfg_tabs["ÁUDIO"] = au
	_cfg_tab("VÍDEO")
	return v

func _cfg_tab(k: String) -> void:
	for t in cfg_tabs: cfg_tabs[t].visible = t == k
	for t in cfg_tab_btns: cfg_tab_btns[t].add_theme_color_override("font_color", GOLD if t == k else DIM)

func _row(label: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l = _lbl(label, 16, PALE)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	return h

## seletor ◀ valor ▶ (clique nas setas ou no valor)
func _choice(label: String, opts: Array, get_i: Callable, set_i: Callable) -> Control:
	var h = _row(label)
	var val = _lbl("", 16, GOLD)
	val.custom_minimum_size = Vector2(210, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upd = func(): val.text = str(opts[clamp(int(get_i.call()), 0, opts.size() - 1)])
	for d in [-1, 1]:
		var b = Button.new()
		b.text = "◀" if d < 0 else "▶"
		b.flat = true
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color(GOLD, .7))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func():
			var i = (int(get_i.call()) + d + opts.size()) % opts.size()
			set_i.call(i)
			upd.call()
			G.save()
			G.snd("click", -12, 1.5))
		if d < 0:
			h.add_child(b); h.add_child(val)
		else:
			h.add_child(b)
	upd.call()
	return h

func _slider(label: String, lo: float, hi: float, step: float, fmt: String, get_v: Callable, set_v: Callable, mul := 1.0) -> Control:
	var h = _row(label)
	var sl = HSlider.new()
	sl.min_value = lo; sl.max_value = hi; sl.step = step
	sl.value = float(get_v.call())
	sl.custom_minimum_size = Vector2(170, 26)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider_theme(sl)
	h.add_child(sl)
	var val = _lbl(fmt % (sl.value * mul), 15, GOLD, f_wide)
	val.custom_minimum_size = Vector2(60, 0)
	h.add_child(val)
	sl.value_changed.connect(func(x):
		set_v.call(x)
		val.text = fmt % (x * mul)
		G.save())
	sl.drag_ended.connect(func(_c): G.snd("click", -6))
	return h

func _page_ctl() -> Control:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_lbl("CONTROLES", 13, DIM, f_wide))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for c in [["Mover", "WASD"], ["Pular / parede", "ESPAÇO"], ["Dash", "SHIFT"], ["Deslizar / pisão", "C"],
		["Atirar", "MOUSE 1"], ["Especial", "MOUSE 2"], ["Soco / aparar", "F"], ["Girar / recarregar", "R"],
		["Trocar arma", "Q · 1–8"], ["Blasfêmia", "G"], ["Terminal", "E"], ["Pausar", "ESC"]]:
		var hb = HBoxContainer.new()
		hb.custom_minimum_size = Vector2(186, 0)
		hb.add_child(_lbl(c[0], 14, PALE))
		var s = Control.new(); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(s)
		hb.add_child(_lbl(c[1], 13, GOLD, f_wide))
		grid.add_child(hb)
	var tip = _lbl("O sangue cura: lute de perto. Esferas laranja podem ser devolvidas com F.", 13, DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(380, 0)
	v.add_child(tip)
	return v

# ---------------- abrir / sair ----------------
func open(is_paused: bool) -> void:
	paused = is_paused
	visible = true
	cont_btn.visible = paused
	exit_btn.text = "MENU PRINCIPAL" if paused else "SAIR"
	_number_entries()
	sub.text = ""
	sub.visible = false
	tag.visible = false
	title_box.visible = not paused
	pause_head.visible = paused
	blur.visible = paused
	foot.visible = not paused
	hint.visible = not paused
	if lay_tw: lay_tw.kill()
	for p in pages: pages[p].visible = p == "info"
	deco.queue_redraw()
	# pausa: coluna centralizada sobre o jogo borrado; menu principal: coluna à esquerda
	if paused:
		left.anchor_left = .5; left.anchor_right = .5
		left.offset_left = -250; left.offset_right = 250; left.offset_top = 40
		for b in buttons: b.custom_minimum_size.x = 500
	else:
		left.anchor_left = 0; left.anchor_right = 0
		left.offset_left = 86; left.offset_right = 640; left.offset_top = 28
		for b in buttons: b.custom_minimum_size.x = 440
	panel.visible = not paused
	panel.offset_left = -560; panel.offset_right = -70
	_show_info(G.mode if paused else "torre")
	# entrada animada
	modulate.a = 0
	_tw().tween_property(self, "modulate:a", 1.0, .25)
	var i = 0
	for b in buttons:
		if not b.visible: continue
		b.modulate.a = 0
		var tw = _tw().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(.04 * i)
		tw.tween_property(b, "modulate:a", 1.0, .2)
		i += 1
	var first: Button = cont_btn if paused else buttons[1]
	first.call_deferred("grab_focus")

func _exit() -> void:
	if paused: main.quit_to_menu()
	else: get_tree().quit()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible: return
	if ev.is_action_pressed("ui_cancel") and paused and not pages.info.visible:
		_show_page("info")
		get_viewport().set_input_as_handled()
		return
	if ev.is_action_pressed("ui_cancel") and not paused and not pages.info.visible:
		_show_info("torre")
		get_viewport().set_input_as_handled()

# ---------------- arte do fundo ----------------
func _new_ash(anywhere := false) -> Dictionary:
	var vs = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	return {"p": Vector2(randf() * vs.x, (randf() * vs.y) if anywhere else vs.y + 10), "v": Vector2(randf_range(-8, 8), -randf_range(10, 38)),
		"s": randf_range(1.5, 4.0), "c": Color(1, randf_range(.35, .7), .2, randf_range(.2, .7)) if randf() < .35 else Color(.6, .55, .5, randf_range(.15, .4)),
		"ph": randf() * 6.0}

func _process(dt: float) -> void:
	if not visible: return
	t += dt
	var vs = size
	for a in ash:
		a.p += (a.v + Vector2(sin(t * .8 + a.ph) * 10, 0)) * dt
		if a.p.y < -10: a.merge(_new_ash(), true)
	# gotas de sangue que escorrem da auréola
	if randf() < dt * 1.4 and drips.size() < 14:
		var ang = randf_range(.25, PI - .25)
		drips.append({"a": ang, "len": 0.0, "max": randf_range(40, 220), "w": randf_range(1.5, 3.5), "drop": -1.0})
	for d in drips:
		if d.len < d.max: d.len += dt * randf_range(14, 30)
		elif d.drop < 0: d.drop = 0.0
		else: d.drop += dt * 380
	drips = drips.filter(func(d): return d.drop < vs.y)
	for i in eyes_blink.size():
		eyes_blink[i] -= dt
		if eyes_blink[i] < -.18: eyes_blink[i] = randf_range(2.0, 7.0)
	queue_redraw()
	if title_art and title_art.visible:
		if randf() < dt * 1.2 and t_drips.size() < 9:
			t_drips.append({"x": randf_range(30, 520), "len": 0.0, "max": randf_range(14, 46), "w": randf_range(1.6, 3.2), "drop": -1.0})
		for d in t_drips:
			if d.len < d.max: d.len += dt * randf_range(8, 18)
			elif d.drop < 0: d.drop = 0.0
			else: d.drop += dt * 300
		t_drips = t_drips.filter(func(d): return d.drop < 400)
		title_art.queue_redraw()
	if paused:
		pause_head.queue_redraw()
		deco.queue_redraw()

func _draw() -> void:
	if paused: return
	var vs = size
	var a_bg = 1.0
	# fundo em degradê (preto em cima, sangue embaixo)
	var steps = 24
	for i in steps:
		var u = float(i) / steps
		var c = Color("060102").lerp(Color("2a0408"), pow(u, 1.6))
		c.a = a_bg
		draw_rect(Rect2(0, vs.y * u, vs.x, vs.y / steps + 1), c)
	var C = Vector2(vs.x * .69, vs.y * .4)
	var R = min(vs.x, vs.y) * .33
	# raios de luz caindo do alto
	for i in 7:
		var x = vs.x * (.48 + i * .06) + sin(t * .3 + i * 1.7) * 30
		var w = 40 + 30 * sin(t * .5 + i)
		var col = Color(1, .78, .42, (.035 + .02 * sin(t * .7 + i * 2.1)) * a_bg)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, -10), Vector2(x + 8, -10), Vector2(x + w + 140, vs.y), Vector2(x - w + 40, vs.y)]), col)
	# brilho atrás da auréola
	for k in 10:
		draw_circle(C, R * (1.5 - k * .1), Color(1, .55, .2, .018 * a_bg))
	# auréola externa quebrada (gira devagar)
	_ring(C, R, 14, t * .07, 10, Color(GOLD, .9 * a_bg), .16)
	# anel interno ao contrário, com marcas
	_ring(C, R * .78, 3, -t * .11, 24, Color(GOLD, .55 * a_bg), .05)
	for k in 48:
		var ang = -t * .11 + k * TAU / 48
		var d = Vector2(cos(ang), sin(ang))
		draw_line(C + d * R * .74, C + d * R * (.7 if k % 4 == 0 else .725), Color(GOLD, .5 * a_bg), 2)
	# olhos no anel externo
	for i in eyes_blink.size():
		var ang = t * .07 + i * TAU / eyes_blink.size() + .17
		var p = C + Vector2(cos(ang), sin(ang)) * R
		var op = 1.0 if eyes_blink[i] > 0 else clamp(abs(eyes_blink[i] + .09) / .09, 0, 1)
		_eye(p, 13, op, a_bg)
	# olho central enorme, seguindo o mouse
	var mp = get_local_mouse_position()
	var look = (mp - C).limit_length(1.0) if (mp - C).length() < 1 else (mp - C).normalized() * min(1.0, (mp - C).length() / 600.0)
	_eye(C, 52, 1.0 if fmod(t, 9.0) < 8.8 else .15, a_bg, look)
	# sangue escorrendo da auréola
	for d in drips:
		var base = C + Vector2(cos(d.a), sin(d.a)) * R
		var top = base
		if d.drop < 0:
			draw_line(top, top + Vector2(0, d.len), Color(.55, 0, .02, .9 * a_bg), d.w)
			draw_circle(top + Vector2(0, d.len), d.w * .9, Color(.6, 0, .02, .9 * a_bg))
		else:
			draw_line(top, top + Vector2(0, d.max * .3), Color(.45, 0, .02, .7 * a_bg), d.w * .7)
			draw_circle(top + Vector2(0, d.max + d.drop), d.w, Color(.6, 0, .02, .85 * a_bg))
	# cinzas
	for a in ash:
		var c: Color = a.c
		c.a *= a_bg
		draw_rect(Rect2(a.p, Vector2(a.s, a.s)), c)
	# névoa embaixo e vinheta
	for i in 12:
		var u = float(i) / 12
		draw_rect(Rect2(0, vs.y * (.78 + u * .22), vs.x, vs.y * .02 + 1), Color(.35, .02, .04, .05 * a_bg))
	for i in 14:
		var w2 = 6.0 + i * 6.0
		draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0, 0, 0, .045 * a_bg), false, w2)
	# linha dourada fina à esquerda do menu
	draw_rect(Rect2(64, 80, 2, vs.y - 160), Color(GOLD, .25 * a_bg))

func _ring(c: Vector2, r: float, w: float, rot: float, segs: int, col: Color, gap: float) -> void:
	for i in segs:
		var a0 = rot + i * TAU / segs
		var a1 = a0 + TAU / segs * (1.0 - gap) - (0.07 if i % 3 == 0 else 0.0)
		draw_arc(c, r, a0, a1, 24, col, w, true)

func _eye(p: Vector2, r: float, op: float, a: float, look := Vector2.ZERO) -> void:
	var h = r * .62 * op
	if h < 1.0:
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color(GOLD, a), 2)
		return
	var pts = PackedVector2Array()
	for i in 24:
		var u = float(i) / 23.0
		pts.append(p + Vector2(lerp(-r, r, u), -sin(u * PI) * h))
	for i in range(22, 0, -1):
		var u = float(i) / 23.0
		pts.append(p + Vector2(lerp(-r, r, u), sin(u * PI) * h))
	draw_colored_polygon(pts, Color(.93, .88, .8, .95 * a))
	var ir = min(r * .42, h * .95)
	var ip = p + look * r * .35
	draw_circle(ip, ir, Color(.7, .05, .03, a))
	draw_circle(ip, ir * .45, Color(0, 0, 0, a))
	draw_circle(ip + Vector2(-ir * .3, -ir * .35), ir * .18, Color(1, 1, 1, .8 * a))
	pts.append(pts[0])
	draw_polyline(pts, Color(GOLD, a), 2.0, true)


# ---------------- título ----------------
func _spaced_draw(c: CanvasItem, f: Font, x0: float, y: float, txt: String, sz: int, sp: float, col: Color, outline := 0, ocol := Color.BLACK) -> float:
	var x := x0
	for ch in txt:
		if outline > 0: c.draw_string_outline(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, outline, ocol)
		else: c.draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + sp
	return x - sp

func _draw_title() -> void:
	var c := title_art
	var txt := "DEICIDE"
	var sz := 100
	var sp := 6.0
	var base := 108.0
	var x0 := 8.0
	var w := 0.0
	for ch in txt: w += f_deco.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + sp
	w -= sp
	var pulse := .5 + .5 * sin(t * 1.6)
	# brilho de brasa atrás das letras
	for k in 4:
		_spaced_draw(c, f_deco, x0, base, txt, sz, sp, Color.WHITE, 26 - k * 6, Color(.85, .08, .03, (.05 + .04 * pulse) * (k + 1) * .5))
	# sombra funda
	_spaced_draw(c, f_deco, x0 + 4, base + 6, txt, sz, sp, Color(0, 0, 0, .8))
	# contorno escuro + dourado
	_spaced_draw(c, f_deco, x0, base, txt, sz, sp, Color.WHITE, 10, Color(.12, .02, .01))
	_spaced_draw(c, f_deco, x0, base, txt, sz, sp, Color.WHITE, 3, Color(1, .82, .45))
	# preenchimento: ouro escuro embaixo e claro em cima (duas passadas deslocadas)
	_spaced_draw(c, f_deco, x0, base, txt, sz, sp, Color("a86a1c"))
	_spaced_draw(c, f_deco, x0, base - 2, txt, sz, sp, Color("e8b048"))
	_spaced_draw(c, f_deco, x0, base - 4, txt, sz, sp, Color(1, .9, .6, .35))
	# reflexo que passa pelas letras
	var sx: float = fmod(t * 160.0, w + 400.0) - 200.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(x0 + sx, base - 80), Vector2(x0 + sx + 26, base - 80), Vector2(x0 + sx - 4, base + 8), Vector2(x0 + sx - 30, base + 8)]), Color(1, .95, .8, .1))
	# sangue escorrendo da base das letras
	for d in t_drips:
		var p := Vector2(x0 + min(d.x, w - 10), base + 2)
		if d.drop < 0:
			c.draw_line(p, p + Vector2(0, d.len), Color(.55, 0, .02, .95), d.w)
			c.draw_circle(p + Vector2(0, d.len), d.w * .9, Color(.62, 0, .03))
		else:
			c.draw_line(p, p + Vector2(0, d.max * .35), Color(.45, 0, .02, .8), d.w * .7)
			c.draw_circle(p + Vector2(0, d.max + d.drop), d.w, Color(.62, 0, .03, .9))
	# filete com losango e cruz invertida
	var ly := base + 30.0
	c.draw_line(Vector2(x0, ly), Vector2(x0 + w * .44, ly), Color(GOLD, .7), 2.0)
	c.draw_line(Vector2(x0 + w * .56, ly), Vector2(x0 + w, ly), Color(GOLD, .7), 2.0)
	var mc := Vector2(x0 + w * .5, ly)
	c.draw_colored_polygon(PackedVector2Array([mc + Vector2(-10, 0), mc + Vector2(0, -8), mc + Vector2(10, 0), mc + Vector2(0, 8)]), GOLD)
	c.draw_rect(Rect2(mc + Vector2(-1.5, -26), Vector2(3, 20)), GOLD)
	c.draw_rect(Rect2(mc + Vector2(-6, -14), Vector2(12, 3)), GOLD)
	for s2: float in [-1.0, 1.0]:
		c.draw_circle(Vector2(x0 + (w if s2 > 0 else 0.0), ly), 3, GOLD)

# ---------------- pausa ----------------
func _draw_pause_head() -> void:
	var c := pause_head
	var w := c.size.x
	var cx := w * .5
	var txt := "PAUSA"
	var sz := 62
	var sp := 16.0
	var tw := 0.0
	for ch in txt: tw += f_deco.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + sp
	tw -= sp
	var x0 := cx - tw * .5
	_spaced_draw(c, f_deco, x0, 64, txt, sz, sp, Color.WHITE, 12, Color(.7, .05, .03, .25))
	_spaced_draw(c, f_deco, x0, 64, txt, sz, sp, Color.WHITE, 6, Color(.08, .01, .01))
	_spaced_draw(c, f_deco, x0, 64, txt, sz, sp, Color("e8c070"))
	var md: String = MODES.get(G.mode, ["", ""])[0]
	var sub_t := md + "  ·  " + _fmt_time(G.stats.get("t", 0.0)) + "  ·  " + str(G.stats.get("kills", 0)) + " ABATES"
	var stw := f_cin.get_string_size(sub_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string_outline(f_cin, Vector2(cx - stw * .5, 96), sub_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, .8))
	c.draw_string(f_cin, Vector2(cx - stw * .5, 96), sub_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(PALE, .9))
	for s2: float in [-1.0, 1.0]:
		var a := Vector2(cx + s2 * (tw * .5 + 18), 44)
		var b := Vector2(cx + s2 * (w * .5 - 4), 44)
		c.draw_line(a, b, Color(GOLD, .7), 2.0)
		c.draw_colored_polygon(PackedVector2Array([a + Vector2(-6, 0), a + Vector2(0, -6), a + Vector2(6, 0), a + Vector2(0, 6)]), GOLD)
	c.draw_line(Vector2(cx - w * .3, 112), Vector2(cx + w * .3, 112), Color(GOLD, .35), 1.0)

func _fmt_time(sec: float) -> String:
	var s2 := int(sec)
	return "%d:%02d" % [s2 / 60, s2 % 60]

func _draw_pause_deco() -> void:
	if not paused: return
	var c := deco
	var vs := c.size
	var cx := vs.x * .5
	# moldura vertical dourada nos dois lados da coluna
	var top := 60.0
	var bot := vs.y - 60.0
	for s2: float in [-1.0, 1.0]:
		var x := cx + s2 * 300.0
		c.draw_line(Vector2(x, top + 30), Vector2(x, bot - 30), Color(GOLD, .35), 2.0)
		c.draw_line(Vector2(x + s2 * 8, top + 60), Vector2(x + s2 * 8, bot - 60), Color(GOLD, .15), 1.0)
		for y: float in [top + 30, bot - 30]:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y), Vector2(x, y - 6), Vector2(x + 6, y), Vector2(x, y + 6)]), Color(GOLD, .8))
	# auréola fina girando atrás do cabeçalho
	var hc := Vector2(cx, 120)
	_ring(hc, 120, 2, t * .1, 16, Color(GOLD, .18), .2)
	_ring(hc, 104, 1, -t * .15, 32, Color(GOLD, .12), .1)
	# cinzas por cima do jogo borrado
	for a in ash:
		var col: Color = a.c
		col.a *= .6
		c.draw_rect(Rect2(a.p, Vector2(a.s, a.s)), col)
