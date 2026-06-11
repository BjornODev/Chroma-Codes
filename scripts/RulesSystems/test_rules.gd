extends Node

# Run via: gdscript -s test_rules.gd
# Or attach to a scene and run once.

func _ready():
	_test_scenario("4 slots: 1 none, 1 almost, 2 corrects",
		4, {"none": 1, "almost": 1, "correct": 2},
		["none", "correct", "almost", "correct"])

	_test_scenario("4 slots: all corrects",
		4, {"none": 0, "almost": 0, "correct": 4},
		["correct", "correct", "correct", "correct"])

	_test_scenario("4 slots: 2 nones 2 almosts",
		4, {"none": 2, "almost": 2, "correct": 0},
		["none", "almost", "none", "almost"])

	_test_scenario("6 slots: 3 nones, 2 almosts, 1 correct",
		6, {"none": 3, "almost": 2, "correct": 1},
		null)  # Don't hardcode, just inspect

	_test_scenario("6 slots: 2 nones, 1 almost, 3 corrects",
	6, {"none": 2, "almost": 1, "correct": 3},
	null)

	_test_scenario("4 slots: 4 nones (no feedback)",
		4, {"none": 4, "almost": 0, "correct": 0},
		["none", "none", "none", "none"])

	_test_scenario("4 slots: 1 correct, 3 nones",
		4, {"none": 3, "almost": 0, "correct": 1},
		null)


func _test_scenario(label: String, slot_count: int, counts: Dictionary, expected):
	print("\n=== ", label, " ===")
	var result = RulesEngine.resolve_placement(slot_count, counts)
	print("Result: ", result)
	if expected != null:
		var match_str = "PASS" if result == expected else "FAIL"
		print("Expected: ", expected, " — ", match_str)
