tool
extends Path
class_name AutoRoad

# Stay vertical or follow up vectors of the curve
export(bool) var stay_vertical : bool = true setget set_vertical
export(float) var angle_tolerance: float = 4 setget set_tolerance
export(ArrayMesh) var template_mesh : ArrayMesh setget set_template
export(Material) var material : Material setget set_material
export(float) var uv_scale: float = 5
export(Transform) var template_transform : Transform setget set_template_transform
export(int, LAYERS_3D_PHYSICS) var collision_layer : int = 5

var mesh: MeshInstance = MeshInstance.new()
var body: StaticBody = StaticBody.new()
var collider: CollisionShape = CollisionShape.new()

func _ready():
	var _x = connect("curve_changed", self, "regenerate")
	regenerate()

func set_tolerance(tol):
	angle_tolerance = tol
	if Engine.editor_hint:
		regenerate()

func set_template(t):
	template_mesh = t
	if Engine.editor_hint:
		regenerate()

func set_template_transform(tr):
	template_transform = tr
	if Engine.editor_hint:
		regenerate()

func set_vertical(v):
	stay_vertical = v
	if Engine.editor_hint:
		regenerate()

func set_material(m):
	material = m
	mesh.material_override = material

func regenerate():
	print("Regenerating autoroad...")
	if template_mesh == null:
		return
		
	if !has_node("__auto_mesh_gen"):
		mesh.name = "__auto_mesh_gen"
		add_child(mesh)
		
	if !has_node("__auto_body_gen"):
		body.name = "__auto_body_gen"
		body.collision_layer = collision_layer
		add_child(body)
	
	if body and !body.has_node("__auto_collider_gen"):
		collider.name = "__auto_collider_gen"
		body.add_child(collider)
	
	if template_mesh.get_surface_count() != 1:
		print_debug("Warning! Road generation only works with single-surface meshes")
	
	# Get outer edge of mesh
	var data : MeshDataTool = MeshDataTool.new()
	data.set_material(template_mesh.surface_get_material(0))
	var err = data.create_from_surface(template_mesh, 0)
	if err != OK:
		print_debug("ERROR! Failed to create a mesh from a surface: "+ str(err))
	
	var outer_vertices : PoolVector3Array = PoolVector3Array()
	var outer_uv_x : PoolRealArray = PoolRealArray()
	# 2 ints per edge
	var outer_edges : PoolIntArray = PoolIntArray()
	# indeces of the vertices in the source mesh
	var added_indeces: Array = []
	
	for edge_index in range(data.get_edge_count()):
		var faces = data.get_edge_faces(edge_index)
		if faces.size() == 1:
			var face = faces[0]
			
			var v0 = data.get_face_vertex(face, 0)
			var v1 = data.get_face_vertex(face, 1)
			var v2 = data.get_face_vertex(face, 2)
			
			var e0: int = data.get_edge_vertex(edge_index, 0)
			var e1: int = data.get_edge_vertex(edge_index, 1)
			var e2: int
			
			if e0 == v0:
				if e1 == v1:
					e2 = v2
				else:
					e2 = v1
			elif e0 == v1:
				if e1 == v0:
					e2 = v2
				else:
					e2 = v0
			elif e0 == v2:
				if e1 == v0:
					e2 = v1
				else:
					e2 = v0
			
			var v_0 = data.get_vertex(e0)
			var v_1 = data.get_vertex(e1)
			var v_2 = data.get_vertex(e2)
			var n = (v_1 - v_0).cross(v_2 - v_0)
			if n.z > 0:
				outer_edges.append(e0)
				outer_edges.append(e1)
			else:
				outer_edges.append(e1)
				outer_edges.append(e0)
	
	# Get the vertices, convert outer_edges from the source mesh to the target mesh
	for e in range(outer_edges.size()):
		var source_index = outer_edges[e]
		var v = added_indeces.find(source_index)
		if v < 0:
			v = outer_vertices.size()
			added_indeces.append(source_index)
			outer_vertices.append(template_transform.xform(data.get_vertex(source_index)))
			outer_uv_x.append(data.get_vertex_uv(source_index).x)
		outer_edges[e] = v
	
	var uvs : PoolVector2Array = PoolVector2Array()
	var verts : PoolVector3Array = PoolVector3Array()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var points = curve.tessellate(5, angle_tolerance)
	var distance_covered: float = 0
	for point_index in range(points.size()):
		var start = points[point_index]
		var end: Vector3
		if point_index < points.size() - 1:
			end = points[point_index + 1]
		else:
			var diff = start - points[point_index - 1]
			end = start + diff
		
		var point_change = (start - end).length()
		
		var interp = curve.get_closest_offset(start)
		var up = Vector3.UP if stay_vertical else curve.interpolate_baked_up_vector(interp)
		var f = (end-start).normalized()
		var l = up.cross(f).normalized()
		var point_b:Transform = Transform(Basis(l, up, f), start)
		
		for i in range(outer_vertices.size()):
			var vert = outer_vertices[i]
			var uvx = outer_uv_x[i]
			var p = point_b.xform(vert)
			verts.push_back(p)
			var uv = Vector2(uvx, distance_covered/uv_scale)
			uvs.push_back(uv)
		
		if point_index > 0:
			var v = outer_vertices.size()
			var start_index = point_index*v
			for e in range(0, outer_edges.size() - 1, 2):
				var startLeft = outer_edges[e]  + start_index- v
				var startRight = outer_edges[e+1]  + start_index- v
				
				var endLeft = outer_edges[e] + start_index
				var endRight = outer_edges[e+1] + start_index
				
				surface.add_index(endLeft)
				surface.add_index(startRight)
				surface.add_index(startLeft)
				
				surface.add_index(startRight)
				surface.add_index(endLeft)
				surface.add_index(endRight)
		distance_covered += point_change
	# End caps
	if points.size() >= 2:
		var start = points[0]
		var next: Vector3 = points[1]
		var up = Vector3.UP if stay_vertical else curve.interpolate_baked_up_vector(0)
		var f = (next-start).normalized()
		var l = up.cross(f).normalized()
		var voffset = verts.size()
		var point_b:Transform = Transform(Basis(l, up, f), start)
		for v_index in range(data.get_vertex_count()):
			var v = template_transform.xform(data.get_vertex(v_index))
			verts.push_back(point_b.xform(v))
			uvs.push_back(data.get_vertex_uv(v_index))
			
		for f_index in range(data.get_face_count()):
			var v0 = data.get_face_vertex(f_index, 0)
			var v1 = data.get_face_vertex(f_index, 1)
			var v2 = data.get_face_vertex(f_index, 2)
			var vp0 = data.get_vertex(v0)
			var vp1 = data.get_vertex(v1)
			var vp2 = data.get_vertex(v2)
			
			var n = (vp1 - vp0).cross(vp2 - vp0)
			if n.z < 0:
				var t = v1
				v1 = v2
				v2 = t
			surface.add_index(v0 + voffset)
			surface.add_index(v1 + voffset)
			surface.add_index(v2 + voffset)
		
		var end2 = points[points.size() - 1]
		var beforeEnd = points[points.size() - 2]
		var offset = curve.get_closest_offset(end2)
		up = Vector3.UP if stay_vertical else curve.interpolate_baked_up_vector(offset)
		f = (end2-beforeEnd).normalized()
		l = up.cross(f).normalized()
		voffset = verts.size()
		point_b = Transform(Basis(l, up, f), end2)
		for v_index in range(data.get_vertex_count()):
			var v = template_transform.xform(data.get_vertex(v_index))
			verts.push_back(point_b.xform(v))
			uvs.push_back(data.get_vertex_uv(v_index))
			
		for f_index in range(data.get_face_count()):
			var v0 = data.get_face_vertex(f_index, 0)
			var v1 = data.get_face_vertex(f_index, 1)
			var v2 = data.get_face_vertex(f_index, 2)
			var vp0 = data.get_vertex(v0)
			var vp1 = data.get_vertex(v1)
			var vp2 = data.get_vertex(v2)
			
			var n = (vp1 - vp0).cross(vp2 - vp0)
			if n.z > 0:
				var t = v1
				v1 = v2
				v2 = t
			surface.add_index(v0 + voffset)
			surface.add_index(v1 + voffset)
			surface.add_index(v2 + voffset)
		
	for i in range(verts.size()):
		var uv = uvs[i]
		var v = verts[i]
		surface.add_uv(uv)
		surface.add_vertex(v)

	surface.generate_normals()
	mesh.mesh = surface.commit()
	collider.shape = mesh.mesh.create_trimesh_shape()

func has_edge(edges: PoolIntArray, to_find_0: int, to_find_1: int) -> bool:
	for i in range(0, edges.size() - 1, 2):
		if edges[i] == to_find_0 and edges[i+1] == to_find_1:
			return true
	return false
