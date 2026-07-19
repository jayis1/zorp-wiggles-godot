## Zorp Wiggles — Speedrun Timer HUD (Phase 25: Progression & Meta-Systems)
## Canvas overlay that shows the speedrun timer and biome split list.
## Only visible when GameModeManager.is_speedrun() is true.
## Draws with _draw() for a clean, low-overhead timer readout.
##
## Display layout (top-center, below the biome indicator):
##   ⏱ 1m 23.45s        ← total run time, large, cyan
##   Biomes: 3/8         ← progress toward completion
##   Last split: Crystal Caverns — 45.20s  ← most recent split (fades out)
##
## The timer itself is tracked by GameModeManager; this HUD just reads it.
## When the speedrun completes, a "COMPLETE" badge appears and the timer
## freezes (GameModeManager stops counting).

extends Control

class_name SpeedrunTimerHUD

var _fade_alpha: float = 0.0
var _last_split_text: String = ""
var _last_split_alpha: float = 0.0
var _completed: bool = false
var _completed_anim: float = 0.0  # 0..1 badge scale-in

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position below the biome indicator (which sits at the top-left area).
	# We anchor top-center and offset to a centered position.
	offset_left = -160.0
	offset_top = 70.0
	offset_right = 160.0
	offset_bottom = 130.0
	if GameModeManager:
		GameModeManager.speedrun_split.connect(_on_split)
		GameModeManager.speedrun_completed.connect(_on_completed)
		GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_last_split_text = ""
	_last_split_alpha = 0.0
	_completed = false
	_completed_anim = 0.0

func _on_split(biome_id: int, split_time: float) -> void:
	var bname: String = GameConstants.BIOME_NAMES.get(biome_id, "Unknown")
	_last_split_text = "Last split: %s — %s" % [bname, _format_time(split_time)]
	_last_split_alpha = 1.0

func _on_completed(_total_time: float) -> void:
	_completed = true
	_completed_anim = 0.0

func _process(delta: float) -> void:
	# Only visible in speedrun mode
	var should_show: bool = GameModeManager and GameModeManager.is_speedrun()
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Fade out the last-split text after a few seconds
	if _last_split_alpha > 0:
		_last_split_alpha = maxf(0.0, _last_split_alpha - delta * 0.25)
	# Completed badge scale-in
	if _completed and _completed_anim < 1.0:
		_completed_anim = minf(1.0, _completed_anim + delta * 2.5)
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not GameModeManager or not GameModeManager.is_speedrun():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0
	# Background pill behind the timer for readability
	var timer_text: String = "⏱ %s" % _format_time(GameModeManager.get_speedrun_time())
	var timer_size: Vector2 = font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var pill_w: float = timer_size.x + 40.0
	var pill_h: float = 40.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	draw_rect(pill_rect, Color(0.02, 0.03, 0.08, 0.75 * a), true)
	draw_rect(pill_rect, Color(0.4, 0.8, 1.0, 0.6 * a), false, 1.5)
	# Timer text (cyan, large)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - timer_size.x / 2.0, 26.0),
		timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(0.4, 0.9, 1.0, a))
	# Biome progress
	var visited: int = GameModeManager.get_speedrun_visited_count()
	var total: int = GameModeManager.SPEEDRUN_SPLIT_BIOME_COUNT
	var prog_text: String = "Biomes: %d/%d" % [visited, total]
	var prog_size: Vector2 = font.get_string_size(prog_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - prog_size.x / 2.0, 52.0),
		prog_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.7, 0.8, 0.9, 0.85 * a))
	# Last split text (fading)
	if _last_split_alpha > 0.01:
		var split_size: Vector2 = font.get_string_size(_last_split_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - split_size.x / 2.0, 72.0),
			_last_split_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.6, 0.85, 1.0, _last_split_alpha * a))
	# Personal best hint (small, below)
	var pb: float = GameModeManager.get_speedrun_pb()
	if pb > 0:
		var pb_text: String = "PB: %s" % _format_time(pb)
		var pb_size: Vector2 = font.get_string_size(pb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - pb_size.x / 2.0, 90.0),
			pb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.5, 0.55, 0.65, 0.7 * a))
	# Completed badge
	if _completed:
		var badge_scale: float = _ease_out_back(_completed_anim)
		var badge_text: String = "🏆 COMPLETE!"
		var badge_size: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		var badge_y: float = 110.0
		# Glow background
		var glow_rect := Rect2(center_x - (badge_size.x + 30.0) / 2.0 * badge_scale,
			badge_y, (badge_size.x + 30.0) * badge_scale, 36.0 * badge_scale)
		draw_rect(glow_rect, Color(1.0, 0.85, 0.3, 0.25 * a * badge_scale), true)
		draw_rect(glow_rect, Color(1.0, 0.85, 0.3, 0.8 * a * badge_scale), false, 2.0)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - badge_size.x / 2.0 * badge_scale,
				badge_y + 26.0 * badge_scale),
			badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(26.0 * badge_scale),
			Color(1.0, 0.85, 0.3, a * badge_scale))

# Ease-out with overshoot (TRANS_BACK equivalent) for the badge pop-in
func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _format_time(seconds: float) -> String:
	var s: float = seconds
	var m: int = int(s) / 60
	var sec: int = int(s) % 60
	var ms: int = int(fmod(s, 1.0) * 100.0)
	if m > 0:
		return "%dm %02ds.%02d" % [m, sec, ms]
	else:
		return "%ds.%02d" % [sec, ms]