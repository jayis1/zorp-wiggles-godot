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
# Phase 20: Try Again button
var _try_again_btn: Button = null
var _quit_btn: Button = null
# Track hover tweens so we can kill them before starting a new one (avoid jitter)
var _hover_tweens: Dictionary = {}  # button -> Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to player death signal
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_restarted.connect(_on_game_restarted)
	# Phase 20: Create Try Again and Quit buttons
	_try_again_btn = Button.new()
	_try_again_btn.offset_left = 390.0
	_try_again_btn.offset_top = 520.0
	_try_again_btn.offset_right = 620.0
	_try_again_btn.offset_bottom = 570.0
	_try_again_btn.text = "↻ Try Again"
	_try_again_btn.add_theme_font_size_override("font_size", 22)
	_try_again_btn.visible = false
	_try_again_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_try_again_btn.pressed.connect(_on_try_again)
	# Hover pivot: center so scale grows from the middle
	_try_again_btn.pivot_offset = Vector2(115.0, 25.0)
	add_child(_try_again_btn)

	_quit_btn = Button.new()
	_quit_btn.offset_left = 660.0
	_quit_btn.offset_top = 520.0
	_quit_btn.offset_right = 890.0
	_quit_btn.offset_bottom = 570.0
	_quit_btn.text = "✖ Quit to Menu"
	_quit_btn.add_theme_font_size_override("font_size", 22)
	_quit_btn.visible = false
	_quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_quit_btn.pressed.connect(_on_quit)
	_quit_btn.pivot_offset = Vector2(115.0, 25.0)
	add_child(_quit_btn)

	# Connect hover signals for death screen buttons (matches menu polish)
	for btn in [_try_again_btn, _quit_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))

func _on_player_died() -> void:
	_is_shown = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  # Accept clicks
	_fade_progress = 0.0
	_title_alpha = 0.0
	_stats_alpha = 0.0
	_prompt_alpha = 0.0
	_stat_anim_timer = 0.0
	_displayed_score = 0
	_time_survived = GameManager.game_time
	# Phase 20: Show buttons after fade-in (delayed via _process)
	# Reset button visual state so the entrance animation plays cleanly
	_try_again_btn.visible = false
	_try_again_btn.modulate.a = 0.0
	_try_again_btn.scale = Vector2(0.8, 0.8)
	_quit_btn.visible = false
	_quit_btn.modulate.a = 0.0
	_quit_btn.scale = Vector2(0.8, 0.8)
	# Unpause the tree so buttons are clickable (death screen uses PROCESS_MODE_ALWAYS)
	get_tree().paused = false
	GameManager.is_paused = false

func _on_game_restarted() -> void:
	_is_shown = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _try_again_btn:
		_try_again_btn.visible = false
		_try_again_btn.scale = Vector2.ONE  # Reset for next death
		_try_again_btn.modulate.a = 1.0
	if _quit_btn:
		_quit_btn.visible = false
		_quit_btn.scale = Vector2.ONE
		_quit_btn.modulate.a = 1.0

func _on_try_again() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	GameManager.restart_game()

func _on_quit() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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

	# Phase 20: Show buttons when prompt fades in — with a staggered scale-in
	# entrance animation (fade + scale up from 0.8 with overshoot). This makes
	# the death screen feel less abrupt and gives the player a clear, juicy
	# call-to-action. The buttons start hidden + transparent + scaled down
	# (set in _on_player_died); here we make them visible and tween them in.
	if _prompt_alpha > 0.5:
		if _try_again_btn and not _try_again_btn.visible:
			_try_again_btn.visible = true
			_animate_button_in(_try_again_btn, 0.0)
		if _quit_btn and not _quit_btn.visible:
			_quit_btn.visible = true
			_animate_button_in(_quit_btn, 0.08)

queue_redraw()

## Entrance animation for death-screen buttons: fade in + scale up from 0.8
## with a gentle overshoot. The stagger delay offsets the second button so
## they don't pop in simultaneously.
func _animate_button_in(btn: Button, delay: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(btn, "modulate:a", 1.0, 0.25) \
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Hover effect: buttons grow slightly on hover, shrink on exit.
## Mirrors the main/pause menu hover juice so all UI feels cohesive.
## Uses a kill-and-recreate tween pattern to avoid jitter from overlapping tweens.
func _on_button_hover(btn: Button, is_hovering: bool) -> void:
	# Don't run hover while the entrance animation is still playing
	if btn.modulate.a < 0.9:
		return
	if _hover_tweens.has(btn):
		var existing: Tween = _hover_tweens[btn]
		if is_instance_valid(existing):
			existing.kill()
	var tween := create_tween()
	var target_scale := Vector2(1.06, 1.06) if is_hovering else Vector2.ONE
	tween.tween_property(btn, "scale", target_scale, 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[btn] = tween
	if is_hovering:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

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