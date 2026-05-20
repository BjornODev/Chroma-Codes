extends Node

# =========================
# PEG INVENTORY MANAGER
# Tracks finite peg counts per color that persist between boards
# =========================

signal peg_count_changed(color_id: int, new_count: int, old_count: int)
signal stack_refilled

# Tunable values — can be modified by items/difficulty
var starting_peg_count := 15
var refill_amount := 3
var refill_damage := 1

# peg_counts: { color_id: int }
var peg_counts: Dictionary = {
	1: 15,  # red
	2: 15,  # yellow
	3: 15,  # green
	4: 15,  # white
	5: 15,  # purple
	6: 15,  # orange
}


func reset_for_new_run():
	for color_id in peg_counts.keys():
		peg_counts[color_id] = starting_peg_count


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


# =========================
# REFILL
# =========================

func refill_all_stacks():
	for color_id in peg_counts.keys():
		var old_count = peg_counts[color_id]
		set_count(color_id, old_count + refill_amount)
	emit_signal("stack_refilled")
