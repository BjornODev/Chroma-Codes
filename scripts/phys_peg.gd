extends Node2D

signal hovered
signal hovered_off

var peg_id := 0
var current_slot = null
var hand_position
var is_copy := false

var peg_database_reference
var peg_down_reference
var peg_out_reference
var peg_sprite2D

var row := -1
var column := -1

var last_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var tilt_strength = 0.05
var max_tilt = 0.75

var is_special := false
var special_type := ""


var shader_material: ShaderMaterial

@onready var modifier = ""

#func _ready() -> void:
#	get_parent().connect_peg_signals(self)
#	add_to_group("pegs")
#	if is_special:
#		modifier = "_" + special_type
#	peg_database_reference = preload("res://scripts/peg_data.gd")
#	peg_down_reference = load("res://assets/peg_down" + modifier + ".svg")
#	peg_out_reference = load("res://assets/peg_out" + modifier + ".svg")
#	peg_sprite2D = $Sprite2D
#	
#	peg_sprite2D.material = peg_sprite2D.material.duplicate()
#	last_position = position
#	shader_material = peg_sprite2D.material as ShaderMaterial
#	if shader_material == null:
#		print("Error: Material is not a ShaderMaterial")
#		return


func _ready():
	get_parent().connect_peg_signals(self)
	add_to_group("pegs")
	peg_database_reference = preload("res://scripts/peg_data.gd")
	peg_sprite2D = $Sprite2D
	
	setup_visuals()
	
	peg_sprite2D.material = peg_sprite2D.material.duplicate()
	last_position = position
	shader_material = peg_sprite2D.material as ShaderMaterial


func _process(delta: float) -> void:
	if drag_velocity.length() > 0:
		var target_rotation = clamp(drag_velocity.x * tilt_strength, -max_tilt, max_tilt)
		rotation = lerpf(rotation, target_rotation, 10.0 * delta)
	else:
		rotation = lerpf(rotation, 0.0, 10.0 * delta)


func setup_visuals():
	modifier = ""
	if is_special:
		modifier = "_" + special_type
	
	peg_down_reference = load("res://assets/peg_down" + modifier + ".svg")
	peg_out_reference = load("res://assets/peg_out" + modifier + ".svg")
	
	if peg_sprite2D:
		peg_sprite2D.texture = peg_out_reference


func update_shader_value(new_value):
	if shader_material:
		shader_material.set_shader_parameter("outline_thickness", new_value)



func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)


func get_submission_value():
	if is_special:
		match special_type:
			"goop":
				return 0  # Special non-color ID
	return peg_id