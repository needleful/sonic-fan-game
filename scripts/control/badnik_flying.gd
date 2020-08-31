extends RigidBody

export(NodePath) var sonicNode: NodePath
export(NodePath) var weaponNode: NodePath = NodePath("Eye")

export(float) var player_outer_radius = 8
export(float) var player_inner_radius = 3
export(float) var acceleration = 25
export(float) var pivot_acceleration = 25
export(float) var torque_to_player = 10
export(float) var torque_to_reorient = 10
export(float) var repulsion = 10
export(float) var avoidance_strength = 18
export(float) var angular_drag = .9
export(float) var weapon_rotation_speed: float = deg2rad(33)

const DRAG_AIR = 0.00005
onready var sonic: Sonic = get_node(sonicNode)
onready var weapon: Spatial = get_node(weaponNode)
onready var anim: AnimationPlayer = $AttackAnimations

var aim = false
var firing = false
var commit = false
var cancel = false

const TIME_TO_CANCEL = .65
var cancel_timer = 0

func _ready():
	var _c = $Eye/AttackArea.connect("body_entered", self, "onAttackEnter")
	_c = $Eye/AttackArea.connect("body_exited", self, "onAttackExit")

func _physics_process(delta):
	if firing:
		for b in $Eye/AttackArea.get_overlapping_bodies():
			if b != self and b.has_method("die"):
				b.die()
	elif cancel:
		cancel_timer += delta
		if commit:
			cancel = false
			cancel_timer = 0
		elif cancel_timer >= TIME_TO_CANCEL:
			anim.play("CancelAttack")
			aim = false
			cancel = false
			commit = false
			cancel_timer = 0
	
	var dist = sonic.global_transform.origin + sonic.velocity*delta - global_transform.origin
	var dir:Vector3 = (dist).normalized()
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
	
	var avoidance: Vector3 = Vector3.ZERO
	for r in $Avoidance.get_children():
		if !(r is RayCast):
			continue
		var rc: RayCast = r
		if rc.is_colliding():
			var p = rc.get_collision_point()
			var strength = rc.cast_to.length_squared() - (p - rc.global_transform.origin).length_squared()
			var d = (p - rc.global_transform.origin).normalized()*strength
			if is_nan(d.x) or is_nan(d.y) or is_nan(d.z):
				continue
			avoidance -= d
	if avoidance.length_squared() > 0:
		avoidance = avoidance.normalized()
	
	var move : Vector3 = (dir)*acceleration
	var accel:Vector3 = move + avoidance*avoidance_strength
	
	var move_correction = accel.normalized() - linear_velocity.normalized()
	var vcor = move_correction*pivot_acceleration
	var drag:Vector3 = DRAG_AIR*linear_velocity*linear_velocity*linear_velocity
	
	add_central_force((accel-drag+vcor)*mass)
	add_torque(dtorq)
	add_torque(rtorq)
	add_torque(drtorq)
	
	var future_sonic = sonic.attack_position()
	var weapdir = (future_sonic - weapon.global_transform.origin).normalized()
	var angle = weapon.global_transform.basis.z.angle_to(weapdir)
	var axis = weapon.global_transform.basis.z.cross(weapdir).normalized()
	
	if axis.length_squared() >= 0.999:
		weapon.global_rotate(axis, sign(angle)*min(abs(angle), weapon_rotation_speed*delta))

func kill_start():
	firing = true

func kill_end():
	firing = false

func onAttackEnter(body):
	if !(body is Sonic) or body.dead:
		return
	aim = true
	cancel = false
	cancel_timer = 0
	if !anim.is_playing() and anim.current_animation != "Attack":
		anim.play("Attack")

func onAttackExit(body):
	if body is Sonic:
		if !commit:
			cancel_timer = 0
			cancel = true
		else:
			aim = false

func attack_commit():
	commit = true

func attack_start():
	commit = false

func die():
	queue_free()
