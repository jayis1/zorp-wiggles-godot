// Colorblind Correction Shader (Phase 31: QoL — Accessibility)
// Simulates/corrects for color vision deficiencies: protanopia, deuteranopia,
// tritanopia, and achromatopsia (full desaturation). Uses the Brettel/Machado
// model approach — a 3x3 color transform matrix applied per pixel.
//
// These are CORRECTION filters (help colorblind players distinguish colors),
// not simulations of the deficiency. mode: 0=off, 1=protanopia, 2=deuteranopia,
// 3=tritanopia, 4=achromatopsia.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 4) = 0;

// Correction matrices (simplified LMS-based transforms).
// These approximate the color shift needed to make distinctions clearer for
// each deficiency type. Values are tuned for a balanced correction — strong
// enough to help, not so strong as to look unnatural for normal-vision players.
const mat3 PROTANOPIA_CORRECT = mat3(
	vec3(0.45, 0.20, 0.00),
	vec3(0.50, 0.80, 0.10),
	vec3(0.05, 0.00, 1.00)
);
const mat3 DEUTERANOPIA_CORRECT = mat3(
	vec3(0.70, 0.30, 0.00),
	vec3(0.70, 0.70, 0.10),
	vec3(0.00, 0.00, 1.00)
);
const mat3 TRITANOPIA_CORRECT = mat3(
	vec3(1.00, 0.00, 0.00),
	vec3(0.00, 0.85, 0.25),
	vec3(0.00, 0.15, 0.60)
);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 src = texture(screen_texture, uv);
	vec3 col = src.rgb;

	if (mode == 1) {
		// Protanopia correction (red deficiency)
		col = PROTANOPIA_CORRECT * col;
	} else if (mode == 2) {
		// Deuteranopia correction (green deficiency)
		col = DEUTERANOPIA_CORRECT * col;
	} else if (mode == 3) {
		// Tritanopia correction (blue deficiency)
		col = TRITANOPIA_CORRECT * col;
	} else if (mode == 4) {
		// Achromatopsia — full desaturation to grayscale (no color info)
		float l = dot(col, LUMA);
		col = vec3(l);
	}

	COLOR = vec4(mix(src.rgb, col, strength), 1.0);
}