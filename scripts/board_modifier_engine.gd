extends Node

var active_modifiers = []

var all_modifiers : Array[ModifierData] = []
var modifiers_by_name := {}

var color_counters := {}
var feedback_counters := {}   # keyword counters
var prev_color_counters := {}
var prev_feedback_counters := {}
signal color_counters_updated(counters: Dictionary)
signal feedback_counters_updated(counters: Dictionary)

var disable_mode := false
var disables_left := 0
var disabled_modifiers_this_round := []

func start_disable_mode(amount):
	disable_mode = true
	disables_left = amount
#	disabled_modifiers_this_round.clear()
	print("Disable mode started:", amount)


func disable_modifier(modifier):
	if not disable_mode:
		return

	if modifier in disabled_modifiers_this_round:
		return

	disabled_modifiers_this_round.append(modifier)
	disables_left -= 1

	print("Disabled:", modifier.modifier_name)

	if disables_left <= 0:
		disable_mode = false
		print("Disable mode ended.")


# =========================
# INITIALIZATION
# =========================

func _ready() -> void:
	initialize()
#	activate_modifier_by_name("Green Spike")
#	activate_modifier_by_name("Wide Board")

func initialize():
	if all_modifiers.size() == 0:
		load_modifiers()
	
	# Example: auto-activate first modifier for testing
#	if all_modifiers.size() > 0:
##		activate_modifier_by_name("Very Wide Board")
#		activate_modifier_by_name("Goop Board")


# =========================
# LOAD MODIFIERS
# =========================


func load_modifiers():
	all_modifiers.clear()
	modifiers_by_name.clear()
	
	var files := ResourceLoader.list_directory("res://data/modifiers")
	files.sort()
	if files.is_empty():
		push_error("Modifiers folder missing")
		return
	
	
	for file_name in files:
		if file_name.ends_with(".tres"):
			#if file_name.ends_with(".remap"):
				#file_name = file_name.replace(".remap", "")
			var path = "res://data/modifiers/" + file_name
			var modifier : ModifierData =ResourceLoader.load(path)
			if modifier:
				all_modifiers.append(modifier)
				modifiers_by_name[modifier.modifier_name] = modifier
			else:
				push_warning("Failed to load modifiers: " + path)
	print("Loaded modifiers: ", all_modifiers.size())


# =========================
# ACTIVATION
# =========================

func activate_modifier_by_name(name : String):
	if not modifiers_by_name.has(name):
		return
	    
	var existing = null
	
	for mod in active_modifiers:
		if mod.modifier_name == name:
			existing = mod
			break
	
	if existing:
		existing.level += 1
		print(name, " upgraded to level ", existing.level)
	else:
		var new_mod = modifiers_by_name[name].duplicate()
		new_mod.level = 1
		active_modifiers.append(new_mod)
		print("Activated modifier:", name)


func get_active_modifiers():
	return active_modifiers


# =========================
# BUILD PHASES
# =========================

func pre_board_build(board):
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.phase == "pre_build" and modifier.get_scaled_effect != null:
			apply_effect(board, modifier.get_scaled_effect())

func post_board_build(board):
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.phase == "post_build" and modifier.get_scaled_effect() != null:
			apply_effect(board, modifier.get_scaled_effect())

# =========================
# RUNTIME PROCESSING
# =========================

func process_row_submission(board, guess, result):
	update_color_counters(guess)
	update_feedback_counters(result)
	
	check_triggers(board)
	
	var black_this_row = result[0]

	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.base_effect != null and modifier.base_effect.has("Goop"):
			var multiplier = modifier.get_scaled_effect()
			spawn_goop_from_black(board, black_this_row * multiplier["Goop"])


func update_color_counters(guess):
	for value in guess:
		if value == 0:
			continue
		
		var color = get_color_name_from_id(value)
		
		if not color_counters.has(color):
			color_counters[color] = 0
	
		color_counters[color] += 1
	emit_signal("color_counters_updated", color_counters.duplicate())

func check_triggers(board):
	var snap_prev_color = prev_color_counters.duplicate()
	var snap_prev_feedback = prev_feedback_counters.duplicate()
	
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.trigger == null:
			continue
		var times = trigger_count(modifier.trigger, snap_prev_color, snap_prev_feedback)
		if times > 0:
			for i in range(times):
				if modifier.get_scaled_effect() != null:
					apply_effect(board, modifier.get_scaled_effect())
	
	prev_color_counters = color_counters.duplicate()
	prev_feedback_counters = feedback_counters.duplicate()


func trigger_count(trigger_block, snap_prev_color, snap_prev_feedback) -> int:
	if trigger_block == null or trigger_block.is_empty():
		return 0
	
	var times := 0
	
	for key in trigger_block.keys():
		var threshold = trigger_block[key]
		
		if color_counters.has(key):
			var current = color_counters.get(key, 0)
			var previous = snap_prev_color.get(key, 0)
			times = max(times, int(current / threshold) - int(previous / threshold))
		
		if feedback_counters.has(key):
			var current_f = feedback_counters.get(key, 0)
			var previous_f = snap_prev_feedback.get(key, 0)
			times = max(times, int(current_f / threshold) - int(previous_f / threshold))
	
	return times



func update_feedback_counters(result):
	var black = result[0]
	var white = result[1]
	
	if not feedback_counters.has("black"):
		feedback_counters["black"] = 0
	
	if not feedback_counters.has("white"):
		feedback_counters["white"] = 0
	
	feedback_counters["black"] += black
	feedback_counters["white"] += white
	
	emit_signal("feedback_counters_updated", feedback_counters.duplicate())


func reset_trigger(trigger_block):
	for key in trigger_block.keys():
		for k in color_counters.keys():
			if k == key:
				color_counters[key] = 0
		for k in feedback_counters.keys():
			if k == key:
				feedback_counters[key] = 0
	emit_signal("feedback_counters_updated", feedback_counters.duplicate())
	emit_signal("color_counters_updated",color_counters.duplicate())


# =========================
# EFFECT APPLICATION
# =========================

func apply_effect(board, effect):
	for key in effect.keys():
		match key:
			"Wide":
				apply_wide(board, effect[key])
			
			"Trapped":
				spawn_traps(board, effect[key])
			
			"Sudden Spike":
				spawn_spikes(board, effect[key])
			
			"Obscure":
				spawn_obscure(board, effect[key])
			"Short":
				apply_short(board, effect[key])
# =========================
# WIDE (Pre-Build Effect)
# =========================

func apply_wide(board, value):
	print("Applying Wide:", value)
	board.columns += value

func apply_short(board, value):
	print("Applying Short: ", value)
	board.soft_row_limit = max(board.soft_row_limit - value, 2)

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

	var empty_slots := []

	for slot in board.slot_lookup.values():
		if slot.peg_in_slot == null:
			empty_slots.append(slot)

	if empty_slots.is_empty():
		print("No empty slots available for spikes.")
		return

	empty_slots.shuffle()

	var placed := 0

	for slot in empty_slots:

		var spike = preload("res://scenes/Spike.tscn").instantiate()
		board.add_child(spike)

		spike.position = slot.position
		spike.sprite.scale = Vector2.ZERO

		var tween = board.create_tween()
		tween.tween_property(spike.sprite, "scale", Vector2(0.15,0.15), 0.2)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN_OUT)

		slot.peg_in_slot = spike
		slot.set_glow_red()
		spike.current_slot = slot

		placed += 1
		if placed >= amount:
			break

	print("Spikes placed:", placed, "/", amount)


func spawn_goop_from_black(board, black_count):
	if black_count <= 0:
		return
	
	var peg_manager = board.get_node("../PegManager")
	var hand = peg_manager.player_hand_reference
	
	for i in range(black_count):
		var goop = preload("res://scenes/Phys_Peg.tscn").instantiate()
		
		AudioLoader.play_sound("goop")
		
		goop.is_special = true
		goop.is_copy = true
		goop.special_type = "goop"
		goop.peg_id = -1
		goop.setup_visuals()
		
		# IMPORTANT: configure BEFORE adding to scene
		hand.add_special_peg(goop)


func spawn_obscure(board, amount):
	var empty_slots := []
	
	for slot in board.slot_lookup.values():
		if slot.peg_in_slot == null:
			empty_slots.append(slot)
	
	if empty_slots.is_empty():
			return
	
	empty_slots.shuffle()
	var placed := 0
	
	for slot in empty_slots:
		var obs = preload("res://scenes/ObscureObstacle.tscn").instantiate()
		
		board.add_child(obs)
		obs.position = slot.position
		slot.peg_in_slot = obs
		obs.current_slot = slot
		placed += 1
		if placed >= amount:
			break


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
