## Zorp Wiggles — Survival Mode HUD (Phase 34: Endgame)
## Canvas overlay that shows the survival timer, next boss countdown, and
## passive score accumulation. Only visible when EndgameManager.is_survival_active()
## is true.
##
## Display layout (top-center, below the biome indicator):
##   ☠ Survival           ← mode label, red-orange
##   ⏱ 2m 15.43s          ← total elapsed time
##   Next boss: 45s       ← countdown to next forced boss
##   ▓▓▓░░░░░░░           ← progress bar (time until next boss)
##
## The survival mode has no healing, no shops, and one life — the persistent
## HUD overlay gives the player constant awareness of how long they've survived
## and when the next boss is coming, matching the visual language of the
## Endless, Boss Rush, and Speedrun mode HUDs.

extends Control

class_name SurvivalHUD

var _fade_alpha: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -160.0
	offset_top = 70.0
	offset_right = 160.0
	offset_bottom = 130.0
	GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_fade_alpha = 0.0

func _process(delta: float) -> void:
	var should_show: bool = false
	if EndgameManager and EndgameManager.is_survival_active():
		should_show = true
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not EndgameManager or not EndgameManager.is_survival_active():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0

	# Background pill
	var label_text: String = "☠ Survival"
	var label_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var pill_w: float = label_size.x + 60.0
	var pill_h: float = 80.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	draw_rect(pill_rect, Color(0.15, 0.03, 0.02, 0.78 * a), true)
	# Red-orange border
	draw_rect(pill_rect, Color(0.9, 0.25, 0.1, 0.7 * a), false, 1.5)

	# Mode label
	font.draw_string(get_canvas_item(),
		Vector2(center_x - label_size.x / 2.0, 22.0),
		label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(1.0, 0.4, 0.2, a))

	# Elapsed time
	var elapsed: float = EndgameManager.get_survival_time()
	var time_text: String = _format_time(elapsed)
	var time_size: Vector2 = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - time_size.x / 2.0, 44.0),
		time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(1.0, 0.85, 0.7, 0.9 * a))

	# Next boss countdown
	var next_boss: float = EndgameManager.get_survival_next_boss_time()
	var boss_text: String = "Next boss: %ds" % int(ceil(next_boss))
	var boss_size: Vector2 = font.get_string_size(boss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	# Turn red when boss is imminent (< 10s)
	var boss_color: Color
	if next_boss < 10.0:
		boss_color = Color(1.0, 0.3, 0.2, 0.95 * a)
	else:
		boss_color = Color(0.85, 0.65, 0.5, 0.85 * a)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - boss_size.x / 2.0, 62.0),
		boss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		boss_color)

	# Progress bar (time until next boss)
	var bar_w: float = 200.0
	var bar_h: float = 5.0
	var bar_x: float = center_x - bar_w / 2.0
	var bar_y: float = 74.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.05, 0.03, 0.6 * a), true)
	var interval: float = GameConstants.SURVIVAL_MODE_BOSS_INTERVAL
	var fill_frac: float = 1.0 - (next_boss / interval) if interval > 0 else 0.0
	fill_frac = clampf(fill_frac, 0.0, 1.0)
	var fill_w: float = bar_w * fill_frac
	if fill_w > 0:
		var bar_color: Color
		if next_boss < 10.0:
			bar_color = Color(1.0, 0.3, 0.15, 0.9 * a)
		else:
			bar_color = Color(0.9, 0.4, 0.2, 0.85 * a)
		draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), bar_color, true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.9, 0.3, 0.15, 0.5 * a), false, 1.0)

func _format_time(t: float) -> String:
	var minutes: int = int(t) / 60
	var seconds: float = t - (minutes * 60)
	if minutes > 0:
		return "%dm %05.2fs" % [minutes, seconds]
	return "%.2fs" % seconds