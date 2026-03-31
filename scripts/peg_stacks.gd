extends Node2D

@export var peg_id : int
@export var peg_scene : PackedScene

var peg_manager_reference

var peg_database = preload("res://scripts/basics/peg_data.gd")

func _ready():
	modulate = Color(peg_database.PEG_TYPES[peg_id][0])
	$Area2D.input_pickable = true
	$Area2D.connect("input_event", _on_input_event)
	peg_manager_reference = $PegManager


func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		peg_manager_reference.start_drag(self)

func spawn_peg():
	var peg = peg_scene.instantiate()
	peg.peg_id = peg_id
	return peg