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
	1: 0,
	2: 0,
	3: 0,
	4: 0,
	5: 0,
	6: 0,
}

# =========================
# PEG QUOTAS
# =========================
# The quota a player must meet for the current map, as { color_name: amount }.
# Only colors that HAVE a quota appear in this dict.
# Color names match MapManager.COLORS.

var peg_quotas: Dictionary = {}

# Which map the player is on (1-indexed). Drives quota scaling.
var current_map_number: int = 1

# --- Quota generation tuning ---
const QUOTA_BASE := 50              # total pegs required on map 1
const QUOTA_GROWTH := 25             # quadratic growth coefficient
const QUOTA_FLOOR_FRAC := 0.3        # min per-color share (fraction of even split)
const QUOTA_COLORS := ["red", "yellow", "green", "white", "purple", "orange"]

# =========================
# PLAYTEST OVERRIDES
# Set by PlaytestSettings.apply_to_new_run(). When playtest_quota_override is
# true, quota_total_for_map uses playtest_quota_base instead of QUOTA_BASE.
# =========================

var playtest_quota_override := false
var playtest_quota_base := 50

var _rng := RandomNumberGenerator.new()


# =========================
# RUN START
# =========================

func start_new_run():
	run_active = true
	boards_cleared = 0
	player_health = 10
	dollars = 0

	var seed = randi()
	MapManager.start_run(seed)
	PegInventoryManager.reset_for_new_run()

	reward_pool_items = ItemManager.all_items.duplicate()
	_rng.seed = MapManager.run_seed

	# Set up the first map's quotas
	current_map_number = 1
	generate_quotas_for_map(current_map_number)


func end_run():
	run_active = false
	boards_cleared = 0
	ItemManager.player_items.clear()


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

	var board_seed = MapManager.run_seed + board_index * 999983
	_rng.seed = board_seed

	var available = BoardModifierEngine.all_modifiers.duplicate()
	_seeded_shuffle(available)

	var added_modifiers: Array = []

	for i in range(modifier_count):
		if added_modifiers.size() > 0 and _rng.randf() < 0.25:
			var upgradeable = added_modifiers.filter(func(m): return m.level < 3)
			if not upgradeable.is_empty():
				var to_upgrade = upgradeable[_rng.randi() % upgradeable.size()]
				to_upgrade.level += 1
				continue

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
# REWARD CHOICES
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
			continue
		var weight = _rarity_weight(item.rarity)
		for i in range(weight):
			weighted.append(item)
	return weighted


func _rarity_weight(rarity: int) -> int:
	match rarity:
		0: return 27
		1: return 9
		2: return 3
		3: return 1
	return 8


# =========================
# HEALTH
# =========================

func add_health(amount: int):
	var old_health = player_health
	player_health += amount
	emit_signal("health_changed", player_health)

	if player_health != old_health:
		ItemManager.emit_game_event("health_threshold", {
			"new_health": player_health,
			"old_health": old_health,
		})


func remove_health(amount: int):
	var old_health = player_health
	player_health -= amount
	emit_signal("health_changed", player_health)

	if player_health != old_health:
		ItemManager.emit_game_event("health_threshold", {
			"new_health": player_health,
			"old_health": old_health,
		})


func set_health(amount: int):
	var old_health = player_health
	player_health = amount
	emit_signal("health_changed", player_health)

	if player_health != old_health:
		ItemManager.emit_game_event("health_threshold", {
			"new_health": player_health,
			"old_health": old_health,
		})


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


# =========================
# PEG QUOTA GENERATION
# =========================

# Total pegs required across all colors for a given map.
# Quadratic: base + growth*(map-1)^2  (sits around 1.5x per map early on).
func quota_total_for_map(map_number: int) -> int:
	var base = playtest_quota_base if playtest_quota_override else QUOTA_BASE
	return base + QUOTA_GROWTH * (map_number - 1) * (map_number - 1)


# How many colors carry a quota on a given map: 2,3,4,5,6,6,...  (all six by map 5).
func quota_color_count_for_map(map_number: int) -> int:
	return min(6, map_number + 1)


# Generate and store the quotas for the given map. Random colors, random
# weighted split of the total with a per-color floor.
func generate_quotas_for_map(map_number: int) -> void:
	current_map_number = map_number
	var total = quota_total_for_map(map_number)
	var n = quota_color_count_for_map(map_number)

	# Pick which colors get a quota
	var pool = QUOTA_COLORS.duplicate()
	pool.shuffle()
	var chosen = pool.slice(0, n)

	# Random weighted split with a floor so no color is trivially small
	var even = float(total) / float(n)
	var floor_amount = max(1, int(even * QUOTA_FLOOR_FRAC))
	var remaining = total - floor_amount * n
	if remaining < 0:
		remaining = 0
		floor_amount = int(total / n)

	var weights := []
	var wsum := 0.0
	for i in range(n):
		var w = randf()
		weights.append(w)
		wsum += w
	if wsum <= 0.0:
		wsum = 1.0

	var amounts := []
	for i in range(n):
		amounts.append(floor_amount + int(remaining * weights[i] / wsum))

	# Fix rounding remainder so the amounts sum exactly to total
	var diff = total - _sum_array(amounts)
	var idx = 0
	while diff != 0 and n > 0:
		amounts[idx % n] += 1 if diff > 0 else -1
		diff += -1 if diff > 0 else 1
		idx += 1

	peg_quotas = {}
	for i in range(n):
		peg_quotas[chosen[i]] = amounts[i]


func _sum_array(arr: Array) -> int:
	var s := 0
	for v in arr:
		s += v
	return s


# Advance to the next map and generate its quotas.
func advance_to_next_map() -> void:
	generate_quotas_for_map(current_map_number + 1)


# Manually override this map's quotas. Example: set_peg_quotas({"red": 8})
func set_peg_quotas(quotas: Dictionary) -> void:
	peg_quotas = quotas.duplicate()


# Convenience: the colors that have a quota this map, in canonical order.
func get_quota_colors() -> Array:
	var result := []
	for c in QUOTA_COLORS:
		if peg_quotas.has(c):
			result.append(c)
	return result


# Whether the player's earned score pegs currently meet every quota.
func are_quotas_met() -> bool:
	for color_name in peg_quotas.keys():
		var have = ScoreManager.earned_score_pegs.get(color_name, 0)
		if have < peg_quotas[color_name]:
			return false
	return true