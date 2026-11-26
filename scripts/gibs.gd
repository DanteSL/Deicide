extends Node
## Pedaços de inimigos: voam, giram, quicam no chão e nas paredes e deixam manchas de sangue.
## Roda no _physics_process (afetado pelo tempo do jogo: no congelamento os pedaços ficam parados no ar).

const MAX_GIBS := 140
const MAX_SPLATS := 70
const GRAV := 28.0

var gibs: Array = []
var splats: Array = []
var _splat_mats: Array = []
var _meat: StandardMaterial3D
var _bone: StandardMaterial3D

func _ready() -> void:
	var sh = Shader.new()
	sh.code = preload("res://scripts/trono.gd").BLOOD_SHADER
	for i in 5:
		var m = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("mode", 1)
		m.set_shader_parameter("seed", float(i) * 2.3 + .7)
		_splat_mats.append(m)
	_meat = StandardMaterial3D.new()
	_meat.albedo_color = Color(.42, .02, .03)
	_meat.roughness = .15
	_meat.metallic_specular = .9
	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(.86, .8, .7)
	_bone.roughness = .6

## explode o inimigo 'e' em pedaços; 'src' diz como ele morreu
func explode(e: Node3D, src: String) -> void:
	var world: Node3D = G.world
	var c: Vector3 = e.center()
	var away := Vector3.ZERO
	if G.player:
		away = c - (G.player.global_position + Vector3(0, 1.2, 0))
		away.y = 0
		away = away.normalized() if away.length() > .01 else Vector3.FORWARD
	var strong: bool = src in ["punch", "parry", "slam", "rocket", "gren"]
	var power = 1.7 if strong else 1.0
	var big: bool = e.kind == "brute"
	# 1) peças reais do corpo (brutamonte e drone são montados com peças)
	var parts: Array = []
	if e.ceif == null:
		parts = _meshes(e.vis)
	for m in parts:
		var gt: Transform3D = m.global_transform
		m.get_parent().remove_child(m)
		world.add_child(m)
		m.global_transform = gt
		_add(m, c, away, power, false)
	# 2) Ceifadora: fragmentos de mármore em cada osso do esqueleto
	if e.ceif != null and e.ceif.sk:
		var sk: Skeleton3D = e.ceif.sk
		var mat: Material = e.ceif.mats[0] if e.ceif.mats.size() > 0 else _bone
		for b in sk.get_bone_count():
			if b % 2 == 1 and G.rng.randf() < .5: continue
			var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(b)).origin
			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(G.rnd(.18, .38), G.rnd(.2, .5), G.rnd(.15, .32))
			mi.mesh = bm
			mi.material_override = mat
			world.add_child(mi)
			mi.global_position = p
			mi.rotation = Vector3(G.rnd(0, TAU), G.rnd(0, TAU), G.rnd(0, TAU))
			_add(mi, c, away, power, false)
	# 3) carne e ossos para todo mundo
	var n_meat = 14 if big else (6 if e.fly else 9)
	for i in n_meat:
		var mi = MeshInstance3D.new()
		var mesh: Mesh
		if i % 3 == 0:
			var cm = CylinderMesh.new(); cm.top_radius = .04; cm.bottom_radius = .06; cm.height = G.rnd(.3, .6); cm.radial_segments = 5
			mesh = cm
			mi.material_override = _bone
		else:
			var sm = SphereMesh.new(); sm.radius = G.rnd(.1, .22) * (1.4 if big else 1.0); sm.height = sm.radius * G.rnd(1.2, 2.0)
			sm.radial_segments = 6; sm.rings = 4
			mesh = sm
			mi.material_override = _meat
		mi.mesh = mesh
		world.add_child(mi)
		mi.global_position = c + Vector3(G.rnd(-.3, .3), G.rnd(-.4, .5), G.rnd(-.3, .3))
		_add(mi, c, away, power * 1.15, true)
	# 4) jato de sangue
	G.emit("blood", c, 50 if big else 34, 22 * power, .16, 1.2, away + Vector3(0, .6, 0))
	G.emit("blood2", c, 30, 14, .22, 1.4)
	G.emit("blood", c + Vector3(0, .5, 0), 24, 9, .1, .9)
	# manchas no chão logo abaixo
	for i in (4 if big else 2):
		_splat_at(c + Vector3(G.rnd(-1.2, 1.2), 0, G.rnd(-1.2, 1.2)) + away * G.rnd(0, 2.0), G.rnd(.8, 1.6) * (1.4 if big else 1.0))
	# o tempo congela como no aparo
	G.main.hitstop(.25)
	G.shake = max(G.shake, .35 if strong else .22)
	G.snd("slam", -8, G.rnd(.7, .9))

func _meshes(n: Node) -> Array:
	var out = []
	if n is MeshInstance3D and n.visible: out.append(n)
	for ch in n.get_children(): out += _meshes(ch)
	return out

func _add(m: Node3D, c: Vector3, away: Vector3, power: float, meat: bool) -> void:
	var off = m.global_position - c
	var v = off.normalized() * G.rnd(4, 9) + away * G.rnd(5, 12) + Vector3(0, G.rnd(5, 11), 0)
	gibs.append({"m": m, "v": v * power, "w": Vector3(G.rnd(-12, 12), G.rnd(-12, 12), G.rnd(-12, 12)),
		"life": G.rnd(5.0, 7.5), "bleed": 2 if meat else 1, "rest": false})
	while gibs.size() > MAX_GIBS:
		var g = gibs.pop_front()
		if is_instance_valid(g.m): g.m.queue_free()

func _physics_process(dt: float) -> void:
	if G.state != "play" or gibs.is_empty(): return
	var space = G.world.get_world_3d().direct_space_state
	var keep = []
	for g in gibs:
		var m: Node3D = g.m
		if not is_instance_valid(m): continue
		g.life -= dt
		if g.life <= 0.0:
			m.queue_free()
			continue
		if g.life < .6: m.scale = m.scale.lerp(Vector3.ZERO, clamp(dt * 6.0, 0.0, 1.0))
		if not g.rest:
			g.v.y -= GRAV * dt
			var from = m.global_position
			var to = from + g.v * dt
			var q = PhysicsRayQueryParameters3D.create(from, to, 1)
			var hit = space.intersect_ray(q)
			if hit:
				m.global_position = hit.position + hit.normal * .08
				var vn = g.v.dot(hit.normal)
				var speed = g.v.length()
				g.v = (g.v - hit.normal * vn * 1.4) * .45
				g.w *= .5
				if g.bleed > 0 and speed > 4.0:
					g.bleed -= 1
					_splat_at(hit.position, G.rnd(.35, .8), hit.normal)
				if hit.normal.y > .6 and g.v.length() < 1.2:
					g.rest = true
			else:
				m.global_position = to
				if G.rng.randf() < dt * 6.0: G.emit("blood", to, 2, 2, .08, .5)
			m.rotate_x(g.w.x * dt); m.rotate_y(g.w.y * dt); m.rotate_z(g.w.z * dt)
		keep.append(g)
	gibs = keep

## mancha de sangue numa superfície (chão por padrão)
func _splat_at(p: Vector3, r: float, nrm := Vector3.UP) -> void:
	var q = MeshInstance3D.new()
	var qm = QuadMesh.new(); qm.size = Vector2(r * 2, r * 2)
	q.mesh = qm
	q.material_override = _splat_mats[G.rng.randi() % _splat_mats.size()]
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	G.world.add_child(q)
	if nrm.y > .6:
		# chão: procura a superfície logo abaixo
		var space = G.world.get_world_3d().direct_space_state
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p + Vector3(0, -6, 0), 1))
		if hit: p = hit.position
		q.global_position = p + Vector3(0, .035 + G.rnd(0, .01), 0)
		q.rotation = Vector3(-PI / 2, G.rnd(0, TAU), 0)
	else:
		q.global_position = p + nrm * .03
		q.look_at(q.global_position + nrm, Vector3.UP if abs(nrm.y) < .9 else Vector3.RIGHT)
		q.rotate_object_local(Vector3.FORWARD, G.rnd(0, TAU))
		q.rotate_object_local(Vector3.UP, PI)
	splats.append(q)
	while splats.size() > MAX_SPLATS:
		var o = splats.pop_front()
		if is_instance_valid(o): o.queue_free()

func clear() -> void:
	for g in gibs:
		if is_instance_valid(g.m): g.m.queue_free()
	gibs.clear()
	for s in splats:
		if is_instance_valid(s): s.queue_free()
	splats.clear()
