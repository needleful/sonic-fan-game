extends Spatial

export(float) var power = 30
export(float, 0, 2) var reflection = 0.8

func _ready():
	var _x = $Area.connect("body_entered", self, "bounce")

func bounce(body):
	if body is Sonic:
		var n = global_transform.basis.y
		var v = -body.velocity
		var v2 = v.reflect(n) 
		body.velocity = v2*reflection + n*power
