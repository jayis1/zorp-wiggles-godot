## Zorp Wiggles — Boss Gauntlet HUD (Phase 34: Endgame)
## Canvas overlay that shows the Boss Gauntlet progress — the hardest mode
## in the game. Only visible when EndgameManager.is_boss_gauntlet_active() is true.
##
## Display layout (top-center, below the biome indicator):
##   ☠ Boss Gauntlet 3/6       ← boss index / total, deep red
##   ⏱ 1m 23.45s               ← total elapsed time
##   Next in 2s...             ← intermission countdown (when between bosses)
##   ▓▓▓▓░░░░░                 ← progress bar (bosses defeated / total)
##
## Boss Gauntlet throws every boss in sequence with escalating stats and
## NO healing between fights. The persistent HUD overlay gives the player
## constant awareness of how far they've progressed and how many bosses
## remain, matching the visual language of the Boss Rush HUD but with a
## darker, more threatening red palette to convey the higher difficulty.

extends Control

class_name BossGauntletHUD

var _fade_alpha: float = 0.0
# ── Boss-change flash ── When a new boss spawns in the gauntlet,
# _boss_flash snaps to 1.0 and decays to 0 over ~0.6s. While > 0, the
# boss text is drawn larger and brighter, giving the transition a
# dramatic "next challenger" pulse — matching the Boss Rush HUD's flash.
var _boss_flash: float = 0.0
var _last_boss_index: int = -1
var _completed: bool = false
var _completed_anim: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = -170.0
	offset_top = 70.0
	offset_right = 170.0
	offset_bottom = 130.0
	GameManager.game_restarted.connect(_on_restarted)

func _on_restarted() -> void:
	_fade_alpha = 0.0
	_boss_flash = 0.0
	_last_boss_index = -1
	_completed = false
	_completed_anim = 0.0

func _process(delta: float) -> void:
	var should_show: bool = false
	if EndgameManager and EndgameManager.is_boss_gauntlet_active():
		should_show = true
	# Keep showing briefly after completion for the completion badge animation
	if _completed and _completed_anim < 1.0:
		should_show = true
	var target: float = 1.0 if should_show else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	# Detect boss index change for flash
	if EndgameManager and EndgameManager.is_boss_gauntlet_active():
		var cur_idx: int = EndgameManager.get_boss_gauntlet_index()
		if cur_idx != _last_boss_index:
			_last_boss_index = cur_idx
			_boss_flash = 1.0
	# Check completion
	if EndgameManager and EndgameManager.is_boss_gauntlet_completed() and not _completed:
		_completed = true
		_completed_anim = 0.0
	# Animate completion badge
	if _completed and _completed_anim < 1.0:
		_completed_anim = minf(1.0, _completed_anim + delta * 2.5)
	# Decay the boss flash
	if _boss_flash > 0.0:
		_boss_flash = maxf(0.0, _boss_flash - delta * 1.8)
		queue_redraw()
	if _fade_alpha > 0.01:
		queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not EndgameManager:
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var center_x: float = size.x / 2.0
	var flash: float = _boss_flash * _boss_flash * (3.0 - 2.0 * _boss_flash)

	# Current boss info
	var idx: int = EndgameManager.get_boss_gauntlet_index()
	var total_count: int = GameConstants.BOSS_GAUNTLET_QUEUE.size()
	var total_time: float = EndgameManager.get_boss_gauntlet_total_time()
	var intermission: float = EndgameManager.get_boss_gauntlet_intermission()

	# Background pill
	var header_text: String = "☠ Boss Gauntlet %d/%d" % [idx + 1, total_count]
	var header_font_size: int = int(18 + flash * 6.0)
	var header_size: Vector2 = font.get_string_size(header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size)
	var pill_w: float = maxf(header_size.x, 220.0) + 50.0
	var pill_h: float = 80.0
	var pill_rect := Rect2(center_x - pill_w / 2.0, 0.0, pill_w, pill_h)
	# Darker background than boss rush — conveys higher difficulty
	draw_rect(pill_rect, Color(0.12, 0.02, 0.02, 0.82 * a), true)
	# Deep red border — glows brighter during flash
	var border_color: Color = Color(
		lerpf(0.8, 1.0, flash),
		lerpf(0.15, 0.3, flash),
		lerpf(0.1, 0.15, flash),
		(0.7 + flash * 0.3) * a
	)
	draw_rect(pill_rect, border_color, false, 1.5 + flash * 1.5)

	# Header text — deep red, brighter during flash
	var header_color: Color = Color(
		lerpf(0.9, 1.0, flash),
		lerpf(0.2, 0.35, flash),
		lerpf(0.15, 0.25, flash),
		a
	)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - header_size.x / 2.0, 22.0),
		header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_font_size,
		header_color)

	# Total elapsed time
	var time_text: String = _format_time(total_time)
	var time_size: Vector2 = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	font.draw_string(get_canvas_item(),
		Vector2(center_x - time_size.x / 2.0, 44.0),
		time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.9, 0.7, 0.6, 0.9 * a))

	# Intermission countdown or "In combat" status
	if intermission > 0:
		var inter_text: String = "Next in %ds..." % int(ceil(intermission))
		var inter_size: Vector2 = font.get_string_size(inter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - inter_size.x / 2.0, 62.0),
			inter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.8, 0.5, 0.3, 0.85 * a))
	else:
		var combat_text: String = "⚔ In combat — NO HEALING"
		var combat_size: Vector2 = font.get_string_size(combat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - combat_size.x / 2.0, 62.0),
			combat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1.0, 0.3, 0.2, 0.9 * a))

	# Progress bar (bosses defeated / total)
	var bar_w: float = 200.0
	var bar_h: float = 6.0
	var bar_x: float = center_x - bar_w / 2.0
	var bar_y: float = 74.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.03, 0.02, 0.6 * a), true)
	var fill_frac: float = float(idx) / float(total_count) if total_count > 0 else 0.0
	fill_frac = clampf(fill_frac, 0.0, 1.0)
	var fill_w: float = bar_w * fill_frac
	if fill_w > 0:
		draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), Color(0.85, 0.2, 0.1, 0.9 * a), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.8, 0.2, 0.1, 0.5 * a), false, 1.0)

	# Completion badge — animated slide-in + golden glow
	if _completed and _completed_anim > 0.0:
		var badge_text: String = "🏆 COMPLETE!"
		var badge_font_size: int = 22
		var badge_size: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_font_size)
		# Ease-out-back scale for a celebratory pop
		var t: float = _completed_anim
		var scale: float = 1.0 + (t * t * (3.0 - 2.0 * t) - t) * 0.3 + t * 0.1
		var badge_color := Color(1.0, 0.85, 0.3, _completed_anim * a)
		font.draw_string(get_canvas_item(),
			Vector2(center_x - badge_size.x * scale / 2.0, 105.0),
			badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(badge_font_size * scale), badge_color)

func _format_time(t: float) -> String:
	var minutes: int = int(t) / 60
	var seconds: float = t - (minutes * 60)
	if minutes > 0:
		return "%dm %05.2fs" % [minutes, seconds]
	return "%.2fs" % seconds