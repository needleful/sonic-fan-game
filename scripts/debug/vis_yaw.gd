extends MeshInstance

export(Color) var color: Color setget set_color

func set_color(c):
	color = c
	var m = get_surface_material(0)
	m.albedo_color = c
