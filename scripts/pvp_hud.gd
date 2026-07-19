## Zorp Wiggles — PvP Arena HUD (Phase 32: Multiplayer & Social)
## Overlay HUD for PvP arena mode. Shows both players' HP bars, round wins,
## round timer, and match progress. Only visible when PvP is active.
##
## Uses _draw() for custom rendering — no scene file needed.

extends Control

class_name PvpHud

var _fade_alpha: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Fade in/out based on PvP activity
	var target: float = 1.0 if (PvpArena and PvpArena.is_pvp_active()) else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 4.0)
	if _fade_alpha > 0.01:
		queue_redraw()


func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	if not PvpArena or not PvpArena.is_pvp_active():
		return
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	var state: Dictionary = PvpArena.get_pvp_state()
	# ── Top bar: round wins + timer ──
	var bar_h: float = 60.0
	var bar_rect := Rect2(0, 0, screen.x, bar_h)
	draw_rect(bar_rect, Color(0.02, 0.03, 0.08, 0.85 * a), true)
	# P1 wins (left)
	var p1_wins: int = int(state.get("p1_wins", 0))
	var p2_wins: int = int(state.get("p2_wins", 0))
	var best_of: int = int(state.get("best_of", 3))
	var wins_needed: int = int(best_of / 2) + 1
	_draw_text(font, "ZORP", 30, 15, 18, Color(0.4, 0.9, 1.0, a))
	for i in wins_needed:
		var dot_x: float = 110 + i * 24
		var filled: bool = i < p1_wins
		draw_circle(Vector2(dot_x, 24), 8, Color(0.3, 0.5, 0.7, 0.5 * a) if not filled else Color(0.4, 0.9, 1.0, a))
	# P2 wins (right)
	_draw_text(font, "ZERP", screen.x - 80, 15, 18, Color(1.0, 0.4, 0.8, a))
	for i in wins_needed:
		var dot_x: float = screen.x - 140 - i * 24
		var filled: bool = i < p2_wins
		draw_circle(Vector2(dot_x, 24), 8, Color(0.5, 0.3, 0.5, 0.5 * a) if not filled else Color(1.0, 0.4, 0.8, a))
	# Round info (center)
	var round_num: int = int(state.get("round", 0))
	var round_text: String = "Round %d" % round_num
	if bool(state.get("intermission", false)):
		round_text = "Next round soon..."
	_draw_centered_text(font, round_text, Vector2(screen.x / 2, 22), 20, Color(1.0, 0.9, 0.5, a))
	# Timer
	var timer: float = float(state.get("round_timer", 0))
	if timer > 0:
		var timer_str: String = "%d" % int(timer)
		var timer_color: Color = Color(0.8, 0.9, 1.0, a) if timer > 20 else Color(1.0, 0.7, 0.3, a) if timer > 10 else Color(1.0, 0.3, 0.3, a)
		_draw_centered_text(font, timer_str, Vector2(screen.x / 2, 45), 16, timer_color)
	# ── HP bars ──
	var p1_hp: int = int(state.get("p1_hp", 0))
	var p1_max: int = int(state.get("p1_max_hp", 100))
	var p2_hp: int = int(state.get("p2_hp", 0))
	var p2_max: int = int(state.get("p2_max_hp", 100))
	# P1 HP bar (bottom-left)
	var hp_bar_w: float = 280.0
	var hp_bar_h: float = 24.0
	var p1_bar_x: float = 30.0
	var p1_bar_y: float = screen.y - 50.0
	_draw_hp_bar(p1_bar_x, p1_bar_y, hp_bar_w, hp_bar_h, p1_hp, p1_max, Color(0.4, 0.9, 1.0), a, "ZORP", font)
	# P2 HP bar (bottom-right)
	var p2_bar_x: float = screen.x - 30 - hp_bar_w
	var p2_bar_y: float = screen.y - 50.0
	_draw_hp_bar(p2_bar_x, p2_bar_y, hp_bar_w, hp_bar_h, p2_hp, p2_max, Color(1.0, 0.4, 0.8), a, "ZERP", font)


func _draw_hp_bar(x: float, y: float, w: float, h: float, hp: int, max_hp: int, color: Color, a: float, label: String, font) -> void:
	# Background
	draw_rect(Rect2(x, y, w, h), Color(0.1, 0.12, 0.18, 0.9 * a), true)
	draw_rect(Rect2(x, y, w, h), Color(0.3, 0.4, 0.5, 0.5 * a), false, 1.0)
	# Fill
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
	var fill_w: float = w * ratio
	# Color shifts from green to yellow to red
	var fill_color: Color = color
	if ratio < 0.3:
		fill_color = Color(1.0, 0.3, 0.3, a)
	elif ratio < 0.6:
		fill_color = Color(1.0, 0.8, 0.3, a)
	draw_rect(Rect2(x, y, fill_w, h), fill_color, true)
	# Label
	_draw_text(font, label, x + 8, y + 4, 14, Color(1.0, 1.0, 1.0, a))
	# HP text
	var hp_text: String = "%d / %d" % [hp, max_hp]
	_draw_text(font, hp_text, x + w - 80, y + 4, 14, Color(1.0, 1.0, 1.0, a))


# ── Helpers ───────────────────────────────────────────────────────────────────

func _draw_text(font, text: String, x: float, y: float, size: int, color: Color) -> void:
	font.draw_string(get_canvas_item(), Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_centered_text(font, text: String, pos: Vector2, size: int, color: Color) -> void:
	font.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)