extends Node2D

const HAND_COUNT = 6
const PEG_SCENE_PATH = "res://scenes/Phys_Peg.tscn"
const PEG_WIDTH = 100
const HAND_Y_POSITION = 475

var peg_bag = [6, 5, 4, 3, 2, 1]
var player_hand = []
var center_screen_x
var peg_database_reference


func _ready() -> void:
	center_screen_x = $"../Camera2D".position.x
	var peg_scene = preload(PEG_SCENE_PATH)
	peg_database_reference = preload("res://scripts/basics/peg_data.gd")
	for i in peg_bag:
		var new_peg = peg_scene.instantiate()
		new_peg.peg_id = i
		$"../PegManager".add_child(new_peg)
		new_peg.peg_sprite2D.modulate = Color(peg_database_reference.PEG_TYPES[new_peg.peg_id][0])
		player_hand.insert(-0, new_peg)
		update_hand_positions()


# =========================
# CLICK-TO-SPAWN
# =========================

func try_spawn_peg_from_stack(stack_peg):
	var color_id = stack_peg.peg_id

	if PegInventoryManager.is_empty(color_id):
		_on_empty_stack_clicked()
		return null

	PegInventoryManager.remove_peg(color_id)

	var peg_scene = preload(PEG_SCENE_PATH)
	var new_peg = peg_scene.instantiate()
	new_peg.peg_id = color_id
	new_peg.is_copy = true
	$"../PegManager".add_child(new_peg)
	new_peg.peg_sprite2D.modulate = Color(peg_database_reference.PEG_TYPES[color_id][0])
	new_peg.position = stack_peg.position

	return new_peg


func _on_empty_stack_clicked():
	var board = $"../BoardManager"
	if board and board.has_method("apply_damage"):
		board.apply_damage(PegInventoryManager.refill_damage)
	PegInventoryManager.refill_all_stacks()
	AudioLoader.play_sound("damage")


# =========================
# RETURNING PEGS
# =========================

func return_peg_to_hand(peg):
	var should_delete = peg.is_copy and not peg.is_special

	# Return count to inventory if this is a normal copied peg
	if should_delete and not peg.is_special:
		PegInventoryManager.return_peg(peg.peg_id)

	animate_peg_to_position(peg, peg.hand_position, should_delete)


# =========================
# POSITIONING
# =========================

func update_hand_positions():
	for i in range(player_hand.size()):
		var new_position = Vector2(calculate_peg_position(i), HAND_Y_POSITION)
		var peg = player_hand[i]
		peg.hand_position = new_position
		animate_peg_to_position(peg, new_position, false)


func calculate_peg_position(index):
	var x_offset = (player_hand.size() - 1) * PEG_WIDTH
	var x_position = center_screen_x + index * PEG_WIDTH - x_offset / 2
	return x_position


func animate_peg_to_position(peg, new_position, duplicate):
	var tween = get_tree().create_tween()
	tween.tween_property(peg, "position", new_position, 0.075)

	if duplicate:
		await tween.finished
		peg.queue_free()


func remove_peg_from_hand(peg):
	if peg in player_hand:
		player_hand.erase(peg)
		update_hand_positions()


# =========================
# SPECIAL PEGS
# =========================

func add_special_peg(peg):
	for existing in player_hand:
		if existing.is_stack() and existing.special_type == peg.special_type:
			existing.add_to_stack(1)
			return

	peg.is_special = true
	peg.is_copy = false
	peg.stack_count = 1

	$"../PegManager".add_child(peg)
	player_hand.append(peg)
	update_hand_positions()


func return_special_to_stack(peg):
	var target_stack = null

	for existing in player_hand:
		if existing.is_stack() and existing.special_type == peg.special_type:
			target_stack = existing
			break

	if target_stack:
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(peg, "position", target_stack.position, 0.2)
		await tween.finished

		if not is_instance_valid(target_stack):
			peg.is_copy = false
			peg.stack_count = 1
			player_hand.append(peg)
			update_hand_positions()
			return

		target_stack.add_to_stack(1)
		peg.queue_free()
		return

	peg.is_copy = false
	peg.stack_count = 1
	player_hand.append(peg)
	update_hand_positions()