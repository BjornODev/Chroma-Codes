extends Node2D

# =========================
# MAP COMPLETE SCREEN
# Plays out the end-of-map quota settlement.
#
# Layout:
#   - Score peg totals: vertical, LEFT
#   - Board-visited / multiplier indicator: vertical, CENTER
#   - Peg stack (hand) display: horizontal, BOTTOM
#   - Quota displays: vertical, RIGHT
#
# Sequence:
#   1. Iris opens.
#   2. The full settlement is computed up front (QuotaSettlement).
#   3. After SETTLE_DELAY seconds, the event timeline is replayed as animation:
#      score pegs fly from the left totals, pass THROUGH the lit multiplier slot
#      (splitting into <multiplier> flyers), then fly to the right quota indicator,
#      ticking it down by 1 per flyer. When score pegs run out, hand pegs fly from
#      the bottom (no split); emptying a hand color costs 1 HP and refills to 10.
#   4. On completion: quota met -> advance to next map; HP 0 -> game over.
# =========================

const SETTLE_DELAY := 3.0
const PEG_COLORS := {
	"red": Color("#FF0000"),
	"yellow": Color("#FFF200"),
	"green": Color("#3BB143"),
	"white": Color("#FFFFFF"),
	"purple": Color("#8F00FF"),
	"orange": Color("#ED7117"),
}
const COLORS_ORDER := ["red", "yellow", "green", "white", "purple", "orange"]
const COLOR_TO_PEG_ID := {
	"red": 1, "yellow": 2, "green": 3, "white": 4, "purple": 5, "orange": 6,
}

# Animation timing
const SCORE_FLIGHT_TIME := 0.4      # left total -> multiplier slot
const QUOTA_FLIGHT_TIME := 0.4      # multiplier slot -> quota indicator
const EVENT_STAGGER := 0.04         # gap between consecutive settlement events (stream pacing)
const PEG_SIZE := 90.0              # much larger flight pegs
const WOBBLE_AMP := 85.0            # perpendicular wobble amplitude (pixels) — higher = wider swings
const WOBBLE_FREQ := 6.0            # number of wobble oscillations across the path — higher = more wiggles

@onready var iris_wipe = $IrisWipe
@onready var score_total_display = $ScoreTotalDisplay      # left, vertical
@onready var multiplier_display = $MultiplierDisplay        # center, vertical
@onready var peg_stack_display = $PegStackDisplay           # bottom, horizontal
@onready var quota_display = $QuotaDisplay                  # right, vertical
@onready var health_text = $HUDLayer/HUDRoot/HealthText
@onready var background_layer = $BackgroundLayer

var _settlement: QuotaSettlement
var _flight_layer: Node2D
var _peg_texture: Texture2D
var _debug: SettlementDebug

# Live (animated) values the displays read while replaying
var live_quotas: Dictionary = {}
var live_score_pegs: Dictionary = {}
var live_hand_pegs: Dictionary = {}

# Overlay state
var _overlay_label: Label
var _current_event_index := 0


func _ready():
	_peg_texture = preload("res://assets/pegs/peg_out.svg")

	# Debug: write any override values into the real managers BEFORE anything
	# reads them, so the screen runs exactly as normal play would.
	SettlementDebug.apply_overrides()

	_flight_layer = Node2D.new()
	add_child(_flight_layer)

	# Debug toolkit
	_debug = SettlementDebug.new()
	add_child(_debug)

	background_layer.change_background(RunProgressionManager.map_offset)

	AudioManager.play_screen_music("Synthwave_2")

	# Gather the current manager values (overrides, if any, are already applied)
	var inputs = SettlementDebug.gather_inputs()

	# Snapshot starting state for the live displays
	# Score pegs and hand pegs cover all six colors; quotas cover only the
	# colors that actually have a quota this map (so the quota display shows
	# only those).
	for c in COLORS_ORDER:
		live_score_pegs[c] = inputs["score_pegs"].get(c, 0)
		live_hand_pegs[c] = inputs["hand_pegs"].get(c, 0)
	live_quotas = {}
	for c in inputs["quotas"].keys():
		live_quotas[c] = inputs["quotas"][c]

	# Compute the full settlement up front
	_settlement = QuotaSettlement.new()
	_settlement.compute(
		inputs["quotas"],
		inputs["multipliers"],
		inputs["score_pegs"],
		inputs["hand_pegs"],
		inputs["hp"]
	)

	# Dump the full calculation report before any animation
	SettlementDebug.dump_settlement(inputs, _settlement)

	_init_displays()
	_setup_overlay()

	# DEBUG: confirm what the quota display received
	print("[MapComplete] OVERRIDE_QUOTAS const = ", SettlementDebug.OVERRIDE_QUOTAS)
	print("[MapComplete] RunProgressionManager.peg_quotas = ", RunProgressionManager.peg_quotas)
	print("[MapComplete] live_quotas (sent to display) = ", live_quotas)

	# Iris opens on the last panel position
	iris_wipe.instant_close()
	await get_tree().create_timer(0.3).timeout
	iris_wipe.iris_open(MapManager.last_panel_world_pos if MapManager.last_panel_world_pos != Vector2.ZERO else get_viewport().get_visible_rect().size / 2.0)

	await get_tree().create_timer(_debug.get_delay()).timeout
	await _play_settlement()
	await _finish()


func _init_displays():
	# Rebuild the peg stack so it reflects the (possibly overridden) hand counts,
	# since its own _ready ran before apply_overrides.
	if peg_stack_display and peg_stack_display.has_method("rebuild"):
		peg_stack_display.rebuild()
	if score_total_display and score_total_display.has_method("set_live_source"):
		score_total_display.set_live_source(live_score_pegs)
	if quota_display and quota_display.has_method("set_live_source"):
		quota_display.set_live_source(live_quotas)
	if multiplier_display and multiplier_display.has_method("refresh"):
		multiplier_display.refresh()
	if health_text:
		health_text.initialize()
		health_text.change_health(RunProgressionManager.player_health)


# =========================
# SETTLEMENT PLAYBACK
# Replays the precomputed event timeline as animation.
# =========================

func _play_settlement():
	_current_event_index = 0

	for event in _settlement.events:
		# Pause handling
		while _debug != null and _debug._paused:
			await get_tree().process_frame

		# Step mode: wait for keypress before each event
		if _debug != null:
			await _debug.await_step(get_tree())

		if _debug != null and SettlementDebug.VERBOSE_EVENTS:
			print("[Settlement] event %d: %s" % [_current_event_index, SettlementDebug._format_event(event)])

		_update_overlay(event)

		match event.get("type", ""):
			"score":
				await _play_score_event(event)
			"hand":
				await _play_hand_event(event)
			"damage":
				await _play_damage_event(event)
			"dead":
				break
		_current_event_index += 1
		await get_tree().create_timer(_scaled(EVENT_STAGGER)).timeout

	_update_overlay_done()

	# The last events fired their flyers without awaiting them, so give the final
	# pegs time to finish landing before committing and navigating.
	await get_tree().create_timer(_scaled(QUOTA_FLIGHT_TIME) + 0.2).timeout



func _scaled(t: float) -> float:
	if _debug != null:
		return _debug.scaled(t)
	return t


func _play_score_event(event: Dictionary):
	var color: String = event["color"]
	var flyers: int = event["flyers"]
	var ticks: int = event["ticks"]

	# Decrement the live score total now (peg leaves the left display)
	live_score_pegs[color] = max(0, live_score_pegs.get(color, 0) - 1)
	_redraw_score_total()

	var from_pos = _score_total_screen_pos(color)
	var mult_pos = _multiplier_screen_pos(color)
	var quota_pos = _quota_screen_pos(color)

	# Fly source -> multiplier; when it arrives, split into <flyers> heading to
	# the quota. This whole chain runs on its own (NOT awaited) so the next peg
	# can launch immediately, producing a continuous stream.
	_fly_peg_then(color, from_pos, mult_pos, _scaled(SCORE_FLIGHT_TIME), func():
		for i in range(flyers):
			var offset = Vector2((i - (flyers - 1) / 2.0) * 30.0, 0)
			var counts = i < ticks
			_launch_split_flyer(color, mult_pos + offset, quota_pos, counts, i == flyers - 1)
	)

	# Only wait the short stagger before the next event fires — this is what makes
	# the pegs pour out like a stream instead of one-at-a-time.
	await get_tree().create_timer(_scaled(EVENT_STAGGER)).timeout


func _play_hand_event(event: Dictionary):
	var color: String = event["color"]

	# Decrement the live hand count (peg leaves the bottom display)
	live_hand_pegs[color] = max(0, live_hand_pegs.get(color, 0) - 1)
	_redraw_hand_stack(color)

	var from_pos = _hand_stack_screen_pos(color)
	var quota_pos = _quota_screen_pos(color)
	# Fire-and-forget: ticks the quota down on arrival, doesn't block the stream.
	_fly_peg(color, from_pos, quota_pos, _scaled(QUOTA_FLIGHT_TIME), true)

	await get_tree().create_timer(_scaled(EVENT_STAGGER)).timeout


func _play_damage_event(event: Dictionary):
	var color: String = event["color"]
	var new_hp: int = event["hp"]
	_hp_during_playback = new_hp

	# Let any hand pegs still streaming toward the quota finish landing before we
	# snap the counter back up to a full refill.
	await get_tree().create_timer(_scaled(QUOTA_FLIGHT_TIME)).timeout

	# Refill the hand color to 10 and apply damage
	live_hand_pegs[color] = QuotaSettlement.HAND_REFILL
	_redraw_hand_stack(color)

	if health_text:
		health_text.change_health(new_hp)
	# Flash / feedback could go here
	AudioManager.play_sound("damage")
	await get_tree().create_timer(_scaled(0.25)).timeout


# =========================
# FLYERS
# =========================

# A single peg flying from -> to (fire-and-forget) with a wobbling path. If it
# counts toward the quota, ticks on arrival. Does not block the stream.
func _fly_peg(color: String, from_pos: Vector2, to_pos: Vector2, duration: float, ticks_quota := false):
	var inv = _flight_layer.get_global_transform_with_canvas().affine_inverse()
	var local_from = inv * from_pos
	var local_to = inv * to_pos
	_spawn_wobble_flyer(color, local_from, local_to, duration, func():
		if ticks_quota:
			_tick_quota_down(color)
	)


# Fly a peg from -> to with wobble, then run on_arrive when it lands.
func _fly_peg_then(color: String, from_pos: Vector2, to_pos: Vector2, duration: float, on_arrive: Callable):
	var inv = _flight_layer.get_global_transform_with_canvas().affine_inverse()
	var local_from = inv * from_pos
	var local_to = inv * to_pos
	_spawn_wobble_flyer(color, local_from, local_to, duration, on_arrive)


# Core wobbling flyer: animates a 0->1 progress and positions the sprite along an
# eased path with a perpendicular sine wobble that tapers to zero on arrival.
func _spawn_wobble_flyer(color: String, local_from: Vector2, local_to: Vector2, duration: float, on_arrive: Callable):
	var flyer = _make_flyer(color)
	flyer.position = local_from
	_flight_layer.add_child(flyer)

	var tween = create_tween()
	tween.tween_method(
		_wobble_step.bind(flyer, local_from, local_to),
		0.0, 1.0, duration
	)
	tween.finished.connect(func():
		if is_instance_valid(flyer):
			flyer.queue_free()
		if on_arrive.is_valid():
			on_arrive.call()
	)


func _wobble_step(t: float, flyer: Sprite2D, from_pos: Vector2, to_pos: Vector2):
	if not is_instance_valid(flyer):
		return
	# Ease-in cubic: slow start, fast finish
	var eased = t * t * t
	var base = from_pos.lerp(to_pos, eased)

	var dir = to_pos - from_pos
	if dir.length() > 0.001:
		var perp = Vector2(-dir.y, dir.x).normalized()
		var amp = WOBBLE_AMP * (1.0 - t)              # taper to 0 on arrival
		var wob = sin(t * PI * WOBBLE_FREQ) * amp
		base += perp * wob

	flyer.position = base


# Split flyer: travels multiplier slot -> quota with wobble; ticks quota on
# arrival if it counts.
func _launch_split_flyer(color: String, from_pos: Vector2, to_pos: Vector2, counts: bool, _is_last: bool):
	var inv = _flight_layer.get_global_transform_with_canvas().affine_inverse()
	var local_from = inv * from_pos
	var local_to = inv * to_pos
	_spawn_wobble_flyer(color, local_from, local_to, _scaled(QUOTA_FLIGHT_TIME), func():
		if counts:
			_tick_quota_down(color)
	)


func _make_flyer(color: String) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = _peg_texture
	s.modulate = PEG_COLORS.get(color, Color.WHITE)
	var scl = PEG_SIZE / float(_peg_texture.get_width())
	s.scale = Vector2(scl, scl)
	return s


func _tick_quota_down(color: String):
	live_quotas[color] = max(0, live_quotas.get(color, 0) - 1)
	_redraw_quota()


# =========================
# DISPLAY REDRAW HOOKS
# =========================

func _redraw_score_total():
	if score_total_display and score_total_display.has_method("queue_redraw"):
		score_total_display.queue_redraw()


func _redraw_quota():
	if quota_display and quota_display.has_method("queue_redraw"):
		quota_display.queue_redraw()


func _redraw_hand_stack(color: String):
	if peg_stack_display == null:
		return
	# Update the matching stack peg's counter text
	if "stack_pegs" in peg_stack_display:
		var pid = COLOR_TO_PEG_ID[color]
		for peg in peg_stack_display.stack_pegs:
			if is_instance_valid(peg) and "peg_id" in peg and peg.peg_id == pid:
				if "counter" in peg and peg.counter:
					peg.counter.text = str(live_hand_pegs.get(color, 0))
				break


# =========================
# SCREEN POSITION LOOKUPS
# These ask each display where a given color sits, so flyers aim correctly.
# =========================

func _score_total_screen_pos(color: String) -> Vector2:
	if score_total_display and score_total_display.has_method("get_color_screen_pos"):
		return score_total_display.get_color_screen_pos(color)
	return Vector2(120, get_viewport().get_visible_rect().size.y / 2.0)


func _multiplier_screen_pos(color: String) -> Vector2:
	if multiplier_display and multiplier_display.has_method("get_color_screen_pos"):
		return multiplier_display.get_color_screen_pos(color)
	return get_viewport().get_visible_rect().size / 2.0


func _quota_screen_pos(color: String) -> Vector2:
	if quota_display and quota_display.has_method("get_color_screen_pos"):
		return quota_display.get_color_screen_pos(color)
	var s = get_viewport().get_visible_rect().size
	return Vector2(s.x - 120, s.y / 2.0)


func _hand_stack_screen_pos(color: String) -> Vector2:
	if peg_stack_display and "stack_pegs" in peg_stack_display:
		var pid = COLOR_TO_PEG_ID[color]
		for peg in peg_stack_display.stack_pegs:
			if is_instance_valid(peg) and "peg_id" in peg and peg.peg_id == pid:
				return peg.global_position
	var s = get_viewport().get_visible_rect().size
	return Vector2(s.x / 2.0, s.y - 80)


# =========================
# DEBUG OVERLAY
# On-screen live readout of settlement state during playback.
# =========================

func _setup_overlay():
	if _debug == null or not SettlementDebug.SHOW_OVERLAY or not SettlementDebug.DEBUG_ENABLED:
		return
	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_overlay_label = Label.new()
	_overlay_label.position = Vector2(20, 20)
	_overlay_label.add_theme_font_size_override("font_size", 22)
	_overlay_label.add_theme_color_override("font_color", Color("#00FF66"))
	_overlay_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_overlay_label)
	_update_overlay({})


func _update_overlay(current_event: Dictionary):
	if _overlay_label == null:
		return
	var lines := []
	lines.append("=== SETTLEMENT DEBUG ===")
	lines.append("event %d / %d" % [_current_event_index, _settlement.events.size()])
	if not current_event.is_empty():
		lines.append("now: " + SettlementDebug._format_event(current_event))
	lines.append("")
	lines.append("QUOTAS (remaining):")
	for c in COLORS_ORDER:
		if live_quotas.has(c):
			lines.append("  %-7s %d" % [c, live_quotas.get(c, 0)])
	lines.append("SCORE PEGS:")
	for c in COLORS_ORDER:
		if live_score_pegs.get(c, 0) > 0 or live_quotas.has(c):
			lines.append("  %-7s %d" % [c, live_score_pegs.get(c, 0)])
	lines.append("HAND PEGS:")
	for c in COLORS_ORDER:
		lines.append("  %-7s %d" % [c, live_hand_pegs.get(c, 0)])
	lines.append("")
	lines.append("HP: %d   predicted final HP: %d" % [_current_hp(), _settlement.final_hp])
	lines.append("predicted: %s" % ("WIN" if _settlement.quota_met else ("DEAD" if not _settlement.alive else "?")))
	if SettlementDebug.STEP_MODE:
		lines.append("")
		lines.append("[STEP MODE] press SPACE to advance")
	lines.append("[P] pause/resume")
	_overlay_label.text = "\n".join(lines)


var _hp_during_playback := -999

func _current_hp() -> int:
	if _hp_during_playback == -999:
		return RunProgressionManager.player_health
	return _hp_during_playback


func _update_overlay_done():
	if _overlay_label == null:
		return
	_overlay_label.text += "\n\n=== SETTLEMENT COMPLETE ==="


# =========================
# RESOLUTION
# =========================

func _finish():
	# Commit the computed final state to the managers
	RunProgressionManager.peg_quotas = _settlement.final_quotas
	RunProgressionManager.set_health(_settlement.final_hp)
	ScoreManager.earned_score_pegs = _settlement.final_score_pegs
	for c in COLORS_ORDER:
		PegInventoryManager.set_count(COLOR_TO_PEG_ID[c], _settlement.final_hand_pegs.get(c, 0))

	await get_tree().create_timer(0.6).timeout

	# In debug, hold on the finished screen for a moment so you can read the
	# final state in the overlay before it auto-advances.
	if _debug != null and SettlementDebug.DEBUG_ENABLED:
		await get_tree().create_timer(SettlementDebug.FINISH_HOLD).timeout

	if not _settlement.alive:
		_game_over()
	elif _settlement.quota_met:
		_advance_to_next_map()
	else:
		# Quota not met but still alive — shouldn't happen given the rules,
		# but fall back to game over to be safe.
		_game_over()


func _advance_to_next_map():
	RunProgressionManager.advance_to_next_map()
	RunProgressionManager.first_time_on_map = true
	MapManager.reset_map()
	iris_wipe.iris_close(get_viewport().get_visible_rect().size / 2.0)
	await iris_wipe.closed
	get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")


func _game_over():
	PopUpText.show_popup("[center][b][color=#FF073A] YOU LOSE [/color][/b][/center]")
	AudioManager.play_sound("lose")
	await get_tree().create_timer(3.0).timeout
	RunProgressionManager.end_run()
	get_tree().change_scene_to_file("res://scenes/RunSetupScreen.tscn")