extends Node

signal chaos_changed(new_value: int)
signal dollar_lost(threshold_index: int)
signal dollar_flickered(threshold_index: int)
signal dollars_reset

const MAX_CHAOS := 30
const CHAOS_PER_DAMAGE := 3
const CHAOS_CLEAR_ON_BOARD := 5

# Thresholds are OVER/UNDER — if chaos > threshold, dollar is lost
# Stored as the segment count after which the dollar is lost
const DOLLAR_THRESHOLDS := [5, 10, 15, 20, 25]

# At the top of ChaosManager — easy to tune
const EVENT_TRIGGER_CHANCE := 0.4  # 40% chance an event fires each turn

const CHAOS_EVENTS := {
	"low": [        # chaos 11-15
		"flip_feedback",
#		"hide_pegs",
	],
	"low_mid": [        # chaos 16-20
		"flip_feedback",
		"hide_pegs",
	],
	"high_mid": [        # chaos 21-25
		"flip_feedback",
		"hide_pegs",
	],
	"high": [       # chaos 26-30
#		"hide_pegs",
#		"shift_code",
		"deal_damage",
	]
}

var chaos := 0
var dollars := 5
var dollars_active := [true, true, true, true, true]

var board_reference
var peg_manager_reference
var popup_reference


func set_context(board, peg_manager, popup):
	board_reference = board
	peg_manager_reference = peg_manager
	popup_reference = popup


# =========================
# ADDING CHAOS
# =========================

func add_chaos(amount: int):
	var old_chaos = chaos
	chaos = min(chaos + amount, MAX_CHAOS)
	
	if chaos != old_chaos:
		_check_dollar_thresholds(old_chaos, chaos)
		emit_signal("chaos_changed", chaos)


func add_chaos_from_damage():
	add_chaos(CHAOS_PER_DAMAGE)


# =========================
# REMOVING CHAOS
# =========================

func cleanse_chaos(amount: int):
	var old_chaos = chaos
	chaos = max(chaos - amount, 0)
	
	if chaos != old_chaos:
		# Reactivate any dollars that are now below threshold
		for i in range(DOLLAR_THRESHOLDS.size()):
			if chaos <= DOLLAR_THRESHOLDS[i] and not dollars_active[i]:
				dollars_active[i] = true
		emit_signal("chaos_changed", chaos)
		emit_signal("dollars_reset")


func cleanse_on_board_clear():
	cleanse_chaos(CHAOS_CLEAR_ON_BOARD)
	# Reset dollars but immediately re-check against remaining chaos
	dollars_active = [true, true, true, true, true]
	for i in range(DOLLAR_THRESHOLDS.size()):
		if chaos > DOLLAR_THRESHOLDS[i]:
			dollars_active[i] = false
	emit_signal("dollars_reset")


# =========================
# DOLLAR THRESHOLDS
# =========================

func _check_dollar_thresholds(old_value: int, new_value: int):
	for i in range(DOLLAR_THRESHOLDS.size()):
		var threshold = DOLLAR_THRESHOLDS[i]
		if old_value <= threshold and new_value > threshold:
			if dollars_active[i]:
				dollars_active[i] = false
				emit_signal("dollar_flickered", i)


func get_earned_dollars() -> int:
	var count = 0
	for active in dollars_active:
		if active:
			count += 1
	return count


func reset_dollars():
	dollars_active = [true, true, true, true, true]
	# Re-check current chaos against all thresholds
	for i in range(DOLLAR_THRESHOLDS.size()):
		if chaos > DOLLAR_THRESHOLDS[i]:
			dollars_active[i] = false
	emit_signal("dollars_reset")


# =========================
# CHAOS EVENTS
# =========================

func fire_chaos_event():
	print("CHAOS EVENT FIRED: " + str(chaos))
	if chaos <= 10:
		return
	
	if randf() > EVENT_TRIGGER_CHANCE:
		return
	
	var pool: Array
	if chaos <= 11:
		pool = CHAOS_EVENTS["low"]
	elif chaos <= 16:
		pool = CHAOS_EVENTS["low_mid"]
	elif  chaos <= 21:
		pool = CHAOS_EVENTS["high_mid"]
	else:
		pool = CHAOS_EVENTS["high"]
	
	var chosen = pool[randi() % pool.size()]
	
	print("Pool selected:", pool, "chosen:", chosen)
	
	match chosen:
		"flip_feedback":
			_event_flip_feedback()
		"hide_pegs":
			_event_hide_peg_colors()
		"shift_code":
			_event_shift_code_peg()
		"deal_damage":
			_event_deal_damage()


func _event_flip_feedback():
	if not board_reference:
		return
	
	var cur_row = board_reference.peg_manager_reference.cur_row
	if cur_row <= 0:
		return
	
	var target_row = randi() % cur_row
	
	for child in board_reference.get_children():
		if child is Feedback_Grid and child.row == target_row:
			var pegs = _get_all_feedback_pegs(child)
			for peg in pegs:
				peg.set_color(1 - peg.color_id)
			break
	
	if popup_reference:
		popup_reference.show_popup(
			"[center][b][color=#FF6B00]CHAOS: FEEDBACK FLIPPED[/color][/b][/center]"
		)


func _get_all_feedback_pegs(node) -> Array:
	var pegs = []
	for child in node.get_children():
		if child is Feedback_Peg:
			pegs.append(child)
		else:
			pegs.append_array(_get_all_feedback_pegs(child))
	return pegs





func _event_hide_peg_colors():
	if not board_reference:
		return
	
	var eligible := []
	
	for child in board_reference.get_children():
		if child is SnapZone and child.row < board_reference.peg_manager_reference.cur_row:
			var peg = child.peg_in_slot
			if peg == null:
				continue
			if peg.get("is_spike") or peg.get("is_obscure"):
				continue
			if peg.peg_sprite2D.modulate == Color(0.2, 0.2, 0.2, 1.0):
				continue
			eligible.append(peg)
	
	if eligible.is_empty():
		return
	
	eligible.shuffle()
	
	var count = randi_range(3, 5)
	count = min(count, eligible.size())
	
	for i in range(count):
		eligible[i].peg_sprite2D.modulate = Color(0.2, 0.2, 0.2, 1.0)
	
	if popup_reference:
		popup_reference.show_popup(
			"[center][b][color=#FF6B00]CHAOS: OBSCURED[/color][/b][/center]"
		)



func _event_shift_code_peg():
	if not board_reference:
		return
	
	var code = board_reference.secret_code
	if code.is_empty():
		return
	
	var index = randi() % code.size()
	var old_val = code[index]
	var new_val = old_val
	
	while new_val == old_val:
		new_val = randi_range(1, 6)
	
	board_reference.secret_code[index] = new_val
	
	var display = board_reference.get_node("../SecretCodeDisplay")
	if display and index < display.pegs.size():
		display.pegs[index].set_color_from_id(new_val)
	
	if popup_reference:
		popup_reference.show_popup(
			"[center][b][color=#FF0000]CHAOS: CODE SHIFTED[/color][/b][/center]"
		)



func _event_deal_damage():
	if not board_reference:
		return
	
	board_reference.apply_damage(1)
	
	if popup_reference:
		popup_reference.show_popup(
			"[center][b][color=#FF0000]CHAOS: DAMAGE[/color][/b][/center]"
		)
