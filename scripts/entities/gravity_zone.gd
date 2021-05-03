extends Area

export(float) var base_radius = 100
export(Vector3) var default_gravity = Vector3.ZERO

func _physics_process(delta):
	for c in get_overlapping_bodies():
		if c.has_method("set_gravity"):
			if gravity_point:
				var pos = c.global_transform.origin - global_transform.origin
				c.gravity = -gravity*pos.normalized()/(
					pos.length_squared()/(base_radius*base_radius) )
			else:
				c.gravity = gravity*gravity_vec

func _on_gravity_body_exited(body):
	if body.has_method("set_gravity"):
		if default_gravity == Vector3.ZERO:
			body.gravity *= 0.1
		else:
			body.gravity = default_gravity
