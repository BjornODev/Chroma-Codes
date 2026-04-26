extends CenterContainer

# -----------------------------------------------
# EASY TWEAK ZONE
# -----------------------------------------------
const BASE_DELAY := 0.2
const MIN_DELAY := 0.05
const SPEED_EXPONENT := 0.85  # lower = faster acceleration
const BOUNCE_HEIGHT := 12.0
const BOUNCE_DURATION := 0.15
const DOLLAR_SIZE := 48
const DOLLAR_SPACING := 16
# -----------------------------------------------

const DOLLAR_ACTIVE_COLOR := Color("#FFD700")
const DOLLAR_INACTIVE_COLOR := Color(0.3, 0.3, 0.3, 1.0)

signal all_dollars_animated
signal dollar_activated(index: int)

var dollar_labels: Array = []
var dollar_lit: Array = []
var activation_queue: Array = []  # Array of dollar indices to activate in order
var is_animating := false
var activation_count := 0  # total activations so far (for speed scaling)

var font: Font

@onready var dots_container = $DotsContainer


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_display()


func _build_display():
	dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in dots_container.get_children():
		child.queue_free()
	dollar_labels.clear()
	dollar_lit.clear()

	# Prepopulate so index assignment works
	for i in range(5):
		dollar_labels.append(null)
		dollar_lit.append(false)

	dots_container.add_theme_constant_override("separation", DOLLAR_SPACING)

	for i in range(5):
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(DOLLAR_SIZE, DOLLAR_SIZE)
		dots_container.add_child(wrapper)

		var label = Label.new()
		label.text = "$"
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", DOLLAR_SIZE)
		label.add_theme_color_override("font_color", DOLLAR_INACTIVE_COLOR)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		wrapper.add_child(label)
		dollar_labels[i] = label
		dollar_lit[i] = false





# Call this to queue up which dollars were earned
# earned_indices: array of dollar indices (0-4) that should light up
func animate_earned_dollars(earned_indices: Array):
	activation_queue.clear()
	activation_count = 0

	# Queue base earned dollars
	for i in earned_indices:
		activation_queue.append(i)

	_process_queue()


# Called by item system to add extra dollar activations
func queue_extra_activation(index: int):
	activation_queue.append(index)
	if not is_animating:
		_process_queue()


func _process_queue():
	if activation_queue.is_empty():
		emit_signal("all_dollars_animated")
		is_animating = false
		return

	is_animating = true
	var index = activation_queue.pop_front()
	await _activate_dollar(index)
	_process_queue()


func _activate_dollar(index: int):
	if index < 0 or index >= dollar_labels.size():
		return

	var label = dollar_labels[index]

	# Light up if not already lit
	if not dollar_lit[index]:
		dollar_lit[index] = true
		label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)

	# Bounce animation
	var original_pos = label.get_parent().position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label.get_parent(), "position:y", original_pos.y - BOUNCE_HEIGHT, BOUNCE_DURATION)
	tween.tween_property(label.get_parent(), "position:y", original_pos.y, BOUNCE_DURATION)
	await tween.finished

	emit_signal("dollar_activated", index)

	AudioLoader.play_sound("select")

	# Speed scaled delay
	var delay = max(MIN_DELAY, BASE_DELAY * pow(SPEED_EXPONENT, activation_count))
	activation_count += 1
	await get_tree().create_timer(delay).timeout
