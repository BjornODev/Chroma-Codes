extends CanvasLayer

@onready var label = $RichTextLabel
@onready var mult_label = $MultiplierText

var queue := []
var showing := false

func _ready() -> void:
	label.visible = false

func show_popup(text: String):
	queue.append(text)
	if not showing:
		_process_queue()

func _process_queue():
	if queue.is_empty():
		showing = false
		return
	
	showing = true
	
	var text = queue.pop_front()
	await _animate_popup(text)
	_process_queue()

func _animate_popup(text: String):
	AudioLoader.play_sound("popup")
	label.visible = true
	label.modulate = Color(1,1,1,0)
#	label.scale = Vector2(0.6, 0.6)
	label.clear()
	label.append_text(text)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(label, "modulate:a", 0.85, 0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
#	tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.25)

	await tween.finished
	await get_tree().create_timer(1.5).timeout

	var fade = create_tween()
	fade.tween_property(label, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await fade.finished
	label.visible = false


func mult_increase(amount):
	mult_label.text = "Multiplier: " + str(amount) + "x"