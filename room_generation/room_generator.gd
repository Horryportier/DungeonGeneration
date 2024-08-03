extends Node2D

@export_group("room_generation")
@export var number_of_rooms: int = 100
@export var min_room_size: int = 4
@export var max_room_size: int = 16
@export var room_generation_radius: int = 50
@export var selected_room_size_treshold: float = 20

var rooms: Dictionary = {}
var selected_rooms: Array = []
var selected_room_centers: PackedVector2Array = []

var delaunay: Delaunay
var delaunay_rect: Rect2 
var triangles: Array

func get_random_point_in_circle(radius: float) -> Vector2:
	var t = 2* PI * randf()
	var u = randf() + randf()
	var r = null
	if u > 1:
		r = 2-u 
	else:
		r = u 
	return Vector2(radius * r * cos(t), radius * r * sin(t))

@warning_ignore("integer_division")
func round_room_size(input: Vector2) -> Vector2:
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
		

func generate_rooms():
	for i in number_of_rooms:
		var node = RigidBody2D.new()
		var cr = ColorRect.new()
		cr.color = Color(randf(), randf(), randf(), 1)
		cr.size = round_room_size(get_random_point_in_circle(max_room_size)).abs()
		cr.position = node.position - (cr.size / 2)
		cr.z_index = -1
		node.position = round_room_size(get_random_point_in_circle(room_generation_radius))
		rooms[node] = {"size": cr.size, "position": node.position}
		add_child(node)
		node.add_child(cr)

func regenerate_rooms():
	selected_rooms = []
	selected_room_centers = []
	for child in rooms.keys():
		child.queue_free()
	rooms.clear()
	generate_rooms()

func add_colison_shape(room: Node2D):
	if room.get_child_count() == 2:
		return
	room.lock_rotation = true
	var collison_shape: = CollisionShape2D.new()
	var rect: = RectangleShape2D.new()
	rect.size = room.get_child(0).size
	collison_shape.shape = rect
	room.add_child(collison_shape)


func select_main_rooms(treshold: float) -> Array[RigidBody2D]:
	var r: Array[RigidBody2D] = []
	for room in rooms.keys():
		var size: Vector2 = rooms.get(room).get("size")
		if size.x * size.y >= treshold:
			room.get_child(0).color = Color.RED
			r.append(room)
		else:
			room.get_child(0).color.a =  0.7
	return r


func get_room_center(room: Node2D) -> Vector2:
	return room.position  #- (rooms.get(room).get("size") / 2)

func _ready():
	generate_rooms()

func _draw():
	draw_set_transform_matrix(global_transform.affine_inverse())
	for center in selected_room_centers:
		draw_circle(center, 2, Color.YELLOW)
	if delaunay_rect:
		draw_rect(delaunay_rect, Color(0.2,0.3, 0.8, 0.5))
	for trinagle in triangles as Array[Delaunay.Triangle]:
		if delaunay.is_border_triangle(trinagle):
			continue
		draw_line(trinagle.edge_ab.a, trinagle.edge_ab.b, Color.GREEN) 
		draw_line(trinagle.edge_bc.a, trinagle.edge_bc.b, Color.GREEN) 
		draw_line(trinagle.edge_ca.a, trinagle.edge_ca.b, Color.GREEN) 

func _process(_delta):
	if Input.is_action_just_pressed("regenrate"):
		regenerate_rooms()
	if Input.is_action_just_pressed("seprate"):
		for room in rooms.keys():
			add_colison_shape(room)
	if Input.is_action_just_pressed("select"):
		selected_rooms = select_main_rooms(selected_room_size_treshold)
		for room in selected_rooms:
			selected_room_centers.append(get_room_center(room))

		delaunay_rect = Delaunay.calculate_rect(selected_room_centers)
		delaunay = Delaunay.new(delaunay_rect)
		for point in selected_room_centers:
			delaunay.add_point(point)
		triangles = delaunay.triangulate()
	queue_redraw()
