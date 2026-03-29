extends ColorRect

signal panel_clicked(row, col, panel_type, global_pos)

const DESATURATE_AMOUNT := 0.85

var row: int = 0
var col: int = 0
var panel_type: String = ""
var panel_color: Color = Color.WHITE
var is_activated: bool = false
var is_locked: bool = false

@onready var color_rect = $ColorRect
@onready var icon_rect = $CenterContainer/Icon
@onready var lock_overlay = $LockOverlay

# Placeholder icon colors per type — swap with real textures later
const TYPE_ICON_COLORS := {
	"Board": Color("#000000"),
	"Shop": Color("#FFD700"),
	"Event": Color("#FF69B4"),
	"Forge": Color("#FF8C00"),
	"Gamble": Color("#00FFFF"),
}

const TYPE_SHAPES := {
	"Board": "rect",
	"Shop": "circle",
	"Event": "diamond",
	"Forge": "triangle",
	"Gamble": "star",
}


func setup(p_row: int, p_col: int, p_type: String, p_color: Color, activated: bool, locked: bool):
	row = p_row
	col = p_col
	panel_type = p_type
	panel_color = p_color
	is_activated = activated
	is_locked = locked

	_apply_visuals()


func _apply_visuals():
	if is_activated:
		color_rect.color = panel_color
		lock_overlay.visible = true
		lock_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	else:
		color_rect.color = panel_color
		lock_overlay.visible = false
	
	icon_rect.color = TYPE_ICON_COLORS.get(panel_type, Color.WHITE)
	modulate = Color.WHITE



func _desaturate(c: Color, amount: float) -> Color:
	var gray = (c.r + c.g + c.b) / 3.0
	return Color(
		lerp(c.r, gray, amount),
		lerp(c.g, gray, amount),
		lerp(c.b, gray, amount),
		c.a
	)


func activate():
	if is_activated or is_locked:
		return

	is_activated = true
	_flicker_then_desaturate()


func _flicker_then_desaturate():
	var tween = create_tween()
	var flicker_count = 6
	var flicker_time = 0.08

	for i in range(flicker_count):
		if i % 2 == 0:
			tween.tween_callback(func():
				lock_overlay.visible = true
			)
		else:
			tween.tween_callback(func():
				lock_overlay.visible = false
			)
		tween.tween_interval(flicker_time)

	tween.tween_callback(func():
		lock_overlay.visible = true
	)


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_locked:
			return
		emit_signal("panel_clicked", row, col, panel_type, global_position + size / 2.0)
