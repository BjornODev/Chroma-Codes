extends CanvasLayer

# =========================
# PLAYTEST MENU
# A debug overlay toggled with Q. Sliders tune values that make the game easier
# or harder; "Start New Game" applies them and loads the map. Builds its own UI
# in code so no .tscn is required.
#
# SETUP: add this script to an autoload named "PlaytestMenu" (so Q works on every
# screen), OR add it as a CanvasLayer node in a scene. It needs PlaytestSettings
# to also be an autoload.
# =========================

const TOGGLE_ACTION := "Menu Button"
const PANEL_WIDTH := 460.0
const ROW_HEIGHT := 64.0

# Each entry: label, settings property, min, max, step, default
const SETTINGS := [
	{"label": "Starting Health",     "prop": "starting_health",  "min": 1,  "max": 20,  "step": 1, "default": 5},
	{"label": "Starting Pegs",       "prop": "starting_pegs",    "min": 0,  "max": 60,  "step": 1, "default": 20},
	{"label": "Clicked Panel Pegs",  "prop": "clicked_refill",   "min": 0,  "max": 20,  "step": 1, "default": 5},
	{"label": "Adjacent Panel Pegs", "prop": "adjacent_refill",  "min": 0,  "max": 20,  "step": 1, "default": 1},
	{"label": "Panels Remaining",    "prop": "panels_remaining", "min": 1,  "max": 30,  "step": 1, "default": 10},
	{"label": "Base Quota",          "prop": "base_quota",       "min": 10, "max": 300, "step": 5, "default": 50},
]

var _root: Control
var _value_labels := {}      # prop -> Label
var _sliders := {}           # prop -> HSlider
var _open := false
var _font: Font


func _ready():
	layer = 128                       # draw on top of everything
	_font = load("res://assets/gomarice_goma_block.ttf")
	_build_ui()
	_root.visible = false
	# Make sure the menu still works while the game is paused, if you pause it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if Input.is_action_pressed(TOGGLE_ACTION):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle():
	_open = not _open
	_root.visible = _open
	if _open:
		_sync_from_settings()


# =========================
# UI CONSTRUCTION
# =========================

func _build_ui():
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dim background
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	# Panel centered
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var total_height = 120 + SETTINGS.size() * ROW_HEIGHT + 90
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, total_height)
	panel.position = Vector2(-PANEL_WIDTH / 2.0, -total_height / 2.0)
	_root.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#15151C")
	style.border_color = Color("#3BB143")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "PLAYTEST SETTINGS"
	_style_label(title, 28, Color("#3BB143"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "Press Q to close"
	_style_label(hint, 14, Color("#888888"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# One row per setting
	for entry in SETTINGS:
		vbox.add_child(_build_slider_row(entry))

	vbox.add_child(HSeparator.new())

	# Buttons row
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var reset_btn = Button.new()
	reset_btn.text = "Reset Defaults"
	_style_button(reset_btn, Color("#555555"))
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)

	var start_btn = Button.new()
	start_btn.text = "Start New Game"
	_style_button(start_btn, Color("#3BB143"))
	start_btn.pressed.connect(_on_start_pressed)
	buttons.add_child(start_btn)


func _build_slider_row(entry: Dictionary) -> Control:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 2)

	var header = HBoxContainer.new()
	row.add_child(header)

	var name_label = Label.new()
	name_label.text = entry["label"]
	_style_label(name_label, 18, Color("#FFFFFF"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var value_label = Label.new()
	value_label.text = str(entry["default"])
	_style_label(value_label, 18, Color("#FFF200"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(60, 0)
	header.add_child(value_label)
	_value_labels[entry["prop"]] = value_label

	var slider = HSlider.new()
	slider.min_value = entry["min"]
	slider.max_value = entry["max"]
	slider.step = entry["step"]
	slider.value = entry["default"]
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(entry["prop"]))
	row.add_child(slider)
	_sliders[entry["prop"]] = slider

	return row


# =========================
# INTERACTION
# =========================

func _on_slider_changed(value: float, prop: String):
	var v = int(value)
	PlaytestSettings.set(prop, v)
	if _value_labels.has(prop):
		_value_labels[prop].text = str(v)


func _on_reset_pressed():
	for entry in SETTINGS:
		var prop = entry["prop"]
		PlaytestSettings.set(prop, entry["default"])
		if _sliders.has(prop):
			_sliders[prop].value = entry["default"]


func _on_start_pressed():
	# Turn overrides on and start a fresh run, then apply, then load the map.
	PlaytestSettings.enabled = true

	# Reset run state and generate the run so its values exist to overwrite.
	RunProgressionManager.start_new_run()
	if MapManager.has_method("start_run"):
		MapManager.start_run(randi())

	PlaytestSettings.apply_to_new_run()

	_open = false
	_root.visible = false
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")


# Pull current settings values back into the sliders (e.g. when reopening).
func _sync_from_settings():
	for entry in SETTINGS:
		var prop = entry["prop"]
		var v = PlaytestSettings.get(prop)
		if _sliders.has(prop):
			_sliders[prop].value = v
		if _value_labels.has(prop):
			_value_labels[prop].text = str(int(v))


# =========================
# STYLING HELPERS
# =========================

func _style_label(label: Label, size: int, color: Color):
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _style_button(btn: Button, accent: Color):
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(170, 48)
	var sb = StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = accent.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = sb.duplicate()
	pressed.bg_color = accent.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)