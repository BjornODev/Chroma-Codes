# =========================
# ADD TO KeywordEngine.gd — inside apply_keyword match block
# =========================

#		"Unlock Any":
#			popup_reference.show_popup(
#				"[center][b][color=#FFD700]UNLOCK ANY PANEL[/color][/b][/center]"
#			)
#			MapManager.activate_unlock_any()
#
#		"Charge Active":
#			popup_reference.show_popup(
#				"[center][b][color=#FFD700]CHARGE ACTIVE +%d[/color][/b][/center]" % final_value
#			)
#			for item in ItemManager.player_items:
#				if item.is_active:
#					ActiveItemManager.add_charge_direct(item, float(final_value))


# =========================
# ADD TO ActiveItemManager.gd
# =========================
# A direct charge method that bypasses stat conditions:
#
# func add_charge_direct(item: ItemData, amount: float):
#	if not charge_state.has(item.item_name):
#		charge_state[item.item_name] = 0.0
#	charge_state[item.item_name] = min(
#		charge_state[item.item_name] + amount,
#		item.charge_max
#	)
#	emit_signal("charge_updated",
#		item.item_name,
#		charge_state[item.item_name],
#		item.charge_max
#	)


# =========================
# UPDATE ItemManager.process_item_event
# =========================
# Add color count condition check for map panel triggers:
#
# func process_item_event(item, event_name, payload):
#	for trigger in item.triggers:
#		if trigger.event != event_name:
#			continue
#
#		if trigger.has("pattern"):
#			if payload.get("pattern_name") != trigger.pattern:
#				continue
#
#		if trigger.has("index"):
#			if payload.get("index") != trigger.index:
#				continue
#
#		# NEW: panel color count condition
#		# trigger format: {"event": "panel_activated", "color": "red", "count": 2}
#		if trigger.has("color") and trigger.has("count"):
#			var color_counts = payload.get("color_counts", {})
#			var required_color = trigger["color"]
#			var required_count = trigger["count"]
#			var current = color_counts.get(required_color, 0)
#			# Use threshold crossing — fires every N activations
#			var prev = _get_prev_color_count(item.item_name, required_color)
#			var prev_multiple = int(prev / required_count)
#			var curr_multiple = int(current / required_count)
#			if curr_multiple <= prev_multiple:
#				continue
#			_set_prev_color_count(item.item_name, required_color, current)
#
#		# NEW: panel type condition
#		if trigger.has("panel_type"):
#			if payload.get("panel_type", "") != trigger["panel_type"]:
#				continue
#
#		apply_item_effects(item, payload)
#
# You'll need to add a tracking dictionary to ItemManager for prev color counts:
# var _prev_panel_color_counts := {}
#
# func _get_prev_color_count(item_name: String, color: String) -> int:
#	return _prev_panel_color_counts.get(item_name + "_" + color, 0)
#
# func _set_prev_color_count(item_name: String, color: String, value: int):
#	_prev_panel_color_counts[item_name + "_" + color] = value


# =========================
# MAP SCREEN SCENE ADDITIONS
# =========================
# Add a Label node named "UnlockLabel" to MapScreen.tscn
# Position it above the grid or below the color tracker
# It displays the current unlock condition and progress
# e.g. "Unlock: 1/2 Red + 0/1 Green"
#
# Also add the lock icon asset to your project:
# res://assets/ui/plain-padlock.png
# This is used by MapPanel for locked panel overlay
#
# MapPanel scene needs a new child:
# LockOverlay (ColorRect, full rect, dark overlay)
# └── LockIcon (TextureRect, centered, 32x32, plain-padlock.png)
