extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_NORMAL_PEG = 1
const COLLISION_MASK_PEG_SLOT = 2

var card_manager_reference


func _ready() -> void:
	card_manager_reference = $"../PegManager"


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			raycast_at_cursor()
			emit_signal("left_mouse_button_clicked")
		else:
			emit_signal("left_mouse_button_released")


func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	
	var result = space_state.intersect_point(parameters)
	
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		if result_collision_mask == COLLISION_MASK_NORMAL_PEG:
			var card_found = result[0].collider.get_parent()
			if card_found:
				card_manager_reference.start_drag(card_found)
		if result_collision_mask == COLLISION_MASK_PEG_SLOT:
				var slot_found = result[0].collider.get_parent()
				if slot_found:
					card_manager_reference.destroy_obstacle(slot_found)
	