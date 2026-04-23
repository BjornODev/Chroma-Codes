extends Control

const SYMBOL_HEIGHT := 120
const SCROLL_SPEED := 1200.0

const SYMBOL_COLORS := {
	"dollar":    Color("#FFD700"),
	"chaos":     Color("#00FFFF"),
	"health":    Color("#FF4444"),
	"common":    Color("#888888"),
	"uncommon":  Color("#00CC44"),
	"rare":      Color("#4488FF"),
	"legendary": Color("#FFD700"),
}

var reel_symbols: Array = []
var is_spinning: bool = false
var final_symbol: String = ""
var font: Font
var scroll_tween: Tween = null

@onready var symbol_container = $SymbolContainer
@onready var highlight_bar = $HighlightBar


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	clip_contents = true
	custom_minimum_size = Vector2(160, SYMBOL_HEIGHT * 3)

	if highlight_bar:
		highlight_bar.color = Color(1, 1, 1, 0.12)
		highlight_bar.size = Vector2(160, SYMBOL_HEIGHT)
		highlight_bar.position = Vector2(0, SYMBOL_HEIGHT)
		highlight_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(pool: Array):
	reel_symbols.clear()
	for i in range(8):
		var chunk = pool.duplicate()
		chunk.shuffle()
		reel_symbols.append_array(chunk)
	_build_symbol_nodes()


func _build_symbol_nodes():
	for child in symbol_container.get_children():
		child.queue_free()

	for i in range(reel_symbols.size()):
		var panel = _create_symbol_panel(reel_symbols[i])
		symbol_container.add_child(panel)
		# Manually position each symbol — no layout engine involved
		panel.position = Vector2(0, i * SYMBOL_HEIGHT)

	symbol_container.position.y = 0.0


func _create_symbol_panel(symbol: String) -> Control:
	var container = Control.new()
	# Explicit size — not custom_minimum_size — so nothing can override it
	container.size = Vector2(160, SYMBOL_HEIGHT)

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(160, SYMBOL_HEIGHT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	var label = Label.new()
	label.text = symbol.to_upper()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", SYMBOL_COLORS.get(symbol, Color.WHITE))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 0)
	label.size = Vector2(160, SYMBOL_HEIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	container.set_meta("symbol", symbol)
	return container


func start_spin():
	is_spinning = true
	symbol_container.position.y = 0.0
	_scroll_loop()


func _scroll_loop():
	if not is_spinning:
		return

	var total_height = float(reel_symbols.size() * SYMBOL_HEIGHT)

	if symbol_container.position.y <= -total_height:
		symbol_container.position.y = 0.0

	scroll_tween = create_tween()
	scroll_tween.tween_property(
		symbol_container,
		"position:y",
		-total_height,
		total_height / SCROLL_SPEED
	)
	scroll_tween.tween_callback(_scroll_loop)


func stop_on(symbol: String):
	final_symbol = symbol
	is_spinning = false

	if scroll_tween:
		scroll_tween.kill()
		scroll_tween = null

	# Which index is currently at the center slot?
	# Symbol i is in center when: container.y + i * H = H
	# So i = (H - container.y) / H
	var current_y = symbol_container.position.y
	var current_center := int(round((SYMBOL_HEIGHT - current_y) / float(SYMBOL_HEIGHT)))

	# Find occurrence of target symbol closest to current center
	# i >= 1 ensures position.y stays <= 0 (no top clip)
	var target_index := -1
	var best_distance := 999999
	for i in range(reel_symbols.size()):
		if reel_symbols[i] == symbol and i >= 1:
			var dist = abs(i - current_center)
			if dist < best_distance:
				best_distance = dist
				target_index = i

	if target_index == -1:
		target_index = max(current_center, 1)

	# Place target_index in center slot — always an exact multiple of SYMBOL_HEIGHT
	symbol_container.position.y = float(-(target_index - 1) * SYMBOL_HEIGHT)

	if highlight_bar:
		highlight_bar.color = Color(1, 1, 1, 0.4)
		var tween = create_tween()
		tween.tween_property(highlight_bar, "color", Color(1, 1, 1, 0.12), 0.4)


func get_result() -> String:
	return final_symbol
