# =========================
# INTEGRATION NOTES
# =========================


# =========================
# 1. AUTOLOADS TO ADD
# =========================
# Add ActiveItemManager.gd as autoload named "ActiveItemManager"


# =========================
# 2. ADD TO ItemManager.gd
# =========================

# Add this signal at the top:
# signal items_changed

# Update give_item_by_name to notify active manager and emit signal:
# func give_item_by_name(name: String):
#     if not items_by_name.has(name):
#         return
#     var item = items_by_name[name]
#     player_items.append(item)
#     if item.is_active:
#         ActiveItemManager.add_item(item)
#     emit_signal("items_changed")


# =========================
# 3. HOOK INTO BoardManager.gd
# =========================

# In apply_damage(), after RunProgressionManager.record_damage_taken(damage):
#     ActiveItemManager.on_damage_taken(damage)

# In apply_heal():
#     ActiveItemManager.on_health_healed(amount)

# In submit_guess(), after RunProgressionManager.record_row_submitted(guess):
	#ActiveItemManager.on_row_submitted()
	#for peg_id in guess:
		#ActiveItemManager.on_peg_placed(peg_id)
#     # After showing feedback:
	#ActiveItemManager.on_feedback_received(result[0], result[1])

# In _ready() and start_next_board(), add:
#     ActiveItemManager.set_context(self, peg_manager_reference, popup_manager)


# =========================
# 4. HOOK INTO KeywordEngine.gd
# =========================

# In apply_keyword, inside the "Replace" case, add:
#     ActiveItemManager.on_replace_used()


# =========================
# 5. TOOLTIP ADDITION
# =========================
# Add this function to your Tooltip.gd script:

# func display_active_item(item: ItemData):
	#name_label.text = item.item_name + " [" + item.get_rarity_name() + "]"
	#name_label.add_theme_color_override("font_color", item.get_rarity_color())
#
	#clear_preview()
#
	# Show charge conditions
	#var charge_text = "Charge: "
	#for condition in item.charge_conditions:
		#charge_text += "%s x%.0f  " % [condition.get("stat", ""), condition.get("amount", 1.0)]
	#charge_text += "\nMax Charge: %.0f" % item.charge_max
#
	#description_label.text = item.description
	#effect_label.text = charge_text + "\n" + build_effect_text(item.active_keywords)
	#update_minimum_size()


# =========================
# 6. RARITY WEIGHTING IN RunProgressionManager
# =========================

# Update get_reward_choices() to weight by rarity:
#
# func get_reward_choices() -> Array:
#     var choices := []
#     var weighted_items = _get_weighted_pool(reward_pool_items)
#     weighted_items.shuffle()
#     reward_pool_modifiers.shuffle()
#
#     for i in range(3):
#         if weighted_items.is_empty() or reward_pool_modifiers.is_empty():
#             break
#         choices.append({
#             "item": weighted_items.pop_front(),
#             "modifier": reward_pool_modifiers.pop_front()
#         })
#     return choices
#
# func _get_weighted_pool(pool: Array) -> Array:
#     var weighted := []
#     for item in pool:
#         var weight = _rarity_weight(item.rarity)
#         for i in range(weight):
#             weighted.append(item)
#     weighted.shuffle()
#     return weighted
#
# func _rarity_weight(rarity: int) -> int:
#     match rarity:
#         0: return 8   # Common
#         1: return 4   # Uncommon
#         2: return 2   # Rare
#         3: return 1   # Legendary
#     return 8


# =========================
# 7. RESET ON NEW RUN
# =========================
# In RunProgressionManager.start_new_run():
#     ActiveItemManager.reset_on_new_run()


# =========================
# 8. ACTIVEITEMPANEL SCENE STRUCTURE
# =========================
# PanelContainer (ActiveItemPanel.gd)
# └── VBoxContainer
#     ├── Label "Active Items" (title)
#     └── VBoxContainer "SlotContainer" (separation 4)


# =========================
# 9. ACTIVEITEMSLOT SCENE STRUCTURE
# =========================
# PanelContainer (ActiveItemSlot.gd, custom_minimum_size 120x80)
# ├── BorderPanel (ColorRect, full rect, outline shader for rarity border)
# ├── ReadyGlow (ColorRect, full rect, golden color, hidden by default)
# └── VBoxContainer
#     ├── FillContainer (Control, custom_minimum_size 120x50)
#     │   ├── BGFill (ColorRect, full rect, dark grey)
#     │   ├── FillBar (ColorRect, anchored left, lighter grey, fills left to right)
#     │   └── Icon (TextureRect, centered, 32x32)
#     └── HBoxContainer "ChargeIcons" (separation 2, small icons row)


# =========================
# 10. ADDING PANEL TO A SCENE
# =========================
# Just instance ActiveItemPanel.tscn as a child of your scene
# Position it on the left side
# It handles everything else automatically via autoloads
# =========================
# INTEGRATION NOTES
# =========================


# =========================
# 1. AUTOLOADS TO ADD
# =========================
# Add ActiveItemManager.gd as autoload named "ActiveItemManager"


# =========================
# 2. ADD TO ItemManager.gd
# =========================

# Add this signal at the top:
# signal items_changed

# Update give_item_by_name to notify active manager and emit signal:
# func give_item_by_name(name: String):
#	if not items_by_name.has(name):
#		return
#	var item = items_by_name[name]
#	player_items.append(item)
#	if item.is_active:
#		ActiveItemManager.add_item(item)
#	emit_signal("items_changed")


# =========================
# 3. HOOK INTO BoardManager.gd
# =========================

# In apply_damage(), after RunProgressionManager.record_damage_taken(damage):
#	ActiveItemManager.on_damage_taken(damage)

# In apply_heal():
#	ActiveItemManager.on_health_healed(amount)

# In submit_guess(), after RunProgressionManager.record_row_submitted(guess):
#	ActiveItemManager.on_row_submitted()
#	for peg_id in guess:
#		ActiveItemManager.on_peg_placed(peg_id)
# After showing feedback:
#	ActiveItemManager.on_feedback_received(result[0], result[1])

# In _ready() and start_next_board(), add:
#	ActiveItemManager.set_context(self, peg_manager_reference, popup_manager)


# =========================
# 4. HOOK INTO KeywordEngine.gd
# =========================

# In apply_keyword, inside the "Replace" case, add:
#	ActiveItemManager.on_replace_used()


# =========================
# 5. TOOLTIP ADDITION
# =========================
# Add this function to your Tooltip.gd script:

# func display_active_item(item: ItemData):
#	name_label.text = item.item_name + " [" + item.get_rarity_name() + "]"
#	name_label.add_theme_color_override("font_color", item.get_rarity_color())
#	clear_preview()
#	var charge_text = "Charge: "
#	for condition in item.charge_conditions:
#		charge_text += "%s x%.0f  " % [condition.get("stat", ""), condition.get("amount", 1.0)]
#	charge_text += "\nMax Charge: %.0f" % item.charge_max
#	description_label.text = item.description
#	effect_label.text = charge_text + "\n" + build_effect_text(item.active_keywords)
#	update_minimum_size()


# =========================
# 6. RARITY WEIGHTING IN RunProgressionManager
# =========================

# Update get_reward_choices() to weight by rarity:
#
# func get_reward_choices() -> Array:
#	var choices := []
#	var weighted_items = _get_weighted_pool(reward_pool_items)
#	weighted_items.shuffle()
#	reward_pool_modifiers.shuffle()
#	for i in range(3):
#		if weighted_items.is_empty() or reward_pool_modifiers.is_empty():
#			break
#		choices.append({
#			"item": weighted_items.pop_front(),
#			"modifier": reward_pool_modifiers.pop_front()
#		})
#	return choices
#
# func _get_weighted_pool(pool: Array) -> Array:
#	var weighted := []
#	for item in pool:
#		var weight = _rarity_weight(item.rarity)
#		for i in range(weight):
#			weighted.append(item)
#	weighted.shuffle()
#	return weighted
#
# func _rarity_weight(rarity: int) -> int:
#	match rarity:
#		0: return 8   # Common
#		1: return 4   # Uncommon
#		2: return 2   # Rare
#		3: return 1   # Legendary
#	return 8


# =========================
# 7. RESET ON NEW RUN
# =========================
# In RunProgressionManager.start_new_run():
#	ActiveItemManager.reset_on_new_run()


# =========================
# 8. ACTIVEITEMPANEL SCENE STRUCTURE
# =========================
# PanelContainer (ActiveItemPanel.gd)
# └── VBoxContainer
#	├── Label "Active Items" (title)
#	└── VBoxContainer "SlotContainer" (separation 4)


# =========================
# 9. ACTIVEITEMSLOT SCENE STRUCTURE
# =========================
# PanelContainer (ActiveItemSlot.gd, custom_minimum_size 120x80)
# ├── BorderPanel (ColorRect, full rect, outline shader for rarity border)
# ├── ReadyGlow (ColorRect, full rect, golden color, hidden by default)
# └── VBoxContainer
#	├── FillContainer (Control, custom_minimum_size 120x50)
#	│	├── BGFill (ColorRect, full rect, dark grey)
#	│	├── FillBar (ColorRect, anchored left, lighter grey, fills left to right)
#	│	└── Icon (TextureRect, centered, 32x32)
#	└── HBoxContainer "ChargeIcons" (separation 2, small icons row)


# =========================
# 10. ADDING PANEL TO A SCENE
# =========================
# Just instance ActiveItemPanel.tscn as a child of your scene
# Position it on the left side
# It handles everything else automatically via autoloads
