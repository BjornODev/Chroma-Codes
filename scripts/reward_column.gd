extends PanelContainer

signal reward_selected(choice, column)
signal hovered(resource_data)
signal hovered_off(resource_data)

var reward_data

@onready var item_icon = $VBoxContainer/ItemIcon
@onready var modifier_icon = $VBoxContainer/ModifierIcon


func setup(choice):
	reward_data = choice
	
	item_icon.setup(choice.item)
	modifier_icon.setup(choice.modifier)
	
	item_icon.connect("hovered", _on_icon_hovered)
	item_icon.connect("hovered_off", _on_icon_hovered_off)
	item_icon.connect("icon_clicked", _on_icon_clicked)
	
	modifier_icon.connect("hovered", _on_icon_hovered)
	modifier_icon.connect("hovered_off", _on_icon_hovered_off)
	modifier_icon.connect("icon_clicked", _on_icon_clicked)

func set_selected(enabled):
	$VBoxContainer/ItemIcon.set_selected(enabled)
	$VBoxContainer/ModifierIcon.set_selected(enabled)


func _on_icon_hovered(data):
	emit_signal("hovered", data)


func _on_icon_clicked(_data):
	emit_signal("reward_selected", reward_data, self)


func _on_icon_hovered_off(data):
	emit_signal("hovered_off", data)