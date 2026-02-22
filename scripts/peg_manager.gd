extends Node2D

const COLLISION_MASK_NORMAL_PEG = 1
const COLLISION_MASK_PEG_SLOT = 2

var cur_row = 0

var peg_being_dragged
var is_hovering_on_peg

var drag_start_pos
var drag_start_slot

var player_hand_reference
var peg_reference


func _ready() -> void:
	player_hand_reference = $"../PlayerHand"
	peg_reference = preload("res://scenes/Phys_Peg.tscn")
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)


func _process(delta: float) -> void:
	if peg_being_dragged:
		var mouse_pos = get_global_mouse_position()
		peg_being_dragged.drag_velocity = mouse_pos - peg_being_dragged.position
		peg_being_dragged.position = mouse_pos


func start_drag(peg_stack):
	var peg = null
	print(cur_row)
	if !peg_stack.is_copy:
		peg = peg_stack.duplicate()
		peg_stack.get_parent().add_child(peg)
		peg.is_copy = true
		peg.peg_id = peg_stack.peg_id
		highlight_peg(peg_stack, false)
		highlight_peg(peg, false)

	elif peg_stack.row == cur_row:
		peg = peg_stack
	else:
		return
	drag_start_pos = peg.position
	drag_start_slot = peg.current_slot
	peg.z_index = 100
	peg.scale = Vector2(1.075, 1.075)
	peg.peg_sprite2D.texture = peg.peg_out_reference
	if peg.current_slot:
		peg.current_slot.peg_in_slot = null
		peg.current_slot = null

	peg_being_dragged = peg
	peg.scale = Vector2(1, 1)


func finish_drag():
	var tween_hover = create_tween()
	tween_hover.set_ease(Tween.EASE_OUT)
	tween_hover.set_trans(Tween.TRANS_ELASTIC)
	peg_being_dragged.drag_velocity = Vector2.ZERO
	
	tween_hover.tween_property(
			peg_being_dragged,
			"scale",
			Vector2(1, 1),
			0.25
		)
	
	peg_being_dragged.z_index = 1
	var peg_slot_found = raycast_check_for_peg_slot()
#	print("Slot row:", peg_slot_found.row, "Current row:", cur_row)
	if peg_slot_found and peg_slot_found.row == cur_row:
		var other_peg = peg_slot_found.peg_in_slot
		
		# Place dragged peg in slot
		peg_being_dragged.position = peg_slot_found.position
		peg_slot_found.peg_in_slot = peg_being_dragged
		peg_being_dragged.current_slot = peg_slot_found
		peg_being_dragged.peg_sprite2D.texture = peg_being_dragged.peg_down_reference
		peg_being_dragged.row = peg_slot_found.row
		peg_being_dragged.column = peg_slot_found.column
		
		# If slot already had peg
		if other_peg:
			if drag_start_slot:
				# Swap between slots
				other_peg.current_slot = drag_start_slot
				drag_start_slot.peg_in_slot = other_peg
				# Tween other peg into old slot
				var tween2 = create_tween()
				tween2.tween_property(
					other_peg,
					"position",
					drag_start_pos,
					0.075
				)
			else:
				# Peg came from hand → send old peg back to hand
				other_peg.current_slot = null
				other_peg.peg_sprite2D.texture = other_peg.peg_out_reference
				player_hand_reference.return_peg_to_hand(other_peg)
	else:
		peg_being_dragged.current_slot = null
		player_hand_reference.return_peg_to_hand(peg_being_dragged)
	
	peg_being_dragged = null


func connect_peg_signals(peg):
	peg.connect("hovered", on_hovered_over_peg)
	peg.connect("hovered_off", on_hovered_off_peg)


func on_left_click_released():
	if peg_being_dragged:
		finish_drag()


func on_hovered_over_peg(peg):
	if !is_hovering_on_peg:
		is_hovering_on_peg = true
		highlight_peg(peg, true)


func on_hovered_off_peg(peg):
	if !peg_being_dragged:
		highlight_peg(peg, false)
		var new_peg_hovered = raycast_check_for_peg()
		if new_peg_hovered:
			highlight_peg(new_peg_hovered, true)
		else:
			is_hovering_on_peg = false


func highlight_peg(peg, hovered):
	var tween_hover = create_tween()
	tween_hover.set_ease(Tween.EASE_OUT)
	tween_hover.set_trans(Tween.TRANS_ELASTIC)
	
	if hovered:
		tween_hover.tween_property(
			peg,
			"scale",
			Vector2(1.2, 1.2),
			0.25
		)
	else:
		tween_hover.tween_property(
			peg,
			"scale",
			Vector2(1, 1),
			0.25
		)


func raycast_check_for_peg_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_PEG_SLOT
	
	var result = space_state.intersect_point(parameters)
	
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null


func raycast_check_for_peg():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_NORMAL_PEG
	
	var result = space_state.intersect_point(parameters)
	
	if result.size() > 0:
		return get_peg_with_highest_z_index(result)
	return null


func get_peg_with_highest_z_index(pegs):
	var highest_z_peg = pegs[0].collider.get_parent()
	var highest_z_index = highest_z_peg.z_index
	
	for i in range(1, pegs.size()):
		var current_peg = pegs[i].collider.get_parent()
		if current_peg.z_index > highest_z_index:
			highest_z_peg = current_peg
			highest_z_index = current_peg.z_index
	return highest_z_peg