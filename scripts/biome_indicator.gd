## Zorp Wiggles — Biome Indicator (Phase 5: HUD Polish)
## Shows the current biome name in the top-center of the HUD.
## Fades in on biome change, then gently fades to a dim state after a few seconds.
## Color transitions to match the biome's terrain color.

extends Control

class_name BiomeIndicator

# ─── Internal State ───────────────────────────────────────────────────────────
var _current_biome: int = GameConstants.Biome.GRASS
var _target_color: Color = Color(1, 1, 1, 0)
var _current_color: Color = Color(1, 1, 1, 0)
var _display_alpha: float = 1.0  # Brightness multiplier (fades after display)
var _biome_colors: Dictionary = {}
var _world_ref: Node3D = null

# ── Biome change scale-pop ── When the biome changes, the indicator text
#    used to just lerp color with no motion. The weather indicator gets a
#    scale-pop on change; the biome indicator deserves the same treatment
#    so biome transitions feel deliberate, not silent. A quick shrink →
#    elastic overshoot gives the name a "landed in a new place" read.
#    The pop is driven by a _pop_phase that eases to 0 over ~0.4s, and
#    _draw applies a scale transform around the text center.
var _pop_phase: float = 0.0  # 1.0 at change moment → eases to 0
const POP_DECAY_SPEED: float = 3.5  # How fast the pop settles (higher = snappier)
var _pop_scale: float = 1.0  # Computed scale from _pop_phase

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position in top center
	offset_left = 0
	offset_top = 50
	offset_right = 1280
	offset_bottom = 90

	# Connect to biome change signal
	GameManager.biome_changed.connect(_on_biome_changed)
	# Get biome colors from world generator
	call_deferred("_resolve_world_ref")

func _resolve_world_ref() -> void:
	_world_ref = GameManager.world
	if _world_ref and "BIOME_COLORS" in _world_ref:
		_biome_colors = _world_ref.BIOME_COLORS

func _on_biome_changed(biome_id: int) -> void:
	_current_biome = biome_id
	# Set target color based on biome terrain color
	var biome_color: Color = _biome_colors.get(biome_id, Color(0.5, 0.5, 0.5))
	_target_color = Color(biome_color.r, biome_color.g, biome_color.b, 0.9)
	# Reset display alpha to full (bright)
	_display_alpha = 1.0
	# Trigger the scale-pop so the biome change reads as a deliberate
	# visual "shift" rather than a silent color lerp.
	_pop_phase = 1.0

func _process(delta: float) -> void:
	# Frame-rate-independent exponential lerp (1 - exp(-k*delta)) instead of
	# the old `lerpf(a, b, speed * delta)` which decayed at different rates
	# depending on FPS. At 144 FPS the old lerp converged ~2.4x faster than at
	# 60 FPS, making the biome indicator name flash too briefly on high-refresh
	# displays. The exponential form converges at the same real-time rate
	# regardless of refresh rate, matching the pattern used in player.gd,
	# camera_rig.gd, and the HUD bars.
	var weight: float = 1.0 - exp(-GameConstants.BIOME_INDICATOR_FADE_SPEED * delta)
	# Fade the display brightness down after it's been shown for a while
	_display_alpha = lerpf(_display_alpha, 0.4, weight)
	# Lerp color toward target
	_current_color = _current_color.lerp(_target_color, weight)
	# ── Decay the scale-pop phase ── Uses ease-out elastic so the pop
	#    overshoots past 1.0 then settles, matching the weather icon pop.
	#    The elastic curve is approximated by combining a shrink phase
	#    (first 20% of the decay) and an overshoot phase (remaining 80%).
	if _pop_phase > 0.0:
		_pop_phase -= delta * POP_DECAY_SPEED
		if _pop_phase <= 0.0:
			_pop_phase = 0.0
			_pop_scale = 1.0
		else:
			# Map _pop_phase (1→0) to an elastic pop: shrink to 0.6 at
			# phase=0.8, overshoot to 1.15 at phase=0.4, settle to 1.0 at 0.
			var p: float = _pop_phase
			if p > 0.8:
				# Wind-up shrink: 1.0 → 0.6 as p goes 1.0 → 0.8
				var t: float = (1.0 - p) / 0.2
				_pop_scale = lerpf(1.0, 0.6, t * t)
			elif p > 0.4:
				# Overshoot: 0.6 → 1.15 as p goes 0.8 → 0.4
				var t: float = (0.8 - p) / 0.4
				# Ease-out cubic for a fast pop that decelerates
				t = 1.0 - pow(1.0 - t, 3.0)
				_pop_scale = lerpf(0.6, 1.15, t)
			else:
				# Settle: 1.15 → 1.0 as p goes 0.4 → 0.0
				var t: float = 1.0 - (p / 0.4)
				# Ease-out quartic for a soft landing
				t = 1.0 - pow(1.0 - t, 4.0)
				_pop_scale = lerpf(1.15, 1.0, t)
	# Update actual modulate-like via custom draw
	queue_redraw()

func _draw() -> void:
	if _current_color.a < 0.01:
		return

	var biome_name: String = GameConstants.BIOME_NAMES.get(_current_biome, "Unknown")
	# Add a location icon (◆) prefix
	var display_text := "◆ %s" % biome_name

	var font := get_theme_default_font()
	if not font:
		return

	var font_size: int = 24
	var text_size := font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var center_x: float = size.x / 2.0
	var draw_y: float = 20 + text_size.y / 2.0

	# Draw with the biome color, modulated by display brightness
	var color := Color(_current_color.r, _current_color.g, _current_color.b,
		_current_color.a * _display_alpha)

	# ── Apply scale-pop around the text center ── The pop gives the
	#    biome name a "landed in a new place" read on biome change.
	#    We draw the shadow and text at the scaled position, scaling
	#    around the text's horizontal center so it grows from the
	#    middle, not the top-left corner.
	var scaled_text_w: float = text_size.x * _pop_scale
	var scaled_text_h: float = text_size.y * _pop_scale
	var scaled_center_x: float = center_x
	var scaled_draw_y: float = draw_y - (scaled_text_h - text_size.y) * 0.5
	var scaled_offset_x: float = scaled_center_x - scaled_text_w / 2.0

	# Draw a subtle shadow for readability (scaled with the text)
	var shadow_color := Color(0, 0, 0, color.a * 0.5)
	var shadow_font_size: int = int(float(font_size) * _pop_scale)
	# Clamp font size to avoid zero or negative on extreme scales
	shadow_font_size = maxi(shadow_font_size, 8)
	font.draw_string(get_canvas_item(), Vector2(scaled_offset_x + 2, scaled_draw_y + 2), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, shadow_font_size, shadow_color)
	font.draw_string(get_canvas_item(), Vector2(scaled_offset_x, scaled_draw_y), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, shadow_font_size, color)