extends Node2D

signal hovered
signal hovered_off

@onready var sprite = $Sprite2D

var peg_id := 0
var current_slot = null
var hand_position
var is_copy := false

var peg_down_reference
var peg_out_reference
var peg_sprite2D

var row := -1
var column := -1

var last_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var tilt_strength = 0.05
var max_tilt = 0.75

func _ready() -> void:
	get_parent().connect_peg_signals(self)
	add_to_group("pegs")
	peg_down_reference = preload("res://assets/peg_down.svg")
	peg_out_reference = preload("res://assets/peg_in_hand.svg")
	peg_sprite2D = $Sprite2D
	last_position = position


func _process(delta: float) -> void:
	if drag_velocity.length() > 0:
		var target_rotation = clamp(drag_velocity.x * tilt_strength, -max_tilt, max_tilt)
		rotation = lerpf(rotation, target_rotation, 10.0 * delta)
	else:
		rotation = lerpf(rotation, 0.0, 10.0 * delta)


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
