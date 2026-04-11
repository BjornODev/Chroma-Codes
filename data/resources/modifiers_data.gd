class_name ModifierData
extends Resource

@export var modifier_name : String
@export var icon : Texture2D
@export var phase : String
@export var trigger : Dictionary
@export var base_effect : Dictionary
var level := 1

func get_scaled_effect():
	var scaled := {}
	for key in base_effect.keys():
		scaled[key] = base_effect[key] + (level - 1)
	return scaled