extends CanvasLayer

signal reward_confirmed(choice)

@onready var vbox = $VBoxContainer
@onready var hbox = $VBoxContainer/HBoxContainer
@onready var bg = $ColorRect
@onready var tooltip = get_node("/root/Main/TooltipLayer/Tooltip")
@onready var confirm_button = $VBoxContainer/ConfirmButton
@onready var dollar_display = $VBoxContainer/DollarDisplay
@onready var run_summary = $VBoxContainer/RunSummary

var selected_column = null
var reward_scene = preload("res://scenes/RewardColumn.tscn")

var earned_dollar_indices: Array = []


func _ready():
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirmation_button_pressed)
	dollar_display.connect("dollar_activated", _on_dollar_activated)
	dollar_display.connect("all_dollars_animated", _on_all_dollars_animated)
	ItemManager.connect("active_item_cap_reached", _on_active_cap_reached)



func show_rewards(choices):
	await get_tree().process_frame

	build_icons(choices)
	run_summary._build_summary()

	earned_dollar_indices = _get_earned_dollar_indices()

	vbox.position.y = -vbox.size.y
	bg.position.y = -bg.size.y

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(vbox, "position:y", 320, 0.6)
	tween.parallel().tween_property(bg, "position:y", 320, 0.6)
	await tween.finished

	dollar_display.animate_earned_dollars(earned_dollar_indices)


func _get_earned_dollar_indices() -> Array:
	var indices = []
	for i in range(ChaosManager.DOLLAR_THRESHOLDS.size() - 1, -1, -1):
		if ChaosManager.dollars_active[i]:
			indices.append(i)
	return indices


func _on_dollar_activated(index: int):
	RunProgressionManager.add_dollars(1)
	ItemManager.emit_game_event("dollar_activated", {
		"index": index,
		"display": dollar_display
	})
	ItemManager.process_turn_events()


func _on_all_dollars_animated():
	if selected_column:
		confirm_button.disabled = false


func build_icons(choices):
	for child in hbox.get_children():
		child.queue_free()

	for choice in choices:
		var column = reward_scene.instantiate()
		hbox.add_child(column)
		column.setup(choice)
		column.connect("reward_selected", _on_reward_selected)
		column.connect("hovered", _on_hovered)
		column.connect("hovered_off", _on_hovered_off)


func _on_reward_selected(choice, column):
	if selected_column:
		selected_column.set_selected(false)

	selected_column = column
	selected_column.set_selected(true)

	if not dollar_display.is_animating:
		confirm_button.disabled = false


func _on_hovered(resource_data):
	if not tooltip:
		return
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)


func _on_hovered_off(_resource_data):
	if tooltip:
		tooltip.visible = false


func _on_confirmation_button_pressed():
	if not selected_column:
		return

	confirm_button.disabled = true

	var choice = selected_column.reward_data
	ItemManager.give_item_by_name(choice.item.item_name)

	emit_signal("reward_confirmed", choice)


func _on_active_cap_reached(new_item: ItemData):
	var overlay = preload("res://scenes/ActiveItemReplaceOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.show_overlay(new_item)
	overlay.connect("replacement_confirmed", _on_replacement_confirmed)
	overlay.connect("replacement_cancelled", _on_replacement_cancelled)
	overlay.connect("request_tooltip_show", _on_active_tooltip_show)
	overlay.connect("request_tooltip_hide", _on_active_tooltip_hide)


func _on_replacement_confirmed(old_item: ItemData, new_item: ItemData):
	# Remove old item first
	ItemManager.player_items.erase(old_item)
	ActiveItemManager.remove_item(old_item)
	
	# Now add new item — count is back to 4 so no overflow
	ItemManager.player_items.append(new_item)
	ActiveItemManager.add_item(new_item)
	RunProgressionManager.reward_pool_items.erase(new_item)
	
	# Only emit after everything is in correct state
	ItemManager.emit_signal("items_changed")


func _on_replacement_cancelled(_new_item: ItemData):
	pass


func _on_active_tooltip_show(item: ItemData):
	tooltip.visible = true
	tooltip.display_active_item(item)


func _on_active_tooltip_hide():
	tooltip.visible = false