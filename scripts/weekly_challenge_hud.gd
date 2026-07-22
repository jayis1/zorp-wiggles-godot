## Zorp Wiggles — Weekly Challenge HUD (Phase 25: Progression & Meta-Systems)
##
## Top-center HUD overlay shown during a Weekly Challenge run. Displays:
##   - "📅 WEEKLY CHALLENGE" title with the current ISO week
##   - The shareable seed string
##   - The active weekly modifiers (icon + name)
##   - This week's best score (if attempted)
##   - Attempts remaining indicator
##   - A subtle purple-accented panel (distinct from daily's gold)
##
## The overlay is added to the HUD canvas layer by hud.gd on _ready.
## It auto-shows when GameModeManager.is_weekly_challenge() is true.

extends Control

class_name WeeklyChallengeHud

var _visible_flag: bool = false
var _fade_alpha: float = 0.0

# Cached info for the draw routine
var _week_str: String = ""
var _seed_str: String = ""
var _modifier_info: Array[Dictionary] = []
var _week_best: Dictionary = {}
var _attempts_remaining: int = 3

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if WeeklyChallengeSystem:
		WeeklyChallengeSystem.weekly_best_updated.connect(_on_weekly_best_updated)
	if GameModeManager:
		GameModeManager.mode_changed.connect(_on_mode_changed)

func _process(delta: float) -> void:
	var should_show: bool = _should_show()
	if should_show != _visible_flag:
		_visible_flag = should_show
		if should_show:
			_refresh_info()
	visible = _visible_flag or _fade_alpha > 0.01
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 4.0)
	if _fade_alpha > 0.01:
		queue_redraw()

func _should_show() -> bool:
	if not GameModeManager or not GameModeManager.is_weekly_challenge():
		return false
	if not GameManager or not GameManager.player_is_alive:
		return false
	return true

func _refresh_info() -> void:
	if not WeeklyChallengeSystem:
		return
	_week_str = WeeklyChallengeSystem.get_week_string()
	_seed_str = WeeklyChallengeSystem.get_week_seed_string()
	_modifier_info = WeeklyChallengeSystem.get_week_modifier_info()
	_week_best = WeeklyChallengeSystem.get_week_best()
	_attempts_remaining = WeeklyChallengeSystem.get_attempts_remaining()

func _on_mode_changed(_new_mode: int) -> void:
	_refresh_info()
	queue_redraw()

func _on_weekly_best_updated(_score: int) -> void:
	_refresh_info()
	queue_redraw()

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var a: float = _fade_alpha
	var font := get_theme_default_font()
	if not font:
		return
	var screen := size
	# Panel background — purple-accented (distinct from daily's gold)
	var panel_w: float = 380.0
	var panel_h: float = 100.0
	var panel_rect := Rect2(screen.x / 2.0 - panel_w / 2.0, 8.0, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.06, 0.03, 0.08, 0.78 * a), true)
	draw_rect(panel_rect, Color(0.6, 0.4, 0.9, 0.6 * a), false, 1.5)
	# Title "📅 WEEKLY CHALLENGE"
	var title_text: String = "📅 WEEKLY CHALLENGE"
	var title_size: Vector2 = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - title_size.x) / 2.0, panel_rect.position.y + 18.0),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.7, 0.5, 1.0, a))
	# Week string
	var week_text: String = _week_str
	var week_size: Vector2 = font.get_string_size(week_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - week_size.x) / 2.0, panel_rect.position.y + 34.0),
		week_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.7, 0.65, 0.8, 0.8 * a))
	# Seed
	var seed_text: String = "Seed: %s" % _seed_str
	var seed_size: Vector2 = font.get_string_size(seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - seed_size.x) / 2.0, panel_rect.position.y + 48.0),
		seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.5, 0.55, 0.7, 0.7 * a))
	# Attempts remaining
	var attempt_text: String = "Attempts: %d/%d" % [_attempts_remaining, WeeklyChallengeSystem.WEEKLY_MAX_ATTEMPTS]
	var attempt_size: Vector2 = font.get_string_size(attempt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + panel_rect.size.x - attempt_size.x - 12.0, panel_rect.position.y + 48.0),
		attempt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.8, 0.6, 1.0, 0.85 * a))
	# Modifiers (icon + name, inline)
	var mod_y: float = panel_rect.position.y + 64.0
	var mod_x: float = panel_rect.position.x + 12.0
	for info in _modifier_info:
		var icon_str: String = str(info.get("icon", ""))
		var name_str: String = str(info.get("name", ""))
		var entry_text: String = "%s %s" % [icon_str, name_str]
		var entry_size: Vector2 = font.get_string_size(entry_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		if mod_x + entry_size.x > panel_rect.position.x + panel_rect.size.x - 12.0:
			break
		font.draw_string(get_canvas_item(),
			Vector2(mod_x, mod_y),
			entry_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.75, 0.6, 0.9, 0.85 * a))
		mod_x += entry_size.x + 10.0
	# This week's best (if attempted)
	if not _week_best.is_empty():
		var best_text: String = "Week's Best: %d" % int(_week_best.get("score", 0))
		var best_size: Vector2 = font.get_string_size(best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		font.draw_string(get_canvas_item(),
			Vector2(panel_rect.position.x + (panel_rect.size.x - best_size.x) / 2.0, panel_rect.position.y + panel_rect.size.y - 8.0),
			best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.9, 0.75, 1.0, 0.9 * a))