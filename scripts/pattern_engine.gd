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


#func evaluate_board(board_state, rows, columns, changed_row):
#
#	var triggered := []
#
#	for pattern in patterns:
#
#		var used_positions := {}
#
#		for r in range(max(0, changed_row - 2), min(rows, changed_row + 3)):
#			for c in range(columns):
#
#				if pattern.allowed_rows.size() > 0 and r not in pattern.allowed_rows:
#					continue
#
#				var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
#				if result == null:
#					continue
#
#				# OVERLAP CHECK
#				var overlaps := false
#				for pos in result:
#					var key = str(pos.x) + "_" + str(pos.y)
#					if key in used_positions:
#						overlaps = true
#						break
#
#				if overlaps:
#					continue
#
#				# RESERVE PEGS FOR THIS PATTERN INSTANCE
#				for pos in result:
#					var key = str(pos.x) + "_" + str(pos.y)
#					used_positions[key] = true
#
#				if pattern.duplicate_type == "":
#					if register_pattern(pattern.pattern_name, result):
#						triggered.append({
#							"name": pattern.pattern_name,
#							"positions": result,
#						})
#				else:
#					var all_matches := []
#				
#					# Step 1 — Collect all non-overlapping matches
#					for r2 in range(rows):
#						for c2 in range(columns):
#				
#							if pattern.allowed_rows.size() > 0 and r2 not in pattern.allowed_rows:
#								continue
#				
#							var res = match_pattern_at(board_state, r2, c2, pattern, rows, columns)
#							if res == null:
#								continue
#				
#							# overlap check against used_positions
#							# overlap check against used_positions
#							var dup_overlaps := false
#							for pos in res:
#								var key = str(pos.x) + "_" + str(pos.y)
#								if key in used_positions:
#									dup_overlaps = true
#									break
#							
#							if dup_overlaps:
#								continue
#				
#							all_matches.append(res)
#				
#					# Step 2 — Apply duplicate rules
#				
#					if pattern.duplicate_type == "any":
#						if all_matches.size() < 2:
#							continue
#				
#					if pattern.duplicate_type == "fixed":
#						var required_rows = pattern.duplicate_rows
#						var rows_found := []
#				
#						for match in all_matches:
#							var row_of_match = match[0].x
#							if row_of_match in required_rows:
#								rows_found.append(row_of_match)
#				
#						if rows_found.size() != required_rows.size():
#							continue
#				
#					# Step 3 — Accept and reserve all matches
#					for match in all_matches:
#				
#						for pos in match:
#							var key = str(pos.x) + "_" + str(pos.y)
#							used_positions[key] = true
#				
#						if register_pattern(pattern.pattern_name, match):
#							triggered.append({
#								"name": pattern.pattern_name,
#								"positions": match,
#							})
#	return triggered


func evaluate_board(board_state, rows, columns, changed_row):

	var triggered := []

	for pattern in patterns:

		var used_positions := {}

		# =====================
		# NORMAL PATTERNS
		# =====================
		if pattern.duplicate_type == "":

			for r in range(max(0, changed_row - 2), min(rows, changed_row + 3)):
				for c in range(columns):

					if pattern.allowed_rows.size() > 0 and r not in pattern.allowed_rows:
						continue

					var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
					if result == null:
						continue

					var overlaps := false
					for pos in result:
						var key = str(pos.x) + "_" + str(pos.y)
						if key in used_positions:
							overlaps = true
							break

					if overlaps:
						continue

					for pos in result:
						var key = str(pos.x) + "_" + str(pos.y)
						used_positions[key] = true

					if register_pattern(pattern.pattern_name, result):
						triggered.append({
							"name": pattern.pattern_name,
							"positions": result,
						})

		# =====================
		# DUPLICATE PATTERNS
		# =====================
		else:

			var all_matches := []

			# Step 1 — Collect ALL matches across board
			for r in range(rows):
				for c in range(columns):

					if pattern.allowed_rows.size() > 0 and r not in pattern.allowed_rows:
						continue

					var res = match_pattern_at(board_state, r, c, pattern, rows, columns)
					if res == null:
						continue

					all_matches.append(res)

			# Step 2 — Apply duplicate rules

			if pattern.duplicate_type == "any":
				if all_matches.size() < 2:
					continue

			if pattern.duplicate_type == "fixed":
				var required_rows = pattern.duplicate_rows
				var rows_found := []

				for match in all_matches:
					var row_of_match = match[0].x
					if row_of_match in required_rows:
						rows_found.append(row_of_match)

				if rows_found.size() != required_rows.size():
					continue

			# Step 3 — Enforce non-overlap between duplicate instances
			for match in all_matches:

				var overlaps := false
				for pos in match:
					var key = str(pos.x) + "_" + str(pos.y)
					if key in used_positions:
						overlaps = true
						break

				if overlaps:
					continue

				for pos in match:
					var key = str(pos.x) + "_" + str(pos.y)
					used_positions[key] = true

				if register_pattern(pattern.pattern_name, match):
					triggered.append({
						"name": pattern.pattern_name,
						"positions": match,
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

#func duplicate_rule_matches(board_state, pattern : PatternData, rows, columns):
#
#	var matched_sets := []
#
#	for r in range(rows):
#		for c in range(columns):
#
#			# Allowed row filter
#			if pattern.allowed_rows.size() > 0:
#				if r not in pattern.allowed_rows:
#					continue
#
#			var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
#			if result != null:
#				matched_sets.append(result)
#
#	if pattern.duplicate_type == "any":
#		if matched_sets.size() >= 2:
#			return matched_sets
#		return null
#
#	if pattern.duplicate_type == "fixed":
#		for req in pattern.duplicate_rows:
#			var found := false
#			for positions in matched_sets:
#				if positions[0].x == req:
#					found = true
#					break
#			if not found:
#				return null
#		return matched_sets
#
#	return null


func duplicate_rule_matches(board_state, pattern : PatternData, rows, columns):

	var matched_sets := []

	# Step 1 — Collect ALL matches
	for r in range(rows):
		for c in range(columns):

			if pattern.allowed_rows.size() > 0:
				if r not in pattern.allowed_rows:
					continue

			var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
			if result != null:
				matched_sets.append(result)

	# Step 2 — Need at least 2 total matches
	if matched_sets.size() < 2:
		return null

	# Step 3 — Build non-overlapping set
	var selected_sets := []

	for candidate in matched_sets:

		var overlaps := false

		for chosen in selected_sets:
			if sets_overlap(candidate, chosen):
				overlaps = true
				break

		if not overlaps:
			selected_sets.append(candidate)

	# Step 4 — Apply duplicate rule
	if pattern.duplicate_type == "any":
		if selected_sets.size() >= 2:
			return selected_sets
		return null

	if pattern.duplicate_type == "fixed":
		for req in pattern.duplicate_rows:
			var found := false
			for positions in selected_sets:
				if positions[0].x == req:
					found = true
					break
			if not found:
				return null
		return selected_sets

	return null


func sets_overlap(a, b):
	for pos_a in a:
		for pos_b in b:
			if pos_a == pos_b:
				return true
	return false



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