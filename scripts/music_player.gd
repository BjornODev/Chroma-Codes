extends Node

var sound_library := {}


func _ready():
	sound_library = {
		"peg_snap": preload("res://sounds/sfx/PegSnap.wav"),
		"popup": preload("res://sounds/sfx/Popup.wav"),
		"damage": preload("res://sounds/sfx/Damage.wav"),
		"obscure": preload("res://sounds/sfx/Obscure.wav"),
		"select": preload("res://sounds/sfx/Select.wav"),
		"win": preload("res://sounds/sfx/Win.wav"),
		"lose": preload("res://sounds/sfx/Lose.wav"),
		"reveal": preload("res://sounds/sfx/Reveal.wav"),
		"goop": preload("res://sounds/sfx/Goop.wav")
	}


func play_sound(name: String, db: float = 0.0):
	name = name.to_lower()

	if not sound_library.has(name):
		push_warning("Sound not found: " + name)
		return

	var player := AudioStreamPlayer.new()
	player.stream = sound_library[name]
	player.volume_db = db

	add_child(player)

	player.finished.connect(func():
		player.queue_free()
	)

	player.play()