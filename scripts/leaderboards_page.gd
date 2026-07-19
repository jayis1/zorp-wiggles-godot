## Zorp Wiggles — Leaderboards UI (Phase 32: Multiplayer & Social)
## Full-screen overlay showing the local high-score leaderboards.
## Press F12 (the "leaderboards" input action) to toggle.
## Shows top entries per game mode, with tab switching (1-4 keys).
## Also includes a "Challenge Seed" panel for sharing/entering seeds.
##
## Uses _draw() for custom rendering — no scene file needed.

extends Control

class_name LeaderboardsPage

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _current_tab: int = 0
const TAB_NAMES: Array[String] = ["Normal", "Endless", "Boss Rush", "Speedrun"]
const TAB_ICONS: Array[String] = ["🌍", "♾", "💀", "⏱"]
const MAX_ROWS: int = 12

# Challenge seed input state
var _seed_input: String = ""
var _seed_input_active: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("leaderboards"):
		_visible_flag = not _visible_flag
		if _visible_flag:
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			_seed_input = ""
			_seed_input_active = false
	# Tab switching with 1-4 keys when visible
	if _visible_flag:
		if Input.is_key_pressed(KEY_1): _current_tab = 0
		elif Input.is_key_pressed(KEY_2): _current_tab = 1
		elif Input.is_key_pressed(KEY_3): _current_tab = 2
		elif Input.is_key_pressed(KEY_4): _current_tab = 3
	# Smooth fade
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	# Full-screen dim background
	var bg := Color(0.02, 0.03, 0.08, 0.88 * a)
	draw_rect(Rect2(Vector2.ZERO, screen), bg, true)
	# Main panel
	var panel_w: float = 900.0
	var panel_h: float = 620.0
	var panel_x: float = (screen.x - panel_w) / 2.0
	var panel_y: float = (screen.y - panel_h) / 2.0
	var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.05, 0.08, 0.15, 0.95 * a), true)
	# Border
	draw_rect(panel_rect, Color(0.3, 0.5, 0.8, 0.6 * a), false, 2.0)
	# Title
	_draw_centered_text(font, "🏆 LEADERBOARDS", Vector2(screen.x / 2, panel_y + 30), 28, Color(1.0, 0.85, 0.3, a))
	# Tab buttons
	var tab_y: float = panel_y + 60
	var tab_w: float = 200.0
	for i in TAB_NAMES.size():
		var tx: float = panel_x + 20 + i * (tab_w + 10)
		var tab_rect := Rect2(tx, tab_y, tab_w, 36)
		var is_selected: bool = i == _current_tab
		var tab_color: Color = Color(0.15, 0.25, 0.4, 0.9 * a) if is_selected else Color(0.08, 0.12, 0.2, 0.7 * a)
		draw_rect(tab_rect, tab_color, true)
		draw_rect(tab_rect, Color(0.4, 0.6, 0.9, 0.5 * a) if is_selected else Color(0.2, 0.3, 0.5, 0.3 * a), false, 1.0)
		_draw_centered_text(font, "%s  %s" % [TAB_ICONS[i], TAB_NAMES[i]], Vector2(tx + tab_w / 2, tab_y + 18), 16, Color(0.9, 0.95, 1.0, a))
	# Entries
	var entries: Array[Dictionary] = []
	if Leaderboards:
		entries = Leaderboards.get_leaderboard(TAB_NAMES[_current_tab])
	_draw_entries(font, panel_x, tab_y + 50, panel_w - 40, entries, a)
	# Challenge seed panel at the bottom
	_draw_seed_panel(font, panel_x, panel_y + panel_h - 80, panel_w, a)
	# Footer
	_draw_centered_text(font, "[1-4] Switch Tabs  |  [F12] Close  |  [S] Share Current Seed", Vector2(screen.x / 2, panel_y + panel_h - 15), 13, Color(0.5, 0.6, 0.7, a))


func _draw_entries(font, x: float, y: float, w: float, entries: Array[Dictionary], a: float) -> void:
	# Column headers
	var header_y: float = y
	var rank_x: float = x + 10
	var name_x: float = x + 60
	var score_x: float = x + 280
	var kills_x: float = x + 400
	var level_x: float = x + 480
	var time_x: float = x + 560
	var date_x: float = x + 660
	_draw_text(font, "#", rank_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Name", name_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	if _current_tab == 3:  # Speedrun — time is the score
		_draw_text(font, "Time", score_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	else:
		_draw_text(font, "Score", score_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Kills", kills_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Level", level_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Duration", time_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Date", date_x, header_y, 14, Color(0.6, 0.7, 0.8, a))
	# Separator
	draw_line(Vector2(x, header_y + 22), Vector2(x + w, header_y + 22), Color(0.3, 0.4, 0.5, 0.4 * a), 1.0)
	# Rows
	if entries.is_empty():
		_draw_centered_text(font, "No scores yet — play a run to get on the board!", Vector2(x + w / 2, y + 60), 16, Color(0.5, 0.6, 0.7, a * 0.8))
		return
	var row_y: float = header_y + 34
	var row_h: float = 28.0
	for i in min(entries.size(), MAX_ROWS):
		var e: Dictionary = entries[i]
		var is_top: bool = i == 0
		var row_color: Color = Color(1.0, 0.85, 0.3, a) if is_top else Color(0.85, 0.9, 1.0, a)
		# Rank
		var rank_str: String = "#%d" % (i + 1)
		if is_top:
			rank_str = "🥇 " + rank_str
		elif i == 1:
			rank_str = "🥈 " + rank_str
		elif i == 2:
			rank_str = "🥉 " + rank_str
		_draw_text(font, rank_str, rank_x, row_y, 14, row_color)
		# Name
		_draw_text(font, String(e.get("name", "???")), name_x, row_y, 14, row_color)
		# Score / Time
		if _current_tab == 3:
			_draw_text(font, _format_time(float(e.get("time", 0))), score_x, row_y, 14, row_color)
		else:
			_draw_text(font, "%d" % int(e.get("score", 0)), score_x, row_y, 14, row_color)
		# Kills
		_draw_text(font, "%d" % int(e.get("kills", 0)), kills_x, row_y, 14, row_color)
		# Level
		_draw_text(font, "Lv %d" % int(e.get("level", 1)), level_x, row_y, 14, row_color)
		# Duration
		_draw_text(font, _format_time(float(e.get("time", 0))), time_x, row_y, 14, row_color)
		# Date (just the date part, not time)
		var ts: String = String(e.get("timestamp", ""))
		if " " in ts:
			ts = ts.split(" ")[0]
		_draw_text(font, ts, date_x, row_y, 12, Color(0.6, 0.7, 0.8, a))
		row_y += row_h


func _draw_seed_panel(font, x: float, y: float, w: float, a: float) -> void:
	# Background
	var panel_rect := Rect2(x + 20, y, w - 40, 60)
	draw_rect(panel_rect, Color(0.08, 0.12, 0.2, 0.8 * a), true)
	draw_rect(panel_rect, Color(0.2, 0.3, 0.5, 0.4 * a), false, 1.0)
	# Label
	_draw_text(font, "🎯 Challenge Seed:", x + 35, y + 10, 14, Color(0.7, 0.85, 1.0, a))
	# Current seed display
	var current_seed: String = ""
	if Leaderboards:
		current_seed = Leaderboards.get_share_seed()
	_draw_text(font, "Current: %s" % current_seed, x + 200, y + 10, 14, Color(0.5, 0.8, 0.5, a))
	# Input field
	var input_label: String = "Enter seed: %s_" % _seed_input if _seed_input_active else "[E] Enter a friend's seed"
	_draw_text(font, input_label, x + 500, y + 10, 13, Color(0.8, 0.8, 0.4, a) if _seed_input_active else Color(0.5, 0.6, 0.7, a))


func _unhandled_input(event: InputEvent) -> void:
	if not _visible_flag:
		return
	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		if _seed_input_active:
			# Handle seed input
			if ke.keycode == KEY_ESCAPE:
				_seed_input_active = false
				_seed_input = ""
			elif ke.keycode == KEY_ENTER:
				# Apply the seed
				if not _seed_input.is_empty() and Leaderboards:
					if Leaderboards.apply_share_seed(_seed_input):
						GameManager.add_message("🎯 Challenge seed applied!")
					else:
						GameManager.add_message("⚠ Invalid seed — check the format")
				_seed_input_active = false
				_seed_input = ""
			elif ke.keycode == KEY_BACKSPACE:
				if not _seed_input.is_empty():
					_seed_input = _seed_input.substr(0, _seed_input.length() - 1)
			elif ke.unicode != 0 and ke.unicode >= 32:
				# Accept printable characters
				_seed_input += String(chr(ke.unicode))
			get_viewport().set_input_as_handled()
		else:
			if ke.keycode == KEY_E:
				_seed_input_active = true
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_S:
				# Copy current seed to clipboard
				if Leaderboards:
					var seed: String = Leaderboards.get_share_seed()
					DisplayServer.clipboard_set(seed)
					GameManager.add_message("📋 Seed copied to clipboard: %s" % seed)
				get_viewport().set_input_as_handled()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _draw_text(font, text: String, x: float, y: float, size: int, color: Color) -> void:
	font.draw_string(get_canvas_item(), Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_centered_text(font, text: String, pos: Vector2, size: int, color: Color) -> void:
	font.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)


func _format_time(t: float) -> String:
	var mins: int = int(t) / 60
	var secs: int = int(t) % 60
	return "%d:%02d" % [mins, secs]