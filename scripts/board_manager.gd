extends Node2D

@export var rows := 8
@export var columns := 4
@export var spacing := 45
var radar_blip_scene = preload("res://scenes/RadarBlip.tscn")

var slot_size := 35
var slot_scene
var feedback_scene
var peg_manager_reference

var secret_code = []
var board_state = []        # 2D matrix of peg_ids
var triggered_patterns = {} # Prevent duplicate triggers
var patterns = []
var slot_lookup = {}

# -------------------------
# SETUP
# -------------------------

func _ready():
	slot_scene = preload("res://scenes/SnapZone.tscn")
	feedback_scene = preload("res://scenes/Feedback_Grid.tscn")
	peg_manager_reference = $"../PegManager"
	load_patterns_from_json()
	
	build_board()
	build_empty_board()
	generate_code()


#func spawn_pattern_markers(positions):
#	for pos in positions:
#		var slot = slot_lookup[pos]
#		if slot:
#			var marker = radar_blip_scene.instantiate()
#			add_child(marker)
#			marker.position = slot.position


func spawn_pattern_markers(positions):
	for pos in positions:
		var inverted_row = rows - 1 - int(pos.x)
		var lookup_key = Vector2(inverted_row, pos.y)

		var slot = slot_lookup.get(lookup_key)
		if slot:
			var marker = radar_blip_scene.instantiate()
			add_child(marker)
			marker.position = slot.position


func build_empty_board():
	board_state.clear()
	for r in range(rows):
		board_state.append([])
		for c in range(columns):
			board_state[r].append(null)


func generate_code():
	secret_code.clear()
	for i in range(columns):
		secret_code.append(randi_range(1, 6))


# -------------------------
# SUBMIT GUESS
# -------------------------

func submit_guess():
	var guess = []
	var row_index = peg_manager_reference.cur_row
	
	# Build guess from current row
	for child in get_children():
		if child is SnapZone and child.row == row_index:
			if child.peg_in_slot == null:
				print("Invalid Guess")
				return
			
			guess.append(child.peg_in_slot.peg_id)
	
	print("Guess:", guess)
	
	# Store guess into board_state
	for c in range(columns):
		board_state[row_index][c] = guess[c]
	
	var result = evaluate_guess(guess)
	
	# Show feedback
	for child in get_children():
		if child is Feedback_Grid and child.row == row_index:
			child.show_results(result[0], result[1])
	
	check_patterns_near_row(row_index)
	
	peg_manager_reference.cur_row += 1


# -------------------------
# EVALUATE GUESS
# -------------------------

func evaluate_guess(guess):
	var black := 0
	var white := 0
	
	var secret_copy = secret_code.duplicate()
	var guess_copy = guess.duplicate()
	
	for i in range(columns):
		if guess_copy[i] == secret_copy[i]:
			black += 1
			guess_copy[i] = -1
			secret_copy[i] = -1
	
	for g in guess_copy:
		if g in secret_copy and g != -1:
			white += 1
			secret_copy[secret_copy.find(g)] = -1
	
	return [black, white]


# -------------------------
# PATTERN ENGINE
# -------------------------

func check_patterns_near_row(row_index):
	# Only scan around newly modified row for efficiency
	for r in range(max(0, row_index - 2), min(rows, row_index + 3)):
		for c in range(columns):
			for pattern in patterns:
				var result = match_pattern_at(r, c, pattern)
				
				if result != null:
					register_pattern(pattern.name, Vector2(r,c))
					spawn_pattern_markers(result)


func match_pattern_at(base_r, base_c, pattern):
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
	
	return true


func register_pattern(name, pos):
	var key = name + "_" + str(pos)
	if key in triggered_patterns:
		return
	
	triggered_patterns[key] = true
	print("Pattern triggered:", name, "at", pos)


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
			"cells": []
		}
		
		for cell in pattern_data.cells:
			pattern["cells"].append({
				"offset": Vector2(cell.x, cell.y),
				"color": cell.color
			})
		
		patterns.append(pattern)
	
	print("Loaded patterns:", patterns.size())


# -------------------------
# BOARD CREATION
# -------------------------

func build_board():
	var camera = $"../Camera2D"
	var camera_center = camera.get_screen_center_position()
	
	var bottom_margin = 150
	var screen_size = get_viewport().get_visible_rect().size
	
	var total_width = columns * slot_size + (columns - 1) * spacing
	var total_height = rows * slot_size + (rows - 1) * spacing
	
	var start_x = camera_center.x - total_width / 2.0 + slot_size / 2.0
	var start_y = camera_center.y - total_height / 2.0 + slot_size / 2.0
	
	for r in range(rows):
		for c in range(columns):
			var slot = slot_scene.instantiate()
			slot.row = rows - r - 1
			slot.column = columns - c - 1
			add_child(slot)
			
			var x = start_x + c * (slot_size + spacing)
			var y = start_y + r * (slot_size + spacing)
			
			slot.position = Vector2(x, y)
			slot_lookup[Vector2(r, c)] = slot
		
		var feedback_grid = feedback_scene.instantiate()
		feedback_grid.row = rows - r - 1
		add_child(feedback_grid)
		
		var y = start_y + r * (slot_size + spacing) - 24
		feedback_grid.position = Vector2(start_x + total_width + 10, y)

func _on_pressed() -> void:
	submit_guess()
