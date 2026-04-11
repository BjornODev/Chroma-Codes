extends ColorRect

signal panel_clicked(row, col, panel_type, global_pos)

const DESATURATE_AMOUNT := 0.85
const LOCK_ICON_PATH = "res://assets/ui/plain-padlock.png"

const RARITY_COLORS := {
	0: Color("#888888"),
	1: Color("#00CC44"),
	2: Color("#4488FF"),
	3: Color("#FFD700"),
}

const TYPE_ICONS := {
	"Board": preload("res://assets/ui/Board.svg"),
	"Shop": preload("res://assets/ui/Shop.svg"),
	"Event": preload("res://assets/ui/Event.svg"),
	"Forge": preload("res://assets/ui/Forge.svg"),
	"Gamble": preload("res://assets/ui/Gamble.svg"),
}

var row: int = 0
var col: int = 0
var panel_type: String = ""
var panel_color: Color = Color.WHITE
var is_activated: bool = false
var is_accessible: bool = true  # can the player click this panel

@onready var color_rect = $ColorRect
@onready var icon_rect = $CenterContainer/Icon
@onready var lock_overlay = $LockOverlay
@onready var lock_icon = $LockOverlay/LockIcon


func setup(p_row: int, p_col: int, p_type: String, p_color: Color, activated: bool, accessible: bool):
	row = p_row
	col = p_col
	panel_type = p_type
	panel_color = p_color
	is_activated = activated
	is_accessible = accessible

	_apply_visuals()


func _apply_visuals():
	# Panel color
	if is_activated:
		color_rect.color = panel_color
		lock_overlay.visible = true
		lock_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
		if lock_icon:
			lock_icon.visible = false
	elif not is_accessible:
		# Locked — dimmed with lock icon
		color_rect.color = panel_color
		lock_overlay.visible = true
		lock_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
		if lock_icon:
			lock_icon.visible = true
		modulate = Color.WHITE
	else:
		color_rect.color = panel_color
		lock_overlay.visible = false
		modulate = Color.WHITE

	# Type icon
	if icon_rect:
		icon_rect.texture = TYPE_ICONS.get(panel_type, null)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _desaturate(c: Color, amount: float) -> Color:
	var gray = (c.r + c.g + c.b) / 1.5
	return Color(
		lerp(c.r, gray, amount),
		lerp(c.g, gray, amount),
		lerp(c.b, gray, amount),
		c.a
	)


func activate():
	if is_activated:
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
				lock_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
				if lock_icon: lock_icon.visible = false
			)
		else:
			tween.tween_callback(func():
				lock_overlay.visible = false
			)
		tween.tween_interval(flicker_time)

	tween.tween_callback(func():
		lock_overlay.visible = true
		lock_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
		if lock_icon: lock_icon.visible = false
		modulate = Color.WHITE
	)


func unlock_animate():
	lock_overlay.visible = true
	lock_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	if lock_icon:
		lock_icon.visible = true
		lock_icon.modulate = Color(1, 1, 1, 1)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(lock_overlay, "color:a", 0.0, 0.4)
	if lock_icon:
		tween.parallel().tween_property(lock_icon, "modulate:a", 0.0, 0.4)

	await tween.finished
	lock_overlay.visible = false
	if lock_icon:
		lock_icon.visible = false



func lock_animate():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	lock_overlay.visible = true
	lock_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	lock_overlay.modulate = Color.WHITE
	if lock_icon:
		lock_icon.visible = true
		lock_icon.modulate = Color(1, 1, 1, 0)

	tween.tween_property(lock_overlay, "color:a", 0.5, 0.4)
	if lock_icon:
		tween.parallel().tween_property(lock_icon, "modulate:a", 1.0, 0.4)

	await tween.finished


func set_accessible(accessible: bool):
	is_accessible = accessible
	if not is_activated:
		_apply_visuals()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_activated or not is_accessible:
			return
		emit_signal("panel_clicked", row, col, panel_type, global_position + size / 2.0)
