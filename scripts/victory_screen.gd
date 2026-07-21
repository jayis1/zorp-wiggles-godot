## Zorp Wiggles — Victory Screen (Phase 30: Visual & Audio Polish)
## Full-screen overlay shown when a game mode is completed:
##   - Boss Rush: all bosses defeated (list of boss times + total + PB comparison)
##   - Speedrun: visited the required number of biomes (total time + per-biome splits + PB)
##   - Endless: a "milestone reached" celebration at wave thresholds (10, 25, 50, 100)
##
## The screen shows a ranked letter grade (S/A/B/C/D) based on performance,
## a stats summary, and "Play Again" / "Quit to Menu" buttons. Fades in smoothly
## with staggered stat animation, matching the death screen's presentation.
##
## Signals consumed:
##   GameModeManager.boss_rush_completed(total_time)
##   GameModeManager.speedrun_completed(total_time)
##   GameModeManager.wave_changed(wave)  — for endless milestone celebrations

extends Control

class_name VictoryScreen

# ─── Ranking Tiers ────────────────────────────────────────────────────────────
enum Rank { D, C, B, A, S }
const RANK_NAMES: Array[String] = ["D", "C", "B", "A", "S"]
const RANK_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.55),   # D — grey
	Color(0.50, 0.80, 0.50),   # C — green
	Color(0.40, 0.80, 1.00),   # B — cyan
	Color(1.00, 0.75, 0.30),   # A — gold
	Color(1.00, 0.40, 0.90),   # S — magenta (perfect)
]

# ─── Internal State ───────────────────────────────────────────────────────────
var _is_shown: bool = false
var _fade_progress: float = 0.0
var _title_alpha: float = 0.0
var _rank_alpha: float = 0.0
var _stats_alpha: float = 0.0
var _buttons_alpha: float = 0.0
var _stat_anim_timer: float = 0.0
var _mode: int = 0  # GameModeManager.Mode value
var _total_time: float = 0.0
var _personal_best: float = 0.0
var _is_new_pb: bool = false
var _rank: int = Rank.D
var _splits: Dictionary = {}  # biome_id → time (speedrun)
var _wave: int = 0  # endless mode wave at completion
var _play_again_btn: Button = null
var _quit_btn: Button = null
var _hover_tweens: Dictionary = {}

# ─── Endless milestone waves that trigger a victory celebration ──
const ENDLESS_MILESTONE_WAVES: Array[int] = [10, 25, 50, 100]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Phase 35: add to victory_screen group so other nodes can query our state
	add_to_group("victory_screen")
	# Connect to GameModeManager completion signals
	if GameModeManager:
		GameModeManager.boss_rush_completed.connect(_on_boss_rush_completed)
		GameModeManager.speedrun_completed.connect(_on_speedrun_completed)
		GameModeManager.wave_changed.connect(_on_wave_changed)
	# Connect to game restart to hide the screen
	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)
		GameManager.player_died.connect(_on_player_died)
	# Create Play Again + Quit buttons (matching death screen style)
	_play_again_btn = Button.new()
	_play_again_btn.offset_left = 390.0
	_play_again_btn.offset_top = 560.0
	_play_again_btn.offset_right = 620.0
	_play_again_btn.offset_bottom = 610.0
	_play_again_btn.text = "↻ Play Again"
	_play_again_btn.add_theme_font_size_override("font_size", 22)
	_play_again_btn.visible = false
	_play_again_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_again_btn.pressed.connect(_on_play_again)
	_play_again_btn.pivot_offset = Vector2(115.0, 25.0)
	add_child(_play_again_btn)
	_quit_btn = Button.new()
	_quit_btn.offset_left = 660.0
	_quit_btn.offset_top = 560.0
	_quit_btn.offset_right = 890.0
	_quit_btn.offset_bottom = 610.0
	_quit_btn.text = "✖ Quit to Menu"
	_quit_btn.add_theme_font_size_override("font_size", 22)
	_quit_btn.visible = false
	_quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_quit_btn.pressed.connect(_on_quit)
	_quit_btn.pivot_offset = Vector2(115.0, 25.0)
	add_child(_quit_btn)
	# Hover animations
	for btn in [_play_again_btn, _quit_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))


# ─── Signal Handlers ──────────────────────────────────────────────────────────

func _on_boss_rush_completed(total_time: float) -> void:
	_mode = GameModeManager.Mode.BOSS_RUSH
	_total_time = total_time
	_personal_best = _read_pb("boss_rush_pb_time")
	_is_new_pb = _personal_best <= 0.0 or total_time < _personal_best
	_rank = _rank_for_boss_rush(total_time)
	_show()

func _on_speedrun_completed(total_time: float) -> void:
	_mode = GameModeManager.Mode.SPEEDRUN
	_total_time = total_time
	_splits = GameModeManager.get_speedrun_splits()
	_personal_best = GameModeManager.get_speedrun_pb()
	_is_new_pb = _personal_best <= 0.0 or total_time < _personal_best
	_rank = _rank_for_speedrun(total_time)
	_show()

func _on_wave_changed(wave: int) -> void:
	# Endless mode: celebrate milestone waves (10, 25, 50, 100) with a brief
	# victory popup. The game continues running — this is a mid-run celebration,
	# not a final victory screen. We don't show buttons; the overlay auto-hides.
	if not GameModeManager.is_endless():
		return
	if not (wave in ENDLESS_MILESTONE_WAVES):
		return
	_mode = GameModeManager.Mode.ENDLESS
	_wave = wave
	_total_time = GameManager.game_time
	_rank = _rank_for_endless(wave)
	# For endless milestones, we show a brief celebration then auto-hide.
	# Don't pause the game — let the player keep fighting.
	_show_milestone(wave)

func _on_game_restarted() -> void:
	_hide()

func _on_player_died() -> void:
	# If the player dies, hide the victory screen (death screen takes over)
	_hide()


# ─── Show / Hide ──────────────────────────────────────────────────────────────

func _show() -> void:
	_is_shown = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_progress = 0.0
	_title_alpha = 0.0
	_rank_alpha = 0.0
	_stats_alpha = 0.0
	_buttons_alpha = 0.0
	_stat_anim_timer = 0.0
	_play_again_btn.visible = false
	_play_again_btn.modulate.a = 0.0
	_play_again_btn.scale = Vector2(0.8, 0.8)
	_quit_btn.visible = false
	_quit_btn.modulate.a = 0.0
	_quit_btn.scale = Vector2(0.8, 0.8)
	# Pause the game tree so the victory screen is the focus (death screen
	# uses PROCESS_MODE_ALWAYS so its buttons remain clickable while paused).
	get_tree().paused = true
	GameManager.is_paused = true
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)

func _show_milestone(wave: int) -> void:
	# Brief celebration for endless milestone waves — auto-hides after 4s.
	_is_shown = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input during milestone
	_fade_progress = 0.0
	_title_alpha = 0.0
	_rank_alpha = 0.0
	_stats_alpha = 0.0
	_buttons_alpha = 0.0
	_stat_anim_timer = 0.0
	_play_again_btn.visible = false
	_quit_btn.visible = false
	AudioManager.play_sfx(AudioManager.SFX_LEVEL_UP)
	# Auto-hide after 4 seconds via a one-shot timer
	var t: SceneTreeTimer = get_tree().create_timer(4.0)
	t.timeout.connect(_hide)

func _hide() -> void:
	_is_shown = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _play_again_btn:
		_play_again_btn.visible = false
	if _quit_btn:
		_quit_btn.visible = false
	# Unpause if we were pausing
	if get_tree().paused:
		get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false


# ── Phase 35: Public state query for input handling audit ──
# Lets the pause menu (and other systems) check if the victory screen is
# currently shown so they don't open on top of it.
func is_shown() -> bool:
	return _is_shown


# ─── Per-Frame Animation ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_shown:
		return
	# Fade in
	_fade_progress = minf(1.0, _fade_progress + delta / 0.8)
	# Staggered stat reveal: title at 0.0s, rank at 0.3s, stats at 0.6s, buttons at 1.2s
	_stat_anim_timer += delta
	_title_alpha = clampf((_stat_anim_timer - 0.0) / 0.4, 0.0, 1.0)
	_rank_alpha = clampf((_stat_anim_timer - 0.3) / 0.4, 0.0, 1.0)
	_stats_alpha = clampf((_stat_anim_timer - 0.6) / 0.5, 0.0, 1.0)
	_buttons_alpha = clampf((_stat_anim_timer - 1.2) / 0.4, 0.0, 1.0)
	# Show buttons once they've started fading in
	if _buttons_alpha > 0.05 and _play_again_btn:
		_play_again_btn.visible = true
		_play_again_btn.modulate.a = _buttons_alpha
		_play_again_btn.scale = Vector2(0.8, 0.8).lerp(Vector2.ONE, _buttons_alpha)
		_quit_btn.visible = true
		_quit_btn.modulate.a = _buttons_alpha
		_quit_btn.scale = Vector2(0.8, 0.8).lerp(Vector2.ONE, _buttons_alpha)
	queue_redraw()


# ── Phase 35: Input handling audit — keyboard shortcuts for victory screen ──
# The death screen lets you restart with R or Space; the victory screen had
# no keyboard shortcut, which was an inconsistency. Now R/Space/Enter restarts
# the current mode, and Esc/Q returns to the main menu. Only fires after the
# buttons have appeared (so early presses during the fade-in don't accidentally
# skip the screen). Milestone celebrations (auto-hide) ignore these keys.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_shown:
		return
	# Milestone celebrations auto-hide — don't accept restart keys
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	# Wait for buttons to be visible before accepting restart keys
	if _buttons_alpha < 0.5:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_play_again()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
			_on_quit()
			get_viewport().set_input_as_handled()


# ─── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _is_shown:
		return
	var size: Vector2 = get_size()
	# Background — dark with slight transparency
	var bg: Color = Color(0.02, 0.0, 0.05, 0.82 * _fade_progress)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	# Title
	var title_text: String = _title_text()
	var title_color: Color = Color(1.0, 0.85, 0.3, _title_alpha)
	draw_string(_get_title_font(), Vector2(size.x / 2 - 250, 110), title_text,
		HORIZONTAL_ALIGNMENT_CENTER, 500, 56, title_color)
	# Rank (big letter grade)
	if _rank_alpha > 0.0:
		var rank_label: String = "RANK  " + RANK_NAMES[_rank]
		var rank_color: Color = RANK_COLORS[_rank]
		rank_color.a = _rank_alpha
		draw_string(_get_title_font(), Vector2(size.x / 2 - 150, 220), rank_label,
			HORIZONTAL_ALIGNMENT_CENTER, 300, 72, rank_color)
	# Stats
	if _stats_alpha > 0.0:
		_draw_stats(size, _stats_alpha)
	# Personal best line
	if _stats_alpha > 0.5 and _personal_best > 0.0:
		var pb_text: String = "Personal Best: " + _format_time(_personal_best)
		if _is_new_pb:
			pb_text = "★ NEW PERSONAL BEST! ★  (" + _format_time(_total_time) + ")"
		var pb_color: Color = Color(1.0, 0.85, 0.3, _stats_alpha) if _is_new_pb else Color(0.6, 0.7, 0.9, _stats_alpha)
		draw_string(_get_body_font(), Vector2(size.x / 2 - 200, 510), pb_text,
			HORIZONTAL_ALIGNMENT_CENTER, 400, 20, pb_color)


func _draw_stats(size: Vector2, alpha: float) -> void:
	var y: float = 310.0
	var stat_color: Color = Color(0.85, 0.85, 0.95, alpha)
	var label_color: Color = Color(0.5, 0.5, 0.6, alpha)
	match _mode:
		GameModeManager.Mode.BOSS_RUSH:
			_draw_stat_line("Total Time", _format_time(_total_time), y, stat_color, label_color)
			y += 28
			_draw_stat_line("Bosses Defeated", "%d / %d" % [
				GameModeManager.get_boss_rush_total(),
				GameModeManager.get_boss_rush_total(),
			], y, stat_color, label_color)
			y += 28
			_draw_stat_line("Mode", "Boss Rush", y, stat_color, label_color)
		GameModeManager.Mode.SPEEDRUN:
			_draw_stat_line("Total Time", _format_time(_total_time), y, stat_color, label_color)
			y += 28
			_draw_stat_line("Biomes Visited", "%d / %d" % [
				GameModeManager.get_speedrun_visited_count(),
				GameModeManager.SPEEDRUN_SPLIT_BIOME_COUNT,
			], y, stat_color, label_color)
			y += 28
			_draw_stat_line("Mode", "Speedrun", y, stat_color, label_color)
			y += 28
			# Show per-biome splits (up to 4 to fit on screen)
			var split_count: int = 0
			for biome_id in _splits.keys():
				if split_count >= 4:
					break
				var bname: String = "Biome %d" % biome_id
				if GameConstants.BIOME_NAMES.size() > biome_id:
					bname = GameConstants.BIOME_NAMES[biome_id]
				_draw_stat_line(bname, _format_time(float(_splits[biome_id])), y, stat_color, label_color)
				y += 22
				split_count += 1
		GameModeManager.Mode.ENDLESS:
			_draw_stat_line("Wave Reached", str(_wave), y, stat_color, label_color)
			y += 28
			_draw_stat_line("Time Survived", _format_time(_total_time), y, stat_color, label_color)
			y += 28
			_draw_stat_line("Mode", "Endless", y, stat_color, label_color)


func _draw_stat_line(label: String, value: String, y: float, val_color: Color, lbl_color: Color) -> void:
	var size: Vector2 = get_size()
	var x: float = size.x / 2 - 200
	draw_string(_get_body_font(), Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 200, 18, lbl_color)
	draw_string(_get_body_font(), Vector2(x + 200, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 200, 18, val_color)


# ─── Ranking Logic ────────────────────────────────────────────────────────────

func _rank_for_boss_rush(time_sec: float) -> int:
	# Lower time = better rank. Thresholds in seconds.
	if time_sec < 180.0:   # < 3 min
		return Rank.S
	elif time_sec < 300.0: # < 5 min
		return Rank.A
	elif time_sec < 480.0: # < 8 min
		return Rank.B
	elif time_sec < 720.0: # < 12 min
		return Rank.C
	else:
		return Rank.D

func _rank_for_speedrun(time_sec: float) -> int:
	# Speedrun: visiting 8 biomes. Lower time = better rank.
	if time_sec < 240.0:   # < 4 min
		return Rank.S
	elif time_sec < 420.0: # < 7 min
		return Rank.A
	elif time_sec < 600.0: # < 10 min
		return Rank.B
	elif time_sec < 900.0: # < 15 min
		return Rank.C
	else:
		return Rank.D

func _rank_for_endless(wave: int) -> int:
	# Endless: higher wave = better rank.
	if wave >= 100:
		return Rank.S
	elif wave >= 50:
		return Rank.A
	elif wave >= 25:
		return Rank.B
	elif wave >= 10:
		return Rank.C
	else:
		return Rank.D


# ─── Button Handlers ───────────────────────────────────────────────────────────

func _on_play_again() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	_hide()
	# Restart the current mode's run
	GameManager.restart_game()

func _on_quit() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	_hide()
	# Return to main menu — Phase 35: fade transition
	SceneTransition.change_scene("res://scenes/main_menu.tscn")

func _on_button_hover(btn: Button, hovering: bool) -> void:
	if not is_instance_valid(btn):
		return
	if _hover_tweens.has(btn) and is_instance_valid(_hover_tweens[btn] as Tween):
		(_hover_tweens[btn] as Tween).kill()
	var t: Tween = create_tween()
	_hover_tweens[btn] = t
	if hovering:
		t.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		# Subtle hover tick — matches the rest of the UI's hover audio language
		AudioManager.play_sfx(AudioManager.SFX_UI_HOVER)
	else:
		t.tween_property(btn, "scale", Vector2.ONE, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _title_text() -> String:
	match _mode:
		GameModeManager.Mode.BOSS_RUSH:
			return "🏆 BOSS RUSH COMPLETE!"
		GameModeManager.Mode.SPEEDRUN:
			return "🏆 SPEEDRUN COMPLETE!"
		GameModeManager.Mode.ENDLESS:
			return "♾ WAVE %d REACHED!" % _wave
		_:
			return "🏆 VICTORY!"

func _read_pb(key: String) -> float:
	if not Statistics:
		return 0.0
	var v: Variant = Statistics.get_lifetime_stat(key)
	if v == null:
		return 0.0
	return float(v)

func _format_time(seconds: float) -> String:
	var s: float = seconds
	var h: int = int(s) / 3600
	var m: int = (int(s) % 3600) / 60
	var sec: int = int(s) % 60
	var ms: int = int(fmod(s, 1.0) * 100.0)
	if h > 0:
		return "%dh %02dm %02ds.%02d" % [h, m, sec, ms]
	elif m > 0:
		return "%dm %02ds.%02d" % [m, sec, ms]
	else:
		return "%ds.%02d" % [sec, ms]

func _get_title_font() -> Font:
	return get_theme_default_font() as Font

func _get_body_font() -> Font:
	return get_theme_default_font() as Font