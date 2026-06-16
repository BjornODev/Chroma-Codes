extends Node

# =========================
# SCORE MANAGER
# Owns the tug-of-war state per board and the persistent score peg tally per map.
# Score pegs are awarded as feedback resolves in each row.
# At board end, the winning team's earned score pegs double.
# All major events are routed through ItemManager so items can hook in.
# =========================

# Set at board start
var team_a_colors: Array = []
var team_b_colors: Array = []

# Tug-of-war marker — negative = Team B winning, positive = Team A winning
var marker_position: int = 0

# Per-board earnings (reset on each board)
var board_team_a_pegs: Dictionary = {}
var board_team_b_pegs: Dictionary = {}

# Persistent (across boards, reset per map)
var earned_score_pegs: Dictionary = {}

# Pegs banked by the most recent finalize_board, waiting to be animated onto
# the map screen counter. Consumed (and cleared) by the map counter on load.
var pending_board_earnings: Dictionary = {}

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
	ItemManager.emit_game_event("teams_set", {
		"team_a": team_a_colors.duplicate(),
		"team_b": team_b_colors.duplicate(),
	})


# =========================
# FEEDBACK PROCESSING
# =========================

func process_row_feedback(slice_colors: Array, feedback_arrangement: Array):
	for i in range(feedback_arrangement.size()):
		var feedback_type = feedback_arrangement[i]
		if feedback_type == "none":
			continue
		var slice_color = slice_colors[i]
		if slice_color == "black" or slice_color == "":
			continue

		var amount = _amount_for_feedback(feedback_type)
		var team = _color_team(slice_color)
		if team == "none":
			continue

		_award_to_team(slice_color, amount, team)

	ItemManager.process_turn_events()


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
		ItemManager.emit_game_event("marker_shifted", {
			"direction": 1,
			"magnitude": amount,
		})
		emit_signal("score_pegs_earned", color, amount, "a")
		ItemManager.emit_game_event("score_pegs_earned", {
			"color": color,
			"amount": amount,
			"team": "a",
		})
	elif team == "b":
		board_team_b_pegs[color] = board_team_b_pegs.get(color, 0) + amount
		marker_position -= amount
		emit_signal("marker_shifted", -1, amount)
		ItemManager.emit_game_event("marker_shifted", {
			"direction": -1,
			"magnitude": amount,
		})
		emit_signal("score_pegs_earned", color, amount, "b")
		ItemManager.emit_game_event("score_pegs_earned", {
			"color": color,
			"amount": amount,
			"team": "b",
		})


# =========================
# BOARD END
# =========================

func finalize_board() -> Dictionary:
	var winning_team := ""
	var winning_colors := []
	var doubled_pegs := {}

	# Track exactly what gets banked this board, per color, for the map counter.
	var banked_this_board := {}

	if marker_position > 0:
		winning_team = "a"
		winning_colors = team_a_colors.duplicate()
		for color in board_team_a_pegs.keys():
			doubled_pegs[color] = board_team_a_pegs[color] * 2
		for color in doubled_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + doubled_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + doubled_pegs[color]
		for color in board_team_b_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_b_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + board_team_b_pegs[color]
	elif marker_position < 0:
		winning_team = "b"
		winning_colors = team_b_colors.duplicate()
		for color in board_team_b_pegs.keys():
			doubled_pegs[color] = board_team_b_pegs[color] * 2
		for color in doubled_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + doubled_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + doubled_pegs[color]
		for color in board_team_a_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_a_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + board_team_a_pegs[color]
	else:
		winning_team = "tie"
		for color in board_team_a_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_a_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + board_team_a_pegs[color]
		for color in board_team_b_pegs.keys():
			earned_score_pegs[color] = earned_score_pegs.get(color, 0) + board_team_b_pegs[color]
			banked_this_board[color] = banked_this_board.get(color, 0) + board_team_b_pegs[color]

	# Stash for the map counter to animate on return
	pending_board_earnings = banked_this_board.duplicate()

	emit_signal("team_won_board", winning_team, winning_colors, doubled_pegs)

	return {
		"team": winning_team,
		"team_a_pegs": board_team_a_pegs.duplicate(),
		"team_b_pegs": board_team_b_pegs.duplicate(),
		"doubled_pegs": doubled_pegs,
		"marker_position": marker_position,
		"winning_colors": winning_colors,
		"banked_this_board": banked_this_board.duplicate(),
	}


# Returns and clears the pegs banked by the most recent finalize_board.
# The map score peg counter calls this on load to animate the new pegs in.
func consume_pending_board_earnings() -> Dictionary:
	var p = pending_board_earnings.duplicate()
	pending_board_earnings.clear()
	return p