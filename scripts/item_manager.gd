extends Node2D

var player_items = []
var all_items = []

var turn_event_queue = []
var is_processing_turn_events = false
var peg_manager_reference

func _ready():
	load_items()
	peg_manager_reference = $"../PegManager"
	# TEMP: give player first item
	if all_items.size() > 0:
		player_items.append(all_items[0])


func load_items():
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		push_error("Item JSON missing")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		push_error("Item JSON error")
		return
	
	all_items = json.data


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
		
		apply_item_effects(item, payload)


func apply_item_effects(item, payload):
	for keyword in item.keywords.keys():
		var value = item.keywords[keyword]
		
		match keyword:
			"GainHealth":
				print("Would gain health:", value)
		match keyword:
			"Replace":
				peg_manager_reference.start_replace_mode(value)