extends CanvasLayer

var text

var health_ranges = [1, 3, 5, 7, 9]
var range_colors = ["#FF073A", "#FBFF12", "#B7FF00", "#1F51FF", "#7D12FF"]

func initialize():
	text = $RichTextLabel

func change_health(health):
	var range_index := 0
	
	for i in health_ranges:
		if health <= i:
			break
		range_index += 1
	
	# Prevent overflow if health is larger than last range
	range_index = clamp(range_index, 0, range_colors.size() - 1)
	
	var color = range_colors[range_index]
	
	text.bbcode_enabled = true
	text.bbcode_text = "[center][color=%s]%d[/color][/center]" % [color, health]