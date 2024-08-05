extends Camera2D

@export var speed = 200

@export_group("zoom")
@export var zoom_min = 0.1
@export var zoom_max = 4

var zoom_ratio =  1

func _process(delta):
	var direction = Input.get_vector("left", "right", "up", "down")
	var velocity = direction * speed * delta
	position += velocity
	if Input.is_action_pressed("zoom_in"):
		zoom_ratio -= 0.1
	if Input.is_action_pressed("zoom_out"):
		zoom_ratio += 0.1
	zoom = Vector2(clampf(zoom_ratio, zoom_min, zoom_max), clampf(zoom_ratio, zoom_min, zoom_max))
