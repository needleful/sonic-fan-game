extends Node
class_name RespawnManager

var respawn_point: NodePath
var respawn_priority: int

var load_thread: Thread
var target_transform:Transform
var player: Sonic
var old_scene: WeakRef

func reset_level():
	if player != null:
		player.queue_free()
		player = null
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
	if player != null:
		player.queue_free()
		player = null
	respawn_point = NodePath("")
	respawn_priority = -9999
	var _x = get_tree().reload_current_scene()

func set_spawn(c: Checkpoint):
	if c.respawn_priority >= respawn_priority:
		respawn_priority = c.respawn_priority
		respawn_point = c.get_path()

func replace_scene(p_old_scene:Node, new_scene_file:String, p_player:Sonic, transform:Transform):
	old_scene = weakref(p_old_scene)
	assert(old_scene.get_ref())
	player = p_player
	target_transform = transform
	load_thread = Thread.new()
	var _x = load_thread.start(self, "load_scene", new_scene_file)

func load_scene(path):
	assert(old_scene.get_ref())
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
	if result == null:
		print("Failed to load scene")
		return
	assert(old_scene.get_ref())
	call_deferred("finish_load", result)

func finish_load(new_scene:PackedScene):
	load_thread.wait_to_finish()
	set_process(false)
	#var oldTransform = player.global_transform
	var oldTransform = player.global_transform
	player.get_parent().remove_child(player)
	if old_scene.get_ref():
		old_scene.get_ref().queue_free()
	else:
		print_debug("Warning! Bad reference to old_scene")
	old_scene = null
	get_tree().change_scene_to(new_scene)
	call_deferred("insert_player", oldTransform)

func insert_player(oldTransform: Transform):
	var sc = get_tree().current_scene
	if sc.has_node("player_spawn"):
		var new_target: Spatial = sc.get_node("player_spawn")
		var relTransform = target_transform.affine_inverse()*oldTransform
		var absTransform = new_target.global_transform*relTransform
		var odir = oldTransform.basis.z
		var ndir = absTransform.basis.z
		var vel_rot = odir.angle_to(ndir)
		var vel_axis = odir.cross(ndir).normalized() 
		#var relTransform = target_transform.inverse()*oldTransform
		#var absTransform = new_target.global_transform*relTransform
		#print(oldTransform.origin, "->", relTransform.origin, "->", absTransform.origin)
		for s in get_tree().get_nodes_in_group("player"):
			player.time_limit = s.time_limit
			player.rings = s.rings
			player.score = s.score
			s.queue_free()
		$"/root".add_child(player)
		#player.global_transform = absTransform
		player.global_transform = absTransform
		player.up = player.get_node("Armature").global_transform.basis.y
		player.velocity = player.velocity.rotated(vel_axis, vel_rot)
		#player.fix_camera()
