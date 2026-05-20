extends Node

signal health_changed(new_amount: int)
signal dollars_changed(new_amount: int)

var run_active := false
var boards_cleared := 0

var first_time_on_map := true
var map_offset := 0

var reward_pool_items := []
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

var _rng := RandomNumberGenerator.new()


# =========================
# RUN START
# =========================

func start_new_run():
	run_active = true
	boards_cleared = 0
	player_health = 5
	dollars = 0

	var seed = randi()
	MapManager.start_run(seed)
	PegInventoryManager.reset_for_new_run()

	reward_pool_items = ItemManager.all_items.duplicate()
	_rng.seed = MapManager.run_seed


func end_run():
	run_active = false
	boards_cleared = 0


func board_cleared():
	boards_cleared += 1


# =========================
# BOARD MODIFIER GENERATION
# =========================

func apply_board_modifiers():
	print("Applying board modifiers, boards_cleared:", boards_cleared)
	BoardModifierEngine.active_modifiers.clear()
	
	var board_index = boards_cleared
	var modifier_count = board_index
	print("Cleared modifiers, modifier_count:", modifier_count)

	if modifier_count <= 0:
		return

	# Deterministic seed per board
	var board_seed = MapManager.run_seed + board_index * 999983
	_rng.seed = board_seed

	var available = BoardModifierEngine.all_modifiers.duplicate()
	_seeded_shuffle(available)

	var added_modifiers: Array = []

	for i in range(modifier_count):
		# 25% chance to upgrade existing modifier
		if added_modifiers.size() > 0 and _rng.randf() < 0.25:
			var upgradeable = added_modifiers.filter(func(m): return m.level < 3)
			if not upgradeable.is_empty():
				var to_upgrade = upgradeable[_rng.randi() % upgradeable.size()]
				to_upgrade.level += 1
				continue

		# Add new modifier not already in list
		var candidates = available.filter(
			func(m): return not added_modifiers.any(
				func(a): return a.modifier_name == m.modifier_name
			)
		)

		if candidates.is_empty():
			break

		var chosen = candidates[_rng.randi() % candidates.size()]
		var new_mod = chosen.duplicate()
		new_mod.level = 1
		added_modifiers.append(new_mod)
		BoardModifierEngine.active_modifiers.append(new_mod)


func _seeded_shuffle(arr: Array):
	for i in range(arr.size() - 1, 0, -1):
		var j = _rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


# =========================
# REWARD CHOICES — ITEMS ONLY
# =========================

func get_reward_choices() -> Array:
	var choices := []

	var weighted = _get_weighted_item_pool(reward_pool_items)
	_seeded_shuffle(weighted)

	var selected_names := []

	for i in range(3):
		if weighted.is_empty():
			break

		var found: ItemData = null
		for item in weighted:
			if item.item_name not in selected_names:
				found = item
				break

		if found == null:
			found = weighted[0]

		selected_names.append(found.item_name)
		weighted.erase(found)
		choices.append({"item": found})

	return choices


func _get_weighted_item_pool(pool: Array) -> Array:
	var weighted := []
	for item in pool:
		if item.is_gamble_only:
			continue  # ← add this
		var weight = _rarity_weight(item.rarity)
		for i in range(weight):
			weighted.append(item)
	return weighted


func _rarity_weight(rarity: int) -> int:
	match rarity:
		0: return 8
		1: return 4
		2: return 2
		3: return 1
	return 8


# =========================
# HEALTH
# =========================

func add_health(amount: int):
	player_health += amount
	emit_signal("health_changed", player_health)


func remove_health(amount: int):
	player_health -= amount
	emit_signal("health_changed", player_health)


func set_health(amount: int):
	player_health = amount
	emit_signal("health_changed", player_health)


# =========================
# DOLLARS
# =========================

func add_dollars(amount: int):
	dollars += amount
	emit_signal("dollars_changed", dollars)


func spend_dollars(amount: int) -> bool:
	if dollars < amount:
		return false
	dollars -= amount
	emit_signal("dollars_changed", dollars)
	return true


func can_afford(amount: int) -> bool:
	return dollars >= amount

# =========================
# BOARD STATS
# =========================

func reset_board_stats():
	board_rows_submitted = 0
	board_damage_taken = 0
	for key in board_peg_counts.keys():
		board_peg_counts[key] = 0


func record_row_submitted(guess: Array):
	board_rows_submitted += 1
	for peg_id in guess:
		if board_peg_counts.has(peg_id):
			board_peg_counts[peg_id] += 1


func record_damage_taken(amount: int):
	board_damage_taken += amount
