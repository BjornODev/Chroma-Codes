class_name ShopBuffButton
extends PanelContainer

signal buff_purchased(buff_type)
signal hovered(buff_type)
signal hovered_off

enum BuffType { HEALTH, REFILL }

var buff_type: int = BuffType.HEALTH
var font: Font

@onready var icon_rect = $VBoxContainer/CenterContainer/Icon
@onready var price_label = $VBoxContainer/PriceLabel
@onready var remaining_label = $VBoxContainer/RemainingLabel


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")


func setup(p_buff_type: int):
	buff_type = p_buff_type
	refresh()


func refresh():
	var price = ShopManager.HEALTH_PRICE if buff_type == BuffType.HEALTH else ShopManager.REFILL_PRICE
	var remaining = ShopManager.health_remaining() if buff_type == BuffType.HEALTH else ShopManager.refill_remaining()
	var can_afford = ShopManager.can_afford(price)
	var sold_out = remaining <= 0

	# Price
	price_label.text = "$ %d" % price
	price_label.add_theme_font_override("font", font)
	price_label.add_theme_font_size_override("font_size", 16)

	if sold_out:
		price_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	elif can_afford:
		price_label.add_theme_color_override("font_color", Color("#FFD700"))
	else:
		price_label.add_theme_color_override("font_color", Color("#FF4444"))

	# Remaining
	remaining_label.text = "%d left" % remaining
	remaining_label.add_theme_font_override("font", font)
	remaining_label.add_theme_font_size_override("font_size", 12)
	remaining_label.add_theme_color_override(
		"font_color",
		Color(0.4, 0.4, 0.4) if sold_out else Color(0.8, 0.8, 0.8)
	)

	# Dim if unavailable
	modulate = Color(0.4, 0.4, 0.4, 1.0) if sold_out else Color.WHITE

	# Icon color
	if icon_rect:
		icon_rect.color = Color("#FF4444") if buff_type == BuffType.HEALTH else Color("#00FF88")


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not modulate == Color(0.4, 0.4, 0.4, 1.0):
			emit_signal("buff_purchased", buff_type)


func _on_mouse_entered():
	emit_signal("hovered", buff_type)


func _on_mouse_exited():
	emit_signal("hovered_off")
