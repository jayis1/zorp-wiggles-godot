## Zorp Wiggles — Endless Mode Wave HUD (Phase 25: Progression & Meta-Systems)
## Canvas overlay that shows the current wave number and a countdown to the next.
## Only visible when GameModeManager.is_endless() is true.
##
## Display layout (top-center, below the biome indicator):
##   ♾ Wave 3           ← current wave number, large, orange
##   Next wave: 12s     ← countdown to next wave
##   ▓▓▓▓▓░░░░░░░       ← progress bar (time into current wave)

extends Control

class_name EndlessWaveHUD

var _fade_alpha: float = 0.0
# ── Wave-change flash ── When a new wave starts, _wave_flash snaps to 1.0
# and decays to 0 over ~0.6s. While > 0, the wave text is drawn larger and
# brighter with a golden tint, and the pill border glows — giving the wave
# transition a visible "level up" pulse in the HUD itself, beyond the
# camera shake + SFX that GameModeManager already fires.
var _wave_flash: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -140.0
	offset_top = 70.0
	offset_right = 140.0
	offset_bottom = 120.0
	if GameModeManager:
		GameModeManager.wave_changed.connect(_on_wave_changed)
	GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_wave_flash = 0.0

func _on_wave_changed(_wave: int) -> void:
	_wave_flash = 1.0

func _process(delta: float) -> void:
	var should_show: bool = GameModeManager and GameModeManager.is_endless()
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Decay the wave flash with ease-out cubic for a natural falloff
	if _wave_flash > 0.0:
		_wave_flash = maxf(0.0, _wave_flash - delta * 1.8)
		queue_redraw()
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not GameModeManager or not GameModeManager.is_endless():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0
	var wave: int = GameModeManager.get_endless_wave()
	# Wave flash intensity — ease-out cubic for natural decel
	var flash: float = _wave_flash * _wave_flash * (3.0 - 2.0 * _wave_flash)
	# Background pill
	var wave_text: String = "♾ Wave %d" % wave
	# Scale font up slightly during flash (22 → 28 at peak)
	var wave_font_size: int = int(22 + flash * 6.0)
	var wave_size: Vector2 = font.get_string_size(wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, wave_font_size)
	var pill_w: float = wave_size.x + 50.0
	var pill_h: float = 38.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	# Pill fill brightens during flash
	var pill_fill_a: float = 0.75 + flash * 0.2
	draw_rect(pill_rect, Color(0.1, 0.05, 0.02, pill_fill_a * a), true)
	# Border glows gold during flash, orange normally
	var border_color: Color = Color(
		lerpf(1.0, 1.0, flash),
		lerpf(0.6, 0.85, flash),
		lerpf(0.2, 0.3, flash),
		(0.6 + flash * 0.4) * a
	)
	var border_width: float = 1.5 + flash * 1.5
	draw_rect(pill_rect, border_color, false, border_width)
	# Wave text — golden tint during flash, orange normally
	var text_color: Color = Color(
		lerpf(1.0, 1.0, flash),
		lerpf(0.7, 0.85, flash),
		lerpf(0.3, 0.35, flash),
		a
	)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - wave_size.x / 2.0, 25.0),
		wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, wave_font_size,
		text_color)
	# Next wave countdown
	var remaining: float = _wave_remaining()
	var next_text: String = "Next wave: %ds" % int(ceil(remaining))
	var next_size: Vector2 = font.get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - next_size.x / 2.0, 50.0),
		next_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.85, 0.75, 0.6, 0.85 * a))
	# Progress bar (time into current wave)
	var bar_w: float = 180.0
	var bar_h: float = 6.0
	var bar_x: float = center_x - bar_w / 2.0
	var bar_y: float = 66.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.1, 0.05, 0.6 * a), true)
	var interval: float = GameModeManager.ENDLESS_WAVE_INTERVAL
	var fill_frac: float = 1.0 - (remaining / interval) if interval > 0 else 0.0
	fill_frac = clampf(fill_frac, 0.0, 1.0)
	var fill_w: float = bar_w * fill_frac
	if fill_w > 0:
		draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), Color(1.0, 0.6, 0.2, 0.9 * a), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1.0, 0.6, 0.3, 0.5 * a), false, 1.0)

# Read the wave timer from GameModeManager. Since _wave_timer is private, we
# expose it via a getter added below. If the getter is missing, fall back to
# the full interval (bar appears empty).
func _wave_remaining() -> float:
	if GameModeManager and GameModeManager.has_method("get_endless_wave_timer"):
		return GameModeManager.get_endless_wave_timer()
	return GameModeManager.ENDLESS_WAVE_INTERVAL