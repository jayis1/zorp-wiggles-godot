// Crystal Refraction Shader — Crystal biome ambient effect
// Simulates a subtle shimmering refraction with prismatic color separation,
// as if viewing the world through faceted crystal. Adds cool blue-purple tint.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float refraction_scale : hint_range(0.0, 0.02) = 0.004;
uniform float shimmer_speed : hint_range(0.1, 10.0) = 1.5;
uniform float facet_scale : hint_range(2.0, 40.0) = 15.0;  // Size of crystal facets
uniform vec3 prism_color_a : source_color = vec3(0.6, 0.8, 1.0); // Cool blue
uniform vec3 prism_color_b : source_color = vec3(0.8, 0.6, 1.0); // Soft purple
uniform float tint_strength : hint_range(0.0, 0.5) = 0.1;
uniform float edge_glow : hint_range(0.0, 1.0) = 0.3;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.7);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * shimmer_speed;

	// Faceted normal-like displacement: pick a random direction per facet cell
	vec2 facet_uv = floor(uv * facet_scale);
	float h = hash21(facet_uv);
	float angle = h * TAU;
	vec2 facet_dir = vec2(cos(angle), sin(angle));

	// Smooth interpolation between facets
	vec2 f = fract(uv * facet_scale);
	float shimmer = sin(t + h * 10.0) * 0.5 + 0.5;

	// Refraction shift: small offset based on facet direction + shimmer
	vec2 shift = facet_dir * refraction_scale * strength * shimmer;
	// Bias shift toward edges
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float edge = smoothstep(0.4, 0.95, dist);
	shift *= (0.5 + edge);

	vec4 src = texture(SCREEN_TEXTURE, uv + shift);

	// Prismatic color tint — varies by facet, gives rainbow refraction feel
	vec3 prism = mix(prism_color_a, prism_color_b, h);
	vec3 col = mix(src.rgb, src.rgb * (1.0 + prism * tint_strength), strength);

	// Edge glow: subtle prismatic halo at screen borders
	col += prism * edge * edge_glow * strength * shimmer * 0.4;

	COLOR = vec4(col, 1.0);
}