extends Node2D

const COLLISION_MASK_PEG = 1
const COLLISION_MASK_PEG_SLOT = 2

var peg_being_dragged
var is_hovering_on_peg
var drag_start_pos
var drag_start_slot
var player_hand_reference

func _ready() -> void:
	player_hand_reference = $"../PlayerHand"

func _process(delta: float) -> void:
	if peg_being_dragged:
		var mouse_pos = get_global_mouse_position()
		peg_being_dragged.position = mouse_pos


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var peg = raycast_check_for_peg()
			if peg:
				start_drag(peg)
		else:
			if peg_being_dragged:
				finish_drag()


func start_drag(peg):
	drag_start_pos = peg.position
	drag_start_slot = peg.current_slot
	if peg.current_slot:
		peg.current_slot.peg_in_slot = null
		peg.current_slot = null

	peg_being_dragged = peg
	peg.scale = Vector2(1, 1)


func finish_drag():
	peg_being_dragged.scale = Vector2(1.05, 1.05)
	
	var peg_slot_found = raycast_check_for_peg_slot()
	
	if peg_slot_found:
		var other_peg = peg_slot_found.peg_in_slot
		
		# Place dragged peg in slot
		peg_being_dragged.position = peg_slot_found.position
		peg_slot_found.peg_in_slot = peg_being_dragged
		peg_being_dragged.current_slot = peg_slot_found
		
		# If slot already had peg
		if other_peg:
			if drag_start_slot:
				# Swap between slots
				other_peg.position = drag_start_pos
				other_peg.current_slot = drag_start_slot
				drag_start_slot.peg_in_slot = other_peg
			else:
				# Peg came from hand → send old peg back to hand
				other_peg.current_slot = null
				player_hand_reference.add_card_to_hand(other_peg)
	else:
		peg_being_dragged.current_slot = null
		player_hand_reference.add_card_to_hand(peg_being_dragged)

	peg_being_dragged = null

#func finish_drag():
#	peg_being_dragged.scale = Vector2(1.05, 1.05)
#	
#	var peg_slot_found = raycast_check_for_peg_slot()
#	var other_peg = peg_slot_found.peg_in_slot
#	
#	# Place dragged peg in slot
#	peg_being_dragged.position = peg_slot_found.position
#	peg_slot_found.peg_in_slot = peg_being_dragged
#	peg_being_dragged.current_slot = peg_slot_found
#	if peg_slot_found:
#		# Find peg currently in that slot
#		var other_peg = null
#		for peg in get_tree().get_nodes_in_group("pegs"):
#			if peg.current_slot == peg_slot_found:
#				other_peg = peg
#				break
#
#		# Place dragged peg in slot
#		peg_being_dragged.position = peg_slot_found.position
#		peg_slot_found.peg_in_slot = true
#		peg_being_dragged.current_slot = peg_slot_found
#
		# Swap if another peg was there
#	if other_peg and drag_start_slot:
#		other_peg.position = drag_start_pos
#		other_peg.current_slot = drag_start_slot
#		drag_start_slot.peg_in_slot = true
#	else:
#		# Return peg if no slot found
#		if drag_start_slot:
#			peg_being_dragged.position = drag_start_pos
#			drag_start_slot.peg_in_slot = true
#			peg_being_dragged.current_slot = drag_start_slot

	peg_being_dragged = null


func connect_peg_signals(peg):
	peg.connect("hovered", on_hovered_over_peg)
	peg.connect("hovered_off", on_hovered_off_peg)

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
	if hovered:
		peg.scale = Vector2(1.05, 1.05)
		peg.z_index = 2
	else:
		peg.scale = Vector2(1, 1)
		peg.z_index = 1


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
	parameters.collision_mask = COLLISION_MASK_PEG
	
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