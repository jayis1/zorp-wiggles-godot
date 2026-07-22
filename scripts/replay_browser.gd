## Zorp Wiggles — Replay Browser UI (Phase 32: Multiplayer & Social)
## Full-screen overlay for browsing and playing saved replays.
## Press F11 (the "replay_browser" input action) to toggle.
## Shows a list of saved replays with metadata, and a "Play" button.
##
## Uses _draw() for custom rendering — no scene file needed.

extends Control

class_name ReplayBrowser

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _replays: Array[Dictionary] = []
var _selected_idx: int = 0
var _scroll_offset: int = 0
const MAX_ROWS: int = 10


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("replay_browser"):
		_visible_flag = not _visible_flag
		if _visible_flag:
			AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
			_refresh_replays()
	# Smooth fade
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	if _fade_alpha > 0.01 or _visible_flag:
		queue_redraw()


func _refresh_replays() -> void:
	if ReplaySystem:
		_replays = ReplaySystem.get_replay_list()
	_selected_idx = clampi(_selected_idx, 0, max(0, _replays.size() - 1))


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
	var panel_w: float = 800.0
	var panel_h: float = 580.0
	var panel_x: float = (screen.x - panel_w) / 2.0
	var panel_y: float = (screen.y - panel_h) / 2.0
	var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
	draw_rect(panel_rect, Color(0.05, 0.08, 0.15, 0.95 * a), true)
	draw_rect(panel_rect, Color(0.3, 0.5, 0.8, 0.6 * a), false, 2.0)
	# Title
	_draw_centered_text(font, "🎬 REPLAY BROWSER", Vector2(screen.x / 2, panel_y + 30), 28, Color(0.8, 0.9, 1.0, a))
	# Entries
	if _replays.is_empty():
		_draw_centered_text(font, "No saved replays yet — play a run to record one!", Vector2(screen.x / 2, panel_y + 200), 18, Color(0.5, 0.6, 0.7, a * 0.8))
	else:
		_draw_replay_list(font, panel_x + 20, panel_y + 70, panel_w - 40, a)
	# Footer
	_draw_centered_text(font, "[↑↓] Navigate  |  [Enter] Play Ghost  |  [S] Spectate  |  [Del] Delete  |  [F11] Close", Vector2(screen.x / 2, panel_y + panel_h - 15), 13, Color(0.5, 0.6, 0.7, a))


func _draw_replay_list(font, x: float, y: float, w: float, a: float) -> void:
	# Column headers
	_draw_text(font, "#", x + 10, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Mode", x + 50, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Score", x + 160, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Kills", x + 260, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Level", x + 340, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Duration", x + 420, y, 14, Color(0.6, 0.7, 0.8, a))
	_draw_text(font, "Date", x + 540, y, 14, Color(0.6, 0.7, 0.8, a))
	# Separator
	draw_line(Vector2(x, y + 22), Vector2(x + w, y + 22), Color(0.3, 0.4, 0.5, 0.4 * a), 1.0)
	# Rows
	var row_y: float = y + 34
	var row_h: float = 32.0
	for i in min(_replays.size(), MAX_ROWS):
		var idx: int = i + _scroll_offset
		if idx >= _replays.size():
			break
		var e: Dictionary = _replays[idx]
		var is_selected: bool = idx == _selected_idx
		# Highlight selected row
		if is_selected:
			draw_rect(Rect2(x - 5, row_y - 4, w + 10, row_h - 2), Color(0.15, 0.25, 0.4, 0.7 * a), true)
		var row_color: Color = Color(0.9, 0.95, 1.0, a) if is_selected else Color(0.75, 0.8, 0.9, a)
		_draw_text(font, "#%d" % (idx + 1), x + 10, row_y, 14, row_color)
		_draw_text(font, String(e.get("mode", "Normal")), x + 50, row_y, 14, row_color)
		_draw_text(font, "%d" % int(e.get("score", 0)), x + 160, row_y, 14, row_color)
		_draw_text(font, "%d" % int(e.get("kills", 0)), x + 260, row_y, 14, row_color)
		_draw_text(font, "Lv %d" % int(e.get("level", 1)), x + 340, row_y, 14, row_color)
		_draw_text(font, _format_time(float(e.get("duration", 0))), x + 420, row_y, 14, row_color)
		var ts: String = String(e.get("timestamp", ""))
		if " " in ts:
			ts = ts.split(" ")[0]
		_draw_text(font, ts, x + 540, row_y, 12, row_color)
		row_y += row_h


func _unhandled_input(event: InputEvent) -> void:
	if not _visible_flag:
		return
	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		match ke.keycode:
			KEY_UP:
				_selected_idx = max(0, _selected_idx - 1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_selected_idx = min(max(0, _replays.size() - 1), _selected_idx + 1)
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if _selected_idx >= 0 and _selected_idx < _replays.size() and ReplaySystem:
					var rid: String = String(_replays[_selected_idx].get("id", ""))
					if not rid.is_empty():
						ReplaySystem.play_replay(rid)
						GameManager.add_message("🎬 Playing replay ghost...")
						_visible_flag = false
				get_viewport().set_input_as_handled()
			KEY_S:
				# Phase 32: Spectate the selected replay with free-look camera
				if _selected_idx >= 0 and _selected_idx < _replays.size() and SpectatorMode:
					var rid: String = String(_replays[_selected_idx].get("id", ""))
					if not rid.is_empty():
						_visible_flag = false
						SpectatorMode.start_spectating(rid)
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				if _selected_idx >= 0 and _selected_idx < _replays.size() and ReplaySystem:
					var rid: String = String(_replays[_selected_idx].get("id", ""))
					if not rid.is_empty():
						ReplaySystem.delete_replay(rid)
						_refresh_replays()
						GameManager.add_message("🗑 Replay deleted")
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