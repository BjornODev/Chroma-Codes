extends Node2D

var is_obscure := true
@onready var sprite = $ShaderSprite

var current_slot = null

func get_submission_value():
	return 0