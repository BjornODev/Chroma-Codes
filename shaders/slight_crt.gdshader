shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform vec2 resolution = vec2(320.0, 180.0);

uniform float scan_line_amount : hint_range(0.0, 1.0) = 0.5;
uniform float warp_amount : hint_range(0.0, 1.0) = 0.05;
uniform float grille_amount : hint_range(0.0, 1.0) = 0.05;
uniform float brightness_boost : hint_range(1.0, 2.0) = 1.2;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec2 delta = uv - 0.5;
	float warp_factor = dot(delta, delta) * warp_amount;
	uv += delta * warp_factor;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	float scanline = sin(uv.y * resolution.y * PI) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scan_line_amount * 0.5);

	float grille = mod(uv.x * resolution.x, 3.0) < 1.5 ? 0.95 : 1.05;
	grille = mix(1.0, grille, grille_amount * 0.5);

	vec3 color = texture(SCREEN_TEXTURE, uv).rgb * scanline * grille;

	color *= brightness_boost;

	COLOR.rgb = color;
	COLOR.a = 1.0;
}
