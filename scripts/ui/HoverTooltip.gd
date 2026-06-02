extends CanvasLayer

const PEG_COLORS = {
	1: "#FF0000",
	2: "#FFF200",
	3: "#3BB143",
	4: "#FFFFFF",
	5: "#8F00FF",
	6: "#ED7117",
}

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var body_label: RichTextLabel = $Panel/VBoxContainer/BodyLabel

var current_object: Object = null
var _render_handlers := {}


func _ready():
	_render_handlers = {
		"feedback_black": _render_feedback_black,
		"feedback_white": _render_feedback_white,
		"wild_peg": _render_wild_peg,
		"goop_peg": _render_goop_peg,
		"spike": _render_spike,
		"obscure": _render_obscure,
	}
	panel.visible = false


func _process(_delta):
	if not panel.visible:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = panel.size

	if mouse_pos.x > screen_size.x / 2:
		panel.position = mouse_pos - Vector2(tooltip_size.x + 12, 0)
	else:
		panel.position = mouse_pos + Vector2(12, 0)
	panel.position.y = clamp(panel.position.y, 0, screen_size.y - tooltip_size.y)


# =========================
# PUBLIC API
# =========================

func show_for(object: Object):
	if not object.has_method("get_tooltip_content"):
		return
	current_object = object
	var content = object.get_tooltip_content()
	if content == null or not content is Dictionary:
		return
	var content_type = content.get("type", "")
	if not _render_handlers.has(content_type):
		push_warning("No tooltip handler for type: " + content_type)
		return
	_render_handlers[content_type].call(content.get("data", {}))
	panel.visible = true


func hide_tooltip():
	current_object = null
	panel.visible = false


func refresh():
	if current_object and panel.visible:
		show_for(current_object)


# =========================
# RENDER HANDLERS
# =========================

func _render_feedback_black(_data: Dictionary):
	title_label.text = "Black Peg"
	body_label.text = "One of your pegs is the [b]right color[/b] in the [b]right position[/b]."


func _render_feedback_white(_data: Dictionary):
	title_label.text = "White Peg"
	body_label.text = "One of your pegs is the [b]right color[/b] but in the [b]wrong position[/b]."


func _render_wild_peg(data: Dictionary):
	title_label.text = "Wild Peg"
	var text = "Counts as [b]any color[/b].\n"
	text += "When the row is submitted, drains 1 peg from each adjacent non-special color (8 neighbors)."

	# Drained counts is a dict: { color_id: amount }
	var drained_counts: Dictionary = data.get("drained_counts", {})
	if drained_counts.size() > 0:
		text += "\n\n"
		var parts := []
		for color_id in [1, 2, 3, 4, 5, 6]:
			if drained_counts.has(color_id) and drained_counts[color_id] > 0:
				var hex = PEG_COLORS.get(color_id, "#FFFFFF")
				parts.append("[color=%s][b]%d[/b][/color]" % [hex, drained_counts[color_id]])
		text += "  ".join(parts)

	body_label.text = text


func _render_goop_peg(_data: Dictionary):
	title_label.text = "Goop Peg"
	var text = "Submits as [b]nothing[/b] — counts as neither black nor white feedback and may even obscure the row..\n\n"
	text += "Each goop in your hand at the end of the board explodes. Every 2 goop deals [b]1 damage[/b]."
	body_label.text = text


func _render_spike(_data: Dictionary):
	title_label.text = "Spike"
	var text = "Occupies a slot. Placing a peg on a spike deals [b]1 damage[/b].\n\n"
	text += "You may submit a row with a spike in place of a peg."
	body_label.text = text


func _render_obscure(_data: Dictionary):
	title_label.text = "Obscure"
	var text = "Occupies a slot. Placing a peg on an obscured slot triggers a [b]50% chance[/b] to obscure 1 piece of feedback.\n\n"
	text += "You may submit a row with an obscured slot in place of a peg."
	body_label.text = text
