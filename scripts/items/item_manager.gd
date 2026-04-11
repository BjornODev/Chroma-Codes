extends Node2D

var player_items = []
var all_items : Array[ItemData] = []
var items_by_name := {}

var _prev_panel_color_counts := {}

var turn_event_queue = []
var is_processing_turn_events = false

@onready var popup_manager = PopUpText

signal items_changed
signal active_item_cap_reached(new_item: ItemData)


func _ready():
	load_items()
	# TEMP: give player first item
#	if all_items.size() > 0:
#		player_items.append(all_items[0])
#		player_items.append(all_items[2])
#		give_item_by_name("Replace 2")


var board_reference
var peg_manager_reference

func set_board_context(board, peg_manager):
	board_reference = board
	peg_manager_reference = peg_manager


func load_items():
	all_items.clear()
	items_by_name.clear()
	
	var files = ResourceLoader.list_directory("res://data/items")
	files.sort()
	if files.is_empty():
		push_error("Items folder missing")
		return
	
	for file_name in files:
		if file_name.ends_with(".tres"):
			#if file_name.ends_with(".remap"):
				#file_name = file_name.replace(".remap", "")
			var path = "res://data/items/" + file_name
			var item : ItemData = ResourceLoader.load(path)
			if item:
				all_items.append(item)
				items_by_name[item.item_name] = item
			else:
				push_warning("Failed to load item: " + path)
	
	print("Loaded items: ", all_items.size())


func emit_game_event(event_name, payload = {}):
	turn_event_queue.append({
		"event": event_name,
		"payload": payload
	})


func process_turn_events():
	if is_processing_turn_events:
		return
	
	is_processing_turn_events = true
	
	while turn_event_queue.size() > 0:
		var event_data = turn_event_queue.pop_front()
		process_event(event_data.event, event_data.payload)
	
	is_processing_turn_events = false


func process_event(event_name, payload):
	for item in player_items:
		process_item_event(item, event_name, payload)


func process_item_event(item, event_name, payload):
	for trigger in item.triggers:
		if trigger.event != event_name:
			continue

		if trigger.has("pattern"):
			if payload.get("pattern_name") != trigger.pattern:
				continue

		if trigger.has("index"):
			if payload.get("index") != trigger.index:
				continue

		# NEW: panel color count condition
		# trigger format: {"event": "panel_activated", "color": "red", "count": 2}
		if trigger.has("color") and trigger.has("count"):
			var color_counts = payload.get("color_counts", {})
			var required_color = trigger["color"]
			var required_count = trigger["count"]
			var current = color_counts.get(required_color, 0)
			# Use threshold crossing — fires every N activations
			var prev = _get_prev_color_count(item.item_name, required_color)
			var prev_multiple = int(prev / required_count)
			var curr_multiple = int(current / required_count)
			if curr_multiple <= prev_multiple:
				continue
			_set_prev_color_count(item.item_name, required_color, current)

func _get_prev_color_count(item_name: String, color: String) -> int:
	return _prev_panel_color_counts.get(item_name + "_" + color, 0)

func _set_prev_color_count(item_name: String, color: String, value: int):
	_prev_panel_color_counts[item_name + "_" + color] = value


func apply_item_effects(item, payload):
	for keyword in item.keywords.keys():
		KeywordEngine.apply_keyword(
			keyword,
			item.keywords[keyword],
			payload
		)


func has_item_trigger_for_pattern(pattern_name):
	for item in player_items:
		for trigger in item.triggers:
			if trigger.event == "pattern_triggered":
				if trigger.has("pattern") and trigger.pattern == pattern_name:
					return true
	return false


func give_item_by_name(name: String):
	if not items_by_name.has(name):
		return
	var item = items_by_name[name]
	if item.is_active:
		var active_count = player_items.filter(func(i): return i.is_active).size()
		if active_count >= 5:
			emit_signal("active_item_cap_reached", item)
			return  # ← return before adding or emitting items_changed
	player_items.append(item)
	if item.is_active:
		ActiveItemManager.add_item(item)
	RunProgressionManager.reward_pool_items.erase(item)
	emit_signal("items_changed")