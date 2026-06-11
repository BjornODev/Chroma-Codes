extends Control
class_name TugOfWarBar

# =========================
# TUG OF WAR BAR
# Visual representation of the current marker position.
# Shows Team A on the left, Team B on the right.
# Marker tweens smoothly to its new position when shifted.
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const BAR_WIDTH := 400.0
const BAR_HEIGHT := 30.0
const MARKER_SIZE := 24.0
# Marker positions cap at ±MARKER_CAP visually; larger values clip at the cap
const MARKER_CAP := 20.0

var marker_visual_pos: float = 0.0
var target_marker_pos: float = 0.0


func _ready():
	custom_minimum_size = Vector2(BAR_WIDTH + 60, BAR_HEIGHT + 60)
	ScoreManager.connect("teams_set", _on_teams_set)
	ScoreManager.connect("marker_shifted", _on_marker_shifted)
	ScoreManager.connect("team_won_board", _on_team_won)
	queue_redraw()


func _process(_delta):
	if abs(marker_visual_pos - target_marker_pos) > 0.01:
		marker_visual_pos = lerp(marker_visual_pos, target_marker_pos, 0.15)
		queue_redraw()


func _on_teams_set(_team_a: Array, _team_b: Array):
	target_marker_pos = 0.0
	marker_visual_pos = 0.0
	queue_redraw()


func _on_marker_shifted(_direction: int, _magnitude: int):
	target_marker_pos = clamp(float(ScoreManager.marker_position), -MARKER_CAP, MARKER_CAP)


func _on_team_won(_team: String, _winning_colors: Array, _doubled: Dictionary):
	queue_redraw()


func _draw():
	var bar_origin = Vector2(30, 30)

	# Background bar
	draw_rect(Rect2(bar_origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0.15, 0.15, 0.15), true)

	# Center line (neutral)
	var center_x = bar_origin.x + BAR_WIDTH / 2.0
	draw_line(Vector2(center_x, bar_origin.y - 8),
		Vector2(center_x, bar_origin.y + BAR_HEIGHT + 8),
		Color(0.6, 0.6, 0.6), 2.0)

	# Team A colors (left)
	_draw_team_swatch(ScoreManager.team_a_colors, Vector2(bar_origin.x - 25, bar_origin.y + BAR_HEIGHT / 2.0))
	# Team B colors (right)
	_draw_team_swatch(ScoreManager.team_b_colors, Vector2(bar_origin.x + BAR_WIDTH + 25, bar_origin.y + BAR_HEIGHT / 2.0))

	# Marker — position 0 = center, +X = right (Team A wins), -X = left (Team B wins)
	# Bjorn's convention: positive marker = team A wins (from process_row_feedback)
	# Bar shows: left half = Team A side, right half = Team B side. So +marker = LEFT visually for Team A.
	# We invert so that positive marker pushes left toward Team A.
	var marker_x_offset = -(marker_visual_pos / MARKER_CAP) * (BAR_WIDTH / 2.0)
	var marker_x = center_x + marker_x_offset
	var marker_y = bar_origin.y + BAR_HEIGHT / 2.0

	draw_circle(Vector2(marker_x, marker_y), MARKER_SIZE / 2.0, Color.WHITE)
	draw_arc(Vector2(marker_x, marker_y), MARKER_SIZE / 2.0, 0, TAU, 32, Color.BLACK, 2.0)


func _draw_team_swatch(colors: Array, pos: Vector2):
	# Draw 1 or 2 small circles stacked vertically
	if colors.is_empty():
		return
	if colors.size() == 1:
		var c = PEG_COLORS.get(colors[0], Color.WHITE)
		draw_circle(pos, 10.0, c)
		draw_arc(pos, 10.0, 0, TAU, 24, Color.BLACK, 1.5)
	else:
		var top = pos + Vector2(0, -10)
		var bot = pos + Vector2(0, 10)
		var c1 = PEG_COLORS.get(colors[0], Color.WHITE)
		var c2 = PEG_COLORS.get(colors[1], Color.WHITE)
		draw_circle(top, 9.0, c1)
		draw_arc(top, 9.0, 0, TAU, 24, Color.BLACK, 1.5)
		draw_circle(bot, 9.0, c2)
		draw_arc(bot, 9.0, 0, TAU, 24, Color.BLACK, 1.5)