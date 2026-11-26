extends Node
## Cena principal: monta a arena, as duas viewports (mundo + armas), HUD, menus, ondas, projéteis e música.

var vpc: SubViewportContainer
var vp: SubViewport
var vpc2: SubViewportContainer
var vp2: SubViewport
var world: Node3D
var vm_root: Node3D
var player: CharacterBody3D
var world_light: OmniLight3D
const MUS := {"menu": "res://musica/menu.ogg", "coro": "res://musica/combate_coro.ogg", "furia": "res://musica/combate_furia.ogg",
	"gabriel": "res://sfx/gabriel_theme.ogg", "deus": "res://musica/deus.ogg", "sangue": "res://musica/deus_sangue.ogg",
	"final": "res://musica/throne_of_ash_and_gold.ogg"}
const MUS_GROUP := {"coro": ["coro", "furia"], "furia": ["coro", "furia"], "deus": ["deus", "sangue"], "sangue": ["deus", "sangue"]}
var mus = {}
var mus_w = {}
var _mus_us = 0
var _muffle = 0.0
var world_env: Environment
var build_root: Node3D
var gibs: Node
var arena_root: Node3D
var trono: Node3D
var miguel_arena: Node3D
var gabriel_arena: Node3D
var lilith_arena: Node3D
var azazel_arena: Node3D
var _storm_sky: Sky
var _blood_sky: Sky
var _dawn_sky: Sky
var _hall_sky: Sky
var _hell_sky: Sky
var level := "arena"
const LEVEL_ENV := {
	"arena": {"background_color": Color("2b0b0e"), "fog_light_color": Color("2b0b0e"), "ambient_light_color": Color("d0a088"), "ambient_light_energy": .75, "fog_depth_begin": 28.0, "fog_depth_end": 125.0, "sun": .8},
	"gabriel_hall": {"background_color": Color("2a0608"), "fog_light_color": Color("8a3a30"), "ambient_light_color": Color("ffb0a4"), "ambient_light_energy": .5, "fog_depth_begin": 70.0, "fog_depth_end": 340.0, "sun": .4},
	"gabriel_inferno": {"background_color": Color("1a0202"), "fog_light_color": Color("5a0806"), "ambient_light_color": Color("ff6a50"), "ambient_light_energy": .5, "fog_depth_begin": 50.0, "fog_depth_end": 260.0, "sun": .45},
	"gabriel": {"background_color": Color("cfe0f5"), "fog_light_color": Color("efe6f2"), "ambient_light_color": Color("fff4e6"), "ambient_light_energy": .5, "fog_depth_begin": 110.0, "fog_depth_end": 420.0, "sun": .85},
	"azazel": {"background_color": Color("070a12"), "fog_light_color": Color("1a2234"), "ambient_light_color": Color("9aaac8"), "ambient_light_energy": .8, "fog_depth_begin": 60.0, "fog_depth_end": 320.0, "sun": .35},
	"azazel2": {"background_color": Color("120203"), "fog_light_color": Color("3a0606"), "ambient_light_color": Color("b88080"), "ambient_light_energy": .55, "fog_depth_begin": 55.0, "fog_depth_end": 300.0, "sun": .35},
	"lilith": {"background_color": Color("0e0303"), "fog_light_color": Color("2a0804"), "ambient_light_color": Color("8a6a78"), "ambient_light_energy": .45, "fog_depth_begin": 45.0, "fog_depth_end": 200.0, "sun": .25},
	"miguel": {"background_color": Color("0a0610"), "fog_light_color": Color("1a0c22"), "ambient_light_color": Color("b8a8d0"), "ambient_light_energy": .6, "fog_depth_begin": 40.0, "fog_depth_end": 230.0, "sun": .5},
	"trono": {"background_color": Color("160205"), "fog_light_color": Color("2a0a0c"), "ambient_light_color": Color("e8d2c0"), "ambient_light_energy": .55, "fog_depth_begin": 50.0, "fog_depth_end": 190.0, "sun": .55},
}
var world_sun: DirectionalLight3D
var slide_snd: AudioStreamPlayer

var wave = 0
var queue: Array = []
var spawn_cd = 0.0
var wave_delay = 1.2
var wave_active = false
var started = false

# HUD
var hud: Control
var hud2: Control
var blood_scr: Control

func screen_blood(k: float) -> void:
	if blood_scr: blood_scr.add(k)
var ui = {}
var feed_box: VBoxContainer
var menu: Control
var dead_ov: Control
var shown_rank = -1
var b_dmg_w = 100.0
var b_hold = 0.0
var b_last = 100.0

func _ready() -> void:
	G.main = self
	_input_map()
	_build_viewports()
	arena_root = Node3D.new()
	arena_root.name = "Arena"
	build_root = arena_root
	_build_world()
	player = CharacterBody3D.new()
	player.set_script(preload("res://scripts/player.gd"))
	world.add_child(player)
	G.player = player
	player.global_position = Vector3(0, 2.3, 26)
	_build_terminal()
	world.add_child(arena_root)
	trono = Node3D.new()
	trono.name = "SalaDoTrono"
	trono.set_script(preload("res://scripts/trono.gd"))
	trono.build(self)
	miguel_arena = Node3D.new()
	miguel_arena.name = "ArenaDeMiguel"
	miguel_arena.set_script(preload("res://scripts/miguel_arena.gd"))
	miguel_arena.build(self)
	gabriel_arena = Node3D.new()
	gabriel_arena.name = "ArenaDeGabriel"
	gabriel_arena.set_script(preload("res://scripts/gabriel_arena.gd"))
	gabriel_arena.build(self)
	lilith_arena = Node3D.new()
	lilith_arena.name = "ArenaDaLilith"
	lilith_arena.set_script(preload("res://scripts/lilith_arena.gd"))
	lilith_arena.build(self)
	azazel_arena = Node3D.new()
	azazel_arena.name = "ArenaDoAzazel"
	azazel_arena.set_script(preload("res://scripts/azazel_arena.gd"))
	azazel_arena.build(self)
	build_root = world
	gibs = preload("res://scripts/gibs.gd").new()
	add_child(gibs)
	_build_audio()
	_build_hud()
	_build_menus()
	on_weapon_changed()
	G.style_added.connect(_on_style)
	get_viewport().size_changed.connect(_on_resize)
	apply_video()
	_apply_settings()
	show_menu(false)
	# teste automático (só quando chamado com: -- --autotest=modo)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			_autotest(a.split("=")[1])

# ---------------- terminal de arsenal ----------------
const TERM_POS := Vector3(6.6, 2.2, 27.2)
var term_light: OmniLight3D
var term_ov: Control
var term_list: VBoxContainer
var near_term = false

func _build_terminal() -> void:
	var t = Node3D.new()
	t.position = TERM_POS
	t.rotation.y = -PI / 2
	build_root.add_child(t)
	var dk = G.lit(Color("2a2c33"), .6, .3)
	var bz = G.lit(Color("8a8070"), .8, .1)
	var parts = [[Vector3(1.6, .9, .8), dk, Vector3(0, .45, 0)], [Vector3(1.64, .06, .84), bz, Vector3(0, .92, 0)],
		[Vector3(1.05, .82, .7), bz, Vector3(0, 1.37, -.08)], [Vector3(.86, .64, .02), G.unshaded(Color("021208")), Vector3(0, 1.39, .28)],
		[Vector3(.9, .05, .28), dk, Vector3(0, .97, .22)]]
	for i in 3: parts.append([Vector3(.05, .05, .02), G.unshaded([Color("ff3020"), Color("46ff8c"), Color("ffb030")][i]), Vector3(.62, .75 - i * .12, .41)])
	for pt in parts:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = pt[0]
		mi.mesh = bm
		mi.material_override = pt[1]
		mi.position = pt[2]
		t.add_child(mi)
	var lb = Label3D.new()
	lb.text = "ARSENAL\n> REVOLVER\n> ESCOPETA\n> ESPADAS\n> FOGUETES\n> PREGOS\n> RAIO\n> ARPAO\n> GRANADAS\n      [E] ACESSAR_"
	lb.font_size = 22
	lb.pixel_size = .0028
	lb.modulate = Color("46ff8c")
	lb.outline_size = 0
	lb.shaded = false
	lb.double_sided = false
	lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.position = Vector3(0, 1.39, .295)
	t.add_child(lb)
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(1.64, 1.8, .84)
	cs.shape = bs
	cs.position = Vector3(0, .9, 0)
	sb.add_child(cs)
	t.add_child(sb)
	term_light = OmniLight3D.new()
	term_light.light_color = Color("46ff8c")
	term_light.omni_range = 7
	term_light.light_energy = 1.2
	term_light.position = TERM_POS + Vector3(-.8, 1.4, 0)
	build_root.add_child(term_light)

func _build_term_ui(layer: CanvasLayer) -> void:
	term_ov = ColorRect.new()
	term_ov.color = Color(0.0, 0.03, 0.01, 0.9)
	term_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	term_ov.visible = false
	layer.add_child(term_ov)
	var mc = MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: mc.add_theme_constant_override("margin_" + side, 90)
	for side in ["top", "bottom"]: mc.add_theme_constant_override("margin_" + side, 30)
	term_ov.add_child(mc)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)
	var hd = HBoxContainer.new()
	hd.add_child(_lbl("TERMINAL // ARSENAL", 30, Color("46ff8c"), 3))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(sp)
	hd.add_child(_lbl("marque as armas que vai levar e ligue as melhorias · ordem = teclas 1–8", 15, Color("8fd8a8"), 2))
	v.add_child(hd)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	term_list = VBoxContainer.new()
	term_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_list.add_theme_constant_override("separation", 6)
	sc.add_child(term_list)
	var cl = _btn("FECHAR [E]", func(): close_term())
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(cl)
	v.add_child(row)

func _term_style(on: bool) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(.07, .3, .14, .9) if on else Color(.03, .08, .05, .9)
	sb.border_color = Color("46ff8c") if on else Color(.2, .4, .28)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	return sb

func _fill_term() -> void:
	for c in term_list.get_children():
		term_list.remove_child(c)
		c.queue_free()
	for k in G.WEAP.size():
		var w = G.WEAP[k]
		var n = G.loadout.find(k)
		var pan = PanelContainer.new()
		pan.add_theme_stylebox_override("panel", _term_style(n >= 0))
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		pan.add_child(hb)
		var eq = Button.new()
		eq.toggle_mode = true
		eq.button_pressed = n >= 0
		eq.custom_minimum_size = Vector2(380, 64)
		eq.alignment = HORIZONTAL_ALIGNMENT_LEFT
		eq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eq.text = ("[%d] " % (n + 1) if n >= 0 else "[  ] ") + w.name + "\n" + w.desc
		eq.add_theme_font_size_override("font_size", 13)
		eq.add_theme_color_override("font_color", Color("d8ffe4") if n >= 0 else Color("7fa08a"))
		eq.add_theme_color_override("font_pressed_color", Color("d8ffe4"))
		eq.add_theme_color_override("font_hover_pressed_color", Color("ffffff"))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]: eq.add_theme_stylebox_override(st, _term_style(n >= 0))
		eq.toggled.connect(_term_equip.bind(k))
		hb.add_child(eq)
		for u in G.UPG[w.id]:
			var on: bool = G.UP[w.id][u[0]]
			var b = Button.new()
			b.custom_minimum_size = Vector2(250, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.text = ("■ " if on else "□ ") + u[1] + "\n" + u[2]
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_color_override("font_color", Color("fff2b0") if on else Color("8fa898"))
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			var ss = _term_style(on)
			if on:
				ss.bg_color = Color(.3, .25, .05, .9)
				ss.border_color = Color("ffd040")
			for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, ss)
			b.pressed.connect(_term_up.bind(w.id, u[0]))
			hb.add_child(b)
		term_list.add_child(pan)

func _term_equip(on: bool, k: int) -> void:
	if on:
		if not k in G.loadout:
			G.loadout.append(k)
			G.loadout.sort()
	else:
		if G.loadout.size() > 1: G.loadout.erase(k)
	var w = player.weapons
	if not w.prev in G.loadout: w.prev = G.loadout[0]
	G.save()
	G.snd("click", -4)
	_fill_term.call_deferred()
	on_weapon_changed()

func _term_up(wid: String, u: String) -> void:
	G.UP[wid][u] = not G.UP[wid][u]
	player.weapons.apply_upgrades()
	G.save()
	G.snd("shell", -4)
	_fill_term.call_deferred()

func use_pressed() -> void:
	if near_term and G.state == "play": open_term()

func open_term() -> void:
	G.state = "term"
	player.fire_held = false
	player.weapons.alt_release()
	_fill_term()
	term_ov.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	G.snd("click", -4)

func close_term() -> void:
	if G.state != "term": return
	term_ov.visible = false
	var w = player.weapons
	if not w.cur in G.loadout: w.switch_to(G.loadout[0])
	on_weapon_changed()
	G.state = "play"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	G.snd("click", -6)

func _upd_term() -> void:
	var p = player.global_position
	near_term = level == "arena" and Vector2(p.x - TERM_POS.x, p.z - TERM_POS.z).length() < 3.2 and abs(p.y - TERM_POS.y) < 1.6
	term_light.light_energy = 1.0 + sin(Time.get_ticks_msec() / 90.0) * .15 + (-.6 if G.rng.randf() < .02 else 0.0)

func _auto_step(i: int) -> void:
	var w = player.weapons
	player.pitch = 0.05
	if i == 16 and G.state == "play":
		open_term()
		get_tree().create_timer(0.3, true, false, true).timeout.connect(func():
			var img = get_viewport().get_texture().get_image()
			if img: img.save_png("/tmp/gshot_term.png"))
		get_tree().create_timer(0.6, true, false, true).timeout.connect(close_term)
		return
	var k = i % 5
	if k == 0:
		w.alt_release()
		w.switch_to((i / 5 + 2) % 8, true)
	elif k == 1 or k == 4: w.try_fire()
	elif k == 2: w.alt_press()
	else:
		w.try_fire()
		w.alt_release()
		w.punch()

var _aim_boss = false
var _aim_e = null
func _skip_cut_test() -> void:
	trono._start_cut()
	trono._end_cut(true)

func _deus_test() -> void:
	start_mode("deus")
	_skip_cut_test()
	_aim_boss = true
	G.fov_base = 75.0
	player.global_position = Vector3(0, 1, 6)
	var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
	var shot = func(name):
		var img = get_viewport().get_texture().get_image()
		if img: img.save_png("/tmp/deus_%s.png" % name)
	var atks = ["maos", "olhar", "sangue", "aureola", "dedo", "convulsao"]
	rt.call(3.6, func(): G.fov_base = 24.0)
	for j in 3: rt.call(4.4 + j * .5, shot.bind("intro_%d" % j))
	rt.call(5.9, func(): G.fov_base = 75.0)
	for i in atks.size():
		var k = atks[i]
		var t0 = 6.0 + i * 4.6
		rt.call(t0, func():
			player.hp = 100000.0
			if G.boss:
				G.boss._end(false)
				G.boss._attack(k))
		for j in 4: rt.call(t0 + .7 + j * .9, shot.bind("%d%s_%d" % [i, k, j]))
	var t1 = 6.0 + atks.size() * 4.6
	rt.call(t1, func(): if G.boss: G.boss._end(false); G.boss.hp = G.boss.max_hp * .45)
	for j in 3: rt.call(t1 + .8 + j * .9, shot.bind("asc_%d" % j))
	rt.call(t1 + 5.0, func(): if G.boss: G.boss.inv = false; G.boss.take_damage(9999999, "rev", false))
	for j in 5: rt.call(t1 + 5.4 + j * .9, shot.bind("die_%d" % j))
	rt.call(t1 + 10.0, func(): print("DEUSTEST OK boss=", G.boss, " grp=", get_tree().get_nodes_in_group("gabriel").size()); get_tree().quit())
func _ceif_test() -> void:
	start_mode("train")
	for e in G.enemies: e.queue_free()
	G.enemies.clear()
	G.clear_timers()
	player.global_position = Vector3(0, 1, 20)
	spawn_enemy("husk", Vector3(0, 0.5, 4))
	_aim_e = G.enemies.back()
	G.fov_base = 50.0
	var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
	var shot = func(name):
		var img = get_viewport().get_texture().get_image()
		if img: img.save_png("/tmp/ce_%s.png" % name)
	# anda até o jogador, depois cada golpe
	for j in 6: rt.call(1.0 + j * .22, shot.bind("walk%d" % j))
	var atks = ["slash", "overhead", "spin", "lunge"]
	for i in atks.size():
		var k = atks[i]
		var t0 = 3.0 + i * 2.2
		rt.call(t0, func():
			if is_instance_valid(_aim_e):
				_aim_e.cd = 99.0
				_aim_e._start_atk(k))
		for j in 6: rt.call(t0 + .1 + j * .17, shot.bind("%s%d" % [k, j]))
	rt.call(12.5, func(): print("CEIFTEST OK alive=", is_instance_valid(_aim_e), " hp=", player.hp); get_tree().quit())
func _caida_test() -> void:
	start_mode("train")
	for e in G.enemies: e.queue_free()
	G.enemies.clear()
	G.clear_timers()
	player.global_position = Vector3(0, 1, 20)
	spawn_enemy("husk", Vector3(0, 0.5, 2))
	_aim_e = G.enemies.back()
	G.fov_base = 50.0
	var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
	var shot = func(name):
		var img = get_viewport().get_texture().get_image()
		if img: img.save_png("/tmp/ca_%s.png" % name)
	for j in 6: rt.call(4.2 + j * .25, shot.bind("walk%d" % j))
	rt.call(6.0, func():
		if is_instance_valid(_aim_e): _aim_e.cd = 99.0; _aim_e._caida_start("ataque"))
	for j in 6: rt.call(6.1 + j * .22, shot.bind("ataque%d" % j))
	rt.call(8.0, func(): player.global_position = Vector3(0, 1, 20); player.hp = player.max_hp if "max_hp" in player else 100)
	rt.call(8.2, func():
		if is_instance_valid(_aim_e): _aim_e.global_position = Vector3(0, .5, 9); _aim_e.cd = 99.0; _aim_e._caida_start("salto"))
	for j in 7: rt.call(8.3 + j * .26, shot.bind("salto%d" % j))
	rt.call(11.4, func(): if is_instance_valid(_aim_e): _aim_e.take_damage(9999, "punch", false))
	rt.call(11.9, shot.bind("morte"))
	rt.call(12.6, func(): print("CAIDATEST OK hp=", player.hp, " enemies=", G.enemies.size()); get_tree().quit())
## teste genérico de chefe: cada ataque com fotos, depois a segunda fase e os ataques novos
## uso: --autotest=bfx_<modo>   (ex.: bfx_boss, bfx_miguel, bfx_lilith, bfx_azazel, bfx_deus)
func _bfx_test(mode: String) -> void:
	var cfg = {"boss": [["beam", "spears", "quake", "sword", "orbs", "halo"], ["trumpets", "bloodfall", "beam", "spears"]],
		"miguel": [[], []], "lilith": [[], []], "azazel": [[], []], "deus": [[], []]}
	var atks: Array = cfg[mode][0]
	var atks2: Array = cfg[mode][1]
	if mode == "miguel" or mode == "lilith" or mode == "azazel" or mode == "deus":
		var b = load("res://scripts/%s.gd" % ("deus" if mode == "deus" else mode))
		var all: Array = b.get_script_constant_map().get("ATTACKS", []) if b else []
		atks = all.duplicate(); atks2 = all.duplicate()
		for k in b.get_script_constant_map().get("ATTACKS2", []): atks2.push_front(k)
	start_mode(mode)
	_aim_boss = true
	G.fov_base = 60.0
	var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
	var shot = func(name):
		var img = get_viewport().get_texture().get_image()
		if img: img.save_png("/tmp/bfx_%s_%s.png" % [mode, name])
	var keep = func():
		player.hp = 100000.0
		if G.boss and G.boss.get("cine") == true: G.boss.cine = false; G.boss.inv = false
	for k in 200: rt.call(k * .5, keep)
	if mode == "boss": rt.call(1.0, func(): gabriel_enter())
	if mode == "deus":
		for k in 120: rt.call(5.0 + k * .5, func():
			player.global_position = Vector3(0, 1.2, -4); player.velocity = Vector3.ZERO
			if G.boss: var d = G.boss.head_pos() - (player.global_position + Vector3(0, 1.6, 0)); player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length()) - .25)
	var t0 = 7.0 if mode == "deus" else 5.5
	var step = 3.6
	for i in atks.size():
		var k = atks[i]
		rt.call(t0 + i * step, func():
			if G.boss: G.boss.att = ""; G.boss.cd = 99.0; G.boss._attack(k))
		for j in 2: rt.call(t0 + i * step + .7 + j * 1.1, shot.bind("1_%02d%s_%d" % [i, k, j]))
	var t1 = t0 + atks.size() * step
	rt.call(t1, func(): if G.boss: G.boss.att = ""; G.boss.hp = G.boss.max_hp * .49; G.boss.cd = 0.0)
	for j in 4: rt.call(t1 + .8 + j * 1.0, shot.bind("2_fase_%d" % j))
	var t2 = t1 + 7.0
	for i in atks2.size():
		var k = atks2[i]
		rt.call(t2 + i * step, func():
			if G.boss: G.boss.att = ""; G.boss.cd = 99.0; G.boss._attack(k))
		for j in 2: rt.call(t2 + i * step + .7 + j * 1.1, shot.bind("3_%02d%s_%d" % [i, k, j]))
	rt.call(t2 + atks2.size() * step + .5, func(): print("BFX OK ", mode, " ph2=", G.boss.get("ph2") if G.boss else "morto"); get_tree().quit())

func _gab_test() -> void:
	start_mode("boss")
	_aim_boss = true
	G.fov_base = 38.0
	var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
	var shot = func(name):
		var img = get_viewport().get_texture().get_image()
		if img: img.save_png("/tmp/gab_%s.png" % name)
	var atks = ["beam", "feathers", "spears", "quake", "dive", "sword", "orbs", "halo"]
	for i in atks.size():
		var k = atks[i]
		rt.call(5.0 + i * 3.4, func():
			player.hp = 100000.0
			if G.boss:
				G.boss.att = ""
				G.boss._attack(k))
		for j in 3:
			rt.call(5.0 + i * 3.4 + 0.5 + j * 0.9, shot.bind("%d%s_%d" % [i, k, j]))
	var t1 = 5.0 + atks.size() * 3.4
	rt.call(t1, func(): if G.boss: G.boss.att = ""; G.boss.hp = G.boss.max_hp * .45)
	for j in 3: rt.call(t1 + .6 + j * .8, shot.bind("asc_%d" % j))
	rt.call(t1 + 3.4, func(): if G.boss: G.boss.take_damage(999999, "rev", false))
	for j in 4: rt.call(t1 + 3.6 + j * .8, shot.bind("die_%d" % j))
	rt.call(1.0, shot.bind("intro_0"))
	rt.call(2.2, shot.bind("intro_1"))
	rt.call(3.2, shot.bind("intro_2"))
	rt.call(t1 + 7.5, func(): print("GABTEST OK boss=", G.boss, " groups=", get_tree().get_nodes_in_group("gabriel").size()); get_tree().quit())

func _autotest(m: String) -> void:
	G.msaa_i = 0  # renderizador por software dos testes é lento com MSAA
	_apply_render()
	get_tree().create_timer(6.0, true, false, true).timeout.connect(func(): print("FPS teste ", Engine.get_frames_per_second()))
	if m == "gab":
		_gab_test()
		return
	if m == "gun":
		start_mode("train")
		var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shot = func(name):
			get_viewport().get_texture().get_image().save_png("/tmp/gun_%s.png" % name)
		var w = player.weapons
		rt.call(1.5, shot.bind("0idle"))
		rt.call(1.7, func(): w.try_fire())
		rt.call(1.76, shot.bind("1fire"))
		rt.call(2.4, func(): w.rv_ammo = 0; w.start_rev_reload())
		for j in 5: rt.call(2.5 + j * .13, shot.bind("2rel%d" % j))
		rt.call(3.6, func(): w.alt_press())
		for j in 3: rt.call(3.9 + j * .35, shot.bind("3chg%d" % j))
		rt.call(5.0, func(): w.alt_release())
		rt.call(5.6, func(): w.inspect())
		for j in 3: rt.call(5.7 + j * .15, shot.bind("4insp%d" % j))
		rt.call(6.8, func(): get_tree().quit())
		return
	if m == "menu":
		var rtm = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shm = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/menu_%s.png" % nm)
		G.rec["waves"] = {"rank": 5, "wave": 14, "kills": 212}
		rtm.call(1.5, func(): shm.call("a"); print("ts=", Engine.time_scale, " size=", menu.size, " mod=", menu.modulate))
		rtm.call(1.6, func(): menu.buttons[4].grab_focus())
		rtm.call(2.1, shm.bind("deus"))
		rtm.call(2.2, func(): menu._show_page("cfg"); menu.buttons[6].grab_focus(); print("tela ", DisplayServer.screen_get_size(), " janela ", get_window().size, " fator ", get_window().content_scale_factor, " escala3d ", vp.scaling_3d_scale))
		rtm.call(2.45, shm.bind("cfg"))
		rtm.call(2.5, func(): menu._cfg_tab("JOGO"))
		rtm.call(2.75, shm.bind("cfg_jogo"))
		rtm.call(2.76, func(): menu._cfg_tab("VÍDEO"))
		rtm.call(2.8, func(): menu._show_page("ctl"))
		rtm.call(3.2, shm.bind("ctl"))
		rtm.call(3.3, func(): start_mode("waves"))
		rtm.call(5.0, func(): show_menu(true))
		rtm.call(5.5, func(): var i = AudioServer.get_bus_index("Musica"); print("ABAFADO cutoff=", AudioServer.get_bus_effect(i, 0).cutoff_hz, " on=", AudioServer.is_bus_effect_enabled(i, 0), " efeitos_db=", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efeitos"))))
		rtm.call(5.6, shm.bind("pause"))
		rtm.call(5.7, func(): menu._show_page("cfg"))
		rtm.call(6.0, shm.bind("pause_cfg"))
		rtm.call(6.1, func(): quit_to_menu())
		rtm.call(6.8, func(): shm.call("volta"); print("MENU OK state=", G.state, " started=", started, " enemies=", G.enemies.size()); get_tree().quit())
		return
	if m == "deus":
		_deus_test()
		return
	if m == "rage":
		start_mode("deus")
		_skip_cut_test()
		player.global_position = Vector3(0, 1, 6)
		_aim_boss = true
		G.fov_base = 80.0
		var rt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shot = func(name):
			var img = get_viewport().get_texture().get_image()
			if img: img.save_png("/tmp/rage_%s.png" % name)
		rt.call(4.0, func(): if G.boss: G.boss.hp = G.boss.max_hp * .45)
		var la = [""]
		var tk = Timer.new(); tk.wait_time = .1; tk.ignore_time_scale = true; add_child(tk); tk.start()
		tk.timeout.connect(func():
			player.hp = 100000.0
			if G.boss and G.boss.att != la[0]:
				la[0] = G.boss.att
				print("t=%.1f att=%s sec=%s ph2=%s inv=%s" % [G.stats.t, G.boss.att, G.boss.sec, G.boss.ph2, G.boss.inv]))
		for j in 4: rt.call(5.5 + j * 1.0, shot.bind("asc_%d" % j))
		var atks = ["punhos", "lagrimas", "geiser", "mare"]
		for i in atks.size():
			var k = atks[i]
			var t0 = 13.0 + i * 6.0
			rt.call(t0, func(): if G.boss: G.boss._end(false); G.boss._attack(k))
			for j in 3: rt.call(t0 + 1.0 + j * 1.3, shot.bind("%d%s_%d" % [i, k, j]))
		rt.call(13.0 + atks.size() * 6.0 + 8.0, func(): print("RAGE END att=", G.boss.att if G.boss else "none", " mus=", mus_w); get_tree().quit())
		return
	if m == "ceif":
		_ceif_test()
		return
	if m == "caida":
		_caida_test()
		return
	if m == "arms":
		start_mode("train")
		var rta = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		hud.visible = OS.get_cmdline_user_args().has("--hud")
		for k in 8:
			rta.call(1.2 + k * .9, func(): player.weapons.select_slot(k))
			rta.call(2.05 + k * .9, func(): get_viewport().get_texture().get_image().save_png("/tmp/arm_%d.png" % k))
		rta.call(8.6, func(): player.weapons.punch())
		for j in 5:
			rta.call(8.62 + j * .14, func(): get_viewport().get_texture().get_image().save_png("/tmp/arm_soco%d.png" % j))
		rta.call(9.6, func(): print("ARMS OK"); get_tree().quit())
		return
	if m == "reload":
		start_mode("train")
		var rta = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		hud.visible = OS.get_cmdline_user_args().has("--hud")
		var wp = player.weapons
		var st = {"k": 0, "phase": ""}
		# fotografa por tempo de jogo (o teste roda a poucos FPS)
		get_tree().process_frame.connect(func():
			if st.phase == "p" and wp.rv_reloading and wp.rv_t >= st.k * .13:
				get_viewport().get_texture().get_image().save_png("/tmp/rl_p%d.png" % st.k); st.k += 1
			if st.phase == "s" and wp.sg_reloading:
				var tt = (wp.sg_t if wp.sg_phase == "load" else 0.0) + (.3 if wp.sg_phase == "load" else wp.sg_t) + st.get("n", 0) * wp.sg_lt()
				if wp.sg_phase == "load" and wp.sg_t < .02 and not st.get("cnt", false): st.n = st.get("n", 0) + 1; st.cnt = true
				if wp.sg_t > .05: st.cnt = false
				if tt >= st.k * .14:
					get_viewport().get_texture().get_image().save_png("/tmp/rl_s%d.png" % st.k); st.k += 1)
		rta.call(1.0, func(): wp.select_slot(0))
		rta.call(1.8, func(): wp.rv_ammo = 0; st.phase = "p"; st.k = 0; wp.start_rev_reload())
		rta.call(6.0, func(): wp.select_slot(1))
		rta.call(7.0, func(): wp.sg_ammo = 4; st.phase = "s"; st.k = 0; wp.start_sg_reload())
		rta.call(14.0, func(): get_viewport().get_texture().get_image().save_png("/tmp/rl_s_end.png"))
		rta.call(14.2, func(): print("RELOAD OK k=", st.k); get_tree().quit())
		return
	if m == "gibs":
		start_mode("train")
		var rtg = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shg = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/gib_%s.png" % nm)
		rtg.call(1.2, func():
			G.blood = 40.0
			player.global_position = Vector3(0, 1.2, 20)
			player.yaw = 0.0; player.pitch = -.12
			for e in G.enemies.duplicate():
				if is_instance_valid(e) and e.alive: e.global_position = Vector3(e.global_position.x * .5, e.global_position.y, 8.0 + abs(e.global_position.x) * .1))
		rtg.call(2.0, func():
			print("inimigos ", G.enemies.size())
			for e in G.enemies.duplicate():
				if is_instance_valid(e) and e.alive and e.kind != "drone": G.hurt_enemy(e, 9999, "punch", e.center(), false); break)
		rtg.call(2.05, shg.bind("0_congela"))
		rtg.call(2.45, shg.bind("1_voando"))
		rtg.call(2.9, func():
			for e in G.enemies.duplicate():
				if is_instance_valid(e) and e.alive: G.hurt_enemy(e, 9999, "rev", e.center(), false))
		rtg.call(3.3, shg.bind("2_varios"))
		rtg.call(4.6, shg.bind("3_chao"))
		rtg.call(6.0, func():
			blood_scr.clear()
			if gibs.corpses.size() > 0:
				var cp: Vector3 = gibs.corpses[0].m.global_position
				print("corpo ", cp, " rest=", gibs.corpses[0].rest)
				player.global_position = cp + Vector3(0, 1.0, 5.0)
				var d = cp - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length()))
		rtg.call(6.5, shg.bind("4_corpos"))
		rtg.call(7.0, func(): print("GIBS OK corpos=", gibs.corpses.size(), " gotas=", gibs.globs.size(), " sangue=", G.blood, " manchas=", gibs.splats.size(), " ts=", Engine.time_scale); get_tree().quit())
		return
	if m == "fotos_miguel" or m == "fotos_gabriel":
		var gab = m == "fotos_gabriel"
		start_mode("boss" if gab else "miguel")
		var rtf = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shf = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/foto_%s.png" % nm)
		for i in 400: rtf.call(i * .1, func():
			player.hp = 100000.0; player.dead = false
			if G.boss and G.state == "play":
				if not gab:
					G.boss.cd = 99.0 if not G.boss.get("hold_atk") else G.boss.cd
				var d = G.boss.center() - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z)
				player.pitch = atan2(d.y, Vector2(d.x, d.z).length()) + (.05 if gab else .0))
		if gab:
			var pc = Camera3D.new()
			pc.fov = 70
			world.add_child(pc)
			var view = func(pos, at):
				pc.global_position = pos; pc.look_at(at, Vector3.UP); pc.make_current()
			var H: Vector3 = gabriel_arena.HALL
			rtf.call(2.0, func(): hud.visible = false; view.call(H + Vector3(0, 3.4, 27), H + Vector3(0, 8, -14)))
			rtf.call(2.2, func(): view.call(H + Vector3(0, 3.4, 27), H + Vector3(0, 8, -14)))
			rtf.call(2.5, shf.bind("hall_1"))
			rtf.call(2.6, func(): view.call(H + Vector3(-6, 2.4, 22), H + Vector3(0, 4.5, 11)))
			rtf.call(3.1, shf.bind("hall_2"))
			rtf.call(3.2, func(): view.call(H + Vector3(-3, 9.0, -7), H + Vector3(0, 10.5, -19)))
			rtf.call(3.7, shf.bind("hall_3"))
			rtf.call(3.8, func(): view.call(H + Vector3(0, 44, 44), H + Vector3(0, 0, 6)))
			rtf.call(4.3, shf.bind("hall_cima"))
			rtf.call(4.4, func(): player.cam.make_current(); hud.visible = true)
			# sobe a escada andando até o portão
			rtf.call(4.5, func(): player.global_position = H + Vector3(0, 7.8, -9))
			rtf.call(6.5, func(): player.global_position = H + Vector3(0, 7.8, -19.5))
			rtf.call(7.5, func(): print("HALL state=", gabriel_arena.hall_state, " level=", level, " boss=", G.boss != null))
			rtf.call(8.0, func(): if G.boss: G.boss.visible = false)
			rtf.call(8.2, func(): hud.visible = false; view.call(Vector3(-8, 9, 52), Vector3(0, 4, 0)))
			rtf.call(8.8, shf.bind("ga_arena"))
			rtf.call(8.9, func(): view.call(Vector3(0, 60, 75), Vector3(0, 0, 0)))
			rtf.call(9.4, shf.bind("ga_cima"))
			rtf.call(9.5, func(): player.cam.make_current(); hud.visible = true; if G.boss: G.boss.visible = true)
			rtf.call(12.0, func(): player.global_position = Vector3(0, 1.2, 30))
			rtf.call(13.0, func(): if G.boss: G.boss._attack("beam"))
			rtf.call(14.2, shf.bind("gabriel"))
			rtf.call(15.0, func(): print("GAB OK boss=", G.boss != null); get_tree().quit())
		else:
			rtf.call(6.0, func(): if G.boss: G.boss.global_position = Vector3(0, G.boss.BASE_Y, -10); player.global_position = Vector3(0, 1.2, 8))
			rtf.call(6.1, func(): hud.visible = false)
			rtf.call(6.5, shf.bind("miguel"))
			rtf.call(6.6, func(): player.global_position = Vector3(-4, 1.2, 14))
			rtf.call(7.1, func(): hud.visible = true; G.boss.cd = 0.0; G.boss._attack("eyes"))
			rtf.call(8.05, shf.bind("miguel_olhos"))
			rtf.call(9.5, func(): G.boss._end(false); G.boss._attack("cross"))
			rtf.call(10.4, shf.bind("miguel_cruz"))
			rtf.call(11.0, func(): G.boss._end(false); G.boss.hp = G.boss.max_hp * .45)
			rtf.call(14.2, func(): G.boss._end(false); G.boss._attack("rosary"))
			rtf.call(15.4, shf.bind("miguel_eclipse"))
			rtf.call(16.0, func(): get_tree().quit())
		return
	if m == "jab":
		start_mode("train")
		var rtj = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		hud.visible = OS.get_cmdline_user_args().has("--hud")
		var wp = player.weapons
		var st = {"k": 0, "on": false}
		var TS = [.04, .1, .16, .2, .3, .42, .6, .8, .9]
		get_tree().process_frame.connect(func():
			if st.on and st.k < TS.size() and wp.jab_t >= TS[st.k]:
				get_viewport().get_texture().get_image().save_png("/tmp/jab_%d.png" % st.k); st.k += 1)
		rtj.call(1.0, func(): wp.select_slot(0))
		rtj.call(2.0, func(): st.on = true; wp.punch())
		rtj.call(8.0, func(): print("JAB OK k=", st.k); get_tree().quit())
		return
	if m == "spin":
		start_mode("train")
		var rts = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		hud.visible = false
		var wp = player.weapons
		var st = {"k": 0, "on": false}
		get_tree().process_frame.connect(func():
			if st.on and wp.spin_t < 1.0 and wp.spin_t >= st.k * .11:
				get_viewport().get_texture().get_image().save_png("/tmp/sp_%d.png" % st.k); st.k += 1)
		rts.call(1.0, func(): wp.select_slot(0))
		rts.call(2.0, func(): st.on = true; wp.start_spin(3, 2.4, "x"))
		rts.call(9.0, func(): print("SPIN OK k=", st.k); get_tree().quit())
		return
	if m == "asas":
		start_mode("lilith")
		var rta = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var pc = Camera3D.new(); pc.fov = 50
		world.add_child(pc)
		for i in 300: rta.call(i * .2, func(): player.hp = 100000.0; player.dead = false; if G.boss: G.boss.cd = 99.0)
		var views = [Vector3(0, 6, 11), Vector3(11, 6, 2), Vector3(-8, 6, -9), Vector3(0, 6, 11)]
		for i in 8:
			rta.call(4.5 + i * .35, func():
				hud.visible = false
				var b = G.boss
				if b == null: return
				b.global_position = Vector3(0, b.BASE_Y, -10)
				b.rotation.y = 0.0
				var v: Vector3 = views[i % 4]
				player.global_position = b.global_position + v
				player.velocity = Vector3.ZERO
				var d = b.global_position + Vector3(0, 8, 0) - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
				pass)
			rta.call(4.65 + i * .35, func(): get_viewport().get_texture().get_image().save_png("/tmp/as_%d.png" % i))
		rta.call(3.6, func(): if G.boss: G.boss.T.flap = 1.0)
		rta.call(7.5, func(): print("ASAS OK"); get_tree().quit())
		return
	if m == "lilith":
		start_mode("lilith")
		var rtq = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shq = func(n): get_viewport().get_texture().get_image().save_png("/tmp/lt_%s.png" % n)
		for i in 300: rtq.call(i * .2, func():
			player.hp = 100000.0; player.dead = false
			if G.boss and G.state == "play":
				var d = G.boss.center() - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z)
				player.pitch = atan2(d.y, Vector2(d.x, d.z).length()))
		var pc = Camera3D.new(); pc.fov = 70
		world.add_child(pc)
		var view = func(pos, at): pc.global_position = pos; pc.look_at(at, Vector3.UP); pc.make_current()
		rtq.call(1.0, func(): hud.visible = false; view.call(Vector3(0, 22, 52), Vector3(0, 0, -10)))
		rtq.call(1.6, shq.bind("arena"))
		rtq.call(1.7, func(): view.call(Vector3(30, 5, 30), Vector3(60, -1, 60)))
		rtq.call(2.2, shq.bind("arena2"))
		rtq.call(2.3, func(): player.cam.make_current(); hud.visible = true)
		rtq.call(2.8, shq.bind("intro"))
		rtq.call(5.5, func(): if G.boss: G.boss.global_position = Vector3(0, G.boss.BASE_Y, -6); player.global_position = Vector3(0, 1.2, 14))
		rtq.call(6.0, func(): hud.visible = false)
		rtq.call(6.3, shq.bind("perto"))
		rtq.call(6.4, func(): hud.visible = true)
		var atks = ["claw", "crosses", "brimstone", "kiss", "dive", "rift", "souls"]
		for i in atks.size():
			var k = atks[i]
			var t0 = 7.0 + i * 4.5
			rtq.call(t0, func(): if G.boss: G.boss._end(false); G.boss._attack(k))
			rtq.call(t0 + 1.0, shq.bind("%d%s_a" % [i, k]))
			rtq.call(t0 + 2.0, shq.bind("%d%s_b" % [i, k]))
		var te = 7.0 + atks.size() * 4.5
		rtq.call(te, func(): if G.boss: G.boss._end(false); G.boss.hp = G.boss.max_hp * .45)
		rtq.call(te + 3.5, shq.bind("inferno"))
		rtq.call(te + 4.0, func(): print("LILITH OK hp=", G.boss.hp if G.boss else -1, " ph2=", G.boss.ph2 if G.boss else false, " level=", level); get_tree().quit())
		return
	if m == "miguel":
		start_mode("miguel")
		var rtq = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shq = func(n): get_viewport().get_texture().get_image().save_png("/tmp/mg_%s.png" % n)
		for i in 300: rtq.call(i * .2, func(): player.hp = 100000.0; player.dead = false)
		rtq.call(2.5, shq.bind("intro"))
		rtq.call(6.0, shq.bind("idle"))
		for i in 200: rtq.call(5.0 + i * .25, func():
			if G.boss and G.state == "play":
				var d = G.boss.center() - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z)
				player.pitch = atan2(d.y, Vector2(d.x, d.z).length()))
		var atks = ["sweep", "eyes", "cross", "chain", "blink", "rosary", "crown"]
		for i in atks.size():
			var k = atks[i]
			var t0 = 7.0 + i * 5.0
			rtq.call(t0, func(): if G.boss: G.boss._end(false); G.boss._attack(k))
			rtq.call(t0 + 1.0, shq.bind("%d%s_a" % [i, k]))
			rtq.call(t0 + 2.0, shq.bind("%d%s_b" % [i, k]))
		var te = 7.0 + atks.size() * 5.0
		rtq.call(te, func(): if G.boss: G.boss._end(false); G.boss.hp = G.boss.max_hp * .45)
		rtq.call(te + 2.5, shq.bind("eclipse"))
		rtq.call(te + 5.0, func(): print("MIGUEL OK hp=", G.boss.hp if G.boss else -1, " ph2=", G.boss.ph2 if G.boss else false, " level=", level); get_tree().quit())
		return
	if m == "bossbar":
		start_mode("boss")
		var rtb = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		rtb.call(5.0, func(): if G.boss: G.boss.hp = G.boss.max_hp * .62)
		rtb.call(5.3, func(): if G.boss: G.boss.hp = G.boss.max_hp * .55)
		rtb.call(5.5, func(): get_viewport().get_texture().get_image().save_png("/tmp/bb_gabriel.png"))
		rtb.call(5.6, func(): ui.boss.set_boss("deus"))
		rtb.call(6.4, func(): if G.boss: G.boss.hp = G.boss.max_hp * .25)
		rtb.call(7.2, func(): get_viewport().get_texture().get_image().save_png("/tmp/bb_deus.png"))
		rtb.call(7.4, func(): print("BOSSBAR OK vis=", ui.boss.visible); get_tree().quit())
		return
	if m == "fonte":
		start_mode("deus")
		var rtf = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var tp = trono.global_position
		rtf.call(1.0, func(): trono.set_process(false); if G.boss: G.boss.visible = false)
		var fc: Vector3 = trono.fontes[0].global_position
		var wf: Vector3 = trono.falls[2].global_position
		var poses = [[fc + Vector3(0, .5, 7), fc + Vector3(0, 1.2, 0)], [fc + Vector3(8, .5, 13), wf + Vector3(0, -6, 0)]]
		for k in poses.size():
			rtf.call(1.5 + k * 1.2, func():
				player.global_position = poses[k][0]
				player.velocity = Vector3.ZERO
				var d = poses[k][1] - (player.global_position + Vector3(0, 1.6, 0))
				player.yaw = atan2(-d.x, -d.z)
				player.pitch = atan2(d.y, Vector2(d.x, d.z).length()))
			rtf.call(2.3 + k * 1.2, func(): print("pose ", k, " pl=", player.global_position, " fc=", fc); get_viewport().get_texture().get_image().save_png("/tmp/fonte_%d.png" % k))
		rtf.call(4.2, func(): print("FONTE OK"); get_tree().quit())
		return
	if m == "halo":
		start_mode("deus")
		G.fov_base = 100.0
		var rth = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		rth.call(1.0, func():
			trono.set_process(false)
			if G.boss: G.boss.visible = false
			player.global_position = Vector3(-8.5, 9.6, -54.5)
			var d = Vector3(-2.0, 30.0, -72.0) - Vector3(-8.5, 11.2, -54.5)
			player.yaw = atan2(-d.x, -d.z)
			player.pitch = atan2(d.y, Vector2(d.x, d.z).length()))
		rth.call(1.8, func(): get_viewport().get_texture().get_image().save_png("/tmp/halo_perto.png"))
		var poses = [[Vector3(0, 3, 50), Vector3(0, 2.5, 100)], [Vector3(0, 3, 110), Vector3(0, 2.5, 60)], [Vector3(-1, 3.5, 62), Vector3(-6.6, 2.8, 58)], [Vector3(1, 3.5, 71), Vector3(6.6, 2.8, 67)], [Vector3(0, 4, 100), Vector3(0, 3, 70)], [Vector3(0, 4, 100), Vector3(0, 3, 70)]]
		if G.boss: G.boss.visible = false
		for k in poses.size():
			rth.call(3.0 + k * .5, func():
				trono.cam.fov = 60
				trono.cam.global_position = poses[k][0]
				trono.cam.look_at(poses[k][1], Vector3.UP)
				trono.cam.make_current())
			rth.call(3.2 + k * .5, func(): get_viewport().get_texture().get_image().save_png("/tmp/sangue_%d.png" % k))
		rth.call(2.0, func(): player.global_position = Vector3(0, 1.2, 10); player.yaw = 0.0; player.pitch = .18)
		rth.call(2.6, func(): get_viewport().get_texture().get_image().save_png("/tmp/halo_longe.png"))
		rth.call(6.0, func(): get_tree().quit())
		return
	if m.begins_with("bfx_"):
		_bfx_test(m.substr(4))
		return
	if m == "azazel":
		var rta = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var sha = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/aza_%s.png" % nm)
		start_mode("azazel")
		var look = func(pos, at):
			player.global_position = pos; player.velocity = Vector3.ZERO
			var d = at - (pos + Vector3(0, 1.6, 0)); player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		var keep = func(): player.hp = 9999
		for k in 40: rta.call(k * .5, keep)
		rta.call(2.0, func(): look.call(Vector3(0, 1.3, 30), Vector3(0, 12, -18)))
		rta.call(3.0, sha.bind("0_chegada"))
		var a0 = PI / 8
		var dir0 = Vector3(cos(a0), 0, sin(a0))
		var eye0 = dir0 * (44.0 - 6.5) + Vector3(0, 22.0 * .62, 0) - dir0 * 1.35
		rta.call(5.5, func(): look.call(eye0 - dir0 * 5.5 + Vector3(-1.5, -1.9, 0), eye0))
		rta.call(5.8, func(): player.frozen = true)
		rta.call(6.2, sha.bind("torre"))
		rta.call(6.3, func(): player.frozen = false)
		var atks = ["strike", "gaze", "sweep", "nova", "cage", "eyes"]
		for i in atks.size():
			var k = atks[i]
			var t0 = 7.0 + i * 3.6
			rta.call(t0, func(): if G.boss: G.boss.cd = 99.0; G.boss._attack(k); look.call(Vector3(6, 1.3, 16), Vector3(0, 4, -6)))
			rta.call(t0 + (1.25 if k != "sweep" else 2.0), sha.bind("3_%s" % k))
		var close = func():
			var b = G.boss
			b.cd = 99.0; b.mv = "hold"
			var e = b.eye_pos()
			var f = b.global_transform.basis.z.normalized()
			look.call(Vector3(e.x, 0, e.z) + Vector3(f.x, 0, f.z) * 16.0 + Vector3(0, 1.3, 0), e)
		rta.call(28.4, close)
		rta.call(29.0, sha.bind("1_boss"))
		rta.call(29.05, func(): G.boss.T.blink = 1.0)
		rta.call(29.4, sha.bind("2_pisca"))
		rta.call(29.45, func(): G.boss.T.blink = 0.0)
		rta.call(29.6, func(): if G.boss: G.boss.hp = G.boss.max_hp * .49)
		rta.call(34.0, close)
		rta.call(34.6, sha.bind("4_chora"))
		rta.call(34.7, func(): look.call(Vector3(-20, 1.3, 25), Vector3(10, 3, -10)))
		rta.call(35.4, sha.bind("5_arena2"))
		rta.call(35.45, func(): look.call(eye0 - dir0 * 5.5 + Vector3(-1.5, -1.9, 0), eye0))
		rta.call(35.6, func(): player.frozen = true)
		rta.call(35.48, func(): azazel_arena.spires[0].cd = 0.0)
		rta.call(36.0, sha.bind("torre2"))
		rta.call(36.05, func(): player.frozen = false)
		rta.call(36.1, func(): if G.boss: G.boss._attack("strike"); look.call(Vector3(6, 1.3, 16), Vector3(0, 4, -6)))
		rta.call(36.8, sha.bind("6_raio2"))
		rta.call(37.0, func(): print("AZAZEL OK ph2=", G.boss.ph2 if G.boss else null, " hp=", G.boss.hp if G.boss else 0); get_tree().quit())
		return
	if m == "portao":
		var rtp = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var shp = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/po_%s.png" % nm)
		start_mode("boss")
		var H: Vector3 = gabriel_arena.HALL
		var look = func(pos, at):
			player.global_position = pos; player.velocity = Vector3.ZERO
			var d = at - (pos + Vector3(0, 1.6, 0)); player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		rtp.call(2.5, func(): look.call(H + Vector3(0, 1.3, 16), H + Vector3(0, 14, -18)))
		rtp.call(3.2, shp.bind("1_praca"))
		rtp.call(3.3, func(): look.call(H + Vector3(0, 7.3, -6), H + Vector3(0, 12, -18)))
		rtp.call(4.0, shp.bind("2_portao"))
		rtp.call(4.1, func(): gabriel_arena._set_gate(1.0); look.call(H + Vector3(0, 7.4, -8), Vector3(0, 6, 0)))
		rtp.call(4.8, shp.bind("3_vista"))
		rtp.call(5.0, func(): player.frozen = false; gabriel_enter())
		rtp.call(8.5, func(): look.call(Vector3(0, 2.3, 38), Vector3(0, 8, 0)))
		rtp.call(9.2, shp.bind("4_arena"))
		rtp.call(12.5, func(): if G.boss: G.boss.hp = G.boss.max_hp * .49; player.hp = 9999)
		rtp.call(12.0, func(): player.hp = 9999)
		rtp.call(20.0, func(): player.hp = 9999)
		rtp.call(16.0, func(): player.hp = 9999)
		rtp.call(23.5, func(): look.call(Vector3(0, 2.3, 38), Vector3(0, 8, 0)))
		rtp.call(17.5, func(): look.call(Vector3(0, 2.3, 38), Vector3(0, 4, 0)))
		rtp.call(18.0, shp.bind("5a_espalhando"))
		rtp.call(24.2, shp.bind("5_inferno"))
		rtp.call(24.3, func(): look.call(Vector3(-6, 2.3, 30), Vector3(4, 0, 8)))
		rtp.call(25.0, shp.bind("6_corpos"))
		rtp.call(25.2, func(): print("PORTAO OK corrupt=", gabriel_arena.corrupted, " k=", gabriel_arena.corrupt_k); get_tree().quit())
		return
	if m == "escada":
		var rte = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var she = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/es_%s.png" % nm)
		start_mode("boss")
		var H: Vector3 = gabriel_arena.HALL
		rte.call(1.5, func(): player.global_position = H + Vector3(0, 1.5, 4); player.velocity = Vector3.ZERO; player.yaw = 0.0; player.pitch = .25)
		rte.call(2.0, func(): Input.action_press("fwd"))
		for j in 5: rte.call(2.4 + j * .8, func(): print("GAB t=", j, " y=", snapped(player.global_position.y - H.y, .01), " z=", snapped(player.global_position.z - H.z, .01)))
		rte.call(4.0, she.bind("subindo"))
		rte.call(5.0, func(): Input.action_release("fwd"))
		var look = func(pos, at):
			player.global_position = pos; player.velocity = Vector3.ZERO
			var d = at - (pos + Vector3(0, 1.6, 0)); player.yaw = atan2(-d.x, -d.z); player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		rte.call(5.3, func(): look.call(H + Vector3(0, 1.3, 15), H + Vector3(0, 8, -4)))
		rte.call(5.9, she.bind("anjos"))
		var pc2 = Camera3D.new(); pc2.fov = 60
		rte.call(6.0, func():
			world.add_child(pc2); pc2.global_position = H + Vector3(0, 4.0, 30.0); pc2.look_at(H + Vector3(0, 12.0, -4.0), Vector3.UP); pc2.make_current())
		rte.call(6.7, func(): player.cam.make_current(); pc2.queue_free())
		rte.call(6.6, she.bind("anjo_perto"))
		rte.call(6.65, func(): look.call(H + Vector3(0, .4, 31), H + Vector3(0, 1.0, 20)); player.frozen = false; Input.action_press("fwd"))
		rte.call(7.2, func(): print("PRACA y=", snapped(player.global_position.y - H.y, .01), " z=", snapped(player.global_position.z - H.z, .01)))
		rte.call(7.45, func(): Input.action_release("fwd"); print("PRACA y=", snapped(player.global_position.y - H.y, .01), " z=", snapped(player.global_position.z - H.z, .01)))
		# trono de Deus
		rte.call(7.5, func(): start_mode("deus"))
		rte.call(10.5, func(): G.state = "play"; player.frozen = false; player.dead = false; player.global_position = Vector3(4.6, 1.2, -38); player.velocity = Vector3.ZERO; player.yaw = 0.0; player.pitch = .3)
		rte.call(11.0, func(): G.state = "play"; player.frozen = false)
		rte.call(10.8, func(): Input.action_press("fwd"))
		for j in 6: rte.call(11.2 + j * .8, func(): print("TRONO t=", j, " y=", snapped(player.global_position.y, .01), " z=", snapped(player.global_position.z, .01)))
		rte.call(12.0, she.bind("trono_sobe"))
		rte.call(16.2, func(): Input.action_release("fwd"); print("ESCADA OK"); get_tree().quit())
		return
	if m == "trono":
		start_mode("deus")
		var rtt = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		var sht = func(nm): get_viewport().get_texture().get_image().save_png("/tmp/tr_%s.png" % nm)
		var view = func(pos, at, nm):
			trono.cam.global_position = pos
			trono.cam.look_at(at, Vector3.UP)
			trono.cam.make_current()
		rtt.call(1.5, sht.bind("0corredor"))
		rtt.call(1.6, func(): player.global_position = Vector3(0, 1.2, 57))
		rtt.call(5.8, sht.bind("1porta"))
		rtt.call(5.85, func(): view.call(Vector3(-2.5, 1.7, 52), Vector3(0, .5, 40), ""))
		rtt.call(5.95, sht.bind("1b_soleira"))
		rtt.call(6.0, func(): player.cam.make_current(); player.global_position = Vector3(0, 1.2, 40))
		rtt.call(6.6, sht.bind("2salao_jogador"))
		rtt.call(6.7, func(): view.call(Vector3(0, 30, 44), Vector3(0, 8, -50), ""))
		rtt.call(7.0, sht.bind("3geral"))
		rtt.call(7.1, func(): view.call(Vector3(34, 7, 34), Vector3(0, 4, -10), ""))
		rtt.call(7.4, sht.bind("4fontes"))
		rtt.call(7.5, func(): view.call(Vector3(-20, 14, -10), Vector3(-46, 14, -30), ""))
		rtt.call(7.8, sht.bind("5cachoeiras"))
		rtt.call(7.9, func(): view.call(Vector3(0, 14, -26), Vector3(0, 22, -66), ""))
		rtt.call(8.2, sht.bind("6trono"))
		rtt.call(8.3, func(): player.cam.make_current(); player.global_position = Vector3(0, 1.2, 13))
		for k in [1.5, 5.0, 9.5, 13.5, 18.0, 20.8]:
			rtt.call(8.6 + k, sht.bind("c_%04.1f" % k))
		rtt.call(8.6 + 23.0, func(): sht.call("z_luta"); print("TRONO stage=", trono.stage, " cine=", G.boss.cine if G.boss else "-", " inv=", G.boss.inv if G.boss else "-", " frozen=", player.frozen, " mus=", mus_w))
		rtt.call(8.6 + 27.0, func(): sht.call("z_luta2"); print("TRONO OK att=", G.boss.att if G.boss else "-", " pos=", G.boss.global_position if G.boss else "-"); get_tree().quit())
		return
	if m == "blas":
		start_mode("train")
		var shotb = func(nm):
			var img = get_viewport().get_texture().get_image()
			if img: img.save_png("/tmp/blas_%s.png" % nm)
		var rtb = func(t, f): get_tree().create_timer(t, true, false, true).timeout.connect(f)
		rtb.call(1.0, func():
			player.yaw = 0.0; player.pitch = -.05
			G.style = 420.0
			G.blas = 45.0
			print("MUS ", mus_w, " playing coro=", mus.coro.playing, " furia=", mus.furia.playing))
		rtb.call(2.5, func():
			print("MUS2 ", mus_w, " blas=", G.blas, " fill=", ui.blfill.size)
			shotb.call("antes")
			G.blas = 100.0)
		rtb.call(2.8, func(): shotb.call("cheia"); print("alvos ", _blas_targets().size(), " de ", G.enemies.size()); blasfemia())
		rtb.call(3.4, func(): shotb.call("congelado"); print("ts=", Engine.time_scale, " MUS3 ", mus_w))
		rtb.call(3.98, func(): shotb.call("raio"))
		rtb.call(4.1, func(): shotb.call("raio2"))
		rtb.call(5.0, func(): shotb.call("depois"); print("vivos ", G.enemies.size(), " kills ", G.stats.kills, " rank ", G.rank(), " blas_on ", G.blas_on))
		rtb.call(8.5, func(): shotb.call("fim"); print("BLAS OK blas_on=", G.blas_on, " ts=", Engine.time_scale, " bg=", world_env.background_color); get_tree().quit())
		return
	start_mode(m)
	for i in 40:
		G.later(0.5 + i * 0.4, _auto_step.bind(i))
	for k in 6:
		get_tree().create_timer(2.0 + k * 2.5, true, false, true).timeout.connect(func():
			var img = get_viewport().get_texture().get_image()
			if img: img.save_png("/tmp/gshot_%s_%d.png" % [m, k]))
	get_tree().create_timer(17.0, true, false, true).timeout.connect(func(): print("AUTOTEST OK mode=", m, " enemies=", G.enemies.size(), " hp=", player.hp, " boss=", G.boss != null, " kills=", G.stats.kills, " state=", G.state); get_tree().quit())

# ---------------- entrada ----------------
func _input_map() -> void:
	var keys = {"fwd": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE],
		"dash": [KEY_SHIFT], "slide": [KEY_C, KEY_CTRL], "punch": [KEY_F], "inspect": [KEY_R], "swap": [KEY_Q], "use": [KEY_E], "blas": [KEY_G],
		"w1": [KEY_1], "w2": [KEY_2], "w3": [KEY_3], "w4": [KEY_4], "w5": [KEY_5], "w6": [KEY_6], "w7": [KEY_7], "w8": [KEY_8], "pause": [KEY_ESCAPE]}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

func _unhandled_input(ev: InputEvent) -> void:
	if G.state == "term":
		if ev.is_action_pressed("pause") or ev.is_action_pressed("use"): close_term()
		return
	if ev.is_action_pressed("blas") and G.state == "play":
		blasfemia()
		return
	if ev.is_action_pressed("pause"):
		if G.state == "play": show_menu(true)
		elif G.state == "paused": resume()
		return
	if G.state == "play":
		if ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.handle_input(ev)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and G.state == "play":
		show_menu(true)

# ---------------- viewports (mundo pixelado + armas por cima) ----------------
func _build_viewports() -> void:
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	vp.audio_listener_enable_3d = true
	vpc.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	G.world = world
	if G.fx == null or not is_instance_valid(G.fx):
		G.fx = preload("res://scripts/fx.gd").new(); G.fx.name = "FX"; add_child(G.fx)
	vpc2 = SubViewportContainer.new()
	vpc2.stretch = true
	vpc2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vpc2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vpc2.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vpc2)
	vp2 = SubViewport.new()
	vp2.own_world_3d = true
	vp2.transparent_bg = true
	vp2.handle_input_locally = false
	vpc2.add_child(vp2)
	var vcam = Camera3D.new()
	vcam.fov = 55
	vcam.near = 0.01
	vcam.far = 10
	vp2.add_child(vcam)
	vm_root = Node3D.new()
	vp2.add_child(vm_root)
	var env2 = Environment.new()
	env2.background_mode = Environment.BG_CLEAR_COLOR
	env2.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env2.ambient_light_color = Color("c8a894")
	env2.ambient_light_energy = 0.9
	var we2 = WorldEnvironment.new()
	we2.environment = env2
	vp2.add_child(we2)
	var dl = DirectionalLight3D.new()
	dl.rotation = Vector3(-0.8, 0.5, 0)
	dl.light_energy = 1.1
	vp2.add_child(dl)
	var rim = DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.9, 0)
	rim.light_color = Color("ffb08a")
	rim.light_energy = 0.6
	vp2.add_child(rim)

func _apply_settings() -> void:
	vpc.stretch_shrink = 3 if G.retro else 1
	vpc2.stretch_shrink = 3 if G.retro else 1
	_apply_render()

## modo de janela, resolução, vsync, limite de FPS e escala da interface
func apply_video() -> void:
	var w: Window = get_window()
	var scr := DisplayServer.window_get_current_screen()
	var ss: Vector2i = DisplayServer.screen_get_size(scr)
	var target: Vector2i = ss if G.res_i == 0 else G.RES_LIST[G.res_i][1]
	if not DisplayServer.get_name() == "headless" and not OS.has_feature("editor_hint"):
		match int(G.win_mode):
			0:
				w.mode = Window.MODE_WINDOWED
				w.borderless = false
				var sz = Vector2i(min(target.x, ss.x - 40), min(target.y, ss.y - 90))
				w.size = sz
				w.position = DisplayServer.screen_get_position(scr) + (ss - sz) / 2
			1:
				w.mode = Window.MODE_WINDOWED
				w.borderless = true
				w.size = ss
				w.position = DisplayServer.screen_get_position(scr)
			2:
				w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if G.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(G.max_fps)
	_apply_render.call_deferred()

## escala da interface e resolução de renderização do 3D
func _apply_render() -> void:
	var w: Window = get_window()
	var phys: Vector2i = w.size
	var f: float = G.UI_SCALES[G.ui_i]
	if f <= 0.0: f = clamp(phys.y / 1080.0, 1.0, 2.0)
	w.content_scale_factor = f
	var scr := DisplayServer.window_get_current_screen()
	var target_h: float = float(phys.y)
	if G.win_mode != 0 and G.res_i != 0: target_h = float(G.RES_LIST[G.res_i][1].y)
	var logical_h: float = phys.y / f
	var sc: float = 1.0 if G.retro else clamp(target_h / max(1.0, logical_h), .25, 2.0)
	for v in [vp, vp2]:
		v.scaling_3d_scale = sc
		v.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][G.msaa_i]
	if world_env:
		world_env.adjustment_enabled = true
		world_env.adjustment_brightness = G.bright
	if ui.has("fps"): ui.fps.visible = G.show_fps

func _on_resize() -> void:
	_apply_render()

# ---------------- arena ----------------
func _tex(draw: Callable) -> ImageTexture:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	draw.call(img)
	for y in 64:
		for x in 64:
			var c = img.get_pixel(x, y)
			var k = G.rnd(-0.043, 0.043)
			img.set_pixel(x, y, Color(clamp(c.r + k, 0, 1), clamp(c.g + k, 0, 1), clamp(c.b + k, 0, 1)))
	return ImageTexture.create_from_image(img)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)

func _mat_tex(t: Texture2D, scale := 0.25) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.9
	return m

func box(x: float, y: float, z: float, w: float, h: float, d: float, mat: Material) -> void:
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(w, h, d)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(x, y + h / 2.0, z)
	build_root.add_child(sb)

func deco(p: Vector3, s: Vector3, c: Color) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = G.unshaded(c)
	mi.position = p
	build_root.add_child(mi)

func _build_world() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b0b0e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d0a088")
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("2b0b0e")
	env.fog_depth_begin = 28
	env.fog_depth_end = 125
	env.fog_density = 1.0
	var we = WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	world_env = env
	var sun = DirectionalLight3D.new()
	world_sun = sun
	sun.light_color = Color("ffe2c4")
	sun.light_energy = 0.8
	sun.rotation = Vector3(-1.0, 0.6, 0)
	world.add_child(sun)
	world_light = OmniLight3D.new()
	world_light.light_color = Color("ffc070")
	world_light.omni_range = 22
	world_light.light_energy = 0
	world.add_child(world_light)
	var t_floor = _tex(func(img: Image):
		for y in 4:
			for x in 4:
				_rect(img, x * 16, y * 16, 16, 16, Color("3d2c27") if (x + y) % 2 else Color("352520"))
		for i in 4:
			_rect(img, i * 16, 0, 1, 64, Color("1d1210"))
			_rect(img, 0, i * 16, 64, 1, Color("1d1210")))
	var t_wall = _tex(func(img: Image):
		_rect(img, 0, 0, 64, 64, Color("1e0b0b"))
		for y in 8:
			for x in range(-1, 4):
				var c: Color = [Color("5a1e1c"), Color("4e1a18"), Color("62221f")][(x + y * 3 + 9) % 3]
				var px = x * 16 + (y % 2) * 8 + 1
				if px < 0: _rect(img, 0, y * 8 + 1, px + 14, 6, c)
				else: _rect(img, px, y * 8 + 1, min(14, 64 - px), 6, c))
	var t_metal = _tex(func(img: Image):
		_rect(img, 0, 0, 64, 64, Color("4a4c55"))
		_rect(img, 0, 31, 64, 2, Color("34363d"))
		_rect(img, 31, 0, 2, 64, Color("34363d"))
		for p in [[4, 4], [58, 4], [4, 58], [58, 58], [26, 26], [36, 36], [26, 36], [36, 26]]:
			_rect(img, p[0], p[1], 2, 2, Color("8a8c95")))
	var t_crate = _tex(func(img: Image):
		_rect(img, 0, 0, 64, 64, Color("6a4426"))
		for i in range(0, 64, 16): _rect(img, i, 0, 2, 64, Color("3a2414"))
		_rect(img, 0, 0, 64, 4, Color("3a2414"))
		_rect(img, 0, 60, 64, 4, Color("3a2414")))
	var m_floor = _mat_tex(t_floor)
	var m_wall = _mat_tex(t_wall)
	var m_metal = _mat_tex(t_metal)
	var m_crate = _mat_tex(t_crate, 0.5)
	var A = G.A
	box(0, -2, 0, A * 2 + 8, 2, A * 2 + 8, m_floor)
	box(0, 0, -A - 1, A * 2 + 4, 16, 2, m_wall)
	box(0, 0, A + 1, A * 2 + 4, 16, 2, m_wall)
	box(-A - 1, 0, 0, 2, 16, A * 2, m_wall)
	box(A + 1, 0, 0, 2, 16, A * 2, m_wall)
	var red = Color("ff2a1a")
	deco(Vector3(0, 11, -A + .05), Vector3(A * 2, .35, .1), red)
	deco(Vector3(0, 11, A - .05), Vector3(A * 2, .35, .1), red)
	deco(Vector3(-A + .05, 11, 0), Vector3(.1, .35, A * 2), red)
	deco(Vector3(A - .05, 11, 0), Vector3(.1, .35, A * 2), red)
	for p in [[15, 15], [-15, 15], [15, -15], [-15, -15]]:
		box(p[0], 0, p[1], 4, 12, 4, m_metal)
		deco(Vector3(p[0], 12.1, p[1]), Vector3(4.2, .2, 4.2), Color("ffb040"))
	box(0, 0, -26, 18, 2.2, 6, m_metal)
	box(0, 0, 26, 18, 2.2, 6, m_metal)
	box(-26, 0, 0, 6, 2.2, 18, m_metal)
	box(26, 0, 0, 6, 2.2, 18, m_metal)
	box(0, 0, 0, 7, 1.1, 7, m_metal)
	box(0, 1.1, 0, 3.5, 1.1, 3.5, m_metal)
	deco(Vector3(0, 2.25, 0), Vector3(1.2, .1, 1.2), red)
	for c in [[8, -6, 2], [-9, 7, 2], [-7, -10, 3], [10, 9, 3], [30, -12, 2], [-30, 12, 2], [12, 32, 2], [-12, -32, 2]]:
		box(c[0], 0, c[1], c[2], c[2] * .75, c[2], m_crate)
	box(34, 0, -34, 1.2, 10, 9, m_wall)
	box(-34, 0, 34, 1.2, 10, 9, m_wall)
	box(-34, 0, -34, 9, 10, 1.2, m_wall)
	box(34, 0, 34, 9, 10, 1.2, m_wall)

func world_flash(p: Vector3, e: float) -> void:
	world_light.global_position = p
	world_light.light_energy = max(world_light.light_energy, e)

# ---------------- áudio contínuo ----------------
func _build_audio() -> void:
	for k in MUS:
		var mp = AudioStreamPlayer.new()
		var ms = load(MUS[k]) if ResourceLoader.exists(MUS[k]) else null
		if ms is AudioStreamOggVorbis:
			ms.loop = true
			if k == "final": ms.loop_offset = 5.0  # ao repetir, pula a introdução silenciosa
		mp.stream = ms
		mp.bus = "Musica"
		mp.volume_db = -80
		add_child(mp)
		mus[k] = mp
		mus_w[k] = 0.0
	slide_snd = AudioStreamPlayer.new()
	var ss = G.stream("slide")
	if ss is AudioStreamWAV:
		ss.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ss.loop_begin = 0
		ss.loop_end = int(ss.get_length() * ss.mix_rate) - 1
	slide_snd.stream = ss
	slide_snd.bus = "Efeitos"
	slide_snd.volume_db = -80
	add_child(slide_snd)
	slide_snd.play()

# ---------------- HUD ----------------
func _lbl(text: String, size: int, color := Color.WHITE, outline := 4) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(w: float, h: float, bg: Color, fg: Color) -> Array:
	var back = ColorRect.new()
	back.color = bg
	back.custom_minimum_size = Vector2(w, h)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill = ColorRect.new()
	fill.color = fg
	fill.size = Vector2(w, h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return [back, fill]

func _panel() -> PanelContainer:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.01, 0.015, 0.8)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	sb.skew = Vector2(-0.14, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _build_hud() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	# vinheta de dano e clarão
	var vig = TextureRect.new()
	var gt = GradientTexture2D.new()
	var gr = Gradient.new()
	gr.set_color(0, Color(0.8, 0, 0, 0))
	gr.set_color(1, Color(0.8, 0, 0, 0.75))
	gr.add_point(0.55, Color(0.8, 0, 0, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	vig.texture = gt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.modulate.a = 0
	hud.add_child(vig)
	ui.vig = vig
	var fl = ColorRect.new()
	fl.color = Color.WHITE
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.modulate.a = 0
	hud.add_child(fl)
	ui.flash = fl
	# mira e marcador de acerto
	var cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)
	for r in [Rect2(-1, -12, 2, 7), Rect2(-1, 5, 2, 7), Rect2(-12, -1, 7, 2), Rect2(5, -1, 7, 2)]:
		var c = ColorRect.new()
		c.color = Color.WHITE
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(c)
	var hit = Control.new()
	hit.set_anchors_preset(Control.PRESET_CENTER)
	hit.rotation = PI / 4
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.modulate.a = 0
	hud.add_child(hit)
	for r in [Rect2(-1, -17, 2, 9), Rect2(-1, 8, 2, 9), Rect2(-17, -1, 9, 2), Rect2(8, -1, 9, 2)]:
		var c = ColorRect.new()
		c.color = Color.WHITE
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit.add_child(c)
	ui.hit = hit
	# vitais e arsenal (HUD nova, desenhada em scripts/hud2.gd)
	blood_scr = preload("res://scripts/blood_screen.gd").new()
	hud.add_child(blood_scr)
	hud2 = preload("res://scripts/hud2.gd").new()
	hud2.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud2)
	var kh = _lbl("Q troca · R recarregar · F soco · E terminal", 12, Color(1, 1, 1, .4), 2)
	kh.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kh.position = Vector2(-436, -186)
	kh.custom_minimum_size = Vector2(420, 0)
	kh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(kh)
	ui.fps = _lbl("", 14, Color(1, 1, 1, .7), 3)
	ui.fps.position = Vector2(16, 10)
	ui.fps.visible = G.show_fps
	hud.add_child(ui.fps)
	# estilo (canto superior direito)
	var sty = VBoxContainer.new()
	sty.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sty.position = Vector2(-280, 20)
	sty.custom_minimum_size = Vector2(256, 0)
	sty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sty)
	ui.sty = sty
	ui.rank = _lbl("D", 64, Color.WHITE, 6)
	ui.rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sty.add_child(ui.rank)
	ui.rword = _lbl("DESTRUTIVO", 16)
	ui.rword.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sty.add_child(ui.rword)
	var rb = _bar(256, 5, Color(1, 1, 1, .12), Color.WHITE)
	sty.add_child(rb[0])
	ui.rfill = rb[1]
	var bsp = Control.new()
	bsp.custom_minimum_size = Vector2(0, 6)
	sty.add_child(bsp)
	ui.bword = _lbl("BLASFÊMIA", 13, Color("ff4a3a"), 3)
	ui.bword.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sty.add_child(ui.bword)
	var bb = _bar(256, 9, Color(.25, 0, .02, .7), Color("d01a1a"))
	sty.add_child(bb[0])
	ui.blback = bb[0]
	ui.blfill = bb[1]
	ui.bkey = _lbl("[G] LIBERAR A BLASFÊMIA", 15, Color.WHITE, 4)
	ui.bkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.bkey.visible = false
	sty.add_child(ui.bkey)
	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sty.add_child(feed_box)
	# onda, faixa e chefe
	ui.wave = _lbl("PREPARE-SE", 18)
	ui.wave.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ui.wave.position = Vector2(-150, 18)
	ui.wave.custom_minimum_size = Vector2(300, 0)
	ui.wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(ui.wave)
	var ban = VBoxContainer.new()
	ban.set_anchors_preset(Control.PRESET_CENTER)
	ban.position = Vector2(-400, -200)
	ban.custom_minimum_size = Vector2(800, 0)
	ban.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban.modulate.a = 0
	hud.add_child(ban)
	ui.ban = ban
	ui.bt = _lbl("", 72, Color("e8261a"), 8)
	ui.bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban.add_child(ui.bt)
	ui.bs = _lbl("", 20)
	ui.bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban.add_child(ui.bs)
	# barra do chefe estilizada (scripts/boss_bar.gd), um modelo para cada chefe
	var boss = preload("res://scripts/boss_bar.gd").new()
	boss.anchor_right = 1.0
	boss.offset_top = 8; boss.offset_bottom = 160
	boss.visible = false
	hud.add_child(boss)
	ui.boss = boss
	# aviso do terminal
	ui.prompt = _lbl("[E]  TERMINAL DE ARSENAL", 20, Color("46ff8c"), 3)
	ui.prompt.set_anchors_preset(Control.PRESET_CENTER)
	ui.prompt.position = Vector2(-200, 60)
	ui.prompt.custom_minimum_size = Vector2(400, 0)
	ui.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.prompt.visible = false
	hud.add_child(ui.prompt)
	# luneta do fuzil de raio
	var sc = Control.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.visible = false
	sc.draw.connect(func():
		var sz = sc.size
		var c = sz / 2
		var r = sz.y * .42
		var big = sz.length()
		sc.draw_arc(c, r + big / 2, 0, TAU, 96, Color.BLACK, big)
		sc.draw_arc(c, r, 0, TAU, 96, Color("40e8ff"), 3)
		sc.draw_line(Vector2(c.x - r, c.y), Vector2(c.x - 12, c.y), Color(0, 0, 0, .85), 2)
		sc.draw_line(Vector2(c.x + 12, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, .85), 2)
		sc.draw_line(Vector2(c.x, c.y + 12), Vector2(c.x, c.y + r), Color(0, 0, 0, .85), 2)
		sc.draw_circle(c, 2, Color("ff3a2a")))
	sc.resized.connect(sc.queue_redraw)
	hud.add_child(sc)
	hud.move_child(sc, 2)
	ui.scope = sc

func banner(t: String, s := "") -> void:
	ui.bt.text = t
	ui.bs.text = s
	var tw = create_tween()
	tw.tween_property(ui.ban, "modulate:a", 1.0, .25)
	tw.tween_interval(1.6)
	tw.tween_property(ui.ban, "modulate:a", 0.0, .35)

func _on_style(label: String) -> void:
	var l = _lbl("+ " + label, 16, Color.WHITE, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed_box.add_child(l)
	feed_box.move_child(l, 0)
	while feed_box.get_child_count() > 6:
		feed_box.get_child(feed_box.get_child_count() - 1).queue_free()
		feed_box.remove_child(feed_box.get_child(feed_box.get_child_count() - 1))
	var tw = create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, .45)
	tw.tween_callback(l.queue_free)

func on_weapon_changed() -> void:
	if hud2 == null or player == null: return
	var w = player.weapons
	var slots = []
	for n in G.loadout.size():
		var k = G.loadout[n]
		slots.append({"short": G.WEAP[k].short, "cur": k == w.cur})
	hud2.push({"wname": G.WEAP[w.cur].name, "slots": slots})
	var md = w.W()
	var src = md.get("root")
	if w.id() == "sword" and w.X.sw.size() > 0: src = w.X.sw[0].vm
	hud2.set_preview(w.id(), src)

func _upd_hud(dt: float) -> void:
	var p = player
	var w = p.weapons
	var id: String = w.id()
	var X = w.X
	var d = {"hp": p.hp, "stam": p.stamina, "walls": p.wall_jumps, "status": "", "reload": 0.0, "inf": false, "bar": 0.0, "bar_col": Color("40e8ff")}
	match id:
		"rev":
			d.ammo = w.rv_ammo; d.max = w.rv_max; d.kind = "bullet"
			if w.charging:
				d.bar = w.charge
				if w.charge > .1: d.status = "RICOCHETE ×%d" % w.bounces(w.charge)
			if w.rv_reloading: d.reload = clamp(w.rv_t / w.PR_END, 0.0, 1.0)
		"sg":
			d.ammo = w.sg_ammo; d.max = w.sg_max; d.kind = "shell"
			if w.sg_reloading: d.reload = clamp(float(w.sg_ammo) / w.sg_max, 0.0, 1.0)
		"rocket":
			var ai = X.ammo_info(id)
			d.ammo = ai[0]; d.max = 1; d.kind = "rocket"
		"sword":
			var ai = X.ammo_info(id)
			d.ammo = ai[0]; d.max = 4; d.kind = "sword"
		"nail":
			d.inf = true
			d.bar = X.heat if X.over <= 0 else 1.0
			d.bar_col = Color("ff3a1a") if X.over > 0 else Color("ff9a30")
			if X.over > 0: d.status = "SUPERAQUECIDA"
		"rail":
			d.inf = true
			d.bar = 1.0 - w.cd / X.rail_max if w.cd > 0 else 1.0
			if w.cd <= 0: d.status = "PRONTO"
		_:
			d.inf = true
	if not d.has("ammo"): d.ammo = 0; d.max = 0; d.kind = ""
	d.blood = G.blood
	d.cost = G.BLOOD_COST.get(id, 0.0)
	if d.inf and d.cost > 0: d.shots = int(G.blood / d.cost)
	hud2.push(d)
	var scoped: bool = id == "rail" and w.zoom and X.zb > .7 and G.state == "play"
	ui.scope.visible = scoped
	vpc2.visible = not scoped and not player.frozen
	if term_light: _upd_term()
	ui.prompt.visible = near_term and G.state == "play"
	G.hurt_v *= exp(-dt * 3)
	G.flash *= exp(-dt * 8)
	G.hit_v *= exp(-dt * 10)
	ui.vig.modulate.a = max(G.hurt_v, (.35 + sin(Time.get_ticks_msec() / 180.0) * .15) if p.hp < 30 else 0.0)
	ui.flash.modulate.a = G.flash
	ui.hit.modulate = Color(1, .2, .1, G.hit_v) if G.hit_kill else Color(1, 1, 1, G.hit_v)
	if G.show_fps: ui.fps.text = "%d FPS" % Engine.get_frames_per_second()
	# estilo
	var rk = G.rank()
	if not G.blas_on: G.style = max(0.0, G.style - dt * (5 + rk * 4))
	var r2 = int(G.style / 100.0)
	G.best_rank = max(G.best_rank, r2)
	if r2 != shown_rank:
		var R = G.RANKS[r2]
		ui.rank.text = R[0]
		ui.rword.text = R[1]
		ui.sty.modulate = R[2]
		if r2 > shown_rank:
			ui.rank.pivot_offset = ui.rank.size * Vector2(1, .5)
			ui.rank.scale = Vector2.ONE * 1.5
			create_tween().tween_property(ui.rank, "scale", Vector2.ONE, .3)
		shown_rank = r2
	ui.rfill.size.x = 256.0 * fmod(G.style, 100.0) / 100.0
	_upd_blas_hud()
	ui.sty.modulate.a = 1.0 if (G.style > 0 or feed_box.get_child_count() > 0) else .35
	if G.mode == "boss" or G.mode == "deus" or G.mode == "miguel" or G.mode == "lilith" or G.mode == "azazel": ui.wave.text = ""
	elif G.mode == "train": ui.wave.text = "TREINO · ESC PAUSA"
	elif wave > 0: ui.wave.text = "ONDA %d · %d RESTANTES" % [wave, G.enemies.size() + queue.size()]
	else: ui.wave.text = "PREPARE-SE"
	var bs = G.boss
	if bs and is_instance_valid(bs) and bs.alive and bs.spawn_t <= 0 and not bs.get("cine"):
		ui.boss.visible = true
		var wv: float = max(0.0, bs.hp / bs.max_hp * 100.0)
		if wv < b_last:
			b_hold = .6
			b_last = wv
		if b_hold > 0: b_hold -= dt
		else: b_dmg_w += (wv - b_dmg_w) * (1.0 - exp(-4 * dt))
		b_dmg_w = max(b_dmg_w, wv)
		ui.boss.set_hp(wv / 100.0, b_dmg_w / 100.0)
	else:
		ui.boss.visible = false
		b_dmg_w = 100; b_last = 100

# ---------------- menus ----------------
func _btn(text: String, cb: Callable, alt := false) -> Button:
	var b = Button.new()
	b.text = "  " + text + "  "
	b.add_theme_font_size_override("font_size", 24)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("2a2c33") if alt else Color("e8261a")
	sb.set_content_margin_all(12)
	sb.skew = Vector2(-0.14, 0)
	var sh: StyleBoxFlat = sb.duplicate()
	sh.bg_color = Color("3a3d46") if alt else Color("ff3a2a")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", sh)
	b.custom_minimum_size = Vector2(170, 52)
	b.pressed.connect(cb)
	return b

func _build_menus() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu = preload("res://scripts/menu_ui.gd").new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	menu.setup(self)
	# tela de morte
	dead_ov = ColorRect.new()
	dead_ov.color = Color(0.06, 0.01, 0.015, 0.9)
	dead_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	dead_ov.visible = false
	layer.add_child(dead_ov)
	var c2 = CenterContainer.new()
	c2.set_anchors_preset(Control.PRESET_FULL_RECT)
	dead_ov.add_child(c2)
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 18)
	c2.add_child(v2)
	v2.add_child(_lbl("VOCÊ CAIU", 84, Color("e8261a"), 10))
	ui.dstats = _lbl("", 22)
	v2.add_child(ui.dstats)
	var dh = HBoxContainer.new()
	dh.add_theme_constant_override("separation", 14)
	v2.add_child(dh)
	dh.add_child(_btn("DE NOVO", func(): start_mode(G.mode)))
	dh.add_child(_btn("MENU", func(): quit_to_menu(), true))
	_build_term_ui(layer)

func show_menu(paused: bool) -> void:
	G.state = "paused" if paused else "menu"
	dead_ov.visible = false
	menu.open(paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.fire_held = false
	player.weapons.alt_release()

func resume() -> void:
	G.state = "play"
	term_ov.visible = false
	menu.visible = false
	dead_ov.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func start_mode(m: String) -> void:
	G.mode = m
	reset()
	started = true
	resume()

func _store_record() -> void:
	if not started or G.stats.t < 1.0: return
	var r: Dictionary = G.rec.get(G.mode, {})
	r["rank"] = max(int(r.get("rank", 0)), G.best_rank)
	r["kills"] = max(int(r.get("kills", 0)), int(G.stats.kills))
	if G.mode == "waves": r["wave"] = max(int(r.get("wave", 0)), wave)
	G.rec[G.mode] = r
	G.save()

func quit_to_menu() -> void:
	_store_record()
	started = false
	reset()
	for e in G.enemies:
		if is_instance_valid(e): e.queue_free()
	G.enemies.clear()
	if G.boss and is_instance_valid(G.boss): G.boss.queue_free()
	G.boss = null
	G.clear_timers()
	show_menu(false)

func die() -> void:
	_store_record()
	player.dead = true
	G.state = "dead"
	var t = int(G.stats.t)
	ui.dstats.text = "ONDA %d     ABATES %d     MELHOR RANK %s     TEMPO %d:%02d" % [wave, G.stats.kills, G.RANKS[G.best_rank][0], t / 60, t % 60]
	dead_ov.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset() -> void:
	_store_record()
	if gibs: gibs.clear()
	for e in G.enemies:
		if is_instance_valid(e): e.queue_free()
	G.enemies.clear()
	if G.boss and is_instance_valid(G.boss): G.boss.queue_free()
	G.boss = null
	for gb in get_tree().get_nodes_in_group("gabriel"): gb.queue_free()
	for gb in get_tree().get_nodes_in_group("miguel"): gb.queue_free()
	for gb in get_tree().get_nodes_in_group("lilith"): gb.queue_free()
	for gb in get_tree().get_nodes_in_group("azazel"): gb.queue_free()
	for p in G.projs:
		if is_instance_valid(p.m): p.m.queue_free()
	G.projs.clear()
	G.clear_timers()
	_set_level({"deus": "trono", "miguel": "miguel", "boss": "gabriel", "lilith": "lilith", "azazel": "azazel"}.get(G.mode, "arena"))
	player.reset_at({"trono": Vector3(0, 2.3, 104), "miguel": Vector3(0, 2.3, 30), "lilith": Vector3(0, 2.3, 32), "azazel": Vector3(0, 2.3, 30), "gabriel": gabriel_arena.HALL + Vector3(0, 2.3, 40)}.get(level, Vector3(0, 2.3, 26)))
	if level == "gabriel":
		gabriel_arena.start_hall()
		apply_env("gabriel_hall")
	player.weapons.reset_ammo()
	player.weapons.switch_to(G.loadout[0], true)
	wave = 0
	queue.clear()
	wave_active = false
	wave_delay = 1.2
	G.style = 0
	G.best_rank = 0
	G.blas = 0.0
	_blas_end(true)
	G.stats = {"kills": 0, "t": 0.0}
	G.blood = 120.0
	if blood_scr: blood_scr.clear()
	for c in feed_box.get_children(): c.queue_free()
	if G.mode == "boss":
		pass # Gabriel só aparece quando o jogador atravessa o portão da entrada (gabriel_enter)
	elif G.mode == "miguel":
		G.later(1.5, respawn_miguel)
	elif G.mode == "lilith":
		G.later(1.5, respawn_lilith)
	elif G.mode == "azazel":
		G.later(1.5, respawn_azazel)
	elif G.mode == "deus":
		spawn_deus_cine()
	elif G.mode == "train":
		for d in [["husk", -8, 12], ["husk", 0, 8], ["husk", 8, 12], ["brute", 0, -8], ["drone", -14, 4], ["drone", 14, 4]]:
			spawn_enemy(d[0], Vector3(d[1], 0, d[2]), true)
		banner("TREINO", "ALVOS INFINITOS")

# ---------------- inimigos e ondas ----------------
func _set_level(l: String) -> void:
	if trono == null: return
	if l != level:
		var roots = {"arena": arena_root, "trono": trono, "miguel": miguel_arena, "gabriel": gabriel_arena, "lilith": lilith_arena, "azazel": azazel_arena}
		world.remove_child(roots[level])
		world.add_child(roots[l])
		level = l
	if trono: trono.reset_state()
	if miguel_arena: miguel_arena.reset_state()
	if gabriel_arena: gabriel_arena.reset_state()
	if lilith_arena: lilith_arena.reset_state()
	if azazel_arena: azazel_arena.reset_state()
	apply_env(level)

func apply_env(name: String) -> void:
	var E: Dictionary = LEVEL_ENV[name]
	for k in E:
		if k != "sun": world_env.set(k, E[k])
	world_sun.light_energy = E.sun
	world_sun.light_color = {"arena": Color("ffe2c4"), "lilith": Color("ff5a2a"), "miguel": Color("c8b8ff"), "gabriel": Color("ffd9a8"), "gabriel_hall": Color("ff7a70"), "gabriel_inferno": Color("ff3a20"), "azazel": Color("9ab4ff"), "azazel2": Color("ff4a3a")}.get(name, Color("fff4e8"))
	# o Átrio das Trombetas tem céu de amanhecer de verdade (degradê), as outras arenas usam cor lisa
	if name == "gabriel_hall":
		if _hall_sky == null:
			var hm = ProceduralSkyMaterial.new()
			hm.sky_top_color = Color("1a0103")
			hm.sky_horizon_color = Color("a8141a")
			hm.sky_curve = .2
			hm.ground_horizon_color = Color("6a1012")
			hm.ground_bottom_color = Color("1a0203")
			_hall_sky = Sky.new()
			_hall_sky.sky_material = hm
		world_env.sky = _hall_sky
		world_env.background_mode = Environment.BG_SKY
		world_env.fog_sky_affect = .4
	elif name == "azazel" or name == "azazel2":
		var red = name == "azazel2"
		if (_blood_sky if red else _storm_sky) == null:
			var ss = ProceduralSkyMaterial.new()
			ss.sky_top_color = Color("1a0000") if red else Color("02040a")
			ss.sky_horizon_color = Color("6a0a08") if red else Color("243250")
			ss.sky_curve = .18
			ss.ground_horizon_color = Color("3a0404") if red else Color("141c30")
			ss.ground_bottom_color = Color("080000") if red else Color("020306")
			var sk = Sky.new(); sk.sky_material = ss
			if red: _blood_sky = sk
			else: _storm_sky = sk
		world_env.sky = _blood_sky if red else _storm_sky
		world_env.background_mode = Environment.BG_SKY
		world_env.fog_sky_affect = .35
	elif name == "gabriel_inferno":
		if _hell_sky == null:
			var hs = ProceduralSkyMaterial.new()
			hs.sky_top_color = Color("120000")
			hs.sky_horizon_color = Color("c0180c")
			hs.sky_curve = .15
			hs.ground_horizon_color = Color("8a0e06")
			hs.ground_bottom_color = Color("200101")
			_hell_sky = Sky.new()
			_hell_sky.sky_material = hs
		world_env.sky = _hell_sky
		world_env.background_mode = Environment.BG_SKY
		world_env.fog_sky_affect = .3
	elif name == "gabriel":
		if _dawn_sky == null:
			var sm = ProceduralSkyMaterial.new()
			sm.sky_top_color = Color("5f95d8")
			sm.sky_horizon_color = Color("fff1dc")
			sm.sky_curve = .14
			sm.ground_horizon_color = Color("f6ead8")
			sm.ground_bottom_color = Color("d4cce0")
			sm.sun_angle_max = 8.0
			_dawn_sky = Sky.new()
			_dawn_sky.sky_material = sm
		world_env.sky = _dawn_sky
		world_env.background_mode = Environment.BG_SKY
		world_env.fog_sky_affect = .25
	else:
		world_env.background_mode = Environment.BG_COLOR
		world_env.fog_sky_affect = 1.0

## atravessou o portão da entrada: luz branca e o Átrio das Trombetas
func gabriel_enter() -> void:
	G.flash = 1.0
	G.snd("angel", -2, .6)
	apply_env("gabriel")
	player.global_position = Vector3(0, 2.3, 34)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	banner("ÁTRIO DAS TROMBETAS", "O ARAUTO TE ESPERA")
	G.later(1.6, respawn_gabriel)

## Deus já espera no alto do altar; a luta só começa depois da cutscene.
func spawn_deus_cine() -> void:
	if not ResourceLoader.exists("res://deus/deus.glb"): return
	var dn = Node3D.new()
	dn.set_script(preload("res://scripts/deus.gd"))
	world.add_child(dn)
	dn.setup(Vector3(0, 0, -60))
	dn.cine = true
	dn.inv = true
	dn.spawn_t = 0.0
	dn.global_position = trono.DEUS_POS
	dn.rotation.y = 0.0
	G.boss = dn
	G.enemies.append(dn)
	trono.deus = dn
	if ui.has("boss"): ui.boss.set_boss("deus")

func respawn_deus() -> void:
	if G.mode == "deus" and G.boss == null: spawn_enemy("deus", Vector3(0, 0, -30))

func respawn_lilith() -> void:
	if G.mode == "lilith" and G.boss == null: spawn_enemy("lilith", Vector3(0, 0, -16))

## segunda fase da Lilith: a caverna se acende
func lilith_inferno() -> void:
	if level != "lilith": return
	var tw = create_tween().set_parallel(true)
	tw.tween_property(world_env, "background_color", Color("2a0502"), 2.0)
	tw.tween_property(world_env, "fog_light_color", Color("5a1004"), 2.0)
	tw.tween_property(world_env, "ambient_light_color", Color("b07070"), 2.0)

func respawn_azazel() -> void:
	if G.mode == "azazel" and G.boss == null:
		if azazel_arena: azazel_arena.reset_state()
		if level == "azazel": apply_env("azazel")
		spawn_enemy("azazel", Vector3(0, 0, -18))

## o Azazel começou a chorar sangue: a tempestade vira sangue
func azazel_bleed() -> void:
	if level == "azazel": G.later(1.5, func(): if level == "azazel": apply_env("azazel2"))

func respawn_miguel() -> void:
	if G.mode == "miguel" and G.boss == null: spawn_enemy("miguel", Vector3(0, 0, -18))

## segunda fase de Miguel: o céu da arena escurece
func miguel_eclipse() -> void:
	if level != "miguel": return
	var tw = create_tween().set_parallel(true)
	tw.tween_property(world_env, "background_color", Color("050003"), 2.0)
	tw.tween_property(world_env, "fog_light_color", Color("2a0408"), 2.0)
	tw.tween_property(world_env, "ambient_light_color", Color("d08080"), 2.0)
	tw.tween_property(world_sun, "light_color", Color("ff6a5a"), 2.0)

func respawn_gabriel() -> void:
	if G.mode == "boss" and G.boss == null:
		if gabriel_arena: gabriel_arena.purify()
		spawn_enemy("gabriel", Vector3(0, 0, -30))

func spawn_point() -> Vector3:
	for i in 20:
		var a = G.rnd(0, TAU)
		var r = G.rnd(22, 38)
		var p = Vector3(cos(a) * r, 0.5, sin(a) * r)
		if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < 18: continue
		if G.in_solid(p + Vector3(0, 0.6, 0)): continue
		return p
	return Vector3(0, 0.5, -36)

func spawn_enemy(kind: String, at = null, dummy := false) -> void:
	var p: Vector3 = at if at != null else spawn_point()
	if kind == "deus":
		if not ResourceLoader.exists("res://deus/deus.glb"): return
		var dn = Node3D.new()
		dn.set_script(preload("res://scripts/deus.gd"))
		world.add_child(dn)
		dn.setup(p if at != null else Vector3(0, 0, -30))
		G.boss = dn
		G.enemies.append(dn)
		if ui.has("boss"): ui.boss.set_boss("deus")
		banner("DEUS", "AQUELE QUE TUDO VÊ")
		G.snd("angel", -2, .45)
		G.flash = .8
		return
	if kind == "azazel":
		if not ResourceLoader.exists("res://azazel/azazel.glb"): return
		var az = Node3D.new()
		az.set_script(preload("res://scripts/azazel.gd"))
		world.add_child(az)
		az.setup(p)
		G.boss = az
		G.enemies.append(az)
		if ui.has("boss"): ui.boss.set_boss("azazel")
		banner("AZAZEL", "O VIGIA DA TEMPESTADE")
		G.flash = .5
		return
	if kind == "lilith":
		if not ResourceLoader.exists("res://lilith/lilith.glb"): return
		var lg = Node3D.new()
		lg.set_script(preload("res://scripts/lilith.gd"))
		world.add_child(lg)
		lg.setup(p)
		G.boss = lg
		G.enemies.append(lg)
		if ui.has("boss"): ui.boss.set_boss("lilith")
		banner("LILITH", "A RAINHA DO ABISMO")
		G.snd("angel", -2, .3)
		G.flash = .5
		return
	if kind == "miguel":
		if not ResourceLoader.exists("res://miguel/miguel.glb"): return
		var mg = Node3D.new()
		mg.set_script(preload("res://scripts/miguel.gd"))
		world.add_child(mg)
		mg.setup(p)
		G.boss = mg
		G.enemies.append(mg)
		if ui.has("boss"): ui.boss.set_boss("miguel")
		banner("MIGUEL", "O ARCANJO VELADO")
		G.snd("angel", -2, .5)
		G.flash = .5
		return
	if kind == "gabriel":
		if not ResourceLoader.exists("res://gabriel.glb"): return
		var g = Node3D.new()
		g.set_script(preload("res://scripts/gabriel.gd"))
		world.add_child(g)
		g.setup(p)
		G.boss = g
		G.enemies.append(g)
		if ui.has("boss"): ui.boss.set_boss("gabriel")
		banner("GABRIEL", "O ARAUTO DE MUITOS OLHOS")
		G.snd("angel", -4)
		G.flash = .6
		return
	var e = CharacterBody3D.new()
	e.set_script(preload("res://scripts/enemy.gd"))
	world.add_child(e)
	e.setup(kind, Vector3(p.x, 0.5, p.z), dummy)
	G.enemies.append(e)
	G.emit("blood2", Vector3(p.x, .3, p.z), 14, 8, .15, .6)
	G.snd("spawn", -14)

func _start_wave() -> void:
	wave += 1
	wave_active = true
	queue.clear()
	if wave % 10 == 0:
		queue.append("deus")
		for i in wave / 2: queue.append("husk")
		banner("ONDA %d" % wave, "DEUS DESPERTA")
		G.snd("wave", -6)
		return
	if wave % 5 == 0:
		queue.append("gabriel")
		for i in wave: queue.append("husk")
		banner("ONDA %d" % wave, "GABRIEL DESCE")
		G.snd("wave", -6)
		return
	for i in 2 + wave * 2: queue.append("husk")
	for i in wave: queue.append("drone")
	for i in (int((wave - 1) / 2.0) if wave >= 3 else 0): queue.append("brute")
	queue.shuffle()
	banner("ONDA %d" % wave, "%d INIMIGOS" % queue.size())
	G.snd("wave", -6)

func _upd_waves(dt: float) -> void:
	if G.mode != "waves": return
	if not wave_active:
		wave_delay -= dt
		if wave_delay <= 0: _start_wave()
		return
	spawn_cd -= dt
	if queue.size() > 0 and spawn_cd <= 0 and G.enemies.size() < 12:
		spawn_enemy(queue.pop_front())
		spawn_cd = .7
	if queue.is_empty() and G.enemies.is_empty():
		wave_active = false
		wave_delay = 3.5
		G.heal(25)
		banner("ONDA %d LIMPA" % wave, "+25 VIDA")

# marcadores sobre os últimos inimigos (visíveis através das paredes)
var _mark_mesh: SphereMesh
var _mark_mat: StandardMaterial3D
func _upd_marks() -> void:
	var normal = []
	for e in G.enemies:
		if not e.is_boss: normal.append(e)
	var show: bool = G.mode != "train" and (G.mode == "boss" or G.mode == "deus" or G.mode == "miguel" or G.mode == "lilith" or G.mode == "azazel" or queue.is_empty()) and normal.size() <= 3
	if _mark_mesh == null:
		_mark_mesh = SphereMesh.new()
		_mark_mesh.radius = .32; _mark_mesh.height = .64; _mark_mesh.radial_segments = 4; _mark_mesh.rings = 1
		_mark_mat = StandardMaterial3D.new()
		_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mark_mat.albedo_color = Color("ff2a1a")
		_mark_mat.no_depth_test = true
		_mark_mat.render_priority = 10
	for e in normal:
		if e.mark == null:
			e.mark = MeshInstance3D.new()
			e.mark.mesh = _mark_mesh
			e.mark.material_override = _mark_mat
			world.add_child(e.mark)
		e.mark.visible = show and e.spawn_t <= 0
		if e.mark.visible:
			var hh: float = 1.6 if e.fly else e.h + .7
			e.mark.global_position = e.global_position + Vector3(0, hh + sin(Time.get_ticks_msec() / 200.0) * .15, 0)
			e.mark.rotation.y += .05

# ---------------- projéteis inimigos (esferas e penas) ----------------
var _orb_mesh: SphereMesh
func spawn_orb(pos: Vector3, vel: Vector3) -> void:
	if _orb_mesh == null:
		_orb_mesh = SphereMesh.new()
		_orb_mesh.radius = .32; _orb_mesh.height = .64; _orb_mesh.radial_segments = 8; _orb_mesh.rings = 4
	var m = MeshInstance3D.new()
	m.mesh = _orb_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff7a1a")
	m.material_override = mat
	world.add_child(m)
	m.global_position = pos
	var pr = {"m": m, "mat": mat, "vel": vel, "owner": "enemy", "life": 7.0, "big": false}
	_orb_fx(pr)
	G.projs.append(pr)

## brilho (halo + estrela girando) e rastro de luz nas esferas
func _orb_fx(pr: Dictionary) -> void:
	var m: MeshInstance3D = pr.m
	var g = MeshInstance3D.new(); var q = QuadMesh.new(); q.size = Vector2.ONE * 2.4; g.mesh = q
	var gm = G.fx.mat("circle_05", Color(1, 1, 1, .9), true, 1)
	g.material_override = gm; m.add_child(g)
	var s = MeshInstance3D.new(); var q2 = QuadMesh.new(); q2.size = Vector2.ONE * 1.6; s.mesh = q2
	var sm = G.fx.mat("star_08", Color(1, 1, 1, 1), true, 1)
	s.material_override = sm; m.add_child(s)
	var tr = CPUParticles3D.new()
	tr.amount = 24; tr.lifetime = .35; tr.local_coords = false
	tr.gravity = Vector3.ZERO; tr.initial_velocity_min = 0; tr.initial_velocity_max = .5; tr.spread = 180
	var tq = QuadMesh.new(); tq.size = Vector2.ONE * .9
	var tm = G.fx.mat("circle_05", Color(1, 1, 1, .7), true, 2)
	tq.material = tm; tr.mesh = tq
	var cv = Curve.new(); cv.add_point(Vector2(0, 1)); cv.add_point(Vector2(1, 0)); tr.scale_amount_curve = cv
	m.add_child(tr)
	pr.gm = gm; pr.sm = sm; pr.tm = tm

var _fth_mesh: BoxMesh
func spawn_feather(pos: Vector3, vel: Vector3) -> void:
	if _fth_mesh == null:
		_fth_mesh = BoxMesh.new()
		_fth_mesh.size = Vector3(.16, .5, 1.8)
	var m = MeshInstance3D.new()
	m.mesh = _fth_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff4dc")
	m.material_override = mat
	world.add_child(m)
	m.global_position = pos
	m.look_at(pos + vel, Vector3.UP)
	G.projs.append({"m": m, "mat": mat, "vel": vel, "owner": "enemy", "life": 6.0, "big": false, "feather": true})

func parry_proj(p: Dictionary, d: Vector3) -> void:
	p.owner = "player"
	p.big = true
	p.mat.albedo_color = Color("bff8ff")
	p.vel = d * 85.0
	p.life = 4.0
	G.later(.25, func():
		if is_instance_valid(p.m):
			world_flash(p.m.global_position, 12)
			G.emit("cyan", p.m.global_position, 22, 18, .14, .5)
			G.emit("spark", p.m.global_position, 16, 20, .1, .4))

func _upd_projs(dt: float, t: float) -> void:
	for p in G.projs:
		if p.life <= 0: continue
		p.life -= dt
		var m: MeshInstance3D = p.m
		if p.has("grav") and p.owner == "enemy": p.vel.y -= p.grav * dt
		m.global_position += p.vel * dt
		if not p.get("feather", false):
			m.scale = Vector3.ONE * (1.9 if p.big else 1.0) * (1 + sin(t * 30) * .15)
			if p.has("gm"):
				var c: Color = p.mat.albedo_color
				p.gm.albedo_color = Color(c.r, c.g, c.b, .85); p.tm.albedo_color = Color(c.r, c.g, c.b, .6)
				p.sm.albedo_color = Color(lerp(c.r, 1.0, .6), lerp(c.g, 1.0, .6), lerp(c.b, 1.0, .6), 1)
		var q = m.global_position
		if p.owner == "enemy":
			if q.distance_to(player.global_position + Vector3(0, .9, 0)) < 1.0 and G.hurt_player(20):
				p.life = 0
		else:
			G.emit("cyan" if G.rng.randf() < .5 else "spark", q, 2, 2, .12, .35, Vector3.ZERO, 0)
			for e in G.enemies.duplicate():
				if not is_instance_valid(e) or not e.alive or e.spawn_t > 0: continue
				if q.distance_to(e.center()) < e.r + 1.3:
					G.hurt_enemy(e, 220, "parry", q, false, p.vel.normalized())
					G.blast(q, 1.0, "parry")
					p.life = 0
					break
		if p.life > 0 and G.in_solid(q):
			if p.owner == "enemy": G.emit("spark", q, 8, 8, .1, .4)
			else: G.blast(q, 1.0, "parry")
			p.life = 0
		if p.life <= 0: m.queue_free()
	G.projs = G.projs.filter(func(p): return p.life > 0)

# ---------------- hitstop (congelar o tempo) ----------------
func hitstop(t: float) -> void:
	Engine.time_scale = 0.03
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

# ---------------- laço ----------------
func _physics_process(dt: float) -> void:
	world_light.light_energy *= exp(-dt * 14)
	if G.state != "play":
		return
	G.stats.t += dt
	G.tick_timers(dt)
	G.enemies = G.enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	_separate()
	_upd_waves(dt)
	_upd_projs(dt, Time.get_ticks_msec() / 1000.0)
	_upd_marks()

func _separate() -> void:
	var es: Array = G.enemies
	for i in es.size():
		for j in range(i + 1, es.size()):
			var a = es[i]
			var b = es[j]
			if a.fly != b.fly or a.is_boss or b.is_boss: continue
			var d = Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
			var l = d.length()
			var mn: float = a.r + b.r
			if l > 0 and l < mn:
				var push = d / l * (mn - l) * 0.5
				a.velocity -= Vector3(push.x, 0, push.y) * 8
				b.velocity += Vector3(push.x, 0, push.y) * 8

func _process(dt: float) -> void:
	if _aim_e != null and is_instance_valid(_aim_e):
		var de = _aim_e.global_position + Vector3(0, 1.2, 0) - (player.global_position + Vector3(0, 1.6, 0))
		player.yaw = atan2(-de.x, -de.z)
		player.pitch = clamp(atan2(de.y, Vector2(de.x, de.z).length()), -1.2, 1.2)
		player.hp = max(player.hp, 1000.0)
		player.velocity.x = 0; player.velocity.z = 0
		if G.stats.t > 2.6:
			player.global_position = Vector3(_aim_e.global_position.x + 1.5, player.global_position.y, _aim_e.global_position.z + 4.6)
	if _aim_boss and is_instance_valid(G.boss) and G.boss != null:
		var d = (G.boss.center() + (Vector3(0, 6, 0) if G.boss.kind == "deus" else Vector3.ZERO)) - (player.global_position + Vector3(0, 1.6, 0))
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = clamp(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
		player.hp = max(player.hp, 1000.0)
	_upd_hud(dt)
	# som contínuo do deslize
	var sl: bool = G.state == "play" and player.sliding and player.is_on_floor()
	var target = -10.0 if sl else -60.0
	slide_snd.volume_db = lerp(slide_snd.volume_db, target, 1.0 - exp(-(25.0 if sl else 10.0) * dt))
	_upd_music()


# ---------------- música em camadas ----------------
## coro sempre nas ondas; fúria entra conforme o rank; Deus ganha a camada de sangue na fase 2.
func _upd_music() -> void:
	var now = Time.get_ticks_usec()
	var dt = clamp((now - _mus_us) / 1000000.0, 0.0, .1) if _mus_us > 0 else 0.016
	_mus_us = now
	var tgt = {}
	for k in MUS: tgt[k] = 0.0
	var boss_ok: bool = G.boss != null and is_instance_valid(G.boss) and G.boss.alive
	if G.state == "menu":
		tgt.menu = 1.0
	elif started and level == "trono" and trono.stage != "fight":
		tgt.menu = .25 if trono.stage == "cut" else .85
		if G.state == "paused": tgt.menu *= .4
	elif started:
		if boss_ok and G.boss.kind == "deus" and level == "trono" and mus.final.stream != null:
			tgt.final = 1.0
		elif boss_ok and G.boss.kind == "deus":
			tgt.deus = 1.0
			tgt.sangue = 1.0 if G.boss.ph2 else 0.0
		elif boss_ok:
			tgt.gabriel = 1.0
		else:
			var fighting: bool = G.enemies.size() > 0 or wave_active or G.mode == "train"
			tgt.coro = 1.0 if fighting else .5
			tgt.furia = clamp((G.style - 100.0) / 250.0, 0.0, 1.0) if fighting else 0.0
			if G.blas_on: tgt.furia = 1.0
		var k2 = {"paused": .55, "term": .6, "dead": .35}.get(G.state, 1.0)
		if G.blas_on and Engine.time_scale < .5: k2 = .12
		for k in tgt: tgt[k] *= k2
	for k in MUS:
		var p: AudioStreamPlayer = mus[k]
		if p.stream == null: continue
		var w: float = mus_w[k]
		var up: float = 2.5 if k == "furia" else 1.2
		var down: float = .35 if k == "furia" else 1.0
		w = move_toward(w, tgt[k], (up if tgt[k] > w else down) * dt)
		mus_w[k] = w
		var grp: Array = MUS_GROUP.get(k, [k])
		if tgt[k] > 0.0 and not p.playing:
			for g in grp: mus[g].play()
		var vol = w * G.mvol
		p.volume_db = (1.0 + linear_to_db(vol)) if vol > .0005 else -80.0
	for k in MUS:
		var grp: Array = MUS_GROUP.get(k, [k])
		var silent = true
		for g in grp:
			if mus_w[g] > .0005 or tgt[g] > 0.0: silent = false
		if silent and mus[k].playing: mus[k].stop()
	# no menu de pausa / terminal a música fica abafada
	var mt: float = 1.0 if (started and (G.state == "paused" or G.state == "term")) else 0.0
	_muffle = move_toward(_muffle, mt, dt * (3.0 if mt > _muffle else 1.6))
	G.set_music_muffle(_muffle)
	mus.gabriel.pitch_scale = 1.06 if (boss_ok and G.boss.kind != "deus" and G.boss.ph2) else 1.0

# ---------------- Blasfêmia ----------------
var _blas_marks: Array = []
var _blas_env_tw: Tween

func _upd_blas_hud() -> void:
	var full: bool = G.blas >= 100.0
	ui.blfill.size.x = 256.0 * G.blas / 100.0
	var pulse = .5 + .5 * sin(Time.get_ticks_msec() / 90.0)
	ui.blfill.color = Color("d01a1a").lerp(Color("ffe0d0"), pulse * .8) if full else Color("d01a1a")
	ui.bkey.visible = full and not G.blas_on
	ui.bkey.modulate = Color(1, .35 + .65 * pulse, .3 + .7 * pulse)
	ui.bword.text = "BLASFÊMIA" + (" · CHEIA" if full else "")
	if G.blas_on:
		ui.rank.text = "SSS"
		ui.rword.text = "DEICIDA"
		ui.sty.modulate = Color(1, .1 + .2 * pulse, .15)
		shown_rank = -1

func _blas_targets() -> Array:
	var out = []
	var cam: Camera3D = G.cam
	var space = world.get_world_3d().direct_space_state
	var list = G.enemies.duplicate()
	if G.boss != null and is_instance_valid(G.boss) and not list.has(G.boss): list.append(G.boss)
	for e in list:
		if not is_instance_valid(e) or not e.alive: continue
		var c: Vector3 = e.center() if e.has_method("center") else e.global_position
		if not cam.is_position_in_frustum(c): continue
		if not e.get("is_boss"):
			var q = PhysicsRayQueryParameters3D.create(cam.global_position, c, 1)
			if space.intersect_ray(q): continue
		out.append(e)
	return out

func blasfemia() -> void:
	if G.blas < 100.0 or G.blas_on or player.frozen: return
	G.blas_on = true
	G.blas = 0.0
	G.snd("blasfemia", 0)
	banner("BLASFÊMIA", "o céu se cala")
	G.shake = max(G.shake, .4)
	var targets = _blas_targets()
	# o céu escurece e fica vermelho
	if _blas_env_tw: _blas_env_tw.kill()
	_blas_env_tw = create_tween().set_parallel().set_ignore_time_scale()
	_blas_env_tw.tween_property(world_env, "background_color", Color("050000"), .35)
	_blas_env_tw.tween_property(world_env, "fog_light_color", Color("120000"), .35)
	_blas_env_tw.tween_property(world_env, "ambient_light_color", Color("ff3020"), .35)
	_blas_env_tw.tween_property(world_env, "ambient_light_energy", .55, .35)
	_blas_env_tw.tween_property(world_sun, "light_energy", 0.0, .35)
	# o tempo para; marcas de julgamento sobre cada alvo
	Engine.time_scale = 0.03
	for e in targets:
		var mk = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = .08
		cm.bottom_radius = .08
		cm.height = 120
		mk.mesh = cm
		var mt: StandardMaterial3D = G.unshaded(Color(1, .1, .05, .35)).duplicate()
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mk.material_override = mt
		world.add_child(mk)
		var c: Vector3 = e.center() if e.has_method("center") else e.global_position
		mk.global_position = c + Vector3(0, 60, 0)
		_blas_marks.append(mk)
	get_tree().create_timer(1.1, true, false, true).timeout.connect(_blas_strike.bind(targets))

func _blas_strike(targets: Array) -> void:
	for mk in _blas_marks:
		if is_instance_valid(mk): mk.queue_free()
	_blas_marks.clear()
	Engine.time_scale = 1.0
	if G.state != "play" and G.state != "paused":
		_blas_end(false)
		return
	G.shake = 1.2
	G.flash = .7
	var n = 0
	for e in targets:
		if not is_instance_valid(e) or not e.alive: continue
		var c: Vector3 = e.center() if e.has_method("center") else e.global_position
		_bolt(c, n * .06)
		var boss: bool = e.get("is_boss") == true
		var dmg: float = e.max_hp * .08 if boss else 99999.0
		var tgt = e
		G.later(n * .06, func():
			if is_instance_valid(tgt) and tgt.alive:
				G.emit("blood", c, 30, 14, .16, .9)
				G.emit("blood2", c, 20, 9, .2, 1.1)
				G.hurt_enemy(tgt, dmg, "blas", c, false))
		n += 1
	G.add_style(150, "BLASFÊMIA")
	G.style = G.RANKS.size() * 100 - 1
	get_tree().create_timer(2.6, true, false, true).timeout.connect(_blas_end.bind(false))

func _bolt(p: Vector3, delay: float) -> void:
	var root = Node3D.new()
	world.add_child(root)
	root.global_position = p
	var segs = 7
	var top = p + Vector3(G.rnd(-6, 6), 70, G.rnd(-6, 6))
	var prev = top
	var mat: StandardMaterial3D = G.unshaded(Color(1, .85, .8)).duplicate()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var hmat: StandardMaterial3D = G.unshaded(Color(1, .05, .02, .35)).duplicate()
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for i in segs:
		var u = float(i + 1) / segs
		var nxt = top.lerp(p, u) + (Vector3(G.rnd(-2.5, 2.5), 0, G.rnd(-2.5, 2.5)) * (1.0 - u) if i < segs - 1 else Vector3.ZERO)
		var m = MeshInstance3D.new()
		var bm = BoxMesh.new()
		var L = prev.distance_to(nxt)
		bm.size = Vector3(.5, .5, L)
		m.mesh = bm
		m.material_override = mat
		root.add_child(m)
		var halo = MeshInstance3D.new()
		var hm = BoxMesh.new()
		hm.size = Vector3(1.6, 1.6, L)
		halo.mesh = hm
		halo.material_override = hmat
		m.add_child(halo)
		m.global_position = (prev + nxt) * .5
		m.look_at(nxt, Vector3.UP if abs((nxt - prev).normalized().y) < .99 else Vector3.RIGHT)
		prev = nxt
	var glow = OmniLight3D.new()
	glow.light_color = Color(1, .2, .1)
	glow.omni_range = 18
	glow.light_energy = 0
	root.add_child(glow)
	root.visible = false
	var tw = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		root.visible = true
		glow.light_energy = 9
		G.snd("raio", -3, G.rnd(.85, 1.1))
		world_flash(p, 6))
	tw.tween_property(mat, "albedo_color", Color(1, .1, .05, 0), .45)
	tw.parallel().tween_property(hmat, "albedo_color", Color(1, .05, .02, 0), .45)
	tw.parallel().tween_property(glow, "light_energy", 0.0, .45)
	tw.tween_callback(root.queue_free)

func _blas_end(instant: bool) -> void:
	for mk in _blas_marks:
		if is_instance_valid(mk): mk.queue_free()
	_blas_marks.clear()
	if G.blas_on and Engine.time_scale < .5: Engine.time_scale = 1.0
	G.blas_on = false
	shown_rank = -1
	if world_env == null: return
	if _blas_env_tw: _blas_env_tw.kill()
	var E: Dictionary = LEVEL_ENV[level]
	var vals = {"background_color": E.background_color, "fog_light_color": E.fog_light_color, "ambient_light_color": E.ambient_light_color, "ambient_light_energy": E.ambient_light_energy}
	if instant:
		for k in vals: world_env.set(k, vals[k])
		world_sun.light_energy = E.sun
		return
	_blas_env_tw = create_tween().set_parallel().set_ignore_time_scale()
	for k in vals: _blas_env_tw.tween_property(world_env, k, vals[k], 1.5)
	_blas_env_tw.tween_property(world_sun, "light_energy", E.sun, 1.5)
