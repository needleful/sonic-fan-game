extends Area
class_name Checkpoint

export(int) var respawn_priority: int = 1

func _ready():
	var _x = connect("body_entered", self, "on_body_entered")

func on_body_entered(body: Node):
	if body is Sonic and !body.dead:
		print("Setting checkpoint: ", self.get_path())
		$"/root/Respawn".set_spawn(self)
	else:
		print("Not Sonic: ", body.name)
