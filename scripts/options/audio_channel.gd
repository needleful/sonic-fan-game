extends Object
class_name AudioChannel

var bus_name: String
var vol: float
var muted: bool

func _init(name: String):
	bus_name = name
	var bi = AudioServer.get_bus_index(bus_name)
	if bi >= 0:
		muted = AudioServer.is_bus_mute(bi)
		vol = db_to_percent(AudioServer.get_bus_volume_db(bi))

func apply(c):
	vol = c.vol
	muted = c.muted
	var bi = AudioServer.get_bus_index(bus_name)
	if bi >= 0:
		AudioServer.set_bus_mute(bi, muted)
		AudioServer.set_bus_volume_db(bi, percent_to_db(vol))

func percent_to_db(percent):
	if percent >= 1:
		return lerp(0, 6, percent - 1)
	else:
		return lerp(-60, 0, percent)

func db_to_percent(db):
	if db > 0:
		return db/6.0 + 1
	else:
		return (db + 60)/60
