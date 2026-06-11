extends Node

# =========================
# SCORE MANAGER
# Owns the tug-of-war state per board and the persistent score peg tally per map.
# Score pegs are awarded as feedback resolves in each row.
# At board end, the winning team's earned score pegs double.
# =========================

# Set at board start
var team_a_colors: Array = []  # e.g. ["yellow", "green"]
var team_b_colors: Array = []  # e.g. ["red", "orange"]

# Tug-of-war marker — negative = Team B winning, positive = Team A winning
var marker_position: int = 0

# Per-board earnings (reset on each board, banked on board end)
var board_team_a_pegs: Dictionary = {}  # {color_name: amount}
var board_team_b_pegs: Dictionary = {}

# Persistent (across boards, reset per map)
var earned_score_pegs: Dictionary = {}  # {color_name: amount}

signal teams_set(team_a: Array, team_b: Array)
signal score_pegs_earned(color: String, amount: int, team: String)
signal marker_shifted(direction: int, magnitude: int)
signal team_won_board(team: String, winning_colors: Array, doubled_score: Dictionary)


func _ready():
	reset_for_new_map()


# =========================
# MAP / BOARD LIFECYCLE
# =========================

func reset_for_new_map():
	earned_score_pegs.clear()
	for color in ["red", "yellow", "green", "white", "purple", "orange"]:
		earned_score_pegs[color] = 0
	_reset_board_state()


func start_board(adjacent_colors: Array):
	_reset_board_state()
	_assign_teams(adjacent_colors)


func _reset_board_state():
	team_a_colors = []
	team_b_colors = []
	marker_position = 0
	board_team_a_pegs.clear()
	board_team_b_pegs.clear()


# Randomly pair the adjacent colors into two teams of two.
# At edges with fewer than 4 colors, distribute as best as possible.
func _assign_teams(adjacent_colors: Array):
	var shuffled = adjacent_colors.duplicate()
	shuffled.shuffle()

	match shuffled.size():
		4:
			team_a_colors = [shuffled[0], shuffled[1]]
			team_b_colors = [shuffled[2], shuffled[3]]
		3:
			team_a_colors = [shuffled[0], shuffled[1]]
			team_b_colors = [shuffled[2]]
		2:
			team_a_colors = [shuffled[0]]
			team_b_colors = [shuffled[1]]
		1:
			team_a_colors = [shuffled[0]]
			team_b_colors = []
		_:
			team_a_colors = []
			team_b_colors = []

	emit_signal("teams_set", team_a_colors, team_b_colors)


# =========================
# FEEDBACK PROCESSING
# Called by BoardManager after each row's feedback is resolved.
# slice_colors: array of color names per slot (slot 0 = top, clockwise)
# feedback_arrangement: array of "none" / "almost" / "correct" per slot
# =========================

func process_row_feedback(slice_colors: Array, feedback_arrangement: Array):
	for i in range(feedback_arrangement.size()):
		var feedback_type = feedback_arrangement[i]
		if feedback_type == "none":
			continue
		var slice_color = slice_colors[i]
		if slice_color == "black" or slice_color == "":
			# Black slice (no adjacent color) — no scoring
			continue

		var amount = _amount_for_feedback(feedback_type)
		var team = _color_team(slice_color)
		if team == "none":
			continue

		_award_to_team(slice_color, amount, team)


func _amount_for_feedback(feedback_type: String) -> int:
	match feedback_type:
		"correct": return 2
		"almost": return 1
	return 0


func _color_team(color: String) -> String:
	if color in team_a_colors:
		return "a"
	if color in team_b_colors:
		return "b"
	return "none"


func _award_to_team(color: String, amount: int, team: String):
	if team == "a":
		board_team_a_pegs[color] = board_team_a_pegs.get(color, 0) + amount
		marker_position += amount
		emit_signal("marker_shifted", 1, amount)
		emit_signal("score_pegs_earned", color, amount, "a")
	elif team == "b":
		board_team_b_pegs[color] = board_team_b_pegs.get(color, 0) + amount
		marker_position -= amount
		emit_signal("marker_shifted", -1, amount)
		emit_signal("score_pegs_earned", color, amount, "b")


# =========================
# BOARD END
# Doubles the winning team's pegs and banks all earnings to earned_score_pegs.
# Returns the final tally for display.
# =========================

func finalize_board() -> Dictionary:
	var winning_team := ""
	var winning_colors := []
	var doubled_pegs := {}

	if marker_position > 0:
		winning_team = "a"
		winning_colors = team_a_colors.duplicate()
		for color in board_team_a_pegs.keys():
			doubled_pegs[color] = board_team_a_pegs[color] * 2
		# Bank doubled team a, unchanged team b
		for color in doubled_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + doubled_pegs[color]
		for color in board_team_b_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_b_pegs[color]
	elif marker_position < 0:
		winning_team = "b"
		winning_colors = team_b_colors.duplicate()
		for color in board_team_b_pegs.keys():
			doubled_pegs[color] = board_team_b_pegs[color] * 2
		for color in doubled_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + doubled_pegs[color]
		for color in board_team_a_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_a_pegs[color]
	else:
		winning_team = "tie"
		for color in board_team_a_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_a_pegs[color]
		for color in board_team_b_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_b_pegs[color]

	emit_signal("team_won_board", winning_team, winning_colors, doubled_pegs)

	return {
		"team": winning_team,
		"team_a_pegs": board_team_a_pegs.duplicate(),
		"team_b_pegs": board_team_b_pegs.duplicate(),
		"doubled_pegs": doubled_pegs,
		"marker_position": marker_position,
	}