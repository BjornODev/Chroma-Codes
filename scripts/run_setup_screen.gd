extends Control

@onready var item_grid = $VBoxContainer/HSplitContainer/ItemsPanel/ItemsGrid
@onready var modifier_grid = $VBoxContainer/HSplitContainer/ModifiersPanel/ModifiersGrid
@onready var tooltip = $PanelContainer

var item_icons = []
var modifier_icons = []

var selected_items : Array[ItemData] = []
var selected_modifiers : Array[ModifierData] = []

func _ready():
	populate_items()
	populate_modifiers()


func populate_items():
	var items = ItemManager.all_items
	
	for item in items:
		var icon = preload("res://scenes/SelectableIcon.tscn").instantiate()
		item_grid.add_child(icon)
		icon.setup(item)
		icon.connect("toggled", _on_item_toggled)
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)
		item_icons.append(icon)


func populate_modifiers():
	var mods = BoardModifierEngine.all_modifiers
	
	for mod in mods:
		var icon = preload("res://scenes/SelectableIcon.tscn").instantiate()
		modifier_grid.add_child(icon)
		icon.setup(mod)
		icon.connect("toggled", _on_modifier_toggled)
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)
		modifier_icons.append(icon)

func _on_hovered(resource_data):

	tooltip.visible = true
	
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hovered_off(resource_data):
	tooltip.visible = false


func _on_StartRunButton_pressed():

	ItemManager.player_items.clear()
	BoardModifierEngine.active_modifiers.clear()

	for item in selected_items:
		ItemManager.player_items.append(item)

	for mod in selected_modifiers:
		BoardModifierEngine.active_modifiers.append(mod)
	print(selected_items)
	print(selected_modifiers)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_item_toggled(item_data : ItemData, enabled : bool):
	if enabled:
		if item_data not in selected_items:
			selected_items.append(item_data)
	else:
		selected_items.erase(item_data)


func _on_modifier_toggled(modifier_data : ModifierData, enabled : bool):
	if enabled:
		if modifier_data not in selected_modifiers:
			selected_modifiers.append(modifier_data)
	else:
		selected_modifiers.erase(modifier_data)