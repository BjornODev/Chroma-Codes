extends PanelContainer

@onready var name_label = $VBoxContainer/NameLabel
@onready var preview_container = $VBoxContainer/PatternPreviewContainer
@onready var description_label = $VBoxContainer/DescriptionLabel
@onready var effect_label = $VBoxContainer/EffectLabel


func _process(delta: float) -> void:

	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = size

	if mouse_pos.x > screen_size.x / 2:
		position = mouse_pos - Vector2(tooltip_size.x + 12, 0)
	else:
		position = mouse_pos + Vector2(12, 0)

	position.y = clamp(position.y, 0, screen_size.y - tooltip_size.y)


func _ready():
	print("Tooltip ready")


func display_item(item : ItemData):
	if item.is_active:
		display_active_item(item)
		return
	name_label.text = item.get_display_name()
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	description_label.text = item.description
	clear_preview()

	for trigger in item.triggers:
		if trigger.has("pattern"):
			var pattern_name = trigger["pattern"]
			var pattern = PatternEngine.get_pattern_by_name(pattern_name)
			if pattern:
				var preview = preload("res://scenes/PatternPreview.tscn").instantiate()
				preview_container.add_child(preview)
				preview.display_pattern(pattern)
			break

	effect_label.text = build_effect_text(item.keywords)
	update_minimum_size()


func display_modifier(modifier):
	name_label.text = modifier.modifier_name + " (Lv " + str(modifier.level) + ")"
	description_label.text = modifier.modifier_description
	effect_label.text = ""

	clear_preview()
	queue_sort()
	update_minimum_size()
	print("Tooltip size:", size)


func display_active_item(item: ItemData):
	name_label.text = item.get_display_name()
	name_label.add_theme_color_override("font_color", item.get_rarity_color())

	clear_preview()

	var charge_text = "Charge: "
	for condition in item.charge_conditions:
		charge_text += "%s x%.0f  " % [condition.get("stat", ""), condition.get("amount", 1.0)]
	charge_text += "\nMax Charge: %.0f" % item.charge_max

	description_label.text = item.description
	effect_label.text = charge_text + "\n" + build_effect_text(item.active_keywords)
	update_minimum_size()


func clear_preview():
	for child in preview_container.get_children():
		child.queue_free()
	preview_container.update_minimum_size()


func build_effect_text(effect_dict):
	if effect_dict == null or effect_dict.is_empty():
		return ""
	var text = ""
	for key in effect_dict.keys():
		var value = effect_dict[key]
		if value is Dictionary:
			text += "- %s %s %d\n" % [key, value.get("color", ""), value.get("amount", 1)]
		else:
			text += "- %s %d\n" % [key, value]
	return text