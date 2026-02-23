extends Node2D

var is_spike := true
var current_slot = null
@onready var sprite = $Sprite2D

func get_submission_value():
	return 0