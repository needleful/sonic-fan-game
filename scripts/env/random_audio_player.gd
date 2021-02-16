extends AudioStreamPlayer3D

export(float, .1, 30, 0.1) var minimum_time = 1
export(float, 1, 90, 0.1) var maximum_time = 2



func _on_Timer_timeout():
	play()
	$Timer.wait_time = rand_range(minimum_time, maximum_time)
	$Timer.start()
