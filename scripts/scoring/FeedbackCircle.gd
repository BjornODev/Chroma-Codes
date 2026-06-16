extends Control
class_name FeedbackCircle

# =========================
# FEEDBACK CIRCLE
# Holds N slices arranged in a circle. Slot 0 at top (12 o'clock), fills clockwise.
# Dragging: the dragged slice follows the cursor angle directly; other slices
# tween into the slots opened up by the drag. Releasing snaps the dragged slice
# into its final slot.
# =========================

const SLICE_SCRIPT = preload("res://scripts/scoring/SliceNode.gd")

const CIRCLE_RADIUS := 30.0
const INNER_HUB_RADIUS := 8.0
const PADDING := 40.0
const HUB_COLOR := Color("#B0E0FF")
const HUB_OUTLINE_COLOR := Color.BLACK
const HUB_OUTLINE_WIDTH := 2.5

var row: int = -1
var slot_count: int = 4
var slice_colors: Array = []
var slices: Array[SliceNode] = []
var locked: bool = false

var _drag_slice: SliceNode = null
var _hover_slice: SliceNode = null


func _ready():
	custom_minimum_size = Vector2(CIRCLE_RADIUS * 2 + PADDING, CIRCLE_RADIUS * 2 + PADDING)
	mouse_filter = Control.MOUSE_FILTER_STOP


func generate(p_row: int, columns: int, adjacent_colors: Array):
	row = p_row
	slot_count = columns

	slice_colors.clear()
	var pool = adjacent_colors.duplicate()
	while pool.size() < slot_count:
		pool.append("black")
	while pool.size() > slot_count:
		pool.pop_back()
	pool.shuffle()
	slice_colors = pool

	_rebuild_slices()
	queue_redraw()


func _rebuild_slices():
	for s in slices:
		s.queue_free()
	slices.clear()

	var slice_arc = TAU / float(slot_count)
	var top_angle = -PI / 2.0
	var c = size / 2.0

	for i in range(slot_count):
		var slice = Control.new()
		slice.set_script(SLICE_SCRIPT)
		slice.anchor_left = 0
		slice.anchor_top = 0
		slice.anchor_right = 1
		slice.anchor_bottom = 1
		slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slice)

		var center_angle = top_angle + i * slice_arc
		slice.setup(slice_colors[i], center_angle, slice_arc, c, CIRCLE_RADIUS, INNER_HUB_RADIUS)
		slices.append(slice)


func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		_update_slice_centers()


func _update_slice_centers():
	if slices.is_empty():
		return
	var c = size / 2.0
	for slice in slices:
		slice.center = c
		slice.queue_redraw()
	queue_redraw()


# =========================
# DRAW HUB ON TOP OF SLICES
# =========================

func _draw():
	var c = size / 2.0
	draw_circle(c, INNER_HUB_RADIUS, HUB_COLOR)
	draw_arc(c, INNER_HUB_RADIUS, 0, TAU, 32, HUB_OUTLINE_COLOR, HUB_OUTLINE_WIDTH)


# =========================
# SHOW FEEDBACK
# =========================

func show_feedback(correct_count: int, almost_count: int):
	var none_count = slot_count - correct_count - almost_count

	var counts = {
		"none": none_count,
		"almost": almost_count,
		"correct": correct_count,
	}

	var arrangement = RulesEngine.resolve_placement(slot_count, counts)
	if arrangement.is_empty():
		push_warning("RulesEngine returned empty arrangement")
		return

	# Lock immediately so the player can't keep dragging during the reveal.
	for i in range(slot_count):
		slices[i].set_locked(true)

	locked = true
	if _hover_slice:
		_hover_slice.unlift()
		_hover_slice = null
	if _drag_slice:
		_drag_slice.unlift()
		_drag_slice = null

	# Data layer updates synchronously (marker_position, item events, board pegs).
	ScoreManager.process_row_feedback(slice_colors, arrangement)

	# Visual reveal: blink each indicator in clockwise from the top, one at a time.
	# Each slot's score peg launches as its indicator appears.
	_reveal_feedback_clockwise(arrangement)


const REVEAL_STAGGER := 0.25  # delay between consecutive slot reveals


func _reveal_feedback_clockwise(arrangement: Array):
	var hud = get_tree().get_first_node_in_group("score_peg_hud")

	# Set all "none" slots immediately (no indicator to show, no delay).
	for i in range(slot_count):
		if arrangement[i] == "none":
			slices[i].blink_in_feedback("none")

	# Stagger only the slots that actually have feedback, clockwise from the top.
	# The first feedback slot reveals at delay 0.
	var step := 0
	for i in range(slot_count):
		if arrangement[i] == "none":
			continue
		var delay = step * REVEAL_STAGGER
		var idx = i
		var t = get_tree().create_timer(delay)
		t.timeout.connect(func():
			_reveal_one_slot(idx, arrangement[idx], hud)
		)
		step += 1


func _reveal_one_slot(idx: int, feedback: String, hud):
	if idx < 0 or idx >= slices.size():
		return

	# Determine whether this slot will earn pegs, so we can launch them only
	# after the flicker settles.
	var earns := false
	var color_name := ""
	if feedback != "none":
		color_name = slice_colors[idx]
		if color_name != "black" and color_name != "" and \
			(color_name in ScoreManager.team_a_colors or color_name in ScoreManager.team_b_colors):
			earns = true

	if earns and hud != null and is_instance_valid(hud):
		var captured_idx = idx
		var captured_color = color_name
		var captured_feedback = feedback
		# Launch the pegs once the flicker has fully settled.
		var on_settled = _launch_slot_pegs.bind(captured_idx, captured_color, captured_feedback, hud)
		slices[idx].blink_in_feedback(feedback, on_settled)
	else:
		# No pegs to launch — just flicker the indicator in.
		slices[idx].blink_in_feedback(feedback)


func _launch_slot_pegs(idx: int, color_name: String, feedback: String, hud):
	if hud == null or not is_instance_valid(hud):
		return
	if idx < 0 or idx >= slices.size():
		return

	var pegs_earned = 2 if feedback == "correct" else 1
	var slice_screen_pos = _slice_screen_position(slices[idx])
	var shift_dir = 1 if color_name in ScoreManager.team_a_colors else -1

	for p in range(pegs_earned):
		var peg_delay = p * 0.08
		if peg_delay > 0.0:
			_launch_one_delayed(hud, color_name, slice_screen_pos, peg_delay, shift_dir)
		else:
			hud.launch_flying_peg(color_name, slice_screen_pos, shift_dir)


func _launch_one_delayed(hud, color_name: String, from_pos: Vector2, delay: float, shift_dir: int):
	var t = get_tree().create_timer(delay)
	t.timeout.connect(func():
		if is_instance_valid(hud):
			hud.launch_flying_peg(color_name, from_pos, shift_dir)
	)


func _slice_screen_position(slice: SliceNode) -> Vector2:
	# The slice's visual center is at this circle's center + radius along its angle.
	var radius_mid = (slice.inner_radius + slice.base_radius) / 2.0
	var local_offset = Vector2(cos(slice.angle_center), sin(slice.angle_center)) * radius_mid
	var local_point = size / 2.0 + local_offset
	return get_global_transform_with_canvas() * local_point


func reapply_feedback(correct_count: int, almost_count: int):
	show_feedback(correct_count, almost_count)


# =========================
# INPUT HANDLING — hover and drag
# =========================

func _gui_input(event: InputEvent):
	if locked:
		return

	if event is InputEventMouseMotion:
		var rel = event.position - size / 2.0

		if _drag_slice:
			_handle_drag_motion(rel)
		else:
			var hovered = _find_slice_at(rel)
			if hovered != _hover_slice:
				if _hover_slice:
					_hover_slice.unlift()
				_hover_slice = hovered
				if _hover_slice:
					_hover_slice.lift()

	elif event is InputEventMouseButton:
		var rel = event.position - size / 2.0
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var hit = _find_slice_at(rel)
			if hit:
				_drag_slice = hit
				if _hover_slice and _hover_slice != hit:
					_hover_slice.unlift()
				_hover_slice = null
				_drag_slice.lift()
				accept_event()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _drag_slice:
				_release_drag()
				accept_event()


# =========================
# DRAG HANDLING
# Dragged slice follows cursor's angle. Other slices distribute around the rest
# of the circle, smoothly tweening when their target slot changes.
# =========================

func _handle_drag_motion(rel: Vector2):
	if rel.length() < 1.0:
		return
	var cursor_angle = rel.angle()
	_drag_slice.set_angle_immediate(cursor_angle)

	# Determine which slot the dragged slice is currently over
	var target_slot = _angle_to_slot(cursor_angle)
	var dragged_slot = slices.find(_drag_slice)
	if target_slot != dragged_slot and target_slot >= 0 and target_slot < slot_count:
		# Swap the dragged slice with the slice at the target slot.
		# Only the displaced slice needs to animate — back to the dragged slice's old slot.
		var displaced_slice = slices[target_slot]
		var displaced_color = slice_colors[target_slot]
		var dragged_color = slice_colors[dragged_slot]

		slices[dragged_slot] = displaced_slice
		slice_colors[dragged_slot] = displaced_color
		slices[target_slot] = _drag_slice
		slice_colors[target_slot] = dragged_color

		# Tween the displaced slice into the dragged slice's old slot position
		var slice_arc = TAU / float(slot_count)
		var top_angle = -PI / 2.0
		var center_angle = top_angle + dragged_slot * slice_arc
		displaced_slice.tween_to_angle(center_angle)


func _release_drag():
	# Snap the dragged slice back into its slot angle
	var slot = slices.find(_drag_slice)
	var slice_arc = TAU / float(slot_count)
	var top_angle = -PI / 2.0
	var target_angle = top_angle + slot * slice_arc
	_drag_slice.tween_to_angle(target_angle)
	_drag_slice.unlift()
	_drag_slice = null


func _find_slice_at(rel_pos: Vector2) -> SliceNode:
	for s in slices:
		if s.point_in_slice(rel_pos):
			return s
	return null


func _angle_to_slot(angle: float) -> int:
	# Slot 0 center is at -PI/2 (top). Returns the slot whose center is closest to angle.
	var slice_arc = TAU / float(slot_count)
	var top_angle = -PI / 2.0
	var diff = wrapf(angle - top_angle, 0.0, TAU)
	var index = int(round(diff / slice_arc)) % slot_count
	return index