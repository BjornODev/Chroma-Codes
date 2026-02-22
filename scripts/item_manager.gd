extends Node2D


var items = []

func load_items():
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	json.parse(content)
	
	items = json.data