class_name Feedback_Peg
extends TextureRect



var color_id := 0
var peg_textures = [
	preload("res://assets/circle_black.svg"),
	preload("res://assets/circle_white.svg")
	]

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_color(id):
	color_id = id
	texture = peg_textures[id]


func get_tooltip_content() -> Dictionary:
	if color_id == 0:
		return {"type": "feedback_black", "data": {}}
	else:
		return {"type": "feedback_white", "data": {}}


func _on_mouse_entered():
	HoverTooltip.show_for(self)


func _on_mouse_exited():
	HoverTooltip.hide_tooltip()
