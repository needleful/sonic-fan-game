extends RigidBody

export(NodePath) var sonicNode: NodePath
export(NodePath) var weaponNode: NodePath = NodePath("Eye")

export(float) var player_outer_radius = 8
export(float) var player_inner_radius = 3
export(float) var acceleration = 25
export(float) var max_velocity = 45
export(float) var torque_to_player = 10
export(float) var torque_to_reorient = 10
export(float) var repulsion = .5
export(float) var angular_drag = .9
export(float) var weapon_rotation_speed: float = deg2rad(30)

const DRAG_AIR = 0.00005
onready var sonic: Sonic = get_node(sonicNode)
onready var weapon: Spatial = get_node(weaponNode)
onready var anim: AnimationPlayer = $AttackAnimations

var aim = false
var firing = false

func _ready():
	$Eye/AttackArea.connect("body_entered", self, "onAttackEnter")
	$Eye/AttackArea.connect("body_exited", self, "onAttackExit")

func _physics_process(delta):
	if firing and aim:
		sonic.kill()
	var dist = sonic.global_transform.origin - global_transform.origin
	var dir:Vector3 = dist.normalized()
	var f = global_transform.basis.z
	var l = global_transform.basis.x
	var dl = MoveMath.reject(l, Vector3.UP).normalized()
	
	var dtorq = mass*torque_to_player*(f.angle_to(dir)/(2*PI))*f.cross(dir)
	var rtorq = mass*torque_to_reorient*(l.angle_to(dl)/(2*PI))*l.cross(dl)
	var drtorq = -angular_drag*angular_velocity*mass
	
	if dist.length_squared() <= player_inner_radius*player_inner_radius:
		dir = Vector3(0,-dir.y,0)*repulsion
	elif dist.length_squared() <= player_outer_radius*player_outer_radius:
		dir = (sonic.velocity - linear_velocity).normalized()
	
	var accel:Vector3 = dir*acceleration
	var drag:Vector3 = DRAG_AIR*linear_velocity*linear_velocity*linear_velocity
	
	add_central_force((accel-drag)*mass)
	add_torque(dtorq)
	add_torque(rtorq)
	add_torque(drtorq)
	
	var weapdir = (sonic.global_transform.origin - weapon.global_transform.origin).normalized()
	var angle = weapon.global_transform.basis.z.angle_to(weapdir)
	var axis = weapon.global_transform.basis.z.cross(weapdir).normalized()
	
	if axis.length_squared() >= 0.999:
		weapon.global_rotate(axis, sign(angle)*min(abs(angle), weapon_rotation_speed*delta))

func kill_start():
	firing = true

func kill_end():
	firing = false
	if aim:
		anim.queue("Attack")

func onAttackEnter(body):
	aim = true
	anim.play("Attack")

func onAttackExit(body):
	aim = false
	if not firing:
		anim.play_backwards("Attack")
