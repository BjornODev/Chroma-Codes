# =========================
# PEG INVENTORY INTEGRATION NOTES
# =========================


# =========================
# 1. AUTOLOAD
# =========================
# Add PegInventoryManager.gd as autoload named "PegInventoryManager"


# =========================
# 2. CALL reset_for_new_run IN RunProgressionManager
# =========================
# In RunProgressionManager.start_new_run() add:
#	PegInventoryManager.reset_for_new_run()


# =========================
# 3. UPDATE Phys_Peg.gd (hand stack pegs only, not placed pegs)
# =========================
# Replace the counter logic — instead of counting up as pegs placed,
# the counter now displays PegInventoryManager.get_count(peg_id)
#
# Add to _ready() of stack pegs:
#	PegInventoryManager.connect("peg_count_changed", _on_count_changed)
#	_update_counter_display()
#
# New functions:
#
# func _on_count_changed(color_id: int, new_count: int, old_count: int):
#	if color_id != peg_id:
#		return
#	_animate_counter(old_count, new_count)
#
# func _animate_counter(from_val: int, to_val: int):
#	var step = 1 if to_val > from_val else -1
#	var current = from_val
#	var total_steps = abs(to_val - from_val)
#	if total_steps == 0:
#		counter.text = str(to_val)
#		return
#
#	# Ramp speed — faster as it progresses
#	var base_interval := 0.08
#	var min_interval := 0.015
#
#	while current != to_val:
#		current += step
#		counter.text = str(current)
#		var progress = 1.0 - (float(abs(to_val - current)) / float(total_steps))
#		var interval = lerp(base_interval, min_interval, progress)
#		await get_tree().create_timer(interval).timeout
#
#	_update_greyed_state(to_val)
#
# func _update_counter_display():
#	var count = PegInventoryManager.get_count(peg_id)
#	counter.text = str(count)
#	_update_greyed_state(count)
#
# func _update_greyed_state(count: int):
#	if count <= 0:
#		modulate = Color(0.4, 0.4, 0.4, 1.0)
#	else:
#		modulate = Color.WHITE


# =========================
# 4. UPDATE PlayerHand.gd click-to-spawn logic
# =========================
# When a hand stack is clicked and a draggable peg is spawned:
# - Check PegInventoryManager.get_count(peg_id) > 0
# - If count > 0: spawn peg, call PegInventoryManager.remove_peg(peg_id)
# - If count == 0: call _on_empty_stack_clicked()
#
# func _on_empty_stack_clicked():
#	# Deal damage and refill all stacks
#	BoardManager.apply_damage(PegInventoryManager.refill_damage)
#	PegInventoryManager.refill_all_stacks()
#	AudioLoader.play_sound("damage")
#
# Also handle returning pegs to hand:
# When a peg is dropped back onto the hand or removed from a slot,
# call PegInventoryManager.return_peg(peg_id) to restore the count


# =========================
# 5. NEW KEYWORDS IN KeywordEngine
# =========================
# Add these keyword cases to apply_keyword():
#
# "AddPegsColor":
#	# payload must include "color_id"
#	var color_id = payload.get("color_id", 1)
#	PegInventoryManager.add_pegs_to_color(color_id, value)
#
# "AddPegsAll":
#	PegInventoryManager.add_pegs_to_all(value)
#
# "RemovePegsColor":
#	var color_id = payload.get("color_id", 1)
#	PegInventoryManager.remove_pegs_from_color(color_id, value)
#
# "RemovePegsAll":
#	PegInventoryManager.remove_pegs_from_all(value)


# =========================
# 6. HOVER WARNING ON EMPTY STACKS
# =========================
# In Phys_Peg.gd add mouse_entered/exited handlers that flash
# the peg red when empty:
#
# func _on_mouse_entered():
#	if PegInventoryManager.is_empty(peg_id):
#		modulate = Color("#FF4444")
#
# func _on_mouse_exited():
#	_update_greyed_state(PegInventoryManager.get_count(peg_id))


# =========================
# 7. PEG RETURNS ON REPLACE / CLEAR
# =========================
# When a peg is replaced or cleared from the board:
# - The removed peg should return to its stack
# - Call PegInventoryManager.return_peg(removed_peg.peg_id)
# This happens in KeywordEngine Replace and Clear logic or wherever
# pegs are removed from SnapZones
