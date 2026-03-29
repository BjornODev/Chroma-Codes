extends CanvasLayer

signal closed
signal opened

const SCREEN_DIAGONAL_HALF = 2250.0

@onready var shader_rect = $ShaderRect

var is_animating := false


func _ready():
	visible = false
	if shader_rect and shader_rect.material:
		shader_rect.material = shader_rect.material.duplicate()
		shader_rect.material.set_shader_parameter("screen_size", Vector2(1920.0, 1080.0))
		shader_rect.material.set_shader_parameter("radius", SCREEN_DIAGONAL_HALF)
		shader_rect.material.set_shader_parameter("center", Vector2(0.5, 0.5))


func iris_close(world_pos: Vector2):
	visible = true
	is_animating = true

	var uv_center = world_pos / Vector2(1920.0, 1080.0)
	shader_rect.material.set_shader_parameter("center", uv_center)
	shader_rect.material.set_shader_parameter("radius", SCREEN_DIAGONAL_HALF)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(val): shader_rect.material.set_shader_parameter("radius", val),
		SCREEN_DIAGONAL_HALF,
		0.0,
		1.5
	)
	await tween.finished
	is_animating = false
	emit_signal("closed")


func iris_open(world_pos: Vector2):
	if not shader_rect or not shader_rect.material:
		emit_signal("opened")
		return
	
	visible = true
	is_animating = true

	var uv_center = world_pos / Vector2(1920.0, 1080.0)
	shader_rect.material.set_shader_parameter("center", uv_center)
	shader_rect.material.set_shader_parameter("radius", 0.0)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.05)
	tween.tween_method(
		func(val): shader_rect.material.set_shader_parameter("radius", val),
		0.0,
		SCREEN_DIAGONAL_HALF,
		0.6
	)
	await tween.finished
	is_animating = false
	emit_signal("opened")


func instant_close():
	visible = true
	if not shader_rect or not shader_rect.material:
		return
	shader_rect.material.set_shader_parameter("radius", 0.0)