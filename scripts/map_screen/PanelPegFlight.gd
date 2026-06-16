extends Node2D
class_name PanelPegFlight

# =========================
# PANEL PEG FLIGHT
# On board load, animates the colored pegs gained from the activated panel
# flying from the panel's world position into the matching-color hand pegs,
# ticking their counters up as they land.
#
# Usage (from BoardManager, after the hand is populated):
#   var flight = preload("res://scripts/PanelPegFlight.gd").new()
#   add_child(flight)
#   flight.play(hand_reference, origin_world_pos)
# =========================

const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}

const COLOR_TO_PEG_ID := {
	"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6,
}

const FLIGHT_DURATION := 0.6
const WOBBLE_AMP := 24.0
const WOBBLE_FREQ := 2.0
const STAGGER := 0.07
const PEG_SIZE := 34.0

var _hand = null
var _peg_texture: Texture2D


func play(hand_reference, origin_world_pos: Vector2):
	_hand = hand_reference
	_peg_texture = preload("res://assets/pegs/peg_out.svg")

	var refills = MapManager.last_refill_by_color.duplicate()
	MapManager.last_refill_by_color = {}   # consume so it won't replay

	if refills.is_empty():
		queue_free()
		return

	# For each color, set the hand peg's displayed counter back by the refill
	# amount, then tick it up as each flyer lands.
	var total_flyers := 0
	for color_name in refills.keys():
		var amount = refills[color_name]
		if amount <= 0:
			continue
		var peg_node = _find_hand_peg(COLOR_TO_PEG_ID.get(color_name, -1))
		if peg_node == null:
			continue

		# Roll the displayed counter back so the flight animates the gain
		_set_peg_counter_offset(peg_node, -amount)

		for p in range(amount):
			var delay = total_flyers * STAGGER
			_launch_delayed(color_name, origin_world_pos, peg_node, delay)
			total_flyers += 1

	# Clean up after the last flyer would have landed
	var lifetime = total_flyers * STAGGER + FLIGHT_DURATION + 0.5
	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


func _find_hand_peg(peg_id: int):
	if peg_id < 0 or _hand == null:
		return null
	for peg in _hand.player_hand:
		if "is_special" in peg and peg.is_special:
			continue
		if "peg_id" in peg and peg.peg_id == peg_id:
			return peg
	return null


# Adjust the visible counter on a hand peg by delta (negative to roll back).
func _set_peg_counter_offset(peg_node, delta: int):
	if not ("counter" in peg_node) or peg_node.counter == null:
		return
	var current = PegInventoryManager.get_count(peg_node.peg_id)
	var shown = current + delta
	peg_node.counter.text = str(max(0, shown))


func _bump_peg_counter(peg_node):
	if not ("counter" in peg_node) or peg_node.counter == null:
		return
	var shown = int(str(peg_node.counter.text)) if str(peg_node.counter.text).is_valid_int() else 0
	shown += 1
	peg_node.counter.text = str(shown)
	# Little pop on the peg
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	peg_node.scale = Vector2(1.25, 1.25)
	tween.tween_property(peg_node, "scale", Vector2.ONE, 0.18)


func _launch_delayed(color_name: String, origin: Vector2, peg_node, delay: float):
	if delay <= 0.0:
		_launch(color_name, origin, peg_node)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and is_instance_valid(peg_node):
			_launch(color_name, origin, peg_node)
	)


func _launch(color_name: String, origin: Vector2, peg_node):
	var flyer = _Flyer.new()
	add_child(flyer)
	var target = peg_node.global_position
	flyer.setup(_peg_texture, PEG_COLORS.get(color_name, Color.WHITE), origin, target,
		PEG_SIZE / float(_peg_texture.get_width()),
		func():
			if is_instance_valid(peg_node):
				_bump_peg_counter(peg_node)
	)


# Inner flyer node — peg sprite with eased + wobbling flight in global space.
class _Flyer extends Node2D:
	var start_pos: Vector2
	var end_pos: Vector2
	var _sprite: Sprite2D
	var _on_arrive: Callable
	var _t := 0.0
	var _flying := false

	func setup(tex: Texture2D, color: Color, from_pos: Vector2, to_pos: Vector2, scl: float, on_arrive: Callable):
		start_pos = from_pos
		end_pos = to_pos
		_on_arrive = on_arrive
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.modulate = color
		_sprite.scale = Vector2(scl, scl)
		add_child(_sprite)
		global_position = start_pos
		_flying = true

	func _process(delta):
		if not _flying:
			return
		_t += delta / 0.6
		if _t >= 1.0:
			_flying = false
			global_position = end_pos
			if _on_arrive.is_valid():
				_on_arrive.call()
			queue_free()
			return
		global_position = _path(_t)

	func _path(raw_t: float) -> Vector2:
		var eased = raw_t * raw_t * raw_t
		var base = start_pos.lerp(end_pos, eased)
		var dir = end_pos - start_pos
		if dir.length() < 0.001:
			return base
		var perp = Vector2(-dir.y, dir.x).normalized()
		var amp = 24.0 * (1.0 - raw_t)
		var wob = sin(raw_t * PI * 2.0) * amp
		return base + perp * wob