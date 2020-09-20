extends KinematicBody

class_name BadnikGround

var gravity: Vector3 = Vector3(0, -9.8, 0)
var up: Vector3 = Vector3.UP

var velocity: Vector3 = Vector3(0,0,0)

export(NodePath) var sonicNode: NodePath
onready var sonic: Sonic = get_node(sonicNode)

export(NodePath) var pathNode: NodePath
onready var path: Path = get_node(pathNode)

export(float) var accel_move:float = 35
export(float) var accel_pivot: float = 20
export(float) var accel_air: float = 9
export(float) var drag_move: float = 0.25
export(float) var drag_patrol: float = 0.75
export(float) var speed_rotation:float = 3*PI

export(float) var time_to_chase:float = 0.25
export(float) var time_to_forget: float = 10

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
	var _x = $AttackArea.connect("body_entered", self, "onAttack")
	_x = $AttackArea.connect("body_exited", self, "onAttackStop")
	_x = $AttackArea/Weapon.connect("body_entered", self, "kill")
	_x = visionCone.connect("body_entered", self, "onVisionEntered")
	_x = visionCone.connect("body_exited", self, "onVisionExited")

func kill(body):
	if body != self and body.has_method("die"):
		body.die()

func _physics_process(delta):
	if global_transform.origin.y <= -90:
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
	var raycast = space.intersect_ray(
		visionCone.global_transform.origin,
		sonic.global_transform.origin,
		[self, visionCone, $AttackArea, weapon]
	)
	var see_sonic:bool = raycast.has("collider") and raycast["collider"] is Sonic
	
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
			reorient(Vector3.UP, 0.1, 120, delta)
	
	if attacking:
		attack_timer += delta
	elif attack_timer > 0:
		attack_timer += delta
		if attack_timer > ATTACK_TIME:
			doneAttacking()

func get_patrol_point() -> Vector3:
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
	return sonic.global_transform.origin - weapon.global_transform.origin
	
func reorient(new_up:Vector3, interp:float, max_degrees, delta):
	if new_up.length_squared() <= 0.9:
		new_up = Vector3.UP
	if abs(new_up.dot(up)) >= 0.99999:
		return
	var mr = deg2rad(max_degrees)
	var angle = up.angle_to(new_up)
	var up_axis = up.cross(new_up).normalized()
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
		player_in_cone = true

func onVisionExited(body):
	if body is Sonic:
		player_in_cone = false

func doneAttacking():
	attack_timer = 0
	$AttackLight.visible = false

func die():
	sonic.give_points(100)
	queue_free()
