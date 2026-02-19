extends Node2D

@export var rows := 8
@export var columns := 4
@export var spacing := 45

var secret_code = []

var slot_size = 35
var slot_scene
var feedback_scene
var peg_manager_reference

func _ready() -> void:
	slot_scene = preload("res://scenes/SnapZone.tscn")
	feedback_scene = preload("res://scenes/Feedback_Grid.tscn")
	peg_manager_reference = $"../PegManager"
	randomize()
	build_board()
	generate_code()

func generate_code():
	secret_code.clear()
	
	for i in range(columns):
		secret_code.append(randi_range(1, 6))


func submit_guess():
	var guess = []
	
	for child in get_children():
		if child is SnapZone:
			if child.row == peg_manager_reference.cur_row:
				if child.peg_in_slot == null:
					print("Invalid Guess")
					return
		
				guess.append(child.peg_in_slot.peg_id)
	
	print("Guess:", guess)
	var result = evaluate_guess(guess)
	
	for child in get_children():
		if child is Feedback_Grid:
			if child.row == peg_manager_reference.cur_row:
				print("Showing results for row", peg_manager_reference.cur_row)
				child.show_results(result[0], result[1])
	print("Black: ", result[0], "White: ", result[1])
	
	peg_manager_reference.cur_row += 1
	if peg_manager_reference.cur_row >= rows:
		print(secret_code)

func _on_main_pressed() -> void:
	submit_guess()


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


func build_board():
	var camera = $"../Camera2D"
	var camera_center = camera.global_position
	var screen_size = get_viewport().get_visible_rect().size
	var bottom_margin = -350
	var camera_bottom = camera.position.y + screen_size.y / 2.0
	
	var total_width = columns * slot_size + (columns - 1) * spacing
	var total_height = rows * slot_size + (rows - 1) * spacing
	
	var start_x = camera_center.x - total_width / 2.0 + slot_size / 2.0
	var start_y = camera_bottom - total_height -bottom_margin + slot_size / 2.0 
	
	for r in range(rows):
		for c in range(columns):
			var slot = slot_scene.instantiate()
			slot.row = rows - r
			slot.column = columns - c
			add_child(slot)
			
			var x = start_x + c * (slot_size + spacing)
			var y = start_y + r * (slot_size + spacing)
			
			slot.position = Vector2(x, y)
		var feedback_grid = feedback_scene.instantiate()
		feedback_grid.row = rows - r
		add_child(feedback_grid)
		
		var y = start_y + r * (slot_size + spacing) - 24
		
		feedback_grid.position = Vector2(start_x + total_width + 10, y)
