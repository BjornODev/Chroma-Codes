extends Control

const SHOP_ITEM_SCENE = preload("res://scenes/ShopItem.tscn")
const SHOP_BUFF_SCENE = preload("res://scenes/ShopBuffButton.tscn")


@onready var item_grid = $HBoxContainer/ItemSection/GridContainer
@onready var buff_section = $HBoxContainer/BuffSection
@onready var health_button = $HBoxContainer/BuffSection/HealthButton
@onready var refill_button = $HBoxContainer/BuffSection/ChaosButton
@onready var reroll_button = $HBoxContainer/ItemSection/RerollButton
@onready var leave_button = $LeaveButton
@onready var reroll_label = $HBoxContainer/ItemSection/RerollButton/Label
@onready var iris_wipe = $IrisWipe
@onready var background_layer = $BackgroundLayer
@onready var tooltip = $TooltipLayer/Tooltip
@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var money_label = $HUDLayer/HUDRoot/MoneyLabel

var item_slots: Array = []
var font: Font


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")

	$HUDLayer/ActiveItemPanel.connect("request_tooltip_show", _on_active_tooltip_show)
	$HUDLayer/ActiveItemPanel.connect("request_tooltip_hide", _on_active_tooltip_hide)
	$HUDLayer/ActiveItemPanel.can_click = false

	if not ShopManager.is_initialized:
		ShopManager.refresh_shop(MapManager.run_seed + 700000)

	iris_wipe.instant_close()
	background_layer.change_background(randi())
	_build_shop()
	_build_buffs()
	_update_reroll_button()
	_setup_layout()
	populate_hud()

	leave_button.pressed.connect(_on_leave_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)

	RunProgressionManager.connect("dollars_changed", _on_dollars_changed)
	ItemManager.connect("active_item_cap_reached", _on_active_cap_reached)

	await get_tree().process_frame
	iris_wipe.iris_open(MapManager.last_panel_world_pos)


# =========================
# LAYOUT
# =========================

func _setup_layout():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var hbox = $HBoxContainer
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 80)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	buff_section.custom_minimum_size = Vector2(200, 0)
	buff_section.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_section.add_theme_constant_override("separation", 32)

	item_grid.columns = 3
	item_grid.add_theme_constant_override("h_separation", 40)
	item_grid.add_theme_constant_override("v_separation", 40)

	var item_section = $HBoxContainer/ItemSection
	item_section.alignment = BoxContainer.ALIGNMENT_CENTER
	item_section.add_theme_constant_override("separation", 32)

	reroll_button.custom_minimum_size = Vector2(320, 70)

	leave_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	leave_button.offset_top = -250
	leave_button.offset_bottom = -196
	leave_button.offset_left = 760
	leave_button.offset_right = -760
	leave_button.custom_minimum_size = Vector2(320, 70)

	_style_reroll_button()


func _style_reroll_button():
	reroll_label.add_theme_font_override("font", font)
	reroll_label.add_theme_font_size_override("font_size", 24)


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
	money_label.add_theme_font_size_override("font_size", 115)


func _on_hud_hovered(resource_data):
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hud_hovered_off(_data = null):
	tooltip.visible = false


# =========================
# SHOP BUILDING
# =========================

func _build_shop():
	for child in item_grid.get_children():
		child.queue_free()
	item_slots.clear()

	for i in range(ShopManager.SHOP_SIZE):
		var slot = SHOP_ITEM_SCENE.instantiate()
		item_grid.add_child(slot)
		item_slots.append(slot)

		var item = ShopManager.shop_items[i] if i < ShopManager.shop_items.size() else null
		slot.setup(item, i)
		slot.connect("item_purchased", _on_item_purchased)
		slot.connect("hovered", _on_item_hovered)
		slot.connect("hovered_off", _on_item_hovered_off)


func _build_buffs():
	health_button.setup(ShopBuffButton.BuffType.HEALTH)
	refill_button.setup(ShopBuffButton.BuffType.REFILL)
	health_button.connect("buff_purchased", _on_buff_purchased)
	refill_button.connect("buff_purchased", _on_buff_purchased)
	health_button.connect("hovered", _on_buff_hovered)
	refill_button.connect("hovered", _on_buff_hovered)
	health_button.connect("hovered_off", _on_buff_hovered_off)
	refill_button.connect("hovered_off", _on_buff_hovered_off)


func _update_reroll_button():
	var cost = ShopManager.reroll_cost
	var can_afford = ShopManager.can_afford(cost)

	reroll_label.text = "REROLL  $ %d" % cost
	reroll_label.add_theme_color_override(
		"font_color",
		Color("#FFD700") if can_afford else Color("#FF4444")
	)
	reroll_button.disabled = not can_afford


# =========================
# PURCHASES
# =========================

func _on_item_purchased(index: int):
	var item = ShopManager.shop_items[index]
	if item == null:
		return
	if not ShopManager.can_afford(item.price):
		AudioLoader.play_sound("damage")
		return
	if ShopManager.buy_item(index):
		AudioLoader.play_sound("win")
		await item_slots[index].play_death_animation()
		_refresh_affordability()
	else:
		AudioLoader.play_sound("damage")
	populate_hud()


func _on_buff_purchased(buff_type: int):
	var success := false
	if buff_type == ShopBuffButton.BuffType.HEALTH:
		success = ShopManager.buy_health()
	else:
		success = ShopManager.buy_peg_refill()

	if success:
		AudioLoader.play_sound("select")
		health_button.refresh()
		refill_button.refresh()
		_refresh_affordability()
	else:
		AudioLoader.play_sound("damage")


func _on_reroll_pressed():
	if ShopManager.reroll():
		AudioLoader.play_sound("select")
		_build_shop()
		_update_reroll_button()
	else:
		AudioLoader.play_sound("damage")


func _refresh_affordability():
	for slot in item_slots:
		slot.refresh_affordability()
	health_button.refresh()
	refill_button.refresh()
	_update_reroll_button()


func _on_dollars_changed(_new_amount: int):
	_refresh_affordability()
	money_label.text = "$ %d" % RunProgressionManager.dollars


# =========================
# TOOLTIPS
# =========================

func _on_item_hovered(item: ItemData):
	tooltip.visible = true
	if item.is_active:
		tooltip.display_active_item(item)
	else:
		tooltip.display_item(item)


func _on_item_hovered_off():
	tooltip.visible = false


func _on_buff_hovered(buff_type: int):
	tooltip.visible = true
	tooltip.clear_preview()
	if buff_type == ShopBuffButton.BuffType.HEALTH:
		tooltip.name_label.text = "Health Up"
		tooltip.name_label.add_theme_color_override("font_color", Color("#DE0A26"))
		tooltip.description_label.text = "+%d Health\n$%d each\n%d remaining this map" % [
			ShopManager.HEALTH_PER_PURCHASE,
			ShopManager.HEALTH_PRICE,
			ShopManager.health_remaining()
		]
	else:
		tooltip.name_label.text = "Peg Refill"
		tooltip.name_label.add_theme_color_override("font_color", Color("#AF69EE"))
		tooltip.description_label.text = "+%d Pegs (all colors)\n$%d each\n%d remaining this map" % [
			ShopManager.PEG_REFILL_AMOUNT,
			ShopManager.REFILL_PRICE,
			ShopManager.refill_remaining()
		]
	tooltip.effect_label.text = ""
	tooltip.update_minimum_size()


func _on_buff_hovered_off():
	tooltip.visible = false


# =========================
# NAVIGATION
# =========================

func _on_leave_pressed():
	AudioLoader.play_sound("select")
	iris_wipe.iris_close(MapManager.last_panel_world_pos)
	await iris_wipe.closed
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")


func _on_active_cap_reached(new_item: ItemData):
	var overlay = preload("res://scenes/ActiveItemReplaceOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_overlay(new_item)
	overlay.connect("replacement_confirmed", _on_replacement_confirmed)
	overlay.connect("replacement_cancelled", _on_replacement_cancelled)
	overlay.connect("request_tooltip_show", _on_active_tooltip_show)
	overlay.connect("request_tooltip_hide", _on_active_tooltip_hide)


func _on_replacement_confirmed(old_item: ItemData, new_item: ItemData):
	ItemManager.player_items.erase(old_item)
	ActiveItemManager.remove_item(old_item)

	ItemManager.player_items.append(new_item)
	ActiveItemManager.add_item(new_item)
	RunProgressionManager.reward_pool_items.erase(new_item)

	ItemManager.emit_signal("items_changed")

	_refresh_affordability()


func _on_replacement_cancelled(_new_item: ItemData):
	_refresh_affordability()


func _on_active_tooltip_show(item: ItemData):
	tooltip.visible = true
	tooltip.display_active_item(item)


func _on_active_tooltip_hide():
	tooltip.visible = false