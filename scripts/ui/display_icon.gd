extends PanelContainer

signal hovered(resource_data)
signal hovered_off(resource_data)
signal modifier_clicked(resource_data)

var data

@onready var hover_outline = $HoverOutline


func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	
	if hover_outline and hover_outline.material:
		hover_outline.material = hover_outline.material.duplicate()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("modifier_clicked", data)


func _on_mouse_entered():
	if hover_outline and hover_outline.material:
		hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 1))
	
	emit_signal("hovered", data)


func _on_mouse_exited():
	if hover_outline and hover_outline.material:
		hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0))
	
	emit_signal("hovered_off", data)