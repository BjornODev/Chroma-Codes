extends Node

var active_modifiers = []

var all_modifiers : Array[ModifierData] = []
var modifiers_by_name := {}

var counters := {}   # keyword counters

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

func initialize():
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
	
	var dir = DirAccess.open("res://data/modifiers")
	if dir == null:
		push_error("Modifiers folder missing")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var modifier : ModifierData = load("res://data/modifiers/" + file_name)
			all_modifiers.append(modifier)
			modifiers_by_name[modifier.modifier_name] = modifier
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


# =========================
# ACTIVATION
# =========================

func activate_modifier_by_name(name : String):
	if not modifiers_by_name.has(name):
		print("Modifier not found:", name)
		return
	
	active_modifiers.append(modifiers_by_name[name])
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
		if modifier.phase == "pre_build" and modifier.effect != null:
			apply_effect(board, modifier.effect)

func post_board_build(board):
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.phase == "post_build" and modifier.effect != null:
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
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.effect != null and modifier.effect.has("goop"):
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
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.trigger == null:
			continue
		
		if trigger_satisfied(modifier.trigger):
			if modifier.effect != null:
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
	if trigger_block == null or trigger_block.is_empty():
		return false
	
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
			
			"obscure":
				spawn_obscure(board, effect[key])
			"short":
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
		
		goop.is_special = true
		goop.is_copy = true
		goop.special_type = "goop"
		goop.peg_id = 0
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