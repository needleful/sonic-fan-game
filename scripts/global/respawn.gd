extends Node
class_name RespawnManager

var respawn_point: NodePath
var respawn_priority: int

func reset_level():
	var _x = get_tree().reload_current_scene()
	if respawn_priority >= 0 and has_node(respawn_point):
		for s in get_tree().get_nodes_in_group("player"):
			call_deferred("place_player", s.get_path(), s.time_limit)
	else:
		print("No respawn: ", respawn_point)
	
func place_player(path, time_limit):
	print(path, time_limit)
	var player: Sonic = get_node(path)
	player.time_limit = time_limit
	var point: Spatial = get_node(respawn_point)
	player.global_transform = point.global_transform

func reset_no_respawn():
	respawn_point = NodePath("")
	respawn_priority = -9999
	var _x = get_tree().reload_current_scene()

func set_spawn(c: Checkpoint):
	if c.respawn_priority >= respawn_priority:
		respawn_priority = c.respawn_priority
		respawn_point = c.get_path()
