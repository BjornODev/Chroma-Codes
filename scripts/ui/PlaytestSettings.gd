extends Node

# =========================
# PLAYTEST SETTINGS (autoload "PlaytestSettings")
# Holds tunable values chosen in the playtest menu (toggled with Q) and applies
# them when a new game starts. Because several of the real values are consts in
# their managers, apply_to_new_run() overwrites the live state right after the
# run/map is generated, the same way the settlement debug override works.
# =========================

# Whether the playtest overrides are active. The menu sets this true when you
# press "Start New Game"; normal play leaves it false.
var enabled := false

# --- Tunable values (defaults match the game's normal values) ---
var starting_health := 5          # RunProgressionManager.player_health
var starting_pegs := 20           # per-color starting peg count
var clicked_refill := 5           # pegs gained from the activated panel's color
var adjacent_refill := 1          # pegs gained from each adjacent panel's color
var panels_remaining := 10        # how many panels can be activated per map
var base_quota := 50              # base quota total for map 1

const COLOR_TO_PEG_ID := {"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6}


# Call AFTER RunProgressionManager.start_new_run() and MapManager.start_run(),
# so the generated map state exists and we can overwrite it.
func apply_to_new_run() -> void:
	if not enabled:
		return

	# Health
	RunProgressionManager.player_health = starting_health

	# Starting pegs (all six colors)
	for c in COLOR_TO_PEG_ID.keys():
		PegInventoryManager.set_count(COLOR_TO_PEG_ID[c], starting_pegs)

	# Panel refill amounts. ACTIVATED/ADJACENT_PANEL_REFILL are consts in
	# MapManager, so we mirror them into override vars MapManager reads (see the
	# MapManager edit below). If those vars don't exist yet, this is a no-op.
	if "playtest_clicked_refill" in MapManager:
		MapManager.playtest_clicked_refill = clicked_refill
	if "playtest_adjacent_refill" in MapManager:
		MapManager.playtest_adjacent_refill = adjacent_refill
	MapManager.playtest_refill_override = true

	# Panels remaining for this map
	MapManager.panels_remaining = panels_remaining
	MapManager.emit_signal("panels_remaining_changed", panels_remaining)

	# Base quota: regenerate map 1's quotas using the override base. This sets
	# RunProgressionManager.peg_quotas internally (the function returns void).
	RunProgressionManager.playtest_quota_base = base_quota
	RunProgressionManager.playtest_quota_override = true
	RunProgressionManager.generate_quotas_for_map(1)