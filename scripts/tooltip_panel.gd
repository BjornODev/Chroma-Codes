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

	name_label.text = item.item_name
	description_label.text = item.description
	
	clear_preview()
	# Look for pattern trigger
	for trigger in item.triggers:
		if trigger.has("pattern"):
			var pattern_name = trigger["pattern"]

			var pattern = PatternEngine.get_pattern_by_name(pattern_name)
			if pattern:
				var preview = preload("res://scenes/PatternPreview.tscn").instantiate()
				preview_container.add_child(preview)
				preview.display_pattern(pattern)
			break  # Only show first pattern

	effect_label.text = build_effect_text(item.keywords)
#	queue_sort()
	update_minimum_size()
	print("Tooltip size:", size)


func display_modifier(modifier):

	name_label.text = modifier.modifier_name
	description_label.text = ""
	
	clear_preview()
	
	var trigger_text = ""
	if modifier.phase != "":
		trigger_text += "Phase: " + modifier.phase + "\n"
	
	if modifier.trigger.size() > 0:
		trigger_text += "Trigger:\n"
		for key in modifier.trigger.keys():
			trigger_text += "- %s: %d\n" % [key, modifier.trigger[key]]
	
	effect_label.text = trigger_text + build_effect_text(modifier.effect)
#	queue_sort()
	update_minimum_size()
	print("Tooltip size:", size)


func clear_preview():
	for child in preview_container.get_children():
		child.queue_free()
	preview_container.update_minimum_size()

func build_effect_text(effect_dict):
	var text = "Effects:\n"
	for key in effect_dict.keys():
		text += "- %s %d\n" % [key, effect_dict[key]]
	return text