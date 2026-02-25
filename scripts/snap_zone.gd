class_name SnapZone
extends Node2D

var row = 0
var column = 0
var sprite_ref
var peg_in_slot = null
var in_danger_row = false

func _ready() -> void:
	sprite_ref = $Sprite2D


func set_glow_red():
	$ShaderSprite.visible = true


func set_glow_off():
	$ShaderSprite.visible = false