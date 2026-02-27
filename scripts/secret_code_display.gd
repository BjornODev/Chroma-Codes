extends Node2D

var peg_scene = preload("res://scenes/SecretCodePeg.tscn")
var pegs := []

@export var spacing := 90

func build(secret_code: Array):

	clear()

	for i in range(secret_code.size()):
		var peg = peg_scene.instantiate()
		add_child(peg)

		var total_width = secret_code.size() * spacing
		var start_x = -total_width / 2.0 + spacing / 2.0
		
		peg.position = Vector2(start_x + i * spacing, 0)
		
		peg.set_color_from_id(secret_code[i])
		peg.hide_cover()

		pegs.append(peg)


func reveal_all():
	await get_tree().create_timer(1.5).timeout
	for peg in pegs:
		peg.reveal()


func reveal_index(index):
	if index >= 0 and index < pegs.size():
		pegs[index].reveal()


func clear():
	for peg in pegs:
		peg.queue_free()
	pegs.clear()