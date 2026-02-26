extends PanelContainer

signal toggled(resource_data, enabled)
signal hovered(resource_data)
signal hovered_off(resource_data)

var data
var enabled := false

@onready var overlay = $SelectionOverlay
@onready var hover_glow = $HoverGlow

func setup(resource_data):
	data = resource_data
	$Icon.texture = data.icon
	overlay.visible = false
	hover_glow.visible = false

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		enabled = !enabled
		overlay.visible = enabled
		emit_signal("toggled", data, enabled)

func _on_mouse_entered():
	hover_glow.visible = true
	emit_signal("hovered", data)

func _on_mouse_exited():
	hover_glow.visible = false
	emit_signal("hovered_off", data)