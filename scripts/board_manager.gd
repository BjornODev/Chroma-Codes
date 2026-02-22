extends Node2D

@export var columns := 4
@export var spacing := 45
@export var slot_size := 35

@export var soft_row_limit := 6
@export var damage_per_row := 1
@export var player_health := 5

var slot_scene
var feedback_scene
var radar_blip_scene = preload("res://scenes/RadarBlip.tscn")

var peg_manager_reference

var secret_code = []
var board_state = []
var slot_lookup = {}

var rows_generated := 0

@onready var pattern_engine = $"../PatternEngine"
@onready var item_system = $"../ItemManager"


# =========================
# SETUP
# =========================

func _ready():
	slot_scene = preload("res://scenes/SnapZone.tscn")
	feedback_scene = preload("res://scenes/Feedback_Grid.tscn")
	peg_manager_reference = $"../PegManager"

	generate_code()

	# Create safe rows + one danger row
	for i in range(soft_row_limit):
		add_row()


# =========================
# ROW CREATION
# =========================

func add_row():
	var r = rows_generated

	# Grow board_state
	board_state.append([])
	for c in range(columns):
		board_state[r].append(null)

	var camera = $"../Camera2D"
	var camera_center = camera.get_screen_center_position()

	var total_width = columns * slot_size + (columns - 1) * spacing
	var start_x = camera_center.x - total_width / 2.0 + slot_size / 2.0

	# IMPORTANT: grow upward, not downward
	var base_y = camera_center.y + 200
	var y = base_y - r * (slot_size + spacing)

	# Create slots
	for c in range(columns):
		var slot = slot_scene.instantiate()
		slot.row = r
		slot.column = c
		add_child(slot)

		var x = start_x + c * (slot_size + spacing)
		slot.position = Vector2(x, y)

		slot_lookup[Vector2(r, c)] = slot

	# Feedback grid
	var feedback_grid = feedback_scene.instantiate()
	feedback_grid.row = r
	add_child(feedback_grid)
	feedback_grid.position = Vector2(start_x + total_width + 10, y - 24)

	# Danger styling
	if r >= soft_row_limit:
		for child in get_children():
			if (child is SnapZone or child is Feedback_Grid) and child.row == r:
				apply_danger_visual(child)

	rows_generated += 1


func tween_last_row():
	var r = rows_generated - 1
	var camera = $"../Camera2D"
	var screen_height = get_viewport().get_visible_rect().size.y
	
	# World position of top of screen
	var world_top = camera.global_position.y - screen_height / 2.0
	
	for child in get_children():
		if (child is SnapZone or child is Feedback_Grid) and child.row == r:
			var original_pos = child.global_position
			
			# Start above visible screen
			child.global_position.y = world_top - 100
			
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_OUT)
			
			tween.tween_property(child, "global_position", original_pos, 0.6)


func apply_danger_visual(node):
	node.modulate = Color(1.0, 0.5, 0.5, 0.9)

	var glow_mat = CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	node.material = glow_mat


# =========================
# SUBMIT GUESS
# =========================

func submit_guess():
	var guess = []
	var row_index = peg_manager_reference.cur_row

	# Validate row
	for child in get_children():
		if child is SnapZone and child.row == row_index:
			if child.peg_in_slot == null:
				print("Invalid Guess")
				return
			guess.append(child.peg_in_slot.peg_id)

	print("Guess:", guess)

	# Save guess
	for c in range(columns):
		board_state[row_index][c] = guess[c]

	var result = evaluate_guess(guess)

	# Show feedback
	for child in get_children():
		if child is Feedback_Grid and child.row == row_index:
			child.show_results(result[0], result[1])

	# Emit row submitted event
	item_system.emit_game_event("row_submitted", {
		"row": row_index,
		"guess": guess,
		"result": result
	})

	# Pattern detection
	var triggered = pattern_engine.evaluate_board(
		board_state,
		rows_generated,
		columns,
		row_index
	)

	for p in triggered:
		spawn_pattern_markers(p.positions)

		item_system.emit_game_event("pattern_triggered", {
			"pattern_name": p.name,
			"positions": p.positions
		})

	# Apply soft limit damage
	if row_index >= soft_row_limit:
		apply_damage()

	peg_manager_reference.cur_row += 1

	# Add new row when reaching last visible row
	if peg_manager_reference.cur_row >= rows_generated - 1:
		add_row()
		tween_last_row()

	item_system.process_turn_events()


# =========================
# DAMAGE SYSTEM
# =========================

func apply_damage():
	player_health -= damage_per_row
	print("Health:", player_health)

	item_system.emit_game_event("health_lost", {
		"amount": damage_per_row,
		"health": player_health
	})

	if player_health <= 0:
		print("Game Over")


# =========================
# GUESS EVALUATION
# =========================

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


# =========================
# VISUALS
# =========================

func spawn_pattern_markers(positions):
	for pos in positions:
		var slot = slot_lookup.get(pos)
		if slot:
			var marker = radar_blip_scene.instantiate()
			add_child(marker)
			marker.position = slot.position


# =========================
# SECRET CODE
# =========================

func generate_code():
	secret_code.clear()
	for i in range(columns):
		secret_code.append(randi_range(1, 6))


func _on_pressed() -> void:
	submit_guess()