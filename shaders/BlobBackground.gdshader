shader_type canvas_item;

uniform float amplitude = 0.04;
uniform float frequency = 8.0;
uniform float speed = 2.0;
uniform vec2 scroll_direction = vec2(0.1, 0.1);
uniform float scrolling_speed = 0.05;
uniform float blob_scale = 1.0;
uniform int blob_count = 7;

uniform vec4 color_a = vec4(0.2, 0.4, 0.9, 1.0);
uniform vec4 color_b = vec4(0.6, 0.2, 0.8, 1.0);
uniform vec4 color_c = vec4(0.9, 0.3, 0.5, 1.0);
uniform vec4 color_d = vec4(0.2, 0.8, 0.7, 1.0);
uniform vec4 color_e = vec4(0.9, 0.7, 0.2, 1.0);

uniform float seed = 0.0;

const float ASPECT = 1.777;

float hash(float n) {
	n = mod(n, 1000.0);
	return fract(sin(n) * 43758.5453123);
}

vec2 blob_center(int index) {
	float i = float(index);
	float s = mod(seed, 1000.0);
	return vec2(
		fract(sin(s * 127.1 + i * 311.7) * 43758.5453),
		fract(sin(s * 269.5 + i * 183.3) * 43758.5453)
	);
}

float blob_radius(int index) {
	float i = float(index);
	float s = mod(seed, 1000.0);
	return mix(0.15, 0.35, fract(sin(s * 91.3 + i * 57.1) * 43758.5453)) * blob_scale;
}

float smooth_min(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float blob_field(vec2 uv) {
	vec2 uv_a = vec2(uv.x * ASPECT, uv.y);

	float field = 1.0;
	float k = 0.06;

	for (int i = 0; i < 12; i++) {
		if (i >= blob_count) break;
		vec2 center = blob_center(i);
		vec2 center_a = vec2(center.x * ASPECT, center.y);
		float radius = blob_radius(i);
		float dist = length(uv_a - center_a) - radius;
		field = smooth_min(field, dist, k);
	}

	return clamp(field * 3.0, -1.0, 1.0) * 0.5 + 0.5;
}

float wave_field(vec2 uv) {
	float s = mod(seed, 1000.0);
	float offset1 = fract(sin(s * 13.7) * 43758.5) * 6.28;
	float offset2 = fract(sin(s * 7.3) * 43758.5) * 6.28;
	float offset3 = fract(sin(s * 3.1) * 43758.5) * 6.28;

	float w1 = sin(uv.x * 3.14159 * 2.0 + offset1 + uv.y * 1.5) * 0.5 + 0.5;
	float w2 = sin(uv.y * 3.14159 * 1.5 + offset2 + uv.x * 1.2) * 0.5 + 0.5;
	float w3 = sin((uv.x + uv.y) * 3.14159 * 1.8 + offset3) * 0.5 + 0.5;

	float w = w1 * 0.5 + w2 * 0.35 + w3 * 0.15;
	return w * w * (3.0 - 2.0 * w);
}

vec4 sample_palette(float t) {
	t = clamp(t, 0.0, 1.0);
	vec4 colors[5];
	colors[0] = color_a;
	colors[1] = color_b;
	colors[2] = color_c;
	colors[3] = color_d;
	colors[4] = color_e;

	float scaled = t * 4.0;
	int index = clamp(int(scaled), 0, 3);
	float frac = scaled - float(index);
	frac = frac * frac * (3.0 - 2.0 * frac);
	return mix(colors[index], colors[index + 1], frac);
}

void fragment() {
	vec2 uv = UV;

	vec2 scroll = scroll_direction * TIME * scrolling_speed;
	float distort = amplitude * sin(frequency * uv.y + speed * TIME);
	uv.x += distort;
	uv.y +=distort;
	uv += scroll;

	float blobs = blob_field(uv);
	float waves = wave_field(uv);

	float combined = mix(blobs, waves, 0.25);

	// Posterize into distinct color bands with soft edges between them
	float bands = 4.0;
	float band = floor(combined * bands) / bands;
	float frac = fract(combined * bands);
	// Soft edge between bands — lower value = harder edge
	float edge_softness = 0.15;
	frac = smoothstep(0.0, edge_softness, frac) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, frac));
	combined = band + (frac / bands);

	COLOR = sample_palette(combined);
}