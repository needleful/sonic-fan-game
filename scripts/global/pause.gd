extends Control

func _input(event):
	if event.is_action_pressed("gm_pause"):
		pause(!get_tree().paused)
	elif event.is_action_pressed("dev_reset"):
		$"/root/Respawn".reset_no_respawn()

func _ready():
	pause(get_tree().paused)

func pause(paused:bool):
	get_tree().paused = paused
	visible = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		show_main()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed():
	pause(false)

func _on_RestartCheckoint_pressed():
	pause(false)
	$"/root/Respawn".reset_level()
	
func _on_Restart_pressed():
	pause(false)
	$"/root/Respawn".reset_no_respawn()

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

