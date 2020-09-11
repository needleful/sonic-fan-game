extends Control

func _input(event):
	if event.is_action_pressed("gm_pause"):
		get_tree().paused = !get_tree().paused
		pause(get_tree().paused)
	elif event.is_action_pressed("dev_reset"):
		var _x = get_tree().reload_current_scene()

func _ready():
	pause(get_tree().paused)

func pause(paused:bool):
	visible = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		show_main()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed():
	get_tree().paused = false
	pause(false)

func _on_Restart_pressed():
	var _x = get_tree().reload_current_scene()

func _on_Quit_pressed():
	get_tree().quit()

func show_main():
	$MainMenu.visible = true
	$FastOptionsMenu.visible = false

func _on_Options_pressed():
	$MainMenu.visible = false
	$FastOptionsMenu.visible = true

func _on_FastOptionsMenu_apply():
	show_main()

func _on_FastOptionsMenu_cancel():
	show_main()
