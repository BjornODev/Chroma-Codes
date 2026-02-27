extends Node2D

var player_items = []
var all_items : Array[ItemData] = []
var items_by_name := {}

var turn_event_queue = []
var is_processing_turn_events = false

@onready var popup_manager = PopUpText

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
	
	var dir = DirAccess.open("res://data/items")
	if dir == null:
		push_error("Items folder missing")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item : ItemData = load("res://data/items/" + file_name)
			all_items.append(item)
			items_by_name[item.item_name] = item
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


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
		KeywordEngine.apply_keyword(
			keyword,
			item.keywords[keyword],
			payload
		)

func give_item_by_name(name : String):
	if not items_by_name.has(name):
		print("Item not found:", name)
		return
	
	player_items.append(items_by_name[name])

func has_item_trigger_for_pattern(pattern_name):
	for item in player_items:
		for trigger in item.triggers:
			if trigger.event == "pattern_triggered":
				if trigger.has("pattern") and trigger.pattern == pattern_name:
					return true
	return false