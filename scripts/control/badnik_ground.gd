extends KinematicBody

class_name BadnikGround

var gravity: Vector3 = Vector3(0, -9.8, 0)
var up: Vector3 = Vector3.UP

var velocity: Vector3 = Vector3(0,0,0)

var sonicNode: NodePath
onready var sonic: Sonic = get_node(sonicNode)

var accel_move:float = 20
var drag_move: float = 0.1

func _physics_process(delta):
	pass
