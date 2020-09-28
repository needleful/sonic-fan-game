extends Node
class_name RespawnManager

var respawn_point: NodePath
var respawn_priority: int

var load_thread: Thread
var target_transform:Transform
var player: Sonic

func reset_level():
	var _x = get_tree().reload_current_scene()
	if respawn_priority >= 0 and has_node(respawn_point):
		for s in get_tree().get_nodes_in_group("player"):
			call_deferred("place_player", s.get_path(), s.time_limit)
	else:
		print("No respawn: ", respawn_point)
	
func place_player(path, time_limit):
	print(path, time_limit)
	var sonic: Sonic = get_node(path)
	sonic.time_limit = time_limit
	var point: Spatial = get_node(respawn_point)
	sonic.global_transform = point.global_transform

func reset_no_respawn():
	respawn_point = NodePath("")
	respawn_priority = -9999
	var _x = get_tree().reload_current_scene()

func set_spawn(c: Checkpoint):
	if c.respawn_priority >= respawn_priority:
		respawn_priority = c.respawn_priority
		respawn_point = c.get_path()

func load_scene(d:Dictionary):
	var path = d["new_scene"]
	var old_scene = d["old_scene"]
	assert(old_scene)
	var iloader = ResourceLoader.load_interactive(path)
	assert(iloader)
	var result = null
	while true:
		var res:int = iloader.poll()
		if res == ERR_FILE_EOF:
			result = iloader.get_resource()
			break
		elif res != OK:
			print_debug("Failed to load %s with error %d" % [path, res])
			break
	var node
	if result == null:
		print("Failed to load scene")
		node = null
		return
	else:
		node = result.instance()
	if node == null:
		print("Failed to instantiate loaded file")
		return
	assert(old_scene)
	call_deferred("finish_load", old_scene, node)

func replace_scene(old_scene:Node, new_scene_file:String, p_player:Sonic, transform:Transform):
	assert(old_scene)
	player = p_player
	target_transform = transform
	load_thread = Thread.new()
	load_thread.start(self, "load_scene", {"old_scene":old_scene, "new_scene":new_scene_file})

func finish_load(old_scene:Node, new_scene:Node):
	assert(old_scene)
	load_thread.wait_to_finish()
	set_process(false)
	var oldPos = player.global_transform.origin
	player.get_parent().remove_child(player)
	old_scene.queue_free()
	$"/root".add_child(new_scene)
	if new_scene.has_node("player_spawn"):
		var new_target: Spatial = new_scene.get_node("player_spawn")
		var relPos = target_transform.xform_inv(oldPos)
		var absPos = new_target.global_transform.xform(relPos)
		
		print(oldPos, "->", relPos, "->", absPos)
		player.global_transform.origin = absPos
		for s in get_tree().get_nodes_in_group("player"):
			s.free()
		$"/root".add_child(player)
		player.fix_camera()
