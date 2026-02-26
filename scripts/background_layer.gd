extends CanvasLayer

@onready var bg = $Background
@onready var solid_bg = $"../BackgroundLayer/BackgroundBehind"
var bg_list = [0, 1, 2, 3]
var cur_bg = 0

#func _process(delta: float) -> void:
#	if Input.is_action_just_pressed("ui_select"):
#		cur_bg += 1
#		if cur_bg > bg_list.size() - 1:
#			cur_bg = 0
#		change_background(cur_bg)


func change_background(index):
	bg.texture = load("res://assets/backgrounds/background_image_" + str(index) + ".jpg")
	solid_bg.texture = load("res://assets/backgrounds/background_image_" + str(index) + ".jpg")