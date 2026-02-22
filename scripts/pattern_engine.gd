extends Node

var patterns = []
var triggered_patterns = {}

# =========================
# SETUP
# =========================

func _ready():
	load_patterns_from_json()


func load_patterns_from_json():
	var file = FileAccess.open("res://data/patterns.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load patterns.json")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		push_error("JSON Parse Error: " + json.get_error_message())
		return
	
	var data = json.data
	
	patterns.clear()
	
	for pattern_data in data:
		var pattern = {
			"name": pattern_data.name,
			"cells": [],
			"allowed_rows": pattern_data.get("allowed_rows", null),
			"duplicate_rule": pattern_data.get("duplicate_rule", null)
		}
		
		for cell in pattern_data.cells:
			pattern["cells"].append({
				"offset": Vector2(cell.x, cell.y),
				"color": cell.color
			})
		
		patterns.append(pattern)
	
	print("Loaded patterns:", patterns.size())


# =========================
# PUBLIC ENTRY POINT
# =========================

func evaluate_board(board_state, rows, columns, changed_row):
	var triggered = []
	
	for r in range(max(0, changed_row - 2), min(rows, changed_row + 3)):
		for c in range(columns):
			for pattern in patterns:
				
				var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
				
				if result == null:
					continue
				
				# Handle duplicate rules
				if pattern.duplicate_rule != null:
					var dup_sets = duplicate_rule_matches(board_state, pattern, rows, columns)
					
					if dup_sets != null:
						for positions in dup_sets:
							if register_pattern(pattern.name, positions):
								triggered.append({
									"name": pattern.name,
									"positions": positions
								})
				else:
					if register_pattern(pattern.name, result):
						triggered.append({
							"name": pattern.name,
							"positions": result
						})
	
	return triggered


# =========================
# MATCHING LOGIC
# =========================

func match_pattern_at(board_state, base_r, base_c, pattern, rows, columns):
	var matched_positions = []
	
	for cell in pattern.cells:
		var r = base_r + int(cell.offset.y)
		var c = base_c + int(cell.offset.x)
		
		if r < 0 or r >= rows or c < 0 or c >= columns:
			return null
		
		if board_state[r][c] != cell.color:
			return null
		
		matched_positions.append(Vector2(r, c))
	
	return matched_positions


# =========================
# DUPLICATE RULES
# =========================

func duplicate_rule_matches(board_state, pattern, rows, columns):
	var rule = pattern.duplicate_rule
	if rule == null:
		return null
	
	var rule_type = rule.get("type", "")
	
	# ANY: pattern must appear in at least 2 rows
	if rule_type == "any":
		var matched_sets = []
		
		for r in range(rows):
			for c in range(columns):
				var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
				if result != null:
					matched_sets.append(result)
		
		if matched_sets.size() >= 2:
			return matched_sets
		else:
			return null
	
	# FIXED: pattern must appear in specific rows
	if rule_type == "fixed":
		var required_rows = rule.get("rows", [])
		var matched_sets = []
		
		for r in required_rows:
			var found = false
			
			for c in range(columns):
				var result = match_pattern_at(board_state, r, c, pattern, rows, columns)
				if result != null:
					matched_sets.append(result)
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