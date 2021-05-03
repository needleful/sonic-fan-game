extends Control

export(String) var zone_name
export(String) var act
export(Vector2) var camera_rotation
export(Texture) var journal_page

func _ready():
	if !$"/root/Respawn".new_level:
		visible = false
		for sonic in get_tree().get_nodes_in_group("player"):
			sonic.playAnimation("Stand")
			sonic.get_journal_page(journal_page)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$"/root/Pause".set_process_input(false)
	$"/root/SonicUi".visible = false
	for sonic in get_tree().get_nodes_in_group("player"):
		sonic.camRot = camera_rotation
		sonic.fix_camera()
		sonic.set_process_input(false)
		sonic.playAnimation("Sit")

func start(other_scene:String = ""):
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$"/root/Pause".set_process_input(true)
	for sonic in get_tree().get_nodes_in_group("player"):
		sonic.set_process_input(true)
		sonic.playAnimation("Stand")
		sonic.get_journal_page(journal_page)
	$"/root/SceneCards".open_level(zone_name, act)

func _on_Quit_pressed():
	get_tree().quit()

func _on_Options_pressed():
	$MainMenu.visible = false
	$FastOptionsMenu.visible = true

func _on_LevelSelect_pressed():
	pass # Replace with function body.

func _on_NewGame_pressed():
	start()

func _on_FastOptionsMenu_apply():
	$MainMenu.visible = true
	$FastOptionsMenu.visible = false

func _on_FastOptionsMenu_cancel():
	$MainMenu.visible = true
	$FastOptionsMenu.visible = false
