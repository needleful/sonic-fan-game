extends KinematicBody

class_name BadnikGround

var gravity: Vector3 = Vector3(0, -9.8, 0)
var up: Vector3 = Vector3.UP

var velocity: Vector3 = Vector3(0,0,0)

export(NodePath) var sonicNode: NodePath
onready var sonic: Sonic = get_node(sonicNode)

export(float) var accel_move:float = 18
export(float) var accel_stop: float = 60
export(float) var accel_air: float = 9
export(float) var drag_move: float = 0.15
const DRAG_AIR = 0.00005
onready var cast = $GroundCast

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
var mstate = MoveState.Ground

const ATTACK_TIME = 1
var attack_timer = 0
var attacking = false

const COYOTE_TIME = 0.25
var coyote_timer = 0

func _ready():
	$AttackArea.connect("body_entered", self, "onAttack")
	$AttackArea.connect("body_exited", self, "onAttackStop")
	$AttackArea/Weapon.connect("body_entered", self, "kill")

func kill(body):
	if body is Sonic:
		body.kill()

func _physics_process(delta):
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
	process_chase(delta)
	
	if attacking:
		attack_timer += delta
	elif attack_timer > 0:
		attack_timer += delta
		if attack_timer > ATTACK_TIME:
			doneAttacking()

func process_chase(delta):
	var dir:Vector3 = sonic.global_transform.origin - global_transform.origin
	var move:Vector3 = MoveMath.reject(dir, up).normalized()
	var drag:Vector3
	if mstate == MoveState.Air:
		move *= accel_air
		drag = -DRAG_AIR*velocity*velocity*velocity
	else:
		if dir.dot(velocity) <= 0:
			move *= accel_stop
		else:
			move *= accel_move
		drag = -drag_move*velocity
	
	velocity += (gravity + move + drag)*delta
	velocity = move_and_slide(velocity, up)
	
	rotate_by_speed()
	if is_on_floor():
		reorient(get_floor_normal(), 0.9, 1800, delta)
	elif mstate == MoveState.Air:
		if cast.is_colliding():
			reorient(cast.get_collision_normal(), 0.1, 60, delta)
		else:
			reorient(Vector3.UP, 0.1, 120, delta)
	
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

func rotate_by_speed():
	var by = up.cross(velocity).normalized()
	global_transform.basis = Basis(
		by,
		up,
		by.cross(up)
	)

func onAttack(_b):
	attacking = true
	attack_timer = 0
	$AttackLight.visible = true

func onAttackStop(_b):
	attacking = false

func doneAttacking():
	attack_timer = 0
	$AttackLight.visible = false
