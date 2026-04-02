# =========================
# SHOP SETUP NOTES
# =========================


# =========================
# 1. AUTOLOAD
# =========================
# Add ShopManager.gd as autoload named "ShopManager"


# =========================
# 2. REFRESH SHOP AFTER BOSS
# =========================
# In MapScreen.gd, when boss is cleared and new map starts:
#	ShopManager.refresh_shop(MapManager.run_seed + 700000 + boards_cleared * 999983)
# Also call this in RunProgressionManager.start_new_run():
#	ShopManager.is_initialized = false


# =========================
# 3. SHOPSCREEN SCENE STRUCTURE
# =========================
# Control (ShopScreen.gd)
# ├── IrisWipe (CanvasLayer)
# ├── HBoxContainer (separation 20, centered)
# │   ├── BuffSection (VBoxContainer)
# │   │   ├── Label "Buffs"
# │   │   ├── HealthButton (ShopBuffButton.tscn)
# │   │   └── ChaosButton (ShopBuffButton.tscn)
# │   └── ItemSection (VBoxContainer)
# │       ├── Label "Shop"
# │       ├── GridContainer (columns=3, separation 8) "GridContainer"
# │       └── Button "RerollButton"
# │           └── Label
# └── Button "LeaveButton" (bottom of screen)


# =========================
# 4. SHOPITEM SCENE STRUCTURE
# =========================
# PanelContainer (ShopItem.gd, custom_minimum_size 140x160)
# ├── RarityBorder (ColorRect, full rect — just the border color, use StyleBox)
# ├── SoldOverlay (ColorRect, full rect, dark semi-transparent, hidden by default)
# └── MarginContainer
#     └── VBoxContainer
#         ├── CenterContainer
#         │   └── Icon (TextureRect, custom_minimum_size 64x64, shrink center)
#         └── PriceLabel (Label, centered)
#
# For the StyleBox customization space — select the PanelContainer root
# and in Theme Overrides > Styles > Panel, assign a StyleBoxFlat
# This is the easy-to-swap background per item


# =========================
# 5. SHOPBUFFBUTTON SCENE STRUCTURE
# =========================
# PanelContainer (ShopBuffButton.gd, custom_minimum_size 100x120)
# └── VBoxContainer
#     ├── CenterContainer
#     │   └── Icon (ColorRect, 32x32 — placeholder, swap with TextureRect later)
#     ├── PriceLabel (Label)
#     └── RemainingLabel (Label)


# =========================
# 6. RARITY BORDER
# =========================
# The RarityBorder ColorRect uses a shader for an outline effect
# or simply set its color and use it as a thin border behind the panel
# ShopItem.gd sets rarity_border.color from RARITY_COLORS dict
# To make it look like a border: set the PanelContainer StyleBox to have
# a dark background, and the RarityBorder to be slightly larger (use margins)


# =========================
# 7. HOOKING SHOP REFRESH TO BOSS CLEAR
# =========================
# When MapManager detects boss cleared and new map starts,
# call ShopManager.refresh_shop() with a new seed so the shop
# has fresh inventory for the next map
