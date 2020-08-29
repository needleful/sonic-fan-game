
class_name MoveMath

static func min_angle(v1: Vector3, v2: Vector3) ->float:
	var theta = v1.angle_to(v2)
	if abs(theta) <= PI:
		return theta
	else:
		return -sign(theta)*(2*PI -abs(theta))

static func pr(vec:Vector3)->String:
	return "{%05.3f, %05.3f, %05.3f}" % [vec.x, vec.y, vec.z]

static func reject(v1:Vector3, v2: Vector3) -> Vector3:
	return v1 - v1.project(v2)
