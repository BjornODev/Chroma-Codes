extends Control
class_name MultiplierDisplay

# =========================
# MULTIPLIER DISPLAY (VERTICAL)
# A vertical 1:1 copy of the MapScreen ColorTracker: each color is a wrapper
# Control holding a peg_down.svg dot (tinted via MapManager.COLOR_VALUES) plus a
# centered count Label. Reads MapManager.board_color_activation_counts, which is
# the per-color multiplier used during settlement.
#
# Place this node where you want the column; if its parent is a VBoxContainer the
# wrappers stack vertically automatically. Otherwise they are positioned manually.
# =========================

const SLOT_SIZE := 100

# Maps color name -> its wrapper Control, so flyers can aim at each slot.
var _slot_wrappers: Dictionary = {}

var _font: Font


func _ready():
	_font = preload("res://assets/gomarice_goma_block.ttf")
	_build()


func refresh():
	_build()


func _build():
	for child in get_children():
		child.queue_free()
	_slot_wrappers.clear()

	var peg_texture = preload("res://assets/pegs/peg_down.svg")
	var font_res = preload("res://assets/gomarice_goma_block.ttf")

	var i := 0
	for color_name in MapManager.COLORS:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		# Stack vertically. If the parent is a VBoxContainer this is ignored and
		# the container handles layout; otherwise we position by row.
		wrapper.position = Vector2(0, i * SLOT_SIZE)
		add_child(wrapper)
		_slot_wrappers[color_name] = wrapper

		var count = MapManager.board_color_activation_counts[color_name]
		var base_color = MapManager.COLOR_VALUES[color_name]

		var dot = TextureRect.new()
		dot.texture = peg_texture
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.modulate = base_color if count > 0 else Color(base_color.r, base_color.g, base_color.b, 0.2)
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(dot)

		var label = Label.new()
		label.text = str(count)
		label.add_theme_font_override("font", font_res)
		label.add_theme_font_size_override("font_size", 50)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if count > 0 else Color(0.4, 0.4, 0.4, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(label)

		i += 1

	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE * MapManager.COLORS.size())


# Screen position of a color's slot center (for aiming settlement flyers).
func get_color_screen_pos(color_name: String) -> Vector2:
	var wrapper = _slot_wrappers.get(color_name)
	if wrapper == null:
		return get_global_transform_with_canvas() * (size / 2.0)
	return wrapper.get_global_transform_with_canvas() * (wrapper.size / 2.0)