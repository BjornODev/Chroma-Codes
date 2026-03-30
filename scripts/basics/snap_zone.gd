class_name SnapZone
extends Node2D

var row = 0
var column = 0
var sprite_ref
var peg_in_slot = null
var in_danger_row = false

var shader_material: ShaderMaterial

func _ready() -> void:
	sprite_ref = $Sprite2D
	sprite_ref.material = sprite_ref.material.duplicate()
	shader_material = sprite_ref.material as ShaderMaterial


func update_shader_value(new_value):
	if shader_material:
		shader_material.set_shader_parameter("outline_thickness", new_value)


func set_glow_red():
	$ShaderSprite.visible = true


func set_glow_off():
	$ShaderSprite.visible = false