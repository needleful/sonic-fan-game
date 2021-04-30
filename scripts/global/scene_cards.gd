extends Control

func open_level(zone:String, act:String):
	$opener/Zone.text = zone
	$opener/Act.text = "Act " + act
	$AnimationPlayer.play("Start_Level")

func hideUI():
	$"/root/SonicUi".visible = false

func showUI():
	$"/root/SonicUi".visible = true
