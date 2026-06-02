extends Node2D

var is_obscure := true

@onready var sprite = $ShaderSprite
@onready var collision = $Area2D

var current_slot = null


func _on_mouse_entered():
	HoverTooltip.show_for(self)


func _on_mouse_exited():
	HoverTooltip.hide_tooltip()


func get_tooltip_content() -> Dictionary:
	return {"type": "obscure", "data": {}}

func get_submission_value():
	return 0