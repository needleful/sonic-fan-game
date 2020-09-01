extends KinematicBody

class_name Sonic

enum State {
	Ground,
	Jumping,
	Air,
	WallRun,
	Slip,
}

const VEL_JUMP = 10
const ACCEL_START = 90
const ACCEL_RUN = 16
const ACCEL_WALLRUN = 8
const ACCEL_JUMPING = 80
const ACCEL_AIR = 4
const MAX_RUN = 90
const MIN_SLIDE_ACCEL = 3
const SPEED_RUN = 10
const SPEED_STOPPING = 4
const SPEED_STOPPED = 1

const ACCEL_SNEAK = 18
const MAX_SNEAK = 8

const DRAG_STOPPING = 1.2
const DRAG_GROUND = 0.2
const DRAG_AIR = 0.00005
const FORCE_CENTRIFUGAL = 1

const MIN_GROUNDED_ON_WALL = 0.001
const MIN_SPEED_WALL_RUN = 15
const TIME_WALL_RUN = 0.0
const WALL_RUN_MAGNETISM = 20
const WALL_DOT = 0.7
const MIN_ROLL_WALLRUN = .75

var state = State.Ground
var velocity: Vector3 = Vector3(0,0,0)
var vel_difference: Vector3 = Vector3(0,0,0)
var gravity: Vector3 = Vector3(0, -9.8, 0) setget set_gravity
var up: Vector3 = Vector3(0, 1, 0)
var sneaking: bool = false

var timer_wall_run = 0
var recover = true
var wall:Vector3 = Vector3(0,0,0)


export(float) var time_limit = 600
export(int) var score = 0 setget set_score
export(int) var rings = 0 setget set_rings

const TIME_JUMP = 0.1
const TIME_REORIENT = 0.1
var timer_air = 0

# Radians per second
const SPEED_REORIENT_MIN = deg2rad(90)
# 1/x seconds to reorient
const SPEED_REORIENT = 1.2

const TIME_COYOTE = 0.2
var timer_coyote = 0

const SNS_CAM_MOUSE = 0.001
var cameraRot: Vector2 = Vector2(0,0)
onready var camYaw = $CamYaw
onready var camFollow: Spatial = $CamYaw/CamFollow
var oldFollow: Transform
onready var camSpring: Spatial = $CamYaw/CamFollow/SpringArm
onready var mesh: Spatial = $Armature/Skeleton/Sonic
onready var cam : Camera = $CamYaw/CamFollow/SpringArm/Camera
onready var cam_reverse : Camera = $CamYaw/CamFollow/Reverse/Camera

onready var anim: AnimationTree = $AnimationTree
onready var statePlayback: AnimationNodeStateMachinePlayback = anim["parameters/playback"]
onready var debug_imm : ImmediateGeometry = $debug_imm

var stop = false
var dead = false

func _ready():
	set_score(score)
	set_rings(rings)
	cam.current = true
	oldFollow = Transform(camFollow.global_transform)
	statePlayback.start("Ground")

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
	var c = get_camera_rot()
	camYaw.rotate_y(-c.x)
	if cam_reverse.current:
		$CamYaw/CamFollow/Reverse.rotate_x(-c.y)
	else:
		camSpring.rotate_x(c.y)
	
	time_limit -= delta
	$UI/Values/Time.text = "%2d:%02d" % [int(time_limit)/60, int(time_limit)%60]

	$debugUI/status/Up.text = MoveMath.pr(up)
	$debugUI/status/Velocity.text = str(velocity.length())
	$debugUI/status/Position.text = MoveMath.pr(global_transform.origin)

func _physics_process(delta):
	if up.length_squared() < 0.7:
		up = -gravity.normalized()
	oldFollow.basis = camFollow.global_transform.basis
	var new_state = state
	match state:
		State.Ground, State.WallRun:
			if Input.is_action_just_pressed("mv_jump"):
				new_state = State.Jumping
			elif !is_on_floor():
				if state == State.WallRun or $FloorArea.get_overlapping_bodies().size() == 0:
					timer_coyote += delta
					if timer_coyote >= TIME_COYOTE:
						if state == State.WallRun:
							var new_wall = stick_to_wall()
							if wall != Vector3.ZERO:
								wall = new_wall
							elif $WallRunArea.get_overlapping_bodies().size() == 0:
								print("fell from wall")
								new_state = State.Air
						else:
							new_state = State.Air
			else:
				timer_coyote = 0
				if state == State.WallRun:
					if !recover:
						new_state = State.Slip
						print("Bad wall run")
					elif up.dot(Vector3.UP) >= WALL_DOT:
						new_state = State.Ground
					elif velocity.length_squared() <= MIN_SPEED_WALL_RUN*MIN_SPEED_WALL_RUN:
						new_state = State.Slip
				elif up.dot(Vector3.UP) < WALL_DOT:
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
				n = stick_to_wall()
				if n != Vector3.ZERO:
					timer_wall_run += delta
					if timer_wall_run < TIME_WALL_RUN:
						n = Vector3.ZERO
				else:
					timer_wall_run = 0
			if n.dot(Vector3.UP) >= WALL_DOT:
				new_state = State.Ground
			elif n != Vector3.ZERO:
				if recover:
					reorient_wall(n, delta*12)
					new_state = State.WallRun
				else:
					new_state = State.Slip
		State.Slip:
			var jumped: bool = false
			if Input.is_action_just_pressed("mv_jump"):
				var new_wall = stick_to_wall()
				if new_wall != Vector3.ZERO:
					wall = new_wall
				reorient_wall(wall, delta*20)
				jumped = true
		
			if jumped:
				new_state = State.Jumping
			elif is_on_floor():
				var n = get_floor_normal()
				if n.dot(Vector3.UP) >= WALL_DOT:
					new_state = State.Ground
			else:
				var new_wall = stick_to_wall()
				if new_wall == Vector3.ZERO:
					new_state = State.Air
				else:
					wall = new_wall
	set_state(new_state)
	match state:
		State.Ground:
			process_ground(delta, ACCEL_RUN, ACCEL_START)
		State.Air:
			process_air(delta)
		State.Jumping:
			process_jump(delta)
		State.WallRun:
			reorient_wall(wall, delta*3)
			velocity -= wall*WALL_RUN_MAGNETISM*delta
			process_ground(delta, ACCEL_WALLRUN, ACCEL_WALLRUN)
		State.Slip:
			velocity -= wall*WALL_RUN_MAGNETISM*delta
			process_air(delta)
	
	var min_allowed_drift = 1 #radians
	var yawup = camYaw.global_transform.basis.y
	var followup = oldFollow.basis.y
	var upAngle = followup.angle_to(yawup)
	
	var yawZ = camYaw.global_transform.basis.z
	var followZ = camFollow.global_transform.basis.z
	var fAngle:float = followZ.angle_to(yawZ)
	
	if abs(upAngle) > 0.05:
		var min_rot = max(0, abs(upAngle) - min_allowed_drift)
		var rot = max(min_rot, abs(upAngle)*SPEED_REORIENT*delta)
		
		var upAxis = followup.cross(yawup).normalized()
		camFollow.global_transform.basis = oldFollow.rotated(
			upAxis, 
			sign(upAngle) * min (
				abs(upAngle), 
				max( rot, SPEED_REORIENT_MIN*delta )
			)
		).basis
		oldFollow = camFollow.global_transform
	if abs(fAngle) >= 0.05:
		var min_rot = max(0, abs(fAngle) - min_allowed_drift)
		var rot = max(min_rot, abs(fAngle)*SPEED_REORIENT*delta)
		
		var fAxis:Vector3 = followZ.cross(yawZ).normalized()
		camFollow.global_transform.basis = oldFollow.rotated(
			fAxis, 
			sign(fAngle) * min (
				abs(fAngle), 
				max( rot, SPEED_REORIENT_MIN*delta )
			)
		).basis
	
	# Animation Logic
	var speed: float
	if state == State.Ground:
		speed = velocity.length()/MAX_SNEAK
		anim["parameters/Ground/blend_position"] = speed
		anim["parameters/Ground/1/speed/scale"] = max(1, .5 + speed/2)
		anim["parameters/Ground/2/speed/scale"] = speed/3
	else:
		speed = MoveMath.reject(velocity, up).length()/MAX_SNEAK

	$debugUI/status/State.text = State.keys()[state]

func process_ground(delta, accel_move, accel_start):
	sneaking = Input.is_action_pressed("mv_sneak")
	
	var movement: Vector3 = get_movement()
	if velocity.length_squared() >= SPEED_RUN*SPEED_RUN:
		movement *= accel_move
	elif sneaking:
		movement *= max(ACCEL_SNEAK, accel_move)
	else:
		movement *= accel_start
	
	var drag : Vector3
	var c = 1 #max(0, vel_difference.normalized().dot(-up))
	var centrifugal_force = vel_difference*FORCE_CENTRIFUGAL
	var v = MoveMath.reject(velocity, up)
	
	if movement.dot(velocity) < 0 || movement.length_squared() == 0:
		drag = -DRAG_STOPPING*v
		velocity += (movement*c + gravity + drag + centrifugal_force) * delta
		if velocity.length_squared() <= SPEED_STOPPING*SPEED_STOPPING:
			var stop_force
			if delta*accel_start >= 1:
				stop_force = velocity
			else:
				stop_force = velocity*delta*accel_start
			velocity -= stop_force
		if movement.length_squared() == 0 and velocity.length_squared() <= SPEED_STOPPED*SPEED_STOPPED:
			velocity = (velocity + vel_difference).project(up)
	else:
		if velocity.length_squared() >= MAX_RUN*MAX_RUN or (
			sneaking and velocity.length_squared() >= MAX_SNEAK*MAX_SNEAK
		):
			movement = Vector3(0,0,0)
		drag = -DRAG_GROUND*v
		velocity += (movement*c + gravity + drag + centrifugal_force) * delta
	
	vel_difference = velocity
	velocity = move_and_slide(velocity, up)
	vel_difference -= velocity
	if velocity.length_squared() >= SPEED_STOPPED*SPEED_STOPPED:
		rotate_by_speed()
	
	if is_on_floor():
		reorient_ground(get_floor_normal(), 0.9, 12, delta)
	elif state == State.Ground:
		reorient_ground(Vector3.UP, 0.2, 2, delta)
	else:
		var new_wall = stick_to_wall()
		if new_wall != Vector3.ZERO:
			wall = new_wall
		reorient_wall(wall, delta*3)

func process_jump(delta):
	var movement: Vector3 = get_movement()*ACCEL_JUMPING
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	
	vel_difference = velocity
	velocity = move_and_slide(velocity, up)
	vel_difference -= velocity
	if velocity.length_squared() >= 0.01:
		rotate_by_speed()

func process_air(delta):
	var movement = get_movement()*ACCEL_AIR
	var drag = -DRAG_AIR*velocity*velocity*velocity
	velocity += (movement + gravity + drag) * delta
	vel_difference = velocity
	velocity = move_and_slide(velocity, up)
	vel_difference -= velocity
	
	timer_air += delta
	if timer_air >= TIME_REORIENT:
		var desiredUp = -gravity.normalized()
		reorient_air(desiredUp, delta)

func reorient_ground(new_up:Vector3, interp:float, max_radians, delta):
	if new_up.length_squared() <= 0.9:
		new_up = Vector3.UP
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
		#camSpring.rotate_x(-angle*interp)

func stick_to_wall():
	var desiredUp = Vector3.ZERO
	var v = velocity + vel_difference
	for i in range(0, get_slide_count()):
		var n = get_slide_collision(i).normal
		var f = v.dot(n)
		if f <= -MIN_GROUNDED_ON_WALL and f < v.dot(desiredUp):
			desiredUp = n.normalized()
	
	return desiredUp

func reorient_wall(desiredUp:Vector3, delta:float):
	var interp = min(delta, 1)
	# Roll upright
	var forward = camYaw.global_transform.basis.z
	var left = camYaw.global_transform.basis.x
	var df = left.cross(desiredUp).normalized()
	
	var upTarget = MoveMath.reject(desiredUp, forward).normalized()
	var upCurrent = MoveMath.reject(up, forward).normalized()
	
	var angle = upCurrent.angle_to(upTarget)
	var rollAxis = upCurrent.cross(upTarget).normalized()
	var min_angle = abs((abs(angle) - MIN_ROLL_WALLRUN))
	
	#var rotation = sign(angle)*max(abs(angle*interp), min_angle)
	var rotation = angle*interp
	if rollAxis.length_squared() > 0.9:
		global_rotate(rollAxis, rotation)
		up = up.rotated(rollAxis, rotation)
	
	# Pitch upright
	angle = forward.angle_to(df)
	rotation = angle*interp
	var pitchAxis = forward.cross(df).normalized()
	if pitchAxis.length_squared() > 0.9:
		global_rotate(pitchAxis, rotation)
		up = up.rotated(pitchAxis, rotation)
		#camSpring.rotate_x(-angle*interp)

func set_state(new_state):
	if state == new_state:
		return
	print(State.keys()[state], State.keys()[new_state])
	state = new_state
	match state:
		State.Ground:
			$Ball.visible = false
			timer_coyote = 0
			camFollow.global_transform.basis = camYaw.global_transform.basis
			statePlayback.travel("Ground")
			recover = true
		State.Air:
			timer_air = 0
			timer_wall_run = 0
		State.Jumping:
			$Ball.visible = true
			statePlayback.travel("Jump")
			timer_air = 0
			velocity += up*VEL_JUMP
			sneaking = false
		State.WallRun:
			$Ball.visible = false
			timer_coyote = 0
			camFollow.global_transform.basis = camYaw.global_transform.basis
			statePlayback.travel("Ground")
		State.Slip:
			$Ball.visible = false
			recover = false
			timer_air = 0
			timer_wall_run = 0

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

func attack_position():
	return $CollisionShape.global_transform.origin

func kill():
	dead = true
	var _x = get_tree().reload_current_scene()

func die():
	$CustomAnimation.play("Die")

func set_score(s):
	score = s
	$UI/Values/Score.text = str(s)

func set_rings(r):
	rings = r
	$UI/Values/Rings.text = str(r)

func give_points(p):
	set_score(score + p)
