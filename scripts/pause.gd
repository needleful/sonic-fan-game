extends Node

func _input(event):
	if event.is_action_pressed("gm_pause"):
		get_tree().paused = !get_tree().paused
		if get_tree().paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("dev_reset"):
		var _x = get_tree().reload_current_scene()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
