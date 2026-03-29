shader_type canvas_item;

uniform float radius : hint_range(0.0, 2250.0) = 1100.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 screen_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 pixel_pos = UV * screen_size;
	vec2 center_px = center * screen_size;
	float dist = length(pixel_pos - center_px);

	if (dist < radius) {
		discard;
	}

	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
