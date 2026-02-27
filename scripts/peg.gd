#extends TextureRect
#
#var color_id := 0
#var peg_textures = [
#	preload("res://assets/pegs/circle_1.svg"),
#	preload("res://assets/pegs/circle_2.svg"),
#	preload("res://assets/pegs/circle_3.svg"),
#	preload("res://assets/pegs/circle_4.svg"),
#	preload("res://assets/pegs/circle_5.svg"),
#	preload("res://assets/pegs/circle_6.svg")
#	]
#
#func set_color(id):
#	color_id = id
#	texture = peg_textures[id]
#
#func _get_drag_data(_pos):
#	var preview = duplicate()
#	
#	var c = Control.new()
#	c.add_child(preview)
#	preview.position = -0.1 * preview.size
#	
#	set_drag_preview(c)
#	
#	return color_id