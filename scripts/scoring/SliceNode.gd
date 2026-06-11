extends Control
class_name SliceNode

# =========================
# SLICE NODE
# One pie slice in the feedback circle. Custom-drawn arc with outline.
# Supports being repositioned by angle via tween or direct set.
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
	"black": Color("#000000"),
}

const INNER_HUB_COLOR := Color("#00F0FF")
const OUTLINE_COLOR := Color.BLACK
const OUTLINE_WIDTH := 4.25

const LIFT_EXTRA_RADIUS := 10.0
const LIFT_ANIM_DURATION := 0.18
const ANGLE_ANIM_DURATION := 0.22

var slice_color: String = "black"
var slice_arc: float = 0.0  # The angular width of this slice
var angle_center: float = 0.0  # Current center angle (radians)
var center: Vector2 = Vector2.ZERO
var base_radius: float = 35.0
var lift_offset: float = 0.0
var inner_radius: float = 9.0
var feedback_type: String = "none"
var locked: bool = false

var _lift_tween: Tween = null
var _angle_tween: Tween = null


func setup(color_name: String, p_angle_center: float, p_slice_arc: float, c: Vector2, r: float, inner_r: float):
	slice_color = color_name
	angle_center = p_angle_center
	slice_arc = p_slice_arc
	center = c
	base_radius = r
	inner_radius = inner_r
	queue_redraw()


# Smoothly tween center angle to a new target
func tween_to_angle(new_angle: float):
	if _angle_tween:
		_angle_tween.kill()
	_angle_tween = create_tween()
	_angle_tween.set_trans(Tween.TRANS_CUBIC)
	_angle_tween.set_ease(Tween.EASE_OUT)
	_angle_tween.tween_method(_set_angle_center, angle_center, new_angle, ANGLE_ANIM_DURATION)


# Instantly set angle (for dragged slice following cursor)
func set_angle_immediate(new_angle: float):
	if _angle_tween:
		_angle_tween.kill()
		_angle_tween = null
	angle_center = new_angle
	queue_redraw()


func _set_angle_center(a: float):
	angle_center = a
	queue_redraw()


func set_feedback(t: String):
	feedback_type = t
	queue_redraw()


func set_locked(l: bool):
	locked = l


func get_angle_start() -> float:
	return angle_center - slice_arc / 2.0


func get_angle_end() -> float:
	return angle_center + slice_arc / 2.0


# =========================
# LIFT
# =========================

func lift():
	_animate_lift(LIFT_EXTRA_RADIUS)


func unlift():
	_animate_lift(0.0)


func _animate_lift(target: float):
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.set_trans(Tween.TRANS_CUBIC)
	_lift_tween.set_ease(Tween.EASE_OUT)
	_lift_tween.tween_method(_set_lift_offset, lift_offset, target, LIFT_ANIM_DURATION)


func _set_lift_offset(v: float):
	lift_offset = v
	queue_redraw()


# =========================
# DRAW
# =========================

func _draw():
	var radius = base_radius + lift_offset
	var fill_color = _get_fill_color()
	var segments = 32

	var angle_start = get_angle_start()
	var angle_end = get_angle_end()

	# Build outer arc points
	var arc_points := []
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = lerp(angle_start, angle_end, t)
		arc_points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	# Build inner arc points
	var inner_arc_points := []
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = lerp(angle_start, angle_end, t)
		inner_arc_points.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)

	# Fill polygon: outer arc forward, inner arc reverse (donut wedge)
	var fill_points := PackedVector2Array()
	for p in arc_points:
		fill_points.append(p)
	for i in range(inner_arc_points.size() - 1, -1, -1):
		fill_points.append(inner_arc_points[i])
	draw_colored_polygon(fill_points, fill_color)

	# Outline
	_draw_arc_segment(angle_start, angle_end, radius, OUTLINE_COLOR, OUTLINE_WIDTH, segments)
	_draw_arc_segment(angle_start, angle_end, inner_radius, OUTLINE_COLOR, OUTLINE_WIDTH, segments)
	# Straight edges
	var p1_outer = center + Vector2(cos(angle_start), sin(angle_start)) * radius
	var p1_inner = center + Vector2(cos(angle_start), sin(angle_start)) * inner_radius
	var p2_outer = center + Vector2(cos(angle_end), sin(angle_end)) * radius
	var p2_inner = center + Vector2(cos(angle_end), sin(angle_end)) * inner_radius
	draw_line(p1_inner, p1_outer, OUTLINE_COLOR, OUTLINE_WIDTH)
	draw_line(p2_inner, p2_outer, OUTLINE_COLOR, OUTLINE_WIDTH)

	# Feedback indicator
	if feedback_type != "none":
		_draw_feedback_indicator(radius)


func _draw_arc_segment(angle_start: float, angle_end: float, radius: float, color: Color, width: float, segments: int):
	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)
		var a1 = lerp(angle_start, angle_end, t1)
		var a2 = lerp(angle_start, angle_end, t2)
		var p1 = center + Vector2(cos(a1), sin(a1)) * radius
		var p2 = center + Vector2(cos(a2), sin(a2)) * radius
		draw_line(p1, p2, color, width)


func _get_fill_color() -> Color:
	return PEG_COLORS.get(slice_color, Color.WHITE)


func _draw_feedback_indicator(current_radius: float):
	var mid_radius = (inner_radius + current_radius) / 2.0
	var pos = center + Vector2(cos(angle_center), sin(angle_center)) * mid_radius

	# Invert color on black slices for visibility
	var indicator_color = Color.WHITE if slice_color == "black" else Color.BLACK

	match feedback_type:
		"correct":
			draw_circle(pos, 7.0, indicator_color)
		"almost":
			draw_arc(pos, 6.0, 0, TAU, 32, indicator_color, 2.0)


# =========================
# DRAW HUB
# =========================
# The hub is drawn once at the FeedbackCircle level, not per slice, to avoid
# overlapping draw calls. See FeedbackCircle._draw_hub for that.


# =========================
# HIT-TEST
# =========================

func point_in_slice(point_relative_to_center: Vector2) -> bool:
	var dist = point_relative_to_center.length()
	if dist < inner_radius or dist > base_radius + lift_offset:
		return false

	var p_angle = point_relative_to_center.angle()
	# Normalize the angular distance from this slice's center to [-PI, PI]
	var diff = wrapf(p_angle - angle_center, -PI, PI)
	return abs(diff) <= slice_arc / 2.0
