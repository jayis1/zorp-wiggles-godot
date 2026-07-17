## Zorp Wiggles — Death Screen (Phase 5: HUD Polish)
## Full-screen overlay shown when the player dies. Displays:
## - "Zorp has fallen" title (red, large)
## - Stats: score, kills, best combo, time survived, max pickup streak
## - "Press R to restart" prompt
## Fades in smoothly, with stats appearing with staggered animation.
## Inspired by the death screen in Ursina game.py.

extends Control

class_name DeathScreen

# ─── Internal State ───────────────────────────────────────────────────────────
var _bg_color: Color = GameConstants.DEATH_SCREEN_BG_COLOR
var _fade_progress: float = 0.0  # 0..1, controls fade-in
var _title_alpha: float = 0.0
var _stats_alpha: float = 0.0
var _prompt_alpha: float = 0.0
var _is_shown: bool = false
var _stat_anim_timer: float = 0.0
var _displayed_score: int = 0  # For score roll-up animation
var _time_survived: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Connect to player death signal
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_restarted.connect(_on_game_restarted)

func _on_player_died() -> void:
	_is_shown = true
	visible = true
	_fade_progress = 0.0
	_title_alpha = 0.0
	_stats_alpha = 0.0
	_prompt_alpha = 0.0
	_stat_anim_timer = 0.0
	_displayed_score = 0
	_time_survived = GameManager.game_time

func _on_game_restarted() -> void:
	_is_shown = false
	visible = false

func _process(delta: float) -> void:
	if not _is_shown:
		return

	# Fade in the background
	_fade_progress = minf(_fade_progress + delta / GameConstants.DEATH_SCREEN_FADE_IN_DURATION, 1.0)

	# Staggered fade-in: title at 0.2s, stats at 0.5s, prompt at 1.0s
	_stat_anim_timer += delta
	_title_alpha = clampf((_stat_anim_timer - 0.2) / 0.4, 0.0, 1.0)
	_stats_alpha = clampf((_stat_anim_timer - 0.5) / 0.5, 0.0, 1.0)
	_prompt_alpha = clampf((_stat_anim_timer - 1.0) / 0.4, 0.0, 1.0)

	# Score roll-up animation
	if _stats_alpha > 0.1:
		var target_score: int = GameManager.player_score
		_displayed_score = int(lerpf(_displayed_score, target_score, 5.0 * delta))
		if abs(_displayed_score - target_score) < 5:
			_displayed_score = target_score

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_shown:
		return
	if event.is_action_pressed("dash") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
		GameManager.restart_game()

func _draw() -> void:
	if not _is_shown:
		return

	var screen_size := size
	var center := screen_size / 2.0

	# Draw background
	var bg := Color(_bg_color.r, _bg_color.g, _bg_color.b, _bg_color.a * _fade_progress)
	draw_rect(Rect2(Vector2.ZERO, screen_size), bg, true)

	# Draw title: "ZORP HAS FALLEN"
	if _title_alpha > 0.01:
		var title_color := Color(GameConstants.DEATH_SCREEN_TITLE_COLOR.r,
			GameConstants.DEATH_SCREEN_TITLE_COLOR.g,
			GameConstants.DEATH_SCREEN_TITLE_COLOR.b,
			_title_alpha)
		var title_text := "ZORP HAS FALLEN"
		var title_pos := Vector2(center.x, center.y - 120)
		_draw_centered_text(title_text, title_pos, 42, title_color)

	# Draw stats
	if _stats_alpha > 0.01:
		var stat_color := Color(GameConstants.DEATH_SCREEN_STAT_COLOR.r,
			GameConstants.DEATH_SCREEN_STAT_COLOR.g,
			GameConstants.DEATH_SCREEN_STAT_COLOR.b,
			_stats_alpha)
		var label_color := Color(GameConstants.DEATH_SCREEN_STAT_LABEL_COLOR.r,
			GameConstants.DEATH_SCREEN_STAT_LABEL_COLOR.g,
			GameConstants.DEATH_SCREEN_STAT_LABEL_COLOR.b,
			_stats_alpha)

		var stat_y: float = center.y - 40
		var line_height: float = 30

		_draw_stat_line("Final Score", str(_displayed_score), center.x, stat_y, label_color, stat_color)
		stat_y += line_height
		_draw_stat_line("Total Kills", str(GameManager.player_kills), center.x, stat_y, label_color, stat_color)
		stat_y += line_height
		_draw_stat_line("Best Combo", "x%d" % GameManager.player_best_combo, center.x, stat_y, label_color, stat_color)
		stat_y += line_height
		_draw_stat_line("Max Pickup Streak", "x%d" % GameManager.player_max_pickup_streak, center.x, stat_y, label_color, stat_color)
		stat_y += line_height
		var mins: int = int(_time_survived) / 60
		var secs: int = int(_time_survived) % 60
		_draw_stat_line("Time Survived", "%d:%02d" % [mins, secs], center.x, stat_y, label_color, stat_color)

	# Draw restart prompt
	if _prompt_alpha > 0.01:
		var prompt_color := Color(0.8, 0.8, 0.8, _prompt_alpha * (0.6 + 0.4 * sin(_stat_anim_timer * 3.0)))
		_draw_centered_text("Press R or SPACE to Restart", Vector2(center.x, center.y + 140), 22, prompt_color)

func _draw_centered_text(text_str: String, pos: Vector2, font_size: int, color: Color) -> void:
	# Use default font
	var font := get_theme_default_font()
	if font:
		var text_size := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		font.draw_string(get_canvas_item(), Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 2.0), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_stat_line(label: String, value: String, cx: float, y: float, label_color: Color, value_color: Color) -> void:
	var font := get_theme_default_font()
	if not font:
		return
	var font_size: int = 22
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var value_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var total_width: float = label_size.x + 20 + value_size.x
	var start_x: float = cx - total_width / 2.0
	# Draw label (left-aligned)
	font.draw_string(get_canvas_item(), Vector2(start_x, y + label_size.y / 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
	# Draw value (right-aligned at end)
	font.draw_string(get_canvas_item(), Vector2(start_x + label_size.x + 20, y + value_size.y / 2.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, value_color)