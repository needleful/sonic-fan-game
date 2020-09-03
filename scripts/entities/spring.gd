extends Spatial

export(float) var power = 30

func _ready():
	var _x = $Area.connect("body_entered", self, "bounce")

func bounce(body):
	if body is Sonic:
		var n = global_transform.basis.y
		var v = body.velocity
		var t = v.normalized().angle_to(n)
		var a = v.cross(n).normalized()
		var v2 = v.rotated(a, t*2)
		body.velocity = v2 + n*power
