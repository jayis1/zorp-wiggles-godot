// Water Surface Shader — Animated scrolling water for water biome overlays
// Uses sine waves for gentle ripples + scrolling UVs for flow. Semi-transparent.
// Applied to 3D MeshInstance3D (shader_type spatial).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 water_color : source_color = vec3(0.1, 0.3, 0.7);
uniform vec3 deep_color : source_color = vec3(0.02, 0.05, 0.2);
uniform float transparency : hint_range(0.0, 1.0) = 0.6;
uniform float flow_speed : hint_range(0.0, 5.0) = 0.5;
uniform float wave_height : hint_range(0.0, 0.5) = 0.05;
uniform float wave_frequency : hint_range(1.0, 20.0) = 6.0;
uniform float shininess : hint_range(1.0, 100.0) = 30.0;

void vertex() {
	// Gentle vertex displacement for ripple effect
	float wave = sin(VERTEX.x * wave_frequency + TIME * flow_speed) * 0.5
			  + cos(VERTEX.z * wave_frequency * 0.8 + TIME * flow_speed * 1.2) * 0.5;
	VERTEX.y += wave * wave_height;
}

void fragment() {
	// Scrolling UVs for water flow
	vec2 uv = UV * 4.0;
	float t = TIME * flow_speed;
	float r1 = sin(uv.x + t) * 0.5 + 0.5;
	float r2 = cos(uv.y + t * 1.1) * 0.5 + 0.5;
	float ripple = r1 * r2;

	// Mix shallow and deep water color
	vec3 col = mix(deep_color, water_color, ripple);

	// Simple specular highlight from view direction (faked)
	vec3 view_dir = normalize(-VIEW);
	float spec = pow(max(dot(NORMAL, view_dir), 0.0), shininess);
	col += vec3(0.6, 0.8, 1.0) * spec * 0.3;

	// Alpha for transparency
	float alpha = mix(1.0 - transparency, 1.0, ripple * 0.3);

	ALBEDO = col;
	ALPHA = alpha;
}