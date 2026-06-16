extends Control
class_name QuotaDisplay

# =========================
# QUOTA DISPLAY (VERTICAL, STATIC)
# Shows the peg quotas for the current map. Only colors that have a quota are
# shown, centered vertically. The quota amount is drawn centered directly on
# each peg in electric blue with a very large outline.
# This display does NOT change as the map progresses.
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const QUOTA_OUTLINE_COLOR := Color.BLACK
const QUOTA_OUTLINE_SIZE := 20              # very large outline

const ENTRY_HEIGHT := 130.0
const CPU_DISPLAY_SIZE := 125.0             # size of the cpu.svg image (fine control here)
const FONT_SIZE := 32

var font: Font
var cpu_texture: Texture2D
var _quota_colors: Array = []

# Optional external live source for settlement animation. When set, amounts are
# read from this dict (ticking values) instead of RunProgressionManager.
var _live_source: Dictionary = {}
var _use_live_source := false


func set_live_source(source: Dictionary):
	_live_source = source
	_use_live_source = true
	# Show exactly the colors present in the source (canonical order), so the
	# settlement controls which quotas appear and the slot order matches.
	var order = ["red", "yellow", "green", "white", "purple", "orange"]
	var cols := []
	for c in order:
		if source.has(c):
			cols.append(c)
	if not cols.is_empty():
		_quota_colors = cols
		custom_minimum_size = Vector2(CPU_DISPLAY_SIZE + 40, ENTRY_HEIGHT * max(1, _quota_colors.size()))
	queue_redraw()


func _amount_for(color_name: String) -> int:
	if _use_live_source:
		return _live_source.get(color_name, 0)
	return RunProgressionManager.peg_quotas.get(color_name, 0)


# The vertical center (local y) of a given slot index, using the SAME centering
# math as _draw so flyers land exactly where the image is drawn.
func _slot_center_y(i: int, count: int) -> float:
	var stack_height = ENTRY_HEIGHT * count
	# Use the node's height if laid out, otherwise the intended stack height so
	# slots don't all collapse to one point before layout.
	var node_h = size.y if size.y > 1.0 else stack_height
	var start_y = max(0.0, (node_h - stack_height) / 2.0)
	return start_y + ENTRY_HEIGHT * i + ENTRY_HEIGHT / 2.0


func get_color_screen_pos(color_name: String) -> Vector2:
	var count = _quota_colors.size()
	if count == 0:
		return get_global_transform_with_canvas() * (size / 2.0)
	var i = _quota_colors.find(color_name)
	if i < 0:
		return get_global_transform_with_canvas() * (size / 2.0)
	var cx = size.x / 2.0 if size.x > 1.0 else (CPU_DISPLAY_SIZE + 40) / 2.0
	var cy = _slot_center_y(i, count)
	return get_global_transform_with_canvas() * Vector2(cx, cy)


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	cpu_texture = preload("res://assets/ui/cpu.svg")
	_quota_colors = RunProgressionManager.get_quota_colors()
	custom_minimum_size = Vector2(CPU_DISPLAY_SIZE + 40, ENTRY_HEIGHT * max(1, _quota_colors.size()))
	queue_redraw()


# Call if quotas are set after this node is ready.
func refresh():
	_quota_colors = RunProgressionManager.get_quota_colors()
	custom_minimum_size = Vector2(CPU_DISPLAY_SIZE + 40, ENTRY_HEIGHT * max(1, _quota_colors.size()))
	queue_redraw()


func _draw():
	var count = _quota_colors.size()
	if count == 0:
		return

	var cx = size.x / 2.0

	for i in range(count):
		var color_name = _quota_colors[i]
		var amount = _amount_for(color_name)
		var center_y = _slot_center_y(i, count)
		var center = Vector2(cx, center_y)

		# cpu.svg image, tinted to the quota color
		var quota_color = PEG_COLORS.get(color_name, Color.WHITE)
		var tex_rect = Rect2(
			center - Vector2(CPU_DISPLAY_SIZE, CPU_DISPLAY_SIZE) / 2.0,
			Vector2(CPU_DISPLAY_SIZE, CPU_DISPLAY_SIZE)
		)
		draw_texture_rect(cpu_texture, tex_rect, false, quota_color)

		# Quota amount centered on the image, in the quota's color with a big outline
		var text = str(amount)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
		var text_pos = Vector2(
			center.x - text_size.x / 2.0,
			center.y + text_size.y / 2.0 - text_size.y * 0.2
		)

		# Outline first, then fill in the quota color
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, QUOTA_OUTLINE_SIZE, QUOTA_OUTLINE_COLOR)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, quota_color)
