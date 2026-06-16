extends Control
class_name RulesDisplayPanel

# =========================
# RULES DISPLAY PANEL (VERTICAL)
# Always-visible vertical list of active rules with diagrams.
# Designed to sit on the right side of the screen and stack downward.
# =========================

const PANEL_WIDTH := 300.0
const ENTRY_HEIGHT := 150.0
const ENTRY_SPACING := 12.0

var font: Font
var _entries_built := false


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_build_entries()


func _build_entries():
	for child in get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(ENTRY_SPACING))
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	add_child(vbox)

	var rules = RulesEngine.get_active_rules()
	for rule in rules:
		vbox.add_child(_make_entry(rule))

	_entries_built = true


func _make_entry(rule: Rule) -> Control:
	var entry = PanelContainer.new()
	entry.custom_minimum_size = Vector2(PANEL_WIDTH, ENTRY_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	entry.add_theme_stylebox_override("panel", style)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	entry.add_child(v)

	var name_label = Label.new()
	name_label.text = rule.get_rule_name()
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("#FFD700"))
	v.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = rule.get_description()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", font)
	desc_label.add_theme_font_size_override("font_size", 13)
	v.add_child(desc_label)

	var diagram_container = Control.new()
	diagram_container.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 55)
	v.add_child(diagram_container)
	rule.render_diagram(diagram_container)

	return entry


func refresh():
	_build_entries()