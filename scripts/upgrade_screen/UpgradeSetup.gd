# =========================
# UPGRADE SYSTEM SETUP NOTES
# =========================


# =========================
# 1. UPDATE Tooltip.gd display_item() AND display_active_item()
# =========================
# Change name_label.text to use get_display_name() instead of item_name:
#
# func display_item(item: ItemData):
#	name_label.text = item.get_display_name()  # ← was item.item_name
#	# ... rest unchanged
#
# func display_active_item(item: ItemData):
#	name_label.text = item.get_display_name() + " [" + item.get_rarity_name() + "]"
#	# ... rest unchanged


# =========================
# 2. UPGRADESCREEN SCENE STRUCTURE
# =========================
# Control (UpgradeScreen.gd)
# ├── IrisWipe (CanvasLayer)
# ├── BackgroundLayer (CanvasLayer)
# ├── HUDLayer (CanvasLayer)
# ├── TooltipLayer (CanvasLayer, layer=100)
# │   └── Tooltip
# ├── HBoxContainer (full rect, separation 40, alignment center)
# │   ├── ItemListSection (VBoxContainer, custom_minimum_size 400x0)
# │   │   ├── Label "YOUR ITEMS"
# │   │   └── ScrollContainer (custom_minimum_size 400x600)
# │   │       └── ItemList (VBoxContainer, separation 8) "ItemList"
# │   └── DetailsSection (VBoxContainer, custom_minimum_size 500x0, separation 16)
# │       ├── ItemNameLabel (Label)
# │       ├── CurrentStatsLabel (Label)
# │       ├── UpgradePreviewLabel (Label)
# │       ├── CostLabel (Label)
# │       └── ConfirmButton (Button)
# │           └── Label "UPGRADE"
# └── LeaveButton (Button, bottom center)
#     └── Label "LEAVE"


# =========================
# 3. UPGRADEITEMROW SCENE STRUCTURE
# =========================
# PanelContainer (UpgradeItemRow.gd, custom_minimum_size 380x70)
# ├── HoverOutline (ColorRect, full rect, outline shader material)
# └── HBoxContainer (separation 12)
#     ├── Icon (TextureRect, custom_minimum_size 48x48, shrink center)
#     └── VBoxContainer
#         ├── NameLabel (Label)
#         └── UpgradeLabel (Label)


# =========================
# 4. CONFIGURING UPGRADES IN .tres FILES
# =========================
# In each ItemData .tres, set upgrade tiers as Dictionaries:
#
# upgrade_tier_1: {
#     "effect": {"Replace": 1},
#     "trigger": {},
#     "charge_max_delta": 0.0
# }
# upgrade_tier_2: {
#     "effect": {"Replace": 1},
#     "trigger": {"red": -1},
#     "charge_max_delta": 0.0
# }
# upgrade_tier_3: {
#     "effect": {"Replace": 1, "Cleanse": 2},
#     "trigger": {},
#     "charge_max_delta": -2.0
# }
#
# Leave upgrade_tier_1/2/3 empty ({}) if the item should not be upgradeable
# can_upgrade() returns false if all tiers are empty OR upgrade_level >= 3


# =========================
# 5. UPGRADE PERSISTENCE
# =========================
# upgrade_level is a var (not @export) on ItemData
# This means it does NOT persist between runs automatically
# It persists within a run because ItemManager.player_items holds
# the same ItemData instances throughout the run
# On start_new_run(), ItemManager reloads items from disk
# resetting upgrade_level to 0 — this is correct behavior


# =========================
# 6. UPDATE can_upgrade() TO HANDLE EMPTY TIERS
# =========================
# Add to ItemData.gd:
#
# func can_upgrade() -> bool:
#	if upgrade_level >= 3:
#		return false
#	var next = get_next_tier()
#	return not next.is_empty()
