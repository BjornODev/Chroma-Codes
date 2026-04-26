# =========================
# DOLLARBAR SETUP NOTES
# =========================


# =========================
# 1. DOLLARBAR.tscn SCENE STRUCTURE
# =========================
# Control (DollarBar.gd)
# └── DollarRow (HBoxContainer, separation 12)
#
# DollarRow gets populated procedurally with 5 Labels in _ready()


# =========================
# 2. ADDING TO Main.tscn
# =========================
# Add DollarBar.tscn as a child of Main scene
# Position it at the top center of the screen, above the player hand display
# Anchor: top center
# Approximate position offset: (-100, 30) so it's centered horizontally near the top


# =========================
# 3. REMOVE OLD CHAOS BAR
# =========================
# Delete or hide the existing ChaosBar node from Main.tscn
# Delete ChaosBar.gd if no longer used


# =========================
# 4. CONNECT TO DAMAGE SYSTEM
# =========================
# In BoardManager.apply_damage() add:
#	DollarManager.lose_dollar_from_damage()
# Replace any existing ChaosManager.add_chaos_from_damage() calls


# =========================
# 5. RESET ON NEW BOARD
# =========================
# In BoardManager._ready() and start_next_board() add:
#	DollarManager.reset_for_new_board()


# =========================
# 6. RELIGHT KEYWORD
# =========================
# In KeywordEngine.apply_keyword add:
#
# "Relight":
#	DollarManager.relight_multiple(value)
#
# Items can now use {"Relight": 1} as their keyword to relight one dollar


# =========================
# 7. REWARD SCREEN UPDATE
# =========================
# In RewardsSelectionUI._get_earned_dollar_indices() use:
#
# func _get_earned_dollar_indices() -> Array:
#	var indices = []
#	for i in range(DollarManager.DOLLAR_COUNT - 1, -1, -1):
#		if DollarManager.dollars_active[i]:
#			indices.append(i)
#	return indices
