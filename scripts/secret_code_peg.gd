extends Node2D

@onready var peg_sprite = $PegSprite

var peg_database_reference
var revealed := false

func _ready():

	var cover = $Cover
	cover.material = cover.material.duplicate()

	var mat = cover.material as ShaderMaterial
	mat.set_shader_parameter("progress", -1.0)
	
	peg_database_reference = preload("res://scripts/peg_data.gd")


func set_color_from_id(texture):
	peg_sprite.modulate = Color(peg_database_reference.PEG_TYPES[texture][0])


func reveal(duration := 2.5):

	if revealed:
		return

	revealed = true
	await get_tree().create_timer(1.5).timeout
	var mat = $Cover.material as ShaderMaterial

	var tween = create_tween()
	tween.tween_property(
		mat,
		"shader_parameter/progress",
		2.0,
		duration
	)


func hide_cover():

	revealed = false
	var mat = $Cover.material as ShaderMaterial
	mat.set_shader_parameter("progress", -1.0)