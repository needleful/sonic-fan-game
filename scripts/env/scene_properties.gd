extends Spatial
class_name SceneProperties

export(String) var zone_name: String
export(int) var act: int

func _ready():
	if $"/root/Respawn".new_level:
		$"/root/SceneCards".open_level(zone_name, act)
