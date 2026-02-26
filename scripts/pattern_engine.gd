extends Node

var patterns = []
var triggered_patterns = {}

# =========================
# SETUP
# =========================


func _ready() -> void:
	load_patterns()


func load_patterns():
	patterns.clear()

	var dir = DirAccess.open("res://data/patterns")
	if dir == null:
		push_error("Patterns folder missing")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var pattern : PatternData = load("res://data/patterns/" + file_name)
			patterns.append(pattern)
		file_name = dir.get_next()

	dir.list_dir_end()

	print("Loaded patterns:", patterns.size())


# =========================
# PUBLIC ENTRY POINT
# =========================

func evaluate_board(board_state, rows, columns, changed_row):

#	triggered_patterns.clear()
	var triggered := []

	for r in range(max(0, changed_row - 2), min(rows, changed_row + 3)):
		for c in range(columns):
			for pattern in patterns:

				# Allowed row filter
				if pattern.allowed_rows.size() > 0:
					if r not in pattern.allowed_rows:
						continue

				var result = match_pattern_at(board_state, r, c, pattern, rows, columns)

				if result == null:
					continue

				if pattern.duplicate_type == "":
					if register_pattern(pattern.pattern_name, result):
						triggered.append({
							"name": pattern.pattern_name,
							"positions": result,
						})
				else:
					var dup_sets = duplicate_rule_matches(board_state, pattern, rows, columns)
					if dup_sets != null:
						for positions in dup_sets:
							if register_pattern(pattern.pattern_name, positions):
								triggered.append({
									"name": pattern.pattern_name,
									"positions": positions,
									"keywords": pattern.keywords
								})

	return triggered


# =========================
# MATCHING LOGIC
# =========================

func match_pattern_at(board_state, base_r, base_c, pattern : PatternData, rows, columns):

	# Full row pattern
	if pattern.type == "full_row":

		if base_c != 0:
			return null

		var required_color = pattern.grid[0][0]

		for col in range(columns):
			if board_state[base_r][col] != required_color:
				return null

		return get_row_positions(base_r, columns)

	# Grid pattern
	if pattern.width > columns or pattern.height > rows:
		return null

	var matched_positions := []

	for y in range(pattern.height):
		for x in range(pattern.width):

			var pattern_color = pattern.grid[y][x]

			if pattern_color == 0:
				continue

			var r = base_r + y
			var c = base_c + x

			if r < 0 or r >= rows or c < 0 or c >= columns:
				return null

			if board_state[r][c] != pattern_color:
				return null

			matched_positions.append(Vector2(r, c))

	return matched_positions

# =========================
# DUPLICATE RULES
# =========================

func duplicate_rule_matches(board_state, pattern : PatternData, rows, columns):

	var matched_sets := []

	for r in range(rows):
		for c in range(columns):

			# Allowed row filter
			if pattern.allowed_rows.size() > 0:
				if r not in pattern.allowed_rows:
					continue

			var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
			if result != null:
				matched_sets.append(result)

	if pattern.duplicate_type == "any":
		if matched_sets.size() >= 2:
			return matched_sets
		return null

	if pattern.duplicate_type == "fixed":
		for req in pattern.duplicate_rows:
			var found := false
			for positions in matched_sets:
				if positions[0].x == req:
					found = true
					break
			if not found:
				return null
		return matched_sets

	return null



# =========================
# DUPLICATE PREVENTION
# =========================

func register_pattern(name, positions):
	var key = name + "_" + str(positions)
	
	if key in triggered_patterns:
		return false
	
	triggered_patterns[key] = true
	print("Pattern triggered:", name, "at", positions)
	return true


func get_row_positions(row_index, columns):
	var positions := []
	for c in range(columns):
		positions.append(Vector2(row_index, c))
	return positions


func get_pattern_by_name(name : String) -> PatternData:
	for pattern in patterns:
		if pattern.pattern_name == name:
			return pattern
	return null