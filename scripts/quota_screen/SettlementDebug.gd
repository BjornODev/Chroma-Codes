extends Node
class_name SettlementDebug

# =========================
# SETTLEMENT DEBUG TOOLKIT
# Attach to (or instance under) MapCompleteScreen to inspect and control the
# quota settlement. Provides:
#   - Scenario injection (force exact quotas / pegs / multipliers / HP)
#   - Full calculation dump (timeline + final state) BEFORE animation
#   - Playback control (skip delay, pause, step, speed)
#   - On-screen live overlay
#   - Preset scenarios for common cases (win, death, overshoot, big numbers)
#
# Toggle DEBUG_ENABLED off to disable everything in one place.
# =========================

# =========================
# >>> MASTER SWITCH <<<
# DEBUG_ENABLED controls the debug extras (console dump, on-screen overlay,
# step/pause keys) AND whether the override below is applied.
# Set to false for a clean release build.
# =========================
const DEBUG_ENABLED := false

# When true, apply_overrides() writes the OVERRIDE_* values below directly into
# the real managers as the map-complete screen loads. The screen then runs
# EXACTLY as it would in normal play, just with the values you chose. Nothing is
# faked or guarded — these become the real values.
const OVERRIDE_VALUES := true

# --- Override values (written into the real managers if OVERRIDE_VALUES) ---
const OVERRIDE_QUOTAS := {"red": 20, "purple": 12}
const OVERRIDE_SCORE_PEGS := {"red": 5, "purple": 5}
const OVERRIDE_HAND_PEGS := {"red": 10, "yellow": 10, "green": 10, "white": 10, "purple": 10, "orange": 10}
const OVERRIDE_MULTIPLIERS := {"red": 1, "purple": 2}
const OVERRIDE_HP := 5

const COLOR_TO_PEG_ID := {"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6}


# Writes the OVERRIDE_* values straight into the real managers. Call this FIRST
# in the map-complete screen's _ready, before anything reads the values.
static func apply_overrides() -> void:
	if not (DEBUG_ENABLED and OVERRIDE_VALUES):
		return

	# Quotas
	RunProgressionManager.peg_quotas = OVERRIDE_QUOTAS.duplicate()

	# Score pegs
	for c in OVERRIDE_SCORE_PEGS.keys():
		ScoreManager.earned_score_pegs[c] = OVERRIDE_SCORE_PEGS[c]

	# Hand pegs
	for c in OVERRIDE_HAND_PEGS.keys():
		PegInventoryManager.set_count(COLOR_TO_PEG_ID[c], OVERRIDE_HAND_PEGS[c])

	# Multipliers (board-visit counts)
	for c in OVERRIDE_MULTIPLIERS.keys():
		MapManager.board_color_activation_counts[c] = OVERRIDE_MULTIPLIERS[c]

	# HP
	RunProgressionManager.player_health = OVERRIDE_HP

	print("[SettlementDebug] Overrides applied to real managers.")

# --- Playback controls ---
const SKIP_DELAY := false        # skip the 3s pre-settlement wait
const SPEED_MULTIPLIER := 1.0    # >1 faster, <1 slower (scales all timing)
const STEP_MODE := false         # advance one event per key press (see _input)
const STEP_KEY := KEY_SPACE
const DUMP_TIMELINE := true      # print the full event timeline at start
const SHOW_OVERLAY := true       # draw the live on-screen state overlay
const VERBOSE_EVENTS := false    # print each event as it plays
const FINISH_HOLD := 0.5         # seconds to hold the finished screen before auto-advancing

# --- Step-mode signalling ---
var _step_requested := false
var _paused := false


# =========================
# GATHER INPUTS
# Reads the current values from the real managers. If OVERRIDE_VALUES is on,
# apply_overrides() has already written your chosen values into those managers,
# so this reads them back exactly as normal play would.
# =========================

static func gather_inputs() -> Dictionary:
	var colors = ["red", "yellow", "green", "white", "purple", "orange"]
	var color_to_id = {"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6}

	var quotas := {}
	for c in RunProgressionManager.peg_quotas.keys():
		quotas[c] = RunProgressionManager.peg_quotas[c]
	var score := {}
	var hand := {}
	var mult := {}
	for c in colors:
		score[c] = ScoreManager.earned_score_pegs.get(c, 0)
		hand[c] = PegInventoryManager.get_count(color_to_id[c])
		mult[c] = MapManager.board_color_activation_counts.get(c, 0)
	return {
		"quotas": quotas, "score_pegs": score, "hand_pegs": hand,
		"multipliers": mult, "hp": RunProgressionManager.player_health,
	}


# =========================
# CALCULATION DUMP
# Print a full, readable report of the computed settlement before it animates.
# =========================

static func dump_settlement(inputs: Dictionary, settlement) -> void:
	if not DEBUG_ENABLED:
		return
	print("\n========== SETTLEMENT DEBUG DUMP ==========")
	print("INPUTS:")
	print("  quotas      = ", inputs["quotas"])
	print("  multipliers = ", inputs["multipliers"])
	print("  score_pegs  = ", inputs["score_pegs"])
	print("  hand_pegs   = ", inputs["hand_pegs"])
	print("  hp          = ", inputs["hp"])
	print("OUTCOME:")
	print("  quota_met   = ", settlement.quota_met)
	print("  alive       = ", settlement.alive)
	print("  damage      = ", settlement.damage_taken)
	print("  final_hp    = ", settlement.final_hp)
	print("  final_quotas= ", settlement.final_quotas)
	print("  final_score = ", settlement.final_score_pegs)
	print("  final_hand  = ", settlement.final_hand_pegs)
	print("  event_count = ", settlement.events.size())

	if DUMP_TIMELINE:
		print("TIMELINE:")
		var idx := 0
		for e in settlement.events:
			print("  [%3d] %s" % [idx, _format_event(e)])
			idx += 1

	# Sanity checks
	_run_sanity_checks(inputs, settlement)
	print("===========================================\n")


static func _format_event(e: Dictionary) -> String:
	match e.get("type", ""):
		"score":
			return "SCORE  %-7s split x%d, quota -%d" % [e["color"], e["flyers"], e["ticks"]]
		"hand":
			return "HAND   %-7s quota -%d" % [e["color"], e["ticks"]]
		"damage":
			return "DAMAGE %-7s -> HP %d (refill)" % [e["color"], e["hp"]]
		"dead":
			return "DEAD   (HP reached 0)"
	return str(e)


# Independent verification: re-tally the timeline and confirm it matches outputs.
static func _run_sanity_checks(inputs: Dictionary, settlement) -> void:
	print("SANITY CHECKS:")

	# 1. Total quota ticks should equal starting quota minus final quota (per color)
	var ticks_by_color := {}
	var damage_count := 0
	for e in settlement.events:
		var t = e.get("type", "")
		if t == "score" or t == "hand":
			var c = e["color"]
			ticks_by_color[c] = ticks_by_color.get(c, 0) + e["ticks"]
		elif t == "damage":
			damage_count += 1

	var ok := true
	for c in inputs["quotas"].keys():
		var start_q = inputs["quotas"][c]
		var final_q = settlement.final_quotas.get(c, start_q)
		var paid = ticks_by_color.get(c, 0)
		var expected_paid = start_q - final_q
		var mark = "OK" if paid == expected_paid else "MISMATCH"
		if paid != expected_paid:
			ok = false
		print("  %-7s paid=%d  expected=%d  [%s]" % [c, paid, expected_paid, mark])

	# 2. Damage events should match reported damage
	var dmg_mark = "OK" if damage_count == settlement.damage_taken else "MISMATCH"
	if damage_count != settlement.damage_taken:
		ok = false
	print("  damage events=%d  reported=%d  [%s]" % [damage_count, settlement.damage_taken, dmg_mark])

	# 3. HP arithmetic
	var hp_mark = "OK" if (inputs["hp"] - settlement.damage_taken) == settlement.final_hp else "MISMATCH"
	if (inputs["hp"] - settlement.damage_taken) != settlement.final_hp:
		ok = false
	print("  hp %d - dmg %d = %d  reported=%d  [%s]" % [inputs["hp"], settlement.damage_taken, inputs["hp"] - settlement.damage_taken, settlement.final_hp, hp_mark])

	print("  ALL CHECKS: ", "PASS" if ok else "*** FAIL ***")


# =========================
# PLAYBACK CONTROL HELPERS
# =========================

func get_delay() -> float:
	return 0.0 if SKIP_DELAY else 0.5


func scaled(t: float) -> float:
	if SPEED_MULTIPLIER <= 0.0:
		return t
	return t / SPEED_MULTIPLIER


# In step mode, await this before each event. Returns when the user presses STEP_KEY.
func await_step(tree: SceneTree) -> void:
	if not (DEBUG_ENABLED and STEP_MODE):
		return
	_step_requested = false
	while not _step_requested:
		await tree.process_frame
	_step_requested = false


func _input(event: InputEvent) -> void:
	if not DEBUG_ENABLED:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == STEP_KEY:
			_step_requested = true
		elif event.keycode == KEY_P:
			_paused = not _paused
			print("[SettlementDebug] paused = ", _paused)


# =========================
# PRESET SCENARIOS (for quick manual swapping)
# Copy any of these into the OVERRIDE_* consts above.
# =========================
#
#  EASY WIN (lots of score pegs, high multipliers):
#    quotas {"red":20}  score {"red":30}  mult {"red":3}  -> met, 0 dmg
#
#  HAND FALLBACK (score runs out, takes damage):
#    quotas {"red":40} score {"red":5} hand {"red":10} mult {"red":1} hp 5
#    -> uses 5 score + 35 hand = 3 refills (3 dmg), met, hp 2
#
#  DEATH (not enough, HP runs out):
#    quotas {"red":100} score {"red":0} hand {"red":10} mult {"red":1} hp 3
#    -> 3 refills then dead, quota_met false
#
#  MULTI-COLOR OVERSHOOT (multiplier overshoots last tick):
#    quotas {"red":5,"green":7} score {"red":10,"green":10} mult {"red":3,"green":2}
#    -> red: 2 pegs (3+2), green: 4 pegs (2+2+2+1), met, 0 dmg