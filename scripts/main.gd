extends Node2D


@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var tooltip = $HUDLayer/PanelContainer

func _ready():
	populate_hud()

func populate_hud():

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


func _on_hovered(resource_data):
	tooltip.visible = true

	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hovered_off(resource_data):
	tooltip.visible = false