extends PanelContainer

signal hovered(resource_data)
signal hovered_off(resource_data)

var data

@onready var hover_glow = $HoverGlow

func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	hover_glow.visible = false

func _on_mouse_entered():
	hover_glow.visible = true
	emit_signal("hovered", data)

func _on_mouse_exited():
	hover_glow.visible = false
	emit_signal("hovered_off", data)