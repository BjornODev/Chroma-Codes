extends Node2D

const COLLISION_MASK_NORMAL_PEG = 1
const COLLISION_MASK_PEG_SLOT = 2

var cur_row = 0
var replace_mode := false
var replaces_left := 0
var edited_rows := {}

var reveal_mode := false
var reveals_left := 0

var delete_mode := false
var deletions_left := 0

var peg_being_dragged
var is_hovering_on_peg

var drag_start_pos
var drag_start_slot

var player_hand_reference
var peg_reference
var board_reference
var pattern_engine
var item_system

func _ready() -> void:
	player_hand_reference = $"../PlayerHand"
	peg_reference = preload("res://scenes/Phys_Peg.tscn")
	board_reference = $"../BoardManager"
	pattern_engine = PatternEngine
	item_system = ItemManager
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	start_reveal(2)

func _process(delta: float) -> void:
	if peg_being_dragged:
		var mouse_pos = get_global_mouse_position()
		peg_being_dragged.drag_velocity = mouse_pos - peg_being_dragged.position
		peg_being_dragged.global_position = mouse_pos


func start_drag(peg_stack):
	var peg = null
	print(cur_row)
	if !peg_stack.is_copy and not peg_stack.is_special:
		peg = peg_stack.duplicate()
		peg_stack.get_parent().add_child(peg)
		peg.is_copy = true
		peg.peg_id = peg_stack.peg_id
		peg.hand_position = peg_stack.hand_position
		peg.counter.visible = false
		highlight_peg(peg_stack, false)
		highlight_peg(peg, false)

	elif peg_stack.row == cur_row:
		peg = peg_stack
	elif peg_stack.is_special and peg_stack.row == -1:
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
	var target_row = cur_row
	var can_place := false
	
	if peg_slot_found:
		if replace_mode:
			if peg_slot_found.row < cur_row:
				can_place = true
		else:
			if peg_slot_found.row == cur_row:
				can_place = true
	
	if can_place:
		var other_peg = peg_slot_found.peg_in_slot
		
		if other_peg and other_peg.get("is_spike"):
			# Damage player
			board_reference.apply_damage(1)
			
			# Remove spike
			other_peg.queue_free()
			peg_slot_found.peg_in_slot = null
			peg_slot_found.set_glow_off()
			other_peg = null
			
			if replace_mode:
				replaces_left -= 1
				peg_being_dragged.update_shader_value(16)
				edited_rows[peg_slot_found.row] = true
				
				print("Replacements left:", replaces_left)
				
				if replaces_left <= 0:
					print("No replacements left. Awaiting confirmation.")
				
		elif other_peg and other_peg.get("is_obscure"):
			AudioLoader.play_sound("obscure", -20.0)
			board_reference.obscurities += 1
			other_peg.queue_free()
			peg_slot_found.peg_in_slot = null
			other_peg = null
			
			if replace_mode:
				replaces_left -= 1
				peg_being_dragged.update_shader_value(16)
				edited_rows[peg_slot_found.row] = true
				
				print("Replacements left:", replaces_left)
				
				if replaces_left <= 0:
					print("No replacements left. Awaiting confirmation.")

		
		# Place dragged peg in slot
		peg_being_dragged.position = peg_slot_found.position
		peg_slot_found.peg_in_slot = peg_being_dragged
		peg_being_dragged.current_slot = peg_slot_found
		peg_being_dragged.peg_sprite2D.texture = peg_being_dragged.peg_down_reference
		peg_being_dragged.row = peg_slot_found.row
		peg_being_dragged.column = peg_slot_found.column
		
		if peg_being_dragged.is_special:
			player_hand_reference.remove_peg_from_hand(peg_being_dragged)
		AudioLoader.play_sound("peg_snap")
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
				
			if replace_mode:
				replaces_left -= 1
				peg_being_dragged.update_shader_value(16)
				edited_rows[peg_slot_found.row] = true
				
				print("Replacements left:", replaces_left)
				
				if replaces_left <= 0:
					print("No replacements left. Awaiting confirmation.")
	else:
		peg_being_dragged.current_slot = null
		player_hand_reference.return_peg_to_hand(peg_being_dragged)
		if peg_being_dragged.is_special:
			player_hand_reference.player_hand.append(peg_being_dragged)
	
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


func start_replace_mode(amount):
	if board_reference.board_state.is_empty():
		return
	
	if cur_row <= 0:
		return
	
	$"../ReplaceConfirmationButton".disabled = false
	$"../ReplaceConfirmationButton".visible = true
	replace_mode = true
	replaces_left += amount
	edited_rows.clear()
	
	print("Replace mode active. Replacements:", amount)

func confirm_replace():
	if not replace_mode:
		return
	
	var board = get_node("../BoardManager")
	$"../ReplaceConfirmationButton".disabled = true
	$"../ReplaceConfirmationButton".visible = false
	for row in edited_rows.keys():
		board.re_evaluate_row(row)
	
	replace_mode = false
	replaces_left = 0
	edited_rows.clear()
	
	var triggered = pattern_engine.evaluate_board(
		board_reference.board_state,
		board_reference.rows_generated,
		board_reference.columns,
		cur_row
	)

	for p in triggered:
		if item_system.has_item_trigger_for_pattern(p.name):
			board_reference.spawn_pattern_markers(p.positions)
	
			item_system.emit_game_event("pattern_triggered", {
				"pattern_name": p.name,
				"positions": p.positions
			})
	item_system.process_turn_events()
	print("Replace confirmed.")


func destroy_obstacle(slot):
	if delete_mode:
		if slot.row >= cur_row:
			var obstacle = slot.peg_in_slot
			if obstacle and obstacle.get("is_spike"):
				var tween = create_tween()
				
				tween.tween_property(obstacle.sprite, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				slot.peg_in_slot = null
				await tween.finished
				obstacle.queue_free()
				if !slot.in_danger_row:
					slot.set_glow_off()
				
				deletions_left -= 1
				
				if deletions_left == 0:
					delete_mode = false
	

func start_clear(amount):
	delete_mode = true
	deletions_left = amount
	
	print("Clear mode started clears: ", amount)


func reveal_code(code_peg):
	if reveal_mode == true:
		if !code_peg.revealed:
			code_peg.reveal()
			reveals_left -= 1
			if reveals_left <= 0:
				reveal_mode = false

func start_reveal(amount):
	reveal_mode = true
	reveals_left += amount

func _on_pressed() -> void:
	confirm_replace()
	AudioLoader.play_sound("select")
