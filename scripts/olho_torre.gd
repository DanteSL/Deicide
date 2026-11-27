extends StaticBody3D
## Olho da Tempestade arremessado (reliquias.gd): flutua onde caiu, encara o inimigo mais perto e solta raios.
## Fica na camada dos inimigos para que os tiros do jogador o acertem: um tiro nele faz ele explodir.

var R: Node = null
var alive := true
var is_boss := false
var kind := "olho"
var r := .5
var h := 1.0
var spawn_t := 0.0
var velocity := Vector3.ZERO
var hp := 1.0
var t := 0.0
var eye: Node3D
var base_y := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = .55
	cs.shape = sh
	add_child(cs)
	eye = Node3D.new()
	add_child(eye)
	var esc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = .38
	sm.height = .76
	esc.mesh = sm
	esc.material_override = G.lit(Color(.93, .91, .87), .2)
	eye.add_child(esc)
	var iris := MeshInstance3D.new()
	var im := SphereMesh.new()
	im.radius = .21
	im.height = .42
	iris.mesh = im
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.3, .8, 1)
	m.emission_enabled = true
	m.emission = Color(.3, .8, 1)
	m.emission_energy_multiplier = 4.0
	iris.material_override = m
	iris.position = Vector3(0, 0, -.3)
	iris.scale = Vector3(1, 1, .35)
	eye.add_child(iris)
	var pup := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = .09
	pm.height = .18
	pup.mesh = pm
	pup.material_override = G.lit(Color(.01, .01, .02), .05)
	pup.position = Vector3(0, 0, -.37)
	pup.scale = Vector3(.8, 1.3, .3)
	eye.add_child(pup)
	for c in eye.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	G.fx.attach_glow(self, Color(.4, .85, 1, .8), 2.2, true)
	var lt := OmniLight3D.new()
	lt.light_color = Color(.45, .85, 1)
	lt.light_energy = 2.0
	lt.omni_range = 7.0
	add_child(lt)
	base_y = global_position.y

func _process(dt: float) -> void:
	t += dt
	global_position.y = base_y + sin(t * 2.2) * .18
	var tgt: Vector3 = G.cam.global_position if G.cam else global_position + Vector3.FORWARD
	var bd := 20.0
	for e in G.enemies:
		if not is_instance_valid(e) or not e.alive: continue
		var d: float = e.center().distance_to(global_position)
		if d < bd:
			bd = d
			tgt = e.center()
	var want := Basis.looking_at(tgt - global_position + Vector3(0, .001, 0), Vector3.UP)
	eye.basis = eye.basis.orthonormalized().slerp(want, 1.0 - exp(-8.0 * dt))

func center() -> Vector3:
	return global_position

func is_head(_p: Vector3) -> bool:
	return false

func take_damage(_dmg: float, _src: String, _head: bool) -> bool:
	if alive and R:
		alive = false
		R._turret_explode(true)
	return false
