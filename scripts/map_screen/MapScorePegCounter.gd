extends Control
class_name MapScorePegCounter

# =========================
# MAP SCORE PEG COUNTER
# Shows the player's persistent score peg total for the current map.
# When returning from a board, the pegs earned that board fly in from the
# center of the screen (or a provided origin) and tick the totals up.
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

const ENTRY_WIDTH := 280.0
const ENTRY_HEIGHT := 125.0
const PEG_DISPLAY_SIZE := 95.0
const PULSE_SCALE := 1.4
const PULSE_RETURN_TIME := 0.4

var font: Font
var peg_texture: Texture2D

var _peg_scales: Dictionary = {}
var _display_counts: Dictionary = {}
var _pulse_tweens: Dictionary = {}
var _flight_layer: Node2D

# Optional external source. When set, the display reads counts from this dict
# (live, ticking values) instead of its own banked totals, and skips the
# board-return fly-in. Used by the map-complete settlement screen.
var _live_source: Dictionary = {}
var _use_live_source := false


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	peg_texture = preload("res://assets/pegs/peg_out.svg")
	custom_minimum_size = Vector2(ENTRY_WIDTH, ENTRY_HEIGHT * COLORS_ORDER.size())
	size = custom_minimum_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_FILL
	add_to_group("map_score_peg_counter")

	for c in COLORS_ORDER:
		_peg_scales[c] = 1.0

	_flight_layer = Node2D.new()
	add_child(_flight_layer)

	if _use_live_source:
		# Live-source mode: just mirror the provided dict, no fly-in.
		for c in COLORS_ORDER:
			_display_counts[c] = _live_source.get(c, 0)
		queue_redraw()
		return

	# Start displayed counts at the persistent banked total minus what was just
	# earned this board, so the fly-in animates the new pegs landing.
	var pending = ScoreManager.consume_pending_board_earnings()
	for c in COLORS_ORDER:
		var banked = ScoreManager.earned_score_pegs.get(c, 0)
		var earned = pending.get(c, 0)
		_display_counts[c] = banked - earned   # pre-board total

	queue_redraw()

	# Animate the just-earned pegs flying in
	if not pending.is_empty():
		call_deferred("_animate_board_earnings", pending)


func _animate_board_earnings(pending: Dictionary):
	if _use_live_source:
		return
	var origin = get_viewport().get_visible_rect().size / 2.0
	for color_name in pending.keys():
		var amount = pending[color_name]
		for p in range(amount):
			var delay = p * 0.09
			_launch_delayed(color_name, origin, delay)


func _launch_delayed(color_name: String, from_pos: Vector2, delay: float):
	if delay <= 0.0:
		_launch_flying_peg(color_name, from_pos)
		return
	var t = get_tree().create_timer(delay)
	t.timeout.connect(func(): _launch_flying_peg(color_name, from_pos))


func _launch_flying_peg(color_name: String, from_screen_pos: Vector2):
	var flyer = Node2D.new()
	flyer.set_script(preload("res://scripts/scoring/FlyingScorePeg.gd"))
	_flight_layer.add_child(flyer)

	var inv = _flight_layer.get_global_transform_with_canvas().affine_inverse()
	var local_from = inv * from_screen_pos
	var local_to = inv * _slot_screen_position(color_name)

	var peg_scale = PEG_DISPLAY_SIZE / float(peg_texture.get_width())
	flyer.setup(color_name, local_from, local_to, peg_scale,
		func(): _on_peg_landed(color_name))


func _on_peg_landed(color_name: String):
	_display_counts[color_name] = _display_counts.get(color_name, 0) + 1
	_pulse_slot(color_name)
	queue_redraw()


func _pulse_slot(color_name: String):
	if _pulse_tweens.has(color_name) and _pulse_tweens[color_name]:
		_pulse_tweens[color_name].kill()
	_peg_scales[color_name] = PULSE_SCALE
	queue_redraw()
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v): _set_peg_scale(color_name, v), PULSE_SCALE, 1.0, PULSE_RETURN_TIME)
	_pulse_tweens[color_name] = tween


func _set_peg_scale(color_name: String, v: float):
	_peg_scales[color_name] = v
	queue_redraw()


# =========================
# GEOMETRY
# =========================

func _slot_local_pos(color_name: String) -> Vector2:
	var i = COLORS_ORDER.find(color_name)
	if i < 0:
		return Vector2.ZERO
	var center_y = ENTRY_HEIGHT * i + ENTRY_HEIGHT / 2.0
	return Vector2(PEG_DISPLAY_SIZE / 2.0 + 18, center_y)


func _slot_screen_position(color_name: String) -> Vector2:
	return get_global_transform_with_canvas() * _slot_local_pos(color_name)


# =========================
# SETTLEMENT-SCREEN HOOKS
# =========================

# Switch this counter to mirror an external live dict (ticking values), with no
# board-return fly-in. Must be called before _ready (i.e. right after instancing)
# OR followed by a manual refresh if already ready.
func set_live_source(source: Dictionary):
	_live_source = source
	_use_live_source = true
	if is_inside_tree():
		queue_redraw()


# Public screen position of a color's peg (for aiming settlement flyers).
func get_color_screen_pos(color_name: String) -> Vector2:
	return _slot_screen_position(color_name)


# =========================
# DRAW
# =========================

func _draw():
	var font_size = 68
	for i in range(COLORS_ORDER.size()):
		var color_name = COLORS_ORDER[i]
		var count = _live_source.get(color_name, 0) if _use_live_source else _display_counts.get(color_name, 0)
		var slot_pos = _slot_local_pos(color_name)

		var peg_color = PEG_COLORS.get(color_name, Color.WHITE)
		var alpha = 1.0 if count > 0 else 0.35
		peg_color.a = alpha

		var scl = _peg_scales.get(color_name, 1.0)
		var draw_size = PEG_DISPLAY_SIZE * scl
		var tex_rect = Rect2(slot_pos - Vector2(draw_size, draw_size) / 2.0, Vector2(draw_size, draw_size))
		draw_texture_rect(peg_texture, tex_rect, false, peg_color)

		var text = "x" + str(count)
		var text_pos = Vector2(slot_pos.x + PEG_DISPLAY_SIZE / 2.0 + 18, slot_pos.y + font_size / 3.0)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)