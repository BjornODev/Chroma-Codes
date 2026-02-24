class_name Feedback_Peg
extends TextureRect


var color_id := 0
var peg_textures = [
	preload("res://assets/circle_black.svg"),
	preload("res://assets/circle_white.svg")
	]
	
func set_color(id):
	color_id = id
	texture = peg_textures[id]