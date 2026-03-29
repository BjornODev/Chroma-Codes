extends Node2D

@export var columns := 4
@export var spacing := 45
@export var slot_size := 35

@export var soft_row_limit := 5
@export var damage_per_row := 1
@export var player_health := 5

var in_game = true

@export var visible_row_window := 6
@onready var damage_overlay = $DamageOverlay
@onready var bg = $"../BackgroundLayer/ColorRect"
@onready var fade_rect = $CanvasLayer/FadeOut

var slot_scene
var feedback_scene
var radar_blip_scene = preload("res://scenes/RadarBlip.tscn")

var peg_manager_reference
@onready var popup_manager = $"../PopUpText"
@onready var health_text = $"../Health Text"

var secret_code = []
var board_state = []
var slot_lookup = {}
var obscurities := 0

var rows_generated := 0
var scroll_offset := 0.0

@onready var pattern_engine = PatternEngine
@onready var item_system = ItemManager


# =========================
# SETUP
# =========================

func _ready():
	if !RunProgressionManager.run_active:
		RunProgressionManager.start_new_run()
	ChaosManager.set_context(self, peg_manager_reference, popup_manager)
	PopUpText.toggle_mult(true)
	slot_scene = preload("res://scenes/SnapZone.tscn")
	feedback_scene = preload("res://scenes/Feedback_Grid.tscn")
	peg_manager_reference = $"../PegManager"
	print("Items at board start:", item_system.player_items)
	BoardModifierEngine.pre_board_build(self)
	health_text.initialize()
	health_text.change_health(player_health)
	print("Modifiers on Board load: ", BoardModifierEngine.active_modifiers)
	print("Items on Board load: ", ItemManager.player_items)
	$"../BackgroundLayer".change_background(randi() % 5)
	KeywordEngine.multiplier = 1
	KeywordEngine.set_context(
		self,
		peg_manager_reference,
		popup_manager
	)
	
	generate_code()
	$"../SecretCodeDisplay".build(secret_code)
	
	# Create safe rows + one danger row
	for i in range(soft_row_limit):
		add_row()
	for child in get_children():
		if child is SnapZone:
			if child.row == 0:
				child.update_shader_value(50)
	
	update_safe_background()
	
	BoardModifierEngine.post_board_build(self)


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
	
	var slot_width = columns * slot_size + (columns - 1) * spacing
	var feedback_columns = ceil(columns / 2.0)
	var feedback_width = feedback_columns * 24
	var gap = 10

	var total_width = slot_width + gap + feedback_width
	var start_x = camera_center.x - total_width / 2.0 + slot_size / 2.0

	# IMPORTANT: grow upward, not downward
	var base_y = camera_center.y + 350
	var y = base_y - r * (slot_size + spacing)

	if r >= soft_row_limit:
		create_danger_background(y)

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
	feedback_grid.background_resize(columns)
	feedback_grid.position = Vector2(
		start_x + slot_width + gap,
		y - 24
	)

	# Danger styling
	if r >= soft_row_limit:
		for child in get_children():
			if (child is SnapZone) and child.row == r:
				apply_danger_visual(child)

	rows_generated += 1
	if rows_generated <= soft_row_limit:
		update_safe_background()


func collapse_bottom_rows():

	var rows_to_remove = soft_row_limit
	var shift_distance = rows_to_remove * (slot_size + spacing)

	# --------------------
	# Phase 1 — Fade bottom rows
	# --------------------

	var fade_tween = create_tween().set_parallel(true)
	var has_fade := false
	var nodes_to_delete := []

	for child in get_children():

		if child is SnapZone and child.row < rows_to_remove:

			fade_tween.tween_property(child, "modulate:a", 0.0, 0.35)
			has_fade = true
			nodes_to_delete.append(child)

			if child.peg_in_slot:
				fade_tween.tween_property(child.peg_in_slot, "modulate:a", 0.0, 0.35)
				nodes_to_delete.append(child.peg_in_slot)

		elif child is Feedback_Grid and child.row < rows_to_remove:

			fade_tween.tween_property(child, "modulate:a", 0.0, 0.35)
			has_fade = true
			nodes_to_delete.append(child)

	for bg in $DangerBGContainer.get_children():
		if bg.row < rows_to_remove:
			fade_tween.tween_property(bg, "modulate:a", 0.0, 0.35)
			has_fade = true
			nodes_to_delete.append(bg)

	if has_fade:
		await fade_tween.finished

	for n in nodes_to_delete:
		if is_instance_valid(n):
			n.queue_free()

	# Remove logical rows
	for i in range(rows_to_remove):
		if board_state.size() > 0:
			board_state.remove_at(0)

	# --------------------
	# Phase 2 — Shift remaining rows
	# --------------------

	var move_tween = create_tween().set_parallel(true)
	move_tween.set_trans(Tween.TRANS_CUBIC)
	move_tween.set_ease(Tween.EASE_OUT)

	var has_move := false

	for child in get_children():

		if child is SnapZone and child.row >= rows_to_remove:

			child.row -= rows_to_remove

			var new_pos = child.position
			new_pos.y += shift_distance
			move_tween.tween_property(child, "position", new_pos, 0.5)
			has_move = true

			if child.peg_in_slot:
				var occ = child.peg_in_slot
				occ.row -= rows_to_remove

				var occ_new = occ.position
				occ_new.y += shift_distance
				move_tween.tween_property(occ, "position", occ_new, 0.5)

		elif child is Feedback_Grid and child.row >= rows_to_remove:

			child.row -= rows_to_remove

			var new_pos = child.position
			new_pos.y += shift_distance
			move_tween.tween_property(child, "position", new_pos, 0.5)
			has_move = true

	for bg in $DangerBGContainer.get_children():

		bg.row -= rows_to_remove

		var new_pos = bg.position
		new_pos.y += shift_distance
		move_tween.tween_property(bg, "position", new_pos, 0.5)
		has_move = true

	if has_move:
		await move_tween.finished

	# Phase 3 — Delete overflow danger BGs

	var overflow_limit = soft_row_limit * 2
	
	var bg_cleanup_tween = create_tween().set_parallel(true)
	var has_cleanup := false
	var overflow_to_remove := []
	
	for bg in $DangerBGContainer.get_children():
		if bg.row >= overflow_limit:
			bg_cleanup_tween.tween_property(bg, "modulate:a", 0.0, 0.3)
			has_cleanup = true
			overflow_to_remove.append(bg)
	
	if has_cleanup:
		await bg_cleanup_tween.finished
	
	for bg in overflow_to_remove:
		if is_instance_valid(bg):
			bg.queue_free()

	# --------------------
	# Rebuild lookup & sync rows
	# --------------------

	slot_lookup.clear()
	for child in get_children():
		if child is SnapZone:
			slot_lookup[Vector2(child.row, child.column)] = child

	rows_generated = board_state.size()

	peg_manager_reference.cur_row -= rows_to_remove
	if peg_manager_reference.cur_row < 0:
		peg_manager_reference.cur_row = 0
	if peg_manager_reference.cur_row >= rows_generated:
		peg_manager_reference.cur_row = rows_generated - 1
	print(peg_manager_reference.cur_row)
	update_safe_background()


func update_safe_background():
	var camera = $"../Camera2D"
	var camera_center = camera.get_screen_center_position()

	var slot_width = columns * slot_size + (columns - 1) * spacing
	var feedback_columns = ceil(columns / 2.0)
	var feedback_width = feedback_columns * 24
	var gap = 10

	var total_width = slot_width + gap + feedback_width

	var visible_safe_rows = min(rows_generated, soft_row_limit)
	if visible_safe_rows == 0:
		return

	var total_height = soft_row_limit * slot_size + (soft_row_limit - 1) * spacing

	var base_y = camera_center.y + 350
	var top_y = base_y - (visible_safe_rows - 1) * (slot_size + spacing)

	var bg = $SafeBoardBG
	
	var padding_x = 90
	var padding_y = 50
	
	var final_width = total_width + padding_x
	var final_height = total_height + padding_y
	
	bg.size = Vector2(final_width, final_height)
	
	bg.position = Vector2(
		camera_center.x - final_width / 2.0,
		top_y - slot_size / 2.0 - padding_y / 2.0
	)


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


func create_danger_background(y_pos):
	var bg_scene = preload("res://scenes/DangerRowBG.tscn")
	var bg = bg_scene.instantiate()
	bg.row = peg_manager_reference.cur_row
	$DangerBGContainer.add_child(bg)

	var camera = $"../Camera2D"
	var camera_center = camera.get_screen_center_position()

	var slot_width = columns * slot_size + (columns - 1) * spacing
	var feedback_columns = ceil(columns / 2.0)
	var feedback_width = feedback_columns * 24
	var gap = 10
	var total_width = slot_width + gap + feedback_width
	var total_height = slot_size + spacing

	var padding_x = 80
	var padding_y = 17
	
	var final_width = total_width + padding_x
	var final_height = total_height + padding_y
	
	bg.size = Vector2(final_width, final_height)
	
	bg.position = Vector2(
		camera_center.x - final_width / 2.0 - 7,
		y_pos - slot_size / 2.0 - padding_y / 2.0 - 13
	)
	tween_danger_bg(bg)


func tween_danger_bg(bg):
	var camera = $"../Camera2D"
	var screen_height = get_viewport().get_visible_rect().size.y
	var world_top = camera.global_position.y - screen_height / 2.0

	var final_pos = bg.global_position
	bg.global_position.y = world_top - 100

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(bg, "global_position", final_pos, 0.6)


func apply_danger_visual(node):
	node.set_glow_red()
	node.in_danger_row = true


# =========================
# SUBMIT GUESS
# =========================

func submit_guess():
	var guess = []
	var row_index = peg_manager_reference.cur_row

	# Validate row
	for child in get_children():
		if child is SnapZone and child.row == row_index:
			var occupant = child.peg_in_slot
			
			if occupant == null:
				print("Invalid Guess")
				return

			guess.append(occupant.get_submission_value())
	print("Guess:", guess)
	if row_index >= board_state.size():
		return
	# Save guess
	for c in range(columns):
		board_state[row_index][c] = guess[c]

	var result = evaluate_guess(guess)
	
	for r in guess:
		if r == -1:
			obscurities += 1
	
	if obscurities > 0:
		result = apply_obscure_logic(obscurities, result)
		obscurities = 0

	for peg in guess:
		if peg == 7:
			apply_heal(1)


		# Apply soft limit damage
	if row_index >= soft_row_limit:
		apply_damage(damage_per_row)
	
	# Show feedback
	for child in get_children():
		if child is Feedback_Grid and child.row == row_index:
			child.show_results(result[0], result[1])
	
	if result[0] == columns:
		BoardModifierEngine.disabled_modifiers_this_round.clear()
		BoardModifierEngine.disable_mode = false
		$"../SecretCodeDisplay".reveal_all()
		in_game = false
		await handle_goop_explosion()
		if player_health > 0:
			popup_manager.show_popup(
				"[center][b][color=#BEFD73] YOU WIN [/color][/b][/center]"
			)
		AudioLoader.play_sound("win")
		var reward_ui = preload("res://scenes/RewardsSelectionUI.tscn").instantiate()
		add_child(reward_ui)
		
		var choices = RunProgressionManager.get_reward_choices()
		reward_ui.connect("reward_confirmed", _on_reward_confirmed)
		reward_ui.show_rewards(choices)
		
	if in_game:
		BoardModifierEngine.process_row_submission(self, guess, result)
	
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
		item_system.emit_game_event("pattern_triggered", {
			"pattern_name": p["name"],
			"positions": p["positions"]
		})
		
		if item_system.has_item_trigger_for_pattern(p["name"]):
			spawn_pattern_markers(p["positions"])
	item_system.process_turn_events()
	
	if peg_manager_reference.cur_row >= 9:
		await collapse_bottom_rows()
		damage_per_row += 1
		print(peg_manager_reference.cur_row)
	
	peg_manager_reference.cur_row += 1
	
	ChaosManager.fire_chaos_event()
	
	for child in get_children():
		if child is SnapZone:
			if child.row == peg_manager_reference.cur_row:
				child.update_shader_value(50)
	# Collapse BEFORE spawning new danger rows
	
	
	# Add new row
	if peg_manager_reference.cur_row >= rows_generated - 3 and rows_generated < 10:
		add_row()
		tween_last_row()


# =========================
# DAMAGE SYSTEM
# =========================

func apply_damage(damage):
	player_health -= damage
	ChaosManager.add_chaos_from_damage()
	print("Health:", player_health)
	
	flash_damage()
	health_text.change_health(player_health)
	AudioLoader.play_sound("damage")
	item_system.emit_game_event("health_lost", {
		"amount": damage_per_row,
		"health": player_health
	})

	if player_health <= 0:
		print("Game Over")
		in_game = false
		popup_manager.show_popup(
			"[center][b][color=#FF073A] YOU LOSE [/color][/b][/center]"
		)
		AudioLoader.play_sound("lose")
		$"../SecretCodeDisplay".reveal_all()
		in_game = false
		await handle_goop_explosion()
		await get_tree().create_timer(5.0).timeout
		var tween = create_tween().set_ease(Tween.EASE_IN)
		tween.tween_property(
			$CanvasLayer/FadeOut, 
			"modulate:a",
			1,
			2.5
		)
		await tween.finished
		get_tree().change_scene_to_file("res://scenes/RunSetupScreen.tscn")
		return



func flash_damage():
	damage_overlay.modulate = Color(1, 0, 0, 0.8)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_overlay, "modulate", Color(1, 0, 0, 0), 0.5)


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


func re_evaluate_row(row_index):
	var guess = []

	for child in get_children():
		if child is SnapZone and child.row == row_index:
			if child.peg_in_slot:
				guess.append(child.peg_in_slot.get_submission_value())
			else:
				guess.append(0)
	
	var result = evaluate_guess(guess)
	for r in guess:
		if r == -1:
			obscurities += 1
	
	if obscurities > 0:
		result = apply_obscure_logic(obscurities, result)
		obscurities = 0
	for peg in guess:
		if peg == 7:
			apply_heal(1)


	
	BoardModifierEngine.process_row_submission(self, guess, result)
	
	if result[0] == columns:
		BoardModifierEngine.disabled_modifiers_this_round.clear()
		BoardModifierEngine.disable_mode = false
		$"../SecretCodeDisplay".reveal_all()
		in_game = false
		await handle_goop_explosion()
		if player_health > 0:
			popup_manager.show_popup(
						"[center][b][color=#BEFD73] YOU WIN [/color][/b][/center]"
					)
		AudioLoader.play_sound("win")
		var reward_ui = preload("res://scenes/RewardsSelectionUI.tscn").instantiate()
		add_child(reward_ui)
		
		var choices = RunProgressionManager.get_reward_choices()
		reward_ui.connect("reward_confirmed", _on_reward_confirmed)
		reward_ui.show_rewards(choices)
		return
	
	if row_index >= board_state.size():
		return
	
	# Update board state
	for c in range(columns):
		board_state[row_index][c] = guess[c]

	# Update feedback visuals
	for child in get_children():
		if child is Feedback_Grid and child.row == row_index:
			clear_feedback_grid(child)
			child.show_results(result[0], result[1])
	
	var triggered = pattern_engine.evaluate_board(
		board_state,
		rows_generated,
		columns,
		row_index
	)

	for p in triggered:
		if item_system.has_item_trigger_for_pattern(p["name"]):
			spawn_pattern_markers(p["positions"])
		
			item_system.emit_game_event("pattern_triggered", {
				"pattern_name": p["name"],
				"positions": p["positions"]
			})

	print("Row re-evaluated:", row_index, result)


func clear_feedback_grid(grid):
	for node in grid.get_children():
		if node is Feedback_Peg:
			node.queue_free()
		else:
			clear_feedback_grid(node)


func handle_goop_explosion():
	var peg_manager = $"../PegManager"
	var hand = peg_manager.player_hand_reference
	
	var goop_pegs := []
	
	for peg in hand.player_hand:
		if peg.is_special and peg.special_type == "goop":
			goop_pegs.append(peg)
	
	for peg in goop_pegs:
		hand.player_hand.erase(peg)

	hand.update_hand_positions()
	
	var goop_count = 0
	var damage = floor(goop_count / 2)
	
	for peg in goop_pegs:
		goop_count += 1
		spawn_goop_explosion(peg.global_position)
		AudioLoader.play_sound("goop")
		peg.queue_free()
		if goop_count == 2:
			apply_damage(1)
			goop_count = 0
		await get_tree().create_timer(0.25).timeout
	

	
	hand.player_hand = hand.player_hand.filter(
		func(p): return not (p.is_special and p.special_type == "goop")
	)
	
	hand.update_hand_positions()


func spawn_goop_explosion(pos):
	var explosion = preload("res://scenes/GoopExplosion.tscn").instantiate()
	add_child(explosion)
	explosion.global_position = pos
	explosion.explode()


# =========================
# SECRET CODE
# =========================

func generate_code():
	secret_code.clear()
	for i in range(columns):
		secret_code.append(randi_range(1, 6))
	print(secret_code)


func apply_heal(amount):
	player_health += amount
	print("Healed:", amount)
	health_text.change_health(player_health)

	popup_manager.show_popup(
		"[center][b][color=#ED7117]+%d HEALTH[/color][/b][/center]" % amount
	)


func apply_obscure_logic(obscurities, result):
	var black = result[0]
	var white = result[1]
	var obscured := 0
	for g in range(obscurities):
		if randf() < 0.5:
			obscured += 1
			if black > 0:
				black -= 1
			elif white > 0:
				white -= 1
	PopUpText.show_popup(
				"[center][b][color=#BC13FE]OBSCURE %d [/color][/b][/center]" % obscured
			)
	return [black, white]


func start_next_board():
	in_game = true
	
	ChaosManager.set_context(self, peg_manager_reference, popup_manager)
	
	# Reset board state cleanly
	board_state.clear()
	slot_lookup.clear()
	PatternEngine.triggered_patterns.clear()
	rows_generated = 0
	peg_manager_reference.cur_row = 0
	columns = 4
	
	# Clear children rows
	for child in get_children():
		if child is SnapZone: 
			if child.peg_in_slot:
				child.peg_in_slot.queue_free()
			child.queue_free()
		if child is Feedback_Grid:
			child.queue_free()
	
	for bg in $DangerBGContainer.get_children():
		bg.queue_free()
	
	BoardModifierEngine.pre_board_build(self)
	print("Modifiers on Board load: ", BoardModifierEngine.active_modifiers)
	print("Items on Board load: ", ItemManager.player_items)
	$"../BackgroundLayer".change_background(randi() % 5)
	KeywordEngine.multiplier = 1
	KeywordEngine.set_context(
		self,
		peg_manager_reference,
		popup_manager
	)
	popup_manager.mult_reset()
	BoardModifierEngine.color_counters.clear()
	BoardModifierEngine.feedback_counters.clear()
	generate_code()
	$"../SecretCodeDisplay".build(secret_code)
	get_parent().populate_hud()
	for i in range(soft_row_limit):
		add_row()
	
	update_safe_background()
	
	BoardModifierEngine.post_board_build(self)


func _on_reward_confirmed(_choice):
	await fade_out()
	
	ChaosManager.cleanse_on_board_clear()
	ChaosManager.reset_dollars()
	
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")
	
	await fade_in()


func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.6)
	await tween.finished


func fade_in():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.6)
	await tween.finished


func _on_pressed() -> void:
	if in_game:
		submit_guess()
		AudioLoader.play_sound("select")
