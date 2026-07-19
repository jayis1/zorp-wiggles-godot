## Zorp Wiggles — Mode Selector UI (Phase 25: Progression & Meta-Systems)
## Full-screen overlay on the main menu that lets the player choose a game mode.
## Shows 4 mode cards (Normal, Endless, Boss Rush, Speedrun) with icons,
## descriptions, and the currently selected mode highlighted.
## Click a card to select it, then click "Start" to begin.
##
## This is added as a child of the MainMenu control. It reads/writes the
## selected mode via GameModeManager (which persists the choice to disk).

extends Control

class_name ModeSelectorUI

var _visible_flag: bool = false
var _fade_alpha: float = 0.0
var _hovered_mode: int = -1
var _mode_rects: Array[Rect2] = []
var _start_btn_rect: Rect2 = Rect2()
var _back_btn_rect: Rect2 = Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func show_selector() -> void:
	_visible_flag = true
	visible = true
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func hide_selector() -> void:
	_visible_flag = false
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func _process(delta: float) -> void:
	var target: float = 1.0 if _visible_flag else 0.0
	_fade_alpha = move_toward(_fade_alpha, target, delta * 6.0)
	mouse_filter = Control.MOUSE_FILTER_STOP if _fade_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _fade_alpha < 0.01 and not _visible_flag:
		visible = false
	if _fade_alpha > 0.01:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _visible_flag or _fade_alpha < 0.5:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		# Back button
		if _back_btn_rect.has_point(mouse_pos):
			hide_selector()
			return
		# Start button
		if _start_btn_rect.has_point(mouse_pos):
			_start_game()
			return
		# Mode cards
		for i in _mode_rects.size():
			if _mode_rects[i].has_point(mouse_pos):
				if i < GameModeManager.MODE_NAMES.size():
					GameModeManager.set_mode(i)
					AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
				return
	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var new_hover: int = -1
		for i in _mode_rects.size():
			if _mode_rects[i].has_point(mouse_pos):
				new_hover = i
				break
		if new_hover != _hovered_mode:
			_hovered_mode = new_hover
			queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_selector()

func _start_game() -> void:
	AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	# Start biome music once the game scene loads
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _draw() -> void:
	if _fade_alpha < 0.01:
		return
	_mode_rects.clear()
	var font := get_theme_default_font()
	if not font:
		return
	var a: float = _fade_alpha
	var screen := size
	# Full-screen dim background
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.03, 0.08, 0.92 * a), true)
	# Title
	_draw_centered_text(font, "🎮 SELECT GAME MODE", Vector2(screen.x / 2.0, 50.0), 30,
		Color(0.4, 1.0, 0.6, a))
	# Mode cards — 4x2 grid (8 modes)
	var cols: int = 4
	var rows: int = 2
	var card_w: float = minf(280.0, (screen.x - 100.0) / float(cols))
	var card_h: float = 170.0
	var gap: float = 20.0
	var grid_w: float = card_w * cols + gap * (cols - 1)
	var grid_h: float = card_h * rows + gap * (rows - 1)
	var start_x: float = (screen.x - grid_w) / 2.0
	var start_y: float = 100.0
	var current_mode: int = GameModeManager.get_current_mode() if GameModeManager else 0
	for i in GameModeManager.MODE_NAMES.size():
		var col: int = i % cols
		var row: int = i / cols
		var card_x: float = start_x + col * (card_w + gap)
		var card_y: float = start_y + row * (card_h + gap)
		var card_rect := Rect2(card_x, card_y, card_w, card_h)
		_mode_rects.append(card_rect)
		_draw_mode_card(font, i, card_rect, a, current_mode)
	# Start button (bottom-center)
	var btn_w: float = 200.0
	var btn_h: float = 50.0
	var btn_y: float = start_y + grid_h + 30.0
	_start_btn_rect = Rect2(screen.x / 2.0 - btn_w / 2.0, btn_y, btn_w, btn_h)
	_draw_button(font, _start_btn_rect, "▶  START", a, Color(0.2, 0.6, 0.3))
	# Back button (bottom-left of the grid)
	_back_btn_rect = Rect2(start_x, btn_y, 120.0, btn_h)
	_draw_button(font, _back_btn_rect, "✖ Back", a, Color(0.3, 0.3, 0.4))
	# Footer hint
	_draw_centered_text(font, "Click a mode to select  |  [Esc] Back",
		Vector2(screen.x / 2.0, btn_y + btn_h + 30.0), 13,
		Color(0.5, 0.55, 0.7, 0.7 * a))

func _draw_mode_card(font, mode_idx: int, rect: Rect2, a: float, current_mode: int) -> void:
	var mode_name: String = GameModeManager.MODE_NAMES[mode_idx]
	var mode_icon: String = GameModeManager.MODE_ICONS[mode_idx]
	var mode_desc: String = GameModeManager.MODE_DESCRIPTIONS[mode_idx]
	var mode_color: Color = GameModeManager.MODE_COLORS[mode_idx]
	var is_selected: bool = (mode_idx == current_mode)
	var is_hovered: bool = (_hovered_mode == mode_idx)
	# Background
	var bg_color: Color
	if is_selected:
		bg_color = Color(mode_color.r * 0.2, mode_color.g * 0.2, mode_color.b * 0.2, 0.85 * a)
	else:
		bg_color = Color(0.06, 0.07, 0.1, 0.7 * a)
	draw_rect(rect, bg_color, true)
	# Border
	var border_color: Color
	var border_width: float = 2.0
	if is_selected:
		border_color = Color(mode_color.r, mode_color.g, mode_color.b, 0.9 * a)
		border_width = 3.0
	elif is_hovered:
		border_color = Color(0.6, 0.7, 0.9, 0.6 * a)
		border_width = 2.0
	else:
		border_color = Color(0.3, 0.35, 0.45, 0.4 * a)
	draw_rect(rect, border_color, false, border_width)
	# Hover highlight
	if is_hovered and not is_selected:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.05 * a), true)
	# Icon (large, top-center of card)
	var icon_size: Vector2 = font.get_string_size(mode_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + (rect.size.x - icon_size.x) / 2.0, rect.position.y + 42.0),
		mode_icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 32,
		Color(mode_color.r, mode_color.g, mode_color.b, a))
	# Mode name
	var name_size: Vector2 = font.get_string_size(mode_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + (rect.size.x - name_size.x) / 2.0, rect.position.y + 70.0),
		mode_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1.0, 1.0, 1.0, a))
	# "Selected" badge
	if is_selected:
		var badge_text: String = "✓ SELECTED"
		var badge_size: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		font.draw_string(get_canvas_item(),
			Vector2(rect.position.x + (rect.size.x - badge_size.x) / 2.0, rect.position.y + 88.0),
			badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(mode_color.r, mode_color.g, mode_color.b, a))
	# Description (wrapped manually — just draw it; long descriptions may clip)
	# We draw it line by line with a simple word-wrap.
	var desc_y: float = rect.position.y + 110.0
	var desc_max_w: float = rect.size.x - 20.0
	var lines: Array[String] = _word_wrap(font, mode_desc, desc_max_w, 11)
	for line in lines:
		font.draw_string(get_canvas_item(),
			Vector2(rect.position.x + 10.0, desc_y),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.7, 0.75, 0.85, 0.9 * a))
		desc_y += 13.0

func _word_wrap(font, text: String, max_w: float, font_size: int) -> Array[String]:
	var words: Array[String] = text.split(" ")
	var lines: Array[String] = []
	var current: String = ""
	for word in words:
		var test: String = current + (" " if current != "" else "") + word
		var test_size: Vector2 = font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if test_size.x > max_w and current != "":
			lines.append(current)
			current = word
		else:
			current = test
	if current != "":
		lines.append(current)
	return lines

func _draw_button(font, rect: Rect2, text: String, a: float, color: Color) -> void:
	draw_rect(rect, Color(color.r, color.g, color.b, 0.6 * a), true)
	draw_rect(rect, Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.8 * a), false, 1.5)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	font.draw_string(get_canvas_item(),
		Vector2(rect.position.x + (rect.size.x - text_size.x) / 2.0,
		        rect.position.y + (rect.size.y + text_size.y) / 2.0 - 2),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(1.0, 1.0, 1.0, a))

func _draw_centered_text(font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	font.draw_string(get_canvas_item(),
		Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)