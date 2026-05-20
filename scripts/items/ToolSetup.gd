# =========================
# ITEMMAKERTOOL SCENE STRUCTURE
# =========================

# Build ItemMakerTool.tscn in Godot with this hierarchy:
# Control (ItemMakerTool.gd)
# │
# ├── TopBar (HBoxContainer, anchor top)
# │   ├── NewButton (Button, text “New”)
# │   ├── LoadDropdown (OptionButton)
# │   ├── DuplicateButton (Button, text “Duplicate”)
# │   ├── SaveButton (Button, text “Save”)
# │   └── PreviewButton (Button, text “Preview Tooltip”)
# │
# ├── ScrollContainer (anchor full rect, top offset 80)
# │   └── VBox (VBoxContainer, separation 16)
# │       │
# │       ├── SharedSection (VBoxContainer)
# │       │   ├── Label “SHARED FIELDS”
# │       │   ├── NameEdit (LineEdit, placeholder “Item name”)
# │       │   ├── DescriptionEdit (TextEdit)
# │       │   ├── IconDropdown (OptionButton)
# │       │   ├── RarityDropdown (OptionButton)
# │       │   ├── PriceEdit (LineEdit)
# │       │   └── GambleOnlyCheck (CheckBox, text “Gamble Only”)
# │       │
# │       ├── IsActiveCheck (CheckBox, text “Is Active Item”)
# │       │
# │       ├── PassiveSection (VBoxContainer)
# │       │   ├── Label “PASSIVE FIELDS”
# │       │   ├── Label “Triggers”
# │       │   ├── TriggersList (VBoxContainer)
# │       │   │   └── AddButton (Button, text “+ Add Trigger”)
# │       │   │       └── pressed signal → _on_add_trigger()
# │       │   ├── Label “Keywords”
# │       │   └── KeywordsList (VBoxContainer)
# │       │       └── AddButton (Button, text “+ Add Keyword”)
# │       │           └── pressed signal → _on_add_keyword()
# │       │
# │       ├── ActiveSection (VBoxContainer)
# │       │   ├── Label “ACTIVE FIELDS”
# │       │   ├── Label “Charge Max”
# │       │   ├── ChargeMaxEdit (LineEdit)
# │       │   ├── Label “Charge Conditions”
# │       │   ├── ChargeConditionsList (VBoxContainer)
# │       │   │   └── AddButton (Button, text “+ Add Charge Condition”)
# │       │   │       └── pressed signal → _on_add_charge_condition()
# │       │   ├── Label “Active Keywords”
# │       │   └── ActiveKeywordsList (VBoxContainer)
# │       │       └── AddButton (Button, text “+ Add Active Keyword”)
# │       │           └── pressed signal → _on_add_active_keyword()
# │       │
# │       └── UpgradeSection (VBoxContainer)
# │           ├── Label “UPGRADE TIERS”
# │           ├── Tier1 (VBoxContainer)
# │           │   ├── Label “Tier 1 (+)”
# │           │   ├── Label “Effect Deltas”
# │           │   ├── EffectList (VBoxContainer)
# │           │   │   └── AddButton (Button, text “+ Add Effect”)
# │           │   │       └── pressed signal → _on_add_tier_effect($Tier1)
# │           │   ├── Label “Trigger Deltas”
# │           │   ├── TriggerList (VBoxContainer)
# │           │   │   └── AddButton (Button, text “+ Add Trigger Delta”)
# │           │   │       └── pressed signal → _on_add_tier_trigger($Tier1)
# │           │   ├── Label “Charge Max Delta”
# │           │   └── ChargeDeltaEdit (LineEdit)
# │           ├── Tier2 (same structure as Tier1)
# │           └── Tier3 (same structure as Tier1)
# │
# └── TooltipPreview (instance of Tooltip.tscn, visible=false, positioned top right)
# =========================
# WIRING THE ADD BUTTONS
# =========================

# Because each AddButton needs to call the script with specific parameters
# (especially for tier buttons), connect them in the editor:
# 
# TriggersList/AddButton.pressed → root._on_add_trigger
# KeywordsList/AddButton.pressed → root._on_add_keyword
# ChargeConditionsList/AddButton.pressed → root._on_add_charge_condition
# ActiveKeywordsList/AddButton.pressed → root._on_add_active_keyword
# 
# For tier buttons, use lambda connections in script after _ready():
# 
# var tiers = [upgrade_tier_1, upgrade_tier_2, upgrade_tier_3]
# for tier in tiers:
# tier.get_node(“EffectList/AddButton”).pressed.connect(
# func(): _on_add_tier_effect(tier)
# )
# tier.get_node(“TriggerList/AddButton”).pressed.connect(
# func(): _on_add_tier_trigger(tier)
# )
# =========================
# LAUNCHING THE TOOL
# =========================

# Save as res://scenes/ItemMakerTool.tscn
# To launch from your main menu add a hidden dev button that calls:
# get_tree().change_scene_to_file(“res://scenes/ItemMakerTool.tscn”)
# Or set it as the main scene temporarily in Project Settings while editing items
# =========================
# CAVEATS
# =========================
# 1. ResourceSaver.save() works at runtime in the editor but NOT in exported builds
# This tool is for development use only — don’t ship it
# 
# 2. Update _get_keyword_list() to match your actual KeywordEngine keyword list
# 
# 3. CHARGE_CONDITION_TYPES at the top of ItemMakerTool.gd must match the actual
# condition types your ActiveItemManager expects
# 
# 4. The Preview button uses your existing Tooltip.tscn — instance it as a child
# of the root Control and assign it to the @onready var tooltip_preview