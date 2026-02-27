#extends GridContainer
#
#
#@export var rows := 9
#@export var v_columns := 4
#@export var slot_scene: PackedScene
#@export var feedback_scene: PackedScene
#
#var active_row := 0
#var secret_code = []
#var color_count := 6
#
#func _ready():
#	randomize()
#	generate_code()
#	build_board()
#
#func generate_code():
#	secret_code.clear()
#	
#	for i in range(v_columns):
#		secret_code.append(randi() % color_count)
#		
##	print("Secret: ", secret_code)
#
#func build_board():
#	columns = v_columns + 1
#
#	for r in rows:
#		for c in v_columns:
#			var slot = slot_scene.instantiate()
#			slot.row = rows - 1 - r
#			slot.column = c
#			add_child(slot)
#		var grid = feedback_scene.instantiate()
#		grid.row = rows - 1 - r
#		add_child(grid)
#		grid.background_resize(v_columns)
#
#func _on_pressed() -> void:
#	submit_guess()
#	
#
#func submit_guess():
#	var guess = []
#	
#	for child in get_children():
#		if child is Slot:
#			if child.row == active_row:
#				if child.color_id == -1:
#					print("Invalid Guess")
#					return
#		
#				guess.append(child.color_id)
#	
#	print("Guess:", guess)
#	var result = evaluate_guess(guess)
#	
#	for child in get_children():
#		if child is Feedback_Grid:
#			if child.row == active_row:
#				print("Showing results for row", active_row)
#				child.show_results(result[0], result[1])
#	
#	print("Black: ", result[0], "White: ", result[1])
#	
#	active_row += 1
#	if active_row >= rows:
#		print(secret_code)
#
#func evaluate_guess(guess):
#	var black := 0
#	var white := 0
#	
#	var secret_copy = secret_code.duplicate()
#	var guess_copy = guess.duplicate()
#	
#	for i in range(v_columns):
#		if guess_copy[i] == secret_copy[i]:
#			black += 1
#			guess_copy[i] = -1
#			secret_copy[i] = -1
#	
#	for g in guess_copy:
#		if g in secret_copy and g != -1:
#				white += 1
#				secret_copy[secret_copy.find(g)] = -1
#	return [black, white]