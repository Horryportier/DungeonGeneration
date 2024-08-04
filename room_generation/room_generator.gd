class_name RoomGenerator
extends Node2D

@export_group("room_generation")
@export var number_of_rooms: int = 100
@export var min_room_size: int = 4
@export var max_room_size: int = 16
@export var room_generation_radius: int = 50
@export_range(0, 1) var selected_room_size_treshold: float = 20


@export_group("debug")
@export var edge_color: Gradient 

func get_random_point_in_circle(radius: float) -> Vector2:
	var t = 2* PI * randf()
	var u = randf() + randf()
	var r = null
	if u > 1:
		r = 2-u 
	else:
		r = u 
	return Vector2(radius * r * cos(t), radius * r * sin(t))


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
		return self.body.position

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


var seperating = false
var can_triangulate = false

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
	for room in rooms.keys():
		rooms.get(room).body.queue_free()
	rooms.clear()
	generate_rooms()
	# seperate
	for room in rooms.values():
		add_colison_shape(room)
	seperating = true
	get_tree().create_timer(1).timeout.connect(func():if seperating: var moving = are_rooms_moving(); seperating  = !moving; can_triangulate = moving)
	

func add_colison_shape(room: Room):
	if room.body.get_child_count() == 2:
		return
	room.body.lock_rotation = true
	var collison_shape: = CollisionShape2D.new()
	var rect: = RectangleShape2D.new()
	rect.size = room.body.get_child(0).size
	collison_shape.shape = rect
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
	var node_a: Room = selected_rooms.filter(func(room: Room): if room.get_room_center() == edge.a: return true else: return false ).front()
	var node_b: Room = selected_rooms.filter(func(room: Room): if room.get_room_center() == edge.b: return true else: return false ).front()
	var distance = 0
	if node_a and node_b:
		distance = node_a.get_room_center().distance_to(node_b.get_room_center())
	return [rooms.find_key(node_a), rooms.find_key(node_b), distance]

func _ready():
	regenerate_rooms()


func _draw():
	draw_set_transform_matrix(global_transform.affine_inverse())
	if seperating: 
		return
	if delaunay_rect:
		draw_rect(delaunay_rect, Color(0.2,0.3, 0.8, 0.3))
	for edge: RoomGraph.RoomGraphEdge in room_graph.edges:
		var color = edge_color.sample(remap(edge.weight, 0, 200, 0, 1))
		draw_line(edge.node_a.value.get_room_center(), edge.node_b.value.get_room_center(), color,  -1, true)

func _process(_delta):
	if Input.is_action_just_pressed("regenrate"):
		regenerate_rooms()
	if can_triangulate:
		for room: Room in rooms.values():
			room.update_room_position()
		selected_rooms = select_main_rooms(selected_room_size_treshold)
		for room in selected_rooms:
			room.body.get_child(0).color = Color.RED
		for room in rooms.values():
			if not selected_rooms.has(room):
				remove_child(room.body)
		triangulate_selected_rooms()
		room_graph =  crate_graph()
		room_graph.print_edges()
		can_triangulate = false
	
	queue_redraw()
