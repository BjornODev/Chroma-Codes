extends CanvasLayer

@onready var money_label = $HUDRoot/MoneyLabel
@onready var health_text = $HUDRoot/HealthText

func _ready():
	health_text.initialize()
	RunProgressionManager.connect("health_changed", _on_health_changed)
	RunProgressionManager.connect("dollars_changed", _on_dollars_changed)
	_on_health_changed(RunProgressionManager.player_health)
	_on_dollars_changed(RunProgressionManager.dollars)

func _on_health_changed(new_amount: int):
	health_text.change_health(new_amount)


func _on_dollars_changed(new_amount: int):
	money_label.text = "$%d" % new_amount
	money_label.add_theme_color_override("font_color", Color("#FFD700"))
