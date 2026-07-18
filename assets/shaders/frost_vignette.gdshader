// Frost Vignette Shader — Snow biome ambient effect
// Adds a frosty bluish-white vignette with crystalline noise at screen edges,
// and a subtle cold tint over the whole screen.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float frost_intensity : hint_range(0.0, 1.0) = 0.4;  // Edge frost opacity
uniform float vignette_radius : hint_range(0.3, 1.0) = 0.62;
uniform float vignette_softness : hint_range(0.01, 0.5) = 0.35;
uniform vec3 frost_color : source_color = vec3(0.85, 0.92, 1.0); // Pale icy blue
uniform vec3 cold_tint : source_color = vec3(0.7, 0.8, 1.0);
uniform float tint_strength : hint_range(0.0, 0.5) = 0.12;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.0;

// Simple hash for crystalline noise
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen_texture, uv);

	// Radial vignette
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float edge = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

	// Crystalline frost noise at edges (blocky ice crystals)
	vec2 frost_uv = uv * 80.0;
	float frost = hash21(floor(frost_uv)) * 0.6
				+ hash21(floor(frost_uv * 0.5)) * 0.4;
	frost = smoothstep(0.4, 0.9, frost);

	// Frost intensity grows toward corners
	float frost_mask = edge * frost * frost_intensity * strength;

	// Pulse breathing
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	frost_mask *= pulse;

	// Blend frost color onto edges
	vec3 col = mix(src.rgb, frost_color, frost_mask);

	// Cold tint over whole screen (subtle)
	col = mix(col, col * cold_tint, tint_strength * strength);

	// Slight desaturation at edges
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), edge * 0.15 * strength);

	COLOR = vec4(col, 1.0);
}