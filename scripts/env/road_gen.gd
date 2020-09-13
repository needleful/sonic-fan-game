tool
extends Path

# Stay vertical or follow up vectors of the curve
export(bool) var stay_vertical : bool = true setget set_vertical
export(float) var minimum_angle_per_segment: float = 4
export(ArrayMesh) var template_mesh : ArrayMesh setget set_template
export(Transform) var template_transform : Transform setget set_template_transform

var mesh: MeshInstance = MeshInstance.new()
var body: StaticBody = StaticBody.new()
var collider: CollisionShape = CollisionShape.new()

func _ready():
	if Engine.editor_hint:
		connect("curve_changed", self, "regenerate")
		regenerate()

func set_template(t):
	template_mesh = t
	regenerate()

func set_template_transform(tr):
	template_transform = tr
	regenerate()

func set_vertical(v):
	stay_vertical = v
	regenerate()

func regenerate():
	if template_mesh == null:
		return
		
	if !has_node("__auto_mesh_gen"):
		mesh.name = "__auto_mesh_gen"
		add_child(mesh)
		
	if !has_node("__auto_body_gen"):
		body.name = "__auto_body_gen"
		add_child(body)
	
	if body and !body.has_node("__auto_collider_gen"):
		collider.name = "__auto_collider_gen"
		body.add_child(collider)
	
	if template_mesh.get_surface_count() != 1:
		print_debug("Warning! Road generation only works with single-surface meshes")
	
	# Get outer edge of mesh
	var data : MeshDataTool = MeshDataTool.new()
	var err = data.create_from_surface(template_mesh, 0)
	if err != OK:
		print_debug("ERROR! Failed to create a mesh from a surface: "+ str(err))
	
	var outer_vertices : PoolVector3Array = PoolVector3Array()
	# 2 ints per edge
	var outer_edges : PoolIntArray = PoolIntArray()
	# indeces of the vertices in the source mesh
	var added_indeces: Array = []
	
	for edge_index in range(data.get_edge_count()):
		if data.get_edge_faces(edge_index).size() == 1:
			var e0 = data.get_edge_vertex(edge_index, 0)
			var e1 = data.get_edge_vertex(edge_index, 1)
			outer_edges.append(e0)
			outer_edges.append(e1)
	
	# Get the vertices, convert outer_edges from the source mesh to the target mesh
	for e in range(outer_edges.size()):
		var source_index = outer_edges[e]
		var v = added_indeces.find(source_index)
		if v < 0:
			v = outer_vertices.size()
			added_indeces.append(source_index)
			outer_vertices.append(template_transform.xform(data.get_vertex(source_index)))
		outer_edges[e] = v

	var verts : PoolVector3Array = PoolVector3Array()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for point_index in range(curve.get_point_count()):
		var start = curve.get_point_position(point_index)
		var end: Vector3
		if point_index < curve.get_point_count() - 1:
			end = curve.get_point_position(point_index + 1)
		else:
			var diff = start - curve.get_point_position(point_index - 1)
			end = start + diff
		
		var up = Vector3.UP
		var f = (end-start).normalized()
		var l = up.cross(f).normalized()
		var point_b:Transform = Transform(Basis(l, up, f), start)
		
		for vert in outer_vertices:
			var p = point_b.xform(vert)
			verts.push_back(p)
		
		if point_index > 0:
			var v = outer_vertices.size()
			var start_index = point_index*v
			for e in range(0, outer_edges.size() - 1, 2):
				var startLeft = outer_edges[e]  + start_index- v
				var startRight = outer_edges[e+1]  + start_index- v
				
				var endLeft = outer_edges[e] + start_index
				var endRight = outer_edges[e+1] + start_index
				
				var lr = verts[startRight] - verts[startLeft]
				var se = verts[endLeft] - verts[startLeft]
				
				if lr.cross(se).dot(up) > 0:
					surface.add_index(endLeft)
					surface.add_index(startRight)
					surface.add_index(startLeft)
					
					surface.add_index(startRight)
					surface.add_index(endLeft)
					surface.add_index(endRight)
				else:
					surface.add_index(startRight)
					surface.add_index(endLeft)
					surface.add_index(startLeft)
					
					surface.add_index(endLeft)
					surface.add_index(startRight)
					surface.add_index(endRight)
	
	for v in verts:
		surface.add_vertex(v)
	#debug
	surface.generate_normals()
	mesh.mesh = surface.commit()

func has_edge(edges: PoolIntArray, to_find_0: int, to_find_1: int) -> bool:
	for i in range(0, edges.size() - 1, 2):
		if edges[i] == to_find_0 and edges[i+1] == to_find_1:
			return true
	return false
