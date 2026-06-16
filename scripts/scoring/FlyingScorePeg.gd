extends Node2D
class_name FlyingScorePeg

# =========================
# FLYING SCORE PEG
# A peg_out sprite that animates from an origin (a feedback slice) to a target
# (a slot in the ScorePegHUD). Travels along an eased path (slow start, fast end)
# with a perpendicular wobble that tapers to zero on arrival.
# Lives on a CanvasLayer (screen space).
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const FLIGHT_DURATION := 0.7
const WOBBLE_AMP := 30.0
const WOBBLE_FREQ := 2.5  # oscillations across the whole path

var start_pos: Vector2
var end_pos: Vector2
var _sprite: Sprite2D
var _on_arrive: Callable
var _t: float = 0.0
var _flying: bool = false


func setup(color_name: String, from_pos: Vector2, to_pos: Vector2, peg_scale: float, on_arrive: Callable):
	start_pos = from_pos
	end_pos = to_pos
	_on_arrive = on_arrive

	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/pegs/peg_out.svg")
	_sprite.modulate = PEG_COLORS.get(color_name, Color.WHITE)
	_sprite.scale = Vector2(peg_scale, peg_scale)
	add_child(_sprite)

	position = start_pos
	_t = 0.0
	_flying = true


func _process(delta):
	if not _flying:
		return

	_t += delta / FLIGHT_DURATION
	if _t >= 1.0:
		_t = 1.0
		_flying = false
		position = end_pos
		if _on_arrive.is_valid():
			_on_arrive.call()
		queue_free()
		return

	position = _path_position(_t)


func _path_position(raw_t: float) -> Vector2:
	# Ease-in cubic: slow at the start, fast at the end
	var eased = raw_t * raw_t * raw_t

	var base = start_pos.lerp(end_pos, eased)

	# Perpendicular wobble, tapering to zero as raw_t -> 1
	var dir = (end_pos - start_pos)
	if dir.length() < 0.001:
		return base
	var perp = Vector2(-dir.y, dir.x).normalized()
	var amp = WOBBLE_AMP * (1.0 - raw_t)
	var wobble = sin(raw_t * PI * WOBBLE_FREQ) * amp

	return base + perp * wobble