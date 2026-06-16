extends RefCounted
class_name QuotaSettlement

# =========================
# QUOTA SETTLEMENT CALCULATOR
# Computes the ENTIRE outcome of paying down the map's quotas up front:
# final quota values, damage taken, win/loss, and an ordered event timeline
# the map-complete screen replays as animation so it feels live.
#
# Rules:
#  - Each quota color is paid down using score pegs of that color first.
#    A score peg splits into <multiplier> flyers; each flyer ticks the quota
#    down by 1. (multiplier = that color's board-visited count, min 1.)
#  - When score pegs run out, hand pegs of that color are used (NOT multiplied,
#    one tick each). When a color's hand count hits 0, the player takes 1 damage
#    and that color's hand refills to HAND_REFILL.
#  - A color stops once its quota reaches 0.
#  - If HP hits 0, settlement stops and the player loses.
# =========================

const HAND_REFILL := 10

const PEG_ID_TO_COLOR := {
	1: "red", 2: "yellow", 3: "green", 4: "white", 5: "purple", 6: "orange",
}
const COLOR_TO_PEG_ID := {
	"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6,
}

# Event types (each is a Dictionary in the timeline):
#  {type="score", color, flyers, ticks}   one score peg launched, splits into <flyers>, quota -<ticks>
#  {type="hand",  color, ticks}           one hand peg launched, quota -<ticks> (ticks always 1)
#  {type="damage", color, hp}             a hand color emptied: -1 HP, hand refilled
#  {type="dead"}                          HP hit 0, settlement ends in a loss

var events: Array = []
var quota_met: bool = false
var alive: bool = true
var damage_taken: int = 0
var final_hp: int = 0
var final_score_pegs: Dictionary = {}
var final_hand_pegs: Dictionary = {}
var final_quotas: Dictionary = {}


# quotas: { color: amount }
# multipliers: { color: int }   (board-visited counts; missing = 1)
# score_pegs: { color: int }    (ScoreManager.earned_score_pegs)
# hand_pegs: { color: int }     (current PegInventoryManager counts by color)
# hp: starting player health
func compute(quotas: Dictionary, multipliers: Dictionary, score_pegs: Dictionary, hand_pegs: Dictionary, hp: int) -> void:
	events.clear()
	damage_taken = 0
	alive = true

	# Work on copies so we can report final states
	var q := {}
	for c in quotas.keys():
		q[c] = quotas[c]
	var sp := {}
	for c in score_pegs.keys():
		sp[c] = score_pegs[c]
	var hand := {}
	for c in hand_pegs.keys():
		hand[c] = hand_pegs[c]

	var cur_hp := hp

	for color in q.keys():
		var remaining: int = q[color]
		var mult: int = max(1, int(multipliers.get(color, 1)))

		# Phase 1 — score pegs (multiplied)
		while remaining > 0 and sp.get(color, 0) > 0:
			sp[color] -= 1
			var ticks: int = min(mult, remaining)
			remaining -= ticks
			events.append({
				"type": "score", "color": color, "flyers": mult, "ticks": ticks,
			})

		# Phase 2 — hand pegs (not multiplied) with damage/refill
		var broke_out := false
		while remaining > 0:
			if hand.get(color, 0) <= 0:
				damage_taken += 1
				cur_hp -= 1
				hand[color] = HAND_REFILL
				events.append({"type": "damage", "color": color, "hp": cur_hp})
				if cur_hp <= 0:
					alive = false
					events.append({"type": "dead"})
					broke_out = true
					break
			hand[color] -= 1
			remaining -= 1
			events.append({"type": "hand", "color": color, "ticks": 1})

		q[color] = remaining
		if broke_out:
			break

	final_hp = cur_hp
	final_score_pegs = sp
	final_hand_pegs = hand
	final_quotas = q

	var all_met := true
	for c in q.keys():
		if q[c] > 0:
			all_met = false
			break
	quota_met = all_met and alive


# Helper: build a hand_pegs {color:int} dict from PegInventoryManager.
static func hand_pegs_from_inventory() -> Dictionary:
	var result := {}
	for peg_id in PEG_ID_TO_COLOR.keys():
		result[PEG_ID_TO_COLOR[peg_id]] = PegInventoryManager.get_count(peg_id)
	return result