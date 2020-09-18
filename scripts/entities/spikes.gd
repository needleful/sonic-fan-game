extends StaticBody

export(float, 0, 10) var death_speed: float = 2

func tryKill(body):
	if body.has_method("die"):
		body.die()
