extends Node

# =========================
# RULES ENGINE
# Add new rule paths to RULE_PATHS when you create new rules.
# Each rule script must extend Rule.
# =========================

const RULE_PATHS := [
	"res://scripts/rules/SpreadSameType.gd",
	"res://scripts/rules/ClockwiseFromTop.gd",
]

var active_rules: Array[Rule] = []
var disabled_rule_names: Array[String] = []
var rules_loaded: bool = false

signal rules_ready


func _ready():
	_load_rules()


func _load_rules():
	active_rules.clear()
	for path in RULE_PATHS:
		var script = load(path)
		if script == null:
			push_warning("Failed to load rule script: " + path)
			continue
		var instance = script.new()
		if not instance is Rule:
			push_warning("Script does not extend Rule: " + path)
			continue
		active_rules.append(instance)

	active_rules.sort_custom(func(a, b): return a.get_priority() > b.get_priority())
	print("Loaded rules: ", active_rules.size())
	for rule in active_rules:
		print("  - ", rule.get_rule_name(), " (priority ", rule.get_priority(), ")")

	rules_loaded = true
	emit_signal("rules_ready")


# =========================
# PUBLIC API
# =========================

func resolve_placement(slot_count: int, feedback_counts: Dictionary) -> Array:
	var pieces := []
	for type in ["none", "almost", "correct"]:
		var count = feedback_counts.get(type, 0)
		for i in range(count):
			pieces.append(type)

	if pieces.size() != slot_count:
		push_error("Feedback piece count (%d) does not match slot count (%d)" % [pieces.size(), slot_count])
		return []

	var best_arrangement := []
	var best_score := -INF

	var arrangements = _enumerate_distinct_arrangements(pieces)

	for arrangement in arrangements:
		var score = _score_arrangement(arrangement, slot_count)
		if score > best_score:
			best_score = score
			best_arrangement = arrangement

	return best_arrangement


func get_active_rules() -> Array:
	var result := []
	for rule in active_rules:
		if rule.get_rule_name() not in disabled_rule_names:
			result.append(rule)
	return result


func set_rule_enabled(rule_name: String, enabled: bool):
	if enabled:
		disabled_rule_names.erase(rule_name)
	else:
		if rule_name not in disabled_rule_names:
			disabled_rule_names.append(rule_name)


# =========================
# INTERNALS
# =========================

func _score_arrangement(arrangement: Array, slot_count: int) -> float:
	var total := 0.0
	for rule in active_rules:
		if rule.get_rule_name() in disabled_rule_names:
			continue
		var rule_score = rule.score_arrangement(arrangement, slot_count)
		total += float(rule.get_priority()) * rule_score
	return total


func _enumerate_distinct_arrangements(pieces: Array) -> Array:
	var seen := {}
	var results := []
	_permute_helper(pieces.duplicate(), 0, seen, results)
	return results


func _permute_helper(arr: Array, start: int, seen: Dictionary, results: Array):
	if start == arr.size():
		var key = "|".join(arr.map(func(x): return str(x)))
		if not seen.has(key):
			seen[key] = true
			results.append(arr.duplicate())
		return

	var used_at_pos := {}
	for i in range(start, arr.size()):
		if used_at_pos.has(arr[i]):
			continue
		used_at_pos[arr[i]] = true
		var temp = arr[start]
		arr[start] = arr[i]
		arr[i] = temp
		_permute_helper(arr, start + 1, seen, results)
		temp = arr[start]
		arr[start] = arr[i]
		arr[i] = temp
