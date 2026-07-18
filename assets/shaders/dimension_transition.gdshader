shader_type canvas_item;
// Dimension transition shader — screen wipe with chromatic shift.
// Used during entry/exit of dimensional rifts.
// 'progress' goes from 0.0 to 1.0 during the transition.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;       // 0 = start, 1 = end
uniform vec3 wipe_color : source_color = vec3(0.5, 0.7, 1.0);
uniform float wipe_speed = 2.0;     // How many "bands" sweep across
uniform float chromatic_amount = 0.005;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Sweep bands — the wipe moves from left to right with multiple bands
	float band = fract(uv.x * wipe_speed - progress * wipe_speed);
	float wipe_mask = smoothstep(0.0, 0.15, band) * smoothstep(1.0, 0.85, band);

	// Chromatic aberration strongest at the wipe edge
	float edge_dist = abs(band - 0.5);
	float ca = chromatic_amount * (1.0 - smoothstep(0.0, 0.3, edge_dist)) * progress;

	vec2 ca_offset = vec2(ca, 0.0);
	vec4 col_r = texture(screen_texture, uv + ca_offset);
	vec4 col_g = texture(screen_texture, uv);
	vec4 col_b = texture(screen_texture, uv - ca_offset);

	vec4 col = vec4(col_r.r, col_g.g, col_b.b, 1.0);

	// Blend with wipe color at the band edges
	col.rgb = mix(col.rgb, wipe_color, wipe_mask * 0.6);

	// Global tint during transition
	float global_tint = sin(progress * 3.14159) * 0.3;
	col.rgb = mix(col.rgb, wipe_color, global_tint);

	// Slight desaturation at peak transition
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(lum), col.rgb, 1.0 - global_tint * 0.5);

	COLOR = col;
}