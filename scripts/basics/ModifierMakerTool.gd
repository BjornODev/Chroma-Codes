extends Control

# =========================
# MODIFIER MAKER TOOL
# Runtime editor for creating ModifierData .tres files
# =========================

const MODIFIERS_DIR := "res://data/modifiers/"
const ICONS_DIR := "res://assets/mod_icons/"
const PATTERNS_DIR := "res://data/patterns/"

const EVENT_FIELDS := {
	"pattern_triggered": ["pattern"],
	"row_submitted": [],
	"panel_activated": ["color", "count"],
	"Damage Taken": [],
	"feedback_received": [],
	"map_unlock_triggered": [],
	"dollar_changed": ["dollar_index", "state"],
	"health_threshold": ["threshold", "direction"],
	"peg_threshold": ["color", "threshold", "direction"],
	"feedback_obscured": [],
	"feedback_count": ["feedback_type", "count"],
}

const EVENT_TYPES := [
	"pattern_triggered",
	"row_submitted",
	"panel_activated",
	"Damage Taken",
	"feedback_received",
	"map_unlock_triggered",
	"dollar_changed",
	"health_threshold",
	"peg_threshold",
	"feedback_obscured",
	"feedback_count",
]

const THRESHOLD_KEYS := [
	"red",
	"yellow",
	"green",
	"white",
	"purple",
	"orange",
	"feedback_black",
	"feedback_white",
]

const EFFECT_TYPES := [
	"Wide",
	"Trapped",
	"Sudden Spike",
	"Obscure",
	"Short",
	"Remove Color",
	"Remove All",
	"Goop",
	"Extra Damage",
	"Unlight Dollar",
]

const CONDITION_TYPES := [
	"peg_count",
	"health",
	"dollars",
	"dollar_lit",
	"wild_pegs",
]

const COMPARISONS := [">", ">=", "<", "<=", "==", "!="]
const CONDITION_MODES := ["and", "or"]

const PHASES := ["", "pre_build", "post_build"]
const COLORS := ["red", "yellow", "green", "white", "purple", "orange"]
const FEEDBACK_TYPES := ["black", "white", "none"]
const STATES := ["lit", "unlit"]
const DIRECTIONS := ["down", "up"]

var current_filename := ""

@onready var name_edit = $MainHBox/SharedColumn/ScrollContainer/SharedSection/NameEdit
@onready var description_edit = $MainHBox/SharedColumn/ScrollContainer/SharedSection/DescriptionEdit
@onready var icon_dropdown = $MainHBox/SharedColumn/ScrollContainer/SharedSection/IconDropdown
@onready var phase_dropdown = $MainHBox/SharedColumn/ScrollContainer/SharedSection/PhaseDropdown
@onready var triggers_list = $MainHBox/SharedColumn/ScrollContainer/SharedSection/TriggersList
@onready var effects_list = $MainHBox/SharedColumn/ScrollContainer/SharedSection/EffectsList

@onready var new_button = $TopBar/NewButton
@onready var load_dropdown = $TopBar/LoadDropdown
@onready var duplicate_button = $TopBar/DuplicateButton
@onready var save_button = $TopBar/SaveButton
@onready var preview_button = $TopBar/PreviewButton

@onready var tooltip_preview = $TooltipPreview


func _ready():
	_populate_dropdowns()
	_setup_signals()
	_clear_form()

	var add_event_btn = triggers_list.get_node("AddEventTriggerButton")
	var add_threshold_btn = triggers_list.get_node("AddThresholdTriggerButton")
	var add_condition_btn = triggers_list.get_node("AddConditionButton")
	add_event_btn.pressed.connect(_on_add_event_trigger)
	add_threshold_btn.pressed.connect(_on_add_threshold_trigger)
	add_condition_btn.pressed.connect(_on_add_condition)

	var add_effect_btn = effects_list.get_node("AddButton")
	add_effect_btn.pressed.connect(_on_add_effect)


func _populate_dropdowns():
	icon_dropdown.clear()
	icon_dropdown.add_item("(none)", -1)
	var icon_files = _list_files_in_dir(ICONS_DIR, ["png", "svg", "jpg"])
	for i in range(icon_files.size()):
		icon_dropdown.add_item(icon_files[i], i)

	phase_dropdown.clear()
	for p in PHASES:
		phase_dropdown.add_item(p if p != "" else "(runtime)")

	load_dropdown.clear()
	load_dropdown.add_item("(load existing...)", -1)
	var mod_files = _list_files_in_dir(MODIFIERS_DIR, ["tres"])
	for i in range(mod_files.size()):
		load_dropdown.add_item(mod_files[i], i)


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


func _setup_signals():
	save_button.pressed.connect(_on_save_pressed)
	new_button.pressed.connect(_on_new_pressed)
	duplicate_button.pressed.connect(_on_duplicate_pressed)
	preview_button.pressed.connect(_on_preview_pressed)
	load_dropdown.item_selected.connect(_on_load_selected)


func _clear_form():
	current_filename = ""
	name_edit.text = ""
	description_edit.text = ""
	icon_dropdown.select(0)
	phase_dropdown.select(0)
	_clear_dynamic_list(triggers_list)
	_clear_dynamic_list(effects_list)


func _clear_dynamic_list(list: Container):
	for child in list.get_children():
		if child.name == "AddButton":
			continue
		if child.name == "AddEventTriggerButton":
			continue
		if child.name == "AddThresholdTriggerButton":
			continue
		if child.name == "AddConditionButton":
			continue
		child.queue_free()


func _on_new_pressed():
	_clear_form()


func _on_load_selected(index: int):
	if index <= 0:
		return
	var filename = load_dropdown.get_item_text(index)
	_load_modifier_from_file(filename)


func _load_modifier_from_file(filename: String):
	var path = MODIFIERS_DIR + filename
	var modifier: ModifierData = ResourceLoader.load(path)
	if not modifier:
		push_error("Failed to load: " + path)
		return

	current_filename = filename
	name_edit.text = modifier.modifier_name
	description_edit.text = modifier.modifier_description

	if modifier.icon:
		var icon_filename = modifier.icon.resource_path.get_file()
		for i in range(icon_dropdown.item_count):
			if icon_dropdown.get_item_text(i) == icon_filename:
				icon_dropdown.select(i)
				break

	var phase_idx = PHASES.find(modifier.phase)
	if phase_idx >= 0:
		phase_dropdown.select(phase_idx)

	_clear_dynamic_list(triggers_list)
	for trigger in modifier.trigger:
		if trigger.has("event"):
			_add_event_trigger_row(trigger)
		elif trigger.has("condition"):
			_add_condition_row(trigger)
		else:
			_add_threshold_trigger_row(trigger)

	_clear_dynamic_list(effects_list)
	for key in modifier.base_effect.keys():
		_add_effect_row(key, modifier.base_effect[key])


func _on_duplicate_pressed():
	if current_filename == "":
		return
	current_filename = ""
	name_edit.text = name_edit.text + " Copy"


# =========================
# EVENT TRIGGER ROWS
# =========================

func _on_add_event_trigger():
	_add_event_trigger_row()


func _add_event_trigger_row(initial_data: Dictionary = {}):
	var row = HBoxContainer.new()
	row.set_meta("row_type", "event")

	var type_label = Label.new()
	type_label.text = "Event:"
	row.add_child(type_label)

	var event_dropdown = OptionButton.new()
	event_dropdown.custom_minimum_size = Vector2(200, 0)
	for ev in EVENT_TYPES:
		event_dropdown.add_item(ev)
	row.add_child(event_dropdown)

	var extra_field_container = HBoxContainer.new()
	extra_field_container.name = "ExtraFields"
	row.add_child(extra_field_container)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	event_dropdown.item_selected.connect(func(idx):
		_rebuild_extra_fields(extra_field_container, EVENT_TYPES[idx])
	)

	var add_event_btn = triggers_list.get_node("AddEventTriggerButton")
	triggers_list.add_child(row)
	triggers_list.move_child(row, add_event_btn.get_index())

	if initial_data.has("event"):
		var idx = EVENT_TYPES.find(initial_data["event"])
		if idx >= 0:
			event_dropdown.select(idx)
			_rebuild_extra_fields(extra_field_container, initial_data["event"], initial_data)
	else:
		_rebuild_extra_fields(extra_field_container, EVENT_TYPES[event_dropdown.selected])


func _rebuild_extra_fields(container: HBoxContainer, event_name: String, initial: Dictionary = {}):
	for child in container.get_children():
		child.queue_free()

	var fields = EVENT_FIELDS.get(event_name, [])
	for field in fields:
		var label = Label.new()
		label.text = field + ":"
		container.add_child(label)

		if field == "pattern":
			var pattern_dropdown = OptionButton.new()
			pattern_dropdown.name = "Field_pattern"
			pattern_dropdown.custom_minimum_size = Vector2(180, 0)
			var patterns = _list_files_in_dir(PATTERNS_DIR, ["tres"])
			for p in patterns:
				pattern_dropdown.add_item(p.replace(".tres", ""))
			container.add_child(pattern_dropdown)
			if initial.has("pattern"):
				for i in range(pattern_dropdown.item_count):
					if pattern_dropdown.get_item_text(i) == initial["pattern"]:
						pattern_dropdown.select(i)
						break

		elif field == "color":
			var color_dropdown = OptionButton.new()
			color_dropdown.name = "Field_color"
			color_dropdown.custom_minimum_size = Vector2(120, 0)
			for c in COLORS:
				color_dropdown.add_item(c)
			container.add_child(color_dropdown)
			if initial.has("color"):
				var idx = COLORS.find(initial["color"])
				if idx >= 0:
					color_dropdown.select(idx)

		elif field == "feedback_type":
			var fb_dropdown = OptionButton.new()
			fb_dropdown.name = "Field_feedback_type"
			fb_dropdown.custom_minimum_size = Vector2(120, 0)
			for t in FEEDBACK_TYPES:
				fb_dropdown.add_item(t)
			container.add_child(fb_dropdown)
			if initial.has("feedback_type"):
				var idx = FEEDBACK_TYPES.find(initial["feedback_type"])
				if idx >= 0:
					fb_dropdown.select(idx)

		elif field == "state":
			var state_dropdown = OptionButton.new()
			state_dropdown.name = "Field_state"
			state_dropdown.custom_minimum_size = Vector2(120, 0)
			for s in STATES:
				state_dropdown.add_item(s)
			container.add_child(state_dropdown)
			if initial.has("state"):
				var idx = STATES.find(initial["state"])
				if idx >= 0:
					state_dropdown.select(idx)

		elif field == "direction":
			var dir_dropdown = OptionButton.new()
			dir_dropdown.name = "Field_direction"
			dir_dropdown.custom_minimum_size = Vector2(100, 0)
			for d in DIRECTIONS:
				dir_dropdown.add_item(d)
			container.add_child(dir_dropdown)
			if initial.has("direction"):
				var idx = DIRECTIONS.find(initial["direction"])
				if idx >= 0:
					dir_dropdown.select(idx)

		else:
			var line_edit = LineEdit.new()
			line_edit.name = "Field_" + field
			line_edit.custom_minimum_size = Vector2(80, 0)
			line_edit.text = str(initial.get(field, 1))
			container.add_child(line_edit)


# =========================
# THRESHOLD TRIGGER ROWS
# =========================

func _on_add_threshold_trigger():
	_add_threshold_trigger_row()


func _add_threshold_trigger_row(initial_data: Dictionary = {}):
	var row = HBoxContainer.new()
	row.set_meta("row_type", "threshold")

	var type_label = Label.new()
	type_label.text = "Threshold:"
	row.add_child(type_label)

	var key_dropdown = OptionButton.new()
	key_dropdown.custom_minimum_size = Vector2(160, 0)
	for k in THRESHOLD_KEYS:
		key_dropdown.add_item(k)
	row.add_child(key_dropdown)

	var value_edit = LineEdit.new()
	value_edit.custom_minimum_size = Vector2(80, 0)
	value_edit.text = "1"
	row.add_child(value_edit)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	var add_threshold_btn = triggers_list.get_node("AddThresholdTriggerButton")
	triggers_list.add_child(row)
	triggers_list.move_child(row, add_threshold_btn.get_index())

	if not initial_data.is_empty():
		for k in initial_data.keys():
			if k == "event" or k == "condition":
				continue
			var idx = THRESHOLD_KEYS.find(k)
			if idx >= 0:
				key_dropdown.select(idx)
				value_edit.text = str(initial_data[k])
			break


# =========================
# CONDITION ROWS
# =========================

func _on_add_condition():
	_add_condition_row()


func _add_condition_row(initial_data: Dictionary = {}):
	var row = HBoxContainer.new()
	row.set_meta("row_type", "condition")

	var type_label = Label.new()
	type_label.text = "Condition:"
	row.add_child(type_label)

	var type_dropdown = OptionButton.new()
	type_dropdown.name = "ConditionType"
	type_dropdown.custom_minimum_size = Vector2(140, 0)
	for c in CONDITION_TYPES:
		type_dropdown.add_item(c)
	row.add_child(type_dropdown)

	var extras = HBoxContainer.new()
	extras.name = "ConditionExtras"
	row.add_child(extras)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	type_dropdown.item_selected.connect(func(idx):
		_rebuild_condition_extras(extras, CONDITION_TYPES[idx])
	)

	var add_condition_btn = triggers_list.get_node("AddConditionButton")
	triggers_list.add_child(row)
	triggers_list.move_child(row, add_condition_btn.get_index())

	if initial_data.has("condition"):
		var idx = CONDITION_TYPES.find(initial_data["condition"])
		if idx >= 0:
			type_dropdown.select(idx)
			_rebuild_condition_extras(extras, initial_data["condition"], initial_data)
	else:
		_rebuild_condition_extras(extras, CONDITION_TYPES[type_dropdown.selected])


func _rebuild_condition_extras(container: HBoxContainer, condition_type: String, initial: Dictionary = {}):
	for child in container.get_children():
		child.queue_free()

	var mode_label = Label.new()
	mode_label.text = "mode:"
	container.add_child(mode_label)
	var mode_dropdown = OptionButton.new()
	mode_dropdown.name = "Cond_mode"
	mode_dropdown.custom_minimum_size = Vector2(60, 0)
	for m in CONDITION_MODES:
		mode_dropdown.add_item(m)
	container.add_child(mode_dropdown)
	if initial.has("mode"):
		var idx = CONDITION_MODES.find(initial["mode"])
		if idx >= 0:
			mode_dropdown.select(idx)

	if condition_type == "peg_count":
		var color_label = Label.new()
		color_label.text = "color:"
		container.add_child(color_label)
		var color_dropdown = OptionButton.new()
		color_dropdown.name = "Cond_color"
		color_dropdown.custom_minimum_size = Vector2(120, 0)
		for c in COLORS:
			color_dropdown.add_item(c)
		container.add_child(color_dropdown)
		if initial.has("color"):
			var idx = COLORS.find(initial["color"])
			if idx >= 0:
				color_dropdown.select(idx)

	var comp_label = Label.new()
	comp_label.text = "compare:"
	container.add_child(comp_label)
	var comp_dropdown = OptionButton.new()
	comp_dropdown.name = "Cond_comparison"
	comp_dropdown.custom_minimum_size = Vector2(60, 0)
	for c in COMPARISONS:
		comp_dropdown.add_item(c)
	container.add_child(comp_dropdown)
	if initial.has("comparison"):
		var idx = COMPARISONS.find(initial["comparison"])
		if idx >= 0:
			comp_dropdown.select(idx)
	else:
		comp_dropdown.select(0)

	var value_label = Label.new()
	value_label.text = "value:"
	container.add_child(value_label)
	var value_edit = LineEdit.new()
	value_edit.name = "Cond_value"
	value_edit.custom_minimum_size = Vector2(60, 0)
	value_edit.text = str(initial.get("value", 0))
	container.add_child(value_edit)


# =========================
# EFFECT ROWS
# =========================

func _on_add_effect():
	_add_effect_row()


func _add_effect_row(initial_key: String = "", initial_value = 1):
	var row = HBoxContainer.new()

	var key_dropdown = OptionButton.new()
	key_dropdown.custom_minimum_size = Vector2(160, 0)
	for e in EFFECT_TYPES:
		key_dropdown.add_item(e)
	row.add_child(key_dropdown)

	var value_edit = LineEdit.new()
	value_edit.custom_minimum_size = Vector2(80, 0)
	value_edit.text = str(initial_value)
	row.add_child(value_edit)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	var add_btn = effects_list.get_node("AddButton")
	effects_list.add_child(row)
	effects_list.move_child(row, add_btn.get_index())

	if initial_key != "":
		var idx = EFFECT_TYPES.find(initial_key)
		if idx >= 0:
			key_dropdown.select(idx)


# =========================
# SAVE / COLLECT
# =========================

func _on_save_pressed():
	var modifier = ModifierData.new()
	modifier.modifier_name = name_edit.text
	modifier.modifier_description = description_edit.text
	modifier.phase = PHASES[phase_dropdown.selected]

	if icon_dropdown.selected > 0:
		var icon_filename = icon_dropdown.get_item_text(icon_dropdown.selected)
		modifier.icon = load(ICONS_DIR + icon_filename)

	modifier.trigger = _collect_triggers()
	modifier.base_effect = _collect_effects()

	var filename = current_filename
	if filename == "":
		filename = modifier.modifier_name.to_lower().replace(" ", "_") + ".tres"

	var save_path = MODIFIERS_DIR + filename
	var result = ResourceSaver.save(modifier, save_path)
	if result == OK:
		print("Saved:", save_path)
		current_filename = filename
		_populate_dropdowns()
	else:
		push_error("Save failed: " + str(result))


func _collect_triggers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in triggers_list.get_children():
		if child.name == "AddEventTriggerButton" or child.name == "AddThresholdTriggerButton" or child.name == "AddConditionButton":
			continue
		if not (child is HBoxContainer):
			continue

		var row_type = child.get_meta("row_type", "event")

		if row_type == "event":
			var event_dropdown = child.get_child(1) as OptionButton
			var event_name = EVENT_TYPES[event_dropdown.selected]
			var trigger = {"event": event_name}

			var extras = child.get_node("ExtraFields")
			for extra in extras.get_children():
				if extra.name == "Field_pattern":
					trigger["pattern"] = extra.get_item_text(extra.selected)
				elif extra.name == "Field_color":
					trigger["color"] = extra.get_item_text(extra.selected)
				elif extra.name == "Field_feedback_type":
					trigger["feedback_type"] = extra.get_item_text(extra.selected)
				elif extra.name == "Field_state":
					trigger["state"] = extra.get_item_text(extra.selected)
				elif extra.name == "Field_direction":
					trigger["direction"] = extra.get_item_text(extra.selected)
				elif extra.name == "Field_count":
					trigger["count"] = int(extra.text)
				elif extra.name == "Field_index":
					trigger["index"] = int(extra.text)
				elif extra.name == "Field_threshold":
					trigger["threshold"] = int(extra.text)
				elif extra.name == "Field_dollar_index":
					trigger["dollar_index"] = int(extra.text)

			result.append(trigger)

		elif row_type == "condition":
			var cond_type_dropdown = child.get_node("ConditionType") as OptionButton
			var condition = {"condition": CONDITION_TYPES[cond_type_dropdown.selected]}
			var extras = child.get_node("ConditionExtras")
			for extra in extras.get_children():
				if extra.name == "Cond_mode":
					condition["mode"] = extra.get_item_text(extra.selected)
				elif extra.name == "Cond_color":
					condition["color"] = extra.get_item_text(extra.selected)
				elif extra.name == "Cond_comparison":
					condition["comparison"] = extra.get_item_text(extra.selected)
				elif extra.name == "Cond_value":
					condition["value"] = int(extra.text)
			result.append(condition)

		else:
			var key_dropdown = child.get_child(1) as OptionButton
			var value_edit = child.get_child(2) as LineEdit
			var key = THRESHOLD_KEYS[key_dropdown.selected]
			var value = int(value_edit.text)
			result.append({key: value})

	return result


func _collect_effects() -> Dictionary:
	var result := {}
	for child in effects_list.get_children():
		if child.name == "AddButton":
			continue
		if not (child is HBoxContainer):
			continue

		var key_dropdown = child.get_child(0) as OptionButton
		var value_edit = child.get_child(1) as LineEdit
		var key = EFFECT_TYPES[key_dropdown.selected]
		var value = int(value_edit.text)
		result[key] = value
	return result


# =========================
# PREVIEW
# =========================

func _on_preview_pressed():
	var modifier = ModifierData.new()
	modifier.modifier_name = name_edit.text
	modifier.modifier_description = description_edit.text
	modifier.phase = PHASES[phase_dropdown.selected]
	modifier.trigger = _collect_triggers()
	modifier.base_effect = _collect_effects()
	modifier.level = 1

	if tooltip_preview.visible:
		tooltip_preview.visible = false
	else:
		tooltip_preview.visible = true
		tooltip_preview.display_modifier(modifier)


func _on_go_to_items() -> void:
	get_tree().change_scene_to_file("res://scenes/ItemMakerTool.tscn")


func _on_go_to_patterns() -> void:
	get_tree().change_scene_to_file("res://scenes/PatternMakerTool.tscn")