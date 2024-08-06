class_name RoomGenerator
extends Node2D

##=========================================================================
## RoomGenrator
## TODO: 
##	- refactor it into drop in solution
##	- apply padding to rooms (no gap between some rooms) 
##
##=========================================================================


@export_group("room_generation")
@export var number_of_rooms: int = 100
@export var min_room_size: int = 4
@export var max_room_size: int = 16
@export var room_generation_radius: int = 50
@export_range(1, 2) var room_padding: float = 1
@export_range(0, 1) var selected_room_size_treshold: float = 0.3

@export_group("hallways_generation")
@export_range(0, 1) var non_mst_edges_treshold: float = 0.1
@export var hallway_width: int = 4


@export_group("map_generation")
@export_range(0, 1) var map_padding: float = 0.1

@export_group("debug")
@export var edge_color: Gradient 
@export var delaunay_rect_debug: bool
@export var mst_debug: bool
@export var pathways_debug: bool
@export var show_bodies: bool

@onready var tilemap: TileMap = $TileMap

enum LineOrientation { Vertical, Horizontal }

class Room:
	var id: int
	var rect: Rect2
	var body: RigidBody2D

	func _init(i):
		id = i

	func get_body() -> RigidBody2D:
		return body
	
	@warning_ignore("integer_division")
	func round_room_size(input: Vector2, min_room_size: int) -> Vector2:
		var x: int = (int(input.x) / min_room_size) * min_room_size
		var y: int = (int(input.y) / min_room_size) * min_room_size
		if abs(x) < min_room_size: 
			x = min_room_size * (x * 0)
			if x == 0:
				x = min_room_size
		if abs(y) < min_room_size: 
			y = min_room_size * (x * 0)
			if y == 0:
				y = min_room_size
		return Vector2(x,y)
	
	func update_room_position():
		self.rect.position = self.body.position

	func get_room_center() -> Vector2:
		return self.body.position + (self.rect.size * 0.5)

	func is_room_moving() -> bool:
		if not self.body.linear_velocity.is_zero_approx():
			return false
		return true


var rooms: Dictionary = {}
var selected_rooms: Array = []

var delaunay: Delaunay
var delaunay_rect: Rect2 
var triangles: Array
var room_graph: RoomGraph
var mst: Array[RoomGraph.RoomGraphEdge]
var hallways_lines: Array[Array]
var mask: RoomMask

var seperating = false
var can_triangulate = false

func get_line_orinetation(a: Vector2i, b: Vector2i) -> LineOrientation:
	if a.x != b.x:
		return LineOrientation.Horizontal
	return LineOrientation.Vertical

func line_to_vec2i_range(a: Vector2i ,b: Vector2i) -> Array[Vector2i]:
	var accum: Array[Vector2i] = [a]
	var vec = a
	while vec != b:
		if vec.x < b.x:
			vec.x += 1
		elif vec.x > b.x:
			vec.x -= 1
		if vec.y < b.y:
			vec.y += 1
		elif vec.y > b.y:
			vec.y -= 1
				
		accum.append(vec)

	accum.append(b)
	return accum

func get_random_point_in_circle(radius: float) -> Vector2:
	randomize()
	var t = 2* PI * randf()
	randomize()
	var u = randf() + randf()
	var r = null
	if u > 1:
		r = 2-u 
	else:
		r = u 
	return Vector2(radius * r * cos(t), radius * r * sin(t))



func make_room(id: int) -> Room:
		var room: = Room.new(id)
		var node: = RigidBody2D.new()
		var cr: = ColorRect.new()
		var label: = Label.new()
		label.text = str(id)

		cr.script = load("res://room_generation/color_rect.gd")
		cr.color = Color(randf(), randf(), randf(), 1)
		cr.size = room.round_room_size(get_random_point_in_circle(max_room_size), min_room_size).abs()
		cr.position = node.position - (cr.size / 2)
		cr.z_index = -1

		if not show_bodies:
			node.visible = false
		node.position = room.round_room_size(get_random_point_in_circle(room_generation_radius), min_room_size)
		node.mass = 100
		add_child(node)
		node.add_child(cr)
		cr.add_child(label)
		room.body = node
		room.rect = Rect2(cr.position, cr.size);
		return room
	

	

func generate_rooms():
	for i in number_of_rooms:
		var room =  make_room(i + 1)
		rooms[room.id] = room
		

func regenerate_rooms():
	selected_rooms = []
	hallways_lines = []
	for room in rooms.keys():
		rooms.get(room).body.queue_free()
	rooms.clear()
	generate_rooms()
	# seperate
	for room in rooms.values():
		add_colison_shape(room)
	seperating = true
	
	for y in 2000:
		for x in 2000:
			tilemap.set_cell(0, Vector2i(x - 1000, y - 1000), -1)

	get_tree().create_timer(1).timeout.connect(func():if seperating: var moving = are_rooms_moving(); seperating  = !moving; can_triangulate = moving)
	

func add_colison_shape(room: Room):
	if room.body.get_child_count() == 2:
		return
	room.body.lock_rotation = true
	var collison_shape: = CollisionShape2D.new()
	var rect: = RectangleShape2D.new()
	rect.size = room.body.get_child(0).size
	collison_shape.shape = rect
	collison_shape.scale =  collison_shape.scale * room_padding
	room.body.add_child(collison_shape)


func select_main_rooms(treshold: float) -> Array:
	var r: Array = rooms.values()
	r.sort_custom(func(a: Room, b: Room): return a.rect.size > b.rect.size)
	return r.slice(0, int(r.size() * treshold)) 


func calculate_rooms_mean() -> Vector2:
	var accum = Vector2.ZERO
	for room in rooms.values():
		accum += room.rect.size
	return accum / rooms.keys().size()


func triangulate_selected_rooms():
	var selected_room_centers  = []
	for room: Room in selected_rooms:
		selected_room_centers.append(room.get_room_center())

		delaunay_rect = Delaunay.calculate_rect(selected_room_centers)
		delaunay = Delaunay.new(delaunay_rect)
		for point in selected_room_centers:
			delaunay.add_point(point)
		triangles = delaunay.triangulate()

func are_rooms_moving() -> bool:
	for room in rooms.values() as Array[Room]:
		if not room.body.linear_velocity.is_zero_approx():
			return false
	for room in rooms.values():
		room.body.freeze = true
	return true

## Creating Grapth from Tirangulation
func crate_graph() -> RoomGraph:
	var graph = RoomGraph.new()
	add_nodes(graph)
	add_edges(graph)
	return graph

func add_nodes(graph: RoomGraph):
	for id in rooms.keys():
		graph.add_node(id, rooms[id])

func add_edges(graph: RoomGraph):
	var add_edge = func(arr: Array): if arr.size() == 0: return elif arr[0] and arr[1]: graph.add_edge(arr[0], arr[1], arr[2]);
	for triangle: Delaunay.Triangle in triangles:
		add_edge.call(triange_edge_to_room_edge(triangle.edge_ab))
		add_edge.call(triange_edge_to_room_edge(triangle.edge_bc))
		add_edge.call(triange_edge_to_room_edge(triangle.edge_ca))

func triange_edge_to_room_edge(edge: Delaunay.Edge) -> Array:
	var filtered_a = selected_rooms.filter(func(room: Room): if room.get_room_center() == edge.a: return true else: return false )
	var node_a: Room
	if filtered_a:
		node_a = filtered_a.front()
	var filtered_b = selected_rooms.filter(func(room: Room): if room.get_room_center() == edge.b: return true else: return false )
	var node_b: Room
	if filtered_b:
		node_b = filtered_b.front()
	var distance = 0
	if node_a and node_b:
		distance = node_a.get_room_center().distance_to(node_b.get_room_center())
	return [rooms.find_key(node_a), rooms.find_key(node_b), distance]


func add_not_used_eges(treshold: float):
	var non_mst_edges = room_graph.edges.filter(func(edge): if mst.has(edge): return false else: return true)
	mst.append_array( non_mst_edges.slice(0, int(non_mst_edges.size() * treshold)))

func get_lines_from_edges(edge: RoomGraph.RoomGraphEdge) -> Array[Vector2]:
	var node_a: Vector2 = edge.node_a.value.get_room_center()
	var node_b: Vector2 = edge.node_b.value.get_room_center()
	
	return [ node_a, Vector2(node_b.x, node_a.y), node_b, Vector2(node_b.x, node_a.y) ]


func paint_rect(rect: Rect2):
	var width = abs(rect.position.x) + rect.size.x
	var x_range  = [] 
	for w in width:
		x_range.append(rect.position.x +  w)
	var height = abs(rect.position.y) + rect.size.y
	var y_range  = [] 
	for h in abs(height):
		y_range.append(rect.position.y +  h)
	for y in y_range:
		for x in x_range:
			tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
	
	
func paint_map():
	for y in mask.height:
		for x in mask.width:
			if mask.matrix[y][x] != 0 or mask.matrix[y][x] != -1:
					tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 0))
			if mask.matrix[y][x] == 0:
					tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
			if mask.matrix[y][x] == -1:
					tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(2, 0))


func paint_room(room: Room):
	for y in room.rect.size.y:
		for x in room.rect.size.x:
			tilemap.set_cell(0, Vector2i(int(x) + int(room.rect.position.x),int(y) + int(room.rect.position.y)), 0, Vector2i(1,0))


func paint_hallway(a: Vector2, b: Vector2):
	var orientation = get_line_orinetation(a, b)
	for vec in line_to_vec2i_range(a, b):
		for i in hallway_width:
			match orientation:
				LineOrientation.Vertical:
					vec.x += i  
				LineOrientation.Horizontal:
					vec.y -= i 
			if tilemap.get_cell_atlas_coords(0, vec) != Vector2i(1,0):
				tilemap.set_cell(0, vec, 0, Vector2i(2,0))

func _ready():
	regenerate_rooms()


func _draw():
	draw_set_transform_matrix(global_transform.affine_inverse())
	if seperating: 
		return
	if delaunay_rect_debug:
		draw_rect(delaunay_rect, Color(0.2,0.3, 0.8, 0.3))
	#for edge: RoomGraph.RoomGraphEdge in room_graph.edges:
	#	var color = edge_color.sample(remap(edge.weight, 0, 200, 0, 1))
	#	draw_line(edge.node_a.value.get_room_center(), edge.node_b.value.get_room_center(), color,  -1, true)
	if mst_debug:
		for edge: RoomGraph.RoomGraphEdge in mst:
			var color = edge_color.sample(remap(edge.weight, 0, 200, 0, 1))
			draw_line(edge.node_a.value.get_room_center() * 16, edge.node_b.value.get_room_center() * 16, color,  -1, true)
		for edge: RoomGraph.RoomGraphEdge in mst:
			var color = edge_color.sample(remap(edge.weight, 0, 200, 0, 1))
			draw_line(edge.node_a.value.get_room_center(), edge.node_b.value.get_room_center() , color,  -1, true)
	if pathways_debug:
		for lines in hallways_lines:
			draw_line(lines[0] * 16, lines[1] * 16, Color.BLUE,  2, true)
			draw_circle(lines[0] * 16, 16, Color.BLUE  )
			#draw_circle(lines[1] * 16, 16, Color.BLUE  )
			draw_line(lines[2] * 16, lines[3] * 16, Color.PINK,  2, true)
			draw_circle(lines[2] * 16, 16, Color.BLUE  )
			#draw_circle(lines[3] * 16, 16, Color.BLUE  )

func _process(_delta):
	if Input.is_action_just_pressed("regenrate"):
		regenerate_rooms()
	if can_triangulate:
		for room: Room in rooms.values():
			room.update_room_position()
		selected_rooms = select_main_rooms(selected_room_size_treshold)

		for room in rooms.values():
			if not selected_rooms.has(room):
				remove_child(room.body)
		triangulate_selected_rooms()
		room_graph =  crate_graph()
		mst = room_graph.minimal_spanning_tree()
		add_not_used_eges(non_mst_edges_treshold)
		for edge in mst:
			hallways_lines.append(get_lines_from_edges(edge))

		
		var padded_rect: Rect2 = delaunay_rect
		padded_rect.position += (padded_rect.position * map_padding)
		paint_rect(padded_rect)
		for room in selected_rooms:
			paint_room(room)
		for hallway in hallways_lines:
			paint_hallway(hallway[0], hallway[1])
			paint_hallway(hallway[2], hallway[3])
		can_triangulate = false
	else:
		for room: Room in rooms.values():
			room.body.position = room.body.position.floor()
			
	
	queue_redraw()
