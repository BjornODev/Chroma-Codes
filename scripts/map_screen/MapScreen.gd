extends Control

const PANEL_SCENE = preload("res://scenes/MapPanel.tscn")
const GRID_SIZE = 6

var panels: Array = []
var pending_row: int = -1
var pending_col: int = -1
var pending_type: String = ""
var pending_global_pos: Vector2 = Vector2.ZERO

@onready var grid_container = $GridContainer
@onready var iris_wipe = $IrisWipe
@onready var caution_overlay = $CautionOverlay
@onready var unlock_label = $UnlockLabel
@onready var items_hud = $HUDLayer/HUDRoot/ItemsHUD
@onready var modifiers_hud = $HUDLayer/HUDRoot/ModifiersHUD
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var money_label = $HUDLayer/HUDRoot/MoneyLabel
@onready var tooltip = $TooltipLayer/Tooltip
@onready var background_layer = $BackgroundLayer

var font: Font


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")

	if !RunProgressionManager.run_active:
		RunProgressionManager.start_new_run()
	
	if RunProgressionManager.first_time_on_map:
		RunProgressionManager.map_offset = randi()
		RunProgressionManager.first_time_on_map = false
	
	background_layer.change_background(RunProgressionManager.map_offset)
	
	_build_grid()
	_build_color_tracker()
	_update_unlock_label()
	PopUpText.toggle_mult(false)
	populate_hud()
	
	# Connect map signals
	MapManager.connect("map_unlock_triggered", _on_map_unlock_triggered)
	ItemManager.connect("items_changed", _on_items_changed)

	if MapManager.boss_ready:
		MapManager.boss_ready = false
		RunProgressionManager.first_time_on_map = true
		iris_wipe.instant_close()
		_show_caution()
		await get_tree().create_timer(0.5).timeout
		iris_wipe.iris_open(MapManager.last_panel_world_pos)
		await iris_wipe.opened
		await get_tree().create_timer(4.5).timeout
		iris_wipe.iris_close(get_viewport().get_visible_rect().size / 2.0)
		await iris_wipe.closed
		await get_tree().create_timer(0.5).timeout
	elif MapManager.last_panel_world_pos != Vector2.ZERO:
		iris_wipe.instant_close()
		await get_tree().create_timer(0.5).timeout
		iris_wipe.iris_open(MapManager.last_panel_world_pos)



func _build_grid():
	grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	for child in grid_container.get_children():
		child.queue_free()
	panels.clear()

	for r in range(GRID_SIZE):
		var panel_row = []
		for c in range(GRID_SIZE):
			var panel = PANEL_SCENE.instantiate()
			grid_container.add_child(panel)

			var color = MapManager.get_panel_color(r, c)
			var type = MapManager.get_panel_type(r, c)
			var activated = MapManager.grid_activated[r][c]
			var accessible = MapManager.is_panel_accessible(r, c)

			panel.setup(r, c, type, color, activated, accessible)
			panel.connect("panel_clicked", _on_panel_clicked)

			panel_row.append(panel)
		panels.append(panel_row)


func _refresh_all_panels():
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			if panels[r][c].is_activated:
				continue
			var was_accessible = panels[r][c].is_accessible
			var now_accessible = MapManager.is_panel_accessible(r, c)

			if not was_accessible and now_accessible:
				# Newly unlocked — tween in
				panels[r][c].set_accessible(true)
				panels[r][c].unlock_animate()
			elif was_accessible and not now_accessible:
				# Newly locked — tween in lock
				panels[r][c].is_accessible = false
				panels[r][c].lock_animate()
			else:
				panels[r][c].set_accessible(now_accessible)

	_update_unlock_label()


func _update_unlock_label():
	if unlock_label:
		unlock_label.text = MapManager.get_unlock_condition_text()
		unlock_label.add_theme_font_override("font", font)
		unlock_label.add_theme_font_size_override("font_size", 50)
		unlock_label.add_theme_constant_override("outline_size", 20)
		unlock_label.add_theme_color_override("font_color", Color("#FFFFFF"))


func _on_panel_clicked(row: int, col: int, panel_type: String, global_pos: Vector2):
	pending_row = row
	pending_col = col
	pending_type = panel_type
	pending_global_pos = global_pos
	MapManager.last_panel_world_pos = pending_global_pos

	MapManager.activate_panel(row, col)
	panels[row][col].activate()

	await get_tree().create_timer(0.7).timeout

	_refresh_all_panels()
	_update_unlock_label()
	_build_color_tracker()

	iris_wipe.iris_close(pending_global_pos)
	await iris_wipe.closed
	await get_tree().create_timer(0.5).timeout
	_load_panel_scene(panel_type)


func _on_map_unlock_triggered():
	# Animate newly unlocked panel
	_refresh_all_panels()
	AudioLoader.play_sound("reveal")
	PopUpText.show_popup(
		"[center][b][color=#FFD700]PANEL UNLOCKED![/color][/b][/center]"
	)


func _on_items_changed():
	populate_hud()


func _load_panel_scene(panel_type: String):
	match panel_type:
		"Board":
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
		"Shop":
			get_tree().change_scene_to_file("res://scenes/ShopScreen.tscn")
		"Event":
			get_tree().change_scene_to_file("res://scenes/UpgradeScreen.tscn")
		"Forge":
			get_tree().change_scene_to_file("res://scenes/ForgeScreen.tscn")
		"Gamble":
			get_tree().change_scene_to_file("res://scenes/GambleScreen.tscn")


func _show_caution() -> void:
	caution_overlay.visible = true
	await caution_overlay.finish()
	caution_overlay.visible = false


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
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)

	for mod in BoardModifierEngine.active_modifiers:
		var icon = preload("res://scenes/DisplayIcon.tscn").instantiate()
		modifiers_hud.add_child(icon)
		icon.setup(mod)
		icon.connect("hovered", _on_hovered)
		icon.connect("hovered_off", _on_hovered_off)

	health_text.initialize()
	health_text.change_health(RunProgressionManager.player_health)

	money_label.text = "$ %d" % RunProgressionManager.dollars
	money_label.add_theme_color_override("font_color", Color("#FFD700"))
	money_label.add_theme_font_override("font", font)


func _on_hovered(resource_data):
	tooltip.visible = true
	if resource_data is ItemData:
		tooltip.display_item(resource_data)
	elif resource_data is ModifierData:
		tooltip.display_modifier(resource_data)


func _on_hovered_off(_data):
	tooltip.visible = false


# =========================
# COLOR TRACKER
# =========================

@onready var color_tracker = $ColorTracker

func _build_color_tracker():
	for child in color_tracker.get_children():
		child.queue_free()

	var peg_texture = preload("res://assets/pegs/peg_down.svg")
	var font_res = preload("res://assets/gomarice_goma_block.ttf")

	for color_name in MapManager.COLORS:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(100, 100)
		color_tracker.add_child(wrapper)

		var count = MapManager.color_activation_counts[color_name]
		var base_color = MapManager.COLOR_VALUES[color_name]

		var dot = TextureRect.new()
		dot.texture = peg_texture
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.modulate = base_color if count > 0 else Color(base_color.r, base_color.g, base_color.b, 0.2)
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(dot)

		var label = Label.new()
		label.text = str(count)
		label.add_theme_font_override("font", font_res)
		label.add_theme_font_size_override("font_size", 50)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if count > 0 else Color(0.4, 0.4, 0.4, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(label)
