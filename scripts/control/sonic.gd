extends KinematicBody
class_name Sonic

export(float) var kill_plane = -300
export(float) var time_limit = 600
export(int) var score = 0 setget set_score
export(int) var rings = 0 setget set_rings

enum State {
	# Runnin around at the speed of sound
	Ground,
	# Very small window after pressing jump
	# Allows for more precise movement
	Jumping,
	# Jump while sliding for more acceleration
	SlidingJump,
	# Flying through the air with little control
	Air,
	#Needed this for some animation logic
	Backflip,
	# Landing on a wall
	WallRun,
	# Slipping off a wall
	Slip,
	# Playing an animation
	CustomAnimation,
	# Sonic's ded
	Dead
}

const VEL_JUMP = 10
const ACCEL_START = 60
const ACCEL_RUN = 16
const ACCEL_WALLRUN = 1.5
const ACCEL_SLIDE_WALLRUN = 30
const ACCEL_JUMPING = 30
const ACCEL_JUMPING_SLIDE = 300
const ACCEL_AIR = 10
const ACCEL_BACKFLIP = 15
const MAX_RUN = 90
const MIN_SLIDE_ACCEL = 3
const SPEED_RUN = 10
const SPEED_STOPPING = 4
const SPEED_STOPPED = 1
const ANGLE_FLOOR = PI/2 - 0.05

const ACCEL_SNEAK = 38
const MAX_SNEAK = 8

const DRAG_STOPPING = 2
const DRAG_GROUND = 0.18
const DRAG_AIR = 0.00005
const FORCE_CENTRIFUGAL = 1
const MAX_AIR_VEL = 30

const MIN_GROUNDED_ON_WALL = -0.05
const MIN_SPEED_WALL_RUN = 15
const SPEED_WALL_RUN_RECOVERY = 40
const FLOOR_MAGNETISM = 0.5
const WALL_RUN_ROLL_SPEED = 1.2
const WALL_RUN_PITCH_SPEED = 15
const WALL_DOT = 0.5
const MIN_DOT_WALLJUMP = 0.4
const MIN_ROLL_WALLRUN = 1.2
const MIN_PITCH_WALLRUN = 3
const VEL_DIFF_FULL_FRICTION = 4

const REORIENT_AIR = 1.5
const REORIENT_ROLL = 1.5
const REORIENT_PITCH = 2

const FLOOR_SNAP_FORCE = 0
const FLOOR_SNAP_LENGTH = 0.25
const MIN_FLOOR_ANGLE = 0.02

const MIN_ANGLE_SLIDE = 0.3
const MAX_ANGLE_SLIDE = PI/2

var state = State.Ground
var velocity: Vector3 = Vector3(0,0,0)
var vel_difference: Vector3 = Vector3(0,0,0)
var gravity: Vector3 = Vector3(0, -9.8, 0) setget set_gravity
var true_up:Vector3 = -gravity.normalized()
var up: Vector3 = true_up
var target_up: Vector3 = true_up
var sneaking: bool = false

var last_wall_jump:Vector3 = Vector3.ZERO
var can_wall_jump:bool = true

const TIME_JUMP = 0.1
const TIME_REORIENT = 0
const TIME_WALLJUMP_SLIP = 0.75
const TIME_SLIP_FORGET = 3.2
var timer_air = 0

const TIME_WALL_RUN = 0.06
var timer_wall_run = 0

# Radians per second
const CAM_REORIENT_MIN = 0.5
const CAM_REORIENT_MAX = 15

# tolerances in radians
const CAM_ROLL_TOLERANCE = 0.5
const CAM_PITCH_TOLERANCE = 1

const CAMERA_VELOCITY_YAW = 0.5
const CAM_ROTATE_FOLLOW = 0.75
const CAM_MAX_ROTATE_FOLLOW = PI

const TIME_COYOTE = 0.25
const TIME_COYOTE_WALLRUN = 0.25
var timer_coyote = 0

const SPEED_ROTATE_MESH = 24
const SPEED_FLIP_JUMP = 18

const SNS_CAM_MOUSE = 0.001
const SNS_CAM_CONTROLLER = 0.02
var cameraRot: Vector2 = Vector2(0,0)
onready var camFollow = $Cam
onready var camYaw = $Cam/Yaw
onready var camSpring: SpringArm = $Cam/Yaw/SpringArm
onready var mesh: Spatial = $Armature
onready var cam : Camera = $Cam/Yaw/SpringArm/Camera
onready var cam_reverse : Camera = $Cam/Yaw/Reverse/Camera

onready var journal = cam.get_node("Journal")

onready var anim: AnimationTree = $AnimationTree
onready var statePlayback: AnimationNodeStateMachinePlayback = anim["parameters/playback"]

var stop = false
var dead = false
var local_steer: float = 0

var camRot: Vector2 = Vector2(0,0)

const SPRING_LEN_BASE = 2
const SPRING_LEN_ADD = 0.4
const SPRING_LEN_MIN = 3
const SPRING_LEN_MAX = 10

const CAM_TILT = 0.5

onready var ui = $"/root/SonicUi"

func _ready():
	set_score(score)
	set_rings(rings)
	cam.current = true

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
	$Cam/Yaw/Reverse.rotate_x(-c.y)
	camRot = newCamRot
	
	time_limit -= delta
	if time_limit <= 0:
		time_up()
	else:
		if ui:
			ui.get_node("Values/Time").text = "%2d:%02d" % [int(time_limit/60), int(time_limit)%60]

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
	var frontAngle = true_up.dot(forward)*1.5
	var sideAngle = true_up.dot(left)*1.5
	var lean:Vector2 = Vector2(
		clamp(sideAngle, -1, 1),
		clamp(frontAngle, -1, 1)
	)
	anim["parameters/Ground/Walk/1/blend_position"] = lean
	
	var wj = 0.0 if can_wall_jump else 1.5
	var old_blend: Vector2 = anim["parameters/Ground/Walk/2/blend_position"]
	var new_blend: Vector2 = Vector2(
		local_steer/(PI/3),
		clamp(speed - 9 - wj , -wj, 1)
	)
	anim["parameters/Ground/Walk/2/blend_position"] = lerp(old_blend, new_blend, 0.1)
	# Pull out camera based on speed
	camSpring.spring_length = clamp(
		speed*SPRING_LEN_ADD+SPRING_LEN_BASE,
		SPRING_LEN_MIN,
		SPRING_LEN_MAX)

	# Look ahead of the player
	var camUp = camYaw.global_transform.basis.y
	cam.global_transform = cam.global_transform.looking_at(
		camSpring.global_transform.origin + velocity*delta*CAM_TILT,
		camUp)
	
	#Yaw based on velocity
	var cz = camYaw.global_transform.basis.z
	if c == Vector2.ZERO and velocity.dot(cz) > 0:
		var v2 = MoveMath.reject(velocity, camYaw.global_transform.basis.y)
		var yawZaxis = cz.cross(v2).normalized()
		if yawZaxis.is_normalized():
			var yaw = cz.angle_to(v2)
			var fyaw = sqrt(v2.length())*(abs(yaw) + 0.3)/PI
			var cam_speed = CAMERA_VELOCITY_YAW*min(CAM_MAX_ROTATE_FOLLOW, fyaw*CAM_ROTATE_FOLLOW)
			var yaw2 = sign(yaw)*min(abs(yaw), cam_speed*delta)
			camYaw.rotate_y(yawZaxis.dot(camYaw.global_transform.basis.y)*yaw2)

func _physics_process(delta):
	if global_transform.origin.y < kill_plane:
		die()
	var s = velocity.length()
	if is_nan(s):
		print_debug("Velocity is Nan!")
		get_tree().paused = true
	elif s <= 0.02:
		velocity = Vector3.ZERO
	var new_state = state
	match state:
		State.Ground:
			if Input.is_action_just_pressed("mv_jump"):
				if statePlayback.get_current_node() == "Stop-loop":
					new_state = State.SlidingJump
				else:
					new_state = State.Jumping
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE:
					var new_wall = find_good_wall()
					if new_wall == Vector3.ZERO:
						new_state = State.Air
					else:
						set_wall(new_wall)
						if target_up.dot(true_up) <= WALL_DOT:
							if velocity.length_squared() >= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN:
								new_state = State.WallRun
							else:
								new_state = State.Slip
			else:
				if target_up.dot(true_up) < WALL_DOT:
					if velocity.length_squared() >= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN:
						timer_coyote = 0
						new_state = State.WallRun
					else:
						timer_coyote += delta
						if timer_coyote >= TIME_COYOTE:
							new_state = State.Slip
				else:
					timer_coyote = 0
		State.Jumping:
			timer_air += delta
			if timer_air >= TIME_JUMP:
				new_state = State.Air
		State.SlidingJump:
			timer_air += delta
			if timer_air >= TIME_JUMP:
				new_state = State.Backflip
		State.Air, State.Backflip:
			var n: Vector3 = Vector3.ZERO
			if is_on_floor():
				n = get_floor_normal()
			else:
				n = find_good_wall()
			if n.dot(true_up) >= WALL_DOT:
				new_state = State.Ground
			elif (n != Vector3.ZERO
				and velocity.length_squared() >= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN
			):
				set_wall(n)
				new_state = State.WallRun
		State.WallRun:
			can_wall_jump = last_wall_jump.dot(target_up) <= MIN_DOT_WALLJUMP
			if Input.is_action_just_pressed("mv_jump"):
				if can_wall_jump:
					last_wall_jump = target_up
					if statePlayback.get_current_node() == "Stop-loop":
						new_state = State.SlidingJump
					else:
						new_state = State.Jumping
				else:
					new_state = State.Slip
			elif !is_on_floor():
				timer_coyote += delta
				if timer_coyote >= TIME_COYOTE_WALLRUN:
					var new_wall = find_good_wall(0)
					if new_wall != Vector3.ZERO:
						set_wall(new_wall)
					elif $Armature/WallRunArea.get_overlapping_bodies().size() == 0:
						new_state = State.Air
			else:
				var vp = MoveMath.reject(velocity, target_up)
				timer_coyote = 0
				if target_up.dot(true_up) >= WALL_DOT:
					new_state = State.Ground
				elif vp.length_squared() <= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN:
					new_state = State.Slip
		State.Slip:
			if Input.is_action_just_pressed("mv_jump"):
				var wall = find_good_wall()
				can_wall_jump = (wall != Vector3.ZERO
					and last_wall_jump.dot(wall) <= MIN_DOT_WALLJUMP 
					and timer_air < TIME_WALLJUMP_SLIP)
				if can_wall_jump:
					last_wall_jump = wall
					if statePlayback.get_current_node() == "Stop-loop":
						new_state = State.SlidingJump
					else:
						new_state = State.Jumping
			elif is_on_floor():
				var n = get_floor_normal()
				if n.dot(true_up) >= WALL_DOT:
					new_state = State.Ground
			elif ( velocity.length_squared() >= SPEED_WALL_RUN_RECOVERY*SPEED_WALL_RUN_RECOVERY
				and $Armature/WallRunArea.get_overlapping_bodies().size() > 0
			):
				new_state = State.WallRun
			elif timer_air > TIME_SLIP_FORGET:
				new_state = State.Air
		State.CustomAnimation:
			if statePlayback.get_current_node() == "Ground":
				new_state = State.Ground
	set_state(new_state)
	match state:
		State.Ground:
			process_ground(delta, ACCEL_RUN, ACCEL_START)
		State.Air, State.Slip:
			process_air(ACCEL_AIR, delta)
		State.Backflip:
			process_air(ACCEL_BACKFLIP, delta)
		State.WallRun:
			var friction = clamp(target_up.dot(true_up), 0, 1)
			var wall_accel = lerp(ACCEL_WALLRUN, ACCEL_RUN, friction)
			var slide_accel = lerp(ACCEL_SLIDE_WALLRUN, ACCEL_START, friction)
			process_ground(delta, wall_accel, slide_accel)
		State.Jumping:
			process_jump(ACCEL_JUMPING, delta, 4)
		State.SlidingJump:
			process_air(ACCEL_JUMPING_SLIDE, delta)

	var speed = velocity.length()/MAX_SNEAK
	
	var view_up: Vector3 = up
	if state == State.Ground:
		view_up = lerp(true_up, up, clamp(speed/2 - 0.7, 0, 1)).normalized()
	# Reorient upward
	# Pitch
	var baseZ = camFollow.global_transform.basis.z
	var targetZ = camFollow.global_transform.basis.x.cross(view_up).normalized()
	var pitchAngle:float = baseZ.angle_to(targetZ)
	var q = clamp(abs(pitchAngle)/CAM_PITCH_TOLERANCE, 0, 1)
	var pitchSpeed = lerp(CAM_REORIENT_MIN, CAM_REORIENT_MAX, q)
	var pitchAxis:Vector3 = baseZ.cross(targetZ).normalized()

	if pitchAxis.is_normalized():
		var pitch = min(abs(pitchAngle), max(
			abs(pitchAngle)*pitchSpeed*delta,
			CAM_REORIENT_MIN*delta
		))
		camFollow.global_rotate(pitchAxis, sign(pitchAngle)*pitch)

	# Roll
	var baseY = camFollow.global_transform.basis.y
	var targetY = MoveMath.reject(view_up, camFollow.global_transform.basis.z).normalized()
	var rollAngle = baseY.angle_to(targetY)
	q = clamp(abs(rollAngle)/CAM_ROLL_TOLERANCE, 0, 1)
	var rollSpeed = lerp(CAM_REORIENT_MIN, CAM_REORIENT_MAX, q)
	var rollAxis = baseY.cross(targetY).normalized()

	if rollAxis.is_normalized():
		var roll = min( abs(rollAngle), max(
			abs(rollAngle)*rollSpeed*delta,
			CAM_REORIENT_MIN*delta
		))
		camFollow.global_rotate(rollAxis, sign(rollAngle)*roll)
	
	$debugUI/status/Up.text = "UP: " + MoveMath.pr(up)
	$debugUI/status/Velocity.text = "VEL: " + str(velocity.length())
	$debugUI/status/Position.text = "ORIG: " + MoveMath.pr(global_transform.origin)
	#$debugUI/status/Extra.text = "F_VEL: " + MoveMath.pr(velocity_floor)

func process_ground(delta, accel_move, accel_start):
	sneaking = Input.is_action_pressed("mv_sneak")
	var running = velocity.length_squared() > SPEED_RUN*SPEED_RUN
	
	var input: Vector3 = get_movement(target_up)
	var movement:Vector3 
	if MoveMath.reject(velocity, up).length_squared() < SPEED_STOPPED*SPEED_STOPPED:
		movement = input
	else:
		movement = input.project(velocity)
	
	if is_nan(movement.length()):
		print_debug("ded")
		print("Velocity:", velocity)
		print("Movement:", movement)
		print("Input:",input)
		print("Up:", up)
		print("Target Up:", target_up)
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
		var vp = MoveMath.reject(velocity, up)
		if vp.length_squared() <= SPEED_STOPPED*SPEED_STOPPED:
			velocity = (velocity + vel_difference).project(up)
		elif vp.length_squared() <= SPEED_STOPPING*SPEED_STOPPING:
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
	
	var steer_speed:float = 180/(max(6, (velocity.length())*4))
	var steer_angle = steer(delta, input, steer_speed)
	var floorvel = MoveMath.reject(velocity, up)
	
	if PI - abs(steer_angle) <= MIN_ANGLE_SLIDE and (
		input != Vector3.ZERO and
		floorvel.length_squared() >= SPEED_RUN*SPEED_RUN
	):
		statePlayback.travel("Stop-loop")
	
	vel_difference = velocity
	if is_nan(velocity.length()):
		print_debug("ded")
		print("Velocity:", velocity)
		print("Steer:", steer_angle)
		print("Movement:", movement)
		print("Input:",input)
		print("Up:", up)
		print("Target Up:", target_up)
		get_tree().paused = true
		return
	if !up.is_normalized():
		print("up is bad")
	velocity -= up*delta*FLOOR_MAGNETISM
	velocity = move_and_slide(velocity, target_up, false, 4, ANGLE_FLOOR)
	vel_difference -= velocity
	
	if state == State.WallRun:
		var new_wall = find_good_wall()
		if new_wall != Vector3.ZERO:
			set_wall(new_wall)
		reorient(target_up, 25, 50, delta)
	else:
		if is_on_floor():
			var n = get_floor_normal()
			if n.dot(target_up) > 0.5:
				target_up = n
			else:
				target_up = lerp(target_up, n, 0.5)
		reorient(target_up, 40, 60, delta)

func process_air(accel, delta):
	var movement = get_movement()*accel
	var drag = -DRAG_AIR*velocity*velocity*velocity
	if movement.dot(velocity) > 0 && velocity.length_squared() > MAX_AIR_VEL*MAX_AIR_VEL:
		movement = MoveMath.reject(movement, velocity)
	velocity += (movement + gravity + drag) * delta
	vel_difference = velocity
	velocity = move_and_slide(velocity, up, false, 4, ANGLE_FLOOR)
	vel_difference -= velocity
	
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		reorient_air(true_up, delta*REORIENT_AIR)
	target_up = up

func process_jump(accel, delta, turn_rate = 1):
	var input: Vector3 = get_movement(target_up)
	var movement:Vector3 
	if MoveMath.reject(velocity, up).length_squared() < SPEED_STOPPED*SPEED_STOPPED:
		movement = input
	else:
		movement = input.project(velocity)*accel
	var drag = -DRAG_AIR*velocity*velocity*velocity
	if movement.dot(velocity) > 0 && velocity.length_squared() > MAX_AIR_VEL*MAX_AIR_VEL:
		movement = MoveMath.reject(movement, velocity)
	velocity += (movement + gravity + drag) * delta
	vel_difference = velocity
	velocity = move_and_slide(velocity, up, false, 4, ANGLE_FLOOR)
	vel_difference -= velocity
	
	var steer_speed:float = 180/(max(6, (velocity.length())*4))
	steer(delta, input, steer_speed*turn_rate)
	
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		reorient_air(true_up, delta*REORIENT_AIR)
	target_up = up

func steer(delta:float, dir:Vector3, steer_speed:float):
	var floorvel = MoveMath.reject(velocity, up)
	var steer_angle = floorvel.angle_to(dir)
	var axis = floorvel.cross(dir).normalized()
	
	if statePlayback.get_current_node() == "Stop-loop":
		if (floorvel.length_squared() < SPEED_STOPPED*SPEED_STOPPED or
			PI - abs(steer_angle) > MAX_ANGLE_SLIDE
		):
			statePlayback.travel("Ground")
		else:
			steer_angle -= PI
			steer_angle *= 0.2
	if steer_angle != 0 and axis.is_normalized():
		var angle = sign(steer_angle)*min(abs(steer_angle), steer_speed*delta)
		var factor = (1 - (angle*angle)/(4*PI*PI))
		velocity = velocity.rotated(axis, angle)*factor
		local_steer = -steer_angle*up.dot(axis)
		
	return steer_angle

func reorient(new_up:Vector3, rotate_speed: float, min_rotate_speed:float, delta:float):
	if !new_up.is_normalized():
		new_up = true_up

	var angle = up.angle_to(new_up)
	var speed = max(min_rotate_speed, abs(angle)*rotate_speed)
	var rotate: float = sign(angle)*min(abs(angle), speed*delta)
	var up_axis = up.cross(new_up).normalized()
	if up_axis.is_normalized():
		rotate_up(up_axis, rotate)

func reorient_air(desiredUp:Vector3, delta:float):
	var interpRoll = min(delta*REORIENT_ROLL, 1)
	var interpPitch = min(delta*REORIENT_PITCH, 1)

	# Roll upright
	var forward = camYaw.global_transform.basis.z
	var upTarget = MoveMath.reject(desiredUp, forward).normalized()
	var upCurrent = MoveMath.reject(up, forward).normalized()
	var rollangle = upCurrent.angle_to(upTarget)
	var roll = rollangle
	if abs(rollangle) > MIN_FLOOR_ANGLE:
		roll *= interpRoll
	var rollAxis = upCurrent.cross(upTarget).normalized()
	if rollAxis.is_normalized():
		upCurrent = up.rotated(rollAxis, rollangle)
		rotate_up(rollAxis, roll)
		
	# Pitch upright
	upTarget = desiredUp
	var pitchAngle = upCurrent.angle_to(upTarget)
	if abs(pitchAngle) > MIN_FLOOR_ANGLE:
		pitchAngle *= interpPitch
	var pitchAxis = upCurrent.cross(upTarget).normalized()
	if pitchAxis.is_normalized():
		rotate_up(pitchAxis, pitchAngle)
	
	
func find_good_wall(min_grounded = MIN_GROUNDED_ON_WALL) -> Vector3:
	var new_wall = Vector3.ZERO
	var v = velocity + vel_difference
	for i in range(0, get_slide_count()):
		var col: KinematicCollision = get_slide_collision(i)
		if $Armature/WallRunArea.overlaps_body(col.collider):
			var n = col.normal
			var f = v.dot(n)
			if f <= min_grounded and f < v.dot(new_wall):
				new_wall = n.normalized()
	
	return new_wall

func set_state(new_state):
	$debugUI/status/State.text = State.keys()[state]
	if state == new_state:
		return
	timer_wall_run = 0
	timer_coyote = 0
	if new_state == State.CustomAnimation:
		journal.enabled = false
	else:
		journal.enabled = true
	match new_state:
		State.Ground:
			can_wall_jump = true
			$CustomAnimation.play("Jump-Reset")
			timer_air = 0
			statePlayback.travel("Ground")
			last_wall_jump = Vector3.ZERO
		State.Air, State.Backflip:
			if state != State.Jumping and state != State.SlidingJump:
				statePlayback.travel("Fall")
		State.Jumping:
			statePlayback.travel("Jump")
			$CustomAnimation.play("Jump-Roll")
			if state == State.Slip:
				velocity += target_up*VEL_JUMP
			else:
				velocity += up*VEL_JUMP
			sneaking = false
		State.SlidingJump:
			statePlayback.travel("Jump")
			$CustomAnimation.play("Jump-Backflip")
			if state == State.Slip:
				velocity += target_up*VEL_JUMP
			else:
				velocity += up*VEL_JUMP
			sneaking = false
		State.WallRun:
			$CustomAnimation.play("Jump-Reset")
			timer_air = 0
			if target_up == Vector3.ZERO:
				var nw = find_good_wall()
				if nw == Vector3.ZERO:
					set_wall(up)
				else:
					set_wall(nw)
			statePlayback.travel("Ground")
		State.Slip:
			$CustomAnimation.play("Jump-Reset")
			statePlayback.travel("Fall")
	state = new_state

# Rotate the player mesh about about axis by an angle in radians
func rotate_up(axis: Vector3, angle:float):
	up = up.rotated(axis, angle)
	var mx = mesh.global_transform.basis.x
	var mz = mx.cross(up).normalized()
	mx = mx.rotated(axis, angle).normalized()
	mesh.global_transform = Transform(Basis(mx, up, mz), mesh.global_transform.origin)

func rotate_by_speed(delta):
	# reversed
	var desired_forward = velocity
	if state == State.SlidingJump or state == State.Backflip:
		desired_forward = -velocity
	var bx = up.cross(desired_forward).normalized()
	var rx = mesh.global_transform.basis.x.normalized()
	var r = rx.angle_to(bx)
	if r == 0:
		return
	var axis = rx.cross(bx).normalized()
	var angle = sign(r)*min(abs(r), delta*SPEED_ROTATE_MESH)
	
	if axis.is_normalized():
		mesh.global_rotate(axis, angle)

func get_movement(movement_up: Vector3 = up)->Vector3:
	var input = Vector2(
		Input.get_action_strength("mv_left") - Input.get_action_strength("mv_right"),
		Input.get_action_strength("mv_forward") - Input.get_action_strength("mv_back"))
	
	if input.length_squared() > 1:
		input = input.normalized()

	var x = MoveMath.reject(camYaw.global_transform.basis.x, movement_up).normalized()
	var z = MoveMath.reject(camYaw.global_transform.basis.z, movement_up).normalized() 
	return (
		x*input.x
		+ z*input.y)

func get_camera_rot()->Vector2:
	var ret = cameraRot*SNS_CAM_MOUSE
	cameraRot = Vector2(0,0)
	var c = Vector2(
		Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left"),
		Input.get_action_strength("cam_up") - Input.get_action_strength("cam_down")
	)
	c = Vector2(
		sign(c.x)*pow(abs(c.x), 2.6),
		-sign(c.y)*pow(abs(c.y), 2.6)
	)
	return ret + c*SNS_CAM_CONTROLLER

func fix_camera():
	camYaw.rotate_y(-camRot.x)
	camSpring.rotate_x(camRot.y)
	$Cam/Yaw/Reverse.rotate_x(-camRot.y)

func set_wall(w):
	if w == Vector3.ZERO:
		print_debug("Bad Wall")
		print_stack()
		get_tree().paused = true
	target_up = w

func set_gravity(g):
	gravity = g
	true_up = -(g.normalized())

func attack_position():
	return $CollisionShape.global_transform.origin

func kill():
	dead = true
	if time_limit > 0:
		$"/root/Respawn".reset_level()
	else:
		$"/root/Respawn".reset_no_respawn()

func die():
	state = State.Dead
	$DeathScreen/Label.text = "Game Over"
	$CustomAnimation.play("Die")

func time_up():
	$DeathScreen/Label.text = "Time's Up"
	$CustomAnimation.play("Die")

func set_score(s):
	score = s
	if ui:
		ui.get_node("Values/Score").text = str(s)

func set_rings(r):
	rings = r
	if ui:
		ui.get_node("Values/Rings").text = str(r)

func give_points(p):
	set_score(score + p)

func playAnimation(animation:String):
	statePlayback.travel(animation)
	set_state(State.CustomAnimation)

func endAnimation():
	set_state(State.Ground) 
	
func read_hint_text(text:String):
	$HintUI/Label.text = "Hint: "+text
	$HintUI/hint_anim.play("show")

func get_journal_page(page:Texture):
	var j = cam.get_node("Journal")
	if !(page in j.pages):
		j.pages.push_back(page)
		$HintUI/journal_anim.play("show_journal")
		j.current_page = j.pages.size() - 1
