extends GridContainer

var peg_scene = preload("res://scenes/display_peg.tscn")

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func display_pattern(pattern : PatternData):
	print("Display pattern called:", pattern.pattern_name)
	# Special case full row
	if pattern.type == "full_row":
		columns = 4  # temporary preview width
		
		for i in range(4):
			var cell = peg_scene.instantiate()
			add_child(cell)
			cell.custom_minimum_size = Vector2(50,50)
			cell.modulate = get_color_from_id(pattern.grid[0][0])
		update_minimum_size()
		return

	# Normal grid pattern
	columns = pattern.width

	for y in range(pattern.height - 1, -1, -1):
		for x in range(pattern.width):

			var value = pattern.grid[y][x]

			var cell = peg_scene.instantiate()
			add_child(cell)
			cell.custom_minimum_size = Vector2(50,50)

			if value == 0:
				cell.modulate = Color(0,0,0,0)
			else:
				cell.modulate = get_color_from_id(value)
	update_minimum_size()


func get_color_from_id(id):
	match id:
		1: return Color("#FF0000")
		2: return Color("#FFF200")
		3: return Color("#3BB143")
		4: return Color("#FFFFFF")
		5: return Color("#8F00FF")
		6: return Color("#ED7117")