extends Node2D

@export var rows := 8
@export var columns := 4
@export var spacing := 45
var slot_size = 35
var slot_scene 

func _ready() -> void:
	slot_scene = preload("res://scenes/Snap_Zone.tscn")
	build_board()

func build_board():
	var camera = $"../Camera2D"
	var camera_center = camera.global_position
	var screen_size = get_viewport().get_visible_rect().size
	
	var total_width = columns * slot_size + (columns - 1) * spacing
	var total_height = rows * slot_size + (rows - 1) * spacing
	
	var start_x = camera_center.x - total_width / 2.0
	var start_y = camera_center.y - total_height / 2.0
	
	for r in range(rows):
		for c in range(columns):
			var slot = slot_scene.instantiate()
			slot.row = r
			slot.column = c
			add_child(slot)
			
			var x = start_x + c * (slot_size + spacing)
			var y = start_y + r * (slot_size + spacing)
			
			slot.position = Vector2(x, y)