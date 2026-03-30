## =============================================
## 1. ADD TO RunProgressionManager.gd
## =============================================

## Add these variables near the top:
#
# var board_rows_submitted := 0
# var board_damage_taken := 0
# var board_peg_counts := {
# 	1: 0,  # red
# 	2: 0,  # yellow
# 	3: 0,  # green
# 	4: 0,  # white
# 	5: 0,  # purple
# 	6: 0,  # orange
# }
#
# signal dollars_activated(index: int, total_activations: int)
#
## Add this function:
#
# func reset_board_stats():
# 	board_rows_submitted = 0
# 	board_damage_taken = 0
# 	for key in board_peg_counts.keys():
# 		board_peg_counts[key] = 0
#
# func record_row_submitted(guess: Array):
# 	board_rows_submitted += 1
# 	for peg_id in guess:
# 		if board_peg_counts.has(peg_id):
# 			board_peg_counts[peg_id] += 1
#
# func record_damage_taken(amount: int):
# 	board_damage_taken += amount


## =============================================
## 2. ADD TO BoardManager.gd
## =============================================

## In submit_guess(), after saving the guess:
#	RunProgressionManager.record_row_submitted(guess)
#
## In apply_damage(), after player_health -= damage:
#	RunProgressionManager.record_damage_taken(damage)
#
## In _ready() and start_next_board():
#	RunProgressionManager.reset_board_stats()


## =============================================
## 3. DollarDisplay.gd — attach to a new scene
## =============================================
## Scene structure:
## Control (DollarDisplay.gd)
## └── HBoxContainer "DotsContainer"
##     └── (dollar signs built procedurally)


## =============================================
## 4. RewardsSelectionUI changes
## =============================================
## Add DollarDisplay scene above HBoxContainer
## Add RunSummary scene below VBoxContainer
