extends Node

# =========================
# ACTIVE ITEM MANAGER
# Tracks charge state for all active items the player holds
# =========================

const MAX_ACTIVE_ITEMS := 5

signal charge_updated(item_name: String, current: float, maximum: float)
signal item_activated(item_name: String)
signal active_items_changed

# charge_state: { item_name: float }
var charge_state: Dictionary = {}

var board_reference = null
var peg_manager_reference = null
var popup_reference = null

# Tracks how many active items have been activated this run
var total_activations := 0


func set_context(board, peg_manager, popup):
	board_reference = board
	peg_manager_reference = peg_manager
	popup_reference = popup


# =========================
# CHARGE TRACKING
# =========================

func add_charge(stat: String, amount: float = 1.0):
	for item in ItemManager.player_items:
		if not item.is_active:
			continue
		if not ItemManager.player_items.has(item):
			continue
		_process_charge_for_item(item, stat, amount)


func _process_charge_for_item(item: ItemData, stat: String, amount: float):
	if not charge_state.has(item.item_name):
		charge_state[item.item_name] = 0.0

	if charge_state[item.item_name] >= item.charge_max:
		return

	for condition in item.charge_conditions:
		if condition.get("stat", "") == stat:
			var gain = amount * condition.get("amount", 1.0)
			charge_state[item.item_name] = min(
				charge_state[item.item_name] + gain,
				item.charge_max
			)
			emit_signal("charge_updated",
				item.item_name,
				charge_state[item.item_name],
				item.charge_max
			)
			break


func is_fully_charged(item: ItemData) -> bool:
	return charge_state.get(item.item_name, 0.0) >= item.charge_max


func get_charge_fraction(item: ItemData) -> float:
	return charge_state.get(item.item_name, 0.0) / max(item.charge_max, 1.0)


# =========================
# ACTIVATION
# =========================

func try_activate(item: ItemData) -> bool:
	if not is_fully_charged(item):
		return false

	# Reset charge
	charge_state[item.item_name] = 0.0

	total_activations += 1

	# Notify other items that an active was activated
	add_charge("active_activated", 1.0)

	# Apply keywords
	for keyword in item.active_keywords.keys():
		KeywordEngine.apply_keyword(
			keyword,
			item.active_keywords[keyword],
			{}
		)

	emit_signal("item_activated", item.item_name)
	emit_signal("charge_updated", item.item_name, 0.0, item.charge_max)

	if popup_reference:
		popup_reference.show_popup(
			"[center][b][color=#FFD700]%s ACTIVATED[/color][/b][/center]" % item.item_name
		)

	return true


# =========================
# ITEM MANAGEMENT
# =========================

func add_item(item: ItemData):
	if not item.is_active:
		return
	charge_state[item.item_name] = 0.0
	emit_signal("active_items_changed")


func remove_item(item: ItemData):
	charge_state.erase(item.item_name)
	emit_signal("active_items_changed")


func reset_on_new_run():
	charge_state.clear()
	total_activations = 0
	emit_signal("active_items_changed")


# =========================
# STAT HOOKS
# These are called from BoardManager and KeywordEngine
# =========================

func on_damage_taken(amount: int):
	add_charge("damage_taken", float(amount))

func on_health_healed(amount: int):
	add_charge("health_healed", float(amount))

func on_peg_placed(peg_id: int):
	add_charge("pegs_placed_any", 1.0)
	match peg_id:
		1: add_charge("pegs_placed_red", 1.0)
		2: add_charge("pegs_placed_yellow", 1.0)
		3: add_charge("pegs_placed_green", 1.0)
		4: add_charge("pegs_placed_white", 1.0)
		5: add_charge("pegs_placed_purple", 1.0)
		6: add_charge("pegs_placed_orange", 1.0)

func on_row_submitted():
	add_charge("rows_submitted", 1.0)

func on_replace_used(replaces):
	add_charge("replace_used", replaces)

func on_feedback_received(blacks: int, whites: int):
	add_charge("black_pegs", float(blacks))
	add_charge("white_pegs", float(whites))
