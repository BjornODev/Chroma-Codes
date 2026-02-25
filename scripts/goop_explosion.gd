extends Node2D

@onready var particles = $Particles

func explode():
	particles.emitting = true
	await get_tree().create_timer(1.0).timeout
	queue_free()