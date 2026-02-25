extends Node

var all_modifiers = []
var active_modifiers = []

var counters := {}   # keyword counters


# =========================
# INITIALIZATION
# =========================

func initialize():
	load_modifiers()
	
	# Example: auto-activate first modifier for testing
	if all_modifiers.size() > 0:
		active_modifiers.append(all_modifiers[0])
		active_modifiers.append(all_modifiers[2])
		active_modifiers.append(all_modifiers[7])


# =========================
# LOAD MODIFIERS
# =========================

func load_modifiers():
	var file = FileAccess.open("res://data/modifiers.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load modifiers.json")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("Modifier JSON parse error")
		return
	
	all_modifiers = json.data


# =========================
# ACTIVATION
# =========================

func activate_modifier_by_name(name):
	for modifier in all_modifiers:
		if modifier.name == name:
			active_modifiers.append(modifier)
			print("Activated modifier:", name)
			return
	
	print("Modifier not found:", name)


func get_active_modifiers():
	return active_modifiers


# =========================
# BUILD PHASES
# =========================

func pre_board_build(board):
	for modifier in active_modifiers:
		if modifier.has("phase") and modifier.phase == "pre_build":
			if modifier.has("effect"):
				apply_effect(board, modifier.effect)


func post_board_build(board):
	for modifier in active_modifiers:
		if modifier.has("phase") and modifier.phase == "post_build":
			if modifier.has("effect"):
				apply_effect(board, modifier.effect)


# =========================
# RUNTIME PROCESSING
# =========================

func process_row_submission(board, guess, result):
	update_color_counters(guess)
	update_feedback_counters(result)
	
	check_triggers(board)
	
	var black_this_row = result[0]

	for modifier in active_modifiers:
		if modifier.has("effect") and modifier.effect.has("goop"):
			var multiplier = modifier.effect["goop"]
			spawn_goop_from_black(board, black_this_row * multiplier)

	

func update_color_counters(guess):
	for value in guess:
		if value == 0:
			continue
		
		var color = get_color_name_from_id(value)
		
		if not counters.has(color):
			counters[color] = 0
		
		counters[color] += 1


func check_triggers(board):
	for modifier in active_modifiers:
		if not modifier.has("trigger"):
			continue
		
		if trigger_satisfied(modifier.trigger):
			if modifier.has("effect"):
				apply_effect(board, modifier.effect)
			
			reset_trigger(modifier.trigger)


func update_feedback_counters(result):
	var black = result[0]
	var white = result[1]
	
	if not counters.has("black"):
		counters["black"] = 0
	
	if not counters.has("white"):
		counters["white"] = 0
	
	counters["black"] += black
	counters["white"] += white


func trigger_satisfied(trigger_block):
	for key in trigger_block.keys():
		if counters.get(key, 0) < trigger_block[key]:
			return false
	
	return true


func reset_trigger(trigger_block):
	for key in trigger_block.keys():
		counters[key] = 0


# =========================
# EFFECT APPLICATION
# =========================

func apply_effect(board, effect):
	for key in effect.keys():
		match key:
			"wide":
				apply_wide(board, effect[key])
			
			"trapped":
				spawn_traps(board, effect[key])
			
			"sudden_spike":
				spawn_spikes(board, effect[key])
			
			"goop":
				pass

# =========================
# WIDE (Pre-Build Effect)
# =========================

func apply_wide(board, value):
	print("Applying Wide:", value)
	board.columns = value


# =========================
# TRAPPED (Post-Build Effect)
# =========================

func spawn_traps(board, value):
	var total_traps = 2 * value
	
	var slots = board.slot_lookup.values()
	slots.shuffle()
	
	var placed = 0
	
	for slot in slots:
		if slot.peg_in_slot == null:
			var spike = preload("res://scenes/Spike.tscn").instantiate()
			board.add_child(spike)
			
			spike.position = slot.position
			slot.peg_in_slot = spike
			slot.set_glow_red()
			spike.current_slot = slot
			
			placed += 1
			
			if placed >= total_traps:
				break


# =========================
# RUNTIME SPIKE SPAWN
# =========================

func spawn_spikes(board, amount):
	var slots = board.slot_lookup.values()
	slots.shuffle()
	
	var placed = 0
	
	for slot in slots:
		if slot.peg_in_slot == null:
			var spike = preload("res://scenes/Spike.tscn").instantiate()
			var tween = create_tween()
			board.add_child(spike)
			
			spike.position = slot.position
			spike.sprite.scale = Vector2.ZERO
			tween.tween_property(spike.sprite, "scale", Vector2(0.15,0.15), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			slot.peg_in_slot = spike
			slot.set_glow_red()
			spike.current_slot = slot
			
			placed += 1
			
			if placed >= amount:
				break


func spawn_goop_from_black(board, black_count):
	if black_count <= 0:
		return
	
	var peg_manager = board.get_node("../PegManager")
	var hand = peg_manager.player_hand_reference
	
	for i in range(black_count):
		var goop = preload("res://scenes/Phys_Peg.tscn").instantiate()
		
		goop.is_special = true
		goop.is_copy = true
		goop.special_type = "goop"
		goop.peg_id = 0
		goop.setup_visuals()
		
		# IMPORTANT: configure BEFORE adding to scene
		hand.add_special_peg(goop)

# =========================
# UTILITY
# =========================

func get_color_name_from_id(id):
	match id:
		1: return "red"
		2: return "yellow"
		3: return "green"
		4: return "white"
		5: return "purple"
		6: return "orange"
		_: return "unknown"