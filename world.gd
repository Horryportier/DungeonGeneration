extends Node2D

@onready var room_generator: RoomGenerator = $RoomGenerator

func _process(_delta):
	if Input.is_action_just_pressed("regenrate"):
		room_generator.generate_dungeon()
		
