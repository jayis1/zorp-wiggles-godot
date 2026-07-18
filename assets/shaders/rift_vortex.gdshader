// Dimensional rift vortex shader — swirling portal effect with chromatic
// distortion and dimensional color tinting.
// Applied to 3D MeshInstance3D (shader_type spatial).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float time_scale = 1.0;
uniform vec3 dimension_color : source_color = vec3(0.8, 0.9, 1.0);
uniform float swirl_strength = 8.0;
uniform float strength = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Use UV coordinates centered on the disc (0.5, 0.5 = center)
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = uv - center;

	// Distance from center for radial effects
	float dist = length(offset);

	// Polar coordinates for swirl
	float angle = atan(offset.y, offset.x);
	float radius = dist;

	// Swirl — more distortion near center
	float swirl = swirl_strength * (1.0 - smoothstep(0.0, 0.5, radius)) * sin(TIME * time_scale);
	angle += swirl * 0.3;

	// Reconstruct UV with swirl
	vec2 swirled_uv = center + vec2(cos(angle), sin(angle)) * radius;

	// Chromatic aberration — RGB channels sample at different swirl offsets
	float ca_amount = 0.003 * strength * (1.0 - smoothstep(0.0, 0.4, radius));
	vec2 ca_dir = normalize(offset + vec2(0.001));

	// Sample the screen texture for a portal "see-through" effect
	vec4 col_r = texture(screen_texture, SCREEN_UV + ca_dir * ca_amount);
	vec4 col_g = texture(screen_texture, SCREEN_UV);
	vec4 col_b = texture(screen_texture, SCREEN_UV - ca_dir * ca_amount);

	vec3 col = vec3(col_r.r, col_g.g, col_b.b);

	// Dimensional color tint — stronger near center
	float tint_strength = strength * (1.0 - smoothstep(0.1, 0.5, radius)) * 0.4;
	col = mix(col, dimension_color, tint_strength);

	// Pulsing energy rings
	float rings = sin(dist * 40.0 - TIME * time_scale * 3.0) * 0.5 + 0.5;
	rings *= smoothstep(0.5, 0.0, radius) * 0.15 * strength;
	col += dimension_color * rings;

	// Vignette darkening at edges of the portal area
	float vignette = smoothstep(0.6, 0.15, radius);
	col *= mix(1.0, vignette, strength * 0.3);

	// Discard pixels outside the disc radius for a clean circular portal
	if (radius > 0.5) {
		discard;
	}

	ALBEDO = col;
	ALPHA = 1.0;
}