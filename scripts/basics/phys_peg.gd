extends Node2D

signal hovered
signal hovered_off

var peg_id := 0
var current_slot = null
var hand_position
var is_copy := false

var peg_database_reference
var peg_down_reference
var peg_out_reference
var peg_sprite2D

var row := -1
var column := -1

var last_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var tilt_strength = 0.05
var max_tilt = 0.75

var is_special := false
var special_type := ""
var stack_count := 0

var shader_material: ShaderMaterial

@onready var modifier = ""
@onready var counter = $Counter

func _ready():
	get_parent().connect_peg_signals(self)
	add_to_group("pegs")
	peg_database_reference = preload("res://scripts/basics/peg_data.gd")
	peg_sprite2D = $Sprite2D
	if !is_copy and not is_special:
		counter.visible = true
	else:
		counter.visible = false

	setup_visuals()
	
	PegInventoryManager.connect("peg_count_changed", _on_count_changed)
	_update_counter_display()

	if is_copy or is_special:
		modulate = Color.WHITE

	peg_sprite2D.material = peg_sprite2D.material.duplicate()
	last_position = position
	shader_material = peg_sprite2D.material as ShaderMaterial


func _process(delta: float) -> void:
	if drag_velocity.length() > 0:
		var target_rotation = clamp(drag_velocity.x * tilt_strength, -max_tilt, max_tilt)
		rotation = lerpf(rotation, target_rotation, 10.0 * delta)
	else:
		rotation = lerpf(rotation, 0.0, 10.0 * delta)
		if is_copy or is_special:
			if modulate != Color.WHITE:
				modulate = Color.WHITE


func setup_visuals():
	modifier = ""
	if is_special:
		modifier = "_" + special_type
	
	peg_down_reference = load("res://assets/pegs/peg_down" + modifier + ".svg")
	peg_out_reference = load("res://assets/pegs/peg_out" + modifier + ".svg")
	
	if peg_sprite2D:
		peg_sprite2D.texture = peg_out_reference


func update_shader_value(new_value):
	if shader_material:
		shader_material.set_shader_parameter("outline_thickness", new_value)


func is_stack() -> bool:
	return is_special and not is_copy


func take_from_stack() -> bool:
	if not is_stack():
		return false
	
	if stack_count <= 0:
		return false
	
	stack_count -= 1
	counter.text = str(stack_count)
	
	if stack_count <= 0:
		var hand = get_node("../../PlayerHand")
		hand.player_hand.erase(self)
		hand.update_hand_positions()
		queue_free()
	
	return true


func add_to_stack(amount: int):
	stack_count += amount
	counter.text = str(stack_count)
	counter.visible = true


func _on_count_changed(color_id: int, new_count: int, old_count: int):
	if is_copy or is_special:
		return
	if color_id != peg_id:
		return
	_animate_counter(old_count, new_count)


func _animate_counter(from_val: int, to_val: int):
	if is_copy or is_special:
		return
	var step = 1 if to_val > from_val else -1
	var current = from_val
	var total_steps = abs(to_val - from_val)
	if total_steps == 0:
		counter.text = str(to_val)
		return

	# Ramp speed — faster as it progresses
	var base_interval := 0.15
	var min_interval := 0.03

	while current != to_val:
		current += step
		counter.text = str(current)
		var progress = 1.0 - (float(abs(to_val - current)) / float(total_steps))
		var interval = lerp(base_interval, min_interval, progress)
		await get_tree().create_timer(interval).timeout

	_update_greyed_state(to_val)


func _update_counter_display():
	if is_copy or is_special:
		return
	var count = PegInventoryManager.get_count(peg_id)
	counter.text = str(count)
	_update_greyed_state(count)


func _update_greyed_state(count: int):
	if is_copy or is_special:
		modulate = Color.WHITE
	if count <= 0:
		modulate = Color(0.4, 0.4, 0.4, 1.0)
	else:
		modulate = Color.WHITE


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_mouse_exited() -> void:
	emit_signal("hovered_off", self)

func _on_counters_updated(counters):
	for key in counters.keys():
		var color = get_id_from_color_name(key)
		if peg_id == color:
			counter.text = str(counters[key])

func get_submission_value():
	if is_special:
		match special_type:
			"goop":
				return 0  # Special non-color ID
	return peg_id


func get_id_from_color_name(color):
	match color:
		"red": return 1
		"yellow": return 2
		"green": return 3
		"white": return 4
		"purple": return 5
		"orange": return 6
		"unknown": return 0