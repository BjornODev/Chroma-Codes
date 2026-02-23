extends Node2D


# =========================================================
# CONSTANTS
# =========================================================

const COLLISION_MASK_NORMAL_PEG = 1
const COLLISION_MASK_PEG_SLOT = 2


# =========================================================
# TURN STATE
# =========================================================

var cur_row := 0


# =========================================================
# DRAG STATE
# =========================================================

var peg_being_dragged = null
var drag_start_pos := Vector2.ZERO
var drag_start_slot = null
var is_hovering_on_peg := false


# =========================================================
# REFERENCES
# =========================================================

var player_hand_reference
var board_reference
var peg_scene


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	player_hand_reference = $"../PlayerHand"
	board_reference = $"../BoardManager"
	peg_scene = preload("res://scenes/Phys_Peg.tscn")

	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)


# =========================================================
# PROCESS (DRAG FOLLOW)
# =========================================================

func _process(delta: float) -> void:
	if peg_being_dragged:
		update_drag_position()


func update_drag_position():
	var mouse_pos = get_global_mouse_position()
	peg_being_dragged.drag_velocity = mouse_pos - peg_being_dragged.position
	peg_being_dragged.position = mouse_pos


# =========================================================
# START DRAG
# =========================================================

func start_drag(peg_source):
	var peg = null

	# If dragging from hand (not a copy)
	if not peg_source.is_copy:
		peg = duplicate_peg_from_source(peg_source)
	elif peg_source.row == cur_row:
		peg = peg_source
	else:
		return

	if peg == null:
		return

	prepare_peg_for_drag(peg)
	peg_being_dragged = peg


func duplicate_peg_from_source(source):
	var new_peg = source.duplicate()
	source.get_parent().add_child(new_peg)

	new_peg.is_copy = true
	new_peg.peg_id = source.peg_id

	highlight_peg(source, false)
	highlight_peg(new_peg, false)

	return new_peg


func prepare_peg_for_drag(peg):
	drag_start_pos = peg.position
	drag_start_slot = peg.current_slot

	peg.z_index = 100
	peg.scale = Vector2(1.075, 1.075)
	peg.peg_sprite2D.texture = peg.peg_out_reference

	if peg.current_slot:
		peg.current_slot.peg_in_slot = null
		peg.current_slot = null

	peg.scale = Vector2.ONE


# =========================================================
# FINISH DRAG
# =========================================================

func finish_drag():
	if peg_being_dragged == null:
		return

	reset_drag_scale()

	var slot = raycast_check_for_peg_slot()

	if slot and slot.row == cur_row:
		handle_slot_placement(slot)
	else:
		return_peg_to_hand(peg_being_dragged)

	peg_being_dragged = null


func reset_drag_scale():
	var tween_hover = create_tween()
	tween_hover.set_ease(Tween.EASE_OUT)
	tween_hover.set_trans(Tween.TRANS_ELASTIC)

	peg_being_dragged.drag_velocity = Vector2.ZERO

	tween_hover.tween_property(
		peg_being_dragged,
		"scale",
		Vector2.ONE,
		0.25
	)

	peg_being_dragged.z_index = 1


# =========================================================
# SLOT PLACEMENT LOGIC
# =========================================================

func handle_slot_placement(slot):
	var existing = slot.peg_in_slot

	# Handle spike safely
	if existing and is_spike(existing):
		resolve_spike_collision(slot, existing)

	# Place peg
	place_peg_in_slot(slot)

	# Handle swapping
	if existing and not is_spike(existing):
		handle_existing_peg(existing)


func place_peg_in_slot(slot):
	peg_being_dragged.position = slot.position
	slot.peg_in_slot = peg_being_dragged

	peg_being_dragged.current_slot = slot
	peg_being_dragged.row = slot.row
	peg_being_dragged.column = slot.column

	peg_being_dragged.peg_sprite2D.texture = peg_being_dragged.peg_down_reference


# =========================================================
# SPIKE HANDLING
# =========================================================

func is_spike(obj) -> bool:
	# Safely check spike without causing property errors
	if obj == null:
		return false
	
	# Preferred: spike script should define `is_spike = true`
	if "is_spike" in obj:
		return obj.is_spike == true
	
	return false


func resolve_spike_collision(slot, spike):
	# Damage player
	board_reference.apply_damage()

	# Remove spike safely
	spike.queue_free()
	slot.peg_in_slot = null

	# Turn off glow if slot supports it
	if slot.has_method("set_glow_off"):
		slot.set_glow_off()


# =========================================================
# EXISTING PEG HANDLING (SWAP / RETURN)
# =========================================================

func handle_existing_peg(existing):
	if drag_start_slot:
		swap_pegs(existing)
	else:
		send_peg_back_to_hand(existing)


func swap_pegs(existing):
	existing.current_slot = drag_start_slot
	drag_start_slot.peg_in_slot = existing

	var tween2 = create_tween()
	tween2.tween_property(
		existing,
		"position",
		drag_start_pos,
		0.075
	)


func send_peg_back_to_hand(peg):
	peg.current_slot = null
	peg.peg_sprite2D.texture = peg.peg_out_reference
	player_hand_reference.return_peg_to_hand(peg)


func return_peg_to_hand(peg):
	player_hand_reference.return_peg_to_hand(peg)


# =========================================================
# INPUT CALLBACK
# =========================================================

func on_left_click_released():
	if peg_being_dragged:
		finish_drag()


# =========================================================
# HOVER LOGIC
# =========================================================

func connect_peg_signals(peg):
	peg.connect("hovered", on_hovered_over_peg)
	peg.connect("hovered_off", on_hovered_off_peg)


func on_hovered_over_peg(peg):
	if not is_hovering_on_peg:
		is_hovering_on_peg = true
		highlight_peg(peg, true)


func on_hovered_off_peg(peg):
	if peg_being_dragged:
		return
	
	highlight_peg(peg, false)

	var new_hover = raycast_check_for_peg()
	if new_hover:
		highlight_peg(new_hover, true)
	else:
		is_hovering_on_peg = false


func highlight_peg(peg, hovered):
	if peg == null:
		return
	
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
			Vector2.ONE,
			0.25
		)


# =========================================================
# RAYCAST UTILITIES
# =========================================================

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
	var highest = pegs[0].collider.get_parent()
	var highest_z = highest.z_index

	for i in range(1, pegs.size()):
		var current = pegs[i].collider.get_parent()
		if current.z_index > highest_z:
			highest = current
			highest_z = current.z_index

	return highest


# =========================================================
# SAFETY RESET (FOR UNDO / REDO SYSTEM)
# =========================================================

func force_clear_drag_state():
	if peg_being_dragged:
		peg_being_dragged = null
	drag_start_slot = null
	drag_start_pos = Vector2.ZERO
	is_hovering_on_peg = false


# =========================================================
# OPTIONAL: SYNC CUR ROW FROM BOARD
# =========================================================

func sync_row_from_board():
	if board_reference:
		cur_row = board_reference.peg_manager_reference.cur_row