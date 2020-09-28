extends Area
class_name LoadZone

export (NodePath) var scene_root
export (String, FILE, "*.tscn") var next_scene

func _ready():
	connect("body_entered", self, "on_body_entered")

func on_body_entered(x:Spatial):
	if x is Sonic:
		$"/root/Respawn".replace_scene(get_node(scene_root), next_scene, x, global_transform)
