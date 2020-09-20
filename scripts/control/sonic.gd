extends KinematicBody

class_name Sonic

export(float) var time_limit = 600
export(int) var score = 0 setget set_score
export(int) var rings = 0 setget set_rings

enum State {
	# Runnin around at the speed of sound
	Ground,
	# Very small window after pressing jump
	# Allows for more precise movement
	Jumping,
	# Flying through the air with little control
	Air,
	# Landing on a wall
	WallRun,
	# Slipping off a wall
	Slip,
}

const VEL_JUMP = 10
const ACCEL_START = 60
const ACCEL_RUN = 16
const ACCEL_WALLRUN = 3.5
const ACCEL_JUMPING = 80
const ACCEL_AIR = 8
const MAX_RUN = 90
const MIN_SLIDE_ACCEL = 3
const SPEED_RUN = 10
const SPEED_STOPPING = 4
const SPEED_STOPPED = 1

const ACCEL_SNEAK = 38
const MAX_SNEAK = 8

const DRAG_STOPPING = 2
const DRAG_GROUND = 0.18
const DRAG_AIR = 0.00005
const FORCE_CENTRIFUGAL = 1

const MIN_GROUNDED_ON_WALL = 0
const MIN_SPEED_WALL_RUN = 15
const SPEED_WALL_RUN_RECOVERY = 30
const WALL_RUN_MAGNETISM = 5
const WALL_RUN_REORIENT_SPEED = 1
const WALL_DOT = 0.7
const MIN_DOT_WALLJUMP = 0.8
const MIN_ROLL_WALLRUN = 1.2
const MIN_PITCH_WALLRUN = 3
const VEL_DIFF_FULL_FRICTION = 4

const REORIENT_AIR = 1.5

const FLOOR_SNAP_DISTANCE = 0.5

var state = State.Ground
var velocity: Vector3 = Vector3(0,0,0)
var vel_difference: Vector3 = Vector3(0,0,0)
var gravity: Vector3 = Vector3(0, -9.8, 0) setget set_gravity
var true_up:Vector3 = -gravity.normalized()
var up: Vector3 = true_up
var sneaking: bool = false

var recover = true
var last_wall_jump:Vector3 = Vector3.ZERO
var wall:Vector3 = Vector3.ZERO

const TIME_JUMP = 0.1
const TIME_REORIENT = 0
var timer_air = 0

const TIME_WALL_RUN = 0.06
var timer_wall_run = 0

# Radians per second
const CAM_REORIENT_MIN = 0.2
# 1/x seconds to reorient
const CAM_REORIENT = 0.25
const CAM_REORIENT_MAX = 20

# tolerances in radians
const CAM_ROLL_TOLERANCE = 1.5
const CAM_PITCH_TOLERANCE = 2

const TIME_COYOTE = 0.05
var timer_coyote = 0

const SPEED_ROTATE_MESH = 24

const SNS_CAM_MOUSE = 0.001
var cameraRot: Vector2 = Vector2(0,0)
onready var camYaw = $CamYaw
onready var camFollow: Spatial = $CamYaw/CamFollow
var oldFollow: Transform
onready var camSpring: SpringArm = $CamYaw/CamFollow/SpringArm
onready var mesh: Spatial = $Armature/Skeleton/Sonic
onready var cam : Camera = $CamYaw/CamFollow/SpringArm/Camera
onready var cam_reverse : Camera = $CamYaw/CamFollow/Reverse/Camera

onready var anim: AnimationTree = $AnimationTree
onready var statePlayback: AnimationNodeStateMachinePlayback = anim["parameters/playback"]
onready var debug_imm : ImmediateGeometry = $debug_imm

var stop = false
var dead = false
var local_steer: float = 0

var camRot: Vector2 = Vector2(0,0)

const SPRING_LEN_BASE = 2
const SPRING_LEN_ADD = 0.4
const SPRING_LEN_MIN = 3
const SPRING_LEN_MAX = 10

const CAM_TILT = 0.5

func _ready():
	set_score(score)
	set_rings(rings)
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
			Engine.time_scale = 0.2
		else:
			Engine.time_scale = 1

func _process(delta):
	var newCamRot = camRot + get_camera_rot()
	newCamRot.y = clamp(newCamRot.y, -PI/2 + 0.5, PI/2 - 0.01)
	var c = newCamRot - camRot
	
	camYaw.rotate_y(-c.x)
	camSpring.rotate_x(c.y)
	$CamYaw/CamFollow/Reverse.rotate_x(-c.y)
	camRot = newCamRot
	
	time_limit -= delta
	if time_limit <= 0:
		time_up()
	else:
		$UI/Values/Time.text = "%2d:%02d" % [int(time_limit/60), int(time_limit)%60]

	$debugUI/status/Up.text = MoveMath.pr(up)
	$debugUI/status/Velocity.text = str(velocity.length())
	$debugUI/status/Position.text = MoveMath.pr(global_transform.origin)

	# Animation Logic
	if velocity.length_squared() >= SPEED_STOPPED*SPEED_STOPPED:
		rotate_by_speed(delta)
	
	var speed: float = velocity.length()/MAX_SNEAK
	if speed <= 0.05:
		speed = 0

	var old_speed = anim["parameters/Ground/Walk/blend_position"]
	anim["parameters/Ground/Walk/blend_position"] = lerp(old_speed, speed, 0.5)
	anim["parameters/Ground/Speed/scale"] = min(0.75+speed/1.5, 2+speed/3)
	
	var left = mesh.global_transform.basis.x
	var forward = mesh.global_transform.basis.z
	var frontAngle = true_up.dot(forward)*2
	var sideAngle = true_up.dot(left)*2
	var lean:Vector2 = Vector2(
		clamp(sideAngle, -1, 1),
		clamp(frontAngle, -1, 1)
	)
	anim["parameters/Ground/Walk/1/blend_position"] = lean
	
	var old_steer = anim["parameters/Ground/Walk/2/blend_position"]
	anim["parameters/Ground/Walk/2/blend_position"] = lerp(old_steer, local_steer/(PI/3), 0.05)

	$debugUI/status/State.text = State.keys()[state]

func _physics_process(delta):
	if is_nan(velocity.length()):
		print_debug("Velocity is Nan!")
		get_tree().paused = true
	if up.length_squared() < 0.7:
		up = true_up
	oldFollow.basis = camFollow.global_transform.basis
	var new_state = state
	match state:
		State.Ground:
			if Input.is_action_just_pressed("mv_jump"):
				new_state = State.Jumping
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE:
					if $FloorArea.get_overlapping_bodies().size() == 0:
						new_state = State.Air
					else:
						var new_wall = find_good_wall(0)
						if new_wall == Vector3.ZERO:
							new_state = State.Air
						else:
							wall = new_wall
							new_state = State.WallRun
			else:
				timer_coyote = 0
				if up.dot(true_up) < WALL_DOT:
					new_state = State.WallRun
		State.Jumping:
			timer_air += delta
			if timer_air >= TIME_JUMP:
				new_state = State.Air
		State.Air:
			var n: Vector3 = Vector3.ZERO
			if is_on_floor():
				n = get_floor_normal()
			else:
				n = find_good_wall()
			if n.dot(true_up) >= WALL_DOT:
				new_state = State.Ground
			elif n != Vector3.ZERO:
				set_wall(n)
				if recover:
					new_state = State.WallRun
				else:
					new_state = State.Slip
		State.WallRun:
			if ( Input.is_action_just_pressed("mv_jump") 
				and last_wall_jump.dot(wall) <= MIN_DOT_WALLJUMP
			):
				if last_wall_jump.dot(wall) > 0:
					new_state = State.Slip
				else:
					last_wall_jump = wall
					new_state = State.Jumping
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE:
					var new_wall = find_good_wall()
					if new_wall != Vector3.ZERO:
						set_wall(new_wall)
					elif $FloorArea.get_overlapping_bodies().size() == 0:
						new_state = State.Air
			else:
				timer_coyote = 0
				if up.dot(true_up) >= WALL_DOT:
					new_state = State.Ground
				elif !recover or velocity.length_squared() <= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN:
					new_state = State.Slip
		State.Slip:
			if velocity.length_squared() >= SPEED_WALL_RUN_RECOVERY*SPEED_WALL_RUN_RECOVERY:
				recover = true
				new_state = State.WallRun
			if ( Input.is_action_just_pressed("mv_jump") 
				and last_wall_jump.dot(wall) <= MIN_DOT_WALLJUMP
			):
				last_wall_jump = wall
				new_state = State.Jumping
			elif is_on_floor():
				var n = get_floor_normal()
				if n.dot(true_up) >= WALL_DOT:
					new_state = State.Ground
			else:
				var new_wall = find_good_wall()
				if new_wall.length_squared() == 0:
					new_state = State.Air
				else:
					set_wall(new_wall)
	set_state(new_state)
	match state:
		State.Ground:
			process_ground(delta, ACCEL_RUN, ACCEL_START)
		State.Air:
			process_air(delta)
		State.Jumping:
			process_jump(delta)
		State.WallRun:
			var friction = clamp(wall.dot(true_up), 0, 1)
			var wall_accel = lerp(ACCEL_WALLRUN, ACCEL_RUN, friction)
			velocity -= wall*WALL_RUN_MAGNETISM*delta
			process_ground(delta, wall_accel, wall_accel)
		State.Slip:
			velocity -= wall*WALL_RUN_MAGNETISM*delta
			process_air(delta)
	
	#Camera movement
	var camz = oldFollow.basis.z
	var yawup = MoveMath.reject(camYaw.global_transform.basis.y, camz).normalized()
	var followup = MoveMath.reject(oldFollow.basis.y, camz).normalized()
	var rollAngle = followup.angle_to(yawup)
	var q = clamp(abs(rollAngle)/CAM_ROLL_TOLERANCE, 0, 1)
	var rollSpeed = lerp(CAM_REORIENT, CAM_REORIENT_MAX, q)
	
	if abs(rollAngle) > 0.01:
		var roll = clamp(
			abs(rollAngle)*rollSpeed*delta,
			CAM_REORIENT_MIN*delta,
			abs(rollAngle)
		)
		var rollAxis = followup.cross(yawup).normalized()
		oldFollow = oldFollow.rotated(rollAxis, sign(rollAngle)*roll)
	
	var camx = oldFollow.basis.x
	var yawZ = MoveMath.reject(camYaw.global_transform.basis.z, camx).normalized()
	var followZ = MoveMath.reject(oldFollow.basis.z, camx).normalized()
	var pitchAngle:float = followZ.angle_to(yawZ)
	q = clamp(abs(pitchAngle)/CAM_PITCH_TOLERANCE, 0, 1)
	var pitchSpeed = lerp(CAM_REORIENT, CAM_REORIENT_MAX, q)
	
	if abs(pitchAngle) >= 0.01:
		var pitch = clamp(
			abs(pitchAngle)*pitchSpeed*delta,
			CAM_REORIENT_MIN*delta,
			abs(pitchAngle))
		var pitchAxis:Vector3 = followZ.cross(yawZ).normalized()
		oldFollow = oldFollow.rotated(pitchAxis, sign(pitchAngle)*pitch)
	
	# Instantly rotate in yaw
	var camy = oldFollow.basis.y
	followZ = MoveMath.reject(oldFollow.basis.z, camy).normalized()
	yawZ = MoveMath.reject(camYaw.global_transform.basis.z, camy).normalized()
	var yaw = followZ.angle_to(yawZ)
	if abs(yaw) >= 0.00001:
		var yawAxis = followZ.cross(yawZ).normalized()
		oldFollow = oldFollow.rotated(yawAxis, yaw)
	
	camFollow.global_transform.basis = oldFollow.basis
	
	# Other camera logic
	var speed = velocity.length()/MAX_SNEAK
	var camUp = camFollow.global_transform.basis.y
	cam.global_transform = cam.global_transform.looking_at(
		camSpring.global_transform.origin + velocity*delta*CAM_TILT,
		camUp)
	camSpring.spring_length = clamp(
		speed*SPRING_LEN_ADD+SPRING_LEN_BASE,
		SPRING_LEN_MIN,
		SPRING_LEN_MAX)

func process_ground(delta, accel_move, accel_start):
	sneaking = Input.is_action_pressed("mv_sneak")
	var running = velocity.length_squared() > SPEED_RUN*SPEED_RUN
	
	var input: Vector3 = get_movement()
	var movement:Vector3 
	if velocity == Vector3.ZERO:
		movement = input
	else:
		movement = input.project(velocity)
	
	if is_nan(movement.length()):
		print_debug("ded")
		print("Velocity:", velocity)
		print("Movement:", movement)
		print("Input:",input)
		print("Up:", up)
		print("Wall:", wall)
		get_tree().paused = true
		return
	
	if sneaking:
		movement *= min(ACCEL_SNEAK, accel_move)
	elif velocity.dot(movement) < 0 or !running:
		movement *= accel_start
	else:
		movement *= accel_move
	
	var drag : Vector3
	var centrifugal_force = vel_difference*FORCE_CENTRIFUGAL
	var v = MoveMath.reject(velocity, up)
	
	if input.length_squared() == 0:
		drag = -DRAG_STOPPING*v
		velocity += (gravity + drag + centrifugal_force) * delta
		if velocity.length_squared() <= SPEED_STOPPED*SPEED_STOPPED:
			velocity = (velocity + vel_difference).project(up)
		elif velocity.length_squared() <= SPEED_STOPPING*SPEED_STOPPING:
			var stop_force
			if delta*accel_start >= 1:
				stop_force = velocity
			else:
				stop_force = velocity*delta*accel_start
			velocity -= stop_force
	else:
		if movement.dot(velocity) > 0 and (
			velocity.length_squared() >= MAX_RUN*MAX_RUN
			or (sneaking and velocity.length_squared() >= MAX_SNEAK*MAX_SNEAK)
		):
			movement = Vector3.ZERO
		drag = -DRAG_GROUND*v
		velocity += (movement + gravity + drag + centrifugal_force) * delta
	
	var steer_speed = 180/(velocity.length()*4 + 3)
	var steer = movement.angle_to(input)
	var axis = movement.cross(input).normalized()
	if steer != 0 and axis.is_normalized():
		if abs(steer) < PI/2:
			var vp = velocity.slide(up)
			var steer2 = vp.angle_to(input)
			var axis2 = vp.cross(input).normalized()
			if steer2 != 0 and axis2.is_normalized():
				steer = steer2
				axis = axis2
		var angle = sign(steer)*min(abs(steer), steer_speed*delta)
		var factor = (1 - (angle*angle)/(4*PI*PI))
		velocity = velocity.rotated(axis, angle)*factor
		local_steer = -steer*up.dot(axis)
	
	vel_difference = velocity
	if is_nan(velocity.length()):
		print_debug("ded")
		print("Velocity:", velocity)
		print("Steer:", steer)
		print("Axis:", axis)
		print("Movement:", movement)
		print("Input:",input)
		print("Up:", up)
		print("Wall:", wall)
		get_tree().paused = true
		return
	velocity = move_and_slide_with_snap(velocity, -up*FLOOR_SNAP_DISTANCE, up)
	vel_difference -= velocity
	
	if is_on_floor():
		reorient_ground(get_floor_normal(), 0.9, 15, delta)
	elif state == State.Ground:
		reorient_ground(true_up, 0.2, 5, delta)
	elif state == State.WallRun:
		var new_wall = find_good_wall()
		if new_wall != Vector3.ZERO:
			set_wall(new_wall)
		reorient_wall(wall, delta*WALL_RUN_REORIENT_SPEED)

func process_jump(delta):
	var movement: Vector3 = get_movement()*ACCEL_JUMPING
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	
	vel_difference = velocity
	velocity = move_and_slide(velocity, up)
	vel_difference -= velocity

func process_air(delta):
	var movement = get_movement()*ACCEL_AIR
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	vel_difference = velocity
	velocity = move_and_slide(velocity, up)
	vel_difference -= velocity
	
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		var desiredUp = true_up
		reorient_air(desiredUp, delta*REORIENT_AIR)

func reorient_ground(new_up:Vector3, interp:float, max_radians, delta):
	if !new_up.is_normalized():
		new_up = true_up
	if abs(new_up.dot(up)) >= 0.99999:
		return
	var mr = max_radians
	var angle = up.angle_to(new_up)
	var up_axis = up.cross(new_up).normalized()
	up = up.rotated(up_axis, min(angle*interp, mr*delta))
	global_rotate(up_axis, min(angle*interp, mr*delta))

func reorient_air(desiredUp:Vector3, delta:float):
	var interp = min(delta, 1)
	# Roll upright
	var forward = camYaw.global_transform.basis.z
	var df = Vector3(forward.x, 0, forward.z).normalized()
	
	var upTarget = MoveMath.reject(desiredUp, forward).normalized()
	var upCurrent = MoveMath.reject(up, forward).normalized()
	
	var angle = upCurrent.angle_to(upTarget)
	var rollAxis = upCurrent.cross(upTarget).normalized()
	
	if rollAxis.length_squared() > 0.9:
		global_rotate(rollAxis, angle*interp)
		up = up.rotated(rollAxis, angle*interp)
	
	# Pitch upright
	angle = forward.angle_to(df)
	var pitchAxis = forward.cross(df).normalized()
	if pitchAxis.length_squared() > 0.9:
		global_rotate(pitchAxis, angle*interp)
		up = up.rotated(pitchAxis, angle*interp)

func reorient_wall(desiredUp:Vector3, delta:float):
	if desiredUp == Vector3.ZERO:
		print("ERROR: ZERO used for reorient_wall")
		print_stack()
		return
	
	if desiredUp.dot(up) <= -0.9:
		print_debug("Bad!", up, "->", desiredUp)
		return
	
	var min_roll = MIN_ROLL_WALLRUN
	var min_pitch = MIN_PITCH_WALLRUN
	var rotation_speed = 1
	var f = camYaw.global_transform.basis.z
	var l = camYaw.global_transform.basis.x
	if abs(f.dot(desiredUp)) > abs(l.dot(desiredUp)):
		# Running at the wall head on
		rotation_speed = 3
		min_roll = 2*PI
		min_pitch = 2*PI
	var interp = min(delta*rotation_speed, 1)
	# Roll upright
	var forward = camYaw.global_transform.basis.z
	var left = camYaw.global_transform.basis.x
	var df = left.cross(desiredUp).normalized()
	
	var upTarget = MoveMath.reject(desiredUp, forward).normalized()
	var upCurrent = MoveMath.reject(up, forward).normalized()
	
	var angle = upCurrent.angle_to(upTarget)
	var rollAxis = upCurrent.cross(upTarget).normalized()
	var min_angle = max(0, (abs(angle) - min_roll))
	
	var rotation = sign(angle)*max(abs(angle*interp), min_angle)
	if rollAxis.length_squared() > 0.9:
		global_rotate(rollAxis, rotation)
		up = up.rotated(rollAxis, rotation)
	
	# Pitch upright
	var pitchAxis = forward.cross(df).normalized()
	angle = forward.angle_to(df)
	min_angle = max(0, (abs(angle) - min_pitch))
	rotation = sign(angle)*max(abs(angle*interp), min_angle)
	if pitchAxis.length_squared() > 0.9:
		global_rotate(pitchAxis, rotation)
		up = up.rotated(pitchAxis, rotation)

func find_good_wall(min_grounded = MIN_GROUNDED_ON_WALL) -> Vector3:
	var desiredUp = Vector3.ZERO
	var v = velocity + vel_difference
	for i in range(0, get_slide_count()):
		var col = get_slide_collision(i)
		if $WallRunArea.overlaps_body(col.collider):
			var n = col.normal
			var f = v.dot(n)
			if f <= -min_grounded and f < v.dot(desiredUp):
				desiredUp = n.normalized()
	
	return desiredUp

func set_state(new_state):
	if state == new_state:
		return
	#print(State.keys()[state], State.keys()[new_state])
	timer_wall_run = 0
	timer_coyote = 0
	timer_air = 0
	match new_state:
		State.Ground:
			$Ball.visible = false
			camFollow.global_transform.basis = camYaw.global_transform.basis
			statePlayback.travel("Ground")
			recover = true
			last_wall_jump = Vector3.ZERO
		State.Air:
			if state != State.Jumping:
				statePlayback.travel("Fall")
		State.Jumping:
			$Ball.visible = true
			statePlayback.travel("Jump")
			if state == State.Slip:
				velocity += wall*VEL_JUMP
			else:
				velocity += up*VEL_JUMP
			sneaking = false
		State.WallRun:
			if wall == Vector3.ZERO:
				var nw = find_good_wall()
				if nw == Vector3.ZERO:
					wall = up
			print(wall)
			$Ball.visible = false
			camFollow.global_transform.basis = camYaw.global_transform.basis
			statePlayback.travel("Ground")
		State.Slip:
			statePlayback.travel("Fall")
			$Ball.visible = false
			recover = false
	state = new_state

func rotate_by_speed(delta):
	var bx = up.cross(velocity).normalized()
	var rx = mesh.global_transform.basis.x.normalized()
	var r = rx.angle_to(bx)
	if r == 0:
		return
	var axis = rx.cross(bx).normalized()
	var angle = sign(r)*min(abs(r), delta*SPEED_ROTATE_MESH)
	
	if axis.is_normalized():
		mesh.global_rotate(axis, angle)

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

func set_wall(w):
	if w == Vector3.ZERO:
		print_debug("Bad Wall")
		print_stack()
		get_tree().paused = true
	wall = w

func set_gravity(g):
	gravity = g
	true_up = -(g.normalized())

func attack_position():
	return $CollisionShape.global_transform.origin

func kill():
	dead = true
	var _x = get_tree().reload_current_scene()

func die():
	$DeathScreen/Label.text = "Game Over"
	$CustomAnimation.play("Die")

func time_up():
	$DeathScreen/Label.text = "Time's Up"
	$CustomAnimation.play("Die")

func set_score(s):
	score = s
	$UI/Values/Score.text = str(s)

func set_rings(r):
	rings = r
	$UI/Values/Rings.text = str(r)

func give_points(p):
	set_score(score + p)
