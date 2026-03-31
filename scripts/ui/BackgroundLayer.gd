extends CanvasLayer

@onready var bg_rect = $BGRect

# -----------------------------------------------
# EASY TWEAK ZONE — baseline ranges for randomization
# -----------------------------------------------
const AMPLITUDE_RANGE := Vector2(0.02, 0.08)
const FREQUENCY_RANGE := Vector2(4.0, 16.0)
const SPEED_RANGE := Vector2(0.8, 3.0)
const SCROLL_SPEED_RANGE := Vector2(0.02, 0.1)
const BLOB_SCALE_RANGE := Vector2(0.7, 1.4)
const BLOB_COUNT_RANGE := Vector2i(8, 15)
# -----------------------------------------------


func change_background(panel_type: String):
	var mat = bg_rect.material as ShaderMaterial
	if not mat:
		push_error("BGRect has no ShaderMaterial")
		return

	var run_seed = MapManager.run_seed
	var board_index = RunProgressionManager.boards_cleared

	var offsets := {
		"Board": randi(), "Shop": randi(), "Event": randi(),
		"Forge": randi(), "Gamble": randi(), "Map": randi(), "Boss": randi()
	}
	var offset = offsets.get(panel_type, 0)
	var final_seed = run_seed + offset + board_index

	var rng = RandomNumberGenerator.new()
	rng.seed = final_seed
	var scroll_dir = _rand_range(rng, Vector2(0.5, 0.75))
	mat.set_shader_parameter("seed", float(final_seed))

	# All animation parameters derived from seed
	mat.set_shader_parameter("amplitude", _rand_range(rng, AMPLITUDE_RANGE))
	mat.set_shader_parameter("frequency", _rand_range(rng, FREQUENCY_RANGE))
	mat.set_shader_parameter("speed", _rand_range(rng, SPEED_RANGE))
	mat.set_shader_parameter("scrolling_speed", _rand_range(rng, SCROLL_SPEED_RANGE))
	mat.set_shader_parameter("blob_scale", _rand_range(rng, BLOB_SCALE_RANGE))
	mat.set_shader_parameter("blob_count", rng.randi_range(BLOB_COUNT_RANGE.x, BLOB_COUNT_RANGE.y))
	mat.set_shader_parameter("Scroll Direction", Vector2(scroll_dir, scroll_dir))

	# Scroll direction — random angle
	var angle = rng.randf() * TAU
	var scroll_mag = _rand_range(rng, Vector2(0.05, 0.2))
	mat.set_shader_parameter("scroll_direction", Vector2(cos(angle), sin(angle)) * scroll_mag)

	_apply_palette(mat, rng)


func _apply_palette(mat: ShaderMaterial, rng: RandomNumberGenerator):
	var strategy = rng.randi() % 3
	var colors: Array[Color] = []

	match strategy:
		0: colors = _analogous(rng)
		1: colors = _complementary(rng)
		_: colors = _triadic(rng)

	mat.set_shader_parameter("color_a", colors[0])
	mat.set_shader_parameter("color_b", colors[1])
	mat.set_shader_parameter("color_c", colors[2])
	mat.set_shader_parameter("color_d", colors[3])
	mat.set_shader_parameter("color_e", colors[4])


func _rand_range(rng: RandomNumberGenerator, range: Vector2) -> float:
	return rng.randf_range(range.x, range.y)


func _analogous(rng: RandomNumberGenerator) -> Array[Color]:
	var base = rng.randf()
	var spread = rng.randf_range(0.04, 0.15)
	var colors: Array[Color] = []
	for i in range(5):
		var hue = fmod(base + i * spread, 1.0)
		colors.append(Color.from_hsv(hue, rng.randf_range(0.7, 1.0), rng.randf_range(0.6, 1.0)))
	return colors


func _complementary(rng: RandomNumberGenerator) -> Array[Color]:
	var base = rng.randf()
	var comp = fmod(base + 0.5, 1.0)
	var hues = [
		base,
		fmod(base + rng.randf_range(0.04, 0.1), 1.0),
		fmod(base + rng.randf_range(0.2, 0.3), 1.0),
		comp,
		fmod(comp + rng.randf_range(0.04, 0.1), 1.0),
	]
	var colors: Array[Color] = []
	for hue in hues:
		colors.append(Color.from_hsv(hue, rng.randf_range(0.75, 1.0), rng.randf_range(0.6, 1.0)))
	return colors


func _triadic(rng: RandomNumberGenerator) -> Array[Color]:
	var base = rng.randf()
	var hues = [
		base,
		fmod(base + rng.randf_range(0.04, 0.08), 1.0),
		fmod(base + rng.randf_range(0.28, 0.38), 1.0),
		fmod(base + rng.randf_range(0.36, 0.46), 1.0),
		fmod(base + rng.randf_range(0.62, 0.72), 1.0),
	]
	var colors: Array[Color] = []
	for hue in hues:
		colors.append(Color.from_hsv(hue, rng.randf_range(0.75, 1.0), rng.randf_range(0.6, 1.0)))
	return colors