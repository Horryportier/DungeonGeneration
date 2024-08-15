class_name RoomMask

@export var width: int
@export var height: int

## matrix is 2D array of int values coresponding to rooms and pathways
var matrix: Array[Array]

func  _init(w: int, h: int):
	width = w
	height = h
	fill()

func fill():
	for y in height:
		matrix.append([])
		for x in width:
			matrix[y].append(0)

# BUG: might be setting rooms in wrong place
# NOTE: rooms have negative cords which and godot array can acces tail indexes using them 
func add_room(room: RoomGenerator.Room):	
	for y in room.rect.size.y:
		for x in room.rect.size.x:
			matrix[y + room.rect.position.y][x + room.rect.position.x] = room.id

func add_hallway(a, b):
	print(a, b)
	for i in 100:
		var vec: Vector2i = lerp(a ,b, i * 100) as Vector2i
		if matrix[vec.y][vec.x] == 0:
			matrix[vec.y][vec.x] = -1
