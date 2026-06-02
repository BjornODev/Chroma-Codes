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
@export var is_gamble_only: bool = false

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
@export var charge_conditions: Array[Dictionary]
@export var active_keywords: Dictionary

# =========================
# UPGRADE FIELDS
# =========================
# Tier 1
@export var upgrade_tier_1_effect: Dictionary
@export var upgrade_tier_1_trigger: Dictionary  
@export var upgrade_tier_1_charge_delta: float = 0.0

# Tier 2
@export var upgrade_tier_2_effect: Dictionary
@export var upgrade_tier_2_trigger: Dictionary
@export var upgrade_tier_2_charge_delta: float = 0.0

# Tier 3
@export var upgrade_tier_3_effect: Dictionary
@export var upgrade_tier_3_trigger: Dictionary
@export var upgrade_tier_3_charge_delta: float = 0.0


# Current upgrade level — 0 = base, 1 = +, 2 = ++, 3 = +++
var upgrade_level: int = 0


func get_rarity_color() -> Color:
	match rarity:
		0: return Color("#888888")
		1: return Color("#00CC44")
		2: return Color("#4488FF")
		3: return Color("#FFD700")
	return Color("#888888")


func get_rarity_name() -> String:
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Legendary"
	return "Common"


func get_upgrade_label() -> String:
	match upgrade_level:
		0: return ""
		1: return "+"
		2: return "++"
		3: return "+++"
	return ""


func get_display_name() -> String:
	var label = get_upgrade_label()
	if label == "":
		return item_name
	return item_name + " " + label


func get_next_tier() -> Dictionary:
	match upgrade_level:
		0: return {
			"effect": upgrade_tier_1_effect,
			"trigger": upgrade_tier_1_trigger,
			"charge_max_delta": upgrade_tier_1_charge_delta
		}
		1: return {
			"effect": upgrade_tier_2_effect,
			"trigger": upgrade_tier_2_trigger,
			"charge_max_delta": upgrade_tier_2_charge_delta
		}
		2: return {
			"effect": upgrade_tier_3_effect,
			"trigger": upgrade_tier_3_trigger,
			"charge_max_delta": upgrade_tier_3_charge_delta
		}
	return {}


func can_upgrade() -> bool:
	if upgrade_level >= 3:
		return false
	match upgrade_level:
		0: return not (upgrade_tier_1_effect.is_empty() and upgrade_tier_1_trigger.is_empty() and upgrade_tier_1_charge_delta == 0.0)
		1: return not (upgrade_tier_2_effect.is_empty() and upgrade_tier_2_trigger.is_empty() and upgrade_tier_2_charge_delta == 0.0)
		2: return not (upgrade_tier_3_effect.is_empty() and upgrade_tier_3_trigger.is_empty() and upgrade_tier_3_charge_delta == 0.0)
	return false



func get_base_cost(cost_type: String) -> int:
	match cost_type:
		"chaos":
			match rarity:
				0: return 2
				1: return 3
				2: return 4
				3: return 5
		"health":
			match rarity:
				0: return 1
				1: return 2
				2: return 3
				3: return 4
		"dollars":
			match rarity:
				0: return 2
				1: return 3
				2: return 4
				3: return 5
	return 2


func get_upgrade_cost(cost_type: String) -> int:
	var base = get_base_cost(cost_type)
	var next_level = upgrade_level + 1
	return base * next_level


func apply_upgrade():
	if not can_upgrade():
		return

	var tier = get_next_tier()
	if tier.is_empty():
		return

	# Apply effect deltas
	var effect_deltas = tier.get("effect", {})
	for key in effect_deltas:
		var target = active_keywords if is_active else keywords
		var current = target.get(key, 0)
		var delta = effect_deltas[key]

		if current is Dictionary or delta is Dictionary:
			var current_dict = current if current is Dictionary else {"color": "", "amount": int(current)}
			var delta_dict = delta if delta is Dictionary else {"color": "", "amount": int(delta)}
			var new_amount = current_dict.get("amount", 0) + delta_dict.get("amount", 0)
			# Prefer the non-empty color
			var new_color = current_dict.get("color", "")
			if new_color == "":
				new_color = delta_dict.get("color", "")
			target[key] = {"color": new_color, "amount": new_amount}
		else:
			target[key] = int(current) + int(delta)

	# Apply trigger deltas
	var trigger_deltas = tier.get("trigger", {})
	for key in trigger_deltas:
		if triggers.size() > 0:
			var t = triggers[0]
			if t.has(key):
				t[key] = t[key] + trigger_deltas[key]

	# Apply charge_max delta
	var charge_delta = tier.get("charge_max_delta", 0.0)
	if charge_delta != 0.0:
		charge_max = max(1.0, charge_max + charge_delta)

	upgrade_level += 1