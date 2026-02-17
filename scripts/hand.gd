extends HBoxContainer


@export var peg_scene: PackedScene
@export var peg_variations := 6
var hand_size := 6
var bag := []

func _ready():
	build_bag()
	draw_hand()

func build_bag():
	bag.clear()
	for color in range(6):
		for i in range(15):
			bag.append(color)
	bag.shuffle()
	print(bag)

func draw_hand():
	while get_child_count() < hand_size and bag.size() > 0:
		var peg = peg_scene.instantiate()
		peg.set_color(bag.pop_back())
		add_child(peg)

