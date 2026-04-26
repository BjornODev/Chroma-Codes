extends Node

# =========================
# DOLLAR MANAGER
# Replaces chaos-based dollar system with damage-avoidance system
# Every board starts with 5 lit dollars
# Damage unlights left to right (index 0 first, then 1, 2, 3, 4)
# Relight goes right to left (rightmost unlit first)
# =========================

signal dollar_flickered(index: int)
signal dollar_relit(index: int)
signal dollars_reset

const DOLLAR_COUNT := 5

var dollars_active := [true, true, true, true, true]


func reset_for_new_board():
	dollars_active = [true, true, true, true, true]
	emit_signal("dollars_reset")


# =========================
# LOSING DOLLARS (on damage)
# Left to right — index 0 first, then 1, 2, 3, 4
# =========================

func lose_dollar_from_damage():
	for i in range(dollars_active.size() -1, -1, -1):
		if dollars_active[i]:
			dollars_active[i] = false
			emit_signal("dollar_flickered", i)
			return


# =========================
# RELIGHTING DOLLARS (via items)
# Right to left — rightmost unlit first
# =========================

func relight_dollar():
	for i in range(dollars_active.size()):
		if not dollars_active[i]:
			dollars_active[i] = true
			emit_signal("dollar_relit", i)
			return


func relight_multiple(amount: int):
	for i in range(amount):
		relight_dollar()


# =========================
# QUERIES
# =========================

func get_earned_dollars() -> int:
	var count = 0
	for active in dollars_active:
		if active:
			count += 1
	return count
