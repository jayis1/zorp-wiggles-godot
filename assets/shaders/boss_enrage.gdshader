// Boss Enrage Screen Effect Shader
// Combines a pulsing red vignette with chromatic aberration that intensifies
// when the boss is enraged (HP below threshold). Conveys danger and pressure.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;       // 0 = calm, 1 = full enrage
uniform float pulse_speed : hint_range(0.5, 15.0) = 6.0;
uniform float max_shift : hint_range(0.0, 0.02) = 0.008;
uniform float vignette_radius : hint_range(0.3, 1.0) = 0.5;
uniform float vignette_softness : hint_range(0.05, 0.6) = 0.4;
uniform vec3 enrage_color : source_color = vec3(0.9, 0.05, 0.05);
uniform float max_alpha : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float dist = length(centered);

	// Pulsing — faster and more aggressive than low-HP
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	pulse = pow(pulse, 1.2);
	float intensity = strength * pulse;

	// Chromatic aberration at edges
	float edge = smoothstep(0.45, 0.95, dist);
	vec2 dir = dist > 0.0001 ? normalize(centered) : vec2(0.0);
	float shift = max_shift * edge * intensity;
	float r = texture(SCREEN_TEXTURE, uv + dir * shift).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - dir * shift).b;
	vec3 col = vec3(r, g, b);

	// Red vignette
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist * 1.3);
	float red_amount = vignette * intensity * max_alpha;
	col = mix(col, enrage_color, red_amount);

	// Edge darkening for a "tunnel vision" dread effect
	col *= 1.0 - edge * 0.1 * intensity;

	COLOR = vec4(col, 1.0);
}