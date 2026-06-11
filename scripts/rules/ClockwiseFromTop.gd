class_name ClockwiseFromTopRule
extends Rule

# =========================
# RULE: Top slot first, then clockwise.
# Each slot has a positional weight (slot 0 = highest, decreasing clockwise).
# Each piece type has a type priority (none = 3, almost = 2, correct = 1).
# Score = sum of (slot_weight × type_priority) across all slots,
# normalized by the maximum possible score for this arrangement.
# Combined with the PieceTypePriority rule effect, this drives nones
# toward the top, almosts after, corrects last in clockwise order.
# =========================

const TYPE_PRIORITY := {
	"none": 3,
	"almost": 2,
	"correct": 1,
}


func get_rule_name() -> String:
	return "Clockwise From Top"


func get_description() -> String:
	return "Feedback fills from the top of the circle, clockwise. Empty slots take priority, then almost, then correct."


func get_priority() -> int:
	return 50


func score_arrangement(arrangement: Array, slot_count: int) -> float:
	if slot_count == 0:
		return 0.0

	# Slot weight: top (index 0) = 1.0, last clockwise = 1/slot_count
	# Compute raw score
	var raw_score := 0.0
	for i in range(arrangement.size()):
		var slot_weight = float(slot_count - i) / float(slot_count)
		var type_priority = TYPE_PRIORITY.get(arrangement[i], 0)
		raw_score += slot_weight * float(type_priority)

	# Compute max possible score: assign highest-priority types to highest-weight slots
	var type_counts := {}
	for t in arrangement:
		type_counts[t] = type_counts.get(t, 0) + 1

	var sorted_types = type_counts.keys()
	sorted_types.sort_custom(func(a, b): return TYPE_PRIORITY.get(a, 0) > TYPE_PRIORITY.get(b, 0))

	var max_score := 0.0
	var slot_index := 0
	for t in sorted_types:
		var count = type_counts[t]
		for i in range(count):
			var slot_weight = float(slot_count - slot_index) / float(slot_count)
			max_score += slot_weight * float(TYPE_PRIORITY.get(t, 0))
			slot_index += 1

	if max_score <= 0.0:
		return 0.0
	return raw_score / max_score