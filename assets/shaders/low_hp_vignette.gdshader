// Low-HP Warning Vignette Shader
// Pulses a red vignette around the screen edges when the player's HP is low.
// Intensity scales with how low HP is (closer to death = stronger pulse).
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;       // 0 = off, 1 = max danger
uniform float pulse_speed : hint_range(0.5, 10.0) = 4.0;   // Heartbeat-like pulse rate
uniform float vignette_radius : hint_range(0.3, 1.0) = 0.55;
uniform float vignette_softness : hint_range(0.05, 0.6) = 0.45;
uniform vec3 danger_color : source_color = vec3(0.85, 0.05, 0.05);
uniform float max_alpha : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen_texture, uv);

	// Pulsing intensity (heartbeat: quick spike, slower fade)
	float t = TIME * pulse_speed;
	float pulse = 0.55 + 0.45 * sin(t);
	// Sharpen the pulse for a more "throb" feel
	pulse = pow(pulse, 1.5);

	float intensity = strength * pulse;

	// Radial vignette
	vec2 centered = uv - 0.5;
	float dist = length(centered) * 1.4; // Scale so corners are fully covered
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

	// Red overlay
	float red_amount = vignette * intensity * max_alpha;
	vec3 col = mix(src.rgb, danger_color, red_amount);

	// Slight desaturation of the center as HP gets critical (dying feel)
	float desat = strength * 0.2 * (1.0 - vignette);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desat);

	COLOR = vec4(col, 1.0);
}