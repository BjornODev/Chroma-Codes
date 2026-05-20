extends Node

# =========================
# CONSTANTS
# =========================

const GRID_SIZE := 6
const COLORS := ["red", "yellow", "green", "white", "purple", "orange"]

const ACTIVATED_PANEL_REFILL := 5
const ADJACENT_PANEL_REFILL := 0

const COLOR_VALUES := {
	"red": Color("#E05555"),
	"yellow": Color("#E0C055"),
	"green": Color("#55A855"),
	"white": Color("#DDDDDD"),
	"purple": Color("#8855CC"),
	"orange": Color("#E08040"),
}

const COLOR_TO_PEG_ID := {
	"red": 1,
	"yellow": 2,
	"green": 3,
	"white": 4,
	"purple": 5,
	"orange": 6,
}

# Severity thresholds
const SLIGHT_THRESHOLD := 1.3
const MODERATE_THRESHOLD := 1.7
const SEVERE_THRESHOLD := 2.2

const WEIGHT_SLIGHT_BASE := [70, 25, 5]
const WEIGHT_MODERATE_BASE := [30, 50, 20]
const WEIGHT_SEVERE_BASE := [10, 30, 60]

# =========================
# UNLOCK CONDITION TYPES
# =========================
enum UnlockType {
	COLOR_COUNT,     # activate N of certain colored panels
	PANEL_TYPE,      # activate a specific panel type
	TOTAL_PANELS,    # activate N panels total
}

# =========================
# STATE
# =========================

var run_seed: int = 0
var rng: RandomNumberGenerator

var grid_colors: Array = []
var grid_types: Array = []
var grid_activated: Array = []
var grid_adjacency_unlocked: Array = []  # tracks which panels are reachable

var color_activation_counts := {}
var type_activation_counts := {}
var total_activated := 0
var consecutive_non_board := 0

var boss_triggered := false
var boss_ready := false

var last_panel_world_pos: Vector2 = Vector2.ZERO

# Unlock condition for this map
var unlock_condition: Dictionary = {}
var unlock_condition_progress: Dictionary = {}
var unlock_used := false  # has the seeded unlock fired this map

# "Unlock Any" item keyword state
var unlock_any_active := false


# =========================
# SIGNALS
# =========================

signal panel_activated(row: int, col: int, panel_type: String, color: String)
signal unlock_condition_met
signal map_unlock_triggered


# =========================
# INITIALIZATION
# =========================

func start_run(seed_value: int):
	run_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed
	boss_triggered = false
	boss_ready = false
	unlock_used = false
	unlock_any_active = false
	consecutive_non_board = 0

	for color in COLORS:
		color_activation_counts[color] = 0

	for type in ["Board", "Shop", "Event", "Forge", "Gamble"]:
		type_activation_counts[type] = 0

	total_activated = 0

	_generate_grid()
	_generate_unlock_condition()


# =========================
# GRID GENERATION
# =========================

func _generate_grid():
	grid_colors.clear()
	grid_types.clear()
	grid_activated.clear()
	grid_adjacency_unlocked.clear()

	grid_colors = _generate_latin_square()

	var type_pool = []
	for i in range(18): type_pool.append("Board")
	for i in range(5): type_pool.append("Shop")
	for i in range(5): type_pool.append("Event")
	for i in range(4): type_pool.append("Forge")
	for i in range(4): type_pool.append("Gamble")

	_seeded_shuffle(type_pool)

	var idx := 0
	for r in range(GRID_SIZE):
		var type_row = []
		var activated_row = []
		var adjacency_row = []
		for c in range(GRID_SIZE):
			type_row.append(type_pool[idx])
			activated_row.append(false)
			adjacency_row.append(false)
			idx += 1
		grid_types.append(type_row)
		grid_activated.append(activated_row)
		grid_adjacency_unlocked.append(adjacency_row)


func _generate_latin_square() -> Array:
	var base = []
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			row.append(COLORS[(r + c) % GRID_SIZE])
		base.append(row)

	var color_perm = COLORS.duplicate()
	_seeded_shuffle(color_perm)

	var remapped = []
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			var original_index = COLORS.find(base[r][c])
			row.append(color_perm[original_index])
		remapped.append(row)

	var row_list = []
	for i in range(GRID_SIZE): row_list.append(i)
	_seeded_shuffle(row_list)

	var shuffled = []
	for r in row_list:
		shuffled.append(remapped[r])

	var col_order = []
	for i in range(GRID_SIZE): col_order.append(i)
	_seeded_shuffle(col_order)

	var final = []
	for r in range(GRID_SIZE):
		var row = []
		for c in col_order:
			row.append(shuffled[r][c])
		final.append(row)

	return final


func _seeded_shuffle(arr: Array):
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


# =========================
# UNLOCK CONDITION GENERATION
# =========================

func _generate_unlock_condition():
	unlock_condition.clear()
	unlock_condition_progress.clear()
	unlock_used = false

	var condition_type = rng.randi() % 4

	match condition_type:
		UnlockType.COLOR_COUNT:
			# Pick 1-2 colors and counts
			var num_colors = 1 + rng.randi() % 3
			var chosen_colors = COLORS.duplicate()
			_seeded_shuffle(chosen_colors)
			var requirements = {}
			for i in range(num_colors):
				var count = 1 + rng.randi() % 3
				requirements[chosen_colors[i]] = count
			unlock_condition = {
				"type": UnlockType.COLOR_COUNT,
				"requirements": requirements
			}
			for color in requirements.keys():
				unlock_condition_progress[color] = 0

		UnlockType.PANEL_TYPE:
			var types = ["Board", "Shop", "Event", "Forge", "Gamble"]
			var chosen_type = types[rng.randi() % types.size()]
			var count = 2 + rng.randi() % 3
			unlock_condition = {
				"type": UnlockType.PANEL_TYPE,
				"panel_type": chosen_type,
				"count": count
			}
			unlock_condition_progress["count"] = 0

		UnlockType.TOTAL_PANELS:
			var count = 4 + rng.randi() % 4
			unlock_condition = {
				"type": UnlockType.TOTAL_PANELS,
				"count": count
			}
			unlock_condition_progress["count"] = 0


func get_unlock_condition_text() -> String:
	if unlock_condition.is_empty():
		return ""

	match unlock_condition.get("type"):
		UnlockType.COLOR_COUNT:
			var reqs = unlock_condition["requirements"]
			var parts = []
			for color in reqs.keys():
				var progress = unlock_condition_progress.get(color, 0)
				parts.append("%d/%d %s" % [progress, reqs[color], color.capitalize()])
			return "Unlock: " + " + ".join(parts)

		UnlockType.PANEL_TYPE:
			var progress = unlock_condition_progress.get("count", 0)
			return "Unlock: %d/%d %s panels" % [progress, unlock_condition["count"], unlock_condition["panel_type"]]

		UnlockType.TOTAL_PANELS:
			var progress = unlock_condition_progress.get("count", 0)
			return "Unlock: %d/%d panels total" % [progress, unlock_condition["count"]]

	return ""


# =========================
# PANEL ACTIVATION
# =========================

func is_panel_accessible(row: int, col: int) -> bool:
	if grid_activated[row][col]:
		return false

	# First panel — anything goes
	if total_activated == 0:
		return true

	# Unlock Any active — anything goes for one activation
	if unlock_any_active:
		return true

	# Must be orthogonally adjacent to an activated panel
	return _is_adjacent_to_activated(row, col)


func _is_adjacent_to_activated(row: int, col: int) -> bool:
	var neighbors = [
		Vector2(row - 1, col),
		Vector2(row + 1, col),
		Vector2(row, col - 1),
		Vector2(row, col + 1),
	]
	for n in neighbors:
		if n.x >= 0 and n.x < GRID_SIZE and n.y >= 0 and n.y < GRID_SIZE:
			if grid_activated[int(n.x)][int(n.y)]:
				return true
	return false


func activate_panel(row: int, col: int) -> bool:
	if grid_activated[row][col]:
		return false
	if not is_panel_accessible(row, col):
		return false

	grid_activated[row][col] = true

	var color = grid_colors[row][col]
	var panel_type = grid_types[row][col]

	color_activation_counts[color] += 1
	type_activation_counts[panel_type] += 1
	total_activated += 1

	_refill_pegs_from_panel(row, col)

	# Reset unlock any after use
	if unlock_any_active and total_activated > 1:
		unlock_any_active = false

	_check_boss_trigger()
	_check_unlock_condition(color, panel_type)

	# Emit map event for items
	ItemManager.emit_game_event("panel_activated", {
		"row": row,
		"col": col,
		"panel_type": panel_type,
		"color": color,
		"color_counts": color_activation_counts.duplicate(),
		"type_counts": type_activation_counts.duplicate(),
		"total": total_activated
	})
	ItemManager.process_turn_events()

	emit_signal("panel_activated", row, col, panel_type, color)

	return true


func _check_boss_trigger():
	if boss_triggered:
		return

	# Check all horizontal rows
	for r in range(GRID_SIZE):
		var row_complete = true
		for c in range(GRID_SIZE):
			if not grid_activated[r][c]:
				row_complete = false
				break
		if row_complete:
			boss_triggered = true
			boss_ready = true
			return

	# Check all vertical columns
	for c in range(GRID_SIZE):
		var col_complete = true
		for r in range(GRID_SIZE):
			if not grid_activated[r][c]:
				col_complete = false
				break
		if col_complete:
			boss_triggered = true
			boss_ready = true
			return


# =========================
# UNLOCK CONDITION CHECKING
# =========================

func _check_unlock_condition(activated_color: String, activated_type: String):
	if unlock_used or unlock_condition.is_empty():
		return

	var met := false

	match unlock_condition.get("type"):
		UnlockType.COLOR_COUNT:
			var reqs = unlock_condition["requirements"]
			for color in reqs.keys():
				unlock_condition_progress[color] = color_activation_counts.get(color, 0)
			met = true
			for color in reqs.keys():
				if unlock_condition_progress.get(color, 0) < reqs[color]:
					met = false
					break

		UnlockType.PANEL_TYPE:
			unlock_condition_progress["count"] = type_activation_counts.get(
				unlock_condition["panel_type"], 0
			)
			met = unlock_condition_progress["count"] >= unlock_condition["count"]

		UnlockType.TOTAL_PANELS:
			unlock_condition_progress["count"] = total_activated
			met = total_activated >= unlock_condition["count"]

	if met:
		unlock_used = true
		KeywordEngine.apply_keyword("Heal", 1)



func _trigger_unlock():
	unlock_used = true

	# Find all locked non-adjacent panels
	var locked_panels = []
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			if not grid_activated[r][c] and not _is_adjacent_to_activated(r, c):
				locked_panels.append(Vector2(r, c))

	if locked_panels.is_empty():
		return

	# Pick one randomly using the run seed
	var chosen = locked_panels[rng.randi() % locked_panels.size()]
	grid_adjacency_unlocked[int(chosen.x)][int(chosen.y)] = true

	emit_signal("map_unlock_triggered")
	ItemManager.emit_game_event("map_unlock_triggered", {})
	ItemManager.process_turn_events()


# =========================
# UNLOCK ANY KEYWORD
# =========================

func activate_unlock_any():
	unlock_any_active = true


# =========================
# BOSS MODIFIER LOGIC
# =========================

func get_boss_modifier_type() -> Dictionary:
	if total_activated == 0:
		return {"balanced": true, "color": "", "severity": "slight"}

	var average = float(total_activated) / float(COLORS.size())
	var max_count = 0
	for color in COLORS:
		if color_activation_counts[color] > max_count:
			max_count = color_activation_counts[color]

	var top_colors = []
	for color in COLORS:
		if color_activation_counts[color] == max_count:
			top_colors.append(color)

	if top_colors.is_empty():
		return {"balanced": true, "color": "", "severity": "balanced"}

	var ratio = float(max_count) / max(average, 0.001)

	if ratio < SLIGHT_THRESHOLD:
		return {"balanced": true, "color": "", "severity": "balanced"}

	var chosen_color = top_colors[rng.randi() % top_colors.size()]
	var severity = _get_severity(ratio)

	return {
		"balanced": false,
		"color": chosen_color,
		"severity": severity
	}


func _get_severity(ratio: float) -> String:
	var weights: Array
	if ratio >= SEVERE_THRESHOLD:
		weights = WEIGHT_SEVERE_BASE
	elif ratio >= MODERATE_THRESHOLD:
		weights = WEIGHT_MODERATE_BASE
	else:
		weights = WEIGHT_SLIGHT_BASE

	var total = weights[0] + weights[1] + weights[2]
	var roll = rng.randi() % total

	if roll < weights[0]: return "slight"
	elif roll < weights[0] + weights[1]: return "moderate"
	else: return "severe"


# =========================
# UTILITY
# =========================

func get_panel_color(row: int, col: int) -> Color:
	if grid_colors.is_empty() or row >= grid_colors.size():
		return Color.WHITE
	if col >= grid_colors[row].size():
		return Color.WHITE
	return COLOR_VALUES[grid_colors[row][col]]


func get_panel_type(row: int, col: int) -> String:
	if grid_types.is_empty() or row >= grid_types.size():
		return "Board"
	if col >= grid_types[row].size():
		return "Board"
	return grid_types[row][col]


func get_color_name(row: int, col: int) -> String:
	if grid_colors.is_empty() or row >= grid_colors.size():
		return "red"
	if col >= grid_colors[row].size():
		return "red"
	return grid_colors[row][col]


func is_panel_locked(row: int, col: int) -> bool:
	return grid_activated[row][col]


func reset_map():
	boss_triggered = false
	boss_ready = false
	unlock_used = false
	unlock_any_active = false
	consecutive_non_board = 0
	for color in COLORS:
		color_activation_counts[color] = 0
	for type in type_activation_counts.keys():
		type_activation_counts[type] = 0
	total_activated = 0
	grid_activated.clear()
	grid_adjacency_unlocked.clear()
	for r in range(GRID_SIZE):
		var row = []
		var adj_row = []
		for c in range(GRID_SIZE):
			row.append(false)
			adj_row.append(false)
		grid_activated.append(row)
		grid_adjacency_unlocked.append(adj_row)
	_generate_unlock_condition()


func _refill_pegs_from_panel(row: int, col: int):
	var panel_type = grid_types[row][col]

	# Calculate refill amounts with reduction
	var activated_amount = max(1, ACTIVATED_PANEL_REFILL - consecutive_non_board)
	var adjacent_amount = 0

	var activated_color = grid_colors[row][col]
	var activated_peg_id = COLOR_TO_PEG_ID.get(activated_color, 0)
	if activated_peg_id > 0:
		PegInventoryManager.add_pegs_to_color(activated_peg_id, activated_amount)

	var neighbors = [
		Vector2(row - 1, col),
		Vector2(row + 1, col),
		Vector2(row, col - 1),
		Vector2(row, col + 1),
	]

	for n in neighbors:
		var nr = int(n.x)
		var nc = int(n.y)
		if nr < 0 or nr >= GRID_SIZE or nc < 0 or nc >= GRID_SIZE:
			continue
		var adj_color = grid_colors[nr][nc]
		var adj_peg_id = COLOR_TO_PEG_ID.get(adj_color, 0)
		if adj_peg_id > 0:
			PegInventoryManager.add_pegs_to_color(adj_peg_id, adjacent_amount)

	# Update counter based on panel type
	if panel_type == "Board":
		consecutive_non_board = 0
	else:
		consecutive_non_board += 1