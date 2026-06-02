extends Node

# =========================
# PEG INVENTORY MANAGER
# Tracks finite peg counts per color that persist between boards
# =========================

signal peg_count_changed(color_id: int, new_count: int, old_count: int)
signal stack_refilled

var starting_peg_count := 15
var refill_amount := 3
var refill_damage := 1
var wild_pegs_owned: int = 0

var peg_counts: Dictionary = {
	1: 15,
	2: 15,
	3: 15,
	4: 15,
	5: 15,
	6: 15,
}


func reset_for_new_run():
	for color_id in peg_counts.keys():
		peg_counts[color_id] = starting_peg_count
	wild_pegs_owned = 0


func get_count(color_id: int) -> int:
	return peg_counts.get(color_id, 0)


func is_empty(color_id: int) -> bool:
	return get_count(color_id) <= 0


func all_stacks_empty() -> bool:
	for color_id in peg_counts.keys():
		if peg_counts[color_id] > 0:
			return false
	return true


# =========================
# DECREMENT / INCREMENT
# =========================

func remove_peg(color_id: int) -> bool:
	var current = get_count(color_id)
	if current <= 0:
		return false
	set_count(color_id, current - 1)
	return true


func return_peg(color_id: int):
	var current = get_count(color_id)
	set_count(color_id, current + 1)


# =========================
# ADDING / REMOVING (from items/modifiers)
# =========================

func add_pegs_to_color(color_id: int, amount: int):
	var old_count = get_count(color_id)
	var new_count = old_count + amount
	set_count(color_id, new_count)


func add_pegs_to_all(amount: int):
	for color_id in peg_counts.keys():
		var old_count = peg_counts[color_id]
		set_count(color_id, old_count + amount)


func remove_pegs_from_color(color_id: int, amount: int):
	var old_count = get_count(color_id)
	var new_count = max(0, old_count - amount)
	set_count(color_id, new_count)


func remove_pegs_from_all(amount: int):
	for color_id in peg_counts.keys():
		var old_count = peg_counts[color_id]
		var new_count = max(0, old_count - amount)
		set_count(color_id, new_count)


# =========================
# SETTERS
# =========================

func set_count(color_id: int, new_count: int):
	var old_count = peg_counts.get(color_id, 0)
	new_count = max(0, new_count)
	peg_counts[color_id] = new_count
	emit_signal("peg_count_changed", color_id, new_count, old_count)

	# Emit threshold trigger on any change (up or down)
	# ItemManager filters by direction
	if new_count != old_count:
		ItemManager.emit_game_event("peg_threshold", {
			"color_id": color_id,
			"new_count": new_count,
			"old_count": old_count,
		})


# =========================
# REFILL
# =========================

func refill_all_stacks():
	for color_id in peg_counts.keys():
		var old_count = peg_counts[color_id]
		set_count(color_id, old_count + refill_amount)
	emit_signal("stack_refilled")


func add_wild_pegs(amount: int):
	wild_pegs_owned += amount


func consume_wild_peg() -> bool:
	if wild_pegs_owned <= 0:
		return false
	wild_pegs_owned -= 1
	return true


func return_wild_peg():
	wild_pegs_owned += 1