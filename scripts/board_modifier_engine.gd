extends Node

var all_modifiers = []
var active_modifiers = []

# =========================
# INITIALIZATION
# =========================

func initialize():
	load_modifiers()
	active_modifiers.append(all_modifiers[0])


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
# EVENT SYSTEM (EMPTY FOR NOW)
# =========================

func emit_game_event(event_name, payload = {}):
	for modifier in active_modifiers:
		process_modifier_event(modifier, event_name, payload)


func process_modifier_event(modifier, event_name, payload):
	# Step 1 does nothing yet
	pass


func pre_board_build(board):
	for modifier in active_modifiers:
		var keywords = modifier.get("keywords", {})
		
		for keyword in keywords.keys():
			var value = keywords[keyword]
			
			match keyword:
				"Wide":
					apply_wide(board, value)


func post_board_build(board):
	for modifier in active_modifiers:
		var keywords = modifier.get("keywords", {})
		
		if keywords.has("Trapped"):
			var value = keywords["Trapped"]
			apply_trapped(board, value)


func apply_wide(board, value):
	print("Applying Wide:", value)
	board.columns = value


func apply_trapped(board, value):
	var total_traps = 2 * value
	
	var slots = board.slot_lookup.values()
	slots.shuffle()
	
	for i in range(min(total_traps, slots.size())):
		var spike = preload("res://scenes/Spike.tscn").instantiate()
		board.add_child(spike)
		
		var slot = slots[i]
		spike.position = slot.position
		
		slot.peg_in_slot = spike
		slot.set_glow_red()
		spike.current_slot = slot