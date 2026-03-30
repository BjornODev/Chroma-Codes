extends PanelContainer

signal hovered(resource_data)
signal hovered_off(resource_data)
signal icon_clicked(resource_data)

var data
var selected := false

@onready var hover_outline = $HoverOutline


func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	
	if hover_outline and hover_outline.material:
		hover_outline.material = hover_outline.material.duplicate()
	
	set_outline(false)


func set_selected(enabled):
	selected = enabled
	set_outline(enabled)


func set_outline(enabled):
	if hover_outline and hover_outline.material:
		if enabled:
			hover_outline.material.set_shader_parameter("color", Color(1,1,1,1))
		else:
			hover_outline.material.set_shader_parameter("color", Color(1,1,1,0))


func _on_mouse_entered():
	if not selected:
		set_outline(true)
	
	emit_signal("hovered", data)


func _on_mouse_exited():
	if not selected:
		set_outline(false)
	
	emit_signal("hovered_off", data)


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("icon_clicked", data)