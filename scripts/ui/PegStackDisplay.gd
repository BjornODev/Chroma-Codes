extends Node2D

# PegStackDisplay.gd
# Visual-only display of peg stacks for non-board screens
# Mirrors the player hand layout but pegs are purely informational

const PEG_SCENE = preload("res://scenes/Phys_Peg.tscn")
const PEG_WIDTH = 100
const PEG_Y_POSITION = 475  # relative to this node's position

var stack_pegs: Array = []
var peg_database_reference

var center_screen_x: float = 0.0

func _ready():
	peg_database_reference = preload("res://scripts/basics/peg_data.gd")
	center_screen_x = get_viewport().get_visible_rect().size.x / 2.0
	_build_stacks()
	PegInventoryManager.connect("peg_count_changed", _on_count_changed)


func _build_stacks():
	for child in stack_pegs:
		if is_instance_valid(child):
			child.queue_free()
	stack_pegs.clear()

	var peg_ids = [1, 2, 3, 4, 5, 6]

	# First instantiate all pegs and add to array
	for i in range(peg_ids.size()):
		var peg = PEG_SCENE.instantiate()
		peg.peg_id = peg_ids[i]
		peg.is_copy = false
		peg.is_special = false
		add_child(peg)

		peg.set_process_input(false)
		peg.set_process(false)

		for child in peg.get_children():
			if child is Area2D:
				child.input_pickable = false
				child.monitoring = false
				child.monitorable = false

		peg.peg_sprite2D = peg.get_node("Sprite2D")
		peg.peg_sprite2D.modulate = Color(peg_database_reference.PEG_TYPES[peg.peg_id][0])

		var count = PegInventoryManager.get_count(peg.peg_id)
		peg.counter.text = str(count)
		peg.counter.visible = true
		_update_greyed(peg, count)

		stack_pegs.append(peg)

	# Now position all pegs after array is fully populated
	for i in range(stack_pegs.size()):
		stack_pegs[i].position = Vector2(_calculate_peg_position(i), PEG_Y_POSITION)


func _calculate_peg_position(index: int) -> float:
	var total_count = stack_pegs.size()
	var x_offset = (total_count - 1) * PEG_WIDTH
	return index * PEG_WIDTH - x_offset / 2.0


func _on_count_changed(color_id: int, new_count: int, old_count: int):
	for peg in stack_pegs:
		if not is_instance_valid(peg):
			continue
		if peg.peg_id == color_id:
			_animate_peg_counter(peg, old_count, new_count)
			return


func _animate_peg_counter(peg, from_val: int, to_val: int):
	var step = 1 if to_val > from_val else -1
	var current = from_val
	var total_steps = abs(to_val - from_val)
	if total_steps == 0:
		peg.counter.text = str(to_val)
		_update_greyed(peg, to_val)
		return

	var base_interval := 0.08
	var min_interval := 0.015

	while current != to_val:
		current += step
		peg.counter.text = str(current)
		var progress = 1.0 - (float(abs(to_val - current)) / float(total_steps))
		var interval = lerp(base_interval, min_interval, progress)
		await get_tree().create_timer(interval).timeout

	_update_greyed(peg, to_val)


func _update_greyed(peg, count: int):
	if count <= 0:
		peg.modulate = Color(0.4, 0.4, 0.4, 1.0)
	else:
		peg.modulate = Color.WHITE


func connect_peg_signals(peg):
	pass