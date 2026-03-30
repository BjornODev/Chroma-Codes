extends PanelContainer

const PEG_COLORS := {
	1: Color("#E05555"),  # red
	2: Color("#E0C055"),  # yellow
	3: Color("#55A855"),  # green
	4: Color("#DDDDDD"),  # white
	5: Color("#8855CC"),  # purple
	6: Color("#E08040"),  # orange
}

var font: Font
var font_size := 18

@onready var content = $MarginContainer/VBoxContainer


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")


func _build_summary():
	for child in content.get_children():
		child.queue_free()

	_add_label("BOARD SUMMARY", 22, Color("#FFFFFF"))
#	_add_separator()
	_add_label("Rows Submitted: %d" % RunProgressionManager.board_rows_submitted, font_size, Color("#C0FF00"))
	_add_label("Damage Taken: %d" % RunProgressionManager.board_damage_taken, font_size, Color("#FF4444"))
#	_add_separator()
	_add_label("Pegs Placed:", font_size, Color("#FFFFFF"))
	_add_peg_counts()


func _add_label(text: String, size: int, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)


func _add_separator():
	var sep = HSeparator.new()
	content.add_child(sep)


func _add_peg_counts():
	var peg_row = HBoxContainer.new()
	peg_row.alignment = BoxContainer.ALIGNMENT_CENTER
	peg_row.add_theme_constant_override("separation", 12)
	content.add_child(peg_row)

	var peg_texture = preload("res://assets/pegs/peg_down.svg")

	for peg_id in PEG_COLORS.keys():
		var count = RunProgressionManager.board_peg_counts.get(peg_id, 0)

		var wrapper = VBoxContainer.new()
		wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
		peg_row.add_child(wrapper)

		# Peg icon
		var icon = TextureRect.new()
		icon.texture = peg_texture
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = PEG_COLORS[peg_id]
		wrapper.add_child(icon)

		# Count label
		var label = Label.new()
		label.text = str(count)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", PEG_COLORS[peg_id])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wrapper.add_child(label)
