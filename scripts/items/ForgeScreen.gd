extends Control

const ITEM_ICON_SCENE = preload("res://scenes/SelectableIcon.tscn")

@onready var active_column = $HBoxContainer/ActiveSection/ActiveGrid
@onready var passive_grid = $HBoxContainer/PassiveSection/PassiveGrid
@onready var confirm_button = $ConfirmButton
@onready var confirm_label = $ConfirmButton/Label
@onready var leave_button = $LeaveButton
@onready var iris_wipe = $IrisWipe
@onready var background_layer = $BackgroundLayer
@onready var tooltip = $TooltipLayer/Tooltip
@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var money_label = $HUDLayer/HUDRoot/MoneyLabel

var smelts_this_visit := 0

var selected_item: ItemData = null
var selected_icon: Node = null
var font: Font

const RARITY_ORDER = [3, 2, 1, 0]  # Legendary first, Common last


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	iris_wipe.instant_close()
	background_layer.change_background(randi())
	_build_inventory()
	_setup_confirm_button()
	populate_hud()
	_update_leave_button()

	leave_button.pressed.connect(_on_leave_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.visible = false

	RunProgressionManager.connect("dollars_changed", _on_dollars_changed)

	await get_tree().process_frame
	iris_wipe.iris_open(MapManager.last_panel_world_pos)


# =========================
# INVENTORY BUILDING
# =========================

func _build_inventory():
	for child in active_column.get_children():
		child.queue_free()
	for child in passive_grid.get_children():
		child.queue_free()

	# Sort items by rarity descending
	var active_items = ItemManager.player_items.filter(func(i): return i.is_active)
	var passive_items = ItemManager.player_items.filter(func(i): return not i.is_active)

	active_items.sort_custom(func(a, b): return a.rarity > b.rarity)
	passive_items.sort_custom(func(a, b): return a.rarity > b.rarity)

	for item in active_items:
		_add_item_icon(item, active_column)

	for item in passive_items:
		_add_item_icon(item, passive_grid)


func _add_item_icon(item: ItemData, container: Node):
	var icon = ITEM_ICON_SCENE.instantiate()
	container.add_child(icon)
	icon.setup(item)
	icon.connect("hovered", _on_item_hovered)
	icon.connect("hovered_off", _on_item_hovered_off)
	icon.connect("toggled", _on_item_toggled)


# =========================
# SELECTION
# =========================

func _on_item_toggled(item: ItemData, is_enabled: bool):
	if not is_enabled:
		selected_item = null
		selected_icon = null
		confirm_button.visible = false
		return

	# Deselect previous
	if selected_icon and selected_icon != null:
		selected_icon.enabled = false
		selected_icon._gui_input(InputEventMouseButton.new())
		var mat = selected_icon.get_node("HoverOutline").material
		if mat:
			mat.set_shader_parameter("color", Color(1, 1, 1, 0))
		selected_icon.enabled = false

	var all_icons = active_column.get_children() + passive_grid.get_children()
	for icon in all_icons:
		if icon.data == item:
			selected_icon = icon
			break

	selected_item = item
	_update_confirm_button()


func _update_confirm_button():
	if selected_item == null:
		confirm_button.visible = false
		return

	var payout = _calculate_payout(selected_item)
	confirm_button.visible = true
	confirm_label.text = "SMELT FOR $%d" % payout
	confirm_label.add_theme_font_override("font", font)
	confirm_label.add_theme_font_size_override("font_size", 22)
	confirm_label.add_theme_color_override("font_color", Color("#FFD700"))


func _calculate_payout(item: ItemData) -> int:
	return ceili(item.price * 0.5)


func _setup_confirm_button():
	confirm_button.custom_minimum_size = Vector2(300, 60)
	# Position below the grids — anchored bottom center
	confirm_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	confirm_button.offset_top = -140
	confirm_button.offset_bottom = -80
	confirm_button.offset_left = 760
	confirm_button.offset_right = -760

	if not confirm_button.get_node_or_null("Label"):
		var label = Label.new()
		label.name = "Label"
		confirm_button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# =========================
# SMELTING
# =========================

func _on_confirm_pressed():
	if selected_item == null:
		return

	confirm_button.visible = false
	smelts_this_visit += 1

	var payout = _calculate_payout(selected_item)
	var icon_to_remove = selected_icon

	await _play_smelt_animation(icon_to_remove)

	if selected_item.is_active:
		ActiveItemManager.remove_item(selected_item)

	ItemManager.player_items.erase(selected_item)
	ItemManager.emit_signal("items_changed")
	RunProgressionManager.add_dollars(payout)
	AudioLoader.play_sound("win")

	selected_item = null
	selected_icon = null

	_build_inventory()
	_update_leave_button()


func _play_smelt_animation(icon: Node):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	# Flash rarity color then shrink and fade
	var rarity_color = icon.data.get_rarity_color() if icon.data else Color.WHITE

	tween.tween_callback(func(): icon.modulate = rarity_color)
	tween.tween_interval(0.06)
	tween.tween_callback(func(): icon.modulate = Color.WHITE)
	tween.tween_interval(0.06)
	tween.tween_callback(func(): icon.modulate = rarity_color)
	tween.tween_interval(0.06)
	tween.tween_callback(func(): icon.modulate = Color.WHITE)
	tween.tween_interval(0.06)

	tween.parallel().tween_property(icon, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(icon, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.2)

	await tween.finished
	icon.queue_free()


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
		var icon = ITEM_ICON_SCENE.instantiate()
		items_hud.add_child(icon)
		icon.setup(item)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	for mod in BoardModifierEngine.active_modifiers:
		var icon = ITEM_ICON_SCENE.instantiate()
		modifiers_hud.add_child(icon)
		icon.setup(mod)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	health_text.initialize()
	health_text.change_health(RunProgressionManager.player_health)

	money_label.text = "$ %d" % RunProgressionManager.dollars
	money_label.add_theme_color_override("font_color", Color("#FFD700"))
	money_label.add_theme_font_override("font", font)


func _on_dollars_changed(_new_amount: int):
	money_label.text = "$ %d" % RunProgressionManager.dollars


# =========================
# TOOLTIPS
# =========================

func _on_item_hovered(item):
	tooltip.visible = true
	if item is ItemData:
		if item.is_active:
			tooltip.display_active_item(item)
		else:
			tooltip.display_item(item)


func _on_item_hovered_off(_item):
	tooltip.visible = false


func _on_hud_hovered(resource_data):
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hud_hovered_off(_data):
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


func _update_leave_button():
	var has_items = not ItemManager.player_items.is_empty()
	if has_items and smelts_this_visit == 0:
		leave_button.disabled = true
		# Show hint
		var label = leave_button.get_node_or_null("Label")
		if label:
			label.text = "SMELT AN ITEM FIRST"
			label.add_theme_color_override("font_color", Color("#FF4444"))
	else:
		leave_button.disabled = false
		var label = leave_button.get_node_or_null("Label")
		if label:
			label.text = "LEAVE"
			label.add_theme_color_override("font_color", Color("#FFFFFF"))