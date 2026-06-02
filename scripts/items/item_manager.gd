extends Node2D

var player_items = []
var all_items : Array[ItemData] = []
var items_by_name := {}

var _prev_panel_color_counts := {}

var color_counters := {}
var feedback_counters := {}
var prev_color_counters := {}
var prev_feedback_counters := {}

signal color_counters_updated(counters: Dictionary)
signal feedback_counters_updated(counters: Dictionary)

var turn_event_queue = []
var is_processing_turn_events = false

@onready var popup_manager = PopUpText

signal items_changed
signal active_item_cap_reached(new_item: ItemData)

var board_reference
var peg_manager_reference


func _ready():
	load_items()


func set_board_context(board, peg_manager):
	board_reference = board
	peg_manager_reference = peg_manager


# =========================
# LOAD ITEMS
# =========================

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
			var path = "res://data/items/" + file_name
			var item : ItemData = ResourceLoader.load(path)
			if item:
				all_items.append(item)
				items_by_name[item.item_name] = item
			else:
				push_warning("Failed to load item: " + path)

	print("Loaded items: ", all_items.size())


# =========================
# BOARD RESET
# =========================

func reset_for_new_board():
	color_counters.clear()
	feedback_counters.clear()
	prev_color_counters.clear()
	prev_feedback_counters.clear()
	_prev_panel_color_counts.clear()
	turn_event_queue.clear()


# =========================
# EVENT EMISSION
# =========================

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
		_process_entity_event_triggers(item, event_name, payload)

	for modifier in BoardModifierEngine.active_modifiers:
		if modifier in BoardModifierEngine.disabled_modifiers_this_round:
			continue
		_process_entity_event_triggers(modifier, event_name, payload)


# =========================
# ROW SUBMISSION
# =========================

func process_row_submission(guess, result):
	_update_color_counters(guess)
	_update_feedback_counters(result)
	_check_threshold_triggers()


func _update_color_counters(guess):
	for value in guess:
		if value == 0 or value < 0:
			continue
		var color = _color_id_to_name(value)
		if not color_counters.has(color):
			color_counters[color] = 0
		color_counters[color] += 1
	emit_signal("color_counters_updated", color_counters.duplicate())


func _update_feedback_counters(result):
	var black = result[0]
	var white = result[1]
	if not feedback_counters.has("feedback_black"):
		feedback_counters["feedback_black"] = 0
	if not feedback_counters.has("feedback_white"):
		feedback_counters["feedback_white"] = 0
	feedback_counters["feedback_black"] += black
	feedback_counters["feedback_white"] += white
	emit_signal("feedback_counters_updated", feedback_counters.duplicate())


func _check_threshold_triggers():
	var snap_prev_color = prev_color_counters.duplicate()
	var snap_prev_feedback = prev_feedback_counters.duplicate()

	for item in player_items:
		_process_entity_threshold_triggers(item, snap_prev_color, snap_prev_feedback)

	for modifier in BoardModifierEngine.active_modifiers:
		if modifier in BoardModifierEngine.disabled_modifiers_this_round:
			continue
		_process_entity_threshold_triggers(modifier, snap_prev_color, snap_prev_feedback)

	prev_color_counters = color_counters.duplicate()
	prev_feedback_counters = feedback_counters.duplicate()


# =========================
# TRIGGER PROCESSING
# =========================

func _process_entity_event_triggers(entity, event_name, payload):
	var triggers = _get_entity_triggers(entity)
	var conditions = _get_conditions(triggers)

	for trigger in triggers:
		if not _is_event_trigger(trigger):
			continue
		if trigger.event != event_name:
			continue
		if not _event_trigger_matches(entity, trigger, event_name, payload):
			continue
		if not _all_conditions_match(conditions):
			continue
		_apply_entity_effects(entity, payload)


func _process_entity_threshold_triggers(entity, snap_prev_color, snap_prev_feedback):
	var triggers = _get_entity_triggers(entity)
	var conditions = _get_conditions(triggers)

	for trigger in triggers:
		if not _is_threshold_trigger(trigger):
			continue
		var times = _threshold_trigger_count(trigger, snap_prev_color, snap_prev_feedback)
		if times > 0:
			if not _all_conditions_match(conditions):
				continue
			for i in range(times):
				_apply_entity_effects(entity, {})


func _get_entity_triggers(entity) -> Array:
	if entity is ItemData:
		return entity.triggers
	if entity is ModifierData:
		return entity.trigger
	return []


func _is_event_trigger(trigger: Dictionary) -> bool:
	return trigger.has("event")


func _is_condition(trigger: Dictionary) -> bool:
	return trigger.has("condition")


func _is_threshold_trigger(trigger: Dictionary) -> bool:
	return not trigger.has("event") and not trigger.has("condition")


func _get_conditions(triggers: Array) -> Array:
	var result := []
	for t in triggers:
		if _is_condition(t):
			result.append(t)
	return result


# =========================
# CONDITION EVALUATION
# AND conditions: all must pass
# OR conditions: at least one must pass (if any OR conditions exist)
# Both rules apply independently — AND group all pass AND OR group has at least one pass
# =========================

func _all_conditions_match(conditions: Array) -> bool:
	var and_conditions := []
	var or_conditions := []

	for c in conditions:
		if c.get("mode", "and") == "or":
			or_conditions.append(c)
		else:
			and_conditions.append(c)

	# All AND conditions must pass
	for c in and_conditions:
		if not _condition_matches(c):
			return false

	# If any OR conditions exist, at least one must pass
	if or_conditions.size() > 0:
		var any_or_passes := false
		for c in or_conditions:
			if _condition_matches(c):
				any_or_passes = true
				break
		if not any_or_passes:
			return false

	return true


func _condition_matches(condition: Dictionary) -> bool:
	var comparison = condition.get("comparison", ">=")
	var target = condition.get("value", 0)

	match condition.get("condition", ""):
		"peg_count":
			var color_id = _color_name_to_id(condition.get("color", "red"))
			var current = PegInventoryManager.get_count(color_id)
			return _compare(current, comparison, target)

		"health":
			var current = RunProgressionManager.player_health
			return _compare(current, comparison, target)

		"dollars":
			var current = RunProgressionManager.dollars
			return _compare(current, comparison, target)

		"dollar_lit":
			var current = DollarManager.get_earned_dollars()
			return _compare(current, comparison, target)

		"wild_pegs":
			var current = PegInventoryManager.wild_pegs_owned
			return _compare(current, comparison, target)

	return true


func _compare(current: int, comparison: String, target: int) -> bool:
	match comparison:
		">": return current > target
		">=": return current >= target
		"<": return current < target
		"<=": return current <= target
		"==": return current == target
		"!=": return current != target
	return false


# =========================
# EVENT TRIGGER MATCHING
# =========================

func _event_trigger_matches(entity, trigger, event_name, payload) -> bool:
	if trigger.has("pattern"):
		if payload.get("pattern_name") != trigger.pattern:
			return false

	if trigger.has("index"):
		if payload.get("index") != trigger.index:
			return false

	if trigger.has("color") and trigger.has("count") and event_name == "panel_activated":
		var color_counts = payload.get("color_counts", {})
		var required_color = trigger["color"]
		var required_count = trigger["count"]
		var current = color_counts.get(required_color, 0)
		var entity_key = _get_entity_key(entity)
		var prev = _get_prev_color_count(entity_key, required_color)
		var prev_multiple = int(prev / required_count)
		var curr_multiple = int(current / required_count)
		if curr_multiple <= prev_multiple:
			return false
		_set_prev_color_count(entity_key, required_color, current)

	if event_name == "dollar_changed":
		if trigger.has("dollar_index"):
			if payload.get("dollar_index") != trigger.dollar_index:
				return false
		if trigger.has("state"):
			if payload.get("state") != trigger.state:
				return false

	if event_name == "health_threshold":
		if trigger.has("threshold"):
			var threshold = trigger["threshold"]
			var old_health = payload.get("old_health", -1)
			var new_health = payload.get("new_health", -1)
			var direction = trigger.get("direction", "down")
			match direction:
				"down":
					if not (old_health >= threshold and new_health < threshold):
						return false
				"up":
					if not (old_health < threshold and new_health >= threshold):
						return false

	if event_name == "peg_threshold":
		if trigger.has("color") and trigger.has("threshold"):
			var trigger_color_id = _color_name_to_id(trigger["color"])
			if payload.get("color_id") != trigger_color_id:
				return false
			var threshold = trigger["threshold"]
			var old_count = payload.get("old_count", -1)
			var new_count = payload.get("new_count", -1)
			var direction = trigger.get("direction", "down")
			match direction:
				"down":
					if not (old_count >= threshold and new_count < threshold):
						return false
				"up":
					if not (old_count < threshold and new_count >= threshold):
						return false

	if event_name == "feedback_count":
		if trigger.has("feedback_type") and trigger.has("count"):
			var fb_type = trigger["feedback_type"]
			var required = trigger["count"]
			var black = payload.get("black", 0)
			var white = payload.get("white", 0)
			match fb_type:
				"black":
					if black != required:
						return false
				"white":
					if white != required:
						return false
				"none":
					if black != 0 or white != 0:
						return false

	if event_name == "Damage Taken":
		if trigger.has("source"):
			if payload.get("source", "normal") != trigger.source:
				return false

	return true


# =========================
# THRESHOLD TRIGGER MATCHING
# =========================

func _threshold_trigger_count(trigger_block, snap_prev_color, snap_prev_feedback) -> int:
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


# =========================
# EFFECT DISPATCH
# =========================

func _apply_entity_effects(entity, event_data):
	if entity is ItemData:
		_apply_item_keywords(entity, event_data)
	elif entity is ModifierData:
		_apply_modifier_effect(entity)


func _apply_item_keywords(item: ItemData, event_data: Dictionary):
	print("Applying effects for:", item.item_name, "keywords:", item.keywords)
	for keyword in item.keywords.keys():
		print("Applying keyword:", keyword, "value:", item.keywords[keyword])
		KeywordEngine.apply_keyword(keyword, item.keywords[keyword], event_data)


func _apply_modifier_effect(modifier: ModifierData):
	if modifier.get_scaled_effect() != null:
		BoardModifierEngine.apply_effect(board_reference, modifier.get_scaled_effect())


# =========================
# UTILITIES
# =========================

func _get_entity_key(entity) -> String:
	if entity is ItemData:
		return "item_" + entity.item_name
	if entity is ModifierData:
		return "mod_" + entity.modifier_name
	return "unknown"


func _color_name_to_id(color_name: String) -> int:
	match color_name:
		"red": return 1
		"yellow": return 2
		"green": return 3
		"white": return 4
		"purple": return 5
		"orange": return 6
	return 0


func _color_id_to_name(id) -> String:
	match id:
		1: return "red"
		2: return "yellow"
		3: return "green"
		4: return "white"
		5: return "purple"
		6: return "orange"
	return "unknown"


func _get_prev_color_count(entity_key: String, color: String) -> int:
	return _prev_panel_color_counts.get(entity_key + "_" + color, 0)


func _set_prev_color_count(entity_key: String, color: String, value: int):
	_prev_panel_color_counts[entity_key + "_" + color] = value


# =========================
# PATTERN MARKER CHECK
# =========================

func has_item_trigger_for_pattern(pattern_name):
	for item in player_items:
		for trigger in item.triggers:
			if trigger.has("event") and trigger.event == "pattern_triggered":
				if trigger.has("pattern") and trigger.pattern == pattern_name:
					return true
	return false


# =========================
# ITEM LIFECYCLE
# =========================

func give_item_by_name(name: String):
	if not items_by_name.has(name):
		return
	var item = items_by_name[name]
	if item.is_active:
		var active_count = player_items.filter(func(i): return i.is_active).size()
		if active_count >= 5:
			emit_signal("active_item_cap_reached", item)
			return
	player_items.append(item)
	if item.is_active:
		ActiveItemManager.add_item(item)
	RunProgressionManager.reward_pool_items.erase(item)
	emit_signal("items_changed")

