extends Control

const PANEL_SCENE = preload("res://scenes/MapPanel.tscn")
const GRID_SIZE = 6
const PANEL_SIZE = 90
const PANEL_GAP = 8

var panels: Array = []
var pending_row: int = -1
var pending_col: int = -1
var pending_type: String = ""
var pending_global_pos: Vector2 = Vector2.ZERO

@onready var grid_container = $GridContainer
@onready var iris_wipe = $IrisWipe
@onready var caution_overlay = $CautionOverlay


func _ready():
	_build_grid()
	PopUpText.toggle_mult(false)
	
	if MapManager.boss_ready:
		MapManager.boss_ready = false
		_show_caution()
		iris_wipe.instant_close()
		await get_tree().create_timer(0.5).timeout
		iris_wipe.iris_open(MapManager.last_panel_world_pos)
		await iris_wipe.opened
		iris_wipe.iris_close(get_viewport().get_visible_rect().size / 2.0)
		await iris_wipe.closed
		await get_tree().create_timer(0.5).timeout
		# get_tree().change_scene_to_file("res://scenes/BossBoard.tscn")
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
			var locked = MapManager.is_panel_locked(r, c)

			panel.setup(r, c, type, color, activated, locked)
			panel.connect("panel_clicked", _on_panel_clicked)

			panel_row.append(panel)
		panels.append(panel_row)


func _on_panel_clicked(row: int, col: int, panel_type: String, global_pos: Vector2):
	pending_row = row
	pending_col = col
	pending_type = panel_type
	pending_global_pos = global_pos
	MapManager.last_panel_world_pos = pending_global_pos

	MapManager.activate_panel(row, col)
	panels[row][col].activate()

	await get_tree().create_timer(0.7).timeout

	_refresh_locked_states()

	iris_wipe.iris_close(pending_global_pos)
	await iris_wipe.closed
#	await get_tree().create_timer(0.5).timeout
	_load_panel_scene(panel_type)



func _refresh_locked_states():
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var locked = MapManager.is_panel_locked(r, c)
			panels[r][c].is_locked = locked
			panels[r][c]._apply_visuals()


func _load_panel_scene(panel_type: String):
	match panel_type:
		"Board":
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
		"Shop":
			get_tree().change_scene_to_file("res://scenes/ShopScreen.tscn")
		"Event":
			get_tree().change_scene_to_file("res://scenes/EventScreen.tscn")
		"Forge":
			get_tree().change_scene_to_file("res://scenes/ForgeScreen.tscn")
		"Gamble":
			get_tree().change_scene_to_file("res://scenes/GambleScreen.tscn")


func _show_caution() -> void:
	caution_overlay.visible = true
	await caution_overlay.finish()
	caution_overlay.visible = false


func return_to_map(from_panel_pos: Vector2):
	iris_wipe.iris_open(from_panel_pos)


func iris_open_center():
	iris_wipe.iris_open(get_viewport().get_visible_rect().size / 2.0)
