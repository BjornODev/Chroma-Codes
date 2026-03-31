extends Node

# =========================
# CONFIGURATION
# =========================

const WIDTH := 1920
const HEIGHT := 1080

# -----------------------------------------------
# EASY TWEAK ZONE
# -----------------------------------------------
const BLOB_FREQUENCY := 2.5       # higher = smaller blobs
const WAVE_FREQUENCY := 1.5       # higher = tighter waves
const BLEND_RATIO := 0.5          # 0.0 = all waves, 1.0 = all blobs
const LAYER_COUNT := 5            # number of color bands
const DOWNSAMPLE := 4             # generate at 1/N res then scale up
const DOMAIN_WARP_STRENGTH := 0.4 # how much to distort the noise (organic blobs)
# -----------------------------------------------

var _rng := RandomNumberGenerator.new()
var _cache := {}


# =========================
# PUBLIC API
# =========================

func get_background(seed_value: int) -> ImageTexture:
	if _cache.has(seed_value):
		return _cache[seed_value]
	var texture = _generate(seed_value)
	_cache[seed_value] = texture
	return texture


func clear_cache():
	_cache.clear()


# =========================
# GENERATION
# =========================

func _generate(seed_value: int) -> ImageTexture:
	_rng.seed = seed_value

	var palette = _generate_palette()

	var w = WIDTH / DOWNSAMPLE
	var h = HEIGHT / DOWNSAMPLE

	# Layer 1 — large sweeping background waves
	var wave1 = FastNoiseLite.new()
	wave1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wave1.frequency = 0.8 / float(w)
	wave1.seed = seed_value
	wave1.fractal_type = FastNoiseLite.FRACTAL_FBM
	wave1.fractal_octaves = 4

	# Layer 2 — medium blobs
	var wave2 = FastNoiseLite.new()
	wave2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wave2.frequency = 1.8 / float(w)
	wave2.seed = seed_value + 1111
	wave2.fractal_type = FastNoiseLite.FRACTAL_FBM
	wave2.fractal_octaves = 3

	# Layer 3 — smaller detail blobs
	var wave3 = FastNoiseLite.new()
	wave3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wave3.frequency = 3.0 / float(w)
	wave3.seed = seed_value + 2222
	wave3.fractal_type = FastNoiseLite.FRACTAL_FBM
	wave3.fractal_octaves = 2

	# Warp noise — smooth large-scale distortion only
	var warp = FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency = 0.6 / float(w)
	warp.seed = seed_value + 3333
	warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp.fractal_octaves = 2

	var output = Image.create(w, h, false, Image.FORMAT_RGBAF)

	for y in range(h):
		for x in range(w):
			# Gentle warp for organic flow
			var wx = warp.get_noise_2d(x, y) * 0.18 * w
			var wy = warp.get_noise_2d(x + w * 2, y + h * 2) * 0.18 * h

			var v1 = (wave1.get_noise_2d(x + wx, y + wy) + 1.0) * 0.5
			var v2 = (wave2.get_noise_2d(x + wx * 0.7, y + wy * 0.7) + 1.0) * 0.5
			var v3 = (wave3.get_noise_2d(x + wx * 0.4, y + wy * 0.4) + 1.0) * 0.5

			# Weighted blend — large waves dominate, detail adds variation
			var combined = v1 * 0.55 + v2 * 0.30 + v3 * 0.15

			# Smooth contrast boost without hard snapping
			combined = _smooth_contrast(combined, 1.6)

			var color = _sample_palette(palette, combined)
			output.set_pixel(x, y, color)

	output.resize(WIDTH, HEIGHT, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(output)


func _smooth_contrast(value: float, strength: float) -> float:
	# Smooth S-curve contrast — pushes toward extremes without hard edges
	var v = clamp(value, 0.0, 1.0)
	# Apply smoothstep multiple times for stronger contrast
	for i in range(int(strength)):
		v = v * v * (3.0 - 2.0 * v)
	# Handle fractional strength
	var frac = strength - int(strength)
	if frac > 0.0:
		var smooth = v * v * (3.0 - 2.0 * v)
		v = lerp(v, smooth, frac)
	return v




func _sharpen(value: float, contrast: float) -> float:
	# Push values toward extremes to create distinct color bands
	var mid = 0.5
	return clamp(mid + (value - mid) * contrast, 0.0, 1.0)


# =========================
# PALETTE GENERATION
# =========================

func _generate_palette() -> Array:
	var strategy = _rng.randi() % 3
	match strategy:
		0: return _analogous_palette()
		1: return _complementary_palette()
		_: return _triadic_palette()


func _analogous_palette() -> Array:
	var base_hue = _rng.randf()
	var palette = []
	for i in range(LAYER_COUNT):
		var t = float(i) / (LAYER_COUNT - 1)
		var hue = fmod(base_hue + t * 0.22, 1.0)
		var sat = lerp(0.8, 1.0, _rng.randf())
		var val = lerp(0.65, 1.0, _rng.randf())
		palette.append(Color.from_hsv(hue, sat, val))
	return palette


func _complementary_palette() -> Array:
	var base_hue = _rng.randf()
	var comp_hue = fmod(base_hue + 0.5, 1.0)
	var palette = []
	var hues = [
		base_hue,
		fmod(base_hue + 0.07, 1.0),
		fmod(base_hue + 0.25, 1.0),
		comp_hue,
		fmod(comp_hue + 0.07, 1.0),
	]
	for hue in hues:
		var sat = lerp(0.8, 1.0, _rng.randf())
		var val = lerp(0.65, 1.0, _rng.randf())
		palette.append(Color.from_hsv(hue, sat, val))
	return palette


func _triadic_palette() -> Array:
	var base_hue = _rng.randf()
	var palette = []
	var hues = [
		base_hue,
		fmod(base_hue + 0.06, 1.0),
		fmod(base_hue + 0.333, 1.0),
		fmod(base_hue + 0.39, 1.0),
		fmod(base_hue + 0.666, 1.0),
	]
	for hue in hues:
		var sat = lerp(0.8, 1.0, _rng.randf())
		var val = lerp(0.65, 1.0, _rng.randf())
		palette.append(Color.from_hsv(hue, sat, val))
	return palette


func _sample_palette(palette: Array, value: float) -> Color:
	var scaled = clamp(value, 0.0, 1.0) * (palette.size() - 1)
	var index = int(scaled)
	var t = scaled - float(index)
	index = clamp(index, 0, palette.size() - 2)
	t = t * t * (3.0 - 2.0 * t)  # smoothstep
	return palette[index].lerp(palette[index + 1], t)
