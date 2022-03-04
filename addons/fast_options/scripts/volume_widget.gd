extends Control

signal changed(opt_name, value)

var opt_name: String
var value: AudioChannel

func set_option_hint(hints:Dictionary):
	opt_name = hints.name
	$name.text = opt_name.capitalize()

func set_option_value(val: AudioChannel):
	value = val
	$HSlider.value = val.vol
	$mute.pressed = val.muted

func grab_focus():
	$HSlider.grab_focus()

func mute(val: bool):
	if value:
		value.muted = val
		emit_signal("changed", opt_name, value)

func vol_change(val:float):
	if value:
		value.vol = val
		$volLabel.text = "%.2f" % val
		emit_signal("changed", opt_name, value)