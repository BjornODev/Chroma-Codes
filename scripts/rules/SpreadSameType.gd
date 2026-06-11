class_name SpreadSameTypeRule
extends Rule

# =========================
# RULE: Spread same-type feedback as far apart as possible.
# Score is the minimum angular distance between any two same-type pieces,
# normalized to [0, 1]. Higher = better spread.
# Types with only 0 or 1 pieces contribute neutral (1.0, perfectly spread).
# =========================

func get_rule_name() -> String:
	return "Spread"


func get_description() -> String:
	return "Feedback of the same type wants to be as far away from itself as possible."


func get_priority() -> int:
	return 100


func score_arrangement(arrangement: Array, slot_count: int) -> float:
	if slot_count <= 1:
		return 1.0

	var type_positions := {}
	for i in range(arrangement.size()):
		var t = arrangement[i]
		if not type_positions.has(t):
			type_positions[t] = []
		type_positions[t].append(i)

	var max_possible_angular = float(slot_count) / 2.0
	var per_type_scores := []

	for type in type_positions.keys():
		var positions = type_positions[type]
		if positions.size() <= 1:
			per_type_scores.append(1.0)
			continue

		var min_distance = INF
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				var raw_diff = abs(positions[i] - positions[j])
				var circular_diff = min(raw_diff, slot_count - raw_diff)
				if circular_diff < min_distance:
					min_distance = circular_diff

		var normalized = float(min_distance) / max_possible_angular
		per_type_scores.append(clamp(normalized, 0.0, 1.0))

	if per_type_scores.is_empty():
		return 1.0

	var sum := 0.0
	for s in per_type_scores:
		sum += s
	return sum / float(per_type_scores.size())