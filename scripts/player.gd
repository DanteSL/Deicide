extends CharacterBody3D
## Jogador: movimento rápido (dash, deslize, pisão, pulo na parede), câmera e entrada.

var hp = 100.0
var dead = false
var stamina = 3.0
var dash_t = 0.0
var dash_dir = Vector3.FORWARD
var dash_ground = false
var sliding = false
var slide_dir = Vector3.FORWARD
var slamming = false
var wall_jumps = 3
var coyote = 0.0
var eye_h = 1.6
var land = 0.0
var roll = 0.0
var strafe = 0.0
var yaw = 0.0
var pitch = 0.0
var mdx = 0.0
var mdy = 0.0
var look_dx = 0.0
var look_dy = 0.0
var wish = Vector3.ZERO
var cur_fov = 100.0
var was_floor = false
var fire_held = false

var cam: Camera3D
var weapons: Node

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	var cs = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 400
	cam.fov = 100
	cam.position.y = 1.6
	add_child(cam)
	G.cam = cam
	weapons = preload("res://scripts/weapons.gd").new()
	add_child(weapons)

## congelado durante cutscenes
var frozen := false

func reset_at(p: Vector3) -> void:
	frozen = false
	global_position = p
	velocity = Vector3.ZERO
	hp = 100.0
	dead = false
	stamina = 3.0
	dash_t = 0
	sliding = false
	slamming = false
	yaw = 0
	pitch = 0
	land = 0

func handle_input(ev: InputEvent) -> void:
	if G.state != "play" or frozen:
		return
	if ev is InputEventMouseMotion:
		mdx += ev.relative.x
		mdy += ev.relative.y
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			fire_held = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				weapons.alt_press()
			else:
				weapons.alt_release()
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			weapons.cycle(-1)
		elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			weapons.cycle(1)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.is_action("jump"): jump()
		elif ev.is_action("dash"): dash()
		elif ev.is_action("slide"): slide_or_slam()
		elif ev.is_action("punch"): weapons.punch()
		elif ev.is_action("inspect"): weapons.inspect()
		elif ev.is_action("swap"): weapons.quick_swap()
		elif ev.is_action("use"): G.main.use_pressed()
		elif ev.is_action("w9"): weapons.relic_next()
		else:
			for n in 8:
				if ev.is_action("w%d" % (n + 1)):
					weapons.select_slot(n)
					break
	elif ev is InputEventKey and not ev.pressed and ev.is_action("slide"):
		sliding = false

func fwd_dir() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func wish_or_fwd() -> Vector3:
	return wish if wish.length_squared() > 0 else fwd_dir()

func wall_normal():
	var space = get_world_3d().direct_space_state
	var o = global_position + Vector3(0, 1.0, 0)
	for i in 8:
		var a = i * TAU / 8.0
		var d = Vector3(cos(a), 0, sin(a))
		var q = PhysicsRayQueryParameters3D.create(o, o + d * 0.9, 1)
		var hit = space.intersect_ray(q)
		if hit and abs(hit.normal.y) < 0.5:
			return Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	return null

func jump() -> void:
	if dead: return
	if dash_t > 0 and dash_ground:
		dash_t = 0
		velocity = Vector3(dash_dir.x * 28, 12, dash_dir.z * 28)
		G.snd("jump", -10)
		return
	if is_on_floor() or coyote > 0:
		sliding = false
		velocity.y = 14
		coyote = 0
		G.snd("jump", -10)
		return
	var n = wall_normal()
	if n != null and wall_jumps > 0:
		wall_jumps -= 1
		velocity = Vector3(n.x * 14 + velocity.x * 0.3, 13, n.z * 14 + velocity.z * 0.3)
		slamming = false
		G.snd("jump", -10)
		G.emit("dust", global_position + Vector3(-n.x * .5, 1, -n.z * .5), 8, 4, .12, .5)

func dash() -> void:
	if stamina < 1 or dead: return
	stamina -= 1
	dash_dir = wish_or_fwd()
	dash_t = 0.2
	dash_ground = is_on_floor()
	sliding = false
	slamming = false
	G.snd("dash", -6)
	G.emit("dust", global_position + Vector3(0, .3, 0), 6, 4, .15, .4)

func slide_or_slam() -> void:
	if is_on_floor() or coyote > 0:
		sliding = true
		slide_dir = wish_or_fwd()
		G.snd("jump", -12, 0.6)
	else:
		slamming = true
		dash_t = 0

func slam_impact() -> void:
	if weapons.R and weapons.R.cur == "rosario": weapons.R.eclipse(global_position)
	slamming = false
	G.shake = max(G.shake, 0.9)
	G.snd("slam", -2)
	G.emit("dust", global_position + Vector3(0, .2, 0), 22, 12, .25, .7, Vector3.ZERO, 20)
	for e in G.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or e.spawn_t > 0 or e.is_boss: continue
		var d = Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
		if d < 8 and abs(e.global_position.y - global_position.y) < 3:
			e.velocity.y += 5.0 if e.kind == "brute" else 14.0
			G.hurt_enemy(e, 35, "slam", e.center(), false)

func _physics_process(dt: float) -> void:
	if G.state != "play" or dead or frozen:
		_apply_cam(dt)
		return
	var zs = 0.4 if weapons.zoom else 1.0
	var sens = 0.0022 * G.sens_mult * zs
	yaw -= mdx * sens
	pitch = clamp(pitch - mdy * sens * (-1.0 if G.invert_y else 1.0), -1.55, 1.55)
	look_dx = mdx
	look_dy = mdy
	mdx = 0
	mdy = 0
	var fx = -sin(yaw)
	var fz = -cos(yaw)
	var rx = cos(yaw)
	var rz = -sin(yaw)
	var i_f = Input.get_action_strength("fwd") - Input.get_action_strength("back")
	var i_r = Input.get_action_strength("right") - Input.get_action_strength("left")
	var w = Vector3(fx * i_f + rx * i_r, 0, fz * i_f + rz * i_r)
	if w.length() > 0: w = w.normalized()
	wish = w
	strafe = i_r
	var v = velocity
	if dash_t > 0:
		dash_t -= dt
		v = Vector3(dash_dir.x * 46, -1, dash_dir.z * 46)
		if dash_t <= 0:
			v.x *= 0.5
			v.z *= 0.5
	elif sliding:
		v.x = slide_dir.x * 21
		v.z = slide_dir.z * 21
		v.y -= 40 * dt
		if G.rng.randf() < dt * 30:
			G.emit("dust", global_position + Vector3(0, .1, 0), 1, 3, .1, .4)
		if is_on_floor() and G.rng.randf() < dt * 40:
			G.emit("spark", global_position + Vector3(-slide_dir.x * .3, .05, -slide_dir.z * .3), 2, 5, .05, .3, Vector3(-slide_dir.x, .4, -slide_dir.z), 20)
	else:
		if is_on_floor():
			var k = 1.0 - exp(-14 * dt)
			v.x += (w.x * 16 - v.x) * k
			v.z += (w.z * 16 - v.z) * k
		else:
			var hs = Vector2(v.x, v.z).length()
			v.x += w.x * 40 * dt
			v.z += w.z * 40 * dt
			var ns = Vector2(v.x, v.z).length()
			var cap: float = max(16.0, hs)
			if ns > cap:
				v.x *= cap / ns
				v.z *= cap / ns
		if slamming:
			v.y = -75
		else:
			v.y -= 40 * dt
	var vy0 = v.y
	velocity = v
	move_and_slide()
	var on = is_on_floor()
	if on:
		coyote = 0.1
		wall_jumps = 3
		if not was_floor:
			land = clamp(-vy0 / 40.0, 0.0, 1.0)
			if slamming:
				slam_impact()
			elif land > 0.45:
				G.snd("land", -8)
	else:
		coyote -= dt
		if sliding and coyote <= 0:
			sliding = false
	was_floor = on
	if dash_t <= 0:
		stamina = min(3.0, stamina + dt / 1.1)
	if G.mode == "train":
		hp = min(100.0, hp + dt * 12)
	if global_position.y < -30:
		if G.main and G.main.level == "torre":
			G.main.torre_map.player_fell()
		else:
			global_position = Vector3(0, 3, 0)
			velocity = Vector3.ZERO
	if fire_held:
		weapons.try_fire()
	_apply_cam(dt)

func _apply_cam(dt: float) -> void:
	var k = 1.0 - exp(-15 * dt)
	eye_h += ((0.75 if sliding else 1.6) - eye_h) * k
	land *= exp(-8 * dt)
	G.shake *= exp(-7 * dt)
	roll += ((0.06 if sliding else 0.0) - strafe * 0.022 - roll) * (1.0 - exp(-10 * dt))
	var s = G.shake * 0.12 * G.shake_k
	cam.position = Vector3(G.rnd(-1, 1) * s, eye_h - land * 0.25 + G.rnd(-1, 1) * s, G.rnd(-1, 1) * s)
	rotation = Vector3(0, yaw, 0)
	cam.rotation = Vector3(pitch, 0, roll)
	var hs = Vector2(velocity.x, velocity.z).length()
	var tf = G.fov_base + (10.0 if dash_t > 0 else 0.0) + clamp((hs - 16) * 0.4, 0.0, 8.0)
	if weapons.zoom: tf = 32.0
	cur_fov += (tf - cur_fov) * (1.0 - exp(-(18 if weapons.zoom else 10) * dt))
	cam.fov = cur_fov # mesmo FOV vertical da versão web
