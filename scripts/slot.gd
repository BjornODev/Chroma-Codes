class_name Slot
extends TextureRect

@export var empty_texture = Texture

var row := 0
var column := 0

var color_id := -1



var peg_textures = [
	preload("res://assets/pegs/circle_1.svg"),
	preload("res://assets/pegs/circle_2.svg"),
	preload("res://assets/pegs/circle_3.svg"),
	preload("res://assets/pegs/circle_4.svg"),
	preload("res://assets/pegs/circle_5.svg"),
	preload("res://assets/pegs/circle_6.svg")
]

func _ready():
	clear_slot()

func _can_drop_data(_pos, _data):
	return row == get_parent().active_row

func _drop_data(_pos, data):
	color_id = data
	texture = peg_textures[data]
#	set_color(peg.color_id)
#	peg.queue_free()
#	peg.get_parent().draw_hand()

func clear_slot():
	color_id = -1
	texture = empty_texture

func set_color(id):
	color_id = id
	texture = peg_textures[id]

#func _gui_input(event):
#	if event is InputEventMouseButton and event.pressed:
#		cycle_color()

#func cycle_color():
#	color_id += 1
#	if color_id >= peg_colors.size():
#		color_id = -1
#
#	if color_id == -1:
#		texture = empty_texture
#	else:
#		texture = peg_textures[data]
