extends Node

# =========================
# CONSTANTS
# =========================

const GRID_SIZE := 6
const COLORS := ["red", "yellow", "green", "white", "purple", "orange"]

const COLOR_VALUES := {
	"red": Color("#E05555"),
	"yellow": Color("#E0C055"),
	"green": Color("#55A855"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8855CC"),
	"orange": Color("#E08040"),
}

const PANEL_TYPES := ["Board", "Board", "Board", "Shop", "Shop", "Shop", "Shop", "Shop", "Event", "Event", "Event", "Event", "Event", "Forge", "Forge", "Forge", "Forge", "Gamble", "Gamble", "Gamble", "Gamble"]

# Severity thresholds — ratio of most_visited to average
# -----------------------------------------------
const SLIGHT_THRESHOLD := 1.3
const MODERATE_THRESHOLD := 1.7
const SEVERE_THRESHOLD := 2.2
# -----------------------------------------------

# Weights for severity levels (slight, moderate, severe)
# Higher chaos = more weight on severe
# -----------------------------------------------
const WEIGHT_SLIGHT_BASE := [70, 25, 5]
const WEIGHT_MODERATE_BASE := [30, 50, 20]
const WEIGHT_SEVERE_BASE := [10, 30, 60]
# -----------------------------------------------

var run_seed: int = 0
var rng: RandomNumberGenerator

# grid_colors[row][col] = color name string
var grid_colors: Array = []
# grid_types[row][col] = panel type string
var grid_types: Array = []
# grid_activated[row][col] = bool
var grid_activated: Array = []

# How many of each color have been activated
var color_activation_counts := {}
# Track if boss has been triggered this run
var boss_triggered := false
var boss_ready := false

var last_panel_world_pos: Vector2 = Vector2.ZERO


# =========================
# INITIALIZATION
# =========================

func start_run(seed_value: int):
	run_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed
	boss_triggered = false
	boss_ready = false

	for color in COLORS:
		color_activation_counts[color] = 0

	_generate_grid()


func _generate_grid():
	grid_colors.clear()
	grid_types.clear()
	grid_activated.clear()

	# Generate a latin square for colors using the seeded rng
	grid_colors = _generate_latin_square()

	# Generate panel types randomly across all 36 cells
	var type_pool = []
	# 18 Boards, 5 Shop, 5 Event, 4 Forge, 4 Gamble
	for i in range(18):
		type_pool.append("Board")
	for i in range(5):
		type_pool.append("Shop")
	for i in range(5):
		type_pool.append("Event")
	for i in range(4):
		type_pool.append("Forge")
	for i in range(4):
		type_pool.append("Gamble")

	_seeded_shuffle(type_pool)

	var idx := 0
	for r in range(GRID_SIZE):
		var type_row = []
		var activated_row = []
		for c in range(GRID_SIZE):
			type_row.append(type_pool[idx])
			activated_row.append(false)
			idx += 1
		grid_types.append(type_row)
		grid_activated.append(activated_row)


func _generate_latin_square() -> Array:
	# Start with a base latin square then shuffle rows and columns
	var base = []
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			row.append(COLORS[(r + c) % GRID_SIZE])
		base.append(row)

	# Shuffle color assignment
	var color_perm = COLORS.duplicate()
	_seeded_shuffle(color_perm)

	# Remap colors
	var remapped = []
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			var original_color = base[r][c]
			var original_index = COLORS.find(original_color)
			row.append(color_perm[original_index])
		remapped.append(row)

	# Shuffle rows
	var row_order = range(GRID_SIZE)
	var row_list = []
	for i in row_order:
		row_list.append(i)
	_seeded_shuffle(row_list)

	var shuffled = []
	for r in row_list:
		shuffled.append(remapped[r])

	# Shuffle columns
	var col_order = []
	for i in range(GRID_SIZE):
		col_order.append(i)
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
# PANEL ACTIVATION
# =========================

func activate_panel(row: int, col: int) -> bool:
	if grid_activated[row][col]:
		return false

	grid_activated[row][col] = true

	var color = grid_colors[row][col]
	color_activation_counts[color] += 1

	_check_boss_trigger()

	return true


func _check_boss_trigger():
	if boss_triggered:
		return

#	for color in COLORS:
#		if color_activation_counts[color] < 1:
#			return

	var rows = grid_activated.size()
	var cols = grid_activated[0].size()

	# Check Horizontally (Rows)
	for r in range(rows):
		if _row_is_all_true(grid_activated[r]):
			boss_triggered = true
			boss_ready = true

	# Check Vertically (Columns)
	for c in range(cols):
		if _col_is_all_true(grid_activated, c, rows):
			boss_triggered = true
			boss_ready = true



# Helper for horizontal
func _row_is_all_true(row: Array) -> bool:
	return row.all(func(cell): return cell == true)


# Helper for vertical
func _col_is_all_true(board: Array, col_idx: int, rows: int) -> bool:
	for r in range(rows):
		if not board[r][col_idx]:
			return false
	return true


func is_panel_locked(row: int, col: int) -> bool:
	return grid_activated[row][col]


# =========================
# BOSS MODIFIER LOGIC
# =========================

func get_boss_modifier_type() -> Dictionary:
	var total_activated = 0
	for color in COLORS:
		total_activated += color_activation_counts[color]

	if total_activated == 0:
		return {"balanced": true, "color": "", "severity": "slight"}

	var average = float(total_activated) / float(COLORS.size())

	# Find most visited color(s)
	var max_count = 0
	for color in COLORS:
		if color_activation_counts[color] > max_count:
			max_count = color_activation_counts[color]

	var top_colors = []
	for color in COLORS:
		if color_activation_counts[color] == max_count:
			top_colors.append(color)

	# Check if balanced (no color significantly above average)
	var ratio = float(max_count) / max(average, 0.001)

	if ratio < SLIGHT_THRESHOLD:
		return {"balanced": true, "color": "", "severity": "balanced"}

	# Unbalanced — pick random top color if tied
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

	if roll < weights[0]:
		return "slight"
	elif roll < weights[0] + weights[1]:
		return "moderate"
	else:
		return "severe"


# =========================
# UTILITY
# =========================

func get_panel_color(row: int, col: int) -> Color:
	return COLOR_VALUES[grid_colors[row][col]]


func get_panel_type(row: int, col: int) -> String:
	return grid_types[row][col]


func get_color_name(row: int, col: int) -> String:
	return grid_colors[row][col]


func reset_map():
	boss_triggered = false
	boss_ready = false
	for color in COLORS:
		color_activation_counts[color] = 0
	grid_activated.clear()
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			row.append(false)
		grid_activated.append(row)
