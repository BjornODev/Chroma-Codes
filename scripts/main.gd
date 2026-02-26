extends Node2D


func _ready() -> void:
	var bg_mat = $BackgroundLayer/ColorRect.material
	bg_mat.set_shader_parameter("random_seed", randf() * 1000.0)
	randomize_background(bg_mat)

func randomize_background(mat):
	generate_opposite_palette(mat)
	mat.set_shader_parameter("blob_speed", randf_range(0.6, 1.4))
	mat.set_shader_parameter("blob_scale_x", randf_range(0.8, 1.2))
	mat.set_shader_parameter("blob_scale_y", randf_range(0.8, 1.2))


func generate_opposite_palette(mat):

	# Choose a run-wide base hue
	var base_hue = randf()


	# Slight variation per blob
	var hue = fmod(base_hue + randf_range(-0.15, 0.15), 1.0)

	# Adjacent hue (small shift)
	var adjacent = fmod(hue + randf_range(0.1, 0.225), 1.0)
	var top = Color.from_hsv(hue, 1.0, 0.9)
	var bottom = Color.from_hsv(adjacent, 1.0, 0.7)
	
	var opposite_hue = fmod(base_hue + 0.5, 1.0)

	mat.set_shader_parameter("blob_top", top)
	mat.set_shader_parameter("blob_bottom", bottom)

	# Background derived from base hue (desaturated & darker)
	var bg_edge = Color.from_hsv(opposite_hue, 0.15, 0.25)
	var bg_center = Color.from_hsv(opposite_hue, 0.7, 0.55)

	mat.set_shader_parameter("background_edge", bg_edge)
	mat.set_shader_parameter("background_center", bg_center)