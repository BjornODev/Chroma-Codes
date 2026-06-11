extends Control
class_name ScorePegHUD

# =========================
# SCORE PEG HUD
# Shows the player's total earned score pegs per color across the map.
# Updates live as score pegs are earned during boards.
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const COLORS_ORDER := ["red", "yellow", "green", "white", "purple", "orange"]
const ENTRY_WIDTH := 60.0
const ENTRY_HEIGHT := 50.0
const PEG_RADIUS := 14.0


func _ready():
	custom_minimum_size = Vector2(ENTRY_WIDTH * COLORS_ORDER.size(), ENTRY_HEIGHT)
	ScoreManager.connect("score_pegs_earned", _on_pegs_earned)
	ScoreManager.connect("team_won_board", _on_board_won)
	queue_redraw()


func _on_pegs_earned(_color: String, _amount: int, _team: String):
	queue_redraw()


func _on_board_won(_team: String, _winning_colors: Array, _doubled: Dictionary):
	queue_redraw()


func _draw():
	var font = ThemeDB.fallback_font
	var font_size = 18

	for i in range(COLORS_ORDER.size()):
		var color_name = COLORS_ORDER[i]
		var count = ScoreManager.earned_score_pegs.get(color_name, 0) + \
			_pending_pegs_for(color_name)

		var center_x = ENTRY_WIDTH * i + ENTRY_WIDTH / 2.0
		var peg_pos = Vector2(center_x, PEG_RADIUS + 4)
		var label_pos = Vector2(center_x, ENTRY_HEIGHT - 4)

		var peg_color = PEG_COLORS.get(color_name, Color.WHITE)
		var alpha = 1.0 if count > 0 else 0.3
		peg_color.a = alpha

		draw_circle(peg_pos, PEG_RADIUS, peg_color)
		draw_arc(peg_pos, PEG_RADIUS, 0, TAU, 32, Color(0, 0, 0, alpha), 2.0)

		var text = str(count)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = Vector2(center_x - text_size.x / 2.0, label_pos.y)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


# Add the current board's tentative earnings to display
func _pending_pegs_for(color_name: String) -> int:
	var team_a = ScoreManager.board_team_a_pegs.get(color_name, 0)
	var team_b = ScoreManager.board_team_b_pegs.get(color_name, 0)
	return team_a + team_b