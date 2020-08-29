extends RigidBody

class_name BadnikGround

var up: Vector3 = Vector3.UP

export(NodePath) var sonicNode: NodePath
onready var sonic: Sonic = get_node(sonicNode)

export(float) var accel_move:float = 18
export(float) var accel_stop: float = 60
export(float) var drag_move: float = 0.15

enum AIState {
	Patrol,
	Chase,
	Seek
}

enum MoveState {
	Ground,
	Air
}

var state = AIState.Chase

func _physics_process(delta):
	process_chase(delta)

func process_chase(delta):
	var dir:Vector3 = sonic.global_transform.origin - global_transform.origin
	var move:Vector3 = MoveMath.reject(dir, up).normalized()
	if dir.dot(linear_velocity) <= 0:
		move *= accel_stop
	else:
		move *= accel_move
	var drag:Vector3 = -drag_move*linear_velocity
	
	var force = (move + drag)*mass
	add_central_force(force)
	
	rotate_by_speed()
	#if is_on_floor():
		#reorient_ground(get_floor_normal(), 0.9)
	
func reorient_ground(new_up:Vector3, interp:float):
	if new_up.length_squared() <= 0.9:
		new_up = Vector3.UP
	if abs(new_up.dot(up)) >= 0.99999:
		return
	var angle = up.angle_to(new_up)
	var up_axis = up.cross(new_up).normalized()
	up = up.rotated(up_axis, angle*interp)
	global_rotate(up_axis, angle*interp)

func reorient_air(dir):
	var forward = global_transform.basis.z
	var df = linear_velocity.normalized()
	if df.length_squared() >= 0.99:
		var angle = forward.angle_to(df)
		var r = forward.cross(df)
		up = up.rotated(r, angle*0.2)
		global_rotate(r, angle*0.2)

func rotate_by_speed():
	var df = up.cross(linear_velocity).normalized()
	var change = df - global_transform.basis.z 
	add_force(change*mass, Vector3(0, 0, -1.5))
