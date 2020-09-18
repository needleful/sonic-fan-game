tool
extends Path
class_name AutoRoad

# Stay vertical or follow up vectors of the curve
export(bool) var stay_vertical : bool = true setget set_vertical
export(float) var angle_tolerance: float = 4 setget set_tolerance
export(ArrayMesh) var template_mesh : ArrayMesh setget set_template
export(Transform) var template_transform : Transform setget set_template_transform

var mesh: MeshInstance = MeshInstance.new()
var body: StaticBody = StaticBody.new()
var collider: CollisionShape = CollisionShape.new()

func _ready():
	if Engine.editor_hint:
		connect("curve_changed", self, "regenerate")
		regenerate()

func set_tolerance(tol):
	angle_tolerance = tol
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
		outer_edges[e] = v

	var verts : PoolVector3Array = PoolVector3Array()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var points = curve.tessellate(5, angle_tolerance)
	
	for point_index in range(points.size()):
		var start = points[point_index]
		var end: Vector3
		if point_index < points.size() - 1:
			end = points[point_index + 1]
		else:
			var diff = start - points[point_index - 1]
			end = start + diff
		
		var interp = curve.get_closest_offset(start)
		var up = Vector3.UP if stay_vertical else curve.interpolate_baked_up_vector(interp)
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
				
				surface.add_index(endLeft)
				surface.add_index(startRight)
				surface.add_index(startLeft)
				
				surface.add_index(startRight)
				surface.add_index(endLeft)
				surface.add_index(endRight)
	
	for v in verts:
		surface.add_vertex(v)

	surface.generate_normals()
	mesh.mesh = surface.commit()
	# TODO: do really large collision shapes break?
	collider.shape = mesh.mesh.create_trimesh_shape()

func has_edge(edges: PoolIntArray, to_find_0: int, to_find_1: int) -> bool:
	for i in range(0, edges.size() - 1, 2):
		if edges[i] == to_find_0 and edges[i+1] == to_find_1:
			return true
	return false
