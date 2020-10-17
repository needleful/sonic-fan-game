extends Node

# Controller Types
enum ControllerType {
	PAD_XBOX,
	PAD_PLAYSTATION,
	PAD_NINTENDO,
	PAD_OTHER,
}

var using_controller:bool = false
var controller_name:String = "" setget set_controller_name
var controller_type:int = ControllerType.PAD_OTHER

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event:InputEvent) -> void:
	var c = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if using_controller != c:
		using_controller = c
		if c:
			var s = Input.get_joy_name(event.device)
			set_controller_name(s)

func set_controller_name(name:String):
	if name == controller_name:
		return
	print("New Input Device: ",name)
	if name.matchn("*XInput*") or name.matchn("*XBox*"):
		set_controller_type(ControllerType.PAD_XBOX)
	else:
		set_controller_type(ControllerType.PAD_OTHER)
	controller_name = name

func set_controller_type(val):
	controller_type = val
