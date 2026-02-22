extends Node2D


@export var wait_time := 1
@export var speed := 1.25

func _ready():
	var pulse_duration = (0.75 + wait_time) / speed
	await get_tree().create_timer(pulse_duration).timeout
	queue_free()