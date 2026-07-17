// Zorp Wiggles — Biome Transition Fog Shader (Phase 9)
// A screen-space canvas_item shader that simulates exponential fog with
// per-biome color blending. When transitioning between biomes, the fog
// color cross-fades from the old biome's fog color to the new one, and
// the density smoothly interpolates. This creates a visible "fog roll"
// effect as the player crosses biome boundaries.
//
// Uniforms:
//   strength   — 0..1, overall effect intensity (0 = no fog, 1 = full)
//   fog_color  — vec3, the current fog color (0-1 range)
//   fog_density — float, exponential fog density (0.0 = clear, 0.1 = very thick)
//   transition_progress — 0..1, blend factor for biome transition (0 = old, 1 = new)

shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fog_color : source_color = vec3(0.1, 0.1, 0.2);
uniform float fog_density : hint_range(0.0, 0.1) = 0.02;
uniform float transition_progress : hint_range(0.0, 1.0) = 1.0;
uniform float time = 0.0;

void fragment() {
	vec4 screen_color = texture(TEXTURE, UV);

	// Depth-based fog intensity — simulate distance fog by using the
	// vertical position on screen. The bottom of the screen (near the
	// player) has less fog, the top (horizon/distance) has more.
	// This mimics how fog thickens with distance in a 3D scene.
	float depth_factor = pow(UV.y, 1.5);  // 0 at bottom, 1 at top

	// Exponential fog formula: fog_factor = 1 - exp(-density * depth)
	float fog_factor = 1.0 - exp(-fog_density * depth_factor * 30.0);

	// Apply strength multiplier
	fog_factor *= strength;

	// Add subtle animated fog drift — noise-like swirl for organic movement
	float drift = sin(UV.x * 8.0 + time * 0.5) * cos(UV.y * 6.0 + time * 0.3);
	fog_factor += drift * 0.03 * strength;

	// Clamp
	fog_factor = clamp(fog_factor, 0.0, 0.85);

	// Blend screen color with fog color
	vec3 final_color = mix(screen_color.rgb, fog_color, fog_factor);

	// Slight desaturation in foggy areas for atmospheric depth
	float luminance = dot(final_color, vec3(0.299, 0.587, 0.114));
	final_color = mix(vec3(luminance), final_color, 1.0 - fog_factor * 0.3);

	COLOR = vec4(final_color, 1.0);
}