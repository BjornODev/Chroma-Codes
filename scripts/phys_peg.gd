extends Node2D

signal hovered
signal hovered_off

@onready var sprite = $Sprite2D

var color_id := 0
var current_slot = null
var hand_position


var textures = [
	preload("res://assets/pegs/circle_1.svg"),
	preload("res://assets/pegs/circle_2.svg"),
	preload("res://assets/pegs/circle_3.svg"),
	preload("res://assets/pegs/circle_4.svg"),
	preload("res://assets/pegs/circle_5.svg"),
	preload("res://assets/pegs/circle_6.svg")
	]

func _ready() -> void:
	get_parent().connect_peg_signals(self)
	add_to_group("pegs")

func set_color(id):
	color_id = id
	sprite.texture = textures[id]


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)
