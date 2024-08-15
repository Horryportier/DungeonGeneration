extends ColorRect

var old_color: Color 
var old_z_index: int

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	old_color = color
	old_z_index = z_index
	z_index = 100
	color = Color.PINK
	
func _on_mouse_exited():
	color =  old_color
	z_index =  old_z_index
	
