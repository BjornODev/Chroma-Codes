extends Control

# =========================
# PATTERN MAKER TOOL
# Runtime editor for creating PatternData .tres files
# =========================

const PATTERNS_DIR := "res://data/patterns/"
const MAX_GRID_WIDTH := 6
const MAX_GRID_HEIGHT := 8
const CELL_SIZE := 60

const COLORS := ["red", "yellow", "green", "white", "purple", "orange"]
const COLOR_VALUES := {
	"red": Color("#E05555"),
	"yellow": Color("#E0C055"),
	"green": Color("#55A855"),
	"white": Color("#DDDDDD"),
	"purple": Color("#8855CC"),
	"orange": Color("#E08040"),
	"any": Color(0.5, 0.5, 0.5, 0.4),
}

# Conversion between color names (used in UI) and peg ids (used in .tres)
const PEG_ID_TO_COLOR := {
	0: "",
	1: "red",
	2: "yellow",
	3: "green",
	4: "white",
	5: "purple",
	6: "orange",
	-1: "any",
}

const COLOR_TO_PEG_ID := {
	"": 0,
	"red": 1,
	"yellow": 2,
	"green": 3,
	"white": 4,
	"purple": 5,
	"orange": 6,
	"any": -1,
}

const DUPLICATE_TYPES := ["", "any", "fixed"]

var font: Font
var current_filename := ""

var grid_data: Array = []
var cell_buttons: Array = []
var current_color := "red"

@onready var pattern_name_edit = $TopBar/PatternNameEdit
@onready var load_dropdown = $TopBar/LoadDropdown
@onready var new_button = $TopBar/NewButton
@onready var save_button = $TopBar/SaveButton

@onready var color_palette = $LeftPanel/ColorPalette
@onready var clear_button = $LeftPanel/ClearButton
@onready var duplicate_type_dropdown = $LeftPanel/DuplicateTypeDropdown
@onready var allowed_rows_edit = $LeftPanel/AllowedRowsEdit
@onready var duplicate_rows_edit = $LeftPanel/DuplicateRowsEdit

@onready var grid_container = $GridArea/GridContainer


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	_init_grid_data()
	_build_palette()
	_build_grid()
	_populate_load_dropdown()

	new_button.pressed.connect(_on_new_pressed)
	save_button.pressed.connect(_on_save_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	load_dropdown.item_selected.connect(_on_load_selected)

	duplicate_type_dropdown.clear()
	for t in DUPLICATE_TYPES:
		duplicate_type_dropdown.add_item(t if t != "" else "(none)")


func _init_grid_data():
	grid_data.clear()
	for r in range(MAX_GRID_HEIGHT):
		var row = []
		for c in range(MAX_GRID_WIDTH):
			row.append("")
		grid_data.append(row)


func _build_grid():
	for child in grid_container.get_children():
		child.queue_free()
	cell_buttons.clear()

	grid_container.columns = MAX_GRID_WIDTH

	# Initialize cell_buttons with empty rows
	for r in range(MAX_GRID_HEIGHT):
		cell_buttons.append([])

	# Build buttons visually top-to-bottom, but assign them to data rows in reverse
	# So the visual top is the highest row index, visual bottom is row 0
	for visual_r in range(MAX_GRID_HEIGHT):
		var data_r = MAX_GRID_HEIGHT - 1 - visual_r
		for c in range(MAX_GRID_WIDTH):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

			var local_r = data_r
			var local_c = c
			btn.pressed.connect(func(): _on_cell_clicked(local_r, local_c))

			grid_container.add_child(btn)
			cell_buttons[data_r].append(btn)

	for r in range(MAX_GRID_HEIGHT):
		for c in range(MAX_GRID_WIDTH):
			_refresh_cell(r, c)


func _build_palette():
	for child in color_palette.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "Select color:"
	label.add_theme_font_override("font", font)
	color_palette.add_child(label)

	var palette_colors = COLORS.duplicate()
	palette_colors.append("any")
	palette_colors.append("")

	for color_name in palette_colors:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(60, 60)
		btn.text = "X" if color_name == "" else ""

		var style = StyleBoxFlat.new()
		if color_name == "":
			style.bg_color = Color(0.2, 0.2, 0.2)
		else:
			style.bg_color = COLOR_VALUES.get(color_name, Color.GRAY)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color.BLACK
		btn.add_theme_stylebox_override("normal", style)

		var captured = color_name
		btn.pressed.connect(func(): _set_current_color(captured))
		color_palette.add_child(btn)


func _set_current_color(color: String):
	current_color = color


func _on_cell_clicked(row: int, col: int):
	grid_data[row][col] = current_color
	_refresh_cell(row, col)


func _refresh_cell(row: int, col: int):
	var btn = cell_buttons[row][col]
	var color_name = grid_data[row][col]

	var style = StyleBoxFlat.new()
	if color_name == "":
		style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	elif color_name == "any":
		style.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	else:
		style.bg_color = COLOR_VALUES.get(color_name, Color.GRAY)

	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.4)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)

	if color_name == "any":
		btn.text = "?"
	else:
		btn.text = ""


func _compute_bounding_box() -> Dictionary:
	var min_r = MAX_GRID_HEIGHT
	var max_r = -1
	var min_c = MAX_GRID_WIDTH
	var max_c = -1

	for r in range(MAX_GRID_HEIGHT):
		for c in range(MAX_GRID_WIDTH):
			if grid_data[r][c] != "":
				min_r = min(min_r, r)
				max_r = max(max_r, r)
				min_c = min(min_c, c)
				max_c = max(max_c, c)

	if max_r == -1:
		return {"empty": true}

	return {
		"empty": false,
		"min_r": min_r,
		"max_r": max_r,
		"min_c": min_c,
		"max_c": max_c,
		"width": max_c - min_c + 1,
		"height": max_r - min_r + 1
	}


func _on_save_pressed():
	var bbox = _compute_bounding_box()
	print("Save pressed")
	if bbox.empty:
		print("Cannot save — pattern is empty")
		return

	var pattern = PatternData.new()
	pattern.pattern_name = pattern_name_edit.text
	pattern.type = "grid"
	pattern.width = bbox.width
	pattern.height = bbox.height

	# Convert color names to peg ids when saving
	var trimmed: Array = []
	for r in range(bbox.min_r, bbox.max_r + 1):
		var row = []
		for c in range(bbox.min_c, bbox.max_c + 1):
			var color_name = grid_data[r][c]
			row.append(COLOR_TO_PEG_ID.get(color_name, 0))
		trimmed.append(row)
	pattern.grid = trimmed

	pattern.allowed_rows = _parse_int_list(allowed_rows_edit.text)
	pattern.duplicate_type = DUPLICATE_TYPES[duplicate_type_dropdown.selected]
	pattern.duplicate_rows = _parse_int_list(duplicate_rows_edit.text)

	var filename = current_filename
	if filename == "":
		filename = pattern.pattern_name.to_lower().replace(" ", "_") + ".tres"

	var save_path = PATTERNS_DIR + filename
	var result = ResourceSaver.save(pattern, save_path)
	if result == OK:
		print("Saved:", save_path)
		current_filename = filename
		_populate_load_dropdown()
	else:
		push_error("Save failed: " + str(result))


func _parse_int_list(text: String) -> Array[int]:
	var result: Array[int] = []
	if text.strip_edges() == "":
		return result
	for part in text.split(","):
		var trimmed = part.strip_edges()
		if trimmed.is_valid_int():
			result.append(int(trimmed))
	return result


func _populate_load_dropdown():
	load_dropdown.clear()
	load_dropdown.add_item("(load existing...)", -1)
	var pattern_files = _list_files_in_dir(PATTERNS_DIR, ["tres"])
	for i in range(pattern_files.size()):
		load_dropdown.add_item(pattern_files[i], i)


func _list_files_in_dir(path: String, extensions: Array) -> Array:
	var files = []
	var all = ResourceLoader.list_directory(path)
	for f in all:
		for ext in extensions:
			if f.ends_with("." + ext):
				files.append(f)
				break
	files.sort()
	return files


func _on_load_selected(index: int):
	if index <= 0:
		return
	var filename = load_dropdown.get_item_text(index)
	_load_pattern_from_file(filename)


func _load_pattern_from_file(filename: String):
	var path = PATTERNS_DIR + filename
	var pattern: PatternData = ResourceLoader.load(path)
	if not pattern:
		push_error("Failed to load: " + path)
		return

	current_filename = filename
	pattern_name_edit.text = pattern.pattern_name

	_init_grid_data()

	# Convert peg ids to color names when loading
	if pattern.grid != null and pattern.grid.size() > 0:
		for r in range(pattern.grid.size()):
			if not (pattern.grid[r] is Array):
				continue
			for c in range(pattern.grid[r].size()):
				if r < MAX_GRID_HEIGHT and c < MAX_GRID_WIDTH:
					var cell = pattern.grid[r][c]
					if cell is int:
						grid_data[r][c] = PEG_ID_TO_COLOR.get(cell, "")
					else:
						grid_data[r][c] = cell

	for r in range(MAX_GRID_HEIGHT):
		for c in range(MAX_GRID_WIDTH):
			_refresh_cell(r, c)

	allowed_rows_edit.text = ",".join(pattern.allowed_rows.map(func(i): return str(i)))
	duplicate_rows_edit.text = ",".join(pattern.duplicate_rows.map(func(i): return str(i)))

	var dup_idx = DUPLICATE_TYPES.find(pattern.duplicate_type)
	if dup_idx >= 0:
		duplicate_type_dropdown.select(dup_idx)


func _on_new_pressed():
	current_filename = ""
	pattern_name_edit.text = ""
	_init_grid_data()
	for r in range(MAX_GRID_HEIGHT):
		for c in range(MAX_GRID_WIDTH):
			_refresh_cell(r, c)
	allowed_rows_edit.text = ""
	duplicate_rows_edit.text = ""
	duplicate_type_dropdown.select(0)


func _on_clear_pressed():
	_init_grid_data()
	for r in range(MAX_GRID_HEIGHT):
		for c in range(MAX_GRID_WIDTH):
			_refresh_cell(r, c)
