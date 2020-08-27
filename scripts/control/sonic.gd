extends KinematicBody

enum State {
	Ground,
	Jumping,
	Air
}

const VEL_JUMP = 10
const ACCEL_RUN = 25
const ACCEL_JUMPING = 80
const ACCEL_AIR = 4
const MAX_RUN = 90

const DRAG_STOPPING = .8
const DRAG_GROUND = 0.035
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

const SNS_CAM_MOUSE = 0.06
var cameraRot: Vector2 = Vector2(0,0)
onready var camYaw = $CamYaw
onready var camFollow: Spatial = $CamYaw/CamFollow
onready var camSpring: Spatial = $CamYaw/CamFollow/SpringArm
onready var mesh: Spatial = $Sonic
var oldFollow: Transform

func _ready():
	oldFollow = Transform(camFollow.global_transform)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		cameraRot += event.relative

func _process(delta):
	var c = get_camera_rot()
	camYaw.rotate_y(-c.x*delta)
	camSpring.rotate_x(c.y*delta)
	
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
		State.Jumping:
			timer_air += delta
			if timer_air >= TIME_JUMP:
				new_state = State.Air
		State.Air:
			if is_on_floor():
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
	if abs(upAngle) >= 0.01:
		var upAxis = followup.cross(yawup).normalized()
		
		#camFollow.global_transform.basis = oldFollow.basis
		camFollow.global_transform.basis = oldFollow.rotated(
			upAxis, 
			sign(upAngle) * min(abs(upAngle), max(abs(upAngle)*SPEED_REORIENT, SPEED_REORIENT_MIN)*delta)
		).basis
	else:
		camFollow.global_transform.basis = camYaw.global_transform.basis
	
	if velocity.length_squared() >= 0.01:
		var by = up.cross(velocity).normalized()
		mesh.global_transform.basis = Basis(
			by,
			up,
			by.cross(up)
		)
	
	$CamYaw/CamFollow/SpringArm/Camera/UI/status/Position.text = pr(transform.origin)
	$CamYaw/CamFollow/SpringArm/Camera/UI/status/State.text = State.keys()[state]
	$CamYaw/CamFollow/SpringArm/Camera/UI/status/Velocity.text = str(velocity.length())
	$CamYaw/CamFollow/SpringArm/Camera/UI/status/Up.text = pr(up)


func pr(vec:Vector3)->String:
	return "{%05.3f, %05.3f, %05.3f}" % [vec.x, vec.y, vec.z]

func process_ground(delta):
	var accel: Vector3 = get_movement()
	if accel.length_squared() == 0:
		accel -= velocity.normalized()*velocity*velocity*DRAG_STOPPING
		if velocity.length_squared() < 1:
			velocity = Vector3(0,0,0)
	else:
		if velocity.length_squared() >= MAX_RUN*MAX_RUN:
			accel = Vector3(0,0,0)
		accel *= ACCEL_RUN
		accel -= velocity.normalized()*velocity*velocity*DRAG_GROUND
	accel += gravity
	velocity += accel * delta
	
	velocity = move_and_slide(velocity, up)
	if is_on_floor():
		set_up(get_floor_normal(), .99)

func process_jump(delta):
	var accel: Vector3 = get_movement()*ACCEL_JUMPING + gravity
	accel -= DRAG_AIR*velocity*velocity*velocity
	velocity += accel * delta
	
	velocity = move_and_slide(velocity, up)

func process_air(delta):
	var accel = get_movement()*ACCEL_AIR + gravity
	accel -= DRAG_AIR*velocity*velocity*velocity
	velocity += accel * delta
	velocity = move_and_slide(velocity, up)
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		set_up(-gravity.normalized(), 0.05)

func jump():
	velocity += up*VEL_JUMP
	timer_air = 0


func get_movement()->Vector3:
	# x for sides, y for forward/back
	var input = Vector2(
		Input.get_action_strength("mv_right") - Input.get_action_strength("mv_left"),
		Input.get_action_strength("mv_forward") - Input.get_action_strength("mv_back"))
		
	return (
		camYaw.global_transform.basis.z * input.y
		- camYaw.global_transform.basis.x * input.x)

func get_camera_rot()->Vector2:
	var ret = cameraRot*SNS_CAM_MOUSE
	cameraRot = Vector2(0,0)
	return ret

func set_up(new_up:Vector3, interp:float):
	if new_up.length_squared() <= 0.7:
		new_up = Vector3.UP
	if new_up == up:
		return
	var angle = up.angle_to(new_up)
	var up_axis = up.cross(new_up).normalized()
	rotate(up_axis, angle*interp)
	
	up = up.rotated(up_axis, angle*interp)

func set_gravity(g):
	gravity = g
	up = -(g.normalized())
