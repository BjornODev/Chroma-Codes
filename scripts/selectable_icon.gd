extends PanelContainer

signal toggled(resource_data, enabled)
signal hovered(resource_data)
signal hovered_off(resource_data)

var data
var enabled := false


func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	$HoverOutline.material = $HoverOutline.material.duplicate()
	$HoverOutline.material.set_shader_parameter("color", Color(1, 1, 1, 0))

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		var mat = $HoverOutline.material
		enabled = !enabled
		if enabled:
			mat.set_shader_parameter("color", Color(1, 1, 1, 1))
		else:
			mat.set_shader_parameter("color", Color(1, 1, 1, 0))
		emit_signal("toggled", data, enabled)

func _on_mouse_entered():
	var mat = $HoverOutline.material
	if mat and !enabled:
		mat.set_shader_parameter("color", Color(1, 1, 1, 1))
	emit_signal("hovered", data)

func _on_mouse_exited():
	var mat = $HoverOutline.material
	if mat and !enabled:
		mat.set_shader_parameter("color", Color(1, 1, 1, 0))
	emit_signal("hovered_off", data)