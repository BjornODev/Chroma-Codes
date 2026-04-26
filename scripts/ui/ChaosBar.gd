extends Control
#
#const SEGMENT_COUNT := 30
#const DOLLAR_THRESHOLDS := [5, 10, 15, 20, 25]
#
#const ZONE_COLORS := [
#	Color("#00FF44"),  # Zone 1: bright green
#	Color("#80FF00"),  # Zone 2: yellow-green
#	Color("#FFFF00"),  # Zone 3: yellow
#	Color("#FF8000"),  # Zone 4: orange
#	Color("#FF3000"),  # Zone 5: red-orange
#	Color("#FF0000"),  # Zone 6: deep red
#]
#
#const DOLLAR_ACTIVE_COLOR := Color("#FFD700")
#const DOLLAR_LOST_COLOR := Color(0.35, 0.35, 0.35, 1.0)
#
#
## -----------------------------------------------
## EASY TWEAK ZONE
## -----------------------------------------------
#const SEGMENT_WIDTH := 110         # Width of each chevron
#const SEGMENT_HEIGHT := 150        # Height of each chevron
#const SEGMENT_GAP := -120         # Gap between chevrons
#const SEGMENT_OFF_OPACITY := 0.65  # Opacity of inactive chevrons (0.0 - 1.0)
#const DOLLAR_FONT_SIZE := 30       # Dollar sign font size
## -----------------------------------------------
#
#var segments: Array = []
#var dollar_labels: Array = []
#var current_chaos := 0
#
#var chevron_texture: Texture2D
#var dollar_font: Font
#
#
#func _ready():
#	chevron_texture = preload("res://assets/ui/Chaos_Marker.png")
#	dollar_font = preload("res://assets/gomarice_goma_block.ttf")
##	ChaosManager.connect("chaos_changed", _on_chaos_changed)
##	ChaosManager.connect("dollar_flickered", _on_dollar_flickered)
##	ChaosManager.connect("dollars_reset", _on_dollars_reset)
#	_build_bar()
#
#
#func _on_dollars_reset():
#	for entry in dollar_labels:
#		var threshold_index = entry.index
##		if ChaosManager.dollars_active[threshold_index]:
#			entry.label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
#		else:
#			entry.label.add_theme_color_override("font_color", DOLLAR_LOST_COLOR)
#
#
#func _build_bar():
#	for child in get_children():
#		child.queue_free()
#	segments.clear()
#	dollar_labels.clear()
#
#	var segment_column = VBoxContainer.new()
#	segment_column.add_theme_constant_override("separation", SEGMENT_GAP)
#	add_child(segment_column)
#
#	for i in range(SEGMENT_COUNT - 1, -1, -1):
#		var chevron = TextureRect.new()
#		chevron.texture = chevron_texture
#		chevron.custom_minimum_size = Vector2(SEGMENT_WIDTH, SEGMENT_HEIGHT)
#		chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
#		chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
#		chevron.modulate = Color(1.0, 1.0, 1.0, SEGMENT_OFF_OPACITY)
#		segment_column.add_child(chevron)
#		segments.insert(0, chevron)
#
#	await get_tree().process_frame
#	_overlay_dollar_labels(segment_column)
#
#	await get_tree().process_frame
#	_sync_to_current_chaos()
#
#
#func _sync_to_current_chaos():
#	current_chaos = ChaosManager.chaos
#	for i in range(SEGMENT_COUNT):
#		if i < current_chaos:
#			segments[i].modulate = _get_segment_color(i)
#		else:
#			segments[i].modulate = Color(1.0, 1.0, 1.0, SEGMENT_OFF_OPACITY)
#	
#	for entry in dollar_labels:
#		var threshold_index = entry.index
#		if not ChaosManager.dollars_active[threshold_index]:
#			entry.label.add_theme_color_override("font_color", DOLLAR_LOST_COLOR)
#		else:
#			entry.label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
#
#
#func _overlay_dollar_labels(segment_column: VBoxContainer):
#	for d in range(DOLLAR_THRESHOLDS.size()):
#		var threshold = DOLLAR_THRESHOLDS[d]
#
#		# Visual child indices: column built top-to-bottom, index 0 = top = segment 29
#		var lower_seg_visual_index = SEGMENT_COUNT - threshold
#		var upper_seg_visual_index = SEGMENT_COUNT - threshold - 1
#
#		var lower_seg = segment_column.get_child(lower_seg_visual_index)
#		var upper_seg = segment_column.get_child(upper_seg_visual_index)
#
#		if not lower_seg or not upper_seg:
#			continue
#
#		var lower_y = lower_seg.position.y
#		var upper_y = upper_seg.position.y
#		var mid_y = (lower_y + upper_y + SEGMENT_HEIGHT) / 2.0
#
#		var dollar_label = Label.new()
#		dollar_label.text = "$"
#		dollar_label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
#		dollar_label.add_theme_font_override("font", dollar_font)
#		dollar_label.add_theme_font_size_override("font_size", DOLLAR_FONT_SIZE)
#		dollar_label.add_theme_color_override("font_outline_color", Color.BLACK)
#		dollar_label.add_theme_constant_override("outline_size", 15)
#		dollar_label.add_theme_color_override("font_shadow_color", Color.BLACK)
#		dollar_label.add_theme_constant_override("shadow_offset_x", 4)
#		dollar_label.add_theme_constant_override("shadow_offset_y", 4)
#		dollar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#		dollar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
#		dollar_label.size = Vector2(SEGMENT_WIDTH, DOLLAR_FONT_SIZE)
#		dollar_label.position = Vector2(0, mid_y - DOLLAR_FONT_SIZE / 2.0)
#
#		add_child(dollar_label)
#
#		dollar_labels.append({
#			"label": dollar_label,
#			"index": d
#		})
#
#
## =========================
## CHAOS CHANGES
## =========================
#
#func _on_chaos_changed(new_value: int):
#	var old_value = current_chaos
#	current_chaos = new_value
#
#	if new_value > old_value:
#		_animate_segments_on(old_value, new_value)
#	else:
#		_animate_segments_off(old_value, new_value)
#
#
#func _animate_segments_on(from: int, to: int):
#	for i in range(from, to):
#		if i >= SEGMENT_COUNT:
#			break
#		var delay = (i - from) * 0.115
#		var seg = segments[i]
#		var color = _get_segment_color(i)
#
#		var tween = create_tween()
#		tween.tween_interval(delay)
#		tween.tween_callback(func():
#			seg.modulate = color
#		)
#
#
#func _animate_segments_off(from: int, to: int):
#	for i in range(from - 1, to - 1, -1):
#		if i < 0:
#			break
#		var delay = (from - 1 - i) * 0.06
#		var seg = segments[i]
#
#		var tween = create_tween()
#		tween.tween_interval(delay)
#		tween.tween_callback(func():
#			seg.modulate = Color(1.0, 1.0, 1.0, SEGMENT_OFF_OPACITY)
#		)
#
#
#func _get_segment_color(index: int) -> Color:
#	var zone = index / 5
#	zone = clamp(zone, 0, ZONE_COLORS.size() - 1)
#	return ZONE_COLORS[zone]
#
#
## =========================
## DOLLAR FLICKERING
## =========================
#
#func _on_dollar_flickered(threshold_index: int):
#	for entry in dollar_labels:
#		if entry.index == threshold_index:
#			_flicker_dollar(entry.label)
#			break
#
#
#func _flicker_dollar(label: Label):
#	var tween = create_tween()
#	tween.set_loops(6)
#	tween.tween_callback(func():
#		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.1))
#	)
#	tween.tween_interval(0.08)
#	tween.tween_callback(func():
#		label.add_theme_color_override("font_color", DOLLAR_ACTIVE_COLOR)
#	)
#	tween.tween_interval(0.08)
#
#	await tween.finished
#	label.add_theme_color_override("font_color", DOLLAR_LOST_COLOR)
#