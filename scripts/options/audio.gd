extends Object
class_name AudioOptions

var master_audio: AudioChannel = AudioChannel.new("Master") setget set_master
var sound_effects: AudioChannel = AudioChannel.new("SFX_Sonic") setget set_sfx
var music: AudioChannel = AudioChannel.new("Music") setget set_music

var volume_widget = preload("res://addons/fast_options/widgets/volume_widget.tscn")

func get_name():
	return "Audio"

func get_custom_widgets() -> Dictionary:
	return {
		"master_audio":volume_widget,
		"sound_effects":volume_widget,
		"music":volume_widget
	}

func set_master(c):
	master_audio.apply(c)

func set_sfx(c):
	sound_effects.apply(c)

func set_music(c):
	music.apply(c)
