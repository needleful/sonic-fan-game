extends Object
class_name AudioOptions

export(Resource) var master_audio = AudioChannel.new("Master") setget set_master
export(Resource) var sound_effects = AudioChannel.new("SFX") setget set_sfx
export(Resource) var music = AudioChannel.new("Music") setget set_music

var volume_widget = preload("res://addons/fast_options/widgets/volume_widget.tscn")

func get_name():
	return "Audio"

func get_custom_widgets() -> Dictionary:
	return {
		"master_audio":volume_widget,
		"sound_effects":volume_widget,
		"music":volume_widget
	}

func set_master(c: AudioChannel):
	master_audio.apply(c)

func set_sfx(c: AudioChannel):
	sound_effects.apply(c)

func set_music(c: AudioChannel):
	music.apply(c)
