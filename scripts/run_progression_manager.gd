extends Node

var run_active := false
var boards_cleared := 0

var reward_pool_items := []
var reward_pool_modifiers := []

func start_new_run():
	run_active = true
	boards_cleared = 0
	
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


func get_reward_choices():
	var choices := []
	
	reward_pool_items.shuffle()
	reward_pool_modifiers.shuffle()
	
	for i in range(3):
		if reward_pool_items.is_empty() or reward_pool_modifiers.is_empty():
			break
		
		var item = reward_pool_items.pop_front()
		var mod = reward_pool_modifiers.pop_front()
		
		choices.append({
			"item": item,
			"modifier": mod
		})
	
	return choices