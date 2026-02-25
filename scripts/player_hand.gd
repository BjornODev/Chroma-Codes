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
	peg_database_reference = preload("res://scripts/peg_data.gd")
	for i in peg_bag:
		var new_peg = peg_scene.instantiate()
		new_peg.peg_id = i
#		new_peg.peg_sprite2D.modulate = Color(peg_database_reference.PEG_TYPES[new_peg.peg_id][0])
		$"../PegManager".add_child(new_peg)
		new_peg.peg_sprite2D.modulate = Color(peg_database_reference.PEG_TYPES[new_peg.peg_id][0])
		var new_peg_name = "Peg"
		player_hand.insert(-0, new_peg)
		update_hand_positions()


func return_peg_to_hand(peg):
	var should_delete = peg.is_copy and not peg.is_special
	animate_peg_to_position(peg, peg.hand_position, should_delete)


func update_hand_positions():
	for i in range(player_hand.size()):
		# Get new card position based on index
		var new_position = Vector2(calculate_peg_position(i), HAND_Y_POSITION)
		var peg = player_hand[i]
		peg.hand_position = new_position
		animate_peg_to_position(peg, new_position, false)


func calculate_peg_position(index):
	var x_offset = (player_hand.size() - 1) * PEG_WIDTH
	var x_position =  center_screen_x + index * PEG_WIDTH - x_offset / 2
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


func add_special_peg(peg):
	$"../PegManager".add_child(peg)
	player_hand.append(peg)
	update_hand_positions()