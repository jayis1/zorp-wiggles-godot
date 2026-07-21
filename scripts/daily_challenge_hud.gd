## Zorp Wiggles — Daily Challenge HUD (Phase 25: Progression & Meta-Systems)
##
## Top-center HUD overlay shown during a Daily Challenge run. Displays:
##   - "📅 DAILY CHALLENGE" title with today's date
##   - The shareable seed string
##   - The active daily modifiers (icon + name)
##   - Today's best score (if attempted)
##   - A subtle gold-accented panel
##
## The overlay is added to the HUD canvas layer by hud.gd on _ready.
## It auto-shows when GameModeManager.is_daily_challenge() is true.

extends Control

class_name DailyChallengeHud

var _visible_flag: bool = false
var _fade_alpha: float = 0.0

# Cached info for the draw routine
var _date_str: String = ""
var _seed_str: String = ""
var _modifier_info: Array[Dictionary] = []
var _today_best: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Connect to relevant signals for live updates
	if DailyChallengeSystem:
		DailyChallengeSystem.daily_best_updated.connect(_on_daily_best_updated)
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
	if not GameModeManager or not GameModeManager.is_daily_challenge():
		return false
	if not GameManager or not GameManager.player_is_alive:
		return false
	return true

func _refresh_info() -> void:
	if not DailyChallengeSystem:
		return
	_date_str = DailyChallengeSystem.get_today_date_string()
	_seed_str = DailyChallengeSystem.get_today_seed_string()
	_modifier_info = DailyChallengeSystem.get_today_modifier_info()
	_today_best = DailyChallengeSystem.get_today_best()

func _on_mode_changed(_new_mode: int) -> void:
	_refresh_info()
	queue_redraw()

func _on_daily_best_updated(_score: int) -> void:
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
	# Panel background — gold-accented
	var panel_w: float = 360.0
	var panel_h: float = 90.0
	var panel_rect := Rect2(screen.x / 2.0 - panel_w / 2.0, 8.0, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.08, 0.06, 0.02, 0.75 * a), true)
	draw_rect(panel_rect, Color(0.95, 0.75, 0.3, 0.6 * a), false, 1.5)
	# Title "📅 DAILY CHALLENGE"
	var title_text: String = "📅 DAILY CHALLENGE"
	var title_size: Vector2 = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - title_size.x) / 2.0, panel_rect.position.y + 18.0),
		title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.95, 0.75, 0.3, a))
	# Date
	var date_text: String = _date_str
	var date_size: Vector2 = font.get_string_size(date_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - date_size.x) / 2.0, panel_rect.position.y + 34.0),
		date_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.7, 0.7, 0.75, 0.8 * a))
	# Seed
	var seed_text: String = "Seed: %s" % _seed_str
	var seed_size: Vector2 = font.get_string_size(seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	font.draw_string(get_canvas_item(),
		Vector2(panel_rect.position.x + (panel_rect.size.x - seed_size.x) / 2.0, panel_rect.position.y + 48.0),
		seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.5, 0.6, 0.75, 0.7 * a))
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
			Color(0.85, 0.7, 0.4, 0.85 * a))
		mod_x += entry_size.x + 10.0
	# Today's best (if attempted)
	if not _today_best.is_empty():
		var best_text: String = "Today's Best: %d" % int(_today_best.get("score", 0))
		var best_size: Vector2 = font.get_string_size(best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		font.draw_string(get_canvas_item(),
			Vector2(panel_rect.position.x + (panel_rect.size.x - best_size.x) / 2.0, panel_rect.position.y + panel_rect.size.y - 8.0),
			best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.95, 0.85, 0.5, 0.9 * a))