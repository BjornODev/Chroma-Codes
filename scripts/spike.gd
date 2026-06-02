extends Node2D

var is_spike := true
var current_slot = null

@onready var sprite = $Sprite2D


func _on_mouse_entered():
	HoverTooltip.show_for(self)


func _on_mouse_exited():
	HoverTooltip.hide_tooltip()


func get_tooltip_content() -> Dictionary:
	return {"type": "spike", "data": {}}

func get_submission_value():
	return 0