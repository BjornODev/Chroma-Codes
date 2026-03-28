extends CanvasLayer

signal reward_confirmed(choice)

@onready var vbox = $VBoxContainer
@onready var hbox = $VBoxContainer/HBoxContainer
@onready var bg = $ColorRect
@onready var tooltip = get_node("/root/Main/HUDLayer/Tooltip")
@onready var confirm_button = $VBoxContainer/ConfirmButton

var selected_column = null
var reward_scene = preload("res://scenes/RewardColumn.tscn")


func _ready():
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirmation_button_pressed)


func show_rewards(choices):
	await get_tree().process_frame
	
	build_icons(choices)
	
	# Start above screen
	vbox.position.y = -vbox.size.y
	bg.position.y = -bg.size.y
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(vbox, "position:y", 320, 0.6)
	tween.parallel().tween_property(bg, "position:y", 320, 0.6)


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
	
	confirm_button.disabled = false


func _on_hovered(resource_data):
	if not tooltip:
		return
	
	tooltip.visible = true
	
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hovered_off(_resource_data):
	if tooltip:
		tooltip.visible = false


func _on_confirmation_button_pressed():
	if not selected_column:
		return
	
	var choice = selected_column.reward_data
	
	# Apply rewards immediately
	ItemManager.give_item_by_name(choice.item.item_name)
	BoardModifierEngine.activate_modifier_by_name(choice.modifier.modifier_name)
	
	emit_signal("reward_confirmed", choice)
	await get_tree().create_timer(0.6).timeout
	queue_free()