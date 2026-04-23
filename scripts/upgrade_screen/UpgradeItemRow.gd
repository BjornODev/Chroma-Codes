extends PanelContainer

signal row_selected(item, row)
signal hovered(item)
signal hovered_off(item)

var item: ItemData = null
var font: Font

@onready var icon_rect = $HBoxContainer/Icon
@onready var name_label = $HBoxContainer/VBoxContainer/NameLabel
@onready var upgrade_label = $HBoxContainer/VBoxContainer/UpgradeLabel
@onready var hover_outline = $HoverOutline


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	if hover_outline and hover_outline.material:
		hover_outline.material = hover_outline.material.duplicate()
		hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0))


func setup(p_item: ItemData):
	item = p_item

	if icon_rect and item.icon:
		icon_rect.texture = item.icon

	name_label.text = item.get_display_name()
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", item.get_rarity_color())

	var next_label = ""
	match item.upgrade_level:
		0: next_label = "Upgrade to +"
		1: next_label = "Upgrade to ++"
		2: next_label = "Upgrade to +++"

	upgrade_label.text = next_label
	upgrade_label.add_theme_font_override("font", font)
	upgrade_label.add_theme_font_size_override("font_size", 14)
	upgrade_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func set_selected(enabled: bool):
	if hover_outline and hover_outline.material:
		if enabled:
			hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 1))
		else:
			hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0))


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item:
			emit_signal("row_selected", item, self)


func _on_mouse_entered():
	if item:
		if hover_outline and hover_outline.material:
			hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0.5))
		emit_signal("hovered", item)


func _on_mouse_exited():
	if item:
		emit_signal("hovered_off", item)
