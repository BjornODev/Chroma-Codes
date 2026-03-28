extends Bar

@onready var segmented_bar := %SegmentedBar as SegmentedBar
@onready var border := %BorderTexture as Control

var health := 1
@export var increment := 0.1

var tween: Tween

func _ready() -> void:
	border.position.y = 3


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		health += 0.1
		heal(health)
		print(health)
	if Input.is_action_just_pressed("ui_down"):
		health -= 0.1
		damage(health)
		print(health)


func set_health(health: float) -> void:
	segmented_bar.set_value(health)


func set_max_health(max_health: float) -> void:
	segmented_bar.set_max(max_health)


func damage(new_health: float) -> void:
	segmented_bar.change_rate = 1000.0
	segmented_bar.slow_change(new_health, Color.TRANSPARENT, 0.0)
	_shake()


func heal(new_health: float) -> void:
	segmented_bar.change_rate = 1000.0
	segmented_bar.slow_change(new_health, Color.TRANSPARENT, 0.0)


func _shake() -> void:
	if tween != null:
		tween.kill()
	tween = create_tween()
	border.position.y = 5
	tween.tween_property(border, "position:y", 3, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if tween != null:
		tween.kill()
