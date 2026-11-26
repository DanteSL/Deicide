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

## o inimigo 'e' estoura em sangue: o corpo inteiro é arremessado longe e fica no mapa,
## o sangue espirra na tela e gotas de sangue voam até o jogador (é a munição)
const MAX_CORPSES := 28
const BLOOD_GAIN := {"caida": 45.0, "husk": 22.0, "brute": 55.0, "drone": 12.0}
var corpses: Array = []
var globs: Array = []
var _glob_mesh: SphereMesh
var _glob_mat: StandardMaterial3D

func explode(e: Node3D, src: String) -> void:
	var world: Node3D = G.world
	var c: Vector3 = e.center()
	var away := Vector3.ZERO
	var dist := 99.0
	if G.player:
		away = c - (G.player.global_position + Vector3(0, 1.2, 0))
		dist = away.length()
		away.y = 0
		away = away.normalized() if away.length() > .01 else Vector3.FORWARD
	var strong: bool = src in ["punch", "parry", "slam", "rocket", "gren"]
	var power = 1.6 if strong else 1.0
	var big: bool = e.kind == "brute"
	# 1) o corpo inteiro sai voando (para de animar e vira cadáver)
	var body: Node3D = e.vis
	if body and is_instance_valid(body):
		var gt: Transform3D = body.global_transform
		body.get_parent().remove_child(body)
		world.add_child(body)
		body.global_transform = gt
		for n in body.find_children("*", "", true, false):
			n.set_process(false); n.set_physics_process(false)
			if n is AnimationMixer: n.active = false
		if e.ceif: e.ceif.set_process(false); e.ceif.set_physics_process(false)
		var spd = (9.0 if big else 15.0) * power
		var v = away * spd + Vector3(0, (5.0 if big else 8.0) * power, 0)
		var spin_ax = away.cross(Vector3.UP).normalized() * -1.0
		corpses.append({"m": body, "v": v, "ax": spin_ax, "w": G.rnd(6, 11) * power, "rest": false, "ang": 0.0, "fly": e.fly, "h": e.h, "t": 0.0, "bleed": 3})
		while corpses.size() > MAX_CORPSES:
			var o = corpses.pop_front()
			if is_instance_valid(o.m):
				var tw = o.m.create_tween()
				tw.tween_property(o.m, "position:y", o.m.position.y - 2.0, 2.0)
				tw.tween_callback(o.m.queue_free)
	# 2) explosão de sangue
	G.emit("blood", c, 60 if big else 42, 24 * power, .18, 1.2, away + Vector3(0, .7, 0))
	G.emit("blood2", c, 40, 16, .24, 1.4)
	G.emit("blood", c + Vector3(0, .5, 0), 30, 11, .12, .9)
	for i in (5 if big else 3):
		_splat_at(c + Vector3(G.rnd(-1.4, 1.4), 0, G.rnd(-1.4, 1.4)) + away * G.rnd(0, 2.5), G.rnd(.9, 1.8) * (1.4 if big else 1.0))
	# 3) sangue na tela (mais perto = mais sangue)
	var k: float = clamp(1.4 - dist / 16.0, .25, 1.2) * (1.3 if strong else 1.0)
	if G.main.has_method("screen_blood"): G.main.screen_blood(k)
	# 4) gotas de sangue que voam até o jogador
	var gain: float = BLOOD_GAIN.get(e.kind, 20.0) * (1.5 if src == "punch" else 1.0)
	_spawn_globs(c, gain)
	# 5) o tempo congela e o PORRADÃO
	G.main.hitstop(.25)
	G.shake = max(G.shake, .55 if strong else .4)
	G.snd("porrada", 4.0, G.rnd(.92, 1.06))
	G.snd("slam", -2, G.rnd(.6, .75))

func _spawn_globs(c: Vector3, total: float) -> void:
	if _glob_mesh == null:
		_glob_mesh = SphereMesh.new(); _glob_mesh.radius = .11; _glob_mesh.height = .22; _glob_mesh.radial_segments = 6; _glob_mesh.rings = 3
		_glob_mat = StandardMaterial3D.new()
		_glob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glob_mat.albedo_color = Color(1.0, .08, .1)
		_glob_mat.disable_fog = true
	var n: int = clampi(int(total / 4.0), 3, 14)
	for i in n:
		var m = MeshInstance3D.new()
		m.mesh = _glob_mesh
		m.material_override = _glob_mat
		G.world.add_child(m)
		m.global_position = c + Vector3(G.rnd(-.3, .3), G.rnd(-.2, .4), G.rnd(-.3, .3))
		var v = Vector3(G.rnd(-1, 1), G.rnd(.6, 1.4), G.rnd(-1, 1)).normalized() * G.rnd(5, 10)
		globs.append({"m": m, "v": v, "t": 0.0, "amt": total / n})

func _upd_globs(dt: float) -> void:
	if globs.is_empty() or G.player == null: return
	var tgt: Vector3 = G.player.global_position + Vector3(0, 1.1, 0)
	var keep = []
	for g in globs:
		if not is_instance_valid(g.m): continue
		g.t += dt
		var p: Vector3 = g.m.global_position
		if g.t < .35:
			g.v.y -= 14 * dt
			g.v *= exp(-2.0 * dt)
		else:
			var to = tgt - p
			var want = to.normalized() * (18.0 + g.t * 30.0)
			g.v = g.v.lerp(want, 1.0 - exp(-8.0 * dt))
			if to.length() < .9 or g.t > 3.0:
				G.blood_add(g.amt)
				G.snd("ping", -18, G.rnd(1.6, 2.0))
				g.m.queue_free()
				continue
		g.m.global_position = p + g.v * dt
		g.m.scale = Vector3.ONE * (1.0 + .25 * sin(g.t * 30.0))
		if G.rng.randf() < dt * 20.0: G.emit("blood", g.m.global_position, 1, 1, .06, .3)
		keep.append(g)
	globs = keep

func _upd_corpses(dt: float, space: PhysicsDirectSpaceState3D) -> void:
	for c in corpses:
		var m: Node3D = c.m
		if c.rest or not is_instance_valid(m): continue
		c.t += dt
		c.v.y -= GRAV * dt
		var from = m.global_position + Vector3(0, .3, 0)
		var to = from + c.v * dt
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if hit:
			if hit.normal.y > .6:
				m.global_position = hit.position
				if c.bleed > 0:
					c.bleed -= 1
					_splat_at(hit.position, G.rnd(.8, 1.5))
					G.emit("blood", hit.position + Vector3(0, .2, 0), 10, 6, .14, .6)
				if c.v.length() > 6.0:
					c.v = Vector3(c.v.x, -c.v.y * .25, c.v.z) * .4
				else:
					c.rest = true
					# deita de vez, de barriga para cima, virado para onde foi jogado
					var b0: Basis = m.global_transform.basis.orthonormalized()
					var yaw = atan2(c.v.x, c.v.z) if Vector2(c.v.x, c.v.z).length() > .1 else m.rotation.y
					var lay = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2 if not c.fly else PI * .45)
					var sc = m.scale
					var tw = m.create_tween()
					tw.tween_method(func(u): m.basis = b0.slerp(lay, u).scaled(sc), 0.0, 1.0, .18)
			else:
				# bateu na parede: escorrega para baixo deixando uma mancha
				m.global_position = hit.position + hit.normal * .3 - Vector3(0, .3, 0)
				if c.bleed > 0:
					c.bleed -= 1
					_splat_at(hit.position, G.rnd(.8, 1.4), hit.normal)
				c.v = (c.v - hit.normal * c.v.dot(hit.normal) * 1.6) * .3
		else:
			m.global_position = to - Vector3(0, .3, 0)
			m.rotate(c.ax, c.w * dt)
			if G.rng.randf() < dt * 25.0: G.emit("blood", m.global_position + Vector3(0, 1, 0), 2, 3, .1, .5)
		if c.t > 6.0: c.rest = true

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
	if G.state != "play": return
	var space = G.world.get_world_3d().direct_space_state
	_upd_corpses(dt, space)
	_upd_globs(dt)
	if gibs.is_empty(): return
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
	for c in corpses:
		if is_instance_valid(c.m): c.m.queue_free()
	corpses.clear()
	for g in globs:
		if is_instance_valid(g.m): g.m.queue_free()
	globs.clear()
	for g in gibs:
		if is_instance_valid(g.m): g.m.queue_free()
	gibs.clear()
	for s in splats:
		if is_instance_valid(s): s.queue_free()
	splats.clear()
