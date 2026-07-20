## Zorp Wiggles — Pet Training Menu UI (Phase 27)
## Full-screen overlay for starting mini-games and spending Training Points (TP)
## on permanent pet stat upgrades. Press Shift+T (the "pet_training" input action)
## to toggle. Uses _draw() + _gui_input() pattern.

extends Control

class_name PetTrainingMenuUI

var _visible_flag: bool = false
var _fade_alpha: float = 0.0

# Clickable regions
var _game_rects: Dictionary = {}   # game_id → Rect2 (start button)
var _stat_rects: Dictionary = {}   # stat_id → Rect2 (spend TP button)
var _close_btn_rect: Rect2 = Rect2()
var _cancel_btn_rect: Rect2 = Rect2()

const PANEL_COLOR: Color = Color(0.08, 0.06, 0.12, 0.92)
const BORDER_COLOR: Color = Color(0.4, 0.3, 0.6, 0.8)
const TEXT_COLOR: Color = Color(0.85, 0.85, 0.95)
const HOVER_COLOR: Color = Color(0.2, 0.15, 0.3, 0.8)
const BTN_COLOR: Color = Color(0.25, 0.2, 0.4, 0.9)
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)
const GREEN_COLOR: Color = Color(0.3, 0.9, 0.4)
const RED_COLOR: Color = Color(0.9, 0.3, 0.3)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if PetTrainingSystem:
		PetTrainingSystem.tp_changed.connect(_on_changed)
		PetTrainingSystem.stat_upgraded.connect(_on_changed)
		PetTrainingSystem.game_started.connect(_on_changed)
		PetTrainingSystem.game_completed.connect(_on_changed)


func _on_changed(_a = null, _b = null, _c = null) -> void:
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pet_training"):
		if GameManager and not GameManager.is_paused and GameManager.player_is_alive:
			_visible_flag = not _visible_flag
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	if _visible_flag and Input.is_action_just_pressed("pause"):
		_visible_flag = false
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	mouse_filter = Control.MOUSE_FILTER_STOP if _fade_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _visible_flag or _fade_alpha < 0.5:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos: Vector2 = event.position
		if _close_btn_rect.has_point(mouse_pos):
			_visible_flag = false
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			return
		if _cancel_btn_rect.has_point(mouse_pos):
			PetTrainingSystem.cancel_game()
			return
		for gid in _game_rects:
			if _game_rects[gid].has_point(mouse_pos):
				PetTrainingSystem.start_game(gid)
				return
		for sid in _stat_rects:
			if _stat_rects[sid].has_point(mouse_pos):
				PetTrainingSystem.spend_tp(sid)
				return


func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var alpha: float = _fade_alpha
	var screen_size: Vector2 = get_rect().size
	if screen_size.x < 10:
		screen_size = Vector2(1280, 720)

	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.7 * alpha))

	var panel_w: float = 720.0
	var panel_h: float = 580.0
	var panel_pos: Vector2 = Vector2((screen_size.x - panel_w) / 2, (screen_size.y - panel_h) / 2)
	var panel_rect: Rect2 = Rect2(panel_pos, Vector2(panel_w, panel_h))
	draw_rect(panel_rect, Color(PANEL_COLOR.r, PANEL_COLOR.g, PANEL_COLOR.b, PANEL_COLOR.a * alpha))
	_draw_border(panel_rect, BORDER_COLOR * alpha)

	# Title
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, 36), "🎓 PET TRAINING",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT_COLOR * alpha)

	# TP display
	var tp: int = PetTrainingSystem.get_tp()
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(panel_w - 180, 36),
		"TP: %d / %d" % [tp, GameConstants.PET_TRAINING_MAX_TP_PER_RUN],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD_COLOR * alpha)

	# Close button
	_close_btn_rect = Rect2(panel_pos + Vector2(panel_w - 40, 10), Vector2(30, 30))
	draw_rect(_close_btn_rect, Color(BTN_COLOR.r, BTN_COLOR.g, BTN_COLOR.b, BTN_COLOR.a * alpha))
	draw_string(ThemeDB.fallback_font, _close_btn_rect.position + Vector2(8, 22), "✕",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT_COLOR * alpha)

	var y: float = panel_pos.y + 56

	# ── Active game status ──
	if PetTrainingSystem.is_game_active():
		var game_id: int = PetTrainingSystem.get_current_game()
		var time_left: float = PetTrainingSystem.get_time_remaining()
		var progress: String = PetTrainingSystem.get_progress_text()
		draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 16),
			"ACTIVE: %s" % GameConstants.PET_TRAINING_GAME_NAMES[game_id],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD_COLOR * alpha)
		draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 36),
			"Time: %.1fs | %s" % [time_left, progress],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR * alpha)
		# Cancel button
		_cancel_btn_rect = Rect2(panel_pos + Vector2(panel_w - 140, y + 10), Vector2(110, 30))
		draw_rect(_cancel_btn_rect, Color(0.4, 0.15, 0.15, 0.9 * alpha))
		draw_string(ThemeDB.fallback_font, _cancel_btn_rect.position + Vector2(30, 20),
			"CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED_COLOR * alpha)
		y += 60
	else:
		# ── Mini-game selection ──
		draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 16),
			"MINI-GAMES:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD_COLOR * alpha)
		y += 28
		_game_rects.clear()
		for gid in range(3):
			var gx: float = panel_pos.x + 20
			var gw: float = panel_w - 40
			var gh: float = 60.0
			var game_rect: Rect2 = Rect2(Vector2(gx, y), Vector2(gw, gh))
			draw_rect(game_rect, Color(0.12, 0.1, 0.18, 0.8 * alpha))
			_draw_border(game_rect, BORDER_COLOR * alpha)
			draw_string(ThemeDB.fallback_font, Vector2(gx + 10, y + 20),
				GameConstants.PET_TRAINING_GAME_NAMES[gid],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR * alpha)
			draw_string(ThemeDB.fallback_font, Vector2(gx + 10, y + 38),
				GameConstants.PET_TRAINING_GAME_DESCS[gid],
				HORIZONTAL_ALIGNMENT_LEFT, int(gw - 140), 11, Color(0.6, 0.6, 0.7, alpha))
			# Start button
			var btn_rect: Rect2 = Rect2(Vector2(gx + gw - 120, y + 15), Vector2(100, 30))
			draw_rect(btn_rect, Color(0.2, 0.3, 0.15, 0.9 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(28, 20),
				"START", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN_COLOR * alpha)
			_game_rects[gid] = btn_rect
			y += gh + 6

	# ── Stat upgrades ──
	y = panel_pos.y + 360
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, y + 16),
		"STAT UPGRADES:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD_COLOR * alpha)
	y += 28
	_stat_rects.clear()
	var stat_count: int = GameConstants.PET_TRAINING_STAT_NAMES.size()
	for sid in range(stat_count):
		var sx: float = panel_pos.x + 20 + float(sid % 2) * 340
		var sy: float = y + float(int(floor(float(sid) / 2))) * 50
		var stat_rect: Rect2 = Rect2(Vector2(sx, sy), Vector2(320, 42))
		draw_rect(stat_rect, Color(0.12, 0.1, 0.18, 0.8 * alpha))
		_draw_border(stat_rect, BORDER_COLOR * alpha)
		var level: int = PetTrainingSystem.get_stat_level(sid)
		var cost: int = GameConstants.PET_TRAINING_STAT_COSTS[sid]
		var maxed: bool = level >= GameConstants.PET_TRAINING_MAX_POINTS_PER_STAT
		var can_buy: bool = not maxed and tp >= cost
		var stat_name: String = GameConstants.PET_TRAINING_STAT_NAMES[sid]
		var bonus: float = GameConstants.PET_TRAINING_STAT_BONUSES[sid]
		draw_string(ThemeDB.fallback_font, Vector2(sx + 10, sy + 18),
			"%s (Lv%d: +%s)" % [stat_name, level, str(bonus)],
			HORIZONTAL_ALIGNMENT_LEFT, 240, 13, TEXT_COLOR * alpha)
		# Buy button
		var btn_rect: Rect2 = Rect2(Vector2(sx + 230, sy + 8), Vector2(80, 26))
		if maxed:
			draw_rect(btn_rect, Color(0.15, 0.3, 0.15, 0.6 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(12, 18),
				"MAXED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN_COLOR * alpha)
		elif can_buy:
			_stat_rects[sid] = btn_rect
			draw_rect(btn_rect, Color(0.2, 0.3, 0.15, 0.9 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(12, 18),
				"+1 (%dTP)" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD_COLOR * alpha)
		else:
			draw_rect(btn_rect, Color(0.2, 0.15, 0.15, 0.6 * alpha))
			draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(10, 18),
				"%d TP" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.4, 0.4, alpha))

	# Footer
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(20, panel_pos.y + panel_h - 24),
		"Shift+T to close | Win mini-games for TP | TP boosts pet stats for the current run",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.6, alpha))


func _draw_border(rect: Rect2, color: Color) -> void:
	var w: float = 2.0
	draw_rect(rect, color, false, w)