extends Spatial

func play_anim(anim:String):
	$AnimationPlayer.play(anim)

func show_page(page:Texture):
	var mat: SpatialMaterial = $Armature/Skeleton/Cube001.mesh["surface_1/material"]
	mat.albedo_texture = page
