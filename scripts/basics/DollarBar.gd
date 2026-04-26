extends Control

const DOLLAR_ACTIVE_COLOR := Color("#FFD700")
const DOLLAR_LOST_COLOR := Color(0.3, 0.3, 0.3)
const FLICKER_INTERVAL := 0.15
const FLICKER_COUNT := 6

var dollar_labels: Array = []
var font: Font

@onready var dollar_row = $DollarRow


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	_build_dollars()

	DollarManager.connect("dollar_flickered", _on_dollar_flickered)
	DollarManager.connect("dollar_relit", _on_dollar_relit)
	DollarManager.connect("dollars_reset", _on_dollars_reset)

	_sync_to_state()


func _build_dollars():
	for child in dollar_row.get_children():
		child.queue_free()
	dollar_labels.clear()

	for i in range(DollarManager.DOLLAR_COUNT):
		var label = Label.new()
		label.text = "$"
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 45)
		label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		dollar_row.add_child(label)
		dollar_labels.append(label)


func _sync_to_state():
	for i in range(dollar_labels.size()):
		var label = dollar_labels[i]
		if DollarManager.dollars_active[i]:
			label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
		else:
			label.add_theme_color_override("font_color", DOLLAR_LOST_COLOR)


# =========================
# FLICKER ANIMATIONS
# =========================

func _on_dollar_flickered(index: int):
	# Lost — flicker then settle on lost color
	_flicker_to(index, DOLLAR_LOST_COLOR)


func _on_dollar_relit(index: int):
	# Relit — flicker then settle on active color
	_flicker_to(index, DOLLAR_ACTIVE_COLOR)


func _flicker_to(index: int, final_color: Color):
	if index < 0 or index >= dollar_labels.size():
		return
	var label = dollar_labels[index]
	var tween = create_tween()

	for i in range(FLICKER_COUNT):
		tween.tween_callback(func():
			if i % 2 == 0:
				label.add_theme_color_override("font_color", DOLLAR_LOST_COLOR)
			else:
				label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
		)
		tween.tween_interval(FLICKER_INTERVAL)

	tween.tween_callback(func():
		label.add_theme_color_override("font_color", final_color)
	)


func _on_dollars_reset():
	_sync_to_state()
