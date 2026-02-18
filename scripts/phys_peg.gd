extends Node2D

signal hovered
signal hovered_off

@onready var sprite = $Sprite2D

var peg_id := 0
var current_slot = null
var hand_position


func _ready() -> void:
	get_parent().connect_peg_signals(self)
	add_to_group("pegs")


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
