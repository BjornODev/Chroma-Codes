# =========================
# FORGESCREEN SCENE STRUCTURE
# =========================
#
# Control (ForgeScreen.gd, full rect)
# ├── IrisWipe (CanvasLayer)
# ├── BackgroundLayer (CanvasLayer)
# ├── HUDLayer (CanvasLayer)
# │   └── HUDRoot
# │       ├── ItemsHUD
# │       ├── ModifiersHUD
# │       ├── HealthText
# │       └── MoneyLabel
# ├── TooltipLayer (CanvasLayer, layer=100)
# │   └── Tooltip
# ├── HBoxContainer (full rect, separation 40, alignment center)
# │   ├── ActiveSection (VBoxContainer)
# │   │   ├── Label "Active Items" (centered)
# │   │   └── ActiveGrid (VBoxContainer, separation 8)
# │   └── PassiveSection (VBoxContainer)
# │       ├── Label "Items" (centered)
# │       └── PassiveGrid (GridContainer, columns=4, separation 16)
# ├── ConfirmButton (Button)
# │   └── Label
# └── LeaveButton (Button, bottom center)
#     └── Label "LEAVE"
#
# NOTE: PassiveGrid uses GridContainer with columns=4
# so items fill left to right by rarity automatically.
# ActiveGrid uses VBoxContainer since max 5 active items
# fit naturally in a column.
#
# DisplayIcon.tscn custom_minimum_size should be around
# 100x100 so the grid fills the screen nicely at 1920x1080.
