extends Bar

@export var heal_color: Color
@export var damage_color: Color

@onready var segmented_bar_l := %SegmentedBarL as SegmentedBar
@onready var segmented_bar_r := %SegmentedBarR as SegmentedBar

var health := 0.5

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_down"):
		damage(health - 0.10)
		health -= 0.10
	if Input.is_action_just_pressed("ui_up"):
		heal(health + 0.10)
		health += 0.10


func set_health(health: float) -> void:
	segmented_bar_l.set_value(health)
	segmented_bar_r.set_value(health)


func set_max_health(max_health: float) -> void:
	segmented_bar_l.set_max(max_health)
	segmented_bar_r.set_max(max_health)


func damage(new_health: float) -> void:
	segmented_bar_l.change_rate = 0.5
	segmented_bar_r.change_rate = 0.5
	segmented_bar_l.slow_change(new_health, damage_color, 1.0)
	segmented_bar_r.slow_change(new_health, damage_color, 1.0)


func heal(new_health: float) -> void:
	segmented_bar_l.change_rate = 1.0
	segmented_bar_r.change_rate = 1.0
	segmented_bar_l.slow_change(new_health, heal_color, 1.0)
	segmented_bar_r.slow_change(new_health, heal_color, 1.0)
