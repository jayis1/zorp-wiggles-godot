// Color Filter Shader (Phase 30: Visual Polish)
// Cosmetic screen-space color filters: sepia, noir (grayscale), thermal, x-ray.
// These are unlockable cosmetics — purely visual, no gameplay effect.
// mode: 0=off, 1=sepia, 2=noir, 3=thermal, 4=x-ray
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 4) = 0;

// Sepia tint matrix (warm brown vintage look)
const mat3 SEPIA = mat3(
	vec3(0.393, 0.769, 0.189),
	vec3(0.349, 0.686, 0.168),
	vec3(0.272, 0.534, 0.131)
);

// Luminance weights (Rec. 709)
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen_texture, uv);
	vec3 col = src.rgb;

	if (mode == 1) {
		// Sepia — warm vintage photograph tone
		col = SEPIA * col;
		// Slight contrast lift for a faded-photo feel
		col = mix(col, col * 1.1, 0.5);
	} else if (mode == 2) {
		// Noir — grayscale with lifted contrast and crushed blacks
		float l = dot(col, LUMA);
		// Contrast curve: (l - 0.5) * 1.4 + 0.5
		l = clamp((l - 0.5) * 1.4 + 0.5, 0.0, 1.0);
		col = vec3(l);
	} else if (mode == 3) {
		// Thermal — map luminance to a heat gradient (blue→cyan→green→yellow→red)
		float l = dot(col, LUMA);
		// Heat ramp
		vec3 heat;
		if (l < 0.25) {
			heat = mix(vec3(0.0, 0.0, 0.4), vec3(0.0, 0.5, 1.0), l / 0.25);
		} else if (l < 0.5) {
			heat = mix(vec3(0.0, 0.5, 1.0), vec3(0.0, 0.9, 0.4), (l - 0.25) / 0.25);
		} else if (l < 0.75) {
			heat = mix(vec3(0.0, 0.9, 0.4), vec3(1.0, 1.0, 0.0), (l - 0.5) / 0.25);
		} else {
			heat = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.1, 0.0), (l - 0.75) / 0.25);
		}
		col = heat;
	} else if (mode == 4) {
		// X-ray — inverted luminance with cyan tint, bright edges pop
		float l = dot(col, LUMA);
		float inv = 1.0 - l;
		// Boost high-frequency detail via a simple neighbor sample (edge enhance)
		float lx = dot(texture(screen_texture, uv + vec2(0.002, 0.0)).rgb, LUMA);
		float ly = dot(texture(screen_texture, uv + vec2(0.0, 0.002)).rgb, LUMA);
		float edge = abs(l - lx) + abs(l - ly);
		col = vec3(0.2, 0.7, 0.9) * inv + vec3(0.5, 1.0, 1.0) * edge * 3.0;
	}

	COLOR = vec4(mix(src.rgb, col, strength), 1.0);
}