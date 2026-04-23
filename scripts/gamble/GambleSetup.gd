# =========================
# GAMBLE SETUP NOTES
# =========================


# =========================
# 1. ADD TO ItemData.gd
# =========================
# @export var is_gamble_only: bool = false


# =========================
# 2. FILTER FROM REWARD POOL — RunProgressionManager._get_weighted_item_pool()
# =========================
# func _get_weighted_item_pool(pool: Array) -> Array:
#	var weighted := []
#	for item in pool:
#		if item.is_gamble_only:
#			continue
#		var weight = _rarity_weight(item.rarity)
#		for i in range(weight):
#			weighted.append(item)
#	return weighted


# =========================
# 3. FILTER FROM SHOP — ShopManager._build_weighted_pool()
# =========================
# Add: if item.is_gamble_only: continue
# after: if item.item_name in purchased_item_names: continue


# =========================
# 4. ADD can_afford TO RunProgressionManager
# =========================
# func can_afford(amount: int) -> bool:
#	return dollars >= amount


# =========================
# 5. GAMBLESCREEN SCENE STRUCTURE
# =========================
# Control (GambleScreen.gd)
# ├── IrisWipe (CanvasLayer)
# ├── BackgroundLayer (CanvasLayer)
# ├── HUDLayer (CanvasLayer)
# ├── TooltipLayer (CanvasLayer, layer=100)
# │   └── Tooltip
# ├── HBoxContainer (full rect, alignment center)
# │   └── ReelSection (VBoxContainer, alignment center, separation 24)
# │       ├── Reels (HBoxContainer, separation 16)
# │       │   ├── ReelLeft (Control, SlotReel.gd, clip_contents=true)
# │       │   │   ├── SymbolContainer (VBoxContainer, separation 0)
# │       │   │   └── HighlightBar (ColorRect)
# │       │   ├── ReelCenter (same)
# │       │   └── ReelRight (same)
# │       ├── SpinButton (Button, min size 300x70)
# │       │   └── Label
# │       └── ResultLabel (Label, centered, min width 400)
# └── LeaveButton (Button, bottom center)
#     └── Label


# =========================
# 6. SLOTРEEL SCENE STRUCTURE
# =========================
# Control (SlotReel.gd)
# ├── SymbolContainer (VBoxContainer, separation 0)
# └── HighlightBar (ColorRect)
#
# The script handles clip_contents, sizing, and highlight positioning in _ready()
# SymbolContainer gets filled procedurally in setup()
