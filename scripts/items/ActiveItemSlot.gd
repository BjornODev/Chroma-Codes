extends PanelContainer

signal slot_clicked(item)

# Rarity border colors
const RARITY_COLORS := {
	0: Color("#888888"),  # Common
	1: Color("#00CC44"),  # Uncommon
	2: Color("#4488FF"),  # Rare
	3: Color("#FFD700"),  # Legendary
}

# Charge condition stat -> placeholder color (swap with real icons later)
const STAT_COLORS := {
	"damage_taken":      Color("#FF4444"),
	"health_healed":     Color("#44FF88"),
	"pegs_placed_any":   Color("#AAAAAA"),
	"pegs_placed_red":   Color("#E05555"),
	"pegs_placed_yellow":Color("#E0C055"),
	"pegs_placed_green": Color("#55A855"),
	"pegs_placed_white": Color("#DDDDDD"),
	"pegs_placed_purple":Color("#8855CC"),
	"pegs_placed_orange":Color("#E08040"),
	"rows_submitted":    Color("#4488FF"),
	"active_activated":  Color("#FFD700"),
	"replace_used":      Color("#39FF14"),
	"black_pegs":        Color("#111111"),
	"white_pegs":        Color("#EEEEEE"),
}

var item: ItemData = null
var is_empty: bool = true

@onready var bg_fill = $VBoxContainer/FillContainer/BGFill
@onready var fill_bar = $VBoxContainer/FillContainer/FillBar
@onready var icon_rect = $VBoxContainer/FillContainer/CenterContainer/Icon
@onready var charge_icons = $VBoxContainer/ChargeIcons
@onready var border_panel = $BorderPanel
@onready var ready_glow = $ReadyGlow
@onready var hover_outline = $HoverOutline


func _ready():
	set_empty()
	ActiveItemManager.connect("charge_updated", _on_charge_updated)
	ActiveItemManager.connect("active_items_changed", _refresh)
	
	if hover_outline and hover_outline.material:
		hover_outline.material = hover_outline.material.duplicate()


func setup(p_item: ItemData):
	item = p_item
	is_empty = false

	if border_panel and border_panel.material:
		border_panel.material = border_panel.material.duplicate()
		border_panel.material.set_shader_parameter("color", item.get_rarity_color())

	if icon_rect and item.icon:
		icon_rect.texture = item.icon
		icon_rect.visible = true

	_build_charge_icons()
	modulate = Color.WHITE
	
	call_deferred("_sync_fill")


func _sync_fill():
	if item == null:
		return
	_update_fill(ActiveItemManager.get_charge_fraction(item))



func set_empty():
	item = null
	is_empty = true
	modulate = Color(0.4, 0.4, 0.4, 1.0)
	if icon_rect:
		icon_rect.visible = false
	if fill_bar:
		fill_bar.size.x = 0
	if ready_glow:
		ready_glow.visible = false
	_clear_charge_icons()


func _build_charge_icons():
	_clear_charge_icons()
	if not item:
		return

		# Placeholder colored square — swap with real icon TextureRect later
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(138, 138)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = item.icon
	charge_icons.add_child(icon)


func _clear_charge_icons():
	if not charge_icons:
		return
	for child in charge_icons.get_children():
		child.queue_free()


func _update_fill(fraction: float):
	if not fill_bar:
		return

	# Use the container's width as the max, not bg_fill
	var container = fill_bar.get_parent()
	var max_width = container.size.x if container else 120.0
	var tween = create_tween()
	
	if max_width <= 0:
		# Size not ready yet — defer
		await get_tree().process_frame
		max_width = container.size.x if container else 120.0

#	fill_bar.size.x = max_width * clamp(fraction, 0.0, 1.0)
	tween.tween_property(fill_bar, "size:x", max_width * clamp(fraction, 0.0, 1.0), 0.2)
	fill_bar.position.x = 0

	if ready_glow:
		ready_glow.visible = fraction >= 1.0
		if fraction >= 1.0 and not _is_pulsing:
			_start_pulse()



var _is_pulsing := false

func _start_pulse():
	_is_pulsing = true
	var tween = create_tween().set_loops()
	tween.tween_property(ready_glow, "modulate:a", 0.2, 0.6)
	tween.tween_property(ready_glow, "modulate:a", 1.0, 0.6)


func _on_charge_updated(item_name: String, current: float, maximum: float):
	if item and item_name == item.item_name:
		_update_fill(current / max(maximum, 1.0))
		if current < maximum:
			_is_pulsing = false
			if ready_glow:
				ready_glow.visible = false


func _refresh():
	if is_empty:
		set_empty()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_empty and item:
			emit_signal("slot_clicked", item)


func set_selected(enabled: bool):
	if hover_outline and hover_outline.material:
		if enabled:
			hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 1))
		else:
			hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0))


func _on_mouse_entered():
	if hover_outline and hover_outline.material and not is_empty:
		hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 1))


func _on_mouse_exited():
	if hover_outline and hover_outline.material:
		hover_outline.material.set_shader_parameter("color", Color(1, 1, 1, 0))


func play_blink_animation(new_item: ItemData):
	var slot_size = size
	
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 1)
	top_bar.size = Vector2(slot_size.x, 0)
	top_bar.position = Vector2(0, 0)
	top_bar.z_index = 10
	add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 1)
	bottom_bar.size = Vector2(slot_size.x, 0)
	bottom_bar.position = Vector2(0, slot_size.y)
	bottom_bar.z_index = 10
	add_child(bottom_bar)

	var close_tween = create_tween().set_parallel(true)
	close_tween.set_trans(Tween.TRANS_CUBIC)
	close_tween.set_ease(Tween.EASE_IN)
	close_tween.tween_property(top_bar, "size:y", slot_size.y / 2.0, 0.3)
	close_tween.tween_property(bottom_bar, "size:y", slot_size.y / 2.0, 0.3)
	close_tween.tween_property(bottom_bar, "position:y", slot_size.y / 2.0, 0.3)
	await close_tween.finished

	if new_item:
		setup(new_item)
	AudioManager.play_sound("select")

	var open_tween = create_tween().set_parallel(true)
	open_tween.set_trans(Tween.TRANS_CUBIC)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.tween_property(top_bar, "size:y", 0.0, 0.3)
	open_tween.tween_property(bottom_bar, "size:y", 0.0, 0.3)
	open_tween.tween_property(bottom_bar, "position:y", slot_size.y, 0.3)
	await open_tween.finished

	top_bar.queue_free()
	bottom_bar.queue_free()
