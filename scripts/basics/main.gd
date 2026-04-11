extends Node2D


@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var tooltip = $TooltipLayer/Tooltip
@onready var crt_filter = $CanvasLayer/CRTFilter



func _ready():
	print("Tooltip node:", tooltip)
	$HUDLayer/ActiveItemPanel.connect("request_tooltip_show", _on_active_tooltip_show)
	$HUDLayer/ActiveItemPanel.connect("request_tooltip_hide", _on_active_tooltip_hide)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_select"):
		get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")



func populate_hud():
	# Clear old icons first
	for child in items_hud.get_children():
		child.queue_free()
	for child in modifiers_hud.get_children():
		child.queue_free()
	
	
	# Items (top left)
	for item in ItemManager.player_items:
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		items_hud.add_child(icon)
		icon.setup(item)
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)


	# Modifiers (top right)
	for mod in BoardModifierEngine.active_modifiers:
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		modifiers_hud.add_child(icon)
		icon.setup(mod)
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)
		icon.connect("modifier_clicked", _on_modifier_clicked)


func _on_modifier_clicked(modifier_data):

	print("Clicked:", modifier_data.modifier_name)

	if BoardModifierEngine.disable_mode:
		BoardModifierEngine.disable_modifier(modifier_data)
		hide_modifier_icon(modifier_data)


func hide_modifier_icon(modifier_data):
	for child in modifiers_hud.get_children():
		if child.data == modifier_data:
			child.queue_free()
			break


func _on_hovered(resource_data):
	print("_on_hovered called:", resource_data)
	tooltip.visible = true

	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hovered_off(resource_data):
	tooltip.visible = false


func _on_active_tooltip_show(item: ItemData):
	tooltip.visible = true
	tooltip.display_active_item(item)


func _on_active_tooltip_hide():
	tooltip.visible = false
