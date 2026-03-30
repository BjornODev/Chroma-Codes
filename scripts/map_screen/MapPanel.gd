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
const TYPE_ICONS := {
	"Board": preload("res://assets/ui/Board.svg"),
	"Shop": preload("res://assets/ui/Shop.svg"),
	"Event": preload("res://assets/ui/Event.svg"),
	"Forge": preload("res://assets/ui/Forge.svg"),
	"Gamble": preload("res://assets/ui/Gamble.svg"),
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
	
	icon_rect.texture = TYPE_ICONS.get(panel_type, null)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
