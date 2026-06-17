extends Node2D
class_name MapPanelPegFlight

# =========================
# MAP PANEL PEG FLIGHT
# When a panel is activated on the map, the pegs it grants fly from the panel's
# position down to the matching-color peg in the PegStackDisplay, ticking each
# mushroom counter up as they land.
#
# Usage (from MapScreen, right after activate_panel):
#   var flight = preload("res://scripts/MapPanelPegFlight.gd").new()
#   add_child(flight)
#   flight.play(peg_stack_display, panel_global_pos)
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

const FLIGHT_DURATION := 0.5
const WOBBLE_AMP := 24.0
const WOBBLE_FREQ := 2.0
const STAGGER := 0.075
const PEG_SIZE := 60.0
const SHUFFLE_PITCH_RAND := 0.05

var _stack_display = null
var _peg_texture: Texture2D


func play(peg_stack_display, origin_global_pos: Vector2):
	_stack_display = peg_stack_display
	_peg_texture = preload("res://assets/pegs/peg_out.svg")

	var refills = MapManager.last_refill_by_color.duplicate()
	MapManager.last_refill_by_color = {}   # consume so it won't replay

	if refills.is_empty() or _stack_display == null:
		queue_free()
		return

	# Tell the stack display to stop auto-animating its counters for these colors,
	# since the flight will drive the tick-up as pegs land.
	if _stack_display.has_method("suppress_color"):
		for color_name in refills.keys():
			_stack_display.suppress_color(COLOR_TO_PEG_ID.get(color_name, -1))

	var total_flyers := 0
	for color_name in refills.keys():
		var amount = refills[color_name]
		if amount <= 0:
			continue
		var peg_node = _find_stack_peg(COLOR_TO_PEG_ID.get(color_name, -1))
		if peg_node == null:
			continue

		# Roll the displayed counter back by the refill so the flight animates the gain
		_set_counter_offset(peg_node, -amount)

		for p in range(amount):
			var delay = total_flyers * STAGGER
			_launch_delayed(color_name, origin_global_pos, peg_node, delay)
			total_flyers += 1

	var lifetime = total_flyers * STAGGER + FLIGHT_DURATION + 0.5
	get_tree().create_timer(lifetime).timeout.connect(func():
		# Re-enable auto-animation for those colors
		if _stack_display != null and _stack_display.has_method("unsuppress_all"):
			_stack_display.unsuppress_all()
		if is_instance_valid(self):
			queue_free()
	)


func _find_stack_peg(peg_id: int):
	if peg_id < 0 or _stack_display == null:
		return null
	if not ("stack_pegs" in _stack_display):
		return null
	for peg in _stack_display.stack_pegs:
		if is_instance_valid(peg) and "peg_id" in peg and peg.peg_id == peg_id:
			return peg
	return null


# Roll a stack peg's visible counter by delta (negative to roll back).
func _set_counter_offset(peg_node, delta: int):
	if not ("counter" in peg_node) or peg_node.counter == null:
		return
	var current = PegInventoryManager.get_count(peg_node.peg_id)
	peg_node.counter.text = str(max(0, current + delta))


func _bump_counter(peg_node):
	if not ("counter" in peg_node) or peg_node.counter == null:
		return
	var shown = 0
	if str(peg_node.counter.text).is_valid_int():
		shown = int(str(peg_node.counter.text))
	shown += 1
	peg_node.counter.text = str(shown)
	# Restore full color once pegs start arriving
	if shown > 0:
		peg_node.modulate = Color.WHITE
	# Pulse the peg: grow then ease back, matching the score peg system.
	_pulse_peg(peg_node)


const PULSE_SCALE := 1.45
const PULSE_RETURN_TIME := 0.45

func _pulse_peg(peg_node):
	if not is_instance_valid(peg_node):
		return
	# Kill any in-flight pulse on this peg so rapid landings don't stack
	if peg_node.has_meta("_pulse_tween"):
		var prev = peg_node.get_meta("_pulse_tween")
		if prev != null and prev.is_valid():
			prev.kill()
	peg_node.scale = Vector2(PULSE_SCALE, PULSE_SCALE)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(peg_node, "scale", Vector2.ONE, PULSE_RETURN_TIME)
	peg_node.set_meta("_pulse_tween", tween)


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
	# Each flying peg plays the Shuffle sound with slight pitch variation.
	AudioManager.play_sound("Shuffle", 0.0, 1.0, SHUFFLE_PITCH_RAND)
	var target = peg_node.global_position
	flyer.setup(_peg_texture, PEG_COLORS.get(color_name, Color.WHITE), origin, target,
		PEG_SIZE / float(_peg_texture.get_width()),
		func():
			if is_instance_valid(peg_node):
				_bump_counter(peg_node)
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
		_t += delta / 0.5
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