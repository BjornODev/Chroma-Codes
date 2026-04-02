extends Node

var run_active := false
var boards_cleared := 0

var first_time_on_map := true
var map_offset : int

var reward_pool_items := []
var reward_pool_modifiers := []

var player_health := 5
var dollars := 0

var board_rows_submitted := 0
var board_damage_taken := 0
var board_peg_counts := {
	1: 0,  # red
	2: 0,  # yellow
	3: 0,  # green
	4: 0,  # white
	5: 0,  # purple
	6: 0,  # orange
}

signal health_changed(new_amount: int)
signal dollars_changed(new_amount: int)
signal dollars_activated(index: int, total_activations: int)

func add_health(amount: int):
	player_health += amount
	emit_signal("health_changed", player_health)

func remove_health(amount: int):
	player_health -= amount
	emit_signal("health_changed", player_health)

func set_health(amount: int):
	player_health = amount
	emit_signal("health_changed", player_health)

func add_dollars(amount: int):
	dollars += amount
	emit_signal("dollars_changed", dollars)

func spend_dollars(amount: int) -> bool:
	if dollars < amount:
		return false
	dollars -= amount
	emit_signal("dollars_changed", dollars)
	return true



func start_new_run():
	run_active = true
	boards_cleared = 0
	player_health = 5
	dollars = 0
	
	BackgroundGenerator.clear_cache()
	ActiveItemManager.reset_on_new_run()
	ShopManager.is_initialized = false
	
	var seed = randi()
	MapManager.start_run(seed)
	
	reward_pool_items = ItemManager.all_items.duplicate()
	reward_pool_modifiers = BoardModifierEngine.all_modifiers.duplicate()

func end_run():
	run_active = false
	boards_cleared = 0


func board_cleared():
	boards_cleared += 1

#func get_reward_choices():
#	var item_pool = reward_pool_items.duplicate()
#	var mod_pool = reward_pool_modifiers.duplicate()
#	
#	item_pool.shuffle()
#	mod_pool.shuffle()
#	
#	var choices := []
#	
#	for i in range(3):
#		if i >= item_pool.size() or i >= mod_pool.size():
#			break
#		
#		choices.append({
#			"item": item_pool[i],
#			"modifier": mod_pool[i]
#		})
#	
#	return choices


func get_reward_choices() -> Array:
	var choices := []
	var weighted_items = _get_weighted_pool(reward_pool_items)
	weighted_items.shuffle()
	reward_pool_modifiers.shuffle()
	for i in range(3):
		if weighted_items.is_empty() or reward_pool_modifiers.is_empty():
			break
		choices.append({
			"item": weighted_items.pop_front(),
			"modifier": reward_pool_modifiers.pop_front()
		})
	return choices

func _get_weighted_pool(pool: Array) -> Array:
	var weighted := []
	for item in pool:
		var weight = _rarity_weight(item.rarity)
		for i in range(weight):
			weighted.append(item)
	weighted.shuffle()
	return weighted

func _rarity_weight(rarity: int) -> int:
	match rarity:
		0: return 8   # Common
		1: return 4   # Uncommon
		2: return 2   # Rare
		3: return 1   # Legendary
	return 8


func reset_board_stats():
	board_rows_submitted = 0
	board_damage_taken = 0
	for key in board_peg_counts.keys():
		board_peg_counts[key] = 0


func record_row_submitted(guess: Array):
	print("RECORDING ROW - before:", board_rows_submitted)
	board_rows_submitted += 1
	print("RECORDING ROW - after:", board_rows_submitted)
	for peg_id in guess:
		if board_peg_counts.has(peg_id):
			board_peg_counts[peg_id] += 1


func record_damage_taken(amount: int):
	board_damage_taken += amount