extends Control

@onready var reel_left = $HBoxContainer/ReelSection/Reels/ReelLeft
@onready var reel_center = $HBoxContainer/ReelSection/Reels/ReelCenter
@onready var reel_right = $HBoxContainer/ReelSection/Reels/ReelRight
@onready var spin_button = $HBoxContainer/ReelSection/SpinButton
@onready var spin_label = $HBoxContainer/ReelSection/SpinButton/Label
@onready var result_label = $HBoxContainer/ReelSection/ResultLabel
@onready var leave_button = $LeaveButton
@onready var iris_wipe = $IrisWipe
@onready var background_layer = $BackgroundLayer
@onready var tooltip = $TooltipLayer/Tooltip
@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var money_label = $HUDLayer/HUDRoot/MoneyLabel

var font: Font
var spin_cost := 1
var is_spinning := false

const REEL_SYMBOLS := [
	"dollar", "dollar", "dollar", "dollar",
	"refill", "refill", "refill", "refill",
	"health", "health", "health",
	"common", "common", "common",
	"uncommon", "uncommon",
	"rare", "rare",
	"legendary", "legendary"
]

const PRIORITY := {
	"dollar": 0,
	"refill": 1,
	"health": 2,
	"common": 3,
	"uncommon": 4,
	"rare": 5,
	"legendary": 6
}


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	iris_wipe.instant_close()
	background_layer.change_background(randi())
	populate_hud()
	_update_spin_button()
	_style_result_label()

	reel_left.setup(REEL_SYMBOLS)
	reel_center.setup(REEL_SYMBOLS)
	reel_right.setup(REEL_SYMBOLS)

	spin_button.pressed.connect(_on_spin_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	RunProgressionManager.connect("dollars_changed", _on_dollars_changed)

	await get_tree().process_frame
	iris_wipe.iris_open(MapManager.last_panel_world_pos)


# =========================
# SPIN
# =========================

func _on_spin_pressed():
	if is_spinning:
		return
	if not RunProgressionManager.spend_dollars(spin_cost):
		AudioManager.play_sound("damage")
		return

	is_spinning = true
	spin_button.disabled = true
	result_label.text = ""
	result_label.modulate = Color.WHITE
	spin_cost += 1
	_update_spin_button()

	var results = _roll_reels()
	await _animate_reels(results)

	var outcome = _evaluate_results(results)
	await _apply_outcome(outcome)

	is_spinning = false
	_update_spin_button()


func _roll_reels() -> Array:
	var results = []
	for i in range(3):
		var pool = REEL_SYMBOLS.duplicate()
		pool.shuffle()
		results.append(pool[0])
	return results


func _animate_reels(results: Array):
	# Staggered start — all spin concurrently
	reel_left.start_spin()
	await get_tree().create_timer(0.15).timeout
	reel_center.start_spin()
	await get_tree().create_timer(0.15).timeout
	reel_right.start_spin()

	# All three spin together for ~2 seconds
	await get_tree().create_timer(2.0).timeout

	# Stop left to right
	reel_left.stop_on(results[0])
	await get_tree().create_timer(0.5).timeout
	reel_center.stop_on(results[1])
	await get_tree().create_timer(0.5).timeout
	reel_right.stop_on(results[2])
	await get_tree().create_timer(0.4).timeout


# =========================
# EVALUATION
# =========================

func _evaluate_results(results: Array) -> Dictionary:
	print("Results:", results)
	var counts := {}
	for symbol in results:
		counts[symbol] = counts.get(symbol, 0) + 1
	print("Counts:", counts)
	
	var best_symbol := ""
	var best_priority := -1

	for symbol in counts.keys():
		var count = counts[symbol]
		var base_priority = PRIORITY.get(symbol, 0)

		# Item rarities require minimum counts
		if symbol == "legendary" and count < 3:
			continue
		if symbol == "rare" and count < 2:
			continue
		if symbol == "uncommon" and count < 2:
			continue
		if symbol == "common" and count < 1:
			continue

		var effective_priority = base_priority
		if count >= 2:
			effective_priority = base_priority + 10
		if count >= 3:
			effective_priority = base_priority + 20

		if effective_priority > best_priority:
			best_priority = effective_priority
			best_symbol = symbol

	# Fallback — if nothing qualified (e.g. no doubles for rare/legendary)
	# find best non-item symbol
	if best_symbol == "":
		for symbol in ["health", "refill", "dollar"]:
			if counts.has(symbol):
				var p = PRIORITY.get(symbol, 0)
				if p > best_priority:
					best_priority = p
					best_symbol = symbol

	return {
		"symbol": best_symbol,
		"count": counts.get(best_symbol, 1),
		"all_results": results
	}


func _apply_outcome(outcome: Dictionary):
	var symbol = outcome.symbol
	var count = outcome.count
	var multiplier = count
	var result_text := ""

	match symbol:
		"dollar":
			var amount = 2 * multiplier
			RunProgressionManager.add_dollars(amount)
			result_text = "+$%d!" % amount
			AudioManager.play_sound("select")

		"refill":
			var amount = 2 * multiplier
			PegInventoryManager.add_pegs_to_all(amount)
			result_text = "+%d PEGS!" % amount
			AudioManager.play_sound("select")

		"health":
			var amount = 1 * multiplier
			RunProgressionManager.add_health(amount)
			result_text = "+%d HEALTH!" % amount
			AudioManager.play_sound("select")

		"common", "uncommon", "rare", "legendary":
			var rarity_map := {
				"common": 0,
				"uncommon": 1,
				"rare": 2,
				"legendary": 3
			}
			var rarity = rarity_map[symbol]
			var item = _get_random_gamble_item(rarity)
			if item:
				ItemManager.give_item_by_name(item.item_name)
				var rarity_names = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY"]
				result_text = "[%s]\n%s!" % [rarity_names[rarity], item.item_name]
				AudioManager.play_sound("win")
			else:
				var amount = (rarity + 1) * 2 * multiplier
				RunProgressionManager.add_dollars(amount)
				result_text = "ALL %s ITEMS OWNED\n+$%d!" % [symbol.to_upper(), amount]

	_show_result(result_text)
	await get_tree().create_timer(1.5).timeout


func _get_random_gamble_item(rarity: int) -> ItemData:
	var pool = ItemManager.all_items.filter(
		func(i): return i.rarity == rarity
	)
	pool = pool.filter(
		func(i): return not ItemManager.player_items.any(
			func(p): return p.item_name == i.item_name
		)
	)
	if pool.is_empty():
		return null
	pool.shuffle()
	return pool[0]



func _show_result(text: String):
	result_label.text = text
	result_label.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(result_label, "modulate:a", 0.0, 0.3)


# =========================
# UI
# =========================

func _update_spin_button():
	spin_label.text = "SPIN  $%d" % spin_cost
	spin_label.add_theme_font_override("font", font)
	spin_label.add_theme_font_size_override("font_size", 50)
	var can_afford = RunProgressionManager.can_afford(spin_cost)
	spin_label.add_theme_color_override(
		"font_color",
		Color("#FFD700") if can_afford else Color("#FF4444")
	)
	spin_button.disabled = not can_afford or is_spinning


func _style_result_label():
	result_label.add_theme_font_override("font", font)
	result_label.add_theme_font_size_override("font_size", 60)
	result_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD


func _on_dollars_changed(_amount: int):
	money_label.text = "$ %d" % RunProgressionManager.dollars
	if not is_spinning:
		_update_spin_button()


# =========================
# HUD
# =========================

func populate_hud():
	for child in items_hud.get_children():
		child.queue_free()
	for child in modifiers_hud.get_children():
		child.queue_free()

	for item in ItemManager.player_items:
		if item.is_active:
			continue
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		items_hud.add_child(icon)
		icon.setup(item)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	for mod in BoardModifierEngine.active_modifiers:
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		modifiers_hud.add_child(icon)
		icon.setup(mod)
		icon.connect("hovered", _on_hud_hovered)
		icon.connect("hovered_off", _on_hud_hovered_off)

	health_text.initialize()
	health_text.change_health(RunProgressionManager.player_health)
	money_label.text = "$ %d" % RunProgressionManager.dollars
	money_label.add_theme_color_override("font_color", Color("#FFD700"))
	money_label.add_theme_font_override("font", font)


func _on_hud_hovered(resource_data):
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hud_hovered_off(_data):
	tooltip.visible = false


# =========================
# NAVIGATION
# =========================

func _on_leave_pressed():
	AudioManager.play_sound("select")
	iris_wipe.iris_close(MapManager.last_panel_world_pos)
	leave_button.disabled = true
	await iris_wipe.closed
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")
