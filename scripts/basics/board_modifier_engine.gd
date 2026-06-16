extends Node

# =========================
# BOARD MODIFIER ENGINE
# Owns: modifier loading, active modifiers, build phases, effect application, disable mode
# Trigger evaluation and counter tracking now live in ItemManager
# =========================

var active_modifiers = []

var all_modifiers : Array[ModifierData] = []
var modifiers_by_name := {}

var disable_mode := false
var disables_left := 0
var disabled_modifiers_this_round := []


# =========================
# INITIALIZATION
# =========================

func _ready() -> void:
	initialize()


func initialize():
	if all_modifiers.size() == 0:
		load_modifiers()


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
			var path = "res://data/modifiers/" + file_name
			var modifier : ModifierData = ResourceLoader.load(path)
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
# DISABLE MODE
# =========================

func start_disable_mode(amount):
	disable_mode = true
	disables_left = amount
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
# BUILD PHASES
# =========================

func pre_board_build(board):
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.phase == "pre_build" and modifier.get_scaled_effect() != null:
			apply_effect(board, modifier.get_scaled_effect())


func post_board_build(board):
	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.phase == "post_build" and modifier.get_scaled_effect() != null:
			apply_effect(board, modifier.get_scaled_effect())


# =========================
# GOOP — STILL RUNS PER-ROW
# Called by BoardManager after row submission, separate from trigger system
# (Goop scales with this row's black feedback, not a counter threshold)
# =========================

func process_goop_for_row(board, result):
	var black_this_row = result[0]

	for modifier in active_modifiers:
		if modifier in disabled_modifiers_this_round:
			continue
		if modifier.base_effect != null and modifier.base_effect.has("Goop"):
			var scaled = modifier.get_scaled_effect()
			spawn_goop_from_black(board, black_this_row * scaled["Goop"])


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
			"Remove Color":
				remove_color_pegs(effect[key])
			"Remove All":
				remove_all_pegs(effect[key])
			"Extra Damage":
				apply_extra_damage(effect[key])
			"Unlight Dollar":
				apply_unlight_dollar(effect[key])


# =========================
# WIDE (Pre-Build)
# =========================

func apply_wide(board, value):
	print("Applying Wide:", value)
	board.columns += value


func apply_short(board, value):
	print("Applying Short: ", value)
	board.soft_row_limit = max(board.soft_row_limit - value, 2)


# =========================
# TRAPPED (Post-Build)
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


# =========================
# GOOP SPAWN
# =========================

func spawn_goop_from_black(board, black_count):
	if black_count <= 0:
		return

	var peg_manager = board.get_node("../PegManager")
	var hand = peg_manager.player_hand_reference

	for i in range(black_count):
		var goop = preload("res://scenes/Phys_Peg.tscn").instantiate()

		AudioManager.play_sound("goop")

		goop.is_special = true
		goop.is_copy = true
		goop.special_type = "goop"
		goop.peg_id = -1
		goop.setup_visuals()

		hand.add_special_peg(goop)


# =========================
# OBSCURE
# =========================

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
# PEG REMOVAL
# =========================

func remove_color_pegs(payload):
	if payload is Dictionary:
		var color_id = payload.get("color_id", 1)
		var amount = payload.get("amount", 1)
		PegInventoryManager.remove_pegs_from_color(color_id, amount)
	else:
		var color_ids = [1, 2, 3, 4, 5, 6]
		var random_id = color_ids[randi() % color_ids.size()]
		PegInventoryManager.remove_pegs_from_color(random_id, int(payload))


func remove_all_pegs(amount):
	PegInventoryManager.remove_pegs_from_all(int(amount))


# =========================
# EXTRA DAMAGE
# Applies damage directly via RunProgressionManager to bypass apply_damage()
# orchestration, preventing recursion (no flash, no sound, no re-emit of "Damage Taken")
# =========================

func apply_extra_damage(amount):
	print("Applying Extra Damage:", amount)
	RunProgressionManager.remove_health(int(amount))


# =========================
# UNLIGHT DOLLAR
# Unlights N lit dollars, leftmost first (matching damage behavior)
# =========================

func apply_unlight_dollar(amount):
	print("Applying Unlight Dollar:", amount)
	for i in range(int(amount)):
		DollarManager.lose_dollar_from_damage()