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

func _process(delta: float) -> void:
	# Fade the display brightness down after it's been shown for a while
	_display_alpha = lerpf(_display_alpha, 0.4, GameConstants.BIOME_INDICATOR_FADE_SPEED * delta)
	# Lerp color toward target
	_current_color = _current_color.lerp(_target_color, GameConstants.BIOME_INDICATOR_FADE_SPEED * delta)
	# Apply display brightness to alpha
	var draw_alpha: float = _current_color.a * _display_alpha
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

	# Draw a subtle shadow for readability
	var shadow_color := Color(0, 0, 0, color.a * 0.5)
	font.draw_string(get_canvas_item(), Vector2(center_x - text_size.x / 2.0 + 2, draw_y + 2), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	font.draw_string(get_canvas_item(), Vector2(center_x - text_size.x / 2.0, draw_y), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)