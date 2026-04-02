class_name ItemData
extends Resource

# =========================
# SHARED FIELDS
# =========================
@export var item_name: String
@export var description: String
@export var icon: Texture2D
@export_enum("Common", "Uncommon", "Rare", "Legendary") var rarity: int = 0
@export var price: int = 1

# =========================
# PASSIVE FIELDS
# =========================
@export var triggers: Array[Dictionary]
@export var keywords: Dictionary

# =========================
# ACTIVE FIELDS
# =========================
@export var is_active: bool = false
@export var charge_max: float = 10.0

# charge_conditions: Array of Dictionaries
# Each dict: { "stat": "damage_taken", "amount": 1.0, "icon_color": Color }
# Supported stats:
#   "damage_taken"       — increments by damage amount each hit
#   "health_healed"      — increments by heal amount
#   "pegs_placed_red"    — increments when red peg placed
#   "pegs_placed_yellow"
#   "pegs_placed_green"
#   "pegs_placed_white"
#   "pegs_placed_purple"
#   "pegs_placed_orange"
#   "pegs_placed_any"    — any color peg placed
#   "rows_submitted"     — increments each row submit
#   "active_activated"   — increments when any active item is activated
#   "replace_used"       — increments when replace keyword fires
#   "black_pegs"         — increments by black feedback pegs per row
#   "white_pegs"         — increments by white feedback pegs per row
@export var charge_conditions: Array[Dictionary]

# active_keywords: fires when activated (same format as passive keywords)
@export var active_keywords: Dictionary


func get_rarity_color() -> Color:
	match rarity:
		0: return Color("#888888")  # Common
		1: return Color("#00CC44")  # Uncommon
		2: return Color("#4488FF")  # Rare
		3: return Color("#FFD700")  # Legendary
	return Color("#888888")


func get_rarity_name() -> String:
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Legendary"
	return "Common"
