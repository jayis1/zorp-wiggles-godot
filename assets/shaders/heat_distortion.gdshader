// Heat Distortion Shader — Lava biome ambient effect
// Applies a subtle wavy refraction + warm orange tint at screen edges.
// Used as a CanvasItem (2D) overlay shader via ShaderMaterial on a ColorRect.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.5;       // Overall effect intensity
uniform float speed : hint_range(0.1, 10.0) = 2.0;          // Wave speed
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.008; // Max UV shift
uniform float wave_frequency : hint_range(1.0, 30.0) = 12.0; // Spatial frequency
uniform vec3 heat_tint : source_color = vec3(1.0, 0.45, 0.1); // Warm orange tint
uniform float tint_strength : hint_range(0.0, 1.0) = 0.18;  // How strong the tint is
uniform float vignette_radius : hint_range(0.3, 1.0) = 0.7; // Where heat begins (UV radius)
uniform float vignette_softness : hint_range(0.01, 0.5) = 0.25;

void vertex() {
	// Standard full-rect vertex; nothing special needed.
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * speed;

	// Vertical wavy displacement (stronger at bottom = near lava ground)
	float vertical_factor = 1.0 - uv.y; // 0 at top, 1 at bottom
	float wave = sin(uv.y * wave_frequency + t) * 0.5
			  + sin(uv.x * wave_frequency * 1.3 + t * 1.1) * 0.5;
	float shift = wave * wave_amplitude * strength * vertical_factor;

	// Sample the screen with slight horizontal shift for a "heat haze" look
	vec4 src = texture(screen_texture, vec2(uv.x + shift, uv.y));

	// Radial vignette mask — heat is stronger near edges, fades in center
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float edge = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
	float heat_amount = edge * strength;

	// Add warm tint, strongest at edges
	vec3 tinted = mix(src.rgb, src.rgb * (1.0 + heat_tint * tint_strength), heat_amount);

	// Subtle brightness pulse (heat shimmer)
	float pulse = 0.5 + 0.5 * sin(t * 1.5);
	tinted += heat_tint * heat_amount * tint_strength * pulse * 0.3;

	COLOR = vec4(tinted, 1.0);
}