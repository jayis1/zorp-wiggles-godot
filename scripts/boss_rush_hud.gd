## Zorp Wiggles — Boss Rush HUD (Phase 25: Progression & Meta-Systems)
## Canvas overlay that shows the Boss Rush queue progress and total timer.
## Only visible when GameModeManager.is_boss_rush() is true.
##
## Display layout (top-center, below the biome indicator):
##   💀 Boss 2/5: Plasma Serpent    ← current boss index + name
##   ⏱ 1m 23.45s                    ← total elapsed time
##   ▓▓▓░░░░░                       ← progress bar (bosses defeated / total)
##
## The timer and index are tracked by GameModeManager; this HUD just reads them.

extends Control

class_name BossRushHUD

var _fade_alpha: float = 0.0
var _current_boss_name: String = ""
var _completed: bool = false
var _completed_anim: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -180.0
	offset_top = 70.0
	offset_right = 180.0
	offset_bottom = 130.0
	if GameModeManager:
		GameModeManager.boss_rush_boss_index.connect(_on_boss_index)
		GameModeManager.boss_rush_completed.connect(_on_completed)
	GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_current_boss_name = ""
	_completed = false
	_completed_anim = 0.0

func _on_boss_index(index: int, _total: int) -> void:
	# Look up the boss name from the queue
	var queue: Array = GameModeManager.BOSS_RUSH_QUEUE
	if index < queue.size():
		var boss_type: int = queue[index]
		# Map enemy type to a display name
		_current_boss_name = _boss_display_name(boss_type)

func _boss_display_name(boss_type: int) -> String:
	# The EnemyTypeData.TYPES dictionary is keyed by name string, not enum int,
	# so we use a direct match here for the boss rush display names.
	match boss_type:
		GameConstants.EnemyType.DRAKE: return "Apex Plasma Drake"
		GameConstants.EnemyType.SERPENT: return "Plasma Serpent"
		GameConstants.EnemyType.GRAVITON: return "Graviton Prime"
		GameConstants.EnemyType.VOID_LEVIATHAN: return "Colossal Void Leviathan"
		GameConstants.EnemyType.ANCIENT_SENTINEL: return "Rogue Ancient Sentinel"
		_: return "Boss"

func _on_completed(_total_time: float) -> void:
	_completed = true
	_completed_anim = 0.0

func _process(delta: float) -> void:
	var should_show: bool = GameModeManager and GameModeManager.is_boss_rush()
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	if _completed and _completed_anim < 1.0:
		_completed_anim = minf(1.0, _completed_anim + delta * 2.5)
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not GameModeManager or not GameModeManager.is_boss_rush():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0
	var total: int = GameModeManager.get_boss_rush_total()
	var index: int = GameModeManager.get_boss_rush_index()
	# Clamp the displayed index to the queue range (after the last boss dies,
	# index may equal total — show "all defeated" state)
	var display_index: int = minf(index + 1, total)
	var boss_text: String = "💀 Boss %d/%d" % [display_index, total]
	if _current_boss_name != "" and not _completed:
		boss_text += ": " + _current_boss_name
	var boss_size: Vector2 = font.get_string_size(boss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	# Background pill
	var pill_w: float = maxf(boss_size.x + 40.0, 200.0)
	var pill_h: float = 40.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	draw_rect(pill_rect, Color(0.08, 0.02, 0.03, 0.75 * a), true)
	draw_rect(pill_rect, Color(1.0, 0.3, 0.3, 0.6 * a), false, 1.5)
	# Boss text (red-orange)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - boss_size.x / 2.0, 26.0),
		boss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1.0, 0.5, 0.4, a))
	# Timer
	var timer_text: String = "⏱ %s" % _format_time(GameModeManager.get_boss_rush_total_time())
	var timer_size: Vector2 = font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - timer_size.x / 2.0, 50.0),
		timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.9, 0.85, 0.8, 0.9 * a))
	# Progress bar (bosses defeated / total)
	var bar_w: float = 200.0
	var bar_h: float = 8.0
	var bar_x: float = center_x - bar_w / 2.0
	var bar_y: float = 64.0
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.1, 0.1, 0.6 * a), true)
	# Filled portion
	var fill_frac: float = float(index) / float(total) if total > 0 else 0.0
	if _completed:
		fill_frac = 1.0
	var fill_w: float = bar_w * fill_frac
	if fill_w > 0:
		draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), Color(1.0, 0.4, 0.3, 0.9 * a), true)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1.0, 0.5, 0.4, 0.5 * a), false, 1.0)
	# Personal best hint
	var pb: float = 0.0
	if Statistics:
		var v: Variant = Statistics.get_lifetime_stat("boss_rush_pb_time")
		if v != null:
			pb = float(v)
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
		var glow_rect := Rect2(center_x - (badge_size.x + 30.0) / 2.0 * badge_scale,
			badge_y, (badge_size.x + 30.0) * badge_scale, 36.0 * badge_scale)
		draw_rect(glow_rect, Color(1.0, 0.85, 0.3, 0.25 * a * badge_scale), true)
		draw_rect(glow_rect, Color(1.0, 0.85, 0.3, 0.8 * a * badge_scale), false, 2.0)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - badge_size.x / 2.0 * badge_scale,
				badge_y + 26.0 * badge_scale),
			badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(26.0 * badge_scale),
			Color(1.0, 0.85, 0.3, a * badge_scale))

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