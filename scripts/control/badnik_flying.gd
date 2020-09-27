extends RigidBody

export(NodePath) var sonicNode: NodePath

export(float) var player_outer_radius = 8
export(float) var player_inner_radius = 3
export(float) var acceleration = 34
export(float) var pivot_acceleration = 25
export(float) var torque_to_player = 10
export(float) var torque_to_reorient = 10
export(float) var repulsion = 10
export(float) var avoidance_strength = 30
export(float) var angular_drag = .9
export(float) var weapon_rotation_speed: float = deg2rad(40)

const DRAG_AIR = 0.00005
onready var sonic: Sonic = get_node(sonicNode)
onready var weapon: Spatial = $Eye
onready var anim: AnimationPlayer = $AttackAnimations
onready var attackArea = $Eye/AttackMesh/AttackArea

enum WeaponState {
	Idle
	Charging,
	Committed,
	Firing,
	Cancelling
}

enum AIState {
	Inactive,
	Active
}

var state = AIState.Inactive
var weapState = WeaponState.Idle

const TIME_TO_CANCEL = .85
var cancel_timer = 0

func _physics_process(delta):
	if state == AIState.Inactive:
		return
	match weapState:
		WeaponState.Idle:
			if attackArea.get_overlapping_bodies().has(sonic):
				set_state(WeaponState.Charging)
		WeaponState.Firing:
			for b in attackArea.get_overlapping_bodies():
				if b is Sonic:
					var space = get_world().space
					var dstate = PhysicsServer.space_get_direct_state(space)
					var res = dstate.intersect_ray(weapon.global_transform.origin, b.attack_position(), [self])
					if res.has("collider") and res["collider"] == b:
						b.die()
				elif b != self and b.has_method("die"):
					b.die()
		WeaponState.Charging:
			if !anim.is_playing() or anim.current_animation != "Attack":
				anim.play("Attack")
			if !attackArea.get_overlapping_bodies().has(sonic):
				cancel_timer += delta
				if cancel_timer >= TIME_TO_CANCEL:
					set_state(WeaponState.Cancelling)
	
	var dist = sonic.attack_position() + sonic.velocity*delta - weapon.global_transform.origin
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
		if rc.is_colliding() and !(rc.get_collider() is Sonic):
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
	
	if weapState != WeaponState.Firing:
		add_central_force((accel-drag+vcor)*mass)
	else:
		# Loses power while firing
		add_central_force(-Vector3.UP*9.8*mass)
	add_torque(dtorq)
	add_torque(rtorq)
	add_torque(drtorq)
	
	var future_sonic = sonic.attack_position() + sonic.velocity*delta
	var weapdir = (future_sonic - weapon.global_transform.origin).normalized()
	var angle = weapon.global_transform.basis.z.angle_to(weapdir)
	var axis = weapon.global_transform.basis.z.cross(weapdir).normalized()
	
	if axis.length_squared() >= 0.999:
		weapon.global_rotate(axis, sign(angle)*min(abs(angle), weapon_rotation_speed*delta))

func set_state(s):
	if weapState == s:
		return
	cancel_timer = 0
	weapState = s
	match weapState:
		WeaponState.Charging:
			anim.play("Attack")
		WeaponState.Cancelling:
			anim.play("CancelAttack")

func attack_commit():
	set_state(WeaponState.Committed)

func kill_start():
	set_state(WeaponState.Firing)

func kill_end():
	set_state(WeaponState.Idle)

func cancel_end():
	set_state(WeaponState.Idle)

func die():
	sonic.give_points(100)
	queue_free()

func _on_Activation_body_entered(body):
	if body is Sonic:
		sonic = body
		state = AIState.Active
