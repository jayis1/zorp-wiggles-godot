// Dissolve Shader — Toxic bog dripping dissolve effect
// Creates an animated noise-based alpha cutoff that "drips" downward, as if
// the screen edges are being eaten away by corrosive bog fog.
// Applied as a CanvasItem overlay that draws a colored corrosive fringe.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.5;       // Overall intensity
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.3; // How much is dissolved (0=none, 1=full)
uniform float noise_scale : hint_range(5.0, 80.0) = 30.0;  // Spatial frequency of dissolve noise
uniform float drip_speed : hint_range(0.0, 5.0) = 0.8;     // Vertical scroll speed of noise
uniform float edge_softness : hint_range(0.01, 0.3) = 0.08; // Fringe width
uniform vec3 dissolve_color : source_color = vec3(0.5, 0.8, 0.15); // Toxic green
uniform vec3 fringe_color : source_color = vec3(0.8, 1.0, 0.3);    // Bright acid green fringe
uniform float fringe_glow : hint_range(0.0, 3.0) = 1.5;

// 2D hash for noise
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.21));
	p += dot(p, p + 67.43);
	return fract(p.x * p.y);
}

// Value noise (smooth)
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(SCREEN_TEXTURE, uv);

	// Noise field — scrolls downward over time (dripping effect)
	float t = TIME * drip_speed;
	float n = value_noise(vec2(uv.x * noise_scale, uv.y * noise_scale - t));
	// Add a second octave for more detail
	n = n * 0.7 + value_noise(vec2(uv.x * noise_scale * 2.0, uv.y * noise_scale * 2.0 - t * 1.5)) * 0.3;

	// Bias noise by vertical position (more dissolution at bottom, less at top)
	float vertical_bias = (1.0 - uv.y) * 0.4;
	float threshold = dissolve_amount + vertical_bias;

	// Dissolve mask: where noise < threshold, the screen is "eaten"
	float mask = smoothstep(threshold, threshold + edge_softness, n);

	// Fringe: bright glow at the dissolution edge
	float fringe = 1.0 - smoothstep(0.0, edge_softness, abs(n - threshold));
	fringe *= strength;

	// Apply toxic green tint to the surviving area (subtle)
	vec3 col = mix(src.rgb, src.rgb * (1.0 + dissolve_color * 0.08), strength * 0.5);

	// Add fringe glow
	col += fringe_color * fringe * fringe_glow;

	// At the dissolved edges, fade to dark toxic green (vignette of corrosion)
	float edge_vignette = (1.0 - mask) * strength;
	col = mix(col, dissolve_color * 0.3, edge_vignette * 0.6);

	// Keep full alpha — this is a post-process, not a cutout
	COLOR = vec4(col, 1.0);
}