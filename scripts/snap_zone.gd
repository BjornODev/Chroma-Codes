extends Node2D

var row = 0
var column = 0
var sprite_ref
var peg_in_slot = null

func _ready() -> void:
	sprite_ref = $Sprite2D
	print(sprite_ref.texture.get_size())