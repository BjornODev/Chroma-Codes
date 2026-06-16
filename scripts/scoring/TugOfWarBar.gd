extends Control
class_name TugOfWarBar

# =========================
# TUG OF WAR BAR (VERTICAL)
# Team A pulls toward the top, Team B pulls toward the bottom.
# Marker rides a vertical track. Positive marker = Team A (up), negative = Team B (down).
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const BAR_WIDTH := 54.0
const BAR_HEIGHT := 480.0
const MARKER_SIZE := 40.0
const SWATCH_RADIUS := 18.0
const MARKER_CAP := 20.0

var marker_visual_pos: float = 0.0
var target_marker_pos: float = 0.0
# Visual marker is driven by peg landings, not directly by ScoreManager.
# Each landed peg calls apply_visual_shift to nudge the target.
var _visual_marker_accum: float = 0.0


func _ready():
	custom_minimum_size = Vector2(BAR_WIDTH + 80, BAR_HEIGHT + 110)
	add_to_group("tug_of_war_bar")
	ScoreManager.connect("teams_set", _on_teams_set)
	ScoreManager.connect("team_won_board", _on_team_won)
	queue_redraw()


func _process(_delta):
	if abs(marker_visual_pos - target_marker_pos) > 0.01:
		marker_visual_pos = lerp(marker_visual_pos, target_marker_pos, 0.15)
		queue_redraw()


func _on_teams_set(_team_a: Array, _team_b: Array):
	target_marker_pos = 0.0
	marker_visual_pos = 0.0
	_visual_marker_accum = 0.0
	queue_redraw()


# Called when a flying score peg lands. direction: +1 for Team A (up), -1 for Team B (down).
# magnitude: how far to shift (1 for almost, 2 for correct — but pegs land one at a time
# so this is typically called once per peg with magnitude 1).
func apply_visual_shift(direction: int, magnitude: int):
	_visual_marker_accum += direction * magnitude
	target_marker_pos = clamp(_visual_marker_accum, -MARKER_CAP, MARKER_CAP)


func _on_team_won(_team: String, _winning_colors: Array, _doubled: Dictionary):
	queue_redraw()


# Current screen position of the marker (for aiming bonus-peg flyers on win)
func get_marker_screen_position() -> Vector2:
	var cx = size.x / 2.0
	var bar_top = 55.0
	var center_y = bar_top + BAR_HEIGHT / 2.0
	var marker_y_offset = -(marker_visual_pos / MARKER_CAP) * (BAR_HEIGHT / 2.0)
	var local_pos = Vector2(cx, center_y + marker_y_offset)
	return get_global_transform_with_canvas() * local_pos


func _draw():
	var cx = size.x / 2.0
	var bar_top = 55.0
	var bar_origin = Vector2(cx - BAR_WIDTH / 2.0, bar_top)

	# Background track
	draw_rect(Rect2(bar_origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0.15, 0.15, 0.15), true)
	draw_rect(Rect2(bar_origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color(0.4, 0.4, 0.4), false, 2.0)

	# Center neutral line
	var center_y = bar_top + BAR_HEIGHT / 2.0
	draw_line(Vector2(cx - BAR_WIDTH / 2.0 - 8, center_y),
		Vector2(cx + BAR_WIDTH / 2.0 + 8, center_y),
		Color(0.6, 0.6, 0.6), 2.0)

	# Team A swatch (top)
	_draw_team_swatch(ScoreManager.team_a_colors, Vector2(cx, bar_top - 30))
	# Team B swatch (bottom)
	_draw_team_swatch(ScoreManager.team_b_colors, Vector2(cx, bar_top + BAR_HEIGHT + 30))

	# Marker — positive marker moves UP (toward Team A)
	var marker_y_offset = -(marker_visual_pos / MARKER_CAP) * (BAR_HEIGHT / 2.0)
	var marker_y = center_y + marker_y_offset
	var marker_pos = Vector2(cx, marker_y)

	draw_circle(marker_pos, MARKER_SIZE / 2.0, Color.WHITE)
	draw_arc(marker_pos, MARKER_SIZE / 2.0, 0, TAU, 32, Color.BLACK, 2.5)


func _draw_team_swatch(colors: Array, pos: Vector2):
	if colors.is_empty():
		return
	if colors.size() == 1:
		var c = PEG_COLORS.get(colors[0], Color.WHITE)
		draw_circle(pos, SWATCH_RADIUS, c)
		draw_arc(pos, SWATCH_RADIUS, 0, TAU, 24, Color.BLACK, 1.5)
	else:
		var left = pos + Vector2(-SWATCH_RADIUS, 0)
		var right = pos + Vector2(SWATCH_RADIUS, 0)
		var c1 = PEG_COLORS.get(colors[0], Color.WHITE)
		var c2 = PEG_COLORS.get(colors[1], Color.WHITE)
		draw_circle(left, SWATCH_RADIUS - 1, c1)
		draw_arc(left, SWATCH_RADIUS - 1, 0, TAU, 24, Color.BLACK, 1.5)
		draw_circle(right, SWATCH_RADIUS - 1, c2)
		draw_arc(right, SWATCH_RADIUS - 1, 0, TAU, 24, Color.BLACK, 1.5)


# =========================
# SWATCH POSITION LOOKUP
# Returns the screen position of a given color's swatch, or ZERO if not present.
# =========================

func get_swatch_screen_position(color_name: String) -> Vector2:
	var cx = size.x / 2.0
	var bar_top = 55.0
	var top_y = bar_top - 30
	var bot_y = bar_top + BAR_HEIGHT + 30

	var local = _color_swatch_local(color_name, ScoreManager.team_a_colors, cx, top_y)
	if local == Vector2.INF:
		local = _color_swatch_local(color_name, ScoreManager.team_b_colors, cx, bot_y)
	if local == Vector2.INF:
		return Vector2.ZERO
	return get_global_transform_with_canvas() * local


func _color_swatch_local(color_name: String, team_colors: Array, cx: float, y: float) -> Vector2:
	var idx = team_colors.find(color_name)
	if idx < 0:
		return Vector2.INF
	if team_colors.size() == 1:
		return Vector2(cx, y)
	# Two colors: index 0 = left, index 1 = right
	if idx == 0:
		return Vector2(cx - SWATCH_RADIUS, y)
	else:
		return Vector2(cx + SWATCH_RADIUS, y)