extends Control

# =========================
# ITEM MAKER TOOL
# Runtime editor for creating ItemData .tres files
# =========================

const ITEMS_DIR := "res://data/items/"
const ICONS_DIR := "res://assets/items/"
const PATTERNS_DIR := "res://data/patterns/"

const EVENT_FIELDS := {
	"pattern_triggered": ["pattern"],
	"row_submitted": [],
	"panel_activated": ["color", "count"],
	"Damage Taken": [],
	"feedback_received": [],
	"map_unlock_triggered": [],
}

const EVENT_TYPES := [
	"pattern_triggered",
	"row_submitted",
	"panel_activated",
	"Damage Taken",
	"feedback_received",
	"map_unlock_triggered",
]

const CHARGE_CONDITION_TYPES := [
	"row_submitted",
	"peg_placed",
	"damage_taken",
	"health_healed",
	"feedback_black",
	"feedback_white",
	"replace_used",
]

const COLORS := ["red", "yellow", "green", "white", "purple", "orange"]
const RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

const COLOR_KEYWORDS := ["AddPegsColor", "RemovePegsColor"]

var font: Font
var current_filename := ""

@onready var item_name_edit = $MainHBox/SharedColumn/ScrollContainer/SharedSection/NameEdit
@onready var description_edit = $MainHBox/SharedColumn/ScrollContainer/SharedSection/DescriptionEdit
@onready var icon_dropdown = $MainHBox/SharedColumn/ScrollContainer/SharedSection/IconDropdown
@onready var rarity_dropdown = $MainHBox/SharedColumn/ScrollContainer/SharedSection/RarityDropdown
@onready var price_edit = $MainHBox/SharedColumn/ScrollContainer/SharedSection/PriceEdit
@onready var gamble_only_check = $MainHBox/SharedColumn/ScrollContainer/SharedSection/GambleOnlyCheck
@onready var is_active_check = $MainHBox/SharedColumn/ScrollContainer/SharedSection/IsActiveCheck

@onready var passive_column = $MainHBox/PassiveColumn
@onready var passive_section = $MainHBox/PassiveColumn/ScrollContainer/PassiveSection
@onready var triggers_list = $MainHBox/PassiveColumn/ScrollContainer/PassiveSection/TriggersList
@onready var keywords_list = $MainHBox/PassiveColumn/ScrollContainer/PassiveSection/KeywordsList

@onready var active_column = $MainHBox/ActiveColumn
@onready var active_section = $MainHBox/ActiveColumn/ScrollContainer/ActiveSection
@onready var charge_max_edit = $MainHBox/ActiveColumn/ScrollContainer/ActiveSection/ChargeMaxEdit
@onready var charge_conditions_list = $MainHBox/ActiveColumn/ScrollContainer/ActiveSection/ChargeConditionsList
@onready var active_keywords_list = $MainHBox/ActiveColumn/ScrollContainer/ActiveSection/ActiveKeywordsList

@onready var upgrade_tier_1 = $MainHBox/UpgradeColumn/ScrollContainer/UpgradeSection/Tier1
@onready var upgrade_tier_2 = $MainHBox/UpgradeColumn/ScrollContainer/UpgradeSection/Tier2
@onready var upgrade_tier_3 = $MainHBox/UpgradeColumn/ScrollContainer/UpgradeSection/Tier3

@onready var load_dropdown = $TopBar/LoadDropdown
@onready var duplicate_button = $TopBar/DuplicateButton
@onready var save_button = $TopBar/SaveButton
@onready var new_button = $TopBar/NewButton
@onready var preview_button = $TopBar/PreviewButton

@onready var tooltip_preview = $TooltipPreview


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	_populate_dropdowns()
	_setup_signals()
	_clear_form()
	is_active_check.toggled.connect(_on_is_active_toggled)
	_on_is_active_toggled(false)
	PopUpText.toggle_mult(false)

	var tiers = [upgrade_tier_1, upgrade_tier_2, upgrade_tier_3]
	for tier in tiers:
		tier.get_node("EffectList/AddButton").pressed.connect(
			func(): _on_add_tier_effect(tier)
		)
		tier.get_node("TriggerList/AddButton").pressed.connect(
			func(): _on_add_tier_trigger(tier)
		)


func _populate_dropdowns():
	icon_dropdown.clear()
	icon_dropdown.add_item("(none)", -1)
	var icon_files = _list_files_in_dir(ICONS_DIR, ["png", "svg", "jpg"])
	for i in range(icon_files.size()):
		icon_dropdown.add_item(icon_files[i], i)

	rarity_dropdown.clear()
	for i in range(RARITIES.size()):
		rarity_dropdown.add_item(RARITIES[i], i)

	load_dropdown.clear()
	load_dropdown.add_item("(load existing...)", -1)
	var item_files = _list_files_in_dir(ITEMS_DIR, ["tres"])
	for i in range(item_files.size()):
		load_dropdown.add_item(item_files[i], i)


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


func _on_is_active_toggled(is_active: bool):
	passive_column.visible = not is_active
	active_column.visible = is_active


func _clear_form():
	current_filename = ""
	item_name_edit.text = ""
	description_edit.text = ""
	icon_dropdown.select(0)
	rarity_dropdown.select(0)
	price_edit.text = "1"
	gamble_only_check.button_pressed = false
	is_active_check.button_pressed = false
	charge_max_edit.text = "10"
	_clear_dynamic_list(triggers_list)
	_clear_dynamic_list(keywords_list)
	_clear_dynamic_list(charge_conditions_list)
	_clear_dynamic_list(active_keywords_list)
	_clear_tier(upgrade_tier_1)
	_clear_tier(upgrade_tier_2)
	_clear_tier(upgrade_tier_3)


func _clear_dynamic_list(list: Container):
	for child in list.get_children():
		if child.name != "AddButton":
			child.queue_free()


func _clear_tier(tier_node: Node):
	_clear_dynamic_list(tier_node.get_node("EffectList"))
	_clear_dynamic_list(tier_node.get_node("TriggerList"))
	tier_node.get_node("ChargeDeltaEdit").text = "0"


func _on_new_pressed():
	_clear_form()


func _on_load_selected(index: int):
	if index <= 0:
		return
	var filename = load_dropdown.get_item_text(index)
	_load_item_from_file(filename)


func _load_item_from_file(filename: String):
	var path = ITEMS_DIR + filename
	var item: ItemData = ResourceLoader.load(path)
	if not item:
		push_error("Failed to load: " + path)
		return

	current_filename = filename
	item_name_edit.text = item.item_name
	description_edit.text = item.description
	price_edit.text = str(item.price)
	rarity_dropdown.select(item.rarity)
	gamble_only_check.button_pressed = item.is_gamble_only
	is_active_check.button_pressed = item.is_active
	_on_is_active_toggled(item.is_active)

	if item.icon:
		var icon_path = item.icon.resource_path
		var icon_filename = icon_path.get_file()
		for i in range(icon_dropdown.item_count):
			if icon_dropdown.get_item_text(i) == icon_filename:
				icon_dropdown.select(i)
				break

	_clear_dynamic_list(triggers_list)
	for trigger in item.triggers:
		_add_trigger_row(trigger)

	_clear_dynamic_list(keywords_list)
	for key in item.keywords:
		_load_keyword_into_list(keywords_list, key, item.keywords[key])

	charge_max_edit.text = str(item.charge_max)
	_clear_dynamic_list(charge_conditions_list)
	for cond in item.charge_conditions:
		_add_charge_condition_row(cond)

	_clear_dynamic_list(active_keywords_list)
	for key in item.active_keywords:
		_load_keyword_into_list(active_keywords_list, key, item.active_keywords[key])

	_load_tier(upgrade_tier_1, item.upgrade_tier_1_effect, item.upgrade_tier_1_trigger, item.upgrade_tier_1_charge_delta)
	_load_tier(upgrade_tier_2, item.upgrade_tier_2_effect, item.upgrade_tier_2_trigger, item.upgrade_tier_2_charge_delta)
	_load_tier(upgrade_tier_3, item.upgrade_tier_3_effect, item.upgrade_tier_3_trigger, item.upgrade_tier_3_charge_delta)


func _load_keyword_into_list(list: Container, key: String, value):
	if value is Dictionary:
		_add_keyword_row(list, key, value.get("amount", 1), value.get("color", ""))
	else:
		_add_keyword_row(list, key, value)


func _load_tier(tier_node: Node, effect: Dictionary, trigger: Dictionary, charge_delta: float):
	var effect_list = tier_node.get_node("EffectList")
	var trigger_list = tier_node.get_node("TriggerList")
	_clear_dynamic_list(effect_list)
	_clear_dynamic_list(trigger_list)

	for key in effect:
		_load_keyword_into_list(effect_list, key, effect[key])
	for key in trigger:
		_load_keyword_into_list(trigger_list, key, trigger[key])

	tier_node.get_node("ChargeDeltaEdit").text = str(charge_delta)


func _on_duplicate_pressed():
	if current_filename == "":
		return
	current_filename = ""
	item_name_edit.text = item_name_edit.text + " Copy"


func _add_trigger_row(initial_data: Dictionary = {}):
	var row = HBoxContainer.new()

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

	var add_btn = triggers_list.get_node("AddButton")
	triggers_list.add_child(row)
	triggers_list.move_child(row, add_btn.get_index())

	if initial_data.has("event"):
		var idx = EVENT_TYPES.find(initial_data["event"])
		if idx >= 0:
			event_dropdown.select(idx)
			_rebuild_extra_fields(extra_field_container, initial_data["event"], initial_data)


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

		elif field == "count" or field == "index":
			var line_edit = LineEdit.new()
			line_edit.name = "Field_" + field
			line_edit.custom_minimum_size = Vector2(80, 0)
			line_edit.text = str(initial.get(field, 1))
			container.add_child(line_edit)


func _add_keyword_row(list: Container, initial_key: String = "", initial_value = 1, initial_color: String = ""):
	var row = HBoxContainer.new()

	var key_dropdown = OptionButton.new()
	key_dropdown.custom_minimum_size = Vector2(180, 0)
	for kw in _get_keyword_list():
		key_dropdown.add_item(kw)
	row.add_child(key_dropdown)

	var color_dropdown = OptionButton.new()
	color_dropdown.name = "ColorDropdown"
	color_dropdown.custom_minimum_size = Vector2(120, 0)
	for c in COLORS:
		color_dropdown.add_item(c)
	row.add_child(color_dropdown)
	color_dropdown.visible = false

	var value_edit = LineEdit.new()
	value_edit.custom_minimum_size = Vector2(80, 0)
	value_edit.text = str(initial_value)
	row.add_child(value_edit)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	key_dropdown.item_selected.connect(func(idx):
		var keyword = key_dropdown.get_item_text(idx)
		color_dropdown.visible = keyword in COLOR_KEYWORDS
	)

	var add_btn = list.get_node("AddButton")
	list.add_child(row)
	list.move_child(row, add_btn.get_index())

	if initial_key != "":
		for i in range(key_dropdown.item_count):
			if key_dropdown.get_item_text(i) == initial_key:
				key_dropdown.select(i)
				color_dropdown.visible = initial_key in COLOR_KEYWORDS
				break

	if initial_color != "":
		var idx = COLORS.find(initial_color)
		if idx >= 0:
			color_dropdown.select(idx)


func _add_charge_condition_row(initial_data: Dictionary = {}):
	var row = HBoxContainer.new()

	var type_dropdown = OptionButton.new()
	type_dropdown.custom_minimum_size = Vector2(180, 0)
	for c in CHARGE_CONDITION_TYPES:
		type_dropdown.add_item(c)
	row.add_child(type_dropdown)

	var amount_edit = LineEdit.new()
	amount_edit.custom_minimum_size = Vector2(80, 0)
	amount_edit.text = str(initial_data.get("amount", 1))
	row.add_child(amount_edit)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)

	var add_btn = charge_conditions_list.get_node("AddButton")
	charge_conditions_list.add_child(row)
	charge_conditions_list.move_child(row, add_btn.get_index())

	if initial_data.has("type"):
		var idx = CHARGE_CONDITION_TYPES.find(initial_data["type"])
		if idx >= 0:
			type_dropdown.select(idx)


func _get_keyword_list() -> Array:
	return [
		"Replace",
		"Cleanse",
		"Heal",
		"Reveal",
		"Clear",
		"Bleed",
		"Relight",
		"AddPegsColor",
		"AddPegsAll",
		"RemovePegsColor",
		"RemovePegsAll",
		"ExtraDollar",
		"UnlockAny",
	]


func _on_add_trigger():
	_add_trigger_row()


func _on_add_keyword():
	_add_keyword_row(keywords_list)


func _on_add_charge_condition():
	_add_charge_condition_row()


func _on_add_active_keyword():
	_add_keyword_row(active_keywords_list)


func _on_add_tier_effect(tier_node: Node):
	_add_keyword_row(tier_node.get_node("EffectList"))


func _on_add_tier_trigger(tier_node: Node):
	_add_keyword_row(tier_node.get_node("TriggerList"))


func _on_save_pressed():
	var item = ItemData.new()

	item.item_name = item_name_edit.text
	item.description = description_edit.text
	item.price = int(price_edit.text)
	item.rarity = rarity_dropdown.selected
	item.is_gamble_only = gamble_only_check.button_pressed
	item.is_active = is_active_check.button_pressed

	if icon_dropdown.selected > 0:
		var icon_filename = icon_dropdown.get_item_text(icon_dropdown.selected)
		item.icon = load(ICONS_DIR + icon_filename)

	item.triggers = _collect_triggers()
	item.keywords = _collect_keywords(keywords_list)

	item.charge_max = float(charge_max_edit.text)
	item.charge_conditions = _collect_charge_conditions()
	item.active_keywords = _collect_keywords(active_keywords_list)

	item.upgrade_tier_1_effect = _collect_keywords(upgrade_tier_1.get_node("EffectList"))
	item.upgrade_tier_1_trigger = _collect_keywords(upgrade_tier_1.get_node("TriggerList"))
	item.upgrade_tier_1_charge_delta = float(upgrade_tier_1.get_node("ChargeDeltaEdit").text)

	item.upgrade_tier_2_effect = _collect_keywords(upgrade_tier_2.get_node("EffectList"))
	item.upgrade_tier_2_trigger = _collect_keywords(upgrade_tier_2.get_node("TriggerList"))
	item.upgrade_tier_2_charge_delta = float(upgrade_tier_2.get_node("ChargeDeltaEdit").text)

	item.upgrade_tier_3_effect = _collect_keywords(upgrade_tier_3.get_node("EffectList"))
	item.upgrade_tier_3_trigger = _collect_keywords(upgrade_tier_3.get_node("TriggerList"))
	item.upgrade_tier_3_charge_delta = float(upgrade_tier_3.get_node("ChargeDeltaEdit").text)

	var filename = current_filename
	if filename == "":
		filename = item.item_name.to_lower().replace(" ", "_") + ".tres"

	var save_path = ITEMS_DIR + filename
	var result = ResourceSaver.save(item, save_path)
	if result == OK:
		print("Saved:", save_path)
		current_filename = filename
		_populate_dropdowns()
	else:
		push_error("Save failed: " + str(result))


func _collect_triggers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in triggers_list.get_children():
		if child.name == "AddButton":
			continue
		var dropdown = child.get_child(0) as OptionButton
		var event_name = EVENT_TYPES[dropdown.selected]
		var trigger = {"event": event_name}

		var extras = child.get_node("ExtraFields")
		for extra in extras.get_children():
			if extra.name == "Field_pattern":
				trigger["pattern"] = extra.get_item_text(extra.selected)
			elif extra.name == "Field_color":
				trigger["color"] = extra.get_item_text(extra.selected)
			elif extra.name == "Field_count":
				trigger["count"] = int(extra.text)
			elif extra.name == "Field_index":
				trigger["index"] = int(extra.text)

		result.append(trigger)
	return result


func _collect_keywords(list: Container) -> Dictionary:
	var result = {}
	for child in list.get_children():
		if child.name == "AddButton":
			continue
		var key_dropdown = child.get_child(0) as OptionButton
		var color_dropdown = child.get_node("ColorDropdown") as OptionButton
		var value_edit = child.get_child(2) as LineEdit
		var key = key_dropdown.get_item_text(key_dropdown.selected)
		var value = int(value_edit.text)

		if key in COLOR_KEYWORDS:
			result[key] = {
				"color": color_dropdown.get_item_text(color_dropdown.selected),
				"amount": value
			}
		else:
			result[key] = value
	return result


func _collect_charge_conditions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in charge_conditions_list.get_children():
		if child.name == "AddButton":
			continue
		var type_dropdown = child.get_child(0) as OptionButton
		var amount_edit = child.get_child(1) as LineEdit
		result.append({
			"type": CHARGE_CONDITION_TYPES[type_dropdown.selected],
			"amount": int(amount_edit.text)
		})
	return result


func _on_preview_pressed():
	var item = ItemData.new()
	item.item_name = item_name_edit.text
	item.description = description_edit.text
	item.rarity = rarity_dropdown.selected
	item.is_active = is_active_check.button_pressed
	item.triggers = _collect_triggers()
	item.keywords = _collect_keywords(keywords_list)
	item.charge_max = float(charge_max_edit.text)
	item.charge_conditions = _collect_charge_conditions()
	item.active_keywords = _collect_keywords(active_keywords_list)

	if tooltip_preview.visible:
		tooltip_preview.visible = false
	else:
		tooltip_preview.visible = true
	if item.is_active:
		tooltip_preview.display_active_item(item)
	else:
		tooltip_preview.display_item(item)
