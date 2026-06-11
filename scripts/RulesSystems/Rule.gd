class_name Rule
extends Resource

# =========================
# RULE BASE CLASS
# Subclass this in res://scripts/rules/ to add new placement rules.
# RulesEngine auto-discovers all subclasses and uses them to score
# feedback arrangements globally per row.
# =========================

# Rule identity
func get_rule_name() -> String:
	return "Unnamed Rule"


func get_description() -> String:
	return ""


# Higher priority = larger weight in combined score
func get_priority() -> int:
	return 0


# Optional icon for the rules display panel
func get_icon() -> Texture2D:
	return null


# =========================
# SCORING
# Given a candidate arrangement (Array of type strings, one per slot),
# return a normalized score in [0, 1] indicating how well this rule
# is satisfied. RulesEngine multiplies by priority and sums across rules.
#
# arrangement format: ["none", "correct", "almost", "correct"] for 4 slots
# slot_count: convenience, same as arrangement.size()
# =========================
func score_arrangement(arrangement: Array, slot_count: int) -> float:
	return 0.0


# =========================
# DIAGRAM RENDERING
# Optional: render a small visual diagram of the rule into the given
# container. Used by the right-side rules display panel.
# Default does nothing — override to add visuals.
# =========================
func render_diagram(_container: Control):
	pass