extends Node2D

var can_click_off := false

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	can_click_off = true

func _input(event):
# Detects any mouse button press or release
	if can_click_off:
		if event is InputEventMouseButton:
			if event.is_pressed():
				get_tree().change_scene_to_file("res://scenes/RunSetupScreen.tscn")
