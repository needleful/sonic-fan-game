extends KinematicBody

enum State {
	Ground,
	Sneaking,
	Jumping,
	Air,
}

const VEL_JUMP = 10
const ACCEL_RUN = 25
const ACCEL_JUMPING = 80
const ACCEL_AIR = 4
const ACCEL_STOP = 80
const MAX_RUN = 90
const MIN_SLIDE_ACCEL = 3
const SPEED_STOPPING = 4
const SPEED_STOPPED = 1

const DRAG_STOPPING = 1.2
const DRAG_GROUND = 0.025
const DRAG_AIR = 0.00005

var state = State.Ground
var velocity: Vector3 = Vector3(0,0,0)
var gravity: Vector3 = Vector3(0, -9.8, 0) setget set_gravity
var up: Vector3 = Vector3(0, 1, 0)

const TIME_JUMP = 0.1
const TIME_REORIENT = 0.75
var timer_air = 0

# Radians per second
const SPEED_REORIENT_MIN = deg2rad(180)
# 1/x seconds to reorient
const SPEED_REORIENT = 5

const TIME_COYOTE = 0.1
var timer_coyote = 0

const SNS_CAM_MOUSE = 0.001
var cameraRot: Vector2 = Vector2(0,0)
onready var camYaw = $CamYaw
onready var camFollow: Spatial = $CamYaw/CamFollow
var oldFollow: Transform
onready var camSpring: Spatial = $CamYaw/CamFollow/SpringArm
onready var mesh: Spatial = $Sonic
onready var cam : Camera = $CamYaw/CamFollow/SpringArm/Camera
onready var cam_reverse : Camera = $CamYaw/CamFollow/Reverse/Camera

onready var debug_imm : ImmediateGeometry = $debug_imm

var stop = false

func _ready():
	cam.current = true
	oldFollow = Transform(camFollow.global_transform)

func _input(event):
	if event is InputEventMouseMotion:
		cameraRot += event.relative
	elif event.is_action_pressed("cam_reverse"):
		cam_reverse.current = true
	elif event.is_action_released("cam_reverse"):
		cam.current = true
	elif event.is_action_pressed("dev_stop"):
		stop = !stop
		if stop:
			Engine.time_scale = 0.1
		else:
			Engine.time_scale = 1

func _process(delta):
	var c = get_camera_rot()
	camYaw.rotate_y(-c.x)
	camSpring.rotate_x(c.y)
	
	$CamYaw/CamFollow/Reverse.rotate_x(-c.y)

	$CamYaw/CamFollow/SpringArm/Camera/UI/status/Up.text = pr(up)
	$CamYaw/CamFollow/SpringArm/Camera/UI/status/Velocity.text = str(velocity.length())

func _physics_process(delta):
	if up.length_squared() < 0.7:
		up = Vector3.UP
	oldFollow.basis = camFollow.global_transform.basis
	var new_state = state
	match state:
		State.Ground:
			if Input.is_action_just_pressed("mv_jump"):
				jump()
				new_state = State.Jumping
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE:
					timer_air = 0
					new_state = State.Air
			else:
				timer_coyote = 0
				if Input.is_action_pressed("mv_sneak"):
					new_state = State.Sneaking
		State.Jumping:
			timer_air += delta
			if timer_air >= TIME_JUMP:
				new_state = State.Air
		State.Air:
			if is_on_floor():
				$CamYaw/debug_yaw.color = Color.magenta
				new_state = State.Ground
		State.Sneaking:
			if Input.is_action_just_pressed("mv_jump"):
				jump()
				new_state = State.Jumping
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE:
					timer_air = 0
					new_state = State.Air
			else:
				timer_coyote = 0
				if !Input.is_action_pressed("mv_sneak"):
					new_state = State.Ground
	
	state = new_state
	match state:
		State.Ground:
			process_ground(delta)
		State.Jumping:
			process_jump(delta)
		State.Air:
			process_air(delta)
		
	var yawup = camYaw.global_transform.basis.y
	var followup = oldFollow.basis.y
	
	var upAngle = followup.angle_to(yawup)
	if abs(upAngle) >= 0.005:
		var upAxis = followup.cross(yawup).normalized()
		camFollow.global_transform.basis = oldFollow.rotated(
			upAxis, 
			sign(upAngle) * min(abs(upAngle), max(abs(upAngle)*SPEED_REORIENT, SPEED_REORIENT_MIN)*delta)
		).basis
	else:
		camFollow.global_transform.basis = camYaw.global_transform.basis

func process_ground(delta):
	var movement: Vector3 = get_movement()*ACCEL_RUN
	var drag : Vector3
	var v = reject(velocity, up)
	debug_imm.clear()
	debug_imm.begin(Mesh.PRIMITIVE_LINES)
	debug_imm.add_vertex(Vector3(0,.5,0))
	if movement.length_squared() == 0:
		drag = -DRAG_STOPPING*v
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + drag.normalized()) + Vector3(0,.5,0))
		velocity += (movement + gravity + drag) * delta
		if velocity.length_squared() <= SPEED_STOPPING*SPEED_STOPPING:
			var stop
			if delta*ACCEL_STOP >= 1:
				stop = velocity
			else:
				stop = velocity*delta*ACCEL_STOP
			velocity -= stop
		if velocity.length_squared() <= SPEED_STOPPED*SPEED_STOPPED:
			velocity = -up
	else:
		if velocity.length_squared() >= MAX_RUN*MAX_RUN:
			movement = Vector3(0,0,0)
		drag = -DRAG_GROUND*v.normalized()*v*v
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + v.normalized()) + Vector3(0,.5,0))
		velocity += (movement + gravity + drag) * delta
	
	velocity = move_and_slide(velocity, up)
	debug_imm.end()
	
	if is_on_floor():
		reorient_ground(get_floor_normal(), .9)
	
	if velocity.length_squared() >= 0.01:
		rotate_by_speed()

func process_jump(delta):
	var movement: Vector3 = get_movement()*ACCEL_JUMPING
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	
	velocity = move_and_slide(velocity, up)
	if velocity.length_squared() >= 0.01:
		rotate_by_speed()

func process_air(delta):
	var movement = get_movement()*ACCEL_AIR
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	velocity = move_and_slide(velocity, up)
	
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		var desiredUp = -gravity.normalized()
		reorient_air(desiredUp, delta)
	else:
		$CamYaw/debug_yaw.color = Color.green

func reorient_ground(new_up:Vector3, interp:float):
	if new_up.length_squared() <= 0.7:
		new_up = Vector3.UP
	if new_up == up:
		return
	var angle = min_angle(up, new_up)
	var up_axis = up.cross(new_up).normalized()
	global_rotate(up_axis, angle*interp)
	
	up = up.rotated(up_axis, angle*interp)

func reorient_air(desiredUp:Vector3, delta:float):
	var interp = min(delta*3, 1)
	var diff = abs(up.angle_to(desiredUp))
	if ( diff > 0.1 
		#and diff < PI
	):
		$CamYaw/debug_yaw.color = Color.red
		# Roll upright
		var forward = camYaw.global_transform.basis.z
		var left = camYaw.global_transform.basis.x
		var df = Vector3(forward.x, 0, forward.z).normalized()
		
		var upTarget = reject(desiredUp, forward).normalized()
		var upCurrent = reject(up, forward).normalized()
		
		var angle = upCurrent.angle_to(upTarget)
		$CamYaw/CamFollow/SpringArm/Camera/UI/status/Position.text = "Roll: %.2f" % angle
		
		global_rotate(forward, angle*interp)
		up = up.rotated(forward, angle*interp)
		var upRot = up.rotated(forward, angle)
		
		# Pitch upright
		angle = forward.angle_to(df)
		$CamYaw/CamFollow/SpringArm/Camera/UI/status/State.text = "Pitch: %.2f" % angle
		global_rotate(left, angle*interp)
		up = up.rotated(left, angle*interp)
		#camSpring.rotate_x(-angle*interp)
		
		#Debug visualization
		upRot = upRot.rotated(left, angle)
		debug_imm.clear()
		debug_imm.begin(Mesh.PRIMITIVE_LINE_STRIP)
		debug_imm.add_vertex(Vector3(0,0,0))
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + forward))
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + left))
		debug_imm.end()
		
		debug_imm.begin(Mesh.PRIMITIVE_TRIANGLES)
		debug_imm.add_vertex(Vector3(0,0,0))
		#debug_imm.add_vertex(transform.xform_inv(global_transform.origin + upCurrent))
		#debug_imm.add_vertex(transform.xform_inv(global_transform.origin + upTarget))
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + upRot))
		debug_imm.add_vertex(transform.xform_inv(global_transform.origin + desiredUp))
		debug_imm.end()
	else:
		$CamYaw/debug_yaw.color = Color.blue
		reorient_ground(desiredUp, interp)

func jump():
	velocity += up*VEL_JUMP
	timer_air = 0

func rotate_by_speed():
	var by = up.cross(velocity).normalized()
	mesh.global_transform.basis = Basis(
		by,
		up,
		by.cross(up)
	)

func get_movement()->Vector3:
	var input = Vector2(
		Input.get_action_strength("mv_right") - Input.get_action_strength("mv_left"),
		Input.get_action_strength("mv_forward") - Input.get_action_strength("mv_back"))
	
	if input.length_squared() > 1:
		input = input.normalized()
		
	return (
		camYaw.global_transform.basis.z * input.y
		- camYaw.global_transform.basis.x * input.x)

func get_camera_rot()->Vector2:
	var ret = cameraRot*SNS_CAM_MOUSE
	cameraRot = Vector2(0,0)
	return ret

func set_gravity(g):
	gravity = g
	up = -(g.normalized())

func min_angle(v1: Vector3, v2: Vector3) ->float:
	var theta = v1.angle_to(v2)
	if abs(theta) <= PI:
		return theta
	else:
		return -sign(theta)*(2*PI -abs(theta))

func pr(vec:Vector3)->String:
	return "{%05.3f, %05.3f, %05.3f}" % [vec.x, vec.y, vec.z]

func reject(v1:Vector3, v2: Vector3) -> Vector3:
	return v1 - v1.project(v2)
