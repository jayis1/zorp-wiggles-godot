// Chromatic Aberration Shader — Alien biome ambient + boss enrage effect
// Splits RGB channels at screen edges for a "reality tearing" look.
// Intensity can be modulated by the manager for biome ambiance or boss enrage.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.5;       // Overall effect 0..1
uniform float max_shift : hint_range(0.0, 0.02) = 0.006;    // Max UV shift per channel
uniform float edge_falloff : hint_range(0.3, 1.0) = 0.55;   // Radius where shift begins
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform vec3 aberration_tint : source_color = vec3(0.6, 0.2, 0.8); // Alien purple
uniform float tint_strength : hint_range(0.0, 1.0) = 0.1;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;    // Pulsing intensity variation

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float dist = length(centered);

	// Edge mask: aberration stronger toward corners
	float edge = smoothstep(edge_falloff, 0.95, dist);

	// Pulsing
	float pulse = 1.0;
	if (pulse_amount > 0.001) {
		pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	}

	float shift = max_shift * edge * strength * pulse;

	// Sample each channel at a slightly different UV
	// R shifts outward along radial direction, B shifts inward
	vec2 dir = dist > 0.0001 ? normalize(centered) : vec2(0.0);
	float r = texture(SCREEN_TEXTURE, uv + dir * shift).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - dir * shift).b;

	vec3 col = vec3(r, g, b);

	// Subtle alien purple tint at edges
	col = mix(col, col * (1.0 + aberration_tint * tint_strength), edge * strength);

	// Slight darkening at very corners for moody feel
	col *= 1.0 - edge * 0.08 * strength;

	COLOR = vec4(col, 1.0);
}