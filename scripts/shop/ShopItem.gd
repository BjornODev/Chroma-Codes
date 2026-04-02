extends PanelContainer

signal item_purchased(index)
signal hovered(item)
signal hovered_off

const RARITY_COLORS := {
	0: Color("#888888"),
	1: Color("#00CC44"),
	2: Color("#4488FF"),
	3: Color("#FFD700"),
}

var item: ItemData = null
var slot_index: int = 0
var font: Font

@onready var icon_rect = $MarginContainer/VBoxContainer/CenterContainer/Icon
@onready var price_label = $MarginContainer/VBoxContainer/PriceLabel
@onready var rarity_border = $RarityBorder
#@onready var sold_overlay = $SoldOverlay


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")



func setup(p_item: ItemData, p_index: int):
	item = p_item
	slot_index = p_index
#	sold_overlay.visible = false

	if item == null:
		_show_empty()
		return

	# Icon
	if item.icon:
		icon_rect.texture = item.icon

	# Price label
	price_label.text = "$ %d" % item.price
	price_label.add_theme_font_override("font", font)
	price_label.add_theme_font_size_override("font_size", 18)

	var can_afford = ShopManager.can_afford(item.price)
	price_label.add_theme_color_override(
		"font_color",
		Color("#FFD700") if can_afford else Color("#FF4444")
	)

	# Rarity border
	_apply_rarity_border(item.rarity)

	modulate = Color.WHITE


func _show_empty():
	icon_rect.texture = null
	price_label.text = ""
	if rarity_border:
		rarity_border.color = Color(0.2, 0.2, 0.2, 0.5)
	modulate = Color(0.3, 0.3, 0.3, 0.5)


func _apply_rarity_border(rarity: int):
	if rarity_border:
		rarity_border.color = RARITY_COLORS.get(rarity, Color("#888888"))


func refresh_affordability():
	if item == null:
		return
	var can_afford = ShopManager.can_afford(item.price)
	price_label.add_theme_color_override(
		"font_color",
		Color("#FFD700") if can_afford else Color("#FF4444")
	)


# =========================
# MEGAMAN DEATH ANIMATION
# =========================

func play_death_animation():
	var rarity_color = RARITY_COLORS.get(item.rarity if item else 0, Color.WHITE)
	var tween = create_tween()

	# Flash between rarity color and white rapidly
	for i in range(8):
		tween.tween_callback(func():
			modulate = rarity_color if i % 2 == 0 else Color.WHITE
		)
		tween.tween_interval(0.05)

	# Expand and fade out
	tween.tween_callback(func():
		modulate = rarity_color
	)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)

	await tween.finished

	# Reset and show empty
	scale = Vector2.ONE
	modulate = Color.WHITE
	item = null
	_show_empty()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item == null:
			return
		emit_signal("item_purchased", slot_index)


func _on_mouse_entered():
	if item:
		emit_signal("hovered", item)


func _on_mouse_exited():
	emit_signal("hovered_off")
