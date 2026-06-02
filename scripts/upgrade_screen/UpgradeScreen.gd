extends Control

@onready var item_list = $HBoxContainer/ItemListSection/ScrollContainer/ItemList
@onready var upgrade_details = $HBoxContainer/DetailsSection/UpgradeDetails
@onready var item_name_label = $HBoxContainer/DetailsSection/ItemNameLabel
@onready var current_stats_label = $HBoxContainer/DetailsSection/CurrentStatsLabel
@onready var upgrade_preview_label = $HBoxContainer/DetailsSection/UpgradePreviewLabel
@onready var pattern_preview_container = $HBoxContainer/DetailsSection/PatternPreviewContainer
@onready var confirm_button = $HBoxContainer/DetailsSection/ConfirmButton
@onready var leave_button = $LeaveButton
@onready var iris_wipe = $IrisWipe
@onready var background_layer = $BackgroundLayer
@onready var tooltip = $TooltipLayer/Tooltip
@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var money_label = $HUDLayer/HUDRoot/MoneyLabel

const ITEM_ROW_SCENE = preload("res://scenes/UpgradeItemRow.tscn")

var font: Font
var selected_item: ItemData = null
var selected_row: Node = null
var cost_type: String = ""
var cost_amount: int = 0

var upgraded_this_visit := false


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	
	# Apply font to all static labels
	for label in [item_name_label, current_stats_label, upgrade_preview_label]:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 45)
	
	# Section title labels
	for node in [$HBoxContainer/ItemListSection/Label, $HBoxContainer/DetailsSection]:
		if node is Label:
			node.add_theme_font_override("font", font)
			node.add_theme_font_size_override("font_size", 60)

	# Leave and confirm buttons
	var leave_label = leave_button.get_node_or_null("Label")
	if leave_label:
		leave_label.add_theme_font_override("font", font)
		leave_label.add_theme_font_size_override("font_size", 28)

	var confirm_label = confirm_button.get_node_or_null("Label")
	if confirm_label:
		confirm_label.add_theme_font_override("font", font)
		confirm_label.add_theme_font_size_override("font_size", 24)

	iris_wipe.instant_close()
	background_layer.change_background(randi())

	_build_item_list()
	_clear_details()
	populate_hud()

	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	RunProgressionManager.connect("dollars_changed", _on_dollars_changed)

	await get_tree().process_frame
	iris_wipe.iris_open(MapManager.last_panel_world_pos)


# =========================
# COST TYPE
# =========================


# =========================
# ITEM LIST
# =========================

func _build_item_list():
	for child in item_list.get_children():
		child.queue_free()

	var upgradeable = ItemManager.player_items.filter(func(i): return i.can_upgrade())
	print("Total player items:", ItemManager.player_items.size())
	print("Upgradeable items:", upgradeable.size())

	for item in upgradeable:
		print("Adding row for:", item.item_name, "upgrade_level:", item.upgrade_level)
		var row = ITEM_ROW_SCENE.instantiate()
		item_list.add_child(row)
		row.setup(item)
		row.connect("row_selected", _on_row_selected)
		row.connect("hovered", _on_item_hovered)
		row.connect("hovered_off", _on_item_hovered_off)


# =========================
# SELECTION
# =========================

func _on_row_selected(item: ItemData, row: Node):
	if selected_row:
		selected_row.set_selected(false)

	selected_item = item
	selected_row = row
	selected_row.set_selected(true)

	_show_details(item)


func _show_details(item: ItemData):
	item_name_label.text = item.get_display_name()
	item_name_label.add_theme_font_override("font", font)
	item_name_label.add_theme_font_size_override("font_size", 50)
	item_name_label.add_theme_color_override("font_color", item.get_rarity_color())

	for child in pattern_preview_container.get_children():
		child.queue_free()

	var current_text = "CURRENT:\n"
	if item.is_active:
		for key in item.active_keywords:
			current_text += "  %s: %s\n" % [key, _format_keyword_value(item.active_keywords[key])]
		current_text += "  Charge: %.0f\n" % item.charge_max
	else:
		for key in item.keywords:
			current_text += "  %s: %s\n" % [key, _format_keyword_value(item.keywords[key])]

	current_stats_label.text = current_text
	current_stats_label.add_theme_font_override("font", font)
	current_stats_label.add_theme_font_size_override("font_size", 45)

	var tier = item.get_next_tier()
	var preview_text = "AFTER UPGRADE:\n"

	var effect_deltas = tier.get("effect", {})
	for key in effect_deltas:
		var delta = effect_deltas[key]
		var current_raw = item.active_keywords.get(key, item.keywords.get(key, 0))

		if delta is Dictionary or current_raw is Dictionary:
			# Color keyword — both are dicts with color + amount
			var current_amount = current_raw.get("amount", 0) if current_raw is Dictionary else int(current_raw)
			var delta_amount = delta.get("amount", 0) if delta is Dictionary else int(delta)
			preview_text += "  %s: %d → %d\n" % [key, current_amount, current_amount + delta_amount]
		else:
			preview_text += "  %s: %d → %d\n" % [key, int(current_raw), int(current_raw) + int(delta)]

	var trigger_deltas = tier.get("trigger", {})
	for key in trigger_deltas:
		if item.triggers.size() > 0 and item.triggers[0].has(key):
			var current_val = item.triggers[0][key]
			preview_text += "  Trigger %s: %s → %s\n" % [key, str(current_val), str(current_val + trigger_deltas[key])]

	var charge_delta = tier.get("charge_max_delta", 0.0)
	if charge_delta != 0.0:
		preview_text += "  Charge: %.0f → %.0f\n" % [item.charge_max, max(1.0, item.charge_max + charge_delta)]

	upgrade_preview_label.text = preview_text
	upgrade_preview_label.add_theme_font_override("font", font)
	upgrade_preview_label.add_theme_font_size_override("font_size", 45)

	confirm_button.disabled = false


func _format_keyword_value(value) -> String:
	if value is Dictionary:
		return "%s %d" % [value.get("color", ""), value.get("amount", 0)]
	return str(value)


func _clear_details():
	item_name_label.text = ""
	current_stats_label.text = "Select an item to upgrade."
	upgrade_preview_label.text = ""
	confirm_button.disabled = true


# =========================
# CONFIRM
# =========================

func _on_confirm_pressed():
	if not selected_item:
		return
	confirm_button.disabled = true
	selected_item.apply_upgrade()
	AudioLoader.play_sound("win")
	ItemManager.emit_signal("items_changed")
	
	# Clear selection and show completion message
	selected_item = null
	selected_row = null
	item_name_label.text = ""
	current_stats_label.text = "Item upgraded!"
	upgrade_preview_label.text = ""
	
	# Grey out all rows so player knows they're done
	for row in item_list.get_children():
		row.modulate = Color(0.4, 0.4, 0.4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE


# =========================
# HUD
# =========================

func populate_hud():
	for child in items_hud.get_children():
		child.queue_free()
	for child in modifiers_hud.get_children():
		child.queue_free()

	for item in ItemManager.player_items:
		if item.is_active:
			continue
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		items_hud.add_child(icon)
		icon.setup(item)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	for mod in BoardModifierEngine.active_modifiers:
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		modifiers_hud.add_child(icon)
		icon.setup(mod)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	health_text.initialize()
	health_text.change_health(RunProgressionManager.player_health)
	money_label.text = "$ %d" % RunProgressionManager.dollars
	money_label.add_theme_color_override("font_color", Color("#FFD700"))
	money_label.add_theme_font_override("font", font)


func _on_dollars_changed(_amount: int):
	money_label.text = "$ %d" % RunProgressionManager.dollars
	if selected_item:
		_show_details(selected_item)


func _on_hud_hovered(resource_data):
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hud_hovered_off(_data):
	tooltip.visible = false


# =========================
# TOOLTIPS
# =========================

func _on_item_hovered(item: ItemData):
	tooltip.visible = true
	if item.is_active:
		tooltip.display_active_item(item)
	else:
		tooltip.display_item(item)


func _on_item_hovered_off(_item):
	tooltip.visible = false


# =========================
# NAVIGATION
# =========================

func _on_leave_pressed():
	AudioLoader.play_sound("select")
	iris_wipe.iris_close(MapManager.last_panel_world_pos)
	leave_button.disabled = true
	await iris_wipe.closed
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")
