extends PanelContainer

signal toggled(resource_data, enabled)
signal hovered(resource_data)
signal hovered_off(resource_data)

var data
var enabled := false

@onready var overlay = $SelectionOverlay

func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	overlay.visible = false
	$HoverOutline.material = $HoverOutline.material.duplicate()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		enabled = !enabled
		overlay.visible = enabled
		emit_signal("toggled", data, enabled)

func _on_mouse_entered():
	var mat = $HoverOutline.material
	if mat:
		mat.set_shader_parameter("color", Color(1, 1, 1, 1))
	emit_signal("hovered", data)

func _on_mouse_exited():
	var mat = $HoverOutline.material
	if mat:
		mat.set_shader_parameter("color", Color(1, 1, 1, 0))
	emit_signal("hovered_off", data)