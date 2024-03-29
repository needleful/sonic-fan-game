extends KinematicBody

class_name BadnikGround

var gravity: Vector3 = Vector3(0, -9.8, 0) setget set_gravity
var true_up: Vector3 = Vector3.UP
var up: Vector3 = true_up

var velocity: Vector3 = Vector3(0,0,0)

var sonic: Sonic

export(NodePath) var pathNode: NodePath
onready var path: Path = get_node(pathNode)

export(float) var accel_move:float = 25
export(float) var accel_pivot: float = 25
export(float) var accel_air: float = 2
export(float) var drag_move: float = 0.15
export(float) var drag_patrol: float = 0.75
export(float) var speed_rotation:float = 3*PI

export(float) var time_to_chase:float = 0.15
export(float) var time_to_forget: float = 30
# If the 
export(NodePath) var kill_box: NodePath
var killbox: Area

export(float) var kill_plane: float = -90

const DRAG_AIR = 0.00005
onready var cast = $GroundCast
onready var weapon = $AttackArea/Weapon
onready var visionCone = $VisionArea

enum AIState {
	Patrol,
	Chase,
	Seek
}

enum MoveState {
	Ground,
	Air
}

var state = AIState.Patrol
var mstate = MoveState.Ground

const ATTACK_TIME = 1
var attack_timer = 0
var attacking = false

const COYOTE_TIME = 0.25
var coyote_timer = 0

var vision_timer = 0
var player_in_cone = false

const DIST_PATROL_POINT = 4
var patrol_point: int = 0

func _ready():
	if has_node(kill_box):
		killbox = get_node(kill_box) as Area
	var _x = $AttackArea.connect("body_entered", self, "onAttack")
	_x = $AttackArea.connect("body_exited", self, "onAttackStop")
	_x = $AttackArea/Weapon.connect("body_entered", self, "kill")
	if killbox:
		_x = killbox.connect("body_entered", self, "onVisionEntered")
		_x = killbox.connect("body_exited", self, "onVisionExited")
	else:
		_x = visionCone.connect("body_entered", self, "onVisionEntered")
		_x = visionCone.connect("body_exited", self, "onVisionExited")

func kill(body):
	if body != self and body.has_method("die"):
		body.die()

func _physics_process(delta):
	if global_transform.origin.y <= kill_plane:
		die()
	match mstate:
		MoveState.Ground:
			if !is_on_floor():
				coyote_timer += delta
				if coyote_timer >= COYOTE_TIME:
					mstate = MoveState.Air
		MoveState.Air:
			if is_on_floor():
				coyote_timer = 0
				mstate = MoveState.Ground
	var dir
	
	var s: RID = get_world().space
	var space: PhysicsDirectSpaceState = PhysicsServer.space_get_direct_state(s)
	var see_sonic:bool
	if sonic:
		var raycast = space.intersect_ray(
			visionCone.global_transform.origin,
			sonic.global_transform.origin,
			[self, visionCone, $AttackArea, weapon]
		)
		see_sonic = raycast.has("collider") and raycast["collider"] is Sonic
	else:
		see_sonic = false
	
	match state:
		AIState.Chase:
			if !player_in_cone and !see_sonic:
				vision_timer = min(0, vision_timer - delta)
				if vision_timer <= -time_to_forget:
					state = AIState.Patrol
		AIState.Patrol:
			if player_in_cone and see_sonic:
				vision_timer = max(0, vision_timer + delta)
				if vision_timer >= time_to_chase:
					state = AIState.Chase
			else:
				vision_timer -= delta*0.5
	
	var drag_factor
	match state:
		AIState.Chase:
			dir = get_chase_dir()
			drag_factor = drag_move
		AIState.Patrol:
			drag_factor = drag_patrol
			if path:
				dir = get_patrol_point()
			else:
				dir = Vector3(0,0,0)

	var move:Vector3 = MoveMath.reject(dir, up).normalized()
	var drag:Vector3
	if mstate == MoveState.Air:
		move *= accel_air
		drag = -DRAG_AIR*velocity*velocity*velocity
	else:
		move *= accel_move
		var correction = move.normalized() - velocity.normalized()
		move += correction*accel_pivot
		drag = -drag_factor*velocity
	
	velocity += (gravity + move + drag)*delta
	velocity = move_and_slide(velocity, up)
	
	rotate_by_speed(delta)
	if is_on_floor():
		reorient(get_floor_normal(), 0.9, 1800, delta)
	elif mstate == MoveState.Air:
		if cast.is_colliding():
			reorient(cast.get_collision_normal(), 0.1, 60, delta)
		else:
			reorient(true_up, 0.1, 120, delta)
	
	if attacking:
		attack_timer += delta
	elif attack_timer > 0:
		attack_timer += delta
		if attack_timer > ATTACK_TIME:
			doneAttacking()

func set_gravity(g):
	gravity = g
	true_up = -g.normalized()

func get_patrol_point() -> Vector3:
	if path == null:
		return Vector3.ZERO
	var origin = weapon.global_transform.origin
	var pxform = path.global_transform
	var p_pos = pxform.xform(path.curve.get_point_position(patrol_point))
	var dir = p_pos - origin

	if dir.length() >= DIST_PATROL_POINT:
		return dir
	else:
		patrol_point += 1
		if patrol_point >= path.curve.get_point_count():
			patrol_point = 0
		p_pos = pxform.xform(path.curve.get_point_position(patrol_point))
		return p_pos - origin

func get_chase_dir() -> Vector3:
	if sonic:
		return sonic.global_transform.origin - weapon.global_transform.origin
	else:
		return Vector3.ZERO
	
func reorient(new_up:Vector3, interp:float, max_degrees, delta):
	if new_up.length_squared() <= 0.9:
		new_up = true_up
	if abs(new_up.dot(up)) >= 0.99999:
		return
	var mr = deg2rad(max_degrees)
	var angle = up.angle_to(new_up)
	var up_axis = up.cross(new_up).normalized()
	if up_axis.is_normalized():
		up = up.rotated(up_axis, min(angle*interp, mr*delta))
		global_rotate(up_axis, min(angle*interp, mr*delta))

func rotate_by_speed(delta):
	var target = MoveMath.reject(velocity, up).normalized()
	var forward = global_transform.basis.z
	var angle = forward.angle_to(target)
	var axis = forward.cross(target).normalized()
	if axis.length_squared() > 0.9:
		global_rotate(axis, min(angle/2, speed_rotation*delta))

func onAttack(_b):
	attacking = true
	attack_timer = 0
	$AttackLight.visible = true

func onAttackStop(_b):
	attacking = false

func onVisionEntered(body):
	if body is Sonic and !body.dead:
		sonic = body
		player_in_cone = true

func onVisionExited(body):
	if body is Sonic:
		player_in_cone = false

func doneAttacking():
	attack_timer = 0
	$AttackLight.visible = false

func die():
	if sonic:
		sonic.give_points(100)
	queue_free()
