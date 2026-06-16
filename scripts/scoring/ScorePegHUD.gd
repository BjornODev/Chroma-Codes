extends Control
class_name ScorePegHUD

# =========================
# SCORE PEG HUD (VERTICAL)
# One row per color, each showing a peg_out sprite and a running count.
# Receives flying score pegs launched from feedback slices: when one lands,
# the count ticks up and the destination peg pulses (scales up then eases back).
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

const ENTRY_HEIGHT := 70.0      # bigger than before
const ENTRY_WIDTH := 130.0
const PEG_DISPLAY_SIZE := 75.0   # rendered diameter of each HUD peg
const PULSE_SCALE := 1.45        # how big the peg gets on a landing
const PULSE_RETURN_TIME := 0.45

var font: Font
var peg_texture: Texture2D

# Per-color visual scale (animated on landing)
var _peg_scales: Dictionary = {}
# Displayed count per color (ticks up as pegs land, independent of ScoreManager total)
var _display_counts: Dictionary = {}
var _pulse_tweens: Dictionary = {}

# Flying peg layer — pegs are added here so they render above the HUD
var _flight_layer: Node2D


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	peg_texture = preload("res://assets/pegs/peg_out.svg")
	custom_minimum_size = Vector2(ENTRY_WIDTH, ENTRY_HEIGHT * COLORS_ORDER.size())
	add_to_group("score_peg_hud")

	for c in COLORS_ORDER:
		_peg_scales[c] = 1.0
		_display_counts[c] = 0

	# A Node2D child to host flying pegs in this Control's local space
	_flight_layer = Node2D.new()
	add_child(_flight_layer)

	ScoreManager.connect("teams_set", _on_teams_set)
	ScoreManager.connect("team_won_board", _on_board_won)
	queue_redraw()


func _on_teams_set(_a, _b):
	# New board — this HUD shows only the pegs earned during THIS board, so
	# start every color back at zero. The persistent map total lives on the
	# map screen counter instead.
	for c in COLORS_ORDER:
		_display_counts[c] = 0
	queue_redraw()


func _on_board_won(team: String, winning_colors: Array, doubled: Dictionary):
	# The winning team's pegs double. Each color's bonus (the extra copy) flies
	# from that color's swatch on the tug-of-war bar to its counter. The base
	# earnings already flew and counted during play; here we animate only the
	# bonus copies. doubled[color] is the post-double total, so bonus = doubled/2.
	if team == "tie" or team == "":
		# No winner: nothing doubles. Displayed counts already match earnings.
		return

	var bar = get_tree().get_first_node_in_group("tug_of_war_bar")

	for color_name in doubled.keys():
		var total = doubled[color_name]
		var bonus = int(total / 2)  # the extra copies from doubling
		if bonus <= 0:
			continue

		var from_pos = Vector2.ZERO
		if bar and bar.has_method("get_swatch_screen_position"):
			from_pos = bar.get_swatch_screen_position(color_name)
		if from_pos == Vector2.ZERO:
			# Fallback: launch from this HUD's own center
			from_pos = get_global_transform_with_canvas() * (size / 2.0)

		for p in range(bonus):
			var delay = p * 0.1
			_launch_bonus_delayed(color_name, from_pos, delay)


func _launch_bonus_delayed(color_name: String, from_pos: Vector2, delay: float):
	if delay <= 0.0:
		launch_flying_peg(color_name, from_pos)
		return
	var t = get_tree().create_timer(delay)
	t.timeout.connect(func():
		launch_flying_peg(color_name, from_pos)
	)


# =========================
# SLOT GEOMETRY
# =========================

func _slot_local_pos(color_name: String) -> Vector2:
	var i = COLORS_ORDER.find(color_name)
	if i < 0:
		return Vector2.ZERO
	var center_y = ENTRY_HEIGHT * i + ENTRY_HEIGHT / 2.0
	return Vector2(PEG_DISPLAY_SIZE / 2.0 + 12, center_y)


# Global screen position of a color's HUD peg (for aiming flyers)
func get_slot_screen_position(color_name: String) -> Vector2:
	return get_global_transform_with_canvas() * _slot_local_pos(color_name)


# =========================
# FLYING PEG LAUNCH
# from_screen_pos: where the peg starts (a slice, in screen/canvas space)
# =========================

func launch_flying_peg(color_name: String, from_screen_pos: Vector2, shift_direction: int = 0):
	var flyer = Node2D.new()
	flyer.set_script(preload("res://scripts/scoring/FlyingScorePeg.gd"))
	_flight_layer.add_child(flyer)

	# Convert screen positions into the flight layer's local space
	var inv = _flight_layer.get_global_transform_with_canvas().affine_inverse()
	var local_from = inv * from_screen_pos
	var local_to = inv * get_slot_screen_position(color_name)

	var peg_scale = PEG_DISPLAY_SIZE / float(peg_texture.get_width())

	flyer.setup(color_name, local_from, local_to, peg_scale,
		func(): _on_peg_landed(color_name, shift_direction))


func _on_peg_landed(color_name: String, shift_direction: int = 0):
	_display_counts[color_name] = _display_counts.get(color_name, 0) + 1
	_pulse_slot(color_name)
	queue_redraw()

	# Nudge the tug-of-war bar's visual marker as the peg arrives
	if shift_direction != 0:
		var bar = get_tree().get_first_node_in_group("tug_of_war_bar")
		if bar and bar.has_method("apply_visual_shift"):
			bar.apply_visual_shift(shift_direction, 1)


# =========================
# PULSE ANIMATION
# Peg scales up instantly-ish then eases back to 1.0
# =========================

func _pulse_slot(color_name: String):
	if _pulse_tweens.has(color_name) and _pulse_tweens[color_name]:
		_pulse_tweens[color_name].kill()

	_peg_scales[color_name] = PULSE_SCALE
	queue_redraw()

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v): _set_peg_scale(color_name, v),
		PULSE_SCALE, 1.0, PULSE_RETURN_TIME
	)
	_pulse_tweens[color_name] = tween


func _set_peg_scale(color_name: String, v: float):
	_peg_scales[color_name] = v
	queue_redraw()


# =========================
# DRAW
# =========================

func _draw():
	var font_size = 30

	for i in range(COLORS_ORDER.size()):
		var color_name = COLORS_ORDER[i]
		var count = _display_counts.get(color_name, 0)
		var slot_pos = _slot_local_pos(color_name)

		var peg_color = PEG_COLORS.get(color_name, Color.WHITE)
		var alpha = 1.0 if count > 0 else 0.35
		peg_color.a = alpha

		# Draw the peg_out sprite, scaled by its current pulse scale
		var scl = _peg_scales.get(color_name, 1.0)
		var draw_size = PEG_DISPLAY_SIZE * scl
		var tex_rect = Rect2(
			slot_pos - Vector2(draw_size, draw_size) / 2.0,
			Vector2(draw_size, draw_size)
		)
		draw_texture_rect(peg_texture, tex_rect, false, peg_color)

		# Count label
		var text = "x" + str(count)
		var text_pos = Vector2(slot_pos.x + PEG_DISPLAY_SIZE / 2.0 + 16, slot_pos.y + font_size / 3.0)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)